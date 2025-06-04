import Foundation
import MediaPlayer
import Combine

@MainActor
class PlaybackMonitor: ObservableObject {
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    
    // Current tracking state
    @Published var isTracking = false
    private var currentTrackingItem: MPMediaItem?
    private var playbackStartTime: Date?
    private var playbackStartPosition: TimeInterval = 0
    private var totalPlaybackTime: TimeInterval = 0
    private var hasBeenMarkedComplete = false
    
    // Completion criteria - simplified to 50% only
    private let minimumCompletionPercentage: Double = 0.5   // 50% of song
    
    // Callbacks
    var onPlayCompleted: ((MPMediaItem, TimeInterval, TimeInterval, Double) -> Void)?
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Track when songs change
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleSongChange()
                }
            }
            .store(in: &cancellables)
        
        // Track playback state changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handlePlaybackStateChange()
                }
            }
            .store(in: &cancellables)
        
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Start tracking current song if playing
        handleSongChange()
    }
    
    private func handleSongChange() {
        // Finalize previous song if it was being tracked
        finalizePreviousTrack()
        
        // Start tracking new song if available
        if let currentItem = musicPlayer.nowPlayingItem,
           musicPlayer.playbackState == .playing {
            startTracking(item: currentItem)
        }
    }
    
    private func handlePlaybackStateChange() {
        switch musicPlayer.playbackState {
        case .playing:
            if let currentItem = musicPlayer.nowPlayingItem {
                if currentTrackingItem?.persistentID != currentItem.persistentID {
                    // New song started playing
                    finalizePreviousTrack()
                    startTracking(item: currentItem)
                } else if !isTracking {
                    // Same song resumed
                    resumeTracking()
                }
            }
            
        case .paused, .stopped:
            pauseTracking()
            
        case .interrupted:
            pauseTracking()
            
        default:
            break
        }
    }
    
    private func startTracking(item: MPMediaItem) {
        guard !isTracking || currentTrackingItem?.persistentID != item.persistentID else { return }
        
        print("🎵 Starting playback tracking: \(item.title ?? "Unknown")")
        
        currentTrackingItem = item
        playbackStartTime = Date()
        playbackStartPosition = musicPlayer.currentPlaybackTime
        totalPlaybackTime = 0
        hasBeenMarkedComplete = false
        isTracking = true
        
        startPlaybackTimer()
    }
    
    private func resumeTracking() {
        guard let _ = currentTrackingItem, !isTracking else { return }
        
        print("▶️ Resuming playback tracking")
        
        playbackStartTime = Date()
        playbackStartPosition = musicPlayer.currentPlaybackTime
        isTracking = true
        
        startPlaybackTimer()
    }
    
    private func pauseTracking() {
        guard isTracking else { return }
        
        print("⏸ Pausing playback tracking")
        
        // Accumulate playback time
        if let startTime = playbackStartTime {
            totalPlaybackTime += Date().timeIntervalSince(startTime)
        }
        
        isTracking = false
        stopPlaybackTimer()
    }
    
    // Mark as nonisolated so it can be called from deinit
    nonisolated private func finalizePreviousTrack() {
        Task { @MainActor in
            _finalizePreviousTrack()
        }
    }
    
    private func _finalizePreviousTrack() {
        guard let item = currentTrackingItem else { return }
        
        // Accumulate final playback time if still tracking
        if isTracking, let startTime = playbackStartTime {
            totalPlaybackTime += Date().timeIntervalSince(startTime)
        }
        
        // Check if play should be counted as complete
        if shouldCountAsPlay(item: item) && !hasBeenMarkedComplete {
            let songDuration = item.playbackDuration
            let completionPercentage = songDuration > 0 ? totalPlaybackTime / songDuration : 0
            
            print("✅ Play completed: \(item.title ?? "Unknown")")
            print("   Duration: \(totalPlaybackTime)s / \(songDuration)s (\(Int(completionPercentage * 100))%)")
            
            onPlayCompleted?(item, totalPlaybackTime, songDuration, completionPercentage)
            hasBeenMarkedComplete = true
        }
        
        // Reset tracking state
        currentTrackingItem = nil
        playbackStartTime = nil
        totalPlaybackTime = 0
        isTracking = false
        hasBeenMarkedComplete = false
        stopPlaybackTimer()
    }
    
    private func shouldCountAsPlay(item: MPMediaItem) -> Bool {
        let songDuration = item.playbackDuration
        
        // Must have valid song duration
        guard songDuration > 0 else {
            print("⏭ Skipped - no song duration available")
            return false
        }
        
        // Must meet 50% completion requirement
        let completionPercentage = totalPlaybackTime / songDuration
        guard completionPercentage >= minimumCompletionPercentage else {
            print("⏭ Skipped - insufficient completion: \(Int(completionPercentage * 100))% < \(Int(minimumCompletionPercentage * 100))%")
            return false
        }
        
        return true
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPlaybackProgress()
            }
        }
    }
    
    // Mark as nonisolated so it can be called from deinit
    nonisolated private func stopPlaybackTimer() {
        Task { @MainActor in
            _stopPlaybackTimer()
        }
    }
    
    private func _stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func checkPlaybackProgress() {
        guard let item = currentTrackingItem,
              let startTime = playbackStartTime,
              isTracking else { return }
        
        // Update total playback time
        let currentSessionTime = Date().timeIntervalSince(startTime)
        let currentTotalTime = totalPlaybackTime + currentSessionTime
        
        // Check if we've hit completion criteria and haven't already marked it
        if !hasBeenMarkedComplete && shouldCountAsPlayForTime(item: item, totalTime: currentTotalTime) {
            let songDuration = item.playbackDuration
            let completionPercentage = songDuration > 0 ? currentTotalTime / songDuration : 0
            
            print("✅ Play completed (during playback): \(item.title ?? "Unknown")")
            print("   Duration: \(currentTotalTime)s / \(songDuration)s (\(Int(completionPercentage * 100))%)")
            
            onPlayCompleted?(item, currentTotalTime, songDuration, completionPercentage)
            hasBeenMarkedComplete = true
        }
    }
    
    private func shouldCountAsPlayForTime(item: MPMediaItem, totalTime: TimeInterval) -> Bool {
        let songDuration = item.playbackDuration
        
        // Must have valid song duration
        guard songDuration > 0 else { return false }
        
        // Must meet 50% completion requirement
        let completionPercentage = totalTime / songDuration
        return completionPercentage >= minimumCompletionPercentage
    }
    
    deinit {
        finalizePreviousTrack()
        musicPlayer.endGeneratingPlaybackNotifications()
        stopPlaybackTimer()
    }
}
