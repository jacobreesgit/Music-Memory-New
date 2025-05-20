//
//  ImageCache.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import UIKit
import SwiftUI

/// Errors that can occur during image loading and caching
enum ImageCacheError: Error {
    case invalidImageData
    case loadingFailed(String)
    case cancelled
    case invalidURL
}

/// Actor-based cache for loading and storing images with thread safety
actor ImageCache {
    // Singleton instance
    static let shared = ImageCache()
    
    // Use NSCache for automatic memory management based on system pressure
    private var cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.name = "com.jacobrees.MusicMemory.ImageCache"
        cache.countLimit = 100 // Maximum number of images to store
        return cache
    }()
    
    // Track ongoing image loading tasks to avoid duplicate requests
    private var loadingTasks: [URL: Task<UIImage, Error>] = [:]
    
    private init() {
        // Private initializer to enforce singleton pattern
        
        // Set up memory warning notification
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.clearCache()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Get an image from the cache if available
    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    /// Store an image in the cache
    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    
    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        
        // Cancel all ongoing image loading tasks
        for (_, task) in loadingTasks {
            task.cancel()
        }
        loadingTasks.removeAll()
    }
    
    /// Load an image from URL with async/await, using cache if available
    func loadImage(from url: URL) async throws -> UIImage {
        // Check cache first
        if let cachedImage = image(for: url) {
            return cachedImage
        }
        
        // Check if there's already a task loading this image
        if let existingTask = loadingTasks[url] {
            return try await existingTask.value
        }
        
        // Create a new task for loading
        let loadTask = Task<UIImage, Error> { [weak self] in
            guard let self else {
                throw ImageCacheError.loadingFailed("Self reference lost")
            }
            
            // Check for cancellation
            try Task.checkCancellation()
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Check for cancellation after network request
                try Task.checkCancellation()
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw ImageCacheError.loadingFailed("Invalid response")
                }
                
                // Create image from data
                guard let image = UIImage(data: data) else {
                    throw ImageCacheError.invalidImageData
                }
                
                // Store in cache
                self.setImage(image, for: url)
                
                // Remove task from tracking
                self.loadingTasks[url] = nil
                
                return image
            } catch {
                // Remove task from tracking
                self.loadingTasks[url] = nil
                
                if error is CancellationError {
                    throw ImageCacheError.cancelled
                } else {
                    throw ImageCacheError.loadingFailed(error.localizedDescription)
                }
            }
        }
        
        // Track the loading task
        loadingTasks[url] = loadTask
        
        // Return the result
        return try await loadTask.value
    }
    
    /// Prefetch multiple images in parallel using task groups
    func prefetchImages(urls: [URL]) async {
        try? await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                // Skip URLs already in cache
                if image(for: url) != nil {
                    continue
                }
                
                group.addTask {
                    _ = try? await self.loadImage(from: url)
                }
            }
            
            // Wait for all tasks to complete or fail
            for try await _ in group { }
        }
    }
}

/// SwiftUI view for displaying cached images with async loading
struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat
    @State private var image: UIImage?
    @State private var isLoading: Bool = false
    @State private var loadingTask: Task<Void, Never>?
    
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
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "music.note")
                            .iconStyle(size: size * 0.4)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(Theme.Metrics.cornerRadiusSmall)
        .applyShadow(Theme.Shadows.small)
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Cancel loading if view disappears
            loadingTask?.cancel()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        loadingTask = Task {
            do {
                let loadedImage = try await ImageCache.shared.loadImage(from: url)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Error loading image: \(error)")
                    
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// MARK: - High Resolution Image Helper
extension CachedAsyncImage {
    /// Creates a CachedAsyncImage that automatically requests high-resolution artwork
    static func highResolution(url: URL?, displaySize: CGFloat) -> CachedAsyncImage {
        // Calculate a higher resolution URL if possible
        let scaleFactor = UIScreen.main.scale
        let highResSize = displaySize * scaleFactor
        
        // If the URL has width and height parameters, try to modify them
        var highResURL = url
        if let url = url, var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            if var queryItems = components.queryItems {
                // Look for width or height parameters and update them
                for (index, item) in queryItems.enumerated() where ["width", "height", "w", "h"].contains(item.name.lowercased()) {
                    queryItems[index].value = "\(Int(highResSize))"
                }
                components.queryItems = queryItems
                highResURL = components.url
            }
        }
        
        return CachedAsyncImage(url: highResURL, size: displaySize)
    }
}
