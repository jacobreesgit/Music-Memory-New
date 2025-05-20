//
//  DependencyContainer.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation

/// Centralized dependency injection container
class DependencyContainer {
    static let shared = DependencyContainer()
    
    // MARK: - Services
    
    private(set) lazy var musicLibraryService: MusicLibraryServiceProtocol = MusicLibraryService()
    private(set) lazy var appleMusicService: AppleMusicServiceProtocol = AppleMusicService()
    private(set) lazy var networkMonitor: NetworkMonitorProtocol = NetworkMonitorService()
    
    // MARK: - ViewModel Factory Methods
    
    func makeSongsViewModel() -> SongsViewModel {
        return SongsViewModel(
            musicLibraryService: musicLibraryService,
            appleMusicService: appleMusicService,
            networkMonitor: networkMonitor
        )
    }
    
    func makeSongDetailViewModel(song: MPMediaItem, rank: Int) -> SongDetailViewModel {
        return SongDetailViewModel(
            song: song,
            rank: rank,
            musicLibraryService: musicLibraryService,
            appleMusicService: appleMusicService
        )
    }
    
    func makeAppleMusicSongDetailViewModel(song: Song, rank: Int) -> AppleMusicSongDetailViewModel {
        return AppleMusicSongDetailViewModel(
            song: song,
            rank: rank,
            musicLibraryService: musicLibraryService,
            appleMusicService: appleMusicService
        )
    }
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to ensure singleton pattern
    }
    
    // MARK: - Dependency Replacement (for testing)
    
    /// Replace the music library service (useful for testing)
    func setMusicLibraryService(_ service: MusicLibraryServiceProtocol) {
        musicLibraryService = service
    }
    
    /// Replace the Apple Music service (useful for testing)
    func setAppleMusicService(_ service: AppleMusicServiceProtocol) {
        appleMusicService = service
    }
    
    /// Replace the network monitor (useful for testing)
    func setNetworkMonitor(_ monitor: NetworkMonitorProtocol) {
        networkMonitor = monitor
    }
}
