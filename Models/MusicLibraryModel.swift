//
//  MusicLibraryModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

/// Facade that coordinates the Local Music Library and Apple Music services
class MusicLibraryModel: ObservableObject {
    // Services
    private let localLibrary = LocalMusicLibrary()
    private let appleMusicService = AppleMusicService()
    
    // Published properties for UI binding
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
    
    // Search performance optimization
    private var searchCache: [String: [MPMediaItem]] = [:]
    private var currentSearchTask: Task<Void, Never>?
    private var lastSearchText = ""
    
    init() {
        // Initialize from the services
        self.authorizationStatus = localLibrary.authorizationStatus
        self.hasAccess = localLibrary.hasAccess
        self.appleMusicAuthorizationStatus = appleMusicService.authorizationStatus
        self.hasAppleMusicAccess = appleMusicService.hasAccess
    }
    
    /// Request permission for both local library and Apple Music
    func requestPermissionAndLoadLibrary() {
        print("DEBUG: Starting permission request and library load")
        isLoading = true
        
        // First handle local library permissions
        localLibrary.requestPermission { [weak self] success in
            guard let self = self else {
                print("DEBUG: Self is nil in permission completion")
                return
            }
            
            print("DEBUG: Local library permission result: \(success)")
            self.hasAccess = success
            self.authorizationStatus = self.localLibrary.authorizationStatus
            
            // Create a helper function to check if we're done loading
            let checkLoadingComplete = { [weak self] in
                guard let self = self else { return }
                
                // If we've fetched the local library songs OR we don't have access to local library
                // AND we've determined Apple Music access (not .notDetermined)
                if (self.songs.count > 0 || !self.hasAccess) &&
                   self.appleMusicAuthorizationStatus != .notDetermined {
                    print("DEBUG: Setting isLoading to false in checkLoadingComplete")
                    self.isLoading = false
                    
                    // Build index for search
                    self.buildSearchIndex()
                }
            }
            
            if success {
                print("DEBUG: Loading local library")
                self.localLibrary.loadLibrary { [weak self] in
                    guard let self = self else {
                        print("DEBUG: Self is nil in loadLibrary completion")
                        return
                    }
                    print("DEBUG: Library loaded with \(self.localLibrary.songs.count) songs")
                    self.songs = self.localLibrary.songs
                    checkLoadingComplete()
                }
            } else {
                // If no local library access, we don't need to wait for library loading
                print("DEBUG: No local library access, checking if loading is complete")
                checkLoadingComplete()
            }
            
            // Then handle Apple Music permissions
            Task { [weak self] in
                guard let self = self else { return }
                print("DEBUG: Requesting Apple Music permission")
                let appleMusicSuccess = await self.appleMusicService.requestPermission()
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    print("DEBUG: Apple Music permission result: \(appleMusicSuccess)")
                    self.hasAppleMusicAccess = appleMusicSuccess
                    self.appleMusicAuthorizationStatus = self.appleMusicService.authorizationStatus
                    
                    // Check again if we're done loading
                    checkLoadingComplete()
                    
                    // Extra safety to prevent endless loading if something goes wrong
                    DispatchQueue.main.asyncAfter(deadline: .now() + Theme.TimeIntervals.safetyTimeout) { [weak self] in
                        if let self = self, self.isLoading {
                            print("DEBUG: Safety timeout triggered - forcing isLoading to false")
                            self.isLoading = false
                            
                            // Build index for search even in timeout case
                            self.buildSearchIndex()
                        }
                    }
                }
            }
        }
    }
    
    /// Build search index for faster local filtering
    private func buildSearchIndex() {
        // Clear existing cache
        searchCache.removeAll()
        
        // Pre-calculate common search terms
        Task(priority: .background) {
            // Index by first letter for faster filtering
            let alphabet = "abcdefghijklmnopqrstuvwxyz"
            for letter in alphabet {
                let letterStr = String(letter)
                let filtered = self.songs.filter { song in
                    AppHelpers.quickMatch(song.title, letterStr) ||
                    AppHelpers.quickMatch(song.artist, letterStr) ||
                    AppHelpers.quickMatch(song.albumTitle, letterStr)
                }
                await MainActor.run {
                    self.searchCache[letterStr] = filtered
                }
            }
        }
    }
    
    /// Get cached filtered songs for a search query
    func cachedFilteredSongs(for searchText: String) -> [MPMediaItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedSearch.isEmpty {
            return songs
        }
        
        // Check cache first
        if let cachedResults = searchCache[trimmedSearch] {
            return cachedResults
        }
        
        // If not in cache, filter songs and store in cache
        // Use quick match first for better performance
        let filtered = songs.filter { song in
            // Use faster matching algorithm
            AppHelpers.quickMatch(song.title, trimmedSearch) ||
            AppHelpers.quickMatch(song.artist, trimmedSearch) ||
            AppHelpers.quickMatch(song.albumTitle, trimmedSearch)
        }
        
        // Cache results for reuse
        if filtered.count > 0 || trimmedSearch.count > 2 {
            searchCache[trimmedSearch] = filtered
        }
        
        return filtered
    }
    
    /// Search Apple Music catalog with optimized performance
    func searchAppleMusic(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasAppleMusicAccess && !trimmedQuery.isEmpty else { return }
        
        // Cancel any previous search task
        currentSearchTask?.cancel()
        
        await MainActor.run {
            self.isSearchingAppleMusic = true
            self.lastSearchText = trimmedQuery
        }
        
        // Create a new task for this search
        let task = Task {
            // Add a slight delay to prioritize UI responsiveness
            try? await Task.sleep(nanoseconds: Theme.TimeIntervals.searchDebounce)
            
            // Check if task is cancelled
            if Task.isCancelled { return }
            
            // Limit search to 15 results instead of 25 for faster response
            let searchResults = await appleMusicService.searchMusic(query: trimmedQuery, limit: 15)
            
            // Check if task is cancelled or if search query has changed
            if Task.isCancelled { return }
            
            await MainActor.run { [weak self] in
                guard let self = self, self.lastSearchText == trimmedQuery else { return }
                
                // Process and sort the results - prioritize songs in the library
                let sortedResults = self.processSortedResults(searchResults, query: trimmedQuery)
                self.appleMusicSongs = sortedResults
                self.isSearchingAppleMusic = false
                
                // Move precomputing to background
                Task(priority: .background) {
                    self.precomputeSongInfo(for: sortedResults)
                }
            }
        }
        
        currentSearchTask = task
    }
    
    /// Process and sort Apple Music search results
    private func processSortedResults(_ searchResults: [Song], query: String) -> [Song] {
        // Filter out any songs that already fully match songs in the library
        // This improves performance by reducing duplicate processing
        let filteredResults = searchResults.filter { song in
            // Check if this exact song is in the library (by ISRC or exact matching)
            if let localMatch = getExactLocalSongMatch(for: song) {
                // Update the cache while we're here
                let key = self.createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
                songLibraryStatus[key] = true
                songPlayCounts[key] = localMatch.playCount
                
                // Keep songs that are in the library
                return true
            }
            return true
        }
        
        // Sort the results with a faster algorithm
        return filteredResults.sorted { song1, song2 in
            // First priority: Songs in library come first (use cached status when available)
            let song1InLibrary = isSongInLibraryFast(song1)
            let song2InLibrary = isSongInLibraryFast(song2)
            
            if song1InLibrary && !song2InLibrary {
                return true
            } else if !song1InLibrary && song2InLibrary {
                return false
            }
            
            // Second priority: For songs in library, sort by play count
            if song1InLibrary && song2InLibrary {
                let song1PlayCount = getCachedPlayCount(for: song1) ?? 0
                let song2PlayCount = getCachedPlayCount(for: song2) ?? 0
                
                if song1PlayCount != song2PlayCount {
                    return song1PlayCount > song2PlayCount
                }
            }
            
            // Third priority: Title relevance to query
            let titleRelevance1 = AppHelpers.quickMatch(song1.title, query)
            let titleRelevance2 = AppHelpers.quickMatch(song2.title, query)
            
            if titleRelevance1 && !titleRelevance2 {
                return true
            } else if !titleRelevance1 && titleRelevance2 {
                return false
            }
            
            // Default to title ordering
            return song1.title < song2.title
        }
    }
    
    /// Efficient way to check if a song is in library using cache
    private func isSongInLibraryFast(_ song: Song) -> Bool {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        
        // Check cache first for performance
        if let status = songLibraryStatus[key] {
            return status
        }
        
        // Use direct lookup if possible (faster)
        if let _ = localLibrary.findLocalSong(title: song.title, artist: song.artistName, album: song.albumTitle ?? "") {
            songLibraryStatus[key] = true
            return true
        }
        
        // Not found in fast lookup
        songLibraryStatus[key] = false
        return false
    }
    
    /// Get cached play count
    private func getCachedPlayCount(for song: Song) -> Int? {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        return songPlayCounts[key]
    }
    
    /// Clear all search caches and results
    func clearAllSearches() {
        // Cancel any pending search
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Clear Apple Music results
        appleMusicService.clearSearch()
        appleMusicSongs = []
        
        // Clear transient caches
        lastSearchText = ""
        isSearchingAppleMusic = false
    }
    
    /// Clear Apple Music search results and caches
    func clearAppleMusicSearch() {
        // Cancel any pending search
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Clear Apple Music results
        appleMusicService.clearSearch()
        appleMusicSongs = []
        
        // Clear Apple Music search state
        lastSearchText = ""
        isSearchingAppleMusic = false
    }
    
    /// Precompute song information to improve scrolling performance
    private func precomputeSongInfo(for songs: [Song]) {
        // Only compute for new songs that aren't already cached
        let songsToProcess = songs.filter { song in
            let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
            return songLibraryStatus[key] == nil
        }
        
        // Process in batches for better performance
        let batchSize = 5
        for i in stride(from: 0, to: songsToProcess.count, by: batchSize) {
            let end = min(i + batchSize, songsToProcess.count)
            let batch = Array(songsToProcess[i..<end])
            
            for song in batch {
                let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
                
                // Check if song is in library (expensive operation, so we cache it)
                let inLibrary = isAppleMusicSongInLibrary(song)
                songLibraryStatus[key] = inLibrary
                
                // If in library, cache the play count as well
                if inLibrary, let localSong = getLocalSongMatch(for: song) {
                    songPlayCounts[key] = localSong.playCount
                }
            }
        }
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
    
    /// Check if an Apple Music song is in the local library with optimized matching
    func isAppleMusicSongInLibrary(_ appleMusicSong: Song) -> Bool {
        guard hasAccess else { return false }
        
        // First try direct lookup for best performance
        if let _ = localLibrary.findLocalSong(
            title: appleMusicSong.title,
            artist: appleMusicSong.artistName,
            album: appleMusicSong.albumTitle ?? ""
        ) {
            return true
        }
        
        // Try with exact match (faster than full search) using ISRC if available
        if let exactMatch = getExactLocalSongMatch(for: appleMusicSong) {
            return true
        }
        
        // Last resort: full search (most expensive)
        return false
    }
    
    /// Get exact match using ISRC or other identifiers
    private func getExactLocalSongMatch(for appleMusicSong: Song) -> MPMediaItem? {
        // Use ISRC for exact matching if available
        if let isrc = appleMusicSong.isrc {
            // This would require adding ISRC indexing to LocalMusicLibrary
            // For now, we'll skip this optimization
        }
        
        // Direct lookup
        return localLibrary.findLocalSong(
            title: appleMusicSong.title,
            artist: appleMusicSong.artistName,
            album: appleMusicSong.albumTitle ?? ""
        )
    }
    
    /// Get the local library song that matches an Apple Music song
    func getLocalSongMatch(for appleMusicSong: Song) -> MPMediaItem? {
        guard hasAccess else { return nil }
        
        // Try direct lookup first for better performance
        let match = localLibrary.findLocalSong(
            title: appleMusicSong.title,
            artist: appleMusicSong.artistName,
            album: appleMusicSong.albumTitle ?? ""
        )
        
        if match != nil {
            return match
        }
        
        // Fall back to full search if not in cache
        return localLibrary.songs.first { localSong in
            let titleMatch = localLibrary.normalizeString(localSong.title) == localLibrary.normalizeString(appleMusicSong.title)
            let artistMatch = localLibrary.normalizeString(localSong.artist) == localLibrary.normalizeString(appleMusicSong.artistName)
            
            // Only proceed if title and artist match
            return titleMatch && artistMatch
        }
    }
    
    /// Helper function to create a consistent key for a song
    func createSongKey(title: String, artist: String, album: String) -> String {
        return localLibrary.createSongKey(title: title, artist: artist, album: album)
    }
}
