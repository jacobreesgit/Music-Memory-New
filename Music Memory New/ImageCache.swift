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
    private var cache: [URL: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.jacobrees.MusicMemory.ImageCache", attributes: .concurrent)
    
    func image(for url: URL) -> UIImage? {
        var resultImage: UIImage?
        cacheQueue.sync {
            resultImage = cache[url]
        }
        return resultImage
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        cacheQueue.async(flags: .barrier) {
            self.cache[url] = image
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
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
                    RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall)
                        .fill(AppColors.secondaryBackground)
                    
                    Image(systemName: "music.note")
                        .iconStyle(size: size * 0.4)
                }
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(AppMetrics.cornerRadiusSmall)
        .applyShadow(AppShadows.small)
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
