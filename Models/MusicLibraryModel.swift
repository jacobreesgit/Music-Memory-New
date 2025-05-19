//
//  MusicLibraryModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

/// Enhanced model for accessing both local music library and Apple Music catalog
class MusicLibraryModel: ObservableObject {
    @Published var songs: [MPMediaItem] = []
    @Published var appleMusicSongs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var hasAccess: Bool = false
    @Published var hasAppleMusicAccess: Bool = false
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var appleMusicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isSearchingAppleMusic: Bool = false
    
    // Cache dictionaries for improving performance
    private var songLibraryStatus: [String: Bool] = [:]
    private var songPlayCounts: [String: Int] = [:]
    private var localSongMatches: [String: MPMediaItem] = [:]
    
    init() {
        // Check current authorization status for both MediaPlayer and MusicKit
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        hasAccess = authorizationStatus == .authorized
        
        // Check Apple Music authorization
        appleMusicAuthorizationStatus = MusicAuthorization.currentStatus
        hasAppleMusicAccess = appleMusicAuthorizationStatus == .authorized
    }
    
    /// Request permission for both local library and Apple Music
    func requestPermissionAndLoadLibrary() {
        isLoading = true
        
        // First, request MediaPlayer permission (for local library)
        let currentStatus = MPMediaLibrary.authorizationStatus()
        
        if currentStatus == .authorized {
            // Already authorized for local library
            DispatchQueue.main.async {
                self.hasAccess = true
                self.authorizationStatus = .authorized
                self.loadLibrary()
                self.requestAppleMusicPermission()
            }
        } else if currentStatus == .notDetermined {
            // Request local library authorization
            MPMediaLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    self?.hasAccess = status == .authorized
                    
                    if status == .authorized {
                        self?.loadLibrary()
                    }
                    self?.requestAppleMusicPermission()
                }
            }
        } else {
            // Permission denied for local library, still try Apple Music
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                self.hasAccess = false
                self.requestAppleMusicPermission()
            }
        }
    }
    
    /// Request Apple Music permission
    private func requestAppleMusicPermission() {
        Task {
            let status = await MusicAuthorization.request()
            
            await MainActor.run {
                self.appleMusicAuthorizationStatus = status
                self.hasAppleMusicAccess = status == .authorized
                
                if !self.hasAccess && !self.hasAppleMusicAccess {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Load all songs from the local music library
    private func loadLibrary() {
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
            }
        }
    }
    
    /// Build lookup cache for local songs to improve performance
    private func buildSongLookupCache() {
        for song in songs {
            guard let title = song.title, let artist = song.artist else { continue }
            
            let key = createSongKey(title: title, artist: artist, album: song.albumTitle ?? "")
            localSongMatches[key] = song
        }
    }
    
    /// Helper function to create a consistent key for a song
    func createSongKey(title: String, artist: String, album: String) -> String {
        return "\(normalizeString(title))|\(normalizeString(artist))|\(normalizeString(album))"
    }
    
    /// Search Apple Music catalog with improved caching
    func searchAppleMusic(query: String) async {
        guard hasAppleMusicAccess && !query.isEmpty else { return }
        
        await MainActor.run {
            self.isSearchingAppleMusic = true
        }
        
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            
            // Get the songs array
            let searchResults = Array(response.songs)
            
            // Create a dictionary to store unique songs by a composite key
            var uniqueSongs: [String: Song] = [:]
            
            // Deduplicate songs based on title, artist, and album
            for song in searchResults {
                let key = "\(normalizeString(song.title))|\(normalizeString(song.artistName))|\(normalizeString(song.albumTitle ?? ""))"
                
                // If we already have this song and it's in library, prefer the one in library
                if let existingSong = uniqueSongs[key] {
                    let existingInLibrary = isAppleMusicSongInLibrary(existingSong)
                    let newInLibrary = isAppleMusicSongInLibrary(song)
                    
                    // Only replace if new song is in library and existing is not
                    if newInLibrary && !existingInLibrary {
                        uniqueSongs[key] = song
                    }
                } else {
                    // First time seeing this song
                    uniqueSongs[key] = song
                }
            }
            
            // Convert back to array
            let uniqueResults = Array(uniqueSongs.values)
            
            // Sort the results - prioritize songs in the library
            let sortedResults = uniqueResults.sorted { song1, song2 in
                let song1InLibrary = isAppleMusicSongInLibrary(song1)
                let song2InLibrary = isAppleMusicSongInLibrary(song2)
                
                // First priority: Songs in library come first
                if song1InLibrary && !song2InLibrary {
                    return true
                } else if !song1InLibrary && song2InLibrary {
                    return false
                }
                
                // Second priority: For songs in library, sort by play count
                if song1InLibrary && song2InLibrary {
                    let song1PlayCount = getLocalSongMatch(for: song1)?.playCount ?? 0
                    let song2PlayCount = getLocalSongMatch(for: song2)?.playCount ?? 0
                    
                    if song1PlayCount != song2PlayCount {
                        return song1PlayCount > song2PlayCount
                    }
                }
                
                // Third priority: Sort by title relevance to query
                let titleRelevance1 = song1.title.lowercased().contains(query.lowercased())
                let titleRelevance2 = song2.title.lowercased().contains(query.lowercased())
                
                if titleRelevance1 && !titleRelevance2 {
                    return true
                } else if !titleRelevance1 && titleRelevance2 {
                    return false
                }
                
                // Default to the original title order
                return song1.title < song2.title
            }
            
            await MainActor.run {
                self.appleMusicSongs = sortedResults
                self.isSearchingAppleMusic = false
                self.precomputeSongInfo()
            }
        } catch {
            print("Apple Music search error: \(error)")
            await MainActor.run {
                self.appleMusicSongs = []
                self.isSearchingAppleMusic = false
            }
        }
    }
    
    /// Precompute song information to improve scrolling performance
    private func precomputeSongInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Clear existing caches
            self.songLibraryStatus.removeAll()
            self.songPlayCounts.removeAll()
            
            // Precompute status for all search results
            for song in self.appleMusicSongs {
                let key = self.createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
                
                // Check if song is in library (expensive operation, so we cache it)
                let inLibrary = self.isAppleMusicSongInLibrary(song)
                
                DispatchQueue.main.async {
                    // Update caches on main thread to avoid concurrency issues
                    self.songLibraryStatus[key] = inLibrary
                    
                    // If in library, cache the play count as well
                    if inLibrary, let localSong = self.getLocalSongMatch(for: song) {
                        self.songPlayCounts[key] = localSong.playCount
                    }
                }
            }
        }
    }
    
    /// Clear Apple Music search results and caches
    func clearAppleMusicSearch() {
        appleMusicSongs = []
        songLibraryStatus.removeAll()
        songPlayCounts.removeAll()
    }
    
    /// Efficiently check if a song is in the library using cache
    func isSongInLibrary(_ song: Song) -> Bool {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        
        // Check cache first
        if let status = songLibraryStatus[key] {
            return status
        }
        
        // If not in cache, compute and cache for next time
        let status = isAppleMusicSongInLibrary(song)
        songLibraryStatus[key] = status
        return status
    }
    
    /// Get cached play count for a song
    func getPlayCount(for song: Song) -> Int? {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        return songPlayCounts[key]
    }
    
    /// Check if an Apple Music song is in the local library with more precise matching
    func isAppleMusicSongInLibrary(_ appleMusicSong: Song) -> Bool {
        guard hasAccess else { return false }
        
        // First try the cache lookup
        let key = createSongKey(title: appleMusicSong.title, artist: appleMusicSong.artistName, album: appleMusicSong.albumTitle ?? "")
        if let cachedMatch = localSongMatches[key] {
            return true
        }
        
        // Fall back to full search if not in cache
        return songs.contains { localSong in
            // Basic matching (title and artist)
            let titleMatch = normalizeString(localSong.title) == normalizeString(appleMusicSong.title)
            let artistMatch = normalizeString(localSong.artist) == normalizeString(appleMusicSong.artistName)
            
            // Essential match (title + artist)
            let essentialMatch = titleMatch && artistMatch
            
            // Precise matching (album + explicit status)
            if let localAlbum = localSong.albumTitle, let appleMusicAlbum = appleMusicSong.albumTitle {
                let albumMatch = normalizeString(localAlbum) == normalizeString(appleMusicAlbum)
                
                // Match explicit status when available
                let explicitMatch = localSong.isExplicitItem == (appleMusicSong.contentRating == .explicit)
                
                // Return true only for exact matches
                return essentialMatch && albumMatch && explicitMatch
            }
            
            return false // Require album match for accurate results
        }
    }
    
    /// Get the local library song that matches an Apple Music song, using cache when possible
    func getLocalSongMatch(for appleMusicSong: Song) -> MPMediaItem? {
        guard hasAccess else { return nil }
        
        // Try cache lookup first for better performance
        let key = createSongKey(title: appleMusicSong.title, artist: appleMusicSong.artistName, album: appleMusicSong.albumTitle ?? "")
        if let cachedMatch = localSongMatches[key] {
            return cachedMatch
        }
        
        // Fall back to full search if not in cache
        let exactMatch = songs.first { localSong in
            let titleMatch = normalizeString(localSong.title) == normalizeString(appleMusicSong.title)
            let artistMatch = normalizeString(localSong.artist) == normalizeString(appleMusicSong.artistName)
            
            // Only proceed if title and artist match
            guard titleMatch && artistMatch else { return false }
            
            // Check album match when available
            if let localAlbum = localSong.albumTitle, let appleMusicAlbum = appleMusicSong.albumTitle {
                let albumMatch = normalizeString(localAlbum) == normalizeString(appleMusicAlbum)
                
                // Match explicit status
                let explicitMatch = localSong.isExplicitItem == (appleMusicSong.contentRating == .explicit)
                
                return albumMatch && explicitMatch
            }
            
            return false
        }
        
        // Cache the result for future lookups
        if let match = exactMatch {
            localSongMatches[key] = match
        }
        
        return exactMatch
    }
    
    /// Normalize strings for comparison (remove extra spaces, make lowercase, etc.)
    func normalizeString(_ string: String?) -> String {
        guard let string = string else { return "" }
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
