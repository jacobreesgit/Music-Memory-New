//
//  SongDetailView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

struct SongDetailView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let song: MPMediaItem
    let rank: Int
    @State private var appleMusicSong: Song?
    @State private var isSearchingAppleMusic: Bool = false
    
    // Check if this is an uploaded song to iCloud Music Library
    private var isUploadedToCloud: Bool {
        // Uploaded songs are cloud items but don't have protected assets (no DRM)
        // They also typically don't have an asset URL
        return song.isCloudItem && !song.hasProtectedAsset && song.assetURL == nil
    }
    
    // Check if we should search for this song on Apple Music
    private var shouldSearchAppleMusic: Bool {
        // Don't search if:
        // 1. Song is uploaded to iCloud (user's own file)
        // 2. We don't have Apple Music access
        // 3. Song doesn't have basic required info
        guard !isUploadedToCloud,
              musicLibrary.hasAppleMusicAccess,
              let _ = song.title,
              let _ = song.artist else {
            return false
        }
        return true
    }
    
    var body: some View {
        SongDetailBase<MPMediaItem, _, _>.create(song: song, rank: rank) {
            // Header content
            VStack(spacing: Theme.Metrics.spacingMedium) {
                // Large artwork
                LibraryArtworkView(artwork: song.artwork, size: Theme.Metrics.artworkSizeLarge)
                    .applyShadow(Theme.Shadows.medium)
                
                // Song title, artist and metrics
                SongInfoHeader(
                    title: song.title ?? "Unknown",
                    artist: song.artist ?? ""
                ) {
                    RankPlayCountView(
                        rank: rank,
                        playCount: song.playCount,
                        color: Theme.Colors.primary
                    )
                }
                
                // Open in Apple Music button - only show if we found a match
                if let appleMusicSong = appleMusicSong {
                    Button(action: {
                        openInAppleMusic(appleMusicSong)
                    }) {
                        HStack(spacing: Theme.Metrics.spacingSmall) {
                            Image(systemName: "applelogo")
                                .font(.system(size: Theme.FontSizes.regular, weight: .medium))
                            Text("Open in Apple Music")
                                .font(Theme.Typography.bodyBold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, Theme.Metrics.paddingSmall)
                        .padding(.horizontal, Theme.Metrics.paddingLarge)
                        .background(Theme.Colors.appleMusicColor)
                        .cornerRadius(Theme.Metrics.cornerRadiusMedium)
                    }
                    .padding(.top, Theme.Metrics.spacingSmall)
                } else if isSearchingAppleMusic {
                    HStack(spacing: Theme.Metrics.spacingSmall) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Finding on Apple Music...")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Metrics.spacingSmall)
                }
            }
        } detailsContent: {
            // Details content
            LazyVStack(spacing: 0) {
                DetailRow(title: "Album", value: song.albumTitle ?? "Unknown")
                DetailRow(title: "Genre", value: song.genre ?? "Unknown")
                DetailRow(title: "Duration", value: AppHelpers.formatDuration(song.playbackDuration))
                DetailRow(title: "Release Year", value: AppHelpers.formatYear(song.releaseDate))
                DetailRow(title: "Date Added", value: AppHelpers.formatDate(song.dateAdded))
                DetailRow(title: "Last Played", value: AppHelpers.formatDate(song.lastPlayedDate))
                
                if song.albumTrackNumber > 0 {
                    DetailRow(title: "Track Number", value: "\(song.albumTrackNumber)")
                }
                
                if song.discNumber > 0 {
                    DetailRow(title: "Disc Number", value: "\(song.discNumber)")
                }
                
                if song.beatsPerMinute > 0 {
                    DetailRow(title: "BPM", value: "\(song.beatsPerMinute)")
                }
                
                if let composer = song.composer, !composer.isEmpty {
                    DetailRow(title: "Composer", value: composer)
                }
                
                // Enhanced source information
                let sourceText = determineSourceText()
                DetailRow(title: "Source", value: sourceText)
                
                // If we have Apple Music song info, display additional details
                if let appleMusicSong = appleMusicSong {
                    if let isrc = appleMusicSong.isrc {
                        DetailRow(title: "ISRC", value: isrc)
                    }
                    
                    if let contentRating = appleMusicSong.contentRating {
                        let ratingText = contentRating == .explicit ? "Explicit" : "Clean"
                        DetailRow(title: "Content Rating", value: ratingText)
                    } else if song.isExplicitItem {
                        DetailRow(title: "Content", value: "Explicit")
                    }
                    
                    if appleMusicSong.hasLyrics {
                        DetailRow(title: "Lyrics", value: "Available", isLast: true)
                    }
                } else if song.isExplicitItem {
                    DetailRow(title: "Content", value: "Explicit", isLast: true)
                }
            }
        }
        .onAppear {
            // Only search if we should and haven't already
            if shouldSearchAppleMusic && appleMusicSong == nil && !isSearchingAppleMusic {
                fetchAppleMusicInfo()
            }
        }
    }
    
    private func determineSourceText() -> String {
        if isUploadedToCloud {
            return "Uploaded to iCloud Music Library"
        } else if song.isCloudItem && song.hasProtectedAsset {
            return "Apple Music (DRM Protected)"
        } else if song.isCloudItem {
            return "iCloud Music Library"
        } else {
            return "Local Library"
        }
    }
    
    private func fetchAppleMusicInfo() {
        guard shouldSearchAppleMusic,
              let title = song.title,
              let artist = song.artist else {
            return
        }
        
        // Reset states
        isSearchingAppleMusic = true
        
        print("DEBUG: Searching Apple Music for: '\(title)' by '\(artist)'")
        
        // Search Apple Music for this song
        Task {
            do {
                // Create multiple search queries with different combinations
                let searchQueries = [
                    "\(title) \(artist)",
                    title, // Sometimes artist name in the query can hurt results
                    "\"\(title)\" \(artist)" // Try with quotes for exact title match
                ]
                
                var foundMatch: Song?
                
                // Try each search query until we find a match
                for query in searchQueries {
                    if foundMatch != nil { break }
                    
                    print("DEBUG: Trying query: '\(query)'")
                    
                    var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
                    request.limit = 10 // Increase limit for better matching
                    
                    let response = try await request.response()
                    
                    // Look for exact matches first, then fuzzy matches
                    foundMatch = findBestMatch(in: Array(response.songs), title: title, artist: artist, album: song.albumTitle)
                    
                    if foundMatch != nil {
                        print("DEBUG: Found match with query: '\(query)'")
                        break
                    }
                }
                
                await MainActor.run {
                    if let match = foundMatch {
                        self.appleMusicSong = match
                        print("DEBUG: Successfully found Apple Music match")
                    } else {
                        print("DEBUG: No Apple Music match found after trying all queries")
                    }
                    self.isSearchingAppleMusic = false
                }
                
            } catch {
                print("DEBUG: Apple Music search error: \(error)")
                await MainActor.run {
                    self.isSearchingAppleMusic = false
                }
            }
        }
    }
    
    private func findBestMatch(in songs: [Song], title: String, artist: String, album: String?) -> Song? {
        let normalizedTitle = normalizeForMatching(title)
        let normalizedArtist = normalizeForMatching(artist)
        let normalizedAlbum = album != nil ? normalizeForMatching(album!) : nil
        
        // Look for exact matches first
        for song in songs {
            let songTitle = normalizeForMatching(song.title)
            let songArtist = normalizeForMatching(song.artistName)
            
            // Exact title and artist match
            if songTitle == normalizedTitle && songArtist == normalizedArtist {
                return song
            }
        }
        
        // Look for fuzzy matches
        for song in songs {
            let songTitle = normalizeForMatching(song.title)
            let songArtist = normalizeForMatching(song.artistName)
            let songAlbum = song.albumTitle != nil ? normalizeForMatching(song.albumTitle!) : nil
            
            // Title must be very similar
            if AppHelpers.fuzzyMatch(songTitle, normalizedTitle) {
                // Artist should also match
                if AppHelpers.fuzzyMatch(songArtist, normalizedArtist) {
                    // If we have album info, use it to help with matching
                    if let normalizedAlbum = normalizedAlbum,
                       let songAlbum = songAlbum {
                        if AppHelpers.fuzzyMatch(songAlbum, normalizedAlbum) {
                            return song
                        }
                    } else {
                        // No album info, just use title and artist match
                        return song
                    }
                }
            }
        }
        
        return nil
    }
    
    private func normalizeForMatching(_ string: String) -> String {
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
    
    private func openInAppleMusic(_ song: Song) {
        // Try to open the song directly in Apple Music using its URL
        if let url = song.url {
            print("DEBUG: Opening Apple Music URL: \(url)")
            UIApplication.shared.open(url)
        } else {
            // Fallback: open Apple Music app and search for the song
            let searchQuery = "\(song.title) \(song.artistName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchUrl = URL(string: "music://music.apple.com/search?term=\(searchQuery)") {
                print("DEBUG: Opening Apple Music search: \(searchUrl)")
                UIApplication.shared.open(searchUrl)
            } else {
                print("DEBUG: Failed to create Apple Music search URL")
            }
        }
    }
}
