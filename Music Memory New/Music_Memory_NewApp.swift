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
    
    init() {
        // Configure UI appearance
        configureAppAppearance()
    }
    
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
    
    private func configureAppAppearance() {
        // Apply global appearance settings
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Set tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor(AppColors.background)
    }
}
