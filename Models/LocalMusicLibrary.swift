//
//  LocalMusicLibrary.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer

/// Handles local device music library access and operations
class LocalMusicLibrary {
    // Properties
    private(set) var songs: [MPMediaItem] = []
    private(set) var isLoading: Bool = false
    private(set) var hasAccess: Bool = false
    private(set) var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    // Cache for optimizing lookups
    private var songLookupCache: [String: MPMediaItem] = [:]
    
    init() {
        // Check current authorization status
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Request permission for the local library
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let currentStatus = MPMediaLibrary.authorizationStatus()
        
        if currentStatus == .authorized {
            // Already authorized
            DispatchQueue.main.async {
                self.hasAccess = true
                self.authorizationStatus = .authorized
                completion(true)
            }
        } else if currentStatus == .notDetermined {
            // Request authorization
            MPMediaLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    self?.hasAccess = status == .authorized
                    completion(status == .authorized)
                }
            }
        } else {
            // Permission denied
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                self.hasAccess = false
                completion(false)
            }
        }
    }
    
    /// Load all songs from the local music library
    func loadLibrary(completion: @escaping () -> Void) {
        guard hasAccess else {
            completion()
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let songsQuery = MPMediaQuery.songs()
            songsQuery.groupingType = .title
            
            var loadedSongs: [MPMediaItem] = []
            
            if let allSongs = songsQuery.items {
                loadedSongs = allSongs.sorted { song1, song2 in
                    if song1.playCount == song2.playCount {
                        return (song1.title ?? "") < (song2.title ?? "")
                    }
                    return song1.playCount > song2.playCount
                }
            }
            
            DispatchQueue.main.async {
                self?.songs = loadedSongs
                self?.buildSongLookupCache()
                self?.isLoading = false
                completion()
            }
        }
    }
    
    /// Build lookup cache for local songs to improve performance
    private func buildSongLookupCache() {
        songLookupCache.removeAll()
        
        for song in songs {
            guard let title = song.title, let artist = song.artist else { continue }
            
            let key = createSongKey(title: title, artist: artist, album: song.albumTitle ?? "")
            songLookupCache[key] = song
        }
    }
    
    /// Find a local song that matches the provided parameters
    func findLocalSong(title: String, artist: String, album: String) -> MPMediaItem? {
        let key = createSongKey(title: title, artist: artist, album: album)
        return songLookupCache[key]
    }
    
    /// Filter local songs by search text
    func filterSongs(containing searchText: String) -> [MPMediaItem] {
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                (song.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.artist?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.albumTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
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
