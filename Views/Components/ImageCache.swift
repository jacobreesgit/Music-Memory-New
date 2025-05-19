//
//  ImageCache.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import UIKit
import SwiftUI

class ImageCache {
    static let shared = ImageCache()
    private var cache: NSCache<NSURL, UIImage> = NSCache() // Use NSCache instead of Dictionary to better manage memory
    private let cacheQueue = DispatchQueue(label: "com.jacobrees.MusicMemory.ImageCache", attributes: .concurrent)
    
    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat
    @State private var image: UIImage?
    
    init(url: URL?, size: CGFloat) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall)
                        .fill(Theme.Colors.secondaryBackground)
                    
                    Image(systemName: "music.note")
                        .iconStyle(size: size * 0.4)
                }
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(Theme.Metrics.cornerRadiusSmall)
        .applyShadow(Theme.Shadows.small)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            return
        }
        
        // Load from network if not cached
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    await MainActor.run {
                        // Cache the image
                        ImageCache.shared.setImage(downloadedImage, for: url)
                        self.image = downloadedImage
                    }
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
}
