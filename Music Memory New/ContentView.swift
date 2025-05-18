import SwiftUI

struct ContentView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    
    var body: some View {
        NavigationView {
            if musicLibrary.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading your music library...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if !musicLibrary.hasAccess {
                VStack(spacing: 30) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Music Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please allow access to your music library in Settings")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding()
            } else {
                SongsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
