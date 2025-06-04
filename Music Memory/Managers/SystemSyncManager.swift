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
        
        // Create play events for the new plays
        let timeSinceLastSync = Date().timeIntervalSince(trackedSong.lastSyncTimestamp)
        await createEstimatedPlayEvents(
            for: trackedSong,
            playCount: newPlaysCount,
            timeWindow: timeSinceLastSync
        )
        
        return newPlaysCount
    }
    
    private func addNewSong(item: MPMediaItem) async {
        // Save album artwork to file system
        var artworkFileName: String?
        if let artwork = item.artwork,
           let image = artwork.image(at: CGSize(width: 300, height: 300)) {
            artworkFileName = ArtworkManager.shared.save(artwork: image, for: item.persistentID)
        }
        
        // Create tracked song
        let trackedSong = TrackedSong(
            persistentID: item.persistentID,
            title: item.title ?? "Unknown Title",
            artist: item.artist ?? "Unknown Artist",
            albumTitle: item.albumTitle,
            artworkFileName: artworkFileName,
            duration: item.playbackDuration,
            systemPlayCount: item.playCount
        )
        
        modelContext.insert(trackedSong)
        
        // If song already has play count, create historical events
        if item.playCount > 0 {
            await createHistoricalPlayEvents(for: trackedSong, playCount: item.playCount)
        }
        
        print("➕ Added new song: \(trackedSong.title) (\(item.playCount) historical plays)")
    }
    
    private func createEstimatedPlayEvents(for song: TrackedSong, playCount: Int, timeWindow: TimeInterval) async {
        // Distribute plays across the time window
        let now = Date()
        let startTime = now.addingTimeInterval(-timeWindow)
        
        for _ in 0..<playCount {
            // Distribute plays somewhat randomly across the time window
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
    }
    
    private func createHistoricalPlayEvents(for song: TrackedSong, playCount: Int) async {
        // Create historical play events spread over the past
        let now = Date()
        let dayRange: TimeInterval = 365 * 24 * 60 * 60 // 1 year ago
        
        for _ in 0..<playCount {
            // Distribute historical plays over past year
            let randomDaysAgo = TimeInterval.random(in: 0...dayRange)
            let playTime = now.addingTimeInterval(-randomDaysAgo)
            
            let playEvent = PlayEvent(
                timestamp: playTime,
                song: song,
                source: .estimated,
                songDuration: song.duration > 0 ? song.duration : nil
            )
            
            modelContext.insert(playEvent)
        }
    }
    
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
