//
//  SongRowView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

/// Unified song row view supporting both local and Apple Music songs
struct SongRowView<T>: View {
    enum SourceType {
        case localLibrary
        case appleMusic
    }
    
    let item: T
    let rank: Int
    let sourceType: SourceType
    
    // For Apple Music songs
    private var isInLibrary: Bool = false
    private var playCount: Int? = nil
    
    // Initializer for local library songs
    init(song: MPMediaItem, rank: Int) {
        self.item = song as! T
        self.rank = rank
        self.sourceType = .localLibrary
    }
    
    // Initializer for Apple Music songs
    init(song: Song, rank: Int, isInLibrary: Bool, playCount: Int?) {
        self.item = song as! T
        self.rank = rank
        self.sourceType = .appleMusic
        self.isInLibrary = isInLibrary
        self.playCount = playCount
    }
    
    var body: some View {
        switch sourceType {
        case .localLibrary:
            localSongRow()
        case .appleMusic:
            appleMusicSongRow()
        }
    }
    
    @ViewBuilder
    private func localSongRow() -> some View {
        let song = item as! MPMediaItem
        
        HStack(spacing: Theme.Metrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle()
            
            // Artwork
            LibraryArtworkView(artwork: song.artwork, size: Theme.Metrics.artworkSizeSmall)
            
            // Song info
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingXSmall) {
                Text(song.title ?? "Unknown")
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play count and cloud indicator
            VStack(alignment: .trailing, spacing: Theme.Metrics.spacingXSmall) {
                HStack(spacing: Theme.Metrics.spacingXSmall) {
                    Text("\(song.playCount) plays")
                        .font(Theme.Typography.subheadlineBold)
                        .foregroundColor(Theme.Colors.primary)
                    
                    if song.isCloudItem {
                        Image(systemName: "cloud")
                            .iconStyle(size: Theme.Metrics.iconSizeSmall)
                    }
                }
                
                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Theme.Metrics.spacingXSmall)
    }
    
    @ViewBuilder
    private func appleMusicSongRow() -> some View {
        let song = item as! Song
        
        HStack(spacing: Theme.Metrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle(color: Theme.Colors.appleMusicColor)
            
            // Artwork with optimized rendering
            ZStack {
                AsyncArtworkView(
                    url: song.artwork?.url(width: Int(Theme.Metrics.artworkSizeSmall), height: Int(Theme.Metrics.artworkSizeSmall)),
                    size: Theme.Metrics.artworkSizeSmall
                )
                
                // "In Library" indicator overlay - only render if needed
                if isInLibrary {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                                .background(Theme.Colors.inLibrary)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingXSmall) {
                Text(song.title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Apple Music indicator, play count (if in library), and album
            VStack(alignment: .trailing, spacing: Theme.Metrics.spacingXSmall) {
                if isInLibrary {
                    HStack(spacing: Theme.Metrics.spacingXSmall) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.inLibrary)
                        Text("In Library")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.inLibrary)
                    }
                    
                    if let playCount = playCount {
                        Text("\(playCount) plays")
                            .font(Theme.Typography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.inLibrary)
                    }
                } else {
                    HStack(spacing: Theme.Metrics.spacingXSmall) {
                        Image(systemName: "applelogo")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.appleMusicColor)
                        Text("Apple Music")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.appleMusicColor)
                    }
                }
                
                Text(song.albumTitle ?? "")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Theme.Metrics.spacingXSmall)
    }
}

// Factory method to create the appropriate SongRowView from a model
extension SongRowView {
    static func create(from song: MPMediaItem, rank: Int) -> some View {
        SongRowView<MPMediaItem>(song: song, rank: rank)
    }
    
    static func create(from song: Song, rank: Int, musicLibrary: MusicLibraryModel) -> some View {
        let isInLibrary = musicLibrary.isSongInLibrary(song)
        let playCount = musicLibrary.getPlayCount(for: song)
        return SongRowView<Song>(song: song, rank: rank, isInLibrary: isInLibrary, playCount: playCount)
    }
}
