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
                        // Only show results when user presses return/search
                        submitSearch()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        // Process in background but don't show results yet
                        processSearchInBackground(newValue)
                    }
                
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
            
            // Content area
            ScrollView {
                if isSearching {
                    // Extended loading indicator while doing expensive computations
                    VStack(spacing: Theme.Metrics.spacingLarge) {
                        ProgressView()
                            .scaleEffect(Theme.Metrics.progressViewScale)
                        Text("Searching and processing results...")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Text("This may take a moment for better scrolling performance")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Metrics.paddingLarge)
                } else if isActiveSearch {
                    // Show combined search results after user presses return
                    if combinedResults.isEmpty {
                        // No results found
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No results found",
                            message: "No matches for '\(searchText)'"
                        )
                        .padding(.top, Theme.Metrics.paddingLarge)
                    } else {
                        // Combined results list - now optimized for smooth scrolling
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedCombinedResults.enumerated()), id: \.element.id) { index, result in
                                Group {
                                    switch result.type {
                                    case .localSong(let song):
                                        NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                                            OptimizedLocalSongRow(song: song, rank: index + 1)
                                        }
                                        
                                    case .appleMusicSong(let song, let precomputedData):
                                        NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                                            OptimizedAppleMusicSongRow(
                                                song: song,
                                                rank: index + 1,
                                                precomputedData: precomputedData
                                            )
                                        }
                                    }
                                }
                                .padding(.vertical, Theme.Metrics.spacingTiny)
                            }
                        }
                        .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
                        .padding(.top, Theme.Metrics.paddingSmall)
                    }
                } else {
                    // Default view - show library songs
                    if defaultLibrarySongs.isEmpty {
                        // Empty library state
                        EmptyStateView(
                            icon: "music.note",
                            title: "No songs found",
                            message: "Your music library appears to be empty or the app doesn't have permission to access it."
                        )
                        .padding(.top, Theme.Metrics.paddingLarge)
                    } else {
                        // Show all library songs
                        LazyVStack(spacing: 0) {
                            ForEach(Array(defaultLibrarySongs.enumerated()), id: \.element.persistentID) { index, song in
                                NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                                    OptimizedLocalSongRow(song: song, rank: index + 1)
                                }
                                .padding(.vertical, Theme.Metrics.spacingTiny)
                            }
                        }
                        .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
                        .padding(.top, Theme.Metrics.paddingSmall)
                    }
                }
            }
        }
        .padding(.top, Theme.Metrics.paddingMedium)
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        }
        .onAppear {
            // Refresh library when view appears
            if musicLibrary.songs.isEmpty && musicLibrary.hasAccess {
                musicLibrary.requestPermissionAndLoadLibrary()
            }
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
    
    // Process search in background without showing results
    private func processSearchInBackground(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If search is cleared, reset to default view
        if trimmedQuery.isEmpty {
            Task {
                await musicLibrary.clearAllSearches()
                
                await MainActor.run {
                    isActiveSearch = false
                    combinedResults = []
                }
            }
            return
        }
        
        // Process Apple Music search in background only if network is available
        if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
            Task {
                await musicLibrary.searchAppleMusic(query: trimmedQuery)
            }
        }
    }
    
    // When user presses return/search, show the results with all expensive operations pre-computed
    private func submitSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            isActiveSearch = false
            combinedResults = []
            return
        }
        
        // Show loading state for longer while doing expensive computations
        isSearching = true
        isActiveSearch = true
        
        Task {
            // All expensive operations moved to background thread
            var localMatches: [MPMediaItem] = []
            var appleMusicSongs: [Song] = []
            
            // Get local library matches
            localMatches = musicLibrary.cachedFilteredSongs(for: trimmedQuery)
            
            // Wait for Apple Music search if available
            if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
                // Wait for Apple Music search to complete
                while await musicLibrary.isSearchingAppleMusic {
                    try? await Task.sleep(nanoseconds: Theme.TimeIntervals.searchDebounce) // 100ms
                }
                appleMusicSongs = await musicLibrary.appleMusicSongs
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

// Optimized row views that don't do any expensive operations during rendering

struct OptimizedLocalSongRow: View {
    let song: MPMediaItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: Theme.Metrics.songRowSpacing) {
            // Album Artwork first
            LibraryArtworkView(artwork: song.artwork, size: Theme.Metrics.artworkSizeSmall)
            
            // Rank number using theme with dynamic width
            let rankWidth = rank >= 1000 ? Theme.Metrics.rankWidthExtended : Theme.Metrics.rankWidth
            Text("\(rank)")
                .modifier(Theme.Modifiers.RankStyle(color: Theme.Colors.primary, width: rankWidth))
            
            // Song info section
            VStack(alignment: .leading, spacing: Theme.Metrics.songInfoSpacing) {
                HStack(spacing: Theme.Metrics.badgeSpacing) {
                    Text(song.title ?? "Unknown")
                        .font(Theme.Typography.songTitle)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    // Explicit badge using theme
                    if song.isExplicitItem {
                        Text("E")
                            .explicitBadgeStyle()
                    }
                    
                    Spacer()
                }
                
                Text(song.artist ?? "Unknown Artist")
                    .font(Theme.Typography.artistName)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            // Play count - no expensive operations
            VStack(alignment: .trailing, spacing: Theme.Metrics.spacingMicro) {
                Text("\(song.playCount)")
                    .font(Theme.Typography.subheadlineBold)
                    .foregroundColor(Theme.Colors.primary)
                
                Text("plays")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(.vertical, Theme.Metrics.songRowVerticalPadding)
        .contentShape(Rectangle())
    }
}

struct OptimizedAppleMusicSongRow: View {
    let song: Song
    let rank: Int
    let precomputedData: SearchResult.PrecomputedData
    
    var body: some View {
        HStack(spacing: Theme.Metrics.songRowSpacing) {
            // Album Artwork first
            AsyncArtworkView.appleMusic(
                artwork: song.artwork,
                size: Theme.Metrics.artworkSizeSmall
            )
            
            // Rank number using theme with dynamic width
            let rankWidth = rank >= 1000 ? Theme.Metrics.rankWidthExtended : Theme.Metrics.rankWidth
            Text("\(rank)")
                .modifier(Theme.Modifiers.RankStyle(color: Theme.Colors.appleMusicColor, width: rankWidth))
            
            // Song info section
            VStack(alignment: .leading, spacing: Theme.Metrics.songInfoSpacing) {
                HStack(spacing: Theme.Metrics.badgeSpacing) {
                    Text(song.title)
                        .font(Theme.Typography.songTitle)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    // Explicit badge using theme
                    if song.contentRating == .explicit {
                        Text("E")
                            .explicitBadgeStyle()
                    }
                    
                    Spacer()
                }
                
                Text(song.artistName)
                    .font(Theme.Typography.artistName)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            // Use pre-computed play count - no expensive operations during scrolling
            if let playCount = precomputedData.playCount {
                VStack(alignment: .trailing, spacing: Theme.Metrics.spacingMicro) {
                    Text("\(playCount)")
                        .font(Theme.Typography.subheadlineBold)
                        .foregroundColor(Theme.Colors.appleMusicColor)
                    
                    Text("plays")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            } else {
                // Show Apple Music indicator if not in library
                Image(systemName: "applelogo")
                    .font(.system(size: Theme.FontSizes.medium))
                    .foregroundColor(Theme.Colors.appleMusicColor)
            }
        }
        .padding(.vertical, Theme.Metrics.songRowVerticalPadding)
        .contentShape(Rectangle())
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
