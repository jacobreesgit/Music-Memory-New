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
            let previousSongID = previousItem.persistentID  // Fixed: No need for conditional cast
            
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
        
        let persistentID = nowPlayingItem.persistentID  // Fixed: Direct assignment
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
        
        let query = MPMediaQuery.songs()
        guard let items = query.items else {
            print("❌ No songs found in library")
            return
        }
        
        print("📚 Found \(items.count) songs in library")
        
        for item in items {
            let persistentID = item.persistentID  // Fixed: Direct assignment
            
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
                
                // Extract album artwork
                var artworkData: Data?
                if let artwork = item.artwork,
                   let image = artwork.image(at: CGSize(width: 100, height: 100)) {
                    artworkData = image.pngData()
                }
                
                // Create new tracked song
                let trackedSong = TrackedSong(
                    persistentID: persistentID,
                    title: item.title ?? "Unknown Title",
                    artist: item.artist ?? "Unknown Artist",
                    albumTitle: item.albumTitle,
                    albumArtworkData: artworkData,
                    baselinePlayCount: item.playCount
                )
                
                modelContext.insert(trackedSong)
                print("➕ Added: \(trackedSong.title) by \(trackedSong.artist)")
                
            } catch {
                print("❌ Error checking/adding song: \(error)")
            }
        }
        
        do {
            try modelContext.save()
            print("✅ Library seed completed")
        } catch {
            print("❌ Error saving seeded library: \(error)")
        }
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }
}
