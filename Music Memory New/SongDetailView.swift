import SwiftUI
import MediaPlayer

struct SongDetailView: View {
    let song: MPMediaItem
    let rank: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with artwork and basic info
                VStack(spacing: 16) {
                    // Large artwork
                    if let artwork = song.artwork {
                        Image(uiImage: artwork.image(at: CGSize(width: 250, height: 250)) ?? UIImage(systemName: "music.note")!)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 250, height: 250)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                    } else {
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
                        Text(song.title ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Rank and play count
                        HStack(spacing: 16) {
                            VStack {
                                Text("#\(rank)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                Text("Rank")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(song.playCount)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                Text("Plays")
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
                        DetailRow(title: "Genre", value: song.genre ?? "Unknown")
                        DetailRow(title: "Duration", value: formatDuration(song.playbackDuration))
                        DetailRow(title: "Release Year", value: formatYear(song.releaseDate))
                        DetailRow(title: "Date Added", value: formatDate(song.dateAdded))
                        DetailRow(title: "Last Played", value: formatDate(song.lastPlayedDate))
                        
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
                        
                        if song.isExplicitItem {
                            DetailRow(title: "Content", value: "Explicit", isLast: true)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(song.title ?? "Song")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatYear(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12)
            
            if !isLast {
                Divider()
            }
        }
    }
}
