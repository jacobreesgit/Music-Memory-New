//
//  SongArtworkView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

struct ArtworkView: View {
    let uiImage: UIImage?
    let size: CGFloat
    
    init(uiImage: UIImage?, size: CGFloat = Theme.Metrics.artworkSizeMedium) {
        self.uiImage = uiImage
        self.size = size
    }
    
    var body: some View {
        if let image = uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .cornerRadius(Theme.Metrics.cornerRadiusSmall)
                .applyShadow(Theme.Shadows.small)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: size, height: size)
                
                Image(systemName: "music.note")
                    .iconStyle(size: size * 0.4)
            }
            .applyShadow(Theme.Shadows.small)
        }
    }
}

struct AsyncArtworkView: View {
    let url: URL?
    let size: CGFloat
    
    init(url: URL?, size: CGFloat = Theme.Metrics.artworkSizeMedium) {
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
    
    init(artwork: MPMediaItemArtwork?, size: CGFloat = Theme.Metrics.artworkSizeMedium) {
        self.artwork = artwork
        self.size = size
    }
    
    var body: some View {
        if let artwork = artwork {
            // Request artwork at 2x the display size for Retina clarity
            ArtworkView(uiImage: artwork.image(at: CGSize(width: size * 2, height: size * 2)), size: size)
        } else {
            ArtworkView(uiImage: nil, size: size)
        }
    }
}

// MARK: - Apple Music Artwork Extensions
extension AsyncArtworkView {
    /// Creates an AsyncArtworkView with high-resolution Apple Music artwork URL
    static func appleMusic(artwork: MusicKit.Artwork?, size: CGFloat) -> AsyncArtworkView {
        // Request artwork at screen scale for crisp display on Retina devices
        let scale = UIScreen.main.scale
        let pixelSize = Int(size * scale)
        let url = artwork?.url(width: pixelSize, height: pixelSize)
        return AsyncArtworkView(url: url, size: size)
    }
}
