import SwiftUI
import SwiftData

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var tracker: NowPlayingTracker
    @State private var timeFilter: TimeFilter = .allTime
    @State private var songs: [TrackedSong] = []
    
    enum TimeFilter: String, CaseIterable {
        case allTime = "All Time"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        
        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .allTime:
                return nil
            case .thisWeek:
                return calendar.dateInterval(of: .weekOfYear, for: now)?.start
            case .thisMonth:
                return calendar.dateInterval(of: .month, for: now)?.start
            case .thisYear:
                return calendar.dateInterval(of: .year, for: now)?.start
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time filter picker
                Picker("Time Period", selection: $timeFilter) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Chart list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(songs.enumerated()), id: \.element.persistentID) { index, song in
                            ChartRow(
                                rank: index + 1,
                                song: song,
                                isCurrentlyPlaying: tracker.currentSong?.persistentID == song.persistentID
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for now playing bar
                }
            }
            .navigationTitle("Music Memory")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                fetchSongs()
            }
            .onChange(of: timeFilter) { _, _ in
                withAnimation {
                    fetchSongs()
                }
            }
            .onChange(of: tracker.currentSong) { _, _ in
                withAnimation {
                    fetchSongs()
                }
            }
        }
    }
    
    private func fetchSongs() {
        var descriptor = FetchDescriptor<TrackedSong>()
        
        // Apply time filter if needed
        if let startDate = timeFilter.startDate {
            descriptor.predicate = #Predicate<TrackedSong> { song in
                song.playEvents.contains { event in
                    event.timestamp >= startDate
                }
            }
        }
        
        do {
            var filteredSongs = try modelContext.fetch(descriptor)
            
            // Sort by total play count (or filtered play count)
            if timeFilter == .allTime {
                filteredSongs.sort { $0.totalPlayCount > $1.totalPlayCount }
            } else if let startDate = timeFilter.startDate {
                // Sort by plays within the time period
                filteredSongs.sort { song1, song2 in
                    let song1Plays = song1.playEvents.filter { $0.timestamp >= startDate }.count
                    let song2Plays = song2.playEvents.filter { $0.timestamp >= startDate }.count
                    return song1Plays > song2Plays
                }
            }
            
            // Update rankings
            for (index, song) in filteredSongs.enumerated() {
                song.updateRank(index + 1)
            }
            
            songs = filteredSongs
            
        } catch {
            print("Error fetching songs: \(error)")
        }
    }
}

struct ChartRow: View {
    let rank: Int
    let song: TrackedSong
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.title2.bold())
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            // Album artwork
            if let artworkData = song.albumArtworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .fontWeight(isCurrentlyPlaying ? .bold : .regular)
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text("\(song.totalPlayCount) plays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Rank movement - Fixed to use Color directly
                    Text(song.rankMovement.symbol)
                        .font(.caption.bold())
                        .foregroundColor(song.rankMovement.color)
                }
            }
            
            Spacer()
            
            // Currently playing indicator
            if isCurrentlyPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.green)
                    .symbolEffect(.pulse)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentlyPlaying ? Color.accentColor.opacity(0.1) : Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentlyPlaying ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
