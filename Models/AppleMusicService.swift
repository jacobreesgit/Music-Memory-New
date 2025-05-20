//
//  AppleMusicService.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MusicKit

/// Errors that can occur when interacting with Apple Music
enum AppleMusicServiceError: Error {
    case permissionDenied
    case searchFailed(String)
    case emptyQuery
    case cancelled
    case networkError(Error)
}

/// Service for interacting with the Apple Music API using modern Swift concurrency
actor AppleMusicService {
    // Properties
    private(set) var searchResults: [Song] = []
    private(set) var isSearching: Bool = false
    private(set) var hasAccess: Bool = false
    private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    // Cache for recent search queries to prevent duplicate network requests
    private var recentSearchCache: [String: [Song]] = [:]
    private let maxCacheSize = 10
    
    // Task management for cancellation
    private var currentSearchTask: Task<[Song], Error>?
    
    init() {
        // Check Apple Music authorization
        authorizationStatus = MusicAuthorization.currentStatus
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Request permission for Apple Music using async/await
    func requestPermission() async throws -> Bool {
        // Use the built-in async API
        let status = await MusicAuthorization.request()
        
        // Update state
        self.authorizationStatus = status
        self.hasAccess = status == .authorized
        
        // Throw error if not authorized
        if status != .authorized {
            throw AppleMusicServiceError.permissionDenied
        }
        
        return true
    }
    
    /// Set the searching state (actor-isolated)
    private func setSearching(_ value: Bool) {
        isSearching = value
    }
    
    /// Set search results (actor-isolated)
    private func setSearchResults(_ results: [Song]) {
        searchResults = results
    }
    
    /// Cancel any ongoing search operation
    func cancelSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        // Reset search state
        if isSearching {
            setSearching(false)
        }
    }
    
    /// Update state after search completion
    private func updateStateAfterSearch(results: [Song]) {
        setSearchResults(results)
        setSearching(false)
    }
    
    /// Update state after search error
    private func handleSearchError() {
        setSearchResults([])
        setSearching(false)
    }
    
    /// Search Apple Music catalog with optimized performance and error handling
    func searchMusic(query: String, limit: Int = 15) async throws -> [Song] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate inputs
        guard hasAccess else {
            throw AppleMusicServiceError.permissionDenied
        }
        
        guard !trimmedQuery.isEmpty else {
            throw AppleMusicServiceError.emptyQuery
        }
        
        // Check cache first to avoid unnecessary network requests
        if let cachedResults = recentSearchCache[trimmedQuery] {
            setSearchResults(cachedResults)
            return cachedResults
        }
        
        // Cancel any existing search
        cancelSearch()
        
        // Set search state
        setSearching(true)
        
        // Create a new search task that can be cancelled
        let searchTask = Task<[Song], Error> {
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                var request = MusicCatalogSearchRequest(term: trimmedQuery, types: [Song.self])
                request.limit = limit
                
                // Execute the search with built-in async API
                let response = try await request.response()
                let songs = Array(response.songs)
                
                // Check for cancellation again
                try Task.checkCancellation()
                
                // Update cache
                await self.manageCacheAndAddResults(query: trimmedQuery, songs: songs)
                
                // Return results
                return songs
            } catch {
                if error is CancellationError {
                    throw AppleMusicServiceError.cancelled
                } else {
                    throw AppleMusicServiceError.networkError(error)
                }
            }
        }
        
        currentSearchTask = searchTask
        
        do {
            let results = try await searchTask.value
            updateStateAfterSearch(results: results)
            return results
        } catch {
            handleSearchError()
            throw error
        }
    }
    
    /// Perform multiple searches in parallel using task groups
    func batchSearch(queries: [String], limit: Int = 10) async throws -> [String: [Song]] {
        guard hasAccess else {
            throw AppleMusicServiceError.permissionDenied
        }
        
        guard !queries.isEmpty else {
            return [:]
        }
        
        // Use task group for structured concurrency
        return try await withThrowingTaskGroup(of: (String, [Song]).self) { group in
            for query in queries {
                let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !trimmedQuery.isEmpty {
                    group.addTask {
                        let songs = try await self.searchMusic(query: trimmedQuery, limit: limit)
                        return (trimmedQuery, songs)
                    }
                }
            }
            
            var results: [String: [Song]] = [:]
            
            // Collect results as they complete
            for try await (query, songs) in group {
                results[query] = songs
            }
            
            return results
        }
    }
    
    /// Manage search cache to limit memory usage
    private func manageCacheAndAddResults(query: String, songs: [Song]) async {
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
    
    /// Clear search results and cache
    func clearSearch() async {
        // Cancel any ongoing search
        cancelSearch()
        
        // Clear results and optionally clear cache
        setSearchResults([])
        
        // Optionally clear cache if memory usage is a concern
        // recentSearchCache.removeAll()
    }
    
    /// Preload common search terms in parallel to improve responsiveness
    func preloadCommonSearches(terms: [String]) async {
        try? await withThrowingTaskGroup(of: Void.self) { group in
            for term in terms.prefix(5) { // Limit to 5 terms to avoid overloading
                group.addTask {
                    // Use a smaller limit for preloading
                    _ = try? await self.searchMusic(query: term, limit: 5)
                }
            }
            
            // Wait for all preloads to complete or fail
            // We don't care about individual failures for preloading
            for try await _ in group { }
        }
    }
}

// MARK: - Extension for Combine Publishers
extension AppleMusicService {
    // Future extension point for Combine integration if needed
}
