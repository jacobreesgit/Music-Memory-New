//
//  SongArtworkView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer

struct ArtworkView: View {
    let uiImage: UIImage?
    let size: CGFloat
    
    init(uiImage: UIImage?, size: CGFloat = AppMetrics.artworkSizeMedium) {
        self.uiImage = uiImage
        self.size = size
    }
    
    var body: some View {
        if let image = uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .cornerRadius(AppMetrics.cornerRadiusSmall)
                .applyShadow(AppShadows.small)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall)
                    .fill(AppColors.secondaryBackground)
                    .frame(width: size, height: size)
                
                Image(systemName: "music.note")
                    .iconStyle(size: size * 0.4)
            }
            .applyShadow(AppShadows.small)
        }
    }
}

struct AsyncArtworkView: View {
    let url: URL?
    let size: CGFloat
    
    init(url: URL?, size: CGFloat = AppMetrics.artworkSizeMedium) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        CachedAsyncImage(url: url, size: size)
    }
}

struct LibraryArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let size: CGFloat
    
    init(artwork: MPMediaItemArtwork?, size: CGFloat = AppMetrics.artworkSizeMedium) {
        self.artwork = artwork
        self.size = size
    }
    
    var body: some View {
        if let artwork = artwork {
            ArtworkView(uiImage: artwork.image(at: CGSize(width: size, height: size)), size: size)
        } else {
            ArtworkView(uiImage: nil, size: size)
        }
    }
}
