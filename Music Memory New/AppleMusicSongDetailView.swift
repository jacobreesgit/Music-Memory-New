import SwiftUI
import MusicKit

struct AppleMusicSongDetailView: View {
    let song: Song
    let rank: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with artwork and basic info
                VStack(spacing: 16) {
                    // Large artwork
                    AsyncImage(url: song.artwork?.url(width: 250, height: 250)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 250, height: 250)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 250, height: 250)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        }
                        .shadow(radius: 10)
                    }
                    
                    // Song title and artist
                    VStack(spacing: 8) {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(song.artistName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Rank and Apple Music indicator
                        HStack(spacing: 16) {
                            VStack {
                                Text("#\(rank)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("Search Result")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "applelogo")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    Text("Apple Music")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                                Text("Catalog")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Song details
                VStack(alignment: .leading, spacing: 0) {
                    Text("Song Details")
                        .font(.headline)
                        .padding(.bottom, 16)
                    
                    LazyVStack(spacing: 0) {
                        DetailRow(title: "Album", value: song.albumTitle ?? "Unknown")
                        
                        if let genres = song.genreNames.first {
                            DetailRow(title: "Genre", value: genres)
                        }
                        
                        if let duration = song.duration {
                            DetailRow(title: "Duration", value: formatDuration(duration))
                        }
                        
                        if let releaseDate = song.releaseDate {
                            DetailRow(title: "Release Date", value: formatDate(releaseDate))
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
