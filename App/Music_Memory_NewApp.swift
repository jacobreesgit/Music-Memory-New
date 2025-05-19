//
//  Music_Memory_NewApp.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer

@main
struct MusicMemoryApp: App {
    @StateObject private var musicLibrary = MusicLibraryModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    init() {
        // Configure UI appearance
        configureAppAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(musicLibrary)
                .environmentObject(networkMonitor)
                .onAppear {
                    // Request permission and load data when app opens
                    // Only request if not already loading
                    if !musicLibrary.isLoading {
                        musicLibrary.requestPermissionAndLoadLibrary()
                    }
                }
        }
    }
    
    private func configureAppAppearance() {
        // Apply global appearance settings
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.Colors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.Colors.primaryText)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.Colors.primaryText)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Set tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor(Theme.Colors.background)
    }
}
