//
//  AppleMusicSongDetailView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//  Updated on 20/05/2025 to use MVVM architecture
//

import SwiftUI
import MusicKit
import MediaPlayer

struct AppleMusicSongDetailView: View {
    @StateObject private var viewModel: AppleMusicSongDetailViewModel
    
    init(song: Song, rank: Int) {
        _viewModel = StateObject(wrappedValue:
            DependencyContainer.shared.makeAppleMusicSongDetailViewModel(
                song: song,
                rank: rank
            )
        )
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
                
            case .content(let content):
                SongDetailBase<Song, _, _>.create(song: content.song, rank: content.rank) {
                    // Header content
                    VStack(spacing: Theme.Metrics.spacingMedium) {
                        // Large artwork with library indicator - using high resolution
                        ZStack {
                            AsyncArtworkView.appleMusic(
                                artwork: content.song.artwork,
                                size: Theme.Metrics.artworkSizeLarge
                            )
                            .applyShadow(Theme.Shadows.medium)
                            
                            // "In Library" indicator overlay
                            if content.isInLibrary {
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: Theme.Metrics.spacingXSmall) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(Theme.Typography.title2)
                                                .foregroundColor(Theme.Colors.buttonText)
                                                .background(Theme.Colors.inLibrary)
                                                .clipShape(Circle())
                                            
                                            Text("IN LIBRARY")
                                                .font(Theme.Typography.caption2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, Theme.Metrics.paddingSmall)
                                                .padding(.vertical, Theme.Metrics.spacingXSmall)
                                                .background(Theme.Colors.inLibrary)
                                                .foregroundColor(Theme.Colors.buttonText)
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
                            title: content.song.title,
                            artist: content.song.artistName
                        ) {
                            // Library status or rank info
                            if content.isLoading {
                                HStack(spacing: Theme.Metrics.spacingSmall) {
                                    ProgressView()
                                        .scaleEffect(Theme.Metrics.progressViewSmallScale)
                                    Text("Checking library...")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                            } else if content.isInLibrary {
                                LibraryStatusView(isInLibrary: content.isInLibrary, playCount: content.localSongMatch?.playCount)
                            } else {
                                Text("#\(content.rank) in search results")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                        
                        // Open in Apple Music button
                        Button(action: {
                            viewModel.openInAppleMusic()
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
                        DetailRow(title: "Album", value: content.song.albumTitle ?? "Unknown")
                        
                        if let genres = content.song.genreNames.first {
                            DetailRow(title: "Genre", value: genres)
                        }
                        
                        if let duration = content.song.duration {
                            DetailRow(title: "Duration", value: AppHelpers.formatDuration(duration))
                        }
                        
                        if let releaseDate = content.song.releaseDate {
                            DetailRow(title: "Release Date", value: AppHelpers.formatDate(releaseDate))
                        }
                        
                        if let trackNumber = content.song.trackNumber {
                            DetailRow(title: "Track Number", value: "\(trackNumber)")
                        }
                        
                        if let discNumber = content.song.discNumber {
                            DetailRow(title: "Disc Number", value: "\(discNumber)")
                        }
                        
                        if let composerName = content.song.composerName {
                            DetailRow(title: "Composer", value: composerName)
                        }
                        
                        // Content rating
                        if let contentRating = content.song.contentRating {
                            let ratingText = contentRating == .explicit ? "Explicit" : "Clean"
                            DetailRow(title: "Content Rating", value: ratingText)
                        }
                        
                        // ISRC
                        if let isrc = content.song.isrc {
                            DetailRow(title: "ISRC", value: isrc)
                        }
                        
                        // Playback availability
                        DetailRow(title: "Source", value: "Apple Music Catalog")
                        
                        // Library status with additional info
                        if content.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        } else if content.isInLibrary {
                            if let localSong = content.localSongMatch {
                                DetailRow(title: "Library Status", value: "Available in Your Library")
                                DetailRow(title: "Play Count", value: "\(localSong.playCount)")
                                
                                if let lastPlayed = localSong.lastPlayedDate {
                                    DetailRow(title: "Last Played", value: AppHelpers.formatDate(lastPlayed))
                                }
                                
                                // Show source info for the local version
                                let sourceText = viewModel.determineLocalSourceText(localSong)
                                DetailRow(title: "Local Source", value: sourceText)
                            }
                        } else {
                            DetailRow(title: "Library Status", value: "Not in Your Library")
                        }
                        
                        if content.song.hasLyrics {
                            DetailRow(title: "Lyrics", value: "Available", isLast: true)
                        }
                    }
                }
                
            case .error(let error):
                errorView(error)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            ProgressView()
                .scaleEffect(Theme.Metrics.progressViewLargeScale)
            Text("Loading song details...")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: "exclamationmark.triangle")
                .iconStyle(size: Theme.Metrics.iconSizeXLarge, color: Theme.Colors.appleMusicColor)
            
            Text("Error Loading Song")
                .font(Theme.Typography.bodyBold)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(error.localizedDescription)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
