//
//  AppleMusicServiceProtocol.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import MusicKit

/// Protocol for interacting with the Apple Music API
protocol AppleMusicServiceProtocol {
    // MARK: - Properties
    
    /// Whether the app has access to Apple Music
    var hasAccess: Bool { get async }
    
    /// Whether a search is currently in progress
    var isSearching: Bool { get async }
    
    /// Current search results
    var searchResults: [Song] { get async }
    
    /// Current authorization status
    var authorizationStatus: MusicAuthorization.Status { get async }
    
    // MARK: - Authorization
    
    /// Request permission to access Apple Music
    func requestPermission() async throws -> Bool
    
    // MARK: - Search Operations
    
    /// Search the Apple Music catalog
    func searchMusic(query: String, limit: Int) async throws -> [Song]
    
    /// Perform multiple searches in parallel
    func batchSearch(queries: [String], limit: Int) async throws -> [String: [Song]]
    
    // MARK: - Search Management
    
    /// Cancel any ongoing search operation
    func cancelSearch()
    
    /// Clear search results and optionally clear cache
    func clearSearch() async
    
    // MARK: - Performance Optimization
    
    /// Preload common search terms for faster response
    func preloadCommonSearches(terms: [String]) async
}

/// Errors that can occur when interacting with Apple Music
enum AppleMusicServiceError: Error, LocalizedError {
    case permissionDenied
    case searchFailed(String)
    case emptyQuery
    case cancelled
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access Apple Music was denied."
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .emptyQuery:
            return "Search query cannot be empty."
        case .cancelled:
            return "Search was cancelled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
