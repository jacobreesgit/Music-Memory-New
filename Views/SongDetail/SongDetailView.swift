//
//  SongDetailView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//  Updated on 20/05/2025 to use MVVM architecture
//

import SwiftUI
import MediaPlayer
import MusicKit

struct SongDetailView: View {
    @StateObject private var viewModel: SongDetailViewModel
    
    init(song: MPMediaItem, rank: Int) {
        _viewModel = StateObject(wrappedValue:
            DependencyContainer.shared.makeSongDetailViewModel(
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
                SongDetailBase<MPMediaItem, _, _>.create(song: content.song, rank: content.rank) {
                    // Header content
                    VStack(spacing: Theme.Metrics.spacingMedium) {
                        // Large artwork
                        LibraryArtworkView(artwork: content.song.artwork, size: Theme.Metrics.artworkSizeLarge)
                            .applyShadow(Theme.Shadows.medium)
                        
                        // Song title, artist and metrics
                        SongInfoHeader(
                            title: content.song.title ?? "Unknown",
                            artist: content.song.artist ?? ""
                        ) {
                            RankPlayCountView(
                                rank: content.rank,
                                playCount: content.song.playCount,
                                color: Theme.Colors.primary
                            )
                        }
                        
                        // Apple Music button - only show if we found a match
                        if let appleMusicSong = content.appleMusicSong {
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
                        } else if content.isSearchingAppleMusic {
                            HStack(spacing: Theme.Metrics.spacingSmall) {
                                ProgressView()
                                    .scaleEffect(Theme.Metrics.progressViewSmallScale)
                                Text("Finding on Apple Music...")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            .padding(.top, Theme.Metrics.spacingSmall)
                        }
                    }
                } detailsContent: {
                    // Details content
                    LazyVStack(spacing: 0) {
                        DetailRow(title: "Album", value: content.song.albumTitle ?? "Unknown")
                        DetailRow(title: "Genre", value: content.song.genre ?? "Unknown")
                        DetailRow(title: "Duration", value: AppHelpers.formatDuration(content.song.playbackDuration))
                        DetailRow(title: "Release Year", value: AppHelpers.formatYear(content.song.releaseDate))
                        DetailRow(title: "Date Added", value: AppHelpers.formatDate(content.song.dateAdded))
                        DetailRow(title: "Last Played", value: AppHelpers.formatDate(content.song.lastPlayedDate))
                        
                        if content.song.albumTrackNumber > 0 {
                            DetailRow(title: "Track Number", value: "\(content.song.albumTrackNumber)")
                        }
                        
                        if content.song.discNumber > 0 {
                            DetailRow(title: "Disc Number", value: "\(content.song.discNumber)")
                        }
                        
                        if content.song.beatsPerMinute > 0 {
                            DetailRow(title: "BPM", value: "\(content.song.beatsPerMinute)")
                        }
                        
                        if let composer = content.song.composer, !composer.isEmpty {
                            DetailRow(title: "Composer", value: composer)
                        }
                        
                        // Enhanced source information
                        DetailRow(title: "Source", value: viewModel.sourceText)
                        
                        // If we have Apple Music song info, display additional details
                        if let appleMusicSong = content.appleMusicSong {
                            if let isrc = appleMusicSong.isrc {
                                DetailRow(title: "ISRC", value: isrc)
                            }
                            
                            if let contentRating = appleMusicSong.contentRating {
                                let ratingText = contentRating == .explicit ? "Explicit" : "Clean"
                                DetailRow(title: "Content Rating", value: ratingText)
                            } else if content.song.isExplicitItem {
                                DetailRow(title: "Content", value: "Explicit")
                            }
                            
                            if appleMusicSong.hasLyrics {
                                DetailRow(title: "Lyrics", value: "Available", isLast: true)
                            }
                        } else if content.song.isExplicitItem {
                            DetailRow(title: "Content", value: "Explicit", isLast: true)
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
