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
        ScrollView {
            VStack(spacing: AppMetrics.spacingXLarge) {
                // Header with artwork and basic info
                VStack(spacing: AppMetrics.spacingMedium) {
                    // Large artwork
                    if let artwork = song.artwork {
                        ArtworkView(uiImage: artwork.image(at: CGSize(width: AppMetrics.artworkSizeLarge, height: AppMetrics.artworkSizeLarge)),
                                    size: AppMetrics.artworkSizeLarge)
                            .applyShadow(AppShadows.medium)
                    } else {
                        ArtworkView(uiImage: nil, size: AppMetrics.artworkSizeLarge)
                            .applyShadow(AppShadows.medium)
                    }
                    
                    // Song title and artist
                    VStack(spacing: AppMetrics.spacingSmall) {
                        Text(song.title ?? "Unknown")
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(AppFonts.title3)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Rank and play count indicators
                        HStack(spacing: AppMetrics.spacingLarge) {
                            VStack {
                                Text("#\(rank)")
                                    .font(AppFonts.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                Text("Rank")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            VStack {
                                Text("\(song.playCount)")
                                    .font(AppFonts.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                Text("Plays")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .padding(.top, AppMetrics.paddingSmall)
                    }
                }
                
                // Song details
                VStack(alignment: .leading, spacing: 0) {
                    Text("Song Details")
                        .font(AppFonts.bodyBold)
                        .padding(.bottom, AppMetrics.paddingMedium)
                    
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
                    }
                }
                .padding(.horizontal)
                
                // Show loading indicator while searching Apple Music
                if isSearchingAppleMusic {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(song.title ?? "Song")
        .navigationBarTitleDisplayMode(.inline)
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
