import Foundation
import SwiftData

@Model
final class PlayEvent {
    var timestamp: Date
    var song: TrackedSong?
    var source: PlaySource
    var playbackDuration: TimeInterval?
    var songDuration: TimeInterval?
    var completionPercentage: Double?
    
    init(timestamp: Date = Date(),
         song: TrackedSong,
         source: PlaySource = .realTime,
         playbackDuration: TimeInterval? = nil,
         songDuration: TimeInterval? = nil,
         completionPercentage: Double? = nil) {
        self.timestamp = timestamp
        self.song = song
        self.source = source
        self.playbackDuration = playbackDuration
        self.songDuration = songDuration
        self.completionPercentage = completionPercentage
    }
}

// UPDATED: Removed .estimated since we no longer create historical PlayEvents
enum PlaySource: String, Codable, CaseIterable {
    case realTime = "real_time"        // Tracked while app was active
    case systemSync = "system_sync"    // Discovered via system sync (recent activity)
    
    var displayName: String {
        switch self {
        case .realTime: return "Live"
        case .systemSync: return "Sync"
        }
    }
    
    var reliability: Double {
        switch self {
        case .realTime: return 1.0      // Highest reliability - real-time tracking
        case .systemSync: return 0.8    // High reliability - recent system activity
        }
    }
    
    var description: String {
        switch self {
        case .realTime:
            return "Tracked live while app was active"
        case .systemSync:
            return "Discovered through system sync (played while app was closed)"
        }
    }
}
