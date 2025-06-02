import SwiftUI
import MediaPlayer

struct SetupView: View {
    @ObservedObject var tracker: NowPlayingTracker
    @State private var permissionStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var hasSeededLibrary = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
    
    private var currentState: SetupState {
        switch permissionStatus {
        case .notDetermined:
            return .waitingForPermission
        case .denied, .restricted:
            return .permissionDenied
        case .authorized:
            if hasSeededLibrary && !tracker.isSeeding {
                return .completed
            } else {
                return .seeding
            }
        @unknown default:
            return .waitingForPermission
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                iconView
                    .symbolEffect(.pulse, isActive: currentState == .seeding)
                
                // Content based on state
                switch currentState {
                case .waitingForPermission:
                    waitingContent
                case .permissionDenied:
                    deniedContent
                case .seeding:
                    seedingContent
                case .completed:
                    EmptyView() // This state shouldn't be visible
                }
                
                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            checkPermissionStatus()
            // Auto-request permission if not determined
            if permissionStatus == .notDetermined {
                requestMusicAccess()
            }
        }
        .onReceive(tracker.$isSeeding) { isSeeding in
            if !isSeeding && tracker.seedingProgress >= 1.0 {
                UserDefaults.standard.set(true, forKey: "hasSeededLibrary")
                hasSeededLibrary = true
            }
        }
    }
    
    // MARK: - Icon View
    
    @ViewBuilder
    private var iconView: some View {
        switch currentState {
        case .waitingForPermission:
            Image(systemName: "music.note.house")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .symbolEffect(.pulse)
                
        case .permissionDenied:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                
        case .seeding:
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                
        case .completed:
            EmptyView()
        }
    }
    
    // MARK: - Waiting for Permission Content
    
    @ViewBuilder
    private var waitingContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Welcome to Music Memory")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Please allow access to your music library to track your listening habits and create your personal charts.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.2)
        }
    }
    
    // MARK: - Permission Denied Content
    
    @ViewBuilder
    private var deniedContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Music Access Required")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Music Memory needs access to your music library to track your listening habits and create your personal charts. Please grant permission in Settings.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Try Again") {
                    requestMusicAccess()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Seeding Content
    
    @ViewBuilder
    private var seedingContent: some View {
        VStack(spacing: 24) {
            // Title and subtitle
            VStack(spacing: 8) {
                Text("Setting up Music Memory")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Analyzing your music library...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Progress section
            VStack(spacing: 16) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: tracker.seedingProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.accentColor, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: tracker.seedingProgress)
                    
                    // Percentage text
                    Text("\(Int(tracker.seedingProgress * 100))%")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                
                // Song count
                HStack {
                    Text("\(tracker.currentSongIndex)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.accentColor)
                    
                    Text("of")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(tracker.totalSongsToProcess)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white)
                    
                    Text("songs")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Current song being processed
                if !tracker.currentProcessingSong.isEmpty {
                    VStack(spacing: 4) {
                        Text("Processing")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(tracker.currentProcessingSong)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 250)
                    }
                    .transition(.opacity)
                }
            }
            
            // Estimated time remaining
            if tracker.estimatedTimeRemaining > 0 {
                Text("About \(tracker.estimatedTimeRemaining) seconds remaining")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Start seeding when this view appears
            if !tracker.isSeeding {
                Task {
                    await tracker.seedLibrary()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkPermissionStatus() {
        permissionStatus = MPMediaLibrary.authorizationStatus()
    }
    
    private func requestMusicAccess() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                permissionStatus = status
                
                switch status {
                case .authorized:
                    print("✅ Music library access authorized")
                case .denied:
                    print("❌ Music library access denied")
                case .restricted:
                    print("⚠️ Music library access restricted")
                case .notDetermined:
                    print("❓ Music library access not determined")
                @unknown default:
                    print("❓ Unknown music library authorization status")
                }
            }
        }
    }
}

// MARK: - Setup States

enum SetupState {
    case waitingForPermission
    case permissionDenied
    case seeding
    case completed
}
