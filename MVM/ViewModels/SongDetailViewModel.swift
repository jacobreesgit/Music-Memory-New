//
//  SongDetailViewModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer
import MusicKit
import Combine

class SongDetailViewModel: BaseViewModel {
    // MARK: - Types
    
    typealias State = ViewState<Content, Error>
    
    struct Content {
        let song: MPMediaItem
        let rank: Int
        var appleMusicSong: Song?
        var isSearchingAppleMusic: Bool = false
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var state: State = .loading
    
    // MARK: - Dependencies
    
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let appleMusicService: AppleMusicServiceProtocol
    
    // MARK: - Private Properties
    
    private let song: MPMediaItem
    private let rank: Int
    private var appleMusicSong: Song?
    private var isSearchingAppleMusic: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(song: MPMediaItem,
         rank: Int,
         musicLibraryService: MusicLibraryServiceProtocol,
         appleMusicService: AppleMusicServiceProtocol) {
        self.song = song
        self.rank = rank
        self.musicLibraryService = musicLibraryService
        self.appleMusicService = appleMusicService
        
        initialize()
    }
    
    // MARK: - BaseViewModel
    
    func initialize() {
        // Initialize with the current song data
        updateState()
        
        // Search for Apple Music information if appropriate
        if shouldSearchAppleMusic {
            fetchAppleMusicInfo()
        }
    }
    
    func cleanup() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Open the song in Apple Music if available
    func openInAppleMusic() {
        guard let appleMusicSong = appleMusicSong else { return }
        
        // Try to open the song directly in Apple Music using its URL
        if let url = appleMusicSong.url {
            UIApplication.shared.open(url)
        } else {
            // Fallback: open Apple Music app and search for the song
            let searchQuery = "\(appleMusicSong.title) \(appleMusicSong.artistName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchUrl = URL(string: "music://music.apple.com/search?term=\(searchQuery)") {
                UIApplication.shared.open(searchUrl)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determine the source text for the song
    var sourceText: String {
        if isUploadedToCloud {
            return "Uploaded to iCloud Music Library"
        } else if song.isCloudItem && song.hasProtectedAsset {
            return "Apple Music (DRM Protected)"
        } else if song.isCloudItem {
            return "iCloud Music Library"
        } else {
            return "Local Library"
        }
    }
    
    /// Check if this is an uploaded song to iCloud Music Library
    var isUploadedToCloud: Bool {
        // Uploaded songs are cloud items but don't have protected assets (no DRM)
        // They also typically don't have an asset URL
        return song.isCloudItem && !song.hasProtectedAsset && song.assetURL == nil
    }
    
    /// Check if we should search for this song on Apple Music
    var shouldSearchAppleMusic: Bool {
        // Don't search if:
        // 1. Song is uploaded to iCloud (user's own file)
        // 2. We don't have Apple Music access
        // 3. Song doesn't have basic required info
        guard !isUploadedToCloud,
              Task { await appleMusicService.hasAccess }.result.value ?? false,
              let _ = song.title,
              let _ = song.artist else {
            return false
        }
        return true
    }
    
    // MARK: - Private Methods
    
    /// Update the view state with current data
    private func updateState() {
        let content = Content(
            song: song,
            rank: rank,
            appleMusicSong: appleMusicSong,
            isSearchingAppleMusic: isSearchingAppleMusic
        )
        state = .content(content)
    }
    
    /// Search for song info in Apple Music
    private func fetchAppleMusicInfo() {
        guard shouldSearchAppleMusic,
              let title = song.title,
              let artist = song.artist else {
            return
        }
        
        // Update search state
        isSearchingAppleMusic = true
        updateState()
        
        Task {
            do {
                // Create multiple search queries with different combinations
                let searchQueries = [
                    "\(title) \(artist)",
                    title, // Sometimes artist name in the query can hurt results
                    "\"\(title)\" \(artist)" // Try with quotes for exact title match
                ]
                
                var foundMatch: Song?
                
                // Try each search query until we find a match
                for query in searchQueries {
                    if foundMatch != nil { break }
                    
                    let searchResults = try await appleMusicService.searchMusic(query: query, limit: 10)
                    foundMatch = findBestMatch(in: searchResults, title: title, artist: artist, album: song.albumTitle)
                    
                    if foundMatch != nil { break }
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.appleMusicSong = foundMatch
                    self.isSearchingAppleMusic = false
                    self.updateState()
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isSearchingAppleMusic = false
                    self.updateState()
                }
            }
        }
    }
    
    /// Find the best match for a song in Apple Music results
    private func findBestMatch(in songs: [Song], title: String, artist: String, album: String?) -> Song? {
        let normalizedTitle = normalizeForMatching(title)
        let normalizedArtist = normalizeForMatching(artist)
        let normalizedAlbum = album != nil ? normalizeForMatching(album!) : nil
        
        // Look for exact matches first
        for song in songs {
            let songTitle = normalizeForMatching(song.title)
            let songArtist = normalizeForMatching(song.artistName)
            
            // Exact title and artist match
            if songTitle == normalizedTitle && songArtist == normalizedArtist {
                return song
            }
        }
        
        // Look for fuzzy matches
        for song in songs {
            let songTitle = normalizeForMatching(song.title)
            let songArtist = normalizeForMatching(song.artistName)
            let songAlbum = song.albumTitle != nil ? normalizeForMatching(song.albumTitle!) : nil
            
            // Title must be very similar
            if AppHelpers.fuzzyMatch(songTitle, normalizedTitle) {
                // Artist should also match
                if AppHelpers.fuzzyMatch(songArtist, normalizedArtist) {
                    // If we have album info, use it to help with matching
                    if let normalizedAlbum = normalizedAlbum,
                       let songAlbum = songAlbum {
                        if AppHelpers.fuzzyMatch(songAlbum, normalizedAlbum) {
                            return song
                        }
                    } else {
                        // No album info, just use title and artist match
                        return song
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Normalize strings for matching
    private func normalizeForMatching(_ string: String) -> String {
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
}
