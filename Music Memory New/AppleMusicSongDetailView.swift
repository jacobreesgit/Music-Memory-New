import SwiftUI
import MusicKit
import MediaPlayer

struct AppleMusicSongDetailView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let song: Song
    let rank: Int
    
    var isInLibrary: Bool {
        musicLibrary.isAppleMusicSongInLibrary(song)
    }
    
    var localSongMatch: MPMediaItem? {
        musicLibrary.getLocalSongMatch(for: song)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.spacingXLarge) {
                // Header with artwork and basic info
                VStack(spacing: AppMetrics.spacingMedium) {
                    // Large artwork with library indicator
                    ZStack {
                        AsyncArtworkView(
                            url: song.artwork?.url(width: Int(AppMetrics.artworkSizeLarge), height: Int(AppMetrics.artworkSizeLarge)),
                            size: AppMetrics.artworkSizeLarge
                        )
                        .applyShadow(AppShadows.medium)
                        
                        // "In Library" indicator overlay
                        if isInLibrary {
                            VStack {
                                HStack {
                                    Spacer()
                                    VStack(spacing: AppMetrics.spacingXSmall) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(AppFonts.title2)
                                            .foregroundColor(.white)
                                            .background(AppColors.inLibrary)
                                            .clipShape(Circle())
                                        
                                        Text("IN LIBRARY")
                                            .font(AppFonts.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, AppMetrics.paddingSmall)
                                            .padding(.vertical, AppMetrics.spacingXSmall)
                                            .background(AppColors.inLibrary)
                                            .foregroundColor(.white)
                                            .cornerRadius(AppMetrics.cornerRadiusSmall)
                                    }
                                }
                                Spacer()
                            }
                            .padding(AppMetrics.paddingSmall)
                        }
                    }
                    
                    // Song title and artist
                    VStack(spacing: AppMetrics.spacingSmall) {
                        Text(song.title)
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                        
                        Text(song.artistName)
                            .font(AppFonts.title3)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        // Rank and library status indicators
                        HStack(spacing: AppMetrics.spacingLarge) {
                            VStack {
                                Text("#\(rank)")
                                    .font(AppFonts.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.appleMusicColor)
                                Text("Search Result")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            // Library status indicator
                            VStack {
                                HStack(spacing: AppMetrics.spacingXSmall) {
                                    Image(systemName: isInLibrary ? "checkmark.circle.fill" : "circle")
                                        .font(AppFonts.title2)
                                        .foregroundColor(isInLibrary ? AppColors.inLibrary : AppColors.secondaryText)
                                    Text(isInLibrary ? "In Library" : "Not in Library")
                                        .font(AppFonts.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(isInLibrary ? AppColors.inLibrary : AppColors.secondaryText)
                                }
                                if isInLibrary, let playCount = localSongMatch?.playCount {
                                    Text("\(playCount) plays")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.inLibrary)
                                }
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
                        
                        if let genres = song.genreNames.first {
                            DetailRow(title: "Genre", value: genres)
                        }
                        
                        if let duration = song.duration {
                            DetailRow(title: "Duration", value: AppHelpers.formatDuration(duration))
                        }
                        
                        if let releaseDate = song.releaseDate {
                            DetailRow(title: "Release Date", value: AppHelpers.formatDate(releaseDate))
                        }
                        
                        if let trackNumber = song.trackNumber {
                            DetailRow(title: "Track Number", value: "\(trackNumber)")
                        }
                        
                        if let discNumber = song.discNumber {
                            DetailRow(title: "Disc Number", value: "\(discNumber)")
                        }
                        
                        if let composerName = song.composerName {
                            DetailRow(title: "Composer", value: composerName)
                        }
                        
                        // Content rating
                        if let contentRating = song.contentRating {
                            let ratingText = contentRating == .explicit ? "Explicit" : "Clean"
                            DetailRow(title: "Content Rating", value: ratingText)
                        }
                        
                        // ISRC
                        if let isrc = song.isrc {
                            DetailRow(title: "ISRC", value: isrc)
                        }
                        
                        // Playback availability
                        DetailRow(title: "Source", value: "Apple Music Catalog")
                        
                        // Library status with additional info
                        if isInLibrary {
                            if let localSong = localSongMatch {
                                DetailRow(title: "Library Status", value: "Available in Your Library")
                                DetailRow(title: "Play Count", value: "\(localSong.playCount)")
                                
                                if let lastPlayed = localSong.lastPlayedDate {
                                    DetailRow(title: "Last Played", value: AppHelpers.formatDate(lastPlayed))
                                }
                            }
                        } else {
                            DetailRow(title: "Library Status", value: "Not in Your Library")
                        }
                        
                        if song.hasLyrics {
                            DetailRow(title: "Lyrics", value: "Available", isLast: true)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
