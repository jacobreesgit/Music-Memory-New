//
//  SearchResult.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer
import MusicKit

/// Search result model with pre-computed data for efficient display
struct SearchResult: Identifiable {
    enum ResultType {
        case localSong(MPMediaItem)
        case appleMusicSong(Song, PrecomputedData)
    }
    
    /// Pre-computed data for Apple Music songs to avoid expensive operations during scrolling
    struct PrecomputedData {
        let isInLibrary: Bool
        let playCount: Int?
        let localSong: MPMediaItem?
    }
    
    let id = UUID()
    let type: ResultType
    
    // MARK: - Computed Properties
    
    /// Play count of the song (if available)
    var playCount: Int? {
        switch type {
        case .localSong(let song):
            return song.playCount
        case .appleMusicSong(_, let data):
            return data.playCount
        }
    }
    
    /// Whether the song is in the local library
    var isInLibrary: Bool {
        switch type {
        case .localSong:
            return true
        case .appleMusicSong(_, let data):
            return data.isInLibrary
        }
    }
    
    /// Title of the song
    var title: String {
        switch type {
        case .localSong(let song):
            return song.title ?? "Unknown"
        case .appleMusicSong(let song, _):
            return song.title
        }
    }
    
    /// Artist of the song
    var artist: String {
        switch type {
        case .localSong(let song):
            return song.artist ?? "Unknown Artist"
        case .appleMusicSong(let song, _):
            return song.artistName
        }
    }
    
    /// Album title of the song
    var album: String {
        switch type {
        case .localSong(let song):
            return song.albumTitle ?? "Unknown Album"
        case .appleMusicSong(let song, _):
            return song.albumTitle ?? "Unknown Album"
        }
    }
    
    /// Whether the song is explicit
    var isExplicit: Bool {
        switch type {
        case .localSong(let song):
            return song.isExplicitItem
        case .appleMusicSong(let song, _):
            return song.contentRating == .explicit
        }
    }
}
