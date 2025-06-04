import Foundation
import SwiftData
import SwiftUI

@Model
final class TrackedSong {
    @Attribute(.unique) var persistentID: UInt64
    var title: String
    var artist: String
    var albumTitle: String?
    var artworkFileName: String?
    var duration: TimeInterval
    var lastSystemPlayCount: Int
    var lastSyncTimestamp: Date
    var lastKnownRank: Int?
    var previousRank: Int?
    
    @Relationship(deleteRule: .cascade, inverse: \PlayEvent.song)
    var playEvents: [PlayEvent] = []
    
    // Computed properties
    var totalPlayCount: Int {
        playEvents.count
    }
    
    var realTimePlayCount: Int {
        playEvents.filter { $0.source == .realTime }.count
    }
    
    var systemSyncPlayCount: Int {
        playEvents.filter { $0.source == .systemSync }.count
    }
    
    var estimatedPlayCount: Int {
        playEvents.filter { $0.source == .estimated }.count
    }
    
    init(persistentID: UInt64,
         title: String,
         artist: String,
         albumTitle: String? = nil,
         artworkFileName: String? = nil,
         duration: TimeInterval = 0,
         systemPlayCount: Int = 0) {
        self.persistentID = persistentID
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkFileName = artworkFileName
        self.duration = duration
        self.lastSystemPlayCount = systemPlayCount
        self.lastSyncTimestamp = Date()
        self.lastKnownRank = nil
        self.previousRank = nil
    }
    
    func updateSystemPlayCount(_ newCount: Int) {
        lastSystemPlayCount = newCount
        lastSyncTimestamp = Date()
    }
    
    func updateRank(_ newRank: Int) {
        previousRank = lastKnownRank
        lastKnownRank = newRank
    }
    
    var rankMovement: RankMovement {
        guard let current = lastKnownRank else { return .new }
        guard let previous = previousRank else { return .new }
        
        if current < previous {
            return .up(previous - current)
        } else if current > previous {
            return .down(current - previous)
        } else {
            return .unchanged
        }
    }
    
    // Get recent plays within timeframe
    func playsInPeriod(since startDate: Date) -> [PlayEvent] {
        return playEvents.filter { $0.timestamp >= startDate }
    }
    
    // Get artwork from file system
    var albumArtwork: UIImage? {
        guard let fileName = artworkFileName else { return nil }
        return ArtworkManager.shared.loadArtwork(for: fileName)
    }
}

enum RankMovement {
    case up(Int)
    case down(Int)
    case unchanged
    case new
    
    var symbol: String {
        switch self {
        case .up(let positions):
            return "↑\(positions)"
        case .down(let positions):
            return "↓\(positions)"
        case .unchanged:
            return "="
        case .new:
            return "NEW"
        }
    }
    
    var color: Color {
        switch self {
        case .up:
            return .green
        case .down:
            return .red
        case .unchanged:
            return .gray
        case .new:
            return .blue
        }
    }
}
