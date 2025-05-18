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
                    .foregroundColor(.secondary)
                
                TextField("Search songs", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { newValue in
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
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray5))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Tabs for Library vs Apple Music
            if musicLibrary.hasAppleMusicAccess {
                Picker("Source", selection: $selectedTab) {
                    Text("My Library").tag(0)
                    Text("Apple Music").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Local library songs
                if filteredLocalSongs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No songs found" : "No songs match '\(searchText)'")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Your music library appears to be empty or the app doesn't have permission to access it.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching Apple Music...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if musicLibrary.appleMusicSongs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "Search Apple Music" : "No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Type to search millions of songs in the Apple Music catalog")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(musicLibrary.appleMusicSongs.enumerated()), id: \.element.id) { index, song in
                            NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                                AppleMusicSongRow(song: song, rank: index + 1)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
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

// MARK: - Local Library Song Row
struct SongRow: View {
    let song: MPMediaItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.purple)
                .frame(width: 40, alignment: .leading)
            
            // Artwork
            if let artwork = song.artwork {
                Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage(systemName: "music.note")!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title ?? "Unknown")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play count and cloud indicator
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(song.playCount) plays")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                    
                    if song.isCloudItem {
                        Image(systemName: "cloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple Music Song Row
struct AppleMusicSongRow: View {
    let song: Song
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red) // Different color for Apple Music
                .frame(width: 40, alignment: .leading)
            
            // Artwork
            AsyncImage(url: song.artwork?.url(width: 50, height: 50)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Apple Music indicator and album
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "applelogo")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("Apple Music")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text(song.albumTitle ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
