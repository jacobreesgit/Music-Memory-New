//
//  LocalMusicLibrary.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer

/// Errors that can occur when interacting with the local music library
enum LocalMusicLibraryError: Error {
    case permissionDenied
    case loadingFailed(String)
    case cancelled
    case noSongsFound
}

/// Handles local device music library access and operations with modern Swift concurrency
actor LocalMusicLibrary {
    // Properties
    private(set) var songs: [MPMediaItem] = []
    private(set) var isLoading: Bool = false
    private(set) var hasAccess: Bool = false
    private(set) var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    // Cache for optimizing lookups - isolated within the actor
    private var songLookupCache: [String: MPMediaItem] = [:]
    
    // Task for managing cancellation
    private var currentLoadingTask: Task<[MPMediaItem], Error>?
    
    init() {
        // Check current authorization status
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Set the loading state (actor-isolated)
    private func setLoading(_ value: Bool) {
        isLoading = value
    }
    
    /// Set songs array (actor-isolated)
    private func setSongs(_ newSongs: [MPMediaItem]) {
        songs = newSongs
    }
    
    /// Update authorization status (actor-isolated)
    private func updateAuthStatus(_ status: MPMediaLibraryAuthorizationStatus, _ access: Bool) {
        authorizationStatus = status
        hasAccess = access
    }
    
    /// Request permission for the local library using async/await
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
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }
                    
                    Task {
                        await self.updateAuthStatus(status, status == .authorized)
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
        } else {
            // Permission denied or restricted
            updateAuthStatus(currentStatus, false)
            throw LocalMusicLibraryError.permissionDenied
        }
    }
    
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
    private func updateStateAfterLoading(songs: [MPMediaItem]) {
        setSongs(songs)
        setLoading(false)
    }
    
    /// Update state after loading error
    private func handleLoadError() {
        setLoading(false)
    }
    
    /// Load all songs from the local music library with async/await
    func loadLibrary() async throws -> [MPMediaItem] {
        guard hasAccess else {
            throw LocalMusicLibraryError.permissionDenied
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
                throw LocalMusicLibraryError.noSongsFound
            }
            
            return allSongs
        }
        
        currentLoadingTask = loadTask
        
        do {
            let loadedSongs = try await loadTask.value
            updateStateAfterLoading(songs: loadedSongs)
            
            // Build lookup cache
            await buildSongLookupCache()
            
            return loadedSongs
        } catch is CancellationError {
            handleLoadError()
            throw LocalMusicLibraryError.cancelled
        } catch {
            handleLoadError()
            throw error
        }
    }
    
    /// Build lookup cache for local songs to improve performance
    private func buildSongLookupCache() async {
        // Clear existing cache
        songLookupCache.removeAll()
        
        // Build new cache (thread-safe within actor)
        for song in songs {
            // Use safe nil-coalescing instead of force-unwrapping
            let title = song.title ?? ""
            let artist = song.artist ?? ""
            let album = song.albumTitle ?? ""
            
            let key = createSongKey(title: title, artist: artist, album: album)
            songLookupCache[key] = song
        }
    }
    
    /// Find a local song that matches the provided parameters
    func findLocalSong(title: String, artist: String, album: String) -> MPMediaItem? {
        let key = createSongKey(title: title, artist: artist, album: album)
        return songLookupCache[key]
    }
    
    /// Filter local songs by search text using fuzzy matching
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
    
    /// Helper function to create a consistent key for a song
    func createSongKey(title: String, artist: String, album: String) -> String {
        return "\(normalizeString(title))|\(normalizeString(artist))|\(normalizeString(album))"
    }
    
    /// Normalize strings for comparison (remove extra spaces, make lowercase, etc.)
    func normalizeString(_ string: String?) -> String {
        guard let string = string else { return "" }
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}

// MARK: - Sendable Conformance
extension MPMediaItem: @unchecked Sendable {}
