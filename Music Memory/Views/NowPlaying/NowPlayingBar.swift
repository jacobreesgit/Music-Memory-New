import SwiftUI
import MediaPlayer

struct NowPlayingBar: View {
    @ObservedObject var tracker: NowPlayingTracker
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            if let artworkData = tracker.currentSong?.albumArtworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.currentSong?.title ?? "Not Playing")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(tracker.currentSong?.artist ?? "—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play indicator
            if tracker.isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.green)
                    .symbolEffect(.pulse)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
