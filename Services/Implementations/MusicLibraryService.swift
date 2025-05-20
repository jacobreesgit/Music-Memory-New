//
//  MusicLibraryService.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer

/// Service for accessing the local device music library
class MusicLibraryService: MusicLibraryServiceProtocol {
    // MARK: - Private Actor
    
    // Actor for thread-safe operations
    private let libraryActor = LocalMusicLibraryActor()
    
    // Thread-safe library actor
    private actor LocalMusicLibraryActor {
        // MARK: - Properties
        
        private(set) var songs: [MPMediaItem] = []
        private(set) var isLoading: Bool = false
        private(set) var hasAccess: Bool = false
        private(set) var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
        
        // Cache for optimizing lookups
        private var songLookupCache: [String: MPMediaItem] = [:]
        
        // Task for managing cancellation
        private var currentLoadingTask: Task<[MPMediaItem], Error>?
        
        // MARK: - Initialization
        
        init() {
            // Check current authorization status
            authorizationStatus = MPMediaLibrary.authorizationStatus()
            hasAccess = authorizationStatus == .authorized
        }
        
        // MARK: - State Management
        
        /// Set the loading state
        func setLoading(_ value: Bool) {
            isLoading = value
        }
        
        /// Set songs array
        func setSongs(_ newSongs: [MPMediaItem]) {
            songs = newSongs
        }
        
        /// Update authorization status
        func updateAuthStatus(_ status: MPMediaLibraryAuthorizationStatus, _ access: Bool) {
            authorizationStatus = status
            hasAccess = access
        }
        
        // MARK: - Permission Management
        
        /// Request permission to access the music library
        func requestPermission() async throws -> Bool {
            let currentStatus = MPMediaLibrary.authorizationStatus()
            
            if currentStatus == .authorized {
                // Already authorized
                updateAuthStatus(currentStatus, true)
                return true
            } else if currentStatus == .notDetermined {
                // Request authorization with continuation
                return await withCheckedContinuation { continuation in
                    MPMediaLibrary.requestAuthorization { [weak self] status in
                        guard let self = self else {
                            continuation.resume(returning: false)
                            return
                        }
                        
                        self.updateAuthStatus(status, status == .authorized)
                        continuation.resume(returning: status == .authorized)
                    }
                }
            } else {
                // Permission denied or restricted
                updateAuthStatus(currentStatus, false)
                throw MusicLibraryServiceError.permissionDenied
            }
        }
        
        // MARK: - Loading Management
        
        /// Cancel any ongoing library loading operation
        func cancelLoading() {
            currentLoadingTask?.cancel()
            currentLoadingTask = nil
            
            // Reset loading state
            if isLoading {
                setLoading(false)
            }
        }
        
        /// Update state after loading completion
        func updateStateAfterLoading(songs: [MPMediaItem]) {
            setSongs(songs)
            setLoading(false)
        }
        
        /// Update state after loading error
        func handleLoadError() {
            setLoading(false)
        }
        
        // MARK: - Library Operations
        
        /// Load all songs from the local music library
        func loadLibrary() async throws -> [MPMediaItem] {
            guard hasAccess else {
                throw MusicLibraryServiceError.permissionDenied
            }
            
            // Cancel any existing load operation
            cancelLoading()
            
            // Set loading state
            setLoading(true)
            
            // Create a new task for loading that can be cancelled
            let loadTask = Task<[MPMediaItem], Error> {
                // Check for cancellation
                try Task.checkCancellation()
                
                let songsQuery = MPMediaQuery.songs()
                songsQuery.groupingType = .title
                
                // Check for cancellation again before potentially expensive operation
                try Task.checkCancellation()
                
                guard let allSongs = songsQuery.items, !allSongs.isEmpty else {
                    throw MusicLibraryServiceError.noSongsFound
                }
                
                return allSongs
            }
            
            currentLoadingTask = loadTask
            
            do {
                let loadedSongs = try await loadTask.value
                updateStateAfterLoading(songs: loadedSongs)
                
                // Build lookup cache
                buildSongLookupCache()
                
                return loadedSongs
            } catch is CancellationError {
                handleLoadError()
                throw MusicLibraryServiceError.cancelled
            } catch {
                handleLoadError()
                throw MusicLibraryServiceError.loadingFailed(error.localizedDescription)
            }
        }
        
        // MARK: - Cache Management
        
        /// Build lookup cache for local songs to improve performance
        func buildSongLookupCache() {
            // Clear existing cache
            songLookupCache.removeAll()
            
            // Build new cache
            for song in songs {
                let title = song.title ?? ""
                let artist = song.artist ?? ""
                let album = song.albumTitle ?? ""
                
                let key = createSongKey(title: title, artist: artist, album: album)
                songLookupCache[key] = song
            }
        }
        
        // MARK: - Search and Lookup
        
        /// Find a local song that matches the provided parameters
        func findLocalSong(title: String, artist: String, album: String) -> MPMediaItem? {
            let key = createSongKey(title: title, artist: artist, album: album)
            
            // Check direct cache match first (fastest)
            if let match = songLookupCache[key] {
                return match
            }
            
            // If not found in cache, try fuzzy matching
            for song in songs {
                let songTitle = song.title ?? ""
                let songArtist = song.artist ?? ""
                
                if songTitle.lowercased() == title.lowercased() &&
                   songArtist.lowercased() == artist.lowercased() {
                    return song
                }
            }
            
            return nil
        }
        
        /// Filter songs by search text using fuzzy matching
        func filterSongs(containing searchText: String) -> [MPMediaItem] {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedSearch.isEmpty {
                return songs
            } else {
                return songs.filter { song in
                    AppHelpers.fuzzyMatch(song.title, trimmedSearch) ||
                    AppHelpers.fuzzyMatch(song.artist, trimmedSearch) ||
                    AppHelpers.fuzzyMatch(song.albumTitle, trimmedSearch)
                }
            }
        }
        
        /// Asynchronously filter songs with cancellation support
        func filterSongsAsync(containing searchText: String) async throws -> [MPMediaItem] {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // For empty searches, return all songs immediately
            if trimmedSearch.isEmpty {
                return songs
            }
            
            // Use Task for cancellation support
            return try await Task.detached(priority: .userInitiated) { [songs = self.songs] in
                // Check for cancellation before expensive operation
                try Task.checkCancellation()
                
                return songs.filter { song in
                    // Periodically check for cancellation during long operations
                    if Task.isCancelled {
                        return false // Will exit early if cancelled
                    }
                    
                    return AppHelpers.fuzzyMatch(song.title, trimmedSearch) ||
                           AppHelpers.fuzzyMatch(song.artist, trimmedSearch) ||
                           AppHelpers.fuzzyMatch(song.albumTitle, trimmedSearch)
                }
            }.value
        }
        
        // MARK: - Utility Methods
        
        /// Helper function to create a consistent key for a song
        func createSongKey(title: String, artist: String, album: String) -> String {
            return "\(normalizeString(title))|\(normalizeString(artist))|\(normalizeString(album))"
        }
        
        /// Normalize strings for comparison
        func normalizeString(_ string: String?) -> String {
            guard let string = string else { return "" }
            return string.lowguard let string = string else { return "" }
            return string.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "  ", with: " ")
        }
    }
    
    // MARK: - MusicLibraryServiceProtocol
    
    /// Whether the app has access to the music library
    var hasAccess: Bool {
        get async {
            return await libraryActor.hasAccess
        }
    }
    
    /// Whether the library is currently loading
    var isLoading: Bool {
        get async {
            return await libraryActor.isLoading
        }
    }
    
    /// All songs in the library
    var songs: [MPMediaItem] {
        get async {
            return await libraryActor.songs
        }
    }
    
    /// Current authorization status
    var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        get async {
            return await libraryActor.authorizationStatus
        }
    }
    
    /// Request permission to access the music library
    func requestPermission() async throws -> Bool {
        return try await libraryActor.requestPermission()
    }
    
    /// Load all songs from the music library
    func loadLibrary() async throws -> [MPMediaItem] {
        return try await libraryActor.loadLibrary()
    }
    
    /// Filter songs by search text (synchronous)
    func filterSongs(containing searchText: String) -> [MPMediaItem] {
        // This is a non-async call, so we need to use Task for actor access
        let songs = Task {
            await libraryActor.filterSongs(containing: searchText)
        }.result.value ?? []
        
        return songs
    }
    
    /// Filter songs by search text (asynchronous with cancellation support)
    func filterSongsAsync(containing searchText: String) async throws -> [MPMediaItem] {
        return try await libraryActor.filterSongsAsync(containing: searchText)
    }
    
    /// Find a local song that matches the provided metadata
    func findLocalSong(title: String, artist: String, album: String) async throws -> MPMediaItem? {
        return await libraryActor.findLocalSong(title: title, artist: artist, album: album)
    }
    
    /// Create a consistent key for song identification
    func createSongKey(title: String, artist: String, album: String) -> String {
        // Use a synchronous implementation for public API
        return "\(normalizeString(title))|\(normalizeString(artist))|\(normalizeString(album))"
    }
    
    /// Normalize a string for comparison
    func normalizeString(_ string: String?) -> String {
        guard let string = string else { return "" }
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}

// MARK: - Sendable Conformance
extension MPMediaItem: @unchecked Sendable {}
