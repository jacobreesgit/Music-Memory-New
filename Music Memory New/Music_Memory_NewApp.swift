import SwiftUI
import MediaPlayer

@main
struct MusicMemoryApp: App {
    @StateObject private var musicLibrary = MusicLibraryModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(musicLibrary)
                .onAppear {
                    // Request permission and load data when app opens
                    musicLibrary.requestPermissionAndLoadLibrary()
                }
        }
    }
}
