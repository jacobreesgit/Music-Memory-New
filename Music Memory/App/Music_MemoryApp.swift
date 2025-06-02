import SwiftUI
import SwiftData
import MediaPlayer

@main
struct MusicMemoryApp: App {
    let container: ModelContainer
    @StateObject private var tracker: NowPlayingTracker
    @State private var hasSeededLibrary = UserDefaults.standard.bool(forKey: "hasSeededLibrary")
    
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
            ContentView()
                .environmentObject(tracker)
                .modelContainer(container)
                .onAppear {
                    requestMusicLibraryAccess()
                }
        }
    }
    
    private func requestMusicLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                print("✅ Music library access authorized")
                if !hasSeededLibrary {
                    Task {
                        await tracker.seedLibrary()
                        UserDefaults.standard.set(true, forKey: "hasSeededLibrary")
                        hasSeededLibrary = true
                    }
                }
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
