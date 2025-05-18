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
    func searchAppleMusic(query: String) async {
        guard hasAppleMusicAccess && !query.isEmpty else { return }
        
        await MainActor.run {
            self.isSearchingAppleMusic = true
        }
        
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            
            await MainActor.run {
                self.appleMusicSongs = Array(response.songs)
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
    
    /// Check if an Apple Music song is in the local library
    func isAppleMusicSongInLibrary(_ appleMusicSong: Song) -> Bool {
        guard hasAccess else { return false }
        
        return songs.contains { localSong in
            // Compare title and artist name with some tolerance for differences
            let titleMatch = normalizeString(localSong.title) == normalizeString(appleMusicSong.title)
            let artistMatch = normalizeString(localSong.artist) == normalizeString(appleMusicSong.artistName)
            
            return titleMatch && artistMatch
        }
    }
    
    /// Get the local library song that matches an Apple Music song
    func getLocalSongMatch(for appleMusicSong: Song) -> MPMediaItem? {
        guard hasAccess else { return nil }
        
        return songs.first { localSong in
            let titleMatch = normalizeString(localSong.title) == normalizeString(appleMusicSong.title)
            let artistMatch = normalizeString(localSong.artist) == normalizeString(appleMusicSong.artistName)
            
            return titleMatch && artistMatch
        }
    }
    
    /// Normalize strings for comparison (remove extra spaces, make lowercase, etc.)
    func normalizeString(_ string: String?) -> String {
        guard let string = string else { return "" }
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
