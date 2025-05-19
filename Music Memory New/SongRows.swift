import SwiftUI
import MediaPlayer
import MusicKit

// MARK: - Local Library Song Row
struct SongRow: View {
    let song: MPMediaItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle()
            
            // Artwork
            if let artwork = song.artwork {
                ArtworkView(uiImage: artwork.image(at: CGSize(width: AppMetrics.artworkSizeSmall, height: AppMetrics.artworkSizeSmall)),
                           size: AppMetrics.artworkSizeSmall)
            } else {
                ArtworkView(uiImage: nil, size: AppMetrics.artworkSizeSmall)
            }
            
            // Song info
            VStack(alignment: .leading, spacing: AppMetrics.spacingXSmall) {
                Text(song.title ?? "Unknown")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play count and cloud indicator
            VStack(alignment: .trailing, spacing: AppMetrics.spacingXSmall) {
                HStack(spacing: AppMetrics.spacingXSmall) {
                    Text("\(song.playCount) plays")
                        .font(AppFonts.subheadlineBold)
                        .foregroundColor(AppColors.primary)
                    
                    if song.isCloudItem {
                        Image(systemName: "cloud")
                            .iconStyle(size: AppMetrics.iconSizeSmall)
                    }
                }
                
                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(AppFonts.caption2)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, AppMetrics.spacingXSmall)
    }
}

// MARK: - Apple Music Song Row
struct AppleMusicSongRow: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    let song: Song
    let rank: Int
    
    var isInLibrary: Bool {
        musicLibrary.isAppleMusicSongInLibrary(song)
    }
    
    var localSongPlayCount: Int? {
        musicLibrary.getLocalSongMatch(for: song)?.playCount
    }
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Rank
            Text("#\(rank)")
                .rankStyle(color: AppColors.appleMusicColor)
            
            // Artwork
            ZStack {
                AsyncArtworkView(url: song.artwork?.url(width: Int(AppMetrics.artworkSizeSmall), height: Int(AppMetrics.artworkSizeSmall)),
                               size: AppMetrics.artworkSizeSmall)
                
                // "In Library" indicator overlay
                if isInLibrary {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppFonts.caption)
                                .foregroundColor(.white)
                                .background(AppColors.inLibrary)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: AppMetrics.spacingXSmall) {
                HStack {
                    Text(song.title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                }
                
                Text(song.artistName)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Apple Music indicator, play count (if in library), and album
            VStack(alignment: .trailing, spacing: AppMetrics.spacingXSmall) {
                if isInLibrary {
                    HStack(spacing: AppMetrics.spacingXSmall) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.inLibrary)
                        Text("In Library")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.inLibrary)
                    }
                    
                    if let playCount = localSongPlayCount {
                        Text("\(playCount) plays")
                            .font(AppFonts.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.inLibrary)
                    }
                } else {
                    HStack(spacing: AppMetrics.spacingXSmall) {
                        Image(systemName: "applelogo")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.appleMusicColor)
                        Text("Apple Music")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.appleMusicColor)
                    }
                }
                
                Text(song.albumTitle ?? "")
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppMetrics.spacingXSmall)
    }
}
