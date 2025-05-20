//
//  AppleMusicSongDetailViewModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer
import MusicKit
import Combine

class AppleMusicSongDetailViewModel: BaseViewModel {
    // MARK: - Types
    
    typealias State = ViewState<Content, Error>
    
    struct Content {
        let song: Song
        let rank: Int
        var isInLibrary: Bool = false
        var localSongMatch: MPMediaItem?
        var isLoading: Bool = true
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var state: State = .loading
    
    // MARK: - Dependencies
    
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let appleMusicService: AppleMusicServiceProtocol
    
    // MARK: - Private Properties
    
    private let song: Song
    private let rank: Int
    private var isInLibrary: Bool = false
    private var localSongMatch: MPMediaItem?
    private var isLoading: Bool = true
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(song: Song,
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
        // Initial state with loading indicator
        updateState()
        
        // Check library status
        checkLibraryStatus()
    }
    
    func cleanup() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Open the song in Apple Music
    func openInAppleMusic() {
        // Try to open the song directly in Apple Music using its URL
        if let url = song.url {
            UIApplication.shared.open(url) { success in
                if !success {
                    self.openAppleMusicFallback()
                }
            }
        } else {
            openAppleMusicFallback()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determine the source text for a local song
    func determineLocalSourceText(_ localSong: MPMediaItem) -> String {
        if localSong.isCloudItem && !localSong.hasProtectedAsset && localSong.assetURL == nil {
            return "Uploaded to iCloud Music Library"
        } else if localSong.isCloudItem && localSong.hasProtectedAsset {
            return "Apple Music (DRM Protected)"
        } else if localSong.isCloudItem {
            return "iCloud Music Library"
        } else {
            return "Local Library"
        }
    }
    
    // MARK: - Private Methods
    
    /// Update the view state with current data
    private func updateState() {
        let content = Content(
            song: song,
            rank: rank,
            isInLibrary: isInLibrary,
            localSongMatch: localSongMatch,
            isLoading: isLoading
        )
        state = .content(content)
    }
    
    /// Check if the song is in the local library
    private func checkLibraryStatus() {
        isLoading = true
        updateState()
        
        Task {
            do {
                // Check if we have access to the music library
                let hasAccess = await musicLibraryService.hasAccess
                
                if hasAccess {
                    // Try to find a match in the local library
                    let localMatch = try await musicLibraryService.findLocalSong(
                        title: song.title,
                        artist: song.artistName,
                        album: song.albumTitle ?? ""
                    )
                    
                    // Filter out uploaded songs from the match
                    let filteredMatch: MPMediaItem?
                    if let match = localMatch {
                        // Don't consider uploaded songs as "in library" for Apple Music purposes
                        let isUploaded = match.isCloudItem && !match.hasProtectedAsset && match.assetURL == nil
                        filteredMatch = isUploaded ? nil : match
                    } else {
                        filteredMatch = nil
                    }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.isInLibrary = filteredMatch != nil
                        self.localSongMatch = filteredMatch
                        self.isLoading = false
                        self.updateState()
                    }
                } else {
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.isInLibrary = false
                        self.localSongMatch = nil
                        self.isLoading = false
                        self.updateState()
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isInLibrary = false
                    self.localSongMatch = nil
                    self.isLoading = false
                    self.updateState()
                }
            }
        }
    }
    
    /// Fallback method to open Apple Music when direct URL fails
    private func openAppleMusicFallback() {
        // Fallback: open Apple Music app and search for the song
        let searchQuery = "\(song.title) \(song.artistName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try the music:// scheme first
        if let musicUrl = URL(string: "music://music.apple.com/search?term=\(searchQuery)") {
            UIApplication.shared.open(musicUrl) { success in
                if !success {
                    // If music:// doesn't work, try https://
                    if let httpsUrl = URL(string: "https://music.apple.com/search?term=\(searchQuery)") {
                        UIApplication.shared.open(httpsUrl)
                    }
                }
            }
        }
    }
}
