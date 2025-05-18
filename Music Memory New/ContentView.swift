import SwiftUI
import MediaPlayer
import MusicKit

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
            } else if !musicLibrary.hasAccess && !musicLibrary.hasAppleMusicAccess {
                VStack(spacing: 30) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Music Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 16) {
                        if !musicLibrary.hasAccess {
                            VStack(spacing: 8) {
                                Text("Local Music Library")
                                    .font(.headline)
                                Text("Allow access to your downloaded music in Settings")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        if !musicLibrary.hasAppleMusicAccess {
                            VStack(spacing: 8) {
                                Text("Apple Music")
                                    .font(.headline)
                                Text("Allow access to search the Apple Music catalog")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Button("Allow Access") {
                            musicLibrary.requestPermissionAndLoadLibrary()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            } else {
                SongsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
