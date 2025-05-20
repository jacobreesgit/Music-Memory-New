//
//  MusicLibraryServiceProtocol.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer

/// Protocol for interacting with the local music library
protocol MusicLibraryServiceProtocol {
    // MARK: - Properties
    
    /// Whether the app has access to the music library
    var hasAccess: Bool { get async }
    
    /// Whether the library is currently loading
    var isLoading: Bool { get async }
    
    /// All songs in the library
    var songs: [MPMediaItem] { get async }
    
    /// Current authorization status
    var authorizationStatus: MPMediaLibraryAuthorizationStatus { get async }
    
    // MARK: - Permission Management
    
    /// Request permission to access the music library
    func requestPermission() async throws -> Bool
    
    // MARK: - Library Operations
    
    /// Load all songs from the music library
    func loadLibrary() async throws -> [MPMediaItem]
    
    /// Filter songs by search text (synchronous)
    func filterSongs(containing searchText: String) -> [MPMediaItem]
    
    /// Filter songs by search text (asynchronous with cancellation support)
    func filterSongsAsync(containing searchText: String) async throws -> [MPMediaItem]
    
    // MARK: - Song Lookup
    
    /// Find a local song that matches the provided metadata
    func findLocalSong(title: String, artist: String, album: String) async throws -> MPMediaItem?
    
    // MARK: - Utility Methods
    
    /// Create a consistent key for song identification
    func createSongKey(title: String, artist: String, album: String) -> String
    
    /// Normalize a string for comparison
    func normalizeString(_ string: String?) -> String
}

/// Errors that can occur when interacting with the local music library
enum MusicLibraryServiceError: Error, LocalizedError {
    case permissionDenied
    case loadingFailed(String)
    case cancelled
    case noSongsFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access music library was denied."
        case .loadingFailed(let message):
            return "Failed to load music library: \(message)"
        case .cancelled:
            return "Operation was cancelled."
        case .noSongsFound:
            return "No songs found in library."
        }
    }
}
