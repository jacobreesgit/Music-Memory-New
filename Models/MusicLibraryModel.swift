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
@MainActor
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
        // Initialize with default values, we'll fetch actual values in loadInitialData
        Task {
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        // Get current authorization statuses
        self.authorizationStatus = await localLibrary.authorizationStatus
        self.hasAccess = await localLibrary.hasAccess
        self.appleMusicAuthorizationStatus = await appleMusicService.authorizationStatus
        self.hasAppleMusicAccess = await appleMusicService.hasAccess
    }
    
    /// Request permission for both local library and Apple Music
    func requestPermissionAndLoadLibrary() {
        print("DEBUG: Starting permission request and library load")
        isLoading = true
        
        Task {
            // First handle local library permissions
            do {
                let success = try await localLibrary.requestPermission()
                
                print("DEBUG: Local library permission result: \(success)")
                self.hasAccess = success
                self.authorizationStatus = await localLibrary.authorizationStatus
                
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
                    do {
                        let loadedSongs = try await localLibrary.loadLibrary()
                        print("DEBUG: Library loaded with \(loadedSongs.count) songs")
                        self.songs = loadedSongs
                        checkLoadingComplete()
                    } catch {
                        print("DEBUG: Failed to load library: \(error)")
                        checkLoadingComplete()
                    }
                } else {
                    // If no local library access, we don't need to wait for library loading
                    print("DEBUG: No local library access, checking if loading is complete")
                    checkLoadingComplete()
                }
                
                // Then handle Apple Music permissions
                do {
                    print("DEBUG: Requesting Apple Music permission")
                    let appleMusicSuccess = try await appleMusicService.requestPermission()
                    
                    print("DEBUG: Apple Music permission result: \(appleMusicSuccess)")
                    self.hasAppleMusicAccess = appleMusicSuccess
                    self.appleMusicAuthorizationStatus = await appleMusicService.authorizationStatus
                    
                    // Check again if we're done loading
                    checkLoadingComplete()
                } catch {
                    print("DEBUG: Apple Music permission error: \(error)")
                    checkLoadingComplete()
                }
                
                // Extra safety to prevent endless loading if something goes wrong
                DispatchQueue.main.asyncAfter(deadline: .now() + Theme.TimeIntervals.safetyTimeout) { [weak self] in
                    if let self = self, self.isLoading {
                        print("DEBUG: Safety timeout triggered - forcing isLoading to false")
                        self.isLoading = false
                        
                        // Build index for search even in timeout case
                        self.buildSearchIndex()
                    }
                }
            } catch {
                print("DEBUG: Permission request error: \(error)")
                self.isLoading = false
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
            do {
                let searchResults = try await appleMusicService.searchMusic(query: trimmedQuery, limit: 15)
                
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
                        await self.precomputeSongInfo(for: sortedResults)
                    }
                }
            } catch {
                print("DEBUG: Apple Music search error: \(error)")
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isSearchingAppleMusic = false
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
            Task {
                if let localMatch = try? await getExactLocalSongMatch(for: song) {
                    // Update the cache while we're here
                    let key = self.createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
                    songLibraryStatus[key] = true
                    songPlayCounts[key] = localMatch.playCount
                }
            }
            
            // Keep songs that are in the library
            return true
        }
        
        // Sort the results with a faster algorithm
        return filteredResults.sorted { song1, song2 in
            // First priority: Songs in library come first (use cached status when available)
            let song1InLibrary = songLibraryStatus[createSongKey(title: song1.title, artist: song1.artistName, album: song1.albumTitle ?? "")] ?? false
            let song2InLibrary = songLibraryStatus[createSongKey(title: song2.title, artist: song2.artistName, album: song2.albumTitle ?? "")] ?? false
            
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
        
        // Mark as not found initially, will be updated asynchronously
        songLibraryStatus[key] = false
        
        // Queue up a task to update the actual status
        Task {
            do {
                if let _ = try await localLibrary.findLocalSong(title: song.title, artist: song.artistName, album: song.albumTitle ?? "") {
                    await MainActor.run {
                        songLibraryStatus[key] = true
                    }
                    return true
                }
            } catch {
                print("DEBUG: Error checking if song is in library: \(error)")
            }
            return false
        }
        
        return false
    }
    
    /// Get cached play count
    private func getCachedPlayCount(for song: Song) -> Int? {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        return songPlayCounts[key]
    }
    
    /// Clear all search caches and results
    func clearAllSearches() async {
        // Cancel any pending search
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Clear Apple Music results
        await appleMusicService.clearSearch()
        
        await MainActor.run {
            self.appleMusicSongs = []
            
            // Clear transient caches
            self.lastSearchText = ""
            self.isSearchingAppleMusic = false
        }
    }
    
    /// Clear Apple Music search results and caches
    func clearAppleMusicSearch() async {
        // Cancel any pending search
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Clear Apple Music results
        await appleMusicService.clearSearch()
        
        await MainActor.run {
            self.appleMusicSongs = []
            
            // Clear Apple Music search state
            self.lastSearchText = ""
            self.isSearchingAppleMusic = false
        }
    }
    
    /// Precompute song information to improve scrolling performance
    private func precomputeSongInfo(for songs: [Song]) async {
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
                let inLibrary = await isAppleMusicSongInLibrary(song)
                
                await MainActor.run {
                    self.songLibraryStatus[key] = inLibrary
                }
                
                // If in library, cache the play count as well
                if inLibrary, let localSong = try? await getLocalSongMatch(for: song) {
                    await MainActor.run {
                        self.songPlayCounts[key] = localSong.playCount
                    }
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
        
        // If not in cache, mark as not found initially and update asynchronously
        songLibraryStatus[key] = false
        
        Task {
            let status = await isAppleMusicSongInLibrary(song)
            await MainActor.run {
                self.songLibraryStatus[key] = status
            }
        }
        
        return false
    }
    
    /// Get cached play count for a song
    func getPlayCount(for song: Song) -> Int? {
        let key = createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
        return songPlayCounts[key]
    }
    
    /// Check if an Apple Music song is in the local library with optimized matching
    func isAppleMusicSongInLibrary(_ appleMusicSong: Song) async -> Bool {
        guard hasAccess else { return false }
        
        // First try direct lookup for best performance
        do {
            if let _ = try await localLibrary.findLocalSong(
                title: appleMusicSong.title,
                artist: appleMusicSong.artistName,
                album: appleMusicSong.albumTitle ?? ""
            ) {
                return true
            }
            
            // Try with exact match (faster than full search) using ISRC if available
            if let exactMatch = try await getExactLocalSongMatch(for: appleMusicSong) {
                return true
            }
        } catch {
            print("DEBUG: Error checking if Apple Music song is in library: \(error)")
        }
        
        // Not found
        return false
    }
    
    /// Get exact match using ISRC or other identifiers
    private func getExactLocalSongMatch(for appleMusicSong: Song) async throws -> MPMediaItem? {
        // Use ISRC for exact matching if available
        if let isrc = appleMusicSong.isrc {
            // This would require adding ISRC indexing to LocalMusicLibrary
            // For now, we'll skip this optimization
        }
        
        // Direct lookup
        return try await localLibrary.findLocalSong(
            title: appleMusicSong.title,
            artist: appleMusicSong.artistName,
            album: appleMusicSong.albumTitle ?? ""
        )
    }
    
    /// Get the local library song that matches an Apple Music song
    func getLocalSongMatch(for appleMusicSong: Song) async throws -> MPMediaItem? {
        guard hasAccess else { return nil }
        
        // Try direct lookup first for better performance
        let match = try await localLibrary.findLocalSong(
            title: appleMusicSong.title,
            artist: appleMusicSong.artistName,
            album: appleMusicSong.albumTitle ?? ""
        )
        
        if match != nil {
            return match
        }
        
        // Fall back to full search if not in cache
        let songs = await localLibrary.songs
        let normalizedTitle = try await localLibrary.normalizeString(appleMusicSong.title)
        let normalizedArtistName = try await localLibrary.normalizeString(appleMusicSong.artistName)
        
        for localSong in songs {
            let localTitle = try await localLibrary.normalizeString(localSong.title)
            let localArtist = try await localLibrary.normalizeString(localSong.artist)
            
            if localTitle == normalizedTitle && localArtist == normalizedArtistName {
                return localSong
            }
        }
        
        return nil
    }
    
    /// Helper function to create a consistent key for a song
    func createSongKey(title: String, artist: String, album: String) -> String {
        // Create a simplified version since we can't call the actor method directly
        return "\(title.lowercased())|\(artist.lowercased())|\(album.lowercased())"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
