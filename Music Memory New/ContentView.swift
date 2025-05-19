import SwiftUI
import MediaPlayer
import MusicKit

struct ContentView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    
    var body: some View {
        NavigationView {
            if musicLibrary.isLoading {
                VStack(spacing: AppMetrics.spacingLarge) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading your music library...")
                        .font(AppFonts.subheadlineBold)
                        .foregroundColor(AppColors.secondaryText)
                }
            } else if !musicLibrary.hasAccess && !musicLibrary.hasAppleMusicAccess {
                VStack(spacing: AppMetrics.spacingXLarge) {
                    Image(systemName: "music.note.list")
                        .iconStyle(size: AppMetrics.iconSizeXLarge, color: AppColors.primary)
                    
                    Text("Music Access Required")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.primaryText)
                    
                    VStack(spacing: AppMetrics.spacingMedium) {
                        if !musicLibrary.hasAccess {
                            VStack(spacing: AppMetrics.spacingSmall) {
                                Text("Local Music Library")
                                    .font(AppFonts.bodyBold)
                                Text("Allow access to your downloaded music in Settings")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        if !musicLibrary.hasAppleMusicAccess {
                            VStack(spacing: AppMetrics.spacingSmall) {
                                Text("Apple Music")
                                    .font(AppFonts.bodyBold)
                                Text("Allow access to search the Apple Music catalog")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: AppMetrics.spacingSmall) {
                        Button("Allow Access") {
                            musicLibrary.requestPermissionAndLoadLibrary()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(AppMetrics.paddingLarge)
            } else {
                SongsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
