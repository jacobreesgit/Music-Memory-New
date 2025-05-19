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
    
    var body: some View {
        SongDetailBase(title: song.title ?? "Song") {
            // Header content
            VStack(spacing: AppMetrics.spacingMedium) {
                // Large artwork
                LibraryArtworkView(artwork: song.artwork, size: AppMetrics.artworkSizeLarge)
                    .applyShadow(AppShadows.medium)
                
                // Song title, artist and metrics
                SongInfoHeader(
                    title: song.title ?? "Unknown",
                    artist: song.artist ?? ""
                ) {
                    RankPlayCountView(
                        rank: rank,
                        playCount: song.playCount,
                        color: AppColors.primary
                    )
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
                
                // Cloud status
                DetailRow(title: "Source", value: song.isCloudItem ? "Apple Music" : "Local Library")
                
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
                
                // Show loading indicator while searching Apple Music
                if isSearchingAppleMusic {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Look up the song in Apple Music when the view appears
            if musicLibrary.hasAppleMusicAccess {
                fetchAppleMusicInfo()
            }
        }
    }
    
    private func fetchAppleMusicInfo() {
        guard let title = song.title, let artist = song.artist else { return }
        
        isSearchingAppleMusic = true
        
        // Search Apple Music for this song
        Task {
            // Create a specific query for better matching
            let query = "\(title) \(artist)"
            
            do {
                // Use MusicKit to search
                var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
                request.limit = 5 // Limit to top results for efficiency
                let response = try await request.response()
                
                // Look for a match in the results
                if let match = response.songs.first(where: {
                    musicLibrary.normalizeString($0.title) == musicLibrary.normalizeString(title) &&
                    musicLibrary.normalizeString($0.artistName) == musicLibrary.normalizeString(artist)
                }) {
                    await MainActor.run {
                        self.appleMusicSong = match
                        self.isSearchingAppleMusic = false
                    }
                } else {
                    await MainActor.run {
                        self.isSearchingAppleMusic = false
                    }
                }
            } catch {
                print("Error searching Apple Music: \(error)")
                await MainActor.run {
                    self.isSearchingAppleMusic = false
                }
            }
        }
    }
}
