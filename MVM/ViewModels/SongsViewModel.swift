//
//  SongsViewModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//


//
//  SongsViewModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MediaPlayer
import MusicKit
import Combine

class SongsViewModel: BaseViewModel {
    // MARK: - Types
    
    typealias State = ViewState<Content, Error>
    
    struct Content {
        var songs: [MPMediaItem] = []
        var appleMusicSongs: [Song] = []
        var combinedResults: [SearchResult] = []
        var isActiveSearch: Bool = false
    }
    
    enum SortField: String, CaseIterable, Equatable {
        case playCount = "Play Count"
        case title = "Title"
        
        var systemImage: String {
            switch self {
            case .playCount:
                return "play.circle"
            case .title:
                return "textformat.abc"
            }
        }
    }
    
    enum SortDirection: String, Equatable {
        case ascending = "asc"
        case descending = "desc"
        
        var chevronImage: String {
            switch self {
            case .ascending:
                return "chevron.up"
            case .descending:
                return "chevron.down"
            }
        }
        
        mutating func toggle() {
            self = self == .ascending ? .descending : .ascending
        }
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var state: State = .loading
    @Published var searchText: String = ""
    @Published var sortField: SortField = .playCount
    @Published var sortDirection: SortDirection = .descending
    
    // MARK: - Dependencies
    
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let appleMusicService: AppleMusicServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Private Properties
    
    private var songs: [MPMediaItem] = []
    private var appleMusicSongs: [Song] = []
    private var combinedResults: [SearchResult] = []
    private var isActiveSearch: Bool = false
    private var currentSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(musicLibraryService: MusicLibraryServiceProtocol, 
         appleMusicService: AppleMusicServiceProtocol,
         networkMonitor: NetworkMonitorProtocol) {
        self.musicLibraryService = musicLibraryService
        self.appleMusicService = appleMusicService
        self.networkMonitor = networkMonitor
        
        initialize()
    }
    
    // MARK: - BaseViewModel
    
    func initialize() {
        Task {
            await loadLibrary()
        }
    }
    
    func cleanup() {
        currentSearchTask?.cancel()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Load the music library
    func loadLibrary() async {
        await MainActor.run {
            self.state = .loading
        }
        
        do {
            // Check if we have access and request if needed
            if !(await musicLibraryService.hasAccess) {
                _ = try await musicLibraryService.requestPermission()
            }
            
            self.songs = try await musicLibraryService.loadLibrary()
            
            await MainActor.run {
                let content = Content(
                    songs: self.songs,
                    appleMusicSongs: self.appleMusicSongs,
                    combinedResults: self.combinedResults,
                    isActiveSearch: self.isActiveSearch
                )
                self.state = .content(content)
            }
        } catch {
            await MainActor.run {
                self.state = .error(error)
            }
        }
    }
    
    /// Submit a search when the user presses return
    func submitSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            isActiveSearch = false
            combinedResults = []
            updateState()
            return
        }
        
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        // Show loading state
        state = .loading
        isActiveSearch = true
        
        currentSearchTask = Task {
            // Perform search in background
            do {
                // First search local library
                let localMatches = musicLibraryService.filterSongs(containing: trimmedQuery)
                var appleMusicResults: [Song] = []
                
                // Then search Apple Music if connected
                if await appleMusicService.hasAccess && networkMonitor.isConnected {
                    do {
                        appleMusicResults = try await appleMusicService.searchMusic(query: trimmedQuery, limit: 15)
                    } catch {
                        print("Apple Music search failed: \(error.localizedDescription)")
                        // Continue with local results only
                    }
                }
                
                // Process and combine results
                let combined = await processAndCombineResults(
                    localMatches: localMatches,
                    appleMusicSongs: appleMusicResults
                )
                
                // Update state on main thread
                await MainActor.run { [weak self] in
                    guard let self = self, !Task.isCancelled else { return }
                    
                    self.combinedResults = combined
                    self.updateState()
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.state = .error(error)
                    }
                }
            }
        }
    }
    
    /// Clear the current search
    func clearSearch() {
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        // Reset search state
        searchText = ""
        isActiveSearch = false
        combinedResults = []
        
        Task {
            await appleMusicService.clearSearch()
        }
        
        // Update state
        updateState()
    }
    
    /// Toggle the sort direction
    func toggleSortDirection() {
        sortDirection.toggle()
        updateState()
    }
    
    /// Set the sort field
    func setSortField(_ field: SortField) {
        if sortField == field {
            toggleSortDirection()
        } else {
            sortField = field
            sortDirection = .descending
        }
        updateState()
    }
    
    // MARK: - Computed Properties
    
    /// Sorted library songs based on current sort settings
    var sortedSongs: [MPMediaItem] {
        return sortLocalSongs(songs)
    }
    
    /// Sorted combined search results based on current sort settings
    var sortedCombinedResults: [SearchResult] {
        return sortCombinedResults(combinedResults)
    }
    
    /// Whether a search is currently in progress
    var isSearching: Bool {
        if case .loading = state, isActiveSearch {
            return true
        }
        return false
    }
    
    /// Whether the app has Apple Music access
    var hasAppleMusicAccess: Bool {
        return Task {
            return await appleMusicService.hasAccess
        }.result.value ?? false
    }
    
    /// Whether the device has an active network connection
    var isNetworkConnected: Bool {
        return networkMonitor.isConnected
    }
    
    // MARK: - Private Methods
    
    /// Update the view state with current data
    private func updateState() {
        let content = Content(
            songs: self.songs,
            appleMusicSongs: self.appleMusicSongs,
            combinedResults: self.combinedResults,
            isActiveSearch: self.isActiveSearch
        )
        self.state = .content(content)
    }
    
    /// Process and combine search results with precomputed data
    private func processAndCombineResults(
        localMatches: [MPMediaItem],
        appleMusicSongs: [Song]
    ) async -> [SearchResult] {
        var combined: [SearchResult] = []
        
        // Add local matches first
        for song in localMatches {
            combined.append(SearchResult(type: .localSong(song)))
        }
        
        // Process Apple Music songs if we have access and network
        if await appleMusicService.hasAccess && networkMonitor.isConnected {
            // Create lookup dictionary for faster duplicate detection
            let localSongKeys = Set(localMatches.map { song in
                createSongKey(
                    title: song.title ?? "",
                    artist: song.artist ?? "",
                    album: song.albumTitle ?? ""
                )
            })
            
            for song in appleMusicSongs {
                let songKey = createSongKey(
                    title: song.title,
                    artist: song.artistName,
                    album: song.albumTitle ?? ""
                )
                
                // Skip duplicates
                if localSongKeys.contains(songKey) {
                    continue
                }
                
                // Get library status and play count
                let isInLibrary = await isAppleMusicSongInLibrary(song)
                var playCount: Int? = nil
                var localSong: MPMediaItem? = nil
                
                if isInLibrary {
                    do {
                        localSong = try await musicLibraryService.findLocalSong(
                            title: song.title,
                            artist: song.artistName,
                            album: song.albumTitle ?? ""
                        )
                        playCount = localSong?.playCount
                    } catch {
                        print("Error getting local song: \(error.localizedDescription)")
                    }
                }
                
                let precomputedData = SearchResult.PrecomputedData(
                    isInLibrary: isInLibrary,
                    playCount: playCount,
                    localSong: localSong
                )
                
                combined.append(SearchResult(type: .appleMusicSong(song, precomputedData)))
            }
        }
        
        return combined
    }
    
    /// Check if an Apple Music song is in the local library
    private func isAppleMusicSongInLibrary(_ song: Song) async -> Bool {
        do {
            return try await musicLibraryService.findLocalSong(
                title: song.title,
                artist: song.artistName,
                album: song.albumTitle ?? ""
            ) != nil
        } catch {
            return false
        }
    }
    
    /// Sort local songs based on current sort settings
    private func sortLocalSongs(_ songs: [MPMediaItem]) -> [MPMediaItem] {
        switch sortField {
        case .playCount:
            return songs.sorted { song1, song2 in
                if song1.playCount == song2.playCount {
                    return (song1.title ?? "") < (song2.title ?? "")
                }
                return sortDirection == .descending ?
                    song1.playCount > song2.playCount :
                    song1.playCount < song2.playCount
            }
        case .title:
            return songs.sorted { song1, song2 in
                let title1 = song1.title ?? ""
                let title2 = song2.title ?? ""
                return sortDirection == .descending ?
                    title1 > title2 :
                    title1 < title2
            }
        }
    }
    
    /// Sort combined results based on current sort settings
    private func sortCombinedResults(_ results: [SearchResult]) -> [SearchResult] {
        switch sortField {
        case .playCount:
            return results.sorted { result1, result2 in
                let playCount1 = result1.playCount ?? 0
                let playCount2 = result2.playCount ?? 0
                if playCount1 == playCount2 {
                    return result1.title < result2.title
                }
                return sortDirection == .descending ?
                    playCount1 > playCount2 :
                    playCount1 < playCount2
            }
        case .title:
            return results.sorted { result1, result2 in
                return sortDirection == .descending ?
                    result1.title > result2.title :
                    result1.title < result2.title
            }
        }
    }
    
    /// Create a unique key for a song based on its metadata
    private func createSongKey(title: String, artist: String, album: String) -> String {
        return "\(normalizeString(title))|\(normalizeString(artist))|\(normalizeString(album))"
    }
    
    /// Normalize a string for comparison
    private func normalizeString(_ string: String) -> String {
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}