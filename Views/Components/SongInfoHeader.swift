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
        VStack(spacing: AppMetrics.spacingSmall) {
            Text(title)
                .font(AppFonts.title2)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.center)
            
            Text(artist)
                .font(AppFonts.title3)
                .foregroundColor(AppColors.secondaryText)
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
        HStack(spacing: AppMetrics.spacingLarge) {
            VStack {
                Text("#\(rank)")
                    .font(AppFonts.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text("Rank")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            if let plays = playCount {
                VStack {
                    Text("\(plays)")
                        .font(AppFonts.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text("Plays")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .padding(.top, AppMetrics.paddingSmall)
    }
}

struct LibraryStatusView: View {
    let isInLibrary: Bool
    let playCount: Int?
    
    var body: some View {
        VStack {
            HStack(spacing: AppMetrics.spacingXSmall) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.title2)
                    .foregroundColor(isInLibrary ? AppColors.inLibrary : AppColors.secondaryText)
                
                Text(isInLibrary ? "In Library" : "Not in Library")
                    .font(AppFonts.title3)
                    .fontWeight(.medium)
                    .foregroundColor(isInLibrary ? AppColors.inLibrary : AppColors.secondaryText)
            }
            
            if isInLibrary, let playCount = playCount {
                Text("\(playCount) plays")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.inLibrary)
            }
        }
    }
}
