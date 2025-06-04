import Foundation
import MediaPlayer
import SwiftData

@MainActor
class SystemSyncManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func performSystemSync() async {
        print("🔄 Starting system sync...")
        
        let query = MPMediaQuery.songs()
        guard let items = query.items else {
            print("❌ No songs found in system library")
            return
        }
        
        var syncedCount = 0
        var newPlaysDetected = 0
        
        for item in items {
            let persistentID = item.persistentID
            let currentSystemCount = item.playCount
            
            // Find tracked song
            let descriptor = FetchDescriptor<TrackedSong>(
                predicate: #Predicate { song in
                    song.persistentID == persistentID
                }
            )
            
            do {
                let songs = try modelContext.fetch(descriptor)
                
                if let trackedSong = songs.first {
                    // Existing song - check for new plays
                    let newPlays = await syncExistingSong(trackedSong: trackedSong, currentSystemCount: currentSystemCount)
                    newPlaysDetected += newPlays
                    syncedCount += 1
                } else {
                    // New song - add to tracking
                    await addNewSong(item: item)
                    syncedCount += 1
                }
                
            } catch {
                print("❌ Error syncing song \(item.title ?? "Unknown"): \(error)")
            }
            
            // Save periodically to avoid memory issues
            if syncedCount % 100 == 0 {
                try? modelContext.save()
            }
        }
        
        // Final save
        do {
            try modelContext.save()
            print("✅ System sync completed")
            print("   Synced: \(syncedCount) songs")
            print("   New plays detected: \(newPlaysDetected)")
        } catch {
            print("❌ Error saving sync results: \(error)")
        }
    }
    
    private func syncExistingSong(trackedSong: TrackedSong, currentSystemCount: Int) async -> Int {
        let lastKnownCount = trackedSong.lastSystemPlayCount
        let newPlaysCount = currentSystemCount - lastKnownCount
        
        guard newPlaysCount > 0 else {
            // No new plays detected
            return 0
        }
        
        print("🔍 Detected \(newPlaysCount) new plays for: \(trackedSong.title)")
        
        // Update the system count
        trackedSong.updateSystemPlayCount(currentSystemCount)
        
        // Create play events for the new plays with recent timestamps
        let timeSinceLastSync = Date().timeIntervalSince(trackedSong.lastSyncTimestamp)
        await createEstimatedPlayEvents(
            for: trackedSong,
            playCount: newPlaysCount,
            timeWindow: timeSinceLastSync
        )
        
        return newPlaysCount
    }
    
    // UPDATED: Store system play count without creating historical PlayEvents
    private func addNewSong(item: MPMediaItem) async {
        // Save album artwork to file system
        var artworkFileName: String?
        if let artwork = item.artwork,
           let image = artwork.image(at: CGSize(width: 300, height: 300)) {
            artworkFileName = ArtworkManager.shared.save(artwork: image, for: item.persistentID)
        }
        
        // UPDATED: Create tracked song with system play count, but NO historical PlayEvents
        let trackedSong = TrackedSong(
            persistentID: item.persistentID,
            title: item.title ?? "Unknown Title",
            artist: item.artist ?? "Unknown Artist",
            albumTitle: item.albumTitle,
            artworkFileName: artworkFileName,
            duration: item.playbackDuration,
            systemPlayCount: item.playCount  // Store the count, don't create PlayEvents
        )
        
        modelContext.insert(trackedSong)
        
        print("➕ Added new song: \(trackedSong.title) (system: \(item.playCount) plays)")
        print("🎯 Historical plays stored as count only - no fake timestamps created")
    }
    
    // UPDATED: Only create PlayEvents for recent activity (not historical data)
    private func createEstimatedPlayEvents(for song: TrackedSong, playCount: Int, timeWindow: TimeInterval) async {
        // Only create PlayEvents for plays that happened since last sync
        // These are real plays that occurred while app was closed
        let now = Date()
        let startTime = now.addingTimeInterval(-timeWindow)
        
        for _ in 0..<playCount {
            // Distribute plays across the time window since last sync
            let randomOffset = TimeInterval.random(in: 0...timeWindow)
            let playTime = startTime.addingTimeInterval(randomOffset)
            
            let playEvent = PlayEvent(
                timestamp: playTime,
                song: song,
                source: .systemSync,
                songDuration: song.duration > 0 ? song.duration : nil
            )
            
            modelContext.insert(playEvent)
        }
        
        print("📊 Created \(playCount) sync PlayEvents for recent activity")
    }
    
    // REMOVED: createHistoricalPlayEvents function - no longer needed
    
    func quickSync() async {
        // Lightweight sync for app foreground - only check current playing song
        guard let currentItem = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else { return }
        
        // Capture the persistentID before using it in the predicate
        let targetPersistentID = currentItem.persistentID
        
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { song in
                song.persistentID == targetPersistentID
            }
        )
        
        do {
            let songs = try modelContext.fetch(descriptor)
            if let trackedSong = songs.first {
                let currentSystemCount = currentItem.playCount
                let _ = await syncExistingSong(trackedSong: trackedSong, currentSystemCount: currentSystemCount)
                try modelContext.save()
            }
        } catch {
            print("❌ Error in quick sync: \(error)")
        }
    }
    
    func shouldPerformFullSync() -> Bool {
        let lastFullSync = UserDefaults.standard.object(forKey: "lastFullSyncDate") as? Date ?? Date.distantPast
        let hoursSinceLastSync = Date().timeIntervalSince(lastFullSync) / 3600
        
        // Perform full sync if more than 4 hours since last sync
        return hoursSinceLastSync >= 4
    }
    
    func markFullSyncComplete() {
        UserDefaults.standard.set(Date(), forKey: "lastFullSyncDate")
    }
}
