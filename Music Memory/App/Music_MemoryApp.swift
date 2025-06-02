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
                            // Check if setup is complete
                            let hasPermission = MPMediaLibrary.authorizationStatus() == .authorized
                            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
                            
                            if hasPermission && hasSeeded && !isSeeding {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isSetupComplete = true
                                }
                            }
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
    }
    
    private func requestMusicLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                // The SetupView will handle the state changes
                print("Permission status: \(status)")
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
    }
}
