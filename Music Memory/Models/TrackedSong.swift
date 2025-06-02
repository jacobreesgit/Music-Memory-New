import Foundation
import SwiftData
import SwiftUI

@Model
final class TrackedSong {
    @Attribute(.unique) var persistentID: UInt64
    var title: String
    var artist: String
    var albumTitle: String?
    var artworkFileName: String? // Store filename instead of data
    var baselinePlayCount: Int
    var localPlayCount: Int
    var lastKnownRank: Int?
    var previousRank: Int?
    
    @Relationship(deleteRule: .cascade, inverse: \PlayEvent.song)
    var playEvents: [PlayEvent] = []
    
    var totalPlayCount: Int {
        baselinePlayCount + localPlayCount
    }
    
    init(persistentID: UInt64,
         title: String,
         artist: String,
         albumTitle: String? = nil,
         artworkFileName: String? = nil,
         baselinePlayCount: Int = 0) {
        self.persistentID = persistentID
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkFileName = artworkFileName
        self.baselinePlayCount = baselinePlayCount
        self.localPlayCount = 0
        self.lastKnownRank = nil
        self.previousRank = nil
    }
    
    func incrementPlayCount() {
        localPlayCount += 1
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
