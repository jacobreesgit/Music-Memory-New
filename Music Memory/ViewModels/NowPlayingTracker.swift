import Foundation
import MediaPlayer
import SwiftData
import Combine
import UserNotifications

@MainActor
class NowPlayingTracker: ObservableObject {
    @Published var currentSong: TrackedSong?
    @Published var isPlaying: Bool = false
    @Published var currentSystemItem: MPMediaItem?
    
    // Seeding progress tracking
    @Published var isSeeding: Bool = false
    @Published var seedingProgress: Double = 0.0
    @Published var currentSongIndex: Int = 0
    @Published var totalSongsToProcess: Int = 0
    @Published var currentProcessingSong: String = ""
    @Published var estimatedTimeRemaining: Int = 0
    
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext
    private var previousItem: MPMediaItem?
    private var previousPlayCount: Int = 0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
        requestNotificationPermission()
        updateCurrentSong()
        
        // Cleanup old data periodically
        Task {
            await performMaintenanceIfNeeded()
        }
    }
    
    private func setupObservers() {
        // Observe now playing item changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleNowPlayingItemChanged()
                }
            }
            .store(in: &cancellables)
        
        // Observe playback state changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackState()
                }
            }
            .store(in: &cancellables)
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    private func handleNowPlayingItemChanged() {
        print("🎵 Now playing item changed")
        
        // Check if previous song completed
        if let previousItem = previousItem {
            let previousSongID = previousItem.persistentID
            
            let currentPlayCount = previousItem.playCount
            if currentPlayCount > previousPlayCount {
                print("✅ Song completed: \(previousItem.title ?? "Unknown") - Play count increased from \(previousPlayCount) to \(currentPlayCount)")
                recordPlayEvent(for: previousSongID)
            } else {
                print("⏭ Song skipped: \(previousItem.title ?? "Unknown") - Play count unchanged")
            }
        }
        
        // Update to new song
        updateCurrentSong()
        
        // Store reference to current item
        if let currentItem = musicPlayer.nowPlayingItem {
            previousItem = currentItem
            previousPlayCount = currentItem.playCount
        }
    }
    
    private func updateCurrentSong() {
        guard let nowPlayingItem = musicPlayer.nowPlayingItem else {
            currentSong = nil
            currentSystemItem = nil
            return
        }
        
        let persistentID = nowPlayingItem.persistentID
        currentSystemItem = nowPlayingItem
        
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.persistentID == persistentID
            }
        )
        
        do {
            let songs = try modelContext.fetch(descriptor)
            currentSong = songs.first
            print("🎧 Current song: \(currentSong?.title ?? "Unknown")")
        } catch {
            print("❌ Error fetching current song: \(error)")
            currentSong = nil
        }
    }
    
    private func updatePlaybackState() {
        isPlaying = musicPlayer.playbackState == .playing
    }
    
    private func recordPlayEvent(for songID: UInt64) {
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.persistentID == songID
            }
        )
        
        do {
            let songs = try modelContext.fetch(descriptor)
            guard let song = songs.first else {
                print("❌ Song not found for ID: \(songID)")
                return
            }
            
            // Record play event
            let playEvent = PlayEvent(song: song)
            modelContext.insert(playEvent)
            
            // Increment local play count
            song.incrementPlayCount()
            
            // Save changes
            try modelContext.save()
            
            print("📊 Recorded play event for: \(song.title)")
            print("   Total plays: \(song.totalPlayCount)")
            
            // Check for rank changes and notify
            Task {
                await checkRankChangeAndNotify(for: song)
            }
            
        } catch {
            print("❌ Error recording play event: \(error)")
        }
    }
    
    private func checkRankChangeAndNotify(for song: TrackedSong) async {
        // Recalculate rankings
        let descriptor = FetchDescriptor<TrackedSong>(
            sortBy: [SortDescriptor(\.localPlayCount, order: .reverse),
                     SortDescriptor(\.baselinePlayCount, order: .reverse)]
        )
        
        do {
            let allSongs = try modelContext.fetch(descriptor)
            
            // Update rankings
            for (index, trackedSong) in allSongs.enumerated() {
                let newRank = index + 1
                if trackedSong.lastKnownRank != newRank {
                    trackedSong.updateRank(newRank)
                }
            }
            
            try modelContext.save()
            
            // Send notification if rank changed
            if let currentRank = song.lastKnownRank,
               let previousRank = song.previousRank,
               currentRank != previousRank {
                
                let title = "Chart Movement!"
                let body: String
                
                if currentRank == 1 {
                    body = "'\(song.title)' just jumped to #1 on your chart! 🎉"
                } else if currentRank < previousRank {
                    body = "'\(song.title)' climbed to #\(currentRank) (up \(previousRank - currentRank) spots)"
                } else {
                    body = "'\(song.title)' moved to #\(currentRank)"
                }
                
                await sendNotification(title: title, body: body)
            }
            
        } catch {
            print("❌ Error updating rankings: \(error)")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📬 Notification sent: \(body)")
        } catch {
            print("❌ Error sending notification: \(error)")
        }
    }
    
    func seedLibrary() async {
        print("🌱 Starting library seed...")
        
        isSeeding = true
        seedingProgress = 0.0
        currentSongIndex = 0
        currentProcessingSong = ""
        estimatedTimeRemaining = 0
        
        let query = MPMediaQuery.songs()
        guard let items = query.items else {
            print("❌ No songs found in library")
            isSeeding = false
            return
        }
        
        totalSongsToProcess = items.count
        print("📚 Found \(items.count) songs in library")
        
        let startTime = Date()
        var processedCount = 0
        
        for (index, item) in items.enumerated() {
            currentSongIndex = index + 1
            currentProcessingSong = "\(item.artist ?? "Unknown Artist") - \(item.title ?? "Unknown Title")"
            
            // Update progress
            seedingProgress = Double(index) / Double(items.count)
            
            // Calculate estimated time remaining
            if index > 10 { // Start estimating after processing a few songs
                let elapsedTime = Date().timeIntervalSince(startTime)
                let averageTimePerSong = elapsedTime / Double(index)
                let remainingSongs = items.count - index
                estimatedTimeRemaining = Int(averageTimePerSong * Double(remainingSongs))
            }
            
            let persistentID = item.persistentID
            
            // Check if song already exists
            let descriptor = FetchDescriptor<TrackedSong>(
                predicate: #Predicate { song in
                    song.persistentID == persistentID
                }
            )
            
            do {
                let existingSongs = try modelContext.fetch(descriptor)
                if !existingSongs.isEmpty {
                    continue // Skip if already tracked
                }
                
                // Save album artwork to file system
                var artworkFileName: String?
                if let artwork = item.artwork,
                   let image = artwork.image(at: CGSize(width: 300, height: 300)) {
                    artworkFileName = ArtworkManager.shared.save(artwork: image, for: persistentID)
                }
                
                // Create new tracked song
                let trackedSong = TrackedSong(
                    persistentID: persistentID,
                    title: item.title ?? "Unknown Title",
                    artist: item.artist ?? "Unknown Artist",
                    albumTitle: item.albumTitle,
                    artworkFileName: artworkFileName,
                    baselinePlayCount: item.playCount
                )
                
                modelContext.insert(trackedSong)
                processedCount += 1
                print("➕ Added: \(trackedSong.title) by \(trackedSong.artist)")
                
                // Save every 50 songs to avoid memory issues
                if processedCount % 50 == 0 {
                    try modelContext.save()
                }
                
            } catch {
                print("❌ Error checking/adding song: \(error)")
            }
            
            // Small delay to allow UI updates and prevent blocking
            if index % 10 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }
        }
        
        // Final progress update
        seedingProgress = 1.0
        currentProcessingSong = "Completing setup..."
        
        do {
            try modelContext.save()
            print("✅ Library seed completed - Added \(processedCount) new songs")
        } catch {
            print("❌ Error saving seeded library: \(error)")
        }
        
        // Short delay to show completion
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isSeeding = false
    }
    
    // MARK: - Maintenance and Cleanup
    
    private func performMaintenanceIfNeeded() async {
        let lastMaintenance = UserDefaults.standard.object(forKey: "lastMaintenanceDate") as? Date ?? Date.distantPast
        let daysSinceLastMaintenance = Calendar.current.dateComponents([.day], from: lastMaintenance, to: Date()).day ?? 0
        
        if daysSinceLastMaintenance >= 7 { // Weekly maintenance
            await performMaintenance()
            UserDefaults.standard.set(Date(), forKey: "lastMaintenanceDate")
        }
    }
    
    func performMaintenance() async {
        print("🧹 Starting database maintenance...")
        
        // 1. Clean up old play events (keep only last 6 months)
        await cleanupOldPlayEvents()
        
        // 2. Clean up orphaned artwork files
        await cleanupOrphanedArtwork()
        
        // 3. Remove unused songs
        await cleanupUnusedSongs()
        
        print("✅ Database maintenance completed")
    }
    
    private func cleanupOldPlayEvents() async {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<PlayEvent>(
            predicate: #Predicate { event in
                event.timestamp < sixMonthsAgo
            }
        )
        
        do {
            let oldEvents = try modelContext.fetch(descriptor)
            print("🗑 Deleting \(oldEvents.count) old play events")
            
            for event in oldEvents {
                modelContext.delete(event)
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error cleaning up old play events: \(error)")
        }
    }
    
    private func cleanupOrphanedArtwork() async {
        do {
            let allSongs = try modelContext.fetch(FetchDescriptor<TrackedSong>())
            let validFileNames = Set(allSongs.compactMap { $0.artworkFileName })
            
            ArtworkManager.shared.cleanupOrphanedArtwork(validFileNames: validFileNames)
            print("🖼 Cleaned up orphaned artwork files")
        } catch {
            print("❌ Error cleaning up artwork: \(error)")
        }
    }
    
    private func cleanupUnusedSongs() async {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.localPlayCount == 0
            }
        )
        
        do {
            let unplayedSongs = try modelContext.fetch(descriptor)
            let songsToRemove = unplayedSongs.filter { song in
                // Remove if no recent play events and no baseline plays
                let recentEvents = song.playEvents.filter { $0.timestamp > threeMonthsAgo }
                return recentEvents.isEmpty && song.baselinePlayCount == 0
            }
            
            print("🗑 Removing \(songsToRemove.count) unused songs")
            
            for song in songsToRemove {
                // Clean up artwork file
                if let fileName = song.artworkFileName {
                    ArtworkManager.shared.deleteArtwork(for: fileName)
                }
                modelContext.delete(song)
            }
            
            try modelContext.save()
            
        } catch {
            print("❌ Error removing unused songs: \(error)")
        }
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }
}
