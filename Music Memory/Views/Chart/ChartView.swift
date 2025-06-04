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
    
    private func fetchSongs() {
        do {
            var allSongs = try modelContext.fetch(FetchDescriptor<TrackedSong>())
            
            if let startDate = timeFilter.startDate {
                allSongs = allSongs.filter { song in
                    !song.playsInPeriod(since: startDate).isEmpty
                }
                
                allSongs.sort { song1, song2 in
                    let song1Plays = song1.playsInPeriod(since: startDate).count
                    let song2Plays = song2.playsInPeriod(since: startDate).count
                    return song1Plays > song2Plays
                }
            } else {
                allSongs.sort { $0.totalPlayCount > $1.totalPlayCount }
            }
            
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
    
    private var playCount: Int {
        if let startDate = timeFilter.startDate {
            return song.playsInPeriod(since: startDate).count
        } else {
            return song.totalPlayCount
        }
    }
    
    private var playCountBreakdown: (realTime: Int, sync: Int, estimated: Int) {
        let events = timeFilter.startDate != nil ?
            song.playsInPeriod(since: timeFilter.startDate!) :
            song.playEvents
        
        let realTime = events.filter { $0.source == .realTime }.count
        let sync = events.filter { $0.source == .systemSync }.count
        let estimated = events.filter { $0.source == .estimated }.count
        
        return (realTime, sync, estimated)
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
                        
                        let breakdown = playCountBreakdown
                        if breakdown.realTime > 0 || breakdown.sync > 0 {
                            HStack(spacing: 4) {
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
                                if breakdown.estimated > 0 {
                                    Label("\(breakdown.estimated)", systemImage: "questionmark")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .labelStyle(.titleAndIcon)
                                }
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
