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
                if isInLibrary {
                    if let localSong = localSongMatch {
                        DetailRow(title: "Library Status", value: "Available in Your Library")
                        DetailRow(title: "Play Count", value: "\(localSong.playCount)")
                        
                        if let lastPlayed = localSong.lastPlayedDate {
                            DetailRow(title: "Last Played", value: AppHelpers.formatDate(lastPlayed))
                        }
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
            // Calculate these values once when the view appears
            isInLibrary = musicLibrary.isSongInLibrary(song)
            localSongMatch = musicLibrary.getLocalSongMatch(for: song)
        }
    }
}
