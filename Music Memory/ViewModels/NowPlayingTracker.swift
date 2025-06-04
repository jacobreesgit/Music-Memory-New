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
    
    // Sync status
    @Published var isSyncing: Bool = false
    
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext
    let playbackMonitor: PlaybackMonitor
    private let systemSyncManager: SystemSyncManager
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.playbackMonitor = PlaybackMonitor()
        self.systemSyncManager = SystemSyncManager(modelContext: modelContext)
        
        setupPlaybackMonitor()
        setupObservers()
        requestNotificationPermission()
        updateCurrentSong()
        
        // Perform system sync on app launch
        Task {
            await performInitialSync()
        }
    }
    
    private func setupPlaybackMonitor() {
        // Handle play completions from real-time monitoring
        playbackMonitor.onPlayCompleted = { [weak self] item, playbackDuration, songDuration, completionPercentage in
            Task { @MainActor in
                await self?.handlePlayCompleted(
                    item: item,
                    playbackDuration: playbackDuration,
                    songDuration: songDuration,
                    completionPercentage: completionPercentage
                )
            }
        }
    }
    
    private func setupObservers() {
        // Observe now playing item changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateCurrentSong()
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
        
        // App lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppForegrounded()
                }
            }
            .store(in: &cancellables)
        
        musicPlayer.beginGeneratingPlaybackNotifications()
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
    
    private func handlePlayCompleted(item: MPMediaItem, playbackDuration: TimeInterval, songDuration: TimeInterval, completionPercentage: Double) async {
        let persistentID = item.persistentID
        
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.persistentID == persistentID
            }
        )
        
        do {
            let songs = try modelContext.fetch(descriptor)
            guard let song = songs.first else {
                print("❌ Song not found for completed play: \(item.title ?? "Unknown")")
                return
            }
            
            // Create play event with detailed tracking data
            let playEvent = PlayEvent(
                timestamp: Date(),
                song: song,
                source: .realTime,
                playbackDuration: playbackDuration,
                songDuration: songDuration,
                completionPercentage: completionPercentage
            )
            
            modelContext.insert(playEvent)
            
            // Save changes
            try modelContext.save()
            
            print("📊 Recorded real-time play event for: \(song.title)")
            print("   Duration: \(Int(playbackDuration))s / \(Int(songDuration))s (\(Int(completionPercentage * 100))%)")
            print("   Total plays: \(song.totalPlayCount)")
            
            // Check for rank changes and notify
            await checkRankChangeAndNotify(for: song)
            
        } catch {
            print("❌ Error recording play event: \(error)")
        }
    }
    
    private func performInitialSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        if systemSyncManager.shouldPerformFullSync() {
            await systemSyncManager.performSystemSync()
            systemSyncManager.markFullSyncComplete()
        } else {
            await systemSyncManager.quickSync()
        }
        
        isSyncing = false
    }
    
    private func handleAppForegrounded() async {
        // Quick sync when app comes to foreground
        await systemSyncManager.quickSync()
    }
    
    private func checkRankChangeAndNotify(for song: TrackedSong) async {
        // Recalculate rankings
        let descriptor = FetchDescriptor<TrackedSong>(
            sortBy: [SortDescriptor(\.totalPlayCount, order: .reverse)]
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
        
        // Small delay to ensure permission is fully processed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
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
            if index > 10 {
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
                    duration: item.playbackDuration,
                    systemPlayCount: item.playCount
                )
                
                modelContext.insert(trackedSong)
                
                // Create historical play events if the song has play count
                if item.playCount > 0 {
                    await createHistoricalPlayEvents(for: trackedSong, playCount: item.playCount)
                }
                
                processedCount += 1
                print("➕ Added: \(trackedSong.title) by \(trackedSong.artist) (\(item.playCount) plays)")
                
                // Save every 50 songs to avoid memory issues
                if processedCount % 50 == 0 {
                    try modelContext.save()
                }
                
            } catch {
                print("❌ Error checking/adding song: \(error)")
            }
            
            // Small delay to allow UI updates
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
        
        // Mark that we've completed initial seeding
        UserDefaults.standard.set(true, forKey: "hasSeededLibrary")
    }
    
    private func createHistoricalPlayEvents(for song: TrackedSong, playCount: Int) async {
        let now = Date()
        let yearRange: TimeInterval = 365 * 24 * 60 * 60 // 1 year
        
        for _ in 0..<playCount {
            let randomTimeAgo = TimeInterval.random(in: 0...yearRange)
            let playTime = now.addingTimeInterval(-randomTimeAgo)
            
            let playEvent = PlayEvent(
                timestamp: playTime,
                song: song,
                source: .estimated,
                songDuration: song.duration > 0 ? song.duration : nil
            )
            
            modelContext.insert(playEvent)
        }
    }
    
    // MARK: - Maintenance and Cleanup
    
    func performMaintenance() async {
        print("🧹 Starting database maintenance...")
        
        // 1. Clean up old play events (keep only last 1 year)
        await cleanupOldPlayEvents()
        
        // 2. Clean up orphaned artwork files
        await cleanupOrphanedArtwork()
        
        // 3. Remove completely unused songs
        await cleanupUnusedSongs()
        
        print("✅ Database maintenance completed")
    }
    
    private func cleanupOldPlayEvents() async {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<PlayEvent>(
            predicate: #Predicate { event in
                event.timestamp < oneYearAgo
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
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.totalPlayCount == 0
            }
        )
        
        do {
            let unplayedSongs = try modelContext.fetch(descriptor)
            let songsToRemove = unplayedSongs.filter { song in
                // Remove only if no recent activity and no historical plays
                song.playEvents.isEmpty || song.playEvents.allSatisfy { $0.timestamp < sixMonthsAgo }
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
