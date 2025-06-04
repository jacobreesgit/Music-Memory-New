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
                    MainTabView()
                        .environmentObject(tracker)
                        .modelContainer(container)
                        .onAppear {
                            refreshTrackerState()
                        }
                }
            }
            .onAppear {
                initializeApp()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetToSetup)) { _ in
                resetToSetup()
            }
        }
    }
    
    private func initializeApp() {
        let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
        
        print("🔍 App initialization - Permission: \(hasPermission), Seeded: \(hasSeeded)")
        
        if hasPermission && hasSeeded {
            appState = .ready
        } else {
            appState = .firstTimeSetup
            
            if MPMediaLibrary.authorizationStatus() == .notDetermined {
                requestMusicLibraryAccess()
            }
        }
    }
    
    private func resetToSetup() {
        print("🔄 Resetting app to setup mode")
        appState = .firstTimeSetup
    }
    
    private func checkAndUpdateSetupStatus(isSeeding: Bool) {
        print("🔄 Seeding status changed: \(isSeeding)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
            
            print("🔍 Post-seeding check - Permission: \(hasPermission), Seeded: \(hasSeeded), IsSeeding: \(isSeeding)")
            
            if hasPermission && hasSeeded && !isSeeding {
                print("✅ Setup complete - transitioning to main app")
                appState = .ready
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    refreshTrackerState()
                }
            }
        }
    }
    
    private func refreshTrackerState() {
        print("🔄 Refreshing tracker state...")
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
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            refreshTrackerState()
                        }
                    }
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

struct MainTabView: View {
    @EnvironmentObject var tracker: NowPlayingTracker
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationView {
                    ChartView(tracker: tracker)
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Charts")
                }
                
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            
            NowPlayingBar(tracker: tracker)
                .padding(.bottom, 90)
        }
        .onAppear {
            print("📱 MainTabView appeared")
        }
    }
}

extension Notification.Name {
    static let resetToSetup = Notification.Name("resetToSetup")
}
