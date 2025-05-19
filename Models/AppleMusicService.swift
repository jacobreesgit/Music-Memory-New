//
//  AppleMusicService.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MusicKit

/// Service for interacting with the Apple Music API
class AppleMusicService {
    // Properties
    private(set) var searchResults: [Song] = []
    private(set) var isSearching: Bool = false
    private(set) var hasAccess: Bool = false
    private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    // Cache for recent search queries to prevent duplicate network requests
    private var recentSearchCache: [String: [Song]] = [:]
    private let maxCacheSize = 10
    
    init() {
        // Check Apple Music authorization
        authorizationStatus = MusicAuthorization.currentStatus
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Request permission for Apple Music
    func requestPermission() async -> Bool {
        let status = await MusicAuthorization.request()
        
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = status
            self.hasAccess = status == .authorized
        }
        
        return status == .authorized
    }
    
    /// Search Apple Music catalog with optimized performance
    func searchMusic(query: String, limit: Int = 15) async -> [Song] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasAccess && !trimmedQuery.isEmpty else {
            return []
        }
        
        // Check cache first to avoid unnecessary network requests
        if let cachedResults = recentSearchCache[trimmedQuery] {
            await MainActor.run { [weak self] in
                self?.searchResults = cachedResults
            }
            return cachedResults
        }
        
        await MainActor.run { [weak self] in
            self?.isSearching = true
        }
        
        do {
            var request = MusicCatalogSearchRequest(term: trimmedQuery, types: [Song.self])
            
            // Reduced limit for faster response
            request.limit = limit
            
            // Set language and storefront for better localization
            // request.includeTopResults = true // Uncomment if available in future MusicKit
            
            let response = try await request.response()
            let songs = Array(response.songs)
            
            // Update cache
            manageCacheAndAddResults(query: trimmedQuery, songs: songs)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.searchResults = songs
                self.isSearching = false
            }
            
            return songs
        } catch {
            print("Apple Music search error: \(error)")
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.searchResults = []
                self.isSearching = false
            }
            
            return []
        }
    }
    
    /// Manage search cache to limit memory usage
    private func manageCacheAndAddResults(query: String, songs: [Song]) {
        Task { @MainActor in
            // If cache is full, remove oldest entry
            if recentSearchCache.count >= maxCacheSize {
                let oldestKey = recentSearchCache.keys.first
                if let key = oldestKey {
                    recentSearchCache.removeValue(forKey: key)
                }
            }
            
            // Add new results to cache
            recentSearchCache[query] = songs
        }
    }
    
    /// Clear search results and cache
    func clearSearch() {
        Task { @MainActor in
            searchResults.removeAll()
            
            // Optionally clear cache if memory usage is a concern
            // recentSearchCache.removeAll()
        }
    }
}
