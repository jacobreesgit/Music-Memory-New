//
//  AppleMusicSongDetailView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MusicKit
import MediaPlayer

struct AppleMusicSongDetailView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let song: Song
    let rank: Int
    @State private var isInLibrary: Bool = false
    @State private var localSongMatch: MPMediaItem?
    @State private var isLoading: Bool = true
    
    var body: some View {
        SongDetailBase<Song, _, _>.create(song: song, rank: rank) {
            // Header content
            VStack(spacing: Theme.Metrics.spacingMedium) {
                // Large artwork with library indicator - using high resolution
                ZStack {
                    AsyncArtworkView.appleMusic(
                        artwork: song.artwork,
                        size: Theme.Metrics.artworkSizeLarge
                    )
                    .applyShadow(Theme.Shadows.medium)
                    
                    // "In Library" indicator overlay
                    if isInLibrary {
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: Theme.Metrics.spacingXSmall) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(Theme.Typography.title2)
                                        .foregroundColor(.white)
                                        .background(Theme.Colors.inLibrary)
                                        .clipShape(Circle())
                                    
                                    Text("IN LIBRARY")
                                        .font(Theme.Typography.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, Theme.Metrics.paddingSmall)
                                        .padding(.vertical, Theme.Metrics.spacingXSmall)
                                        .background(Theme.Colors.inLibrary)
                                        .foregroundColor(.white)
                                        .cornerRadius(Theme.Metrics.cornerRadiusSmall)
                                }
                            }
                            Spacer()
                        }
                        .padding(Theme.Metrics.paddingSmall)
                    }
                }
                
                // Song title and artist
                SongInfoHeader(
                    title: song.title,
                    artist: song.artistName
                ) {
                    // Library status or rank info
                    if isLoading {
                        HStack(spacing: Theme.Metrics.spacingSmall) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Checking library...")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    } else if isInLibrary {
                        LibraryStatusView(isInLibrary: isInLibrary, playCount: localSongMatch?.playCount)
                    } else {
                        Text("#\(rank) in search results")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                
                // Open in Apple Music button
                Button(action: {
                    openInAppleMusic(song)
                }) {
                    HStack(spacing: Theme.Metrics.spacingSmall) {
                        Image(systemName: "applelogo")
                            .font(.system(size: Theme.FontSizes.regular, weight: .medium))
                        Text("Open in Apple Music")
                            .font(Theme.Typography.bodyBold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, Theme.Metrics.paddingSmall)
                    .padding(.horizontal, Theme.Metrics.paddingLarge)
                    .background(Theme.Colors.appleMusicColor)
                    .cornerRadius(Theme.Metrics.cornerRadiusMedium)
                }
                .padding(.top, Theme.Metrics.spacingSmall)
            }
        } detailsContent: {
            // Details content
            LazyVStack(spacing: 0) {
                DetailRow(title: "Album", value: song.albumTitle ?? "Unknown")
                
                if let genres = song.genreNames.first {
                    DetailRow(title: "Genre", value: genres)
                }
                
                if let duration = song.duration {
                    DetailRow(title: "Duration", value: AppHelpers.formatDuration(duration))
                }
                
                if let releaseDate = song.releaseDate {
                    DetailRow(title: "Release Date", value: AppHelpers.formatDate(releaseDate))
                }
                
                if let trackNumber = song.trackNumber {
                    DetailRow(title: "Track Number", value: "\(trackNumber)")
                }
                
                if let discNumber = song.discNumber {
                    DetailRow(title: "Disc Number", value: "\(discNumber)")
                }
                
                if let composerName = song.composerName {
                    DetailRow(title: "Composer", value: composerName)
                }
                
                // Content rating
                if let contentRating = song.contentRating {
                    let ratingText = contentRating == .explicit ? "Explicit" : "Clean"
                    DetailRow(title: "Content Rating", value: ratingText)
                }
                
                // ISRC
                if let isrc = song.isrc {
                    DetailRow(title: "ISRC", value: isrc)
                }
                
                // Playback availability
                DetailRow(title: "Source", value: "Apple Music Catalog")
                
                // Library status with additional info
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if isInLibrary {
                    if let localSong = localSongMatch {
                        DetailRow(title: "Library Status", value: "Available in Your Library")
                        DetailRow(title: "Play Count", value: "\(localSong.playCount)")
                        
                        if let lastPlayed = localSong.lastPlayedDate {
                            DetailRow(title: "Last Played", value: AppHelpers.formatDate(lastPlayed))
                        }
                        
                        // Show source info for the local version
                        let sourceText = determineLocalSourceText(localSong)
                        DetailRow(title: "Local Source", value: sourceText)
                    }
                } else {
                    DetailRow(title: "Library Status", value: "Not in Your Library")
                }
                
                if song.hasLyrics {
                    DetailRow(title: "Lyrics", value: "Available", isLast: true)
                }
            }
        }
        .onAppear {
            // Check library status when view appears
            checkLibraryStatus()
        }
    }
    
    private func checkLibraryStatus() {
        isLoading = true
        
        // Perform library check in background
        Task.detached(priority: .userInitiated) {
            let inLibrary = musicLibrary.isSongInLibrary(song)
            let localMatch = inLibrary ? musicLibrary.getLocalSongMatch(for: song) : nil
            
            // Filter out uploaded songs from the match
            let filteredMatch: MPMediaItem?
            if let match = localMatch {
                // Don't consider uploaded songs as "in library" for Apple Music purposes
                let isUploaded = match.isCloudItem && !match.hasProtectedAsset && match.assetURL == nil
                filteredMatch = isUploaded ? nil : match
            } else {
                filteredMatch = nil
            }
            
            await MainActor.run {
                self.isInLibrary = filteredMatch != nil
                self.localSongMatch = filteredMatch
                self.isLoading = false
            }
        }
    }
    
    private func determineLocalSourceText(_ localSong: MPMediaItem) -> String {
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
    
    private func openInAppleMusic(_ song: Song) {
        // Try to open the song directly in Apple Music using its URL
        if let url = song.url {
            print("DEBUG: Opening Apple Music URL: \(url)")
            UIApplication.shared.open(url) { success in
                if !success {
                    print("DEBUG: Failed to open Apple Music URL, trying fallback")
                    openAppleMusicFallback(song)
                }
            }
        } else {
            print("DEBUG: No direct URL available, using fallback")
            openAppleMusicFallback(song)
        }
    }
    
    private func openAppleMusicFallback(_ song: Song) {
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
