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
    @State private var selectedTab = 0
    @State private var searchDebounceTimer: Timer?
    
    var filteredLocalSongs: [MPMediaItem] {
        if searchText.isEmpty {
            return musicLibrary.songs
        } else {
            return musicLibrary.songs.filter { song in
                (song.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.artist?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.albumTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                    .font(AppFonts.body)
                    .onChange(of: searchText) { oldValue, newValue in
                        // Debounce Apple Music search
                        searchDebounceTimer?.invalidate()
                        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            if !newValue.isEmpty && musicLibrary.hasAppleMusicAccess {
                                Task {
                                    await musicLibrary.searchAppleMusic(query: newValue)
                                }
                            } else if newValue.isEmpty {
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
            
            // Tabs for Library vs Apple Music
            if musicLibrary.hasAppleMusicAccess {
                Picker("Source", selection: $selectedTab) {
                    Text("My Library").tag(0)
                    Text("Apple Music").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, AppMetrics.paddingSmall)
            }
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Local library songs
                if filteredLocalSongs.isEmpty {
                    VStack(spacing: AppMetrics.spacingLarge) {
                        Image(systemName: "music.note")
                            .iconStyle(size: AppMetrics.iconSizeXLarge)
                        
                        Text(searchText.isEmpty ? "No songs found" : "No songs match '\(searchText)'")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if searchText.isEmpty {
                            Text("Your music library appears to be empty or the app doesn't have permission to access it.")
                                .font(AppFonts.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(filteredLocalSongs.enumerated()), id: \.element.persistentID) { index, song in
                            NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                                SongRow(song: song, rank: index + 1)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            } else {
                // Apple Music search results
                if musicLibrary.isSearchingAppleMusic {
                    VStack(spacing: AppMetrics.spacingLarge) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching Apple Music...")
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if musicLibrary.appleMusicSongs.isEmpty {
                    VStack(spacing: AppMetrics.spacingLarge) {
                        Image(systemName: "magnifyingglass")
                            .iconStyle(size: AppMetrics.iconSizeXLarge)
                        
                        Text(searchText.isEmpty ? "Search Apple Music" : "No results found")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if searchText.isEmpty {
                            Text("Type to search millions of songs in the Apple Music catalog")
                                .font(AppFonts.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppleMusicResultsList(results: musicLibrary.appleMusicSongs)
                        .environmentObject(musicLibrary)
                }
            }
        }
        .navigationTitle("Songs")
        .onAppear {
            // Refresh library when view appears
            if musicLibrary.songs.isEmpty && musicLibrary.hasAccess {
                musicLibrary.requestPermissionAndLoadLibrary()
            }
        }
    }
}

// Separate component for Apple Music results list to improve performance
struct AppleMusicResultsList: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let results: [Song]
    
    var body: some View {
        // Optimize rendering by using LazyVStack inside ScrollView
        // This avoids the recomputation of all cells when list state changes
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, song in
                    AppleMusicResultRow(song: song, index: index)
                        .environmentObject(musicLibrary)
                }
            }
            .padding(.horizontal)
        }
    }
}

// Optimized row component for Apple Music results
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
                    AppleMusicSongRow(song: song, rank: index + 1, musicLibrary: musicLibrary)
                }
            } else {
                // If not in library, navigate to AppleMusicSongDetailView
                NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                    AppleMusicSongRow(song: song, rank: index + 1, musicLibrary: musicLibrary)
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
