//
//  SongRows.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

// MARK: - Local Library Song Row
struct SongRow: View {
    let song: MPMediaItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle()
            
            // Artwork
            LibraryArtworkView(artwork: song.artwork, size: AppMetrics.artworkSizeSmall)
            
            // Song info
            VStack(alignment: .leading, spacing: AppMetrics.spacingXSmall) {
                Text(song.title ?? "Unknown")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play count and cloud indicator
            VStack(alignment: .trailing, spacing: AppMetrics.spacingXSmall) {
                HStack(spacing: AppMetrics.spacingXSmall) {
                    Text("\(song.playCount) plays")
                        .font(AppFonts.subheadlineBold)
                        .foregroundColor(AppColors.primary)
                    
                    if song.isCloudItem {
                        Image(systemName: "cloud")
                            .iconStyle(size: AppMetrics.iconSizeSmall)
                    }
                }
                
                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(AppFonts.caption2)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, AppMetrics.spacingXSmall)
    }
}

// MARK: - Apple Music Song Row - Optimized for better performance
struct AppleMusicSongRow: View {
    let song: Song
    let rank: Int
    let isInLibrary: Bool
    let playCount: Int?
    
    // Optimized initializer that passes computed values rather than computing them in the view
    init(song: Song, rank: Int, musicLibrary: MusicLibraryModel) {
        self.song = song
        self.rank = rank
        self.isInLibrary = musicLibrary.isSongInLibrary(song)
        self.playCount = musicLibrary.getPlayCount(for: song)
    }
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle(color: AppColors.appleMusicColor)
            
            // Artwork with optimized rendering
            ZStack {
                AsyncArtworkView(url: song.artwork?.url(width: Int(AppMetrics.artworkSizeSmall), height: Int(AppMetrics.artworkSizeSmall)),
                               size: AppMetrics.artworkSizeSmall)
                
                // "In Library" indicator overlay - only render if needed
                if isInLibrary {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppFonts.caption)
                                .foregroundColor(.white)
                                .background(AppColors.inLibrary)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: AppMetrics.spacingXSmall) {
                Text(song.title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Apple Music indicator, play count (if in library), and album
            VStack(alignment: .trailing, spacing: AppMetrics.spacingXSmall) {
                if isInLibrary {
                    HStack(spacing: AppMetrics.spacingXSmall) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.inLibrary)
                        Text("In Library")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.inLibrary)
                    }
                    
                    if let playCount = playCount {
                        Text("\(playCount) plays")
                            .font(AppFonts.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.inLibrary)
                    }
                } else {
                    HStack(spacing: AppMetrics.spacingXSmall) {
                        Image(systemName: "applelogo")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.appleMusicColor)
                        Text("Apple Music")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.appleMusicColor)
                    }
                }
                
                Text(song.albumTitle ?? "")
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppMetrics.spacingXSmall)
    }
}
