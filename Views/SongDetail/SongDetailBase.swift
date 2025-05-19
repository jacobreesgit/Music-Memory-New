//
//  SongDetailBase.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

/// Base view for song detail screens with shared structure and styling
struct SongDetailBase<T, HeaderContent: View, DetailsContent: View>: View {
    enum SourceType {
        case localLibrary
        case appleMusic
    }
    
    let title: String
    let item: T?
    let sourceType: SourceType
    let rank: Int
    let headerContent: HeaderContent
    let detailsContent: DetailsContent
    
    // Initializer for local library song details
    init(song: MPMediaItem, rank: Int,
         @ViewBuilder headerContent: () -> HeaderContent,
         @ViewBuilder detailsContent: () -> DetailsContent) {
        self.title = song.title ?? "Song"
        self.item = song as? T
        self.sourceType = .localLibrary
        self.rank = rank
        self.headerContent = headerContent()
        self.detailsContent = detailsContent()
    }
    
    // Initializer for Apple Music song details
    init(song: Song, rank: Int,
         @ViewBuilder headerContent: () -> HeaderContent,
         @ViewBuilder detailsContent: () -> DetailsContent) {
        self.title = song.title
        self.item = song as? T
        self.sourceType = .appleMusic
        self.rank = rank
        self.headerContent = headerContent()
        self.detailsContent = detailsContent()
    }
    
    // General purpose initializer for customization
    init(title: String,
         @ViewBuilder headerContent: () -> HeaderContent,
         @ViewBuilder detailsContent: () -> DetailsContent) {
        self.title = title
        self.item = nil
        self.sourceType = .localLibrary  // Default
        self.rank = 0
        self.headerContent = headerContent()
        self.detailsContent = detailsContent()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingXLarge) {
                // Header content from caller
                headerContent
                
                // Song details from caller
                VStack(alignment: .leading, spacing: 0) {
                    Text("Song Details")
                        .font(Theme.Typography.bodyBold)
                        .padding(.bottom, Theme.Metrics.paddingMedium)
                    
                    detailsContent
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Factory method to create appropriate SongDetailBase view for media items
extension SongDetailBase where T == MPMediaItem {
    static func create(song: MPMediaItem, rank: Int,
                      @ViewBuilder headerContent: () -> HeaderContent,
                      @ViewBuilder detailsContent: () -> DetailsContent) -> some View {
        SongDetailBase<MPMediaItem, HeaderContent, DetailsContent>(
            song: song,
            rank: rank,
            headerContent: headerContent,
            detailsContent: detailsContent
        )
    }
}

// Factory method to create appropriate SongDetailBase view for Apple Music songs
extension SongDetailBase where T == Song {
    static func create(song: Song, rank: Int,
                      @ViewBuilder headerContent: () -> HeaderContent,
                      @ViewBuilder detailsContent: () -> DetailsContent) -> some View {
        SongDetailBase<Song, HeaderContent, DetailsContent>(
            song: song,
            rank: rank,
            headerContent: headerContent,
            detailsContent: detailsContent
        )
    }
}
