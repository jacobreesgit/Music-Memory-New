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
        
        HStack(spacing: Theme.Metrics.songRowSpacing) {
            // Album Artwork first
            LibraryArtworkView(artwork: song.artwork, size: Theme.Metrics.artworkSizeSmall)
            
            // Rank number using theme with dynamic width
            let rankWidth = rank >= 1000 ? Theme.Metrics.rankWidthExtended : Theme.Metrics.rankWidth
            Text("\(rank)")
                .modifier(Theme.Modifiers.RankStyle(color: Theme.Colors.primary, width: rankWidth))
            
            // Song info section
            VStack(alignment: .leading, spacing: Theme.Metrics.songInfoSpacing) {
                HStack(spacing: Theme.Metrics.badgeSpacing) {
                    Text(song.title ?? "Unknown")
                        .font(Theme.Typography.songTitle)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    // Explicit badge using theme
                    if song.isExplicitItem {
                        Text("E")
                            .explicitBadgeStyle()
                    }
                    
                    Spacer()
                }
                
                Text(song.artist ?? "Unknown Artist")
                    .font(Theme.Typography.artistName)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            // Play count instead of ellipsis
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(song.playCount)")
                    .font(Theme.Typography.subheadlineBold)
                    .foregroundColor(Theme.Colors.primary)
                
                Text("plays")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(.vertical, Theme.Metrics.songRowVerticalPadding)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func appleMusicSongRow() -> some View {
        let song = item as! Song
        
        HStack(spacing: Theme.Metrics.songRowSpacing) {
            // Album Artwork first
            AsyncArtworkView.appleMusic(
                artwork: song.artwork,
                size: Theme.Metrics.artworkSizeSmall
            )
            
            // Rank number using theme with dynamic width
            let rankWidth = rank >= 1000 ? Theme.Metrics.rankWidthExtended : Theme.Metrics.rankWidth
            Text("\(rank)")
                .modifier(Theme.Modifiers.RankStyle(color: Theme.Colors.appleMusicColor, width: rankWidth))
            
            // Song info section
            VStack(alignment: .leading, spacing: Theme.Metrics.songInfoSpacing) {
                HStack(spacing: Theme.Metrics.badgeSpacing) {
                    Text(song.title)
                        .font(Theme.Typography.songTitle)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    // Explicit badge using theme
                    if song.contentRating == .explicit {
                        Text("E")
                            .explicitBadgeStyle()
                    }
                    
                    // Library indicator (subtle)
                    if isInLibrary {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.inLibrary)
                    }
                    
                    Spacer()
                }
                
                Text(song.artistName)
                    .font(Theme.Typography.artistName)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            // Play count for Apple Music songs (if in library)
            if isInLibrary, let playCount = playCount {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(playCount)")
                        .font(Theme.Typography.subheadlineBold)
                        .foregroundColor(Theme.Colors.inLibrary)
                    
                    Text("plays")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            } else {
                // Show Apple Music indicator if not in library
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.appleMusicColor)
                    
                    Text("Apple Music")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.appleMusicColor)
                }
            }
        }
        .padding(.vertical, Theme.Metrics.songRowVerticalPadding)
        .contentShape(Rectangle())
    }
}

// Factory methods for creating SongRowView with proper type specification
extension SongRowView {
    static func create(from song: MPMediaItem, rank: Int) -> SongRowView<MPMediaItem> {
        return SongRowView<MPMediaItem>(song: song, rank: rank)
    }
    
    static func create(from song: Song, rank: Int, musicLibrary: MusicLibraryModel) -> SongRowView<Song> {
        let isInLibrary = musicLibrary.isSongInLibrary(song)
        let playCount = musicLibrary.getPlayCount(for: song)
        return SongRowView<Song>(song: song, rank: rank, isInLibrary: isInLibrary, playCount: playCount)
    }
}
