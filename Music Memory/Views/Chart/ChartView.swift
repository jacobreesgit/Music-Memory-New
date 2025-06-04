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
        VStack(spacing: 0) {
            Picker("Time Period", selection: $timeFilter) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(songs.enumerated()), id: \.element.persistentID) { index, song in
                        ChartRow(
                            rank: index + 1,
                            song: song,
                            timeFilter: timeFilter,
                            isCurrentlyPlaying: tracker.currentSong?.persistentID == song.persistentID,
                            tracker: tracker
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Music Memory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if tracker.isSyncing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing")
                            .font(.caption)
                    }
                }
            }
        }
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
    
    // UPDATED: Proper filtering logic that separates All Time from time-filtered views
    private func fetchSongs() {
        do {
            var allSongs = try modelContext.fetch(FetchDescriptor<TrackedSong>())
            
            if let startDate = timeFilter.startDate {
                // UPDATED: Time-filtered views only show songs with actual PlayEvents in the period
                allSongs = allSongs.filter { song in
                    song.playCountInPeriod(since: startDate) > 0
                }
                
                // Sort by actual plays in the time period
                allSongs.sort { song1, song2 in
                    let song1Plays = song1.playCountInPeriod(since: startDate)
                    let song2Plays = song2.playCountInPeriod(since: startDate)
                    return song1Plays > song2Plays
                }
            } else {
                // UPDATED: All Time view includes system count + tracked plays
                // Filter out songs with no plays at all
                allSongs = allSongs.filter { song in
                    song.totalPlayCount > 0
                }
                
                // Sort by total play count (system + tracked)
                allSongs.sort { $0.totalPlayCount > $1.totalPlayCount }
            }
            
            // Update rankings based on current filter
            for (index, song) in allSongs.enumerated() {
                song.updateRank(index + 1)
            }
            
            songs = allSongs
            
        } catch {
            print("Error fetching songs: \(error)")
        }
    }
}

struct ChartRow: View {
    let rank: Int
    let song: TrackedSong
    let timeFilter: ChartView.TimeFilter
    let isCurrentlyPlaying: Bool
    let tracker: NowPlayingTracker
    
    // UPDATED: Proper play count calculation based on filter
    private var playCount: Int {
        if let startDate = timeFilter.startDate {
            // Time-filtered views: only count actual PlayEvents in period
            return song.playCountInPeriod(since: startDate)
        } else {
            // All Time view: system count + tracked plays
            return song.totalPlayCount
        }
    }
    
    // UPDATED: Play count breakdown that shows accurate source information
    private var playCountBreakdown: (realTime: Int, sync: Int, system: Int) {
        if let startDate = timeFilter.startDate {
            // Time-filtered views: only actual events in period
            let events = song.playsInPeriod(since: startDate)
            let realTime = events.filter { $0.source == .realTime }.count
            let sync = events.filter { $0.source == .systemSync }.count
            return (realTime, sync, 0) // No system count for time-filtered views
        } else {
            // All Time view: show breakdown including system baseline
            let realTime = song.realTimePlayCount
            let sync = song.systemSyncPlayCount
            let system = song.lastSystemPlayCount
            return (realTime, sync, system)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.title2.bold())
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            if let artwork = song.albumArtwork {
                Image(uiImage: artwork)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(playCount) plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // UPDATED: Show accurate source breakdown
                        let breakdown = playCountBreakdown
                        HStack(spacing: 4) {
                            if breakdown.system > 0 {
                                Label("\(breakdown.system)", systemImage: "music.note")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                    .labelStyle(.titleAndIcon)
                            }
                            if breakdown.realTime > 0 {
                                Label("\(breakdown.realTime)", systemImage: "circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .labelStyle(.titleAndIcon)
                            }
                            if breakdown.sync > 0 {
                                Label("\(breakdown.sync)", systemImage: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(song.rankMovement.symbol)
                        .font(.caption.bold())
                        .foregroundColor(song.rankMovement.color)
                }
            }
            
            Spacer()
            
            if isCurrentlyPlaying {
                VStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                        .symbolEffect(.pulse)
                    
                    if tracker.playbackMonitor.isTracking {
                        Image(systemName: "record.circle")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentlyPlaying ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}
