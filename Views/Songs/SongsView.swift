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
    @State private var searchText = ""
    @State private var searchDebounceTimer: Timer?
    
    var filteredLocalSongs: [MPMediaItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return musicLibrary.songs
        } else {
            return musicLibrary.songs.filter { song in
                AppHelpers.fuzzyMatch(song.title, searchText) ||
                AppHelpers.fuzzyMatch(song.artist, searchText) ||
                AppHelpers.fuzzyMatch(song.albumTitle, searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .iconStyle()
                
                TextField("Search songs", text: $searchText)
                    .font(Theme.Typography.body)
                    .onChange(of: searchText) { oldValue, newValue in
                        // Debounce Apple Music search
                        searchDebounceTimer?.invalidate()
                        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            let trimmedSearch = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedSearch.isEmpty && musicLibrary.hasAppleMusicAccess {
                                Task {
                                    await musicLibrary.searchAppleMusic(query: trimmedSearch)
                                }
                            } else if trimmedSearch.isEmpty {
                                musicLibrary.clearAppleMusicSearch()
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        musicLibrary.clearAppleMusicSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .iconStyle()
                    }
                }
            }
            .searchBarStyle()
            
            // Combined results in one scrollview
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Library results section
                    if !filteredLocalSongs.isEmpty {
                        ForEach(Array(filteredLocalSongs.enumerated()), id: \.element.persistentID) { index, song in
                            NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                                SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
                    } else if searchText.isEmpty {
                        // Empty library state
                        EmptyStateView(
                            icon: "music.note",
                            title: "No songs found",
                            message: "Your music library appears to be empty or the app doesn't have permission to access it."
                        )
                        .padding(.top, Theme.Metrics.paddingSmall)
                    }
                    
                    // Apple Music results section (only show if searching)
                    if !searchText.isEmpty && musicLibrary.hasAppleMusicAccess {
                        if musicLibrary.isSearchingAppleMusic {
                            // Loading state
                            VStack(spacing: Theme.Metrics.spacingLarge) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Searching Apple Music...")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Metrics.paddingMedium)
                        } else if !musicLibrary.appleMusicSongs.isEmpty {
                            // Apple Music results
                            ForEach(Array(musicLibrary.appleMusicSongs.enumerated()), id: \.element.id) { index, song in
                                AppleMusicResultRow(song: song, index: index)
                                    .padding(.vertical, 4)
                            }
                            .padding(.horizontal, Theme.Metrics.paddingMedium + Theme.Metrics.paddingSmall)
                        } else if filteredLocalSongs.isEmpty {
                            // No results found anywhere
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No results found",
                                message: "No matches for '\(searchText)' in your library or Apple Music"
                            )
                            .padding(.top, Theme.Metrics.paddingSmall)
                        }
                    }
                }
                .padding(.top, Theme.Metrics.paddingSmall)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Row component for Apple Music results
struct AppleMusicResultRow: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let song: Song
    let index: Int
    @State private var isInLibrary: Bool = false
    
    var body: some View {
        Group {
            if isInLibrary, let localSong = musicLibrary.getLocalSongMatch(for: song) {
                // If the song is in the local library, navigate to SongDetailView
                NavigationLink(destination: SongDetailView(song: localSong, rank: index + 1)) {
                    SongRowView<Song>.create(from: song, rank: index + 1, musicLibrary: musicLibrary)
                }
            } else {
                // If not in library, navigate to AppleMusicSongDetailView
                NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                    SongRowView<Song>.create(from: song, rank: index + 1, musicLibrary: musicLibrary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Compute this property once when the row becomes visible
            isInLibrary = musicLibrary.isSongInLibrary(song)
        }
    }
}
