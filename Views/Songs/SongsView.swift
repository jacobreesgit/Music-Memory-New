//
//  SongsView.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI
import MediaPlayer
import MusicKit

struct SongsView: View {
    @StateObject private var viewModel: SongsViewModel
    
    init() {
        // Initialize ViewModel with dependencies from container
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeSongsViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .iconStyle()
                
                TextField(viewModel.isNetworkConnected ? "Search library and Apple Music" : "Search library",
                          text: $viewModel.searchText)
                    .font(Theme.Typography.body)
                    .autocorrectionDisabled(false)
                    .autocapitalization(.none)
                    .onSubmit {
                        viewModel.submitSearch()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .iconStyle()
                    }
                }
            }
            .searchBarStyle()
            
            // Content area
            ScrollView {
                contentView
            }
        }
        .padding(.top, Theme.Metrics.paddingMedium)
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
    }
    
    // MARK: - Content View Builders
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .loading:
            loadingView
            
        case .content(let content):
            if content.isActiveSearch {
                if viewModel.sortedCombinedResults.isEmpty {
                    emptySearchResultsView
                } else {
                    searchResultsListView
                }
            } else {
                if viewModel.sortedSongs.isEmpty {
                    emptyLibraryView
                } else {
                    libraryListView
                }
            }
            
        case .error(let error):
            errorView(error)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            ProgressView()
                .scaleEffect(Theme.Metrics.progressViewLargeScale)
            Text("Searching...")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Metrics.paddingLarge)
    }
    
    @ViewBuilder
    private var emptySearchResultsView: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No results found",
            message: "No matches for '\(viewModel.searchText)'"
        )
        .padding(.top, Theme.Metrics.paddingLarge)
    }
    
    @ViewBuilder
    private var searchResultsListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.sortedCombinedResults.enumerated()), id: \.element.id) { index, result in
                searchResultRow(result: result, index: index)
                    .padding(.vertical, Theme.Metrics.spacingTiny)
            }
        }
        .padding(.horizontal, Theme.Metrics.paddingMedium)
        .padding(.top, Theme.Metrics.paddingSmall)
    }
    
    @ViewBuilder
    private func searchResultRow(result: SearchResult, index: Int) -> some View {
        Group {
            switch result.type {
            case .localSong(let song):
                NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                    SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                }
                
            case .appleMusicSong(let song, _):
                NavigationLink(destination: AppleMusicSongDetailView(song: song, rank: index + 1)) {
                    SongRowView<Song>.create(from: song, rank: index + 1)
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyLibraryView: some View {
        EmptyStateView(
            icon: "music.note",
            title: "No songs found",
            message: "Your music library appears to be empty or the app doesn't have permission to access it."
        )
        .padding(.top, Theme.Metrics.paddingLarge)
    }
    
    @ViewBuilder
    private var libraryListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.sortedSongs.enumerated()), id: \.element.persistentID) { index, song in
                NavigationLink(destination: SongDetailView(song: song, rank: index + 1)) {
                    SongRowView<MPMediaItem>.create(from: song, rank: index + 1)
                }
                .padding(.vertical, Theme.Metrics.spacingTiny)
            }
        }
        .padding(.horizontal, Theme.Metrics.paddingMedium)
        .padding(.top, Theme.Metrics.paddingSmall)
    }
    
    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: "exclamationmark.triangle")
                .iconStyle(size: Theme.Metrics.iconSizeXLarge, color: Theme.Colors.appleMusicColor)
            
            Text("Error")
                .font(Theme.Typography.bodyBold)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(error.localizedDescription)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadLibrary()
                }
            }
            .buttonStyle(Theme.Modifiers.PrimaryButtonStyle())
        }
        .padding()
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            ForEach(SongsViewModel.SortField.allCases, id: \.self) { field in
                Button(action: {
                    withAnimation(.easeInOut(duration: Theme.Animation.standardDuration)) {
                        viewModel.setSortField(field)
                    }
                }) {
                    HStack {
                        Label(field.rawValue, systemImage: field.systemImage)
                        Spacer()
                        if viewModel.sortField == field {
                            Image(systemName: viewModel.sortDirection.chevronImage)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.sortField.systemImage)
                    .font(.system(size: Theme.FontSizes.regular, weight: .medium))
                Image(systemName: viewModel.sortDirection.chevronImage)
                    .font(.system(size: Theme.FontSizes.small, weight: .medium))
            }
            .foregroundColor(Theme.Colors.primary)
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    
    var body: some View {
        VStack(spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: icon)
                .iconStyle(size: Theme.Metrics.iconSizeXLarge)
            
            Text(title)
                .font(Theme.Typography.bodyBold)
                .foregroundColor(Theme.Colors.secondaryText)
            
            if let message = message {
                Text(message)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, Theme.Metrics.paddingLarge)
    }
}
