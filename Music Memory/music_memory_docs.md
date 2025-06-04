# Music Memory - Complete Documentation

## Table of Contents
1. [App Overview](#app-overview)
2. [Architecture](#architecture)
3. [Play Detection System](#play-detection-system)
4. [Data Models](#data-models)
5. [File Structure](#file-structure)
6. [Setup & Onboarding](#setup--onboarding)
7. [Sync Strategies](#sync-strategies)
8. [User Interface](#user-interface)
9. [Technical Implementation](#technical-implementation)
10. [Troubleshooting](#troubleshooting)
11. [Future Enhancements](#future-enhancements)

---

## App Overview

### Purpose
Music Memory is an iOS app that creates personal music charts by tracking listening habits across the system music player. It provides detailed analytics about your music consumption, rank movements, and listening patterns.

### Core Features
- **Real-time Play Tracking**: Monitors active listening with precise completion detection
- **Personal Music Charts**: Ranked lists based on play frequency with time filtering
- **Rank Movement Indicators**: Visual feedback showing chart position changes
- **System Sync**: Captures plays that occurred while app was closed
- **Artwork Management**: Efficient local storage of album artwork
- **Push Notifications**: Alerts for significant chart movements
- **Time-based Analytics**: All-time, weekly, monthly, and yearly views

### Key Value Propositions
1. **Complete Coverage**: Tracks music whether app is open or closed
2. **Industry-Standard Detection**: Uses Last.fm-compatible completion criteria
3. **Rich Data**: Detailed tracking with completion percentages and durations
4. **Visual Feedback**: Clear indicators of tracking sources and reliability
5. **Privacy-Focused**: All data stored locally on device

---

## Architecture

### High-Level System Design

```
┌─────────────────────────────────────────────────────────────┐
│                     Music Memory App                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   UI Layer      │  │  Business Logic │  │ Data Layer  │  │
│  │                 │  │                 │  │             │  │
│  │ • ChartView     │  │ • NowPlayingTracker │ • SwiftData │  │
│  │ • SetupView     │  │ • PlaybackMonitor   │ • Models    │  │
│  │ • NowPlayingBar │  │ • SystemSyncManager │ • FileSystem│  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    iOS System Integration                   │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ MPMusicPlayer   │  │ MediaPlayer     │  │ UserNotif.  │  │
│  │ Controller      │  │ Framework       │  │ Framework   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### **UI Layer**
- **ChartView**: Main interface displaying ranked music charts
- **SetupView**: Onboarding flow for permissions and library seeding
- **NowPlayingBar**: Current song display with real-time status

#### **Business Logic Layer**
- **NowPlayingTracker**: Central coordinator managing all tracking operations
- **PlaybackMonitor**: Real-time playback tracking and completion detection
- **SystemSyncManager**: Background sync with iOS system play counts

#### **Data Layer**
- **SwiftData Models**: Core data persistence with CloudKit support
- **ArtworkManager**: File system management for album artwork
- **UserDefaults**: App state and configuration storage

---

## Play Detection System

### Three-Tier Detection Strategy

Music Memory uses a sophisticated three-tier approach to ensure no plays are missed:

#### **1. Real-Time Tracking (Primary)**
**When**: App is active or backgrounded with audio permission
**How**: `PlaybackMonitor` class actively tracks playback

```swift
// Completion Criteria (Following Last.fm Standard)
- Minimum: 30 seconds played
- Percentage: 50% of song duration
- Maximum: 4 minutes (auto-completes regardless of length)
```

**Data Captured**:
- Exact playback duration
- Song completion percentage
- Precise timestamps
- Play source: `.realTime`

**Advantages**:
- Most accurate tracking
- Rich metadata available
- Immediate feedback
- Custom completion logic

#### **2. System Sync (Secondary)**
**When**: App reopens after being closed
**How**: `SystemSyncManager` compares current vs. last known system play counts

**Process**:
1. Query `MPMediaQuery` for all songs
2. Compare `item.playCount` with stored `lastSystemPlayCount`
3. Create `PlayEvent`s for newly discovered plays
4. Distribute timestamps across time since last sync

**Data Captured**:
- Play count differences
- Estimated timestamps
- Play source: `.systemSync`

**Advantages**:
- Captures background plays
- Never loses system-detected plays
- Automatic on app launch

#### **3. Historical Estimation (Tertiary)**
**When**: Initial library seeding
**How**: Creates estimated play events for existing system play counts

**Process**:
1. For each song with `playCount > 0`
2. Create historical `PlayEvent`s distributed over past year
3. Mark with play source: `.estimated`

**Advantages**:
- Preserves listening history
- Provides baseline for charts
- Smooth transition from system to app tracking

### Completion Criteria Deep Dive

#### **Industry Research Basis**
Based on analysis of major music platforms:

- **Last.fm Official API**: 50% OR 4 minutes maximum
- **Spotify → Last.fm**: 40-50% completion requirement
- **Third-party scrobblers**: 40-50% default threshold
- **Streaming royalties**: 30 seconds minimum (Spotify, Apple Music)

#### **Implementation Logic**
```swift
func shouldCountAsPlay(totalTime: TimeInterval, songDuration: TimeInterval) -> Bool {
    // Must meet 30-second minimum
    guard totalTime >= 30.0 else { return false }
    
    // Auto-complete after 4 minutes (Last.fm standard)
    if totalTime >= 240.0 { return true }
    
    // Otherwise require 50% completion
    if songDuration > 0 {
        return (totalTime / songDuration) >= 0.5
    }
    
    return true
}
```

#### **Real-World Examples**
| Song Length | Required Time | Reasoning |
|-------------|---------------|-----------|
| 30 seconds | 30 seconds (100%) | Short tracks need full listen |
| 2 minutes | 1 minute (50%) | Standard pop song |
| 4 minutes | 2 minutes (50%) | Standard rock song |
| 8 minutes | 4 minutes (cap) | Long song, reasonable limit |
| 15 minutes | 4 minutes (cap) | Epic track, practical limit |

---

## Data Models

### TrackedSong Model

```swift
@Model
final class TrackedSong {
    @Attribute(.unique) var persistentID: UInt64    // iOS system identifier
    var title: String                               // Song title
    var artist: String                              // Primary artist
    var albumTitle: String?                         // Album name (optional)
    var artworkFileName: String?                    // Local artwork file
    var duration: TimeInterval                      // Song length in seconds
    var lastSystemPlayCount: Int                    // Last known system count
    var lastSyncTimestamp: Date                     // When last synced
    var lastKnownRank: Int?                         // Current chart position
    var previousRank: Int?                          // Previous chart position
    
    @Relationship(deleteRule: .cascade, inverse: \PlayEvent.song)
    var playEvents: [PlayEvent] = []               // All play instances
    
    // Computed Properties
    var totalPlayCount: Int                        // All plays combined
    var realTimePlayCount: Int                     // Live-tracked plays only
    var systemSyncPlayCount: Int                   // Sync-discovered plays
    var estimatedPlayCount: Int                    // Historical estimates
    var rankMovement: RankMovement                 // Chart movement indicator
    var albumArtwork: UIImage?                     // Artwork from file system
}
```

### PlayEvent Model

```swift
@Model
final class PlayEvent {
    var timestamp: Date                            // When play occurred
    var song: TrackedSong?                         // Associated song
    var source: PlaySource                         // How play was detected
    var playbackDuration: TimeInterval?            // Actual time played
    var songDuration: TimeInterval?                // Total song length
    var completionPercentage: Double?              // % of song completed
}

enum PlaySource {
    case realTime      // Live tracking (highest reliability)
    case systemSync    // Discovered via sync (medium reliability)
    case estimated     // Historical estimate (lowest reliability)
}
```

### Data Relationships

```
TrackedSong (1) ←→ (Many) PlayEvent
     ↓
ArtworkManager → File System
     ↓
iOS MediaPlayer Framework
```

---

## File Structure

```
Music Memory/
├── App/
│   ├── Music_MemoryApp.swift          // App entry point, setup flow
│   └── Info.plist                     // Permissions, background modes
│
├── Models/
│   ├── TrackedSong.swift              // Core song data model
│   └── PlayEvent.swift                // Individual play instances
│
├── ViewModels/
│   └── NowPlayingTracker.swift        // Central coordinator
│
├── Managers/
│   ├── PlaybackMonitor.swift          // Real-time tracking
│   ├── SystemSyncManager.swift        // Background sync
│   └── ArtworkManager.swift           // File system artwork
│
├── Views/
│   ├── Chart/
│   │   └── ChartView.swift            // Main chart interface
│   ├── NowPlaying/
│   │   └── NowPlayingBar.swift        // Current song display
│   └── Setup/
│       └── SetupView.swift            // Onboarding flow
│
└── Resources/
    ├── Assets.xcassets/               // App icons, colors
    └── MusicMemory.entitlements       // Music library access
```

### Key File Responsibilities

#### **Music_MemoryApp.swift**
- App lifecycle management
- Setup flow coordination
- Permission state tracking
- Transition between setup and main app
- **Current song state refresh after setup completion**

#### **NowPlayingTracker.swift**
- Central coordinator for all tracking
- Manages PlaybackMonitor and SystemSyncManager
- Handles ranking calculations
- Sends push notifications
- **Provides refresh methods for current song state**
- **Ensures consistent state across app transitions**

#### **PlaybackMonitor.swift**
- Real-time playback observation
- Completion criteria enforcement
- Timer-based progress tracking
- Play event creation

#### **SystemSyncManager.swift**
- Background play discovery
- System play count comparison
- Estimated timestamp distribution
- New song detection

---

## Setup & Onboarding

### Setup Flow Overview

```
App Launch → Permission Check → Library Seeding → State Refresh → Main App
     ↓              ↓                ↓               ↓              ↓
 Check Stored   Request Music    Process Songs   Update Current   Start Tracking
 Permissions    Library Access   + Artwork       Song State      + Display Charts
```

### Detailed Setup Process

#### **1. Permission Phase**
```swift
// Check current status
MPMediaLibrary.authorizationStatus()

// Request if needed
MPMediaLibrary.requestAuthorization { status in
    // Handle response
}
```

**States**:
- `.notDetermined` → Auto-request permission
- `.denied/.restricted` → Show settings guidance
- `.authorized` → Proceed to seeding

#### **2. Library Seeding Phase**
**Purpose**: Initial scan of entire music library

**Process**:
1. Query all songs: `MPMediaQuery.songs()`
2. For each song:
   - Create `TrackedSong` record
   - Extract and save artwork (300x300px JPEG)
   - Create historical `PlayEvent`s for existing play count
   - Update progress indicators

**Performance Optimizations**:
- Process in batches of 50 songs
- Save artwork with compression (80% quality)
- Background thread processing
- Progress updates every 10 songs

**Data Created**:
- `TrackedSong` records for all library songs
- Local artwork files in Documents/Artwork/
- Historical `PlayEvent`s with estimated timestamps
- UserDefaults flag: `hasSeededLibrary = true`

#### **3. State Refresh Phase** [NEW]
**Purpose**: Ensure current song state is accurate after setup
**Process**:
1. Refresh current song from system music player
2. Update playback state (playing/paused)
3. Sync tracking state with current playback

**Why This Matters**:
- Prevents blank now playing display after setup
- Ensures immediate tracking starts if music is playing
- Maintains consistency between system state and app state

#### **4. Transition to Main App**
**Trigger**: Seeding complete + permissions granted + state refreshed
**Animation**: Smooth fade transition with 0.5s duration
**Result**: User sees populated chart and current song immediately

---

## Sync Strategies

### When Syncing Occurs

#### **1. App Launch Sync**
**Trigger**: Every app launch
**Type**: Full sync if >4 hours since last, otherwise quick sync
**Purpose**: Catch plays that occurred while app was closed
**Post-Action**: Refresh current song state

#### **2. Foreground Sync**
**Trigger**: App returns from background
**Type**: Quick sync (current song only)
**Purpose**: Update current song's play count
**Post-Action**: Refresh current song and playback state

#### **3. Manual Sync**
**Trigger**: User pulls to refresh (future enhancement)
**Type**: Full sync
**Purpose**: User-initiated update

#### **4. Setup Completion Sync** [NEW]
**Trigger**: Library seeding completion
**Type**: State refresh only
**Purpose**: Initialize current song tracking

### Sync Process Details

#### **Full Sync Process**
```swift
1. Query MPMediaQuery.songs() for all tracks
2. For each track:
   - Compare current playCount vs lastSystemPlayCount
   - If difference > 0:
     - Calculate new plays: current - last
     - Create PlayEvents distributed over time gap
     - Update lastSystemPlayCount and lastSyncTimestamp
3. Save all changes to SwiftData
4. Update UserDefaults: lastFullSyncDate
5. Refresh current song state [NEW]
```

#### **Quick Sync Process**
```swift
1. Get current playing song only
2. Check if playCount increased
3. Create PlayEvents for new plays
4. Update song's sync timestamp
5. Refresh current song and playback state [NEW]
```

#### **Timestamp Distribution Algorithm**
When multiple plays are discovered, they're distributed across the time gap:

```swift
// Example: 3 new plays discovered, last sync was 6 hours ago
let timeGap = 6 * 60 * 60 // 6 hours in seconds
let playsToCreate = 3

for i in 0..<playsToCreate {
    let randomOffset = TimeInterval.random(in: 0...timeGap)
    let playTime = lastSyncTime.addingTimeInterval(randomOffset)
    // Create PlayEvent with estimated timestamp
}
```

**Benefits**:
- Realistic distribution vs. clustering
- Maintains chronological order
- Supports time-based analytics

---

## User Interface

### Main Chart View

#### **Layout Structure**
```
┌─────────────────────────────────────┐
│          Music Memory               │ ← Navigation Title
├─────────────────────────────────────┤
│ [All Time][Week][Month][Year]       │ ← Time Filter Picker
├─────────────────────────────────────┤
│ #1  [🎵] Song Title                 │ ← Chart Rows
│          Artist Name        ↑2      │
│          45 plays          [🔴●]    │
├─────────────────────────────────────┤
│ #2  [🎵] Another Song               │
│          Other Artist       ↓1      │
│          32 plays          [🔄]     │
│ ...                                 │
└─────────────────────────────────────┘
│ [🎵] Currently Playing Song         │ ← Now Playing Bar
│      Artist • [▶]                  │
└─────────────────────────────────────┘
```

#### **Chart Row Components**
- **Rank Number**: Bold, prominent positioning
- **Album Artwork**: 60x60px with fallback icon
- **Song Information**: Title (bold if playing), artist, album
- **Play Count**: Total with breakdown by source
- **Rank Movement**: Arrow indicators (↑3, ↓1, =, NEW)
- **Live Indicators**: Recording dot when actively tracking

#### **Source Indicators**
Visual breakdown of play sources:
- 🟢 **Real-time plays**: Green dot + count
- 🔵 **Sync plays**: Blue sync arrow + count  
- ⚪ **Estimated plays**: Gray question mark + count

### Time Filtering

#### **Filter Options**
- **All Time**: Complete listening history
- **This Week**: Monday to Sunday of current week
- **This Month**: First to last day of current month
- **This Year**: January 1st to December 31st

#### **Dynamic Ranking**
Rankings recalculate based on selected time period:
- Songs without plays in period are hidden
- Rank movements show period-specific changes
- Play counts reflect filtered timeframe only

### Now Playing Bar

#### **Information Display**
- **Artwork**: Current song's album art (50x50px)
- **Song Details**: Title and artist with truncation
- **Status Indicators**: 
  - 🌊 **Waveform**: Song is playing
  - 🔴 **Record dot**: Real-time tracking active

#### **Interactive Features** (Future)
- Tap to expand full player
- Swipe for quick actions
- Long press for song options

---

## Technical Implementation

### Real-Time Tracking Architecture

#### **PlaybackMonitor Class Design**
```swift
class PlaybackMonitor: ObservableObject {
    // State Management
    @Published var isTracking: Bool
    private var currentTrackingItem: MPMediaItem?
    private var playbackStartTime: Date?
    private var totalPlaybackTime: TimeInterval
    
    // Timing Infrastructure
    private var playbackTimer: Timer?
    private let timerInterval: TimeInterval = 1.0
    
    // Completion Logic
    private let minimumPlayTime: TimeInterval = 30.0
    private let minimumCompletionPercentage: Double = 0.5
    private let maximumRequiredTime: TimeInterval = 240.0
}
```

#### **State Management and Refresh** [NEW]

```swift
// NowPlayingTracker refresh methods
func refreshCurrentState() {
    updateCurrentSong()
    updatePlaybackState()
}

private func updateCurrentSong() {
    // Query current playing item from system
    // Match with tracked song in database
    // Update published currentSong property
}

private func updatePlaybackState() {
    // Check system playback state
    // Update published isPlaying property
}
```

**When Refresh Occurs**:
- App setup completion
- App foreground transition
- After sync operations
- Manual refresh calls

#### **Notification Observers**
```swift
// Song changes
NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)

// Playback state changes  
NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)

// App lifecycle
NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
```

#### **Timer-Based Progress Tracking**
- **Frequency**: 1-second intervals
- **Purpose**: Accumulate playback time, check completion criteria
- **Efficiency**: Only runs during active playback
- **Accuracy**: Handles pauses, seeks, and interruptions

### Artwork Management System

#### **Storage Strategy**
```swift
// File locations
Documents/Artwork/
├── 1234567890.jpg    // {persistentID}.jpg
├── 1234567891.jpg
└── ...
```

#### **Optimization Techniques**
- **Compression**: 80% JPEG quality for size vs. quality balance
- **Consistent sizing**: 300x300px for uniformity
- **Async loading**: Background threads for file operations
- **Memory management**: Load on-demand, cache in memory briefly

#### **Cleanup Process**
```swift
// Weekly maintenance
1. Get all tracked song artwork filenames
2. Scan artwork directory for orphaned files
3. Delete files not referenced by any song
4. Log cleanup statistics
```

### SwiftData Integration

#### **Schema Design**
```swift
let schema = Schema([
    TrackedSong.self,
    PlayEvent.self
])

let config = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true
)
```

#### **Query Patterns**
```swift
// Fetch songs by rank
FetchDescriptor<TrackedSong>(
    sortBy: [SortDescriptor(\.totalPlayCount, order: .reverse)]
)

// Fetch plays in time period
FetchDescriptor<PlayEvent>(
    predicate: #Predicate { event in
        event.timestamp >= startDate
    }
)

// Find specific song
FetchDescriptor<TrackedSong>(
    predicate: #Predicate { song in
        song.persistentID == targetID
    }
)
```

#### **Performance Optimizations**
- **Batch operations**: Process in chunks of 50-100 records
- **Lazy loading**: Use `@Relationship` for related data
- **Indexing**: Unique constraints on persistentID
- **Memory management**: Explicit save points, avoid large result sets

---

## Troubleshooting

### Common Issues & Solutions

#### **Problem: Missing Plays**
**Symptoms**: Songs played but not recorded in charts
**Possible Causes**:
1. App not running when song played
2. Completion criteria not met (too short/low percentage)
3. System sync hasn't occurred yet

**Solutions**:
1. Force sync by closing/reopening app
2. Check minimum listening requirements (30s + 50%)
3. Verify music library permissions
4. Check song source (streaming vs. downloaded)

#### **Problem: Blank Now Playing After Setup** [FIXED]
**Symptoms**: Now playing bar shows "Not Playing" even when music is playing after setup completion
**Root Cause**: Current song state not refreshed after transition from setup to main app

**Solution Applied**:
1. Added `refreshCurrentState()` method to `NowPlayingTracker`
2. App now automatically refreshes current song state after setup completion
3. State refresh also occurs on app foreground and after sync operations

#### **Problem: Duplicate Plays**
**Symptoms**: Same song showing multiple plays simultaneously
**Possible Causes**:
1. Both real-time and system sync detecting same play
2. App crash during play event creation
3. Timer overlap in PlaybackMonitor

**Solutions**:
1. Check PlayEvent timestamps for duplicates
2. Implement duplicate detection in sync process
3. Add state guards in PlaybackMonitor

#### **Problem: Artwork Not Loading**
**Symptoms**: Gray placeholders instead of album art
**Possible Causes**:
1. Files deleted from Documents/Artwork/
2. Permission issues with file system
3. Corrupted artwork files

**Solutions**:
1. Trigger artwork re-download during next sync
2. Check file permissions in Documents directory
3. Clear artwork cache and re-seed library

#### **Problem: Rankings Not Updating**
**Symptoms**: Charts show stale data despite new plays
**Possible Causes**:
1. SwiftData context not saving properly
2. UI not refreshing after data changes
3. Ranking calculation logic errors

**Solutions**:
1. Add explicit save calls after play events
2. Verify @Published properties trigger UI updates
3. Debug ranking algorithm with logging

### Debug Information

#### **Logging Categories**
```swift
🎵 // Song/playlist operations
📊 // Play event recording
🔄 // Sync operations  
🎧 // Current song updates
✅ // Successful operations
❌ // Errors and failures
⏭ // Skipped/filtered content
🔍 // State checks and validation
```

#### **Key Metrics to Monitor**
- Total tracked songs count
- Play events count by source type
- Last sync timestamp and success status
- Real-time tracking active duration
- Artwork cache hit/miss ratio
- **Current song refresh frequency and success rate** [NEW]

---

## Future Enhancements

### Near-Term Improvements
1. **Pull-to-refresh functionality** for manual sync
2. **Song detail views** with play history charts
3. **Export capabilities** for personal data
4. **Advanced filtering** by artist, album, genre
5. **Improved state management** for edge cases

### Long-Term Features
1. **Social sharing** of personal charts
2. **Mood-based analytics** using song metadata
3. **Listening streak tracking** and achievements
4. **Integration with external services** (Last.fm, etc.)
5. **Apple Watch companion app**

### Technical Debt
1. **Enhanced error handling** for network failures
2. **Background app refresh optimization**
3. **Memory usage optimization** for large libraries
4. **Automated testing suite** for critical paths
5. **Performance monitoring** and analytics

---

## Conclusion

Music Memory represents a sophisticated approach to personal music analytics, combining real-time tracking with intelligent background synchronization. The three-tier detection system ensures comprehensive coverage while maintaining data accuracy and user privacy.

The app's architecture balances technical complexity with user simplicity, providing rich insights without overwhelming the interface. By following industry standards for play detection and maintaining compatibility with established music tracking conventions, Music Memory offers reliable, meaningful data about personal listening habits.

Recent improvements to state management ensure a seamless user experience from setup through daily use, with automatic refresh mechanisms that maintain accurate current song display across all app transitions.

Key strengths include complete play coverage regardless of app state, detailed source attribution for transparency, efficient local storage that respects user privacy, and robust state management that handles edge cases gracefully. The modular design allows for future enhancements while maintaining core functionality stability.

Music Memory transforms passive music consumption into active insight, helping users understand and appreciate their musical journey through quantified, personal analytics.

---

*Documentation Version: 1.1*  
*Last Updated: June 2025*  
*App Version: 1.0*  
*Latest Changes: Fixed blank now playing issue after setup completion*
