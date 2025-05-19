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
        SongDetailBase(title: song.title) {
            // Header content
            VStack(spacing: AppMetrics.spacingMedium) {
                // Large artwork with library indicator
                ZStack {
                    AsyncArtworkView(
                        url: song.artwork?.url(width: Int(AppMetrics.artworkSizeLarge), height: Int(AppMetrics.artworkSizeLarge)),
                        size: AppMetrics.artworkSizeLarge
                    )
                    .applyShadow(AppShadows.medium)
                    
                    // "In Library" indicator overlay
                    if isInLibrary {
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: AppMetrics.spacingXSmall) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(AppFonts.title2)
                                        .foregroundColor(.white)
                                        .background(AppColors.inLibrary)
                                        .clipShape(Circle())
                                    
                                    Text("IN LIBRARY")
                                        .font(AppFonts.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, AppMetrics.paddingSmall)
                                        .padding(.vertical, AppMetrics.spacingXSmall)
                                        .background(AppColors.inLibrary)
                                        .foregroundColor(.white)
                                        .cornerRadius(AppMetrics.cornerRadiusSmall)
                                }
                            }
                            Spacer()
                        }
                        .padding(AppMetrics.paddingSmall)
                    }
                }
                
                // Song title, artist and info
                SongInfoHeader(
                    title: song.title,
                    artist: song.artistName
                ) {
                    HStack(spacing: AppMetrics.spacingLarge) {
                        VStack {
                            Text("#\(rank)")
                                .font(AppFonts.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.appleMusicColor)
                            Text("Search Result")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        LibraryStatusView(
                            isInLibrary: isInLibrary,
                            playCount: localSongMatch?.playCount
                        )
                    }
                    .padding(.top, AppMetrics.paddingSmall)
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
