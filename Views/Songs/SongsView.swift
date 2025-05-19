//
//  SongsView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

struct SongsView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var searchText = ""
    @State private var isActiveSearch = false
    @State private var isSearching = false
    @State private var combinedResults: [SearchResult] = []
    
    // Default view shows all library songs
    private var defaultLibrarySongs: [MPMediaItem] {
        return musicLibrary.songs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .iconStyle()
                
                TextField(networkMonitor.isConnected ? "Search library and Apple Music" : "Search library", text: $searchText)
                    .font(Theme.Typography.body)
                    .autocorrectionDisabled(true)
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
                        searchText = ""
                        isActiveSearch = false
                        combinedResults = []
                        musicLibrary.clearAllSearches()
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
                    // Single loading indicator when actively searching
                    VStack(spacing: Theme.Metrics.spacingLarge) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching...")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
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
                        // Combined results list
                        LazyVStack(spacing: 0) {
                            ForEach(Array(combinedResults.enumerated()), id: \.element.id) { index, result in
                                Group {
                                    switch result.type {
                                    case .localSong(let song):
                                        NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                                            SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                                        }
                                        
                                    case .appleMusicSong(let song):
                                        // Always show the Apple Music version
                                        NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                                            SongRowView<Song>.create(from: song, rank: index + 1, musicLibrary: musicLibrary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
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
                                    SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                                }
                                .padding(.vertical, 4)
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
        .onAppear {
            // Refresh library when view appears
            if musicLibrary.songs.isEmpty && musicLibrary.hasAccess {
                musicLibrary.requestPermissionAndLoadLibrary()
            }
        }
    }
    
    // Process search in background without showing results
    private func processSearchInBackground(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If search is cleared, reset to default view
        if trimmedQuery.isEmpty {
            isActiveSearch = false
            combinedResults = []
            musicLibrary.clearAllSearches()
            return
        }
        
        // Process Apple Music search in background only if network is available
        if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
            Task {
                await musicLibrary.searchAppleMusic(query: trimmedQuery)
            }
        }
    }
    
    // When user presses return/search, show the results
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
            // Get local library matches
            let localMatches = musicLibrary.cachedFilteredSongs(for: trimmedQuery)
            
            // If Apple Music is enabled and network is available, wait for those results too
            if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
                // Wait for Apple Music search to complete if it's in progress
                while musicLibrary.isSearchingAppleMusic {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
            
            // Combine results - library songs always first
            var combined: [SearchResult] = []
            
            // Add local matches first
            for song in localMatches {
                combined.append(SearchResult(type: .localSong(song)))
            }
            
            // Then add Apple Music songs that aren't duplicates of library songs
            if musicLibrary.hasAppleMusicAccess && networkMonitor.isConnected {
                for song in musicLibrary.appleMusicSongs {
                    // Only add if not already in library (to avoid duplicates)
                    let isDuplicate = localMatches.contains { localSong in
                        return musicLibrary.createSongKey(
                            title: localSong.title ?? "",
                            artist: localSong.artist ?? "",
                            album: localSong.albumTitle ?? ""
                        ) == musicLibrary.createSongKey(
                            title: song.title,
                            artist: song.artistName,
                            album: song.albumTitle ?? ""
                        )
                    }
                    
                    if !isDuplicate {
                        combined.append(SearchResult(type: .appleMusicSong(song)))
                    }
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                combinedResults = combined
                isSearching = false
            }
        }
    }
}

// Unified search result model
struct SearchResult: Identifiable {
    enum ResultType {
        case localSong(MPMediaItem)
        case appleMusicSong(Song)
    }
    
    let id = UUID()
    let type: ResultType
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
