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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        if let self = self, self.isLoading {
                            print("DEBUG: Safety timeout triggered - forcing isLoading to false")
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    /// Search Apple Music catalog
    func searchAppleMusic(query: String) async {
        guard hasAppleMusicAccess && !query.isEmpty else { return }
        
        await MainActor.run {
            self.isSearchingAppleMusic = true
        }
        
        let searchResults = await appleMusicService.searchMusic(query: query)
        
        // Sort the results - prioritize songs in the library
        let sortedResults = searchResults.sorted { song1, song2 in
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
        
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.appleMusicSongs = sortedResults
            self.isSearchingAppleMusic = false
            self.precomputeSongInfo()
        }
    }
    
    /// Precompute song information to improve scrolling performance
    private func precomputeSongInfo() {
        Task { [weak self] in
            guard let self = self else { return }
            
            // Clear existing caches
            self.songLibraryStatus.removeAll()
            self.songPlayCounts.removeAll()
            
            // Create a local copy to avoid concurrent modification issues
            let songs = self.appleMusicSongs
            
            for song in songs {
                let key = self.createSongKey(title: song.title, artist: song.artistName, album: song.albumTitle ?? "")
                
                // Check if song is in library (expensive operation, so we cache it)
                let inLibrary = self.isAppleMusicSongInLibrary(song)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
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
        appleMusicService.clearSearch()
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
        
        // First try direct lookup - removed unused variable declaration
        if localLibrary.findLocalSong(title: appleMusicSong.title, artist: appleMusicSong.artistName, album: appleMusicSong.albumTitle ?? "") != nil {
            return true
        }
        
        // Fall back to full search if not in cache
        return localLibrary.songs.contains { localSong in
            // Basic matching (title and artist)
            let titleMatch = localLibrary.normalizeString(localSong.title) == localLibrary.normalizeString(appleMusicSong.title)
            let artistMatch = localLibrary.normalizeString(localSong.artist) == localLibrary.normalizeString(appleMusicSong.artistName)
            
            // Essential match (title + artist)
            let essentialMatch = titleMatch && artistMatch
            
            // Precise matching (album + explicit status)
            if let localAlbum = localSong.albumTitle, let appleMusicAlbum = appleMusicSong.albumTitle {
                let albumMatch = localLibrary.normalizeString(localAlbum) == localLibrary.normalizeString(appleMusicAlbum)
                
                // Match explicit status when available
                let explicitMatch = localSong.isExplicitItem == (appleMusicSong.contentRating == .explicit)
                
                // Return true only for exact matches
                return essentialMatch && albumMatch && explicitMatch
            }
            
            return false // Require album match for accurate results
        }
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
            guard titleMatch && artistMatch else { return false }
            
            // Check album match when available
            if let localAlbum = localSong.albumTitle, let appleMusicAlbum = appleMusicSong.albumTitle {
                let albumMatch = localLibrary.normalizeString(localAlbum) == localLibrary.normalizeString(appleMusicAlbum)
                
                // Match explicit status
                let explicitMatch = localSong.isExplicitItem == (appleMusicSong.contentRating == .explicit)
                
                return albumMatch && explicitMatch
            }
            
            return false
        }
    }
    
    /// Helper function to create a consistent key for a song
    func createSongKey(title: String, artist: String, album: String) -> String {
        return localLibrary.createSongKey(title: title, artist: artist, album: album)
    }
}
