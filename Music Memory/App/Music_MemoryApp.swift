import SwiftUI
import SwiftData
import MediaPlayer

@main
struct MusicMemoryApp: App {
    let container: ModelContainer
    @StateObject private var tracker: NowPlayingTracker
    @State private var appState: AppState = .initializing
    
    enum AppState {
        case initializing
        case firstTimeSetup
        case ready
    }
    
    init() {
        do {
            let schema = Schema([TrackedSong.self, PlayEvent.self])
            let config = ModelConfiguration(schema: schema)
            container = try ModelContainer(for: schema, configurations: config)
            
            let context = container.mainContext
            _tracker = StateObject(wrappedValue: NowPlayingTracker(modelContext: context))
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState {
                case .initializing:
                    LoadingView()
                    
                case .firstTimeSetup:
                    SetupView(tracker: tracker)
                        .onReceive(tracker.$isSeeding) { isSeeding in
                            checkAndUpdateSetupStatus(isSeeding: isSeeding)
                        }
                    
                case .ready:
                    ContentView()
                        .environmentObject(tracker)
                        .modelContainer(container)
                        .onAppear {
                            // Refresh current song state when main view appears
                            refreshTrackerState()
                        }
                }
            }
            .onAppear {
                initializeApp()
            }
        }
    }
    
    private func initializeApp() {
        // Check setup status immediately
        let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
        
        print("🔍 App initialization - Permission: \(hasPermission), Seeded: \(hasSeeded)")
        
        if hasPermission && hasSeeded {
            // Already set up, go directly to ready state
            appState = .ready
        } else {
            // First time setup needed
            appState = .firstTimeSetup
            
            // Auto-request permission if needed
            if MPMediaLibrary.authorizationStatus() == .notDetermined {
                requestMusicLibraryAccess()
            }
        }
    }
    
    private func checkAndUpdateSetupStatus(isSeeding: Bool) {
        print("🔄 Seeding status changed: \(isSeeding)")
        
        // Add a small delay to ensure UserDefaults has been written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
            
            print("🔍 Post-seeding check - Permission: \(hasPermission), Seeded: \(hasSeeded), IsSeeding: \(isSeeding)")
            
            if hasPermission && hasSeeded && !isSeeding {
                print("✅ Setup complete - transitioning to main app")
                appState = .ready
                
                // Refresh tracker state after transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    refreshTrackerState()
                }
            }
        }
    }
    
    private func refreshTrackerState() {
        print("🔄 Refreshing tracker state...")
        
        // Force update current song state
        tracker.refreshCurrentState()
    }
    
    private func requestMusicLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                print("🎵 Permission status updated: \(status)")
                
                if status == .authorized {
                    let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
                    if hasSeeded {
                        appState = .ready
                        
                        // Refresh tracker state after transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            refreshTrackerState()
                        }
                    }
                    // If not seeded, stay in setup state to begin seeding
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "music.note.house")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse)
                
                Text("Music Memory")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.2)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var tracker: NowPlayingTracker
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ChartView(tracker: tracker)
            
            NowPlayingBar(tracker: tracker)
                .padding(.bottom, 20)
        }
        .onAppear {
            print("📱 ContentView appeared")
        }
    }
}
