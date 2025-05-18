import SwiftUI
import MediaPlayer

/// Simplified model for accessing music library data
class MusicLibraryModel: ObservableObject {
    @Published var songs: [MPMediaItem] = []
    @Published var isLoading: Bool = false
    @Published var hasAccess: Bool = false
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    init() {
        // Check current authorization status
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Request permission and load the music library if authorized
    func requestPermissionAndLoadLibrary() {
        isLoading = true
        
        // Check current status first
        let currentStatus = MPMediaLibrary.authorizationStatus()
        
        if currentStatus == .authorized {
            // Already authorized, load library
            DispatchQueue.main.async {
                self.hasAccess = true
                self.authorizationStatus = .authorized
                self.loadLibrary()
            }
        } else if currentStatus == .notDetermined {
            // Request authorization
            MPMediaLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    self?.hasAccess = status == .authorized
                    
                    if status == .authorized {
                        self?.loadLibrary()
                    } else {
                        self?.isLoading = false
                    }
                }
            }
        } else {
            // Permission denied or restricted
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                self.hasAccess = false
                self.isLoading = false
            }
        }
    }
    
    /// Load all songs from the music library
    private func loadLibrary() {
        // Ensure we're on a background queue for the library query
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Get all songs from both local library and Apple Music
            let songsQuery = MPMediaQuery.songs()
            
            // Include both local and cloud items
            songsQuery.groupingType = .title
            
            var loadedSongs: [MPMediaItem] = []
            
            if let allSongs = songsQuery.items {
                // Sort by play count (highest first), then by title for songs with same play count
                loadedSongs = allSongs.sorted { song1, song2 in
                    if song1.playCount == song2.playCount {
                        return (song1.title ?? "") < (song2.title ?? "")
                    }
                    return song1.playCount > song2.playCount
                }
            }
            
            // Update UI on main queue
            DispatchQueue.main.async {
                self?.songs = loadedSongs
                self?.isLoading = false
            }
        }
    }
}
