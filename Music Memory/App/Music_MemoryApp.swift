import SwiftUI
import SwiftData
import MediaPlayer

@main
struct MusicMemoryApp: App {
    let container: ModelContainer
    @StateObject private var tracker: NowPlayingTracker
    @State private var isSetupComplete = false
    
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
                if isSetupComplete {
                    ContentView()
                        .environmentObject(tracker)
                        .modelContainer(container)
                        .transition(.opacity)
                } else {
                    SetupView(tracker: tracker)
                        .onReceive(tracker.$isSeeding) { isSeeding in
                            checkAndUpdateSetupStatus(isSeeding: isSeeding)
                        }
                        .transition(.opacity)
                }
            }
            .onAppear {
                checkIfSetupComplete()
                // Auto-request permission if needed
                if MPMediaLibrary.authorizationStatus() == .notDetermined {
                    requestMusicLibraryAccess()
                }
            }
        }
    }
    
    private func checkIfSetupComplete() {
        let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
        
        isSetupComplete = hasPermission && hasSeeded
        
        print("🔍 Setup check - Permission: \(hasPermission), Seeded: \(hasSeeded), Complete: \(isSetupComplete)")
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
                withAnimation(.easeInOut(duration: 0.5)) {
                    isSetupComplete = true
                }
            }
        }
    }
    
    private func requestMusicLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                print("🎵 Permission status updated: \(status)")
                checkIfSetupComplete()
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
