//
//  ContentView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

struct ContentView: View {
    @EnvironmentObject var musicLibrary: MusicLibraryModel
    
    var body: some View {
        NavigationStack {
            if musicLibrary.isLoading {
                VStack(spacing: Theme.Metrics.spacingLarge) {
                    ProgressView()
                        .scaleEffect(Theme.Metrics.progressViewLargeScale)
                    Text("Loading your music library...")
                        .font(Theme.Typography.subheadlineBold)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            } else if !musicLibrary.hasAccess && !musicLibrary.hasAppleMusicAccess {
                VStack(spacing: Theme.Metrics.spacingXLarge) {
                    Image(systemName: "music.note.list")
                        .iconStyle(size: Theme.Metrics.iconSizeXLarge, color: Theme.Colors.primary)
                    
                    Text("Music Access Required")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    VStack(spacing: Theme.Metrics.spacingMedium) {
                        if !musicLibrary.hasAccess {
                            VStack(spacing: Theme.Metrics.spacingSmall) {
                                Text("Local Music Library")
                                    .font(Theme.Typography.bodyBold)
                                Text("Allow access to your downloaded music in Settings")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        if !musicLibrary.hasAppleMusicAccess {
                            VStack(spacing: Theme.Metrics.spacingSmall) {
                                Text("Apple Music")
                                    .font(Theme.Typography.bodyBold)
                                Text("Allow access to search the Apple Music catalog")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: Theme.Metrics.spacingSmall) {
                        Button("Allow Access") {
                            musicLibrary.requestPermissionAndLoadLibrary()
                        }
                        .buttonStyle(Theme.Modifiers.PrimaryButtonStyle())
                        
                        Button("Open Settings") {
                            // Use guard to safely unwrap URL
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(Theme.Modifiers.SecondaryButtonStyle())
                    }
                }
                .padding(Theme.Metrics.paddingLarge)
            } else {
                SongsView()
            }
        }
        .onAppear {
            // Double check that we're trying to load on appear
            if !musicLibrary.hasAccess && !musicLibrary.hasAppleMusicAccess && !musicLibrary.isLoading {
                musicLibrary.requestPermissionAndLoadLibrary()
            }
        }
    }
}
