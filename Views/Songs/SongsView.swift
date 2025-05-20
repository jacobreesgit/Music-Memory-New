//
//  SongsView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

// Enhanced SearchResult with all expensive values pre-computed
struct SearchResult: Identifiable {
    enum ResultType {
        case localSong(MPMediaItem)
        case appleMusicSong(Song, PrecomputedData)
    }
    
    // Pre-computed data for Apple Music songs to avoid expensive operations during scrolling
    struct PrecomputedData {
        let isInLibrary: Bool
        let playCount: Int?
        let localSong: MPMediaItem?
    }
    
    let id = UUID()
    let type: ResultType
    
    // Convenience getters for UI
    var playCount: Int? {
        switch type {
        case .localSong(let song):
            return song.playCount
        case .appleMusicSong(_, let data):
            return data.playCount
        }
    }
    
    var isInLibrary: Bool {
        switch type {
        case .localSong:
            return true
        case .appleMusicSong(_, let data):
            return data.isInLibrary
        }
    }
    
    // Helper for sorting
    var title: String {
        switch type {
        case .localSong(let song):
            return song.title ?? "Unknown"
        case .appleMusicSong(let song, _):
            return song.title
        }
    }
}

// Sorting field and direction
enum SortField: String, CaseIterable {
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

enum SortDirection: String {
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

struct SongsView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var searchText = ""
    @State private var isActiveSearch = false
    @State private var isSearching = false
    @State private var combinedResults: [SearchResult] = []
    @State private var sortField: SortField = .playCount
    @State private var sortDirection: SortDirection = .descending
    
    // Default view shows all library songs (sorted)
    private var defaultLibrarySongs: [MPMediaItem] {
        return sortLocalSongs(musicLibrary.songs)
    }
    
    // Sorted combined results
    private var sortedCombinedResults: [SearchResult] {
        return sortCombinedResults(combinedResults)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .iconStyle()
                
                TextField(networkMonitor.isConnected ? "Search library and Apple Music" : "Search library", text: $searchText)
                    .font(Theme.Typography.body)
                    .autocorrectionDisabled(false)
                    .autocapitalization(.none)
                    .onSubmit {
                        // Only search when the user presses return
                        submitSearch()
                    }
                    // No onChange handler - we don't search while typing
                
                if !searchText.isEmpty {
                    Button(action: {
                        clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .iconStyle()
                    }
                }
            }
            .searchBarStyle()
            
            // Content area - broken into separate view builders to help compiler
            ScrollView {
                contentView
            }
        }
        .padding(.top, Theme.Metrics.paddingMedium)
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .onAppear {
            // Refresh library when view appears
            if musicLibrary.songs.isEmpty && musicLibrary.hasAccess {
                musicLibrary.requestPermissionAndLoadLibrary()
            }
        }
    }
    
    // MARK: - View Builders - Breaking down complex views
    
    @ViewBuilder
    private var contentView: some View {
        if isSearching {
            loadingView
        } else if isActiveSearch {
            searchResultsView
        } else {
            libraryView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        // Extended loading indicator while doing expensive computations
        VStack(spacing: Theme.Metrics.spacingLarge) {
            ProgressView()
                // Using fixed value instead of potentially problematic theme value
                .scaleEffect(1.2)
            Text("Searching...")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Metrics.paddingLarge)
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        if combinedResults.isEmpty {
            // No results found
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results found",
                message: "No matches for '\(searchText)'"
            )
            .padding(.top, Theme.Metrics.paddingLarge)
        } else {
            // Combined results list - using standard SongRowView
            searchResultsList
        }
    }
    
    @ViewBuilder
    private var searchResultsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(sortedCombinedResults.enumerated()), id: \.element.id) { index, result in
                searchResultRow(result: result, index: index)
                    .padding(.vertical, Theme.Metrics.spacingTiny)
            }
        }
        .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
        .padding(.top, Theme.Metrics.paddingSmall)
    }
    
    @ViewBuilder
    private func searchResultRow(result: SearchResult, index: Int) -> some View {
        Group {
            switch result.type {
            case .localSong(let song):
                NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                    SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                }
                
            case .appleMusicSong(let song, _):
                NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                    SongRowView<Song>.create(from: song, rank: index + 1, musicLibrary: musicLibrary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var libraryView: some View {
        if defaultLibrarySongs.isEmpty {
            // Empty library state
            EmptyStateView(
                icon: "music.note",
                title: "No songs found",
                message: "Your music library appears to be empty or the app doesn't have permission to access it."
            )
            .padding(.top, Theme.Metrics.paddingLarge)
        } else {
            // Show all library songs - using standard SongRowView
            libraryList
        }
    }
    
    @ViewBuilder
    private var libraryList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(defaultLibrarySongs.enumerated()), id: \.element.persistentID) { index, song in
                NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                    SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                }
                .padding(.vertical, Theme.Metrics.spacingTiny)
            }
        }
        .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
        .padding(.top, Theme.Metrics.paddingSmall)
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            ForEach(SortField.allCases, id: \.self) { field in
                Button(action: {
                    withAnimation(.easeInOut(duration: Theme.Animation.menuDuration)) {
                        if sortField == field {
                            // If same field, toggle direction
                            sortDirection.toggle()
                        } else {
                            // If different field, switch to that field and reset to descending
                            sortField = field
                            sortDirection = .descending
                        }
                    }
                }) {
                    HStack {
                        Label(field.rawValue, systemImage: field.systemImage)
                        Spacer()
                        if sortField == field {
                            Image(systemName: sortDirection.chevronImage)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortField.systemImage)
                    .font(.system(size: Theme.FontSizes.regular, weight: .medium))
                Image(systemName: sortDirection.chevronImage)
                    .font(.system(size: Theme.FontSizes.small, weight: .medium))
            }
            .foregroundColor(Theme.Colors.primary)
        }
    }
    
    // MARK: - Sorting Logic
    
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
    
    // MARK: - Search Logic
    
    // Clear search and reset state
    private func clearSearch() {
        Task {
            await musicLibrary.clearAllSearches()
            
            await MainActor.run {
                searchText = ""
                isActiveSearch = false
                combinedResults = []
            }
        }
    }
    
    // Submit search when return is pressed
    private func submitSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            isActiveSearch = false
            combinedResults = []
            return
        }
        
        // Show loading state
        isSearching = true
        isActiveSearch = true
        
        Task {
            // First cancel any existing searches
            await musicLibrary.clearAllSearches()
            
            // Get local library matches
            let localMatches = musicLibrary.cachedFilteredSongs(for: trimmedQuery)
            var appleMusicSongs: [Song] = []
            
            // Start a fresh Apple Music search if we have access
            if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
                // Start the search
                await musicLibrary.searchAppleMusic(query: trimmedQuery)
                
                // Maximum wait time - quit the loop if this is exceeded
                let startTime = Date()
                let maxWaitTime: TimeInterval = 3.0
                
                // Wait a bit for Apple Music results
                while musicLibrary.isSearchingAppleMusic {
                    // Check if we've exceeded max wait time
                    if Date().timeIntervalSince(startTime) > maxWaitTime {
                        print("DEBUG: Max wait time exceeded for search: \(trimmedQuery)")
                        break
                    }
                    
                    // Brief sleep to prevent tight loop
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    
                    // Break if this task has been cancelled
                    if Task.isCancelled {
                        break
                    }
                }
                
                // Get the results whether we timed out or not
                appleMusicSongs = musicLibrary.appleMusicSongs
            }
            
            // Process and combine results
            let combined = await processAndCombineResults(localMatches: localMatches, appleMusicSongs: appleMusicSongs)
            
            // Update UI on main thread with pre-computed results
            await MainActor.run {
                combinedResults = combined
                isSearching = false
            }
        }
    }
    
    // Process and combine results with all expensive operations done here
    private func processAndCombineResults(localMatches: [MPMediaItem], appleMusicSongs: [Song]) async -> [SearchResult] {
        var combined: [SearchResult] = []
        
        // Add local matches first - these are simple, no expensive operations needed
        for song in localMatches {
            combined.append(SearchResult(type: .localSong(song)))
        }
        
        // Process Apple Music songs with expensive operations done here
        if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
            // Create a lookup dictionary for faster duplicate detection
            let localSongKeys = Set(localMatches.map { song in
                musicLibrary.createSongKey(
                    title: song.title ?? "",
                    artist: song.artist ?? "",
                    album: song.albumTitle ?? ""
                )
            })
            
            for song in appleMusicSongs {
                let songKey = musicLibrary.createSongKey(
                    title: song.title,
                    artist: song.artistName,
                    album: song.albumTitle ?? ""
                )
                
                // Check for duplicates using the lookup set (much faster)
                let isDuplicate = localSongKeys.contains(songKey)
                
                if !isDuplicate {
                    // Do all expensive operations here during loading
                    let isInLibrary = await musicLibrary.isAppleMusicSongInLibrary(song)
                    let localSong: MPMediaItem? = nil // Will update below if in library
                    var playCount: Int? = nil
                    
                    if isInLibrary {
                        do {
                            if let matchedSong = try await musicLibrary.getLocalSongMatch(for: song) {
                                playCount = matchedSong.playCount
                            }
                        } catch {
                            print("DEBUG: Error getting local song match: \(error)")
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
        }
        
        return combined
    }
}

// Empty state view for no results
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    
    var body: some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: icon)
                .iconStyle(size: Theme.Metrics.iconSizeXLarge)
            
            Text(title)
                .font(Theme.Typography.bodyBold)
                .foregroundColor(Theme.Colors.secondaryText)
            
            if let message = message {
                Text(message)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, Theme.Metrics.paddingLarge)
    }
}
