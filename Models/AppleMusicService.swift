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
    
    init() {
        // Check Apple Music authorization
        authorizationStatus = MusicAuthorization.currentStatus
        hasAccess = authorizationStatus == .authorized
    }
    
    /// Request permission for Apple Music
    func requestPermission() async -> Bool {
        let status = await MusicAuthorization.request()
        
        await MainActor.run {
            self.authorizationStatus = status
            self.hasAccess = status == .authorized
        }
        
        return status == .authorized
    }
    
    /// Search Apple Music catalog
    func searchMusic(query: String) async -> [Song] {
        guard hasAccess && !query.isEmpty else {
            return []
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            let songs = Array(response.songs)
            
            await MainActor.run {
                self.searchResults = songs
                self.isSearching = false
            }
            
            return songs
        } catch {
            print("Apple Music search error: \(error)")
            
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            
            return []
        }
    }
    
    /// Clear search results
    func clearSearch() {
        searchResults.removeAll()
    }
}
