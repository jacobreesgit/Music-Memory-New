//
//  SongInfoHeader.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

struct SongInfoHeader: View {
    let title: String
    let artist: String
    let additionalInfo: AnyView
    
    init(title: String, artist: String, @ViewBuilder additionalInfo: () -> some View) {
        self.title = title
        self.artist = artist
        self.additionalInfo = AnyView(additionalInfo())
    }
    
    var body: some View {
        VStack(spacing: Theme.Metrics.spacingSmall) {
            Text(title)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
            
            Text(artist)
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                
            additionalInfo
        }
    }
}

struct RankPlayCountView: View {
    let rank: Int
    let playCount: Int?
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Metrics.spacingLarge) {
            VStack {
                Text("#\(rank)")
                    .font(Theme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text("Rank")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            if let plays = playCount {
                VStack {
                    Text("\(plays)")
                        .font(Theme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text("Plays")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .padding(.top, Theme.Metrics.paddingSmall)
    }
}

struct LibraryStatusView: View {
    let isInLibrary: Bool
    let playCount: Int?
    
    var body: some View {
        VStack {
            HStack(spacing: Theme.Metrics.spacingXSmall) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.title2)
                    .foregroundColor(isInLibrary ? Theme.Colors.inLibrary : Theme.Colors.secondaryText)
                
                Text(isInLibrary ? "In Library" : "Not in Library")
                    .font(Theme.Typography.title3)
                    .fontWeight(.medium)
                    .foregroundColor(isInLibrary ? Theme.Colors.inLibrary : Theme.Colors.secondaryText)
            }
            
            if isInLibrary, let playCount = playCount {
                Text("\(playCount) plays")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.inLibrary)
            }
        }
    }
}
