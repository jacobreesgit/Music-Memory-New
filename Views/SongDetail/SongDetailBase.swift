//
//  SongDetailBase.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

struct SongDetailBase<HeaderContent: View, DetailsContent: View>: View {
    let title: String
    let headerContent: HeaderContent
    let detailsContent: DetailsContent
    
    init(title: String,
         @ViewBuilder headerContent: () -> HeaderContent,
         @ViewBuilder detailsContent: () -> DetailsContent) {
        self.title = title
        self.headerContent = headerContent()
        self.detailsContent = detailsContent()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.spacingXLarge) {
                // Header content from caller
                headerContent
                
                // Song details from caller
                VStack(alignment: .leading, spacing: 0) {
                    Text("Song Details")
                        .font(AppFonts.bodyBold)
                        .padding(.bottom, AppMetrics.paddingMedium)
                    
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
