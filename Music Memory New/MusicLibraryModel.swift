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
                self?.isLoading = false
            }
        }
    }
    
    /// Search Apple Music catalog
    /// Search Apple Music catalog
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
            }
        } catch {
            print("Apple Music search error: \(error)")
            await MainActor.run {
                self.appleMusicSongs = []
                self.isSearchingAppleMusic = false
            }
        }
    }
    
    /// Clear Apple Music search results
    func clearAppleMusicSearch() {
        appleMusicSongs = []
    }
    
    /// Check if an Apple Music song is in the local library with more precise matching
    func isAppleMusicSongInLibrary(_ appleMusicSong: Song) -> Bool {
        guard hasAccess else { return false }
        
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
    
    /// Get the local library song that matches an Apple Music song
    func getLocalSongMatch(for appleMusicSong: Song) -> MPMediaItem? {
        guard hasAccess else { return nil }
        
        // First try for exact match including album and explicit status
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
        
        // Return exact match if found
        if let exactMatch = exactMatch {
            return exactMatch
        }
        
        // As a fallback, we could return a less precise match, but let's keep it strict
        return nil
    }
    
    /// Normalize strings for comparison (remove extra spaces, make lowercase, etc.)
    func normalizeString(_ string: String?) -> String {
        guard let string = string else { return "" }
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
