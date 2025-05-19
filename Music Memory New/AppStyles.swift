//
//  AppColors.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//


import SwiftUI

// MARK: - Color Scheme
struct AppColors {
    // Main brand colors
    static let primary = Color.purple
    static let secondary = Color.blue
    
    // Status colors
    static let inLibrary = Color.green
    static let appleMusicColor = Color.red
    
    // Background colors
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.systemGray6)
    static let searchBackground = Color(.systemGray5)
    
    // Text colors
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
}

// MARK: - Typography
struct AppFonts {
    // Titles
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.bold)
    static let title2 = Font.title2.weight(.bold)
    static let title3 = Font.title3.weight(.semibold)
    
    // Body text
    static let body = Font.body
    static let bodyBold = Font.body.weight(.semibold)
    
    // Secondary text
    static let subheadline = Font.subheadline
    static let subheadlineBold = Font.subheadline.weight(.medium)
    static let caption = Font.caption
    static let caption2 = Font.caption2
    
    // Special text
    static let rankNumber = Font.system(size: 16, weight: .bold)
}

// MARK: - Layout Metrics
struct AppMetrics {
    // Padding
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    
    // Spacing
    static let spacingXSmall: CGFloat = 4
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let spacingXLarge: CGFloat = 24
    
    // Sizes
    static let iconSizeSmall: CGFloat = 16
    static let iconSizeMedium: CGFloat = 24
    static let iconSizeLarge: CGFloat = 32
    static let iconSizeXLarge: CGFloat = 60
    
    static let artworkSizeSmall: CGFloat = 50
    static let artworkSizeMedium: CGFloat = 100
    static let artworkSizeLarge: CGFloat = 250
    
    // Corner radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    
    // Rank width
    static let rankWidth: CGFloat = 40
}

// MARK: - Shadows
struct AppShadows {
    static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
}

// MARK: - Common View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppMetrics.paddingMedium)
            .background(AppColors.background)
            .cornerRadius(AppMetrics.cornerRadiusMedium)
            .shadow(color: AppShadows.medium.color, 
                   radius: AppShadows.medium.radius, 
                   x: AppShadows.medium.x, 
                   y: AppShadows.medium.y)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, AppMetrics.paddingSmall)
            .padding(.horizontal, AppMetrics.paddingMedium)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppMetrics.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, AppMetrics.paddingSmall)
            .padding(.horizontal, AppMetrics.paddingMedium)
            .background(Color.clear)
            .foregroundColor(AppColors.primary)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusMedium)
                    .stroke(AppColors.primary, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppMetrics.paddingSmall)
            .background(AppColors.searchBackground)
            .cornerRadius(AppMetrics.cornerRadiusMedium)
            .padding(.horizontal)
    }
}

struct RankStyle: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(AppFonts.rankNumber)
            .foregroundColor(color)
            .frame(width: AppMetrics.rankWidth, alignment: .leading)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func rankStyle(color: Color = AppColors.primary) -> some View {
        modifier(RankStyle(color: color))
    }
    
    func searchBarStyle() -> some View {
        modifier(SearchBarStyle())
    }
    
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, 
                   radius: shadow.radius, 
                   x: shadow.x, 
                   y: shadow.y)
    }
}

// MARK: - Icon View Styles
extension Image {
    func iconStyle(size: CGFloat = AppMetrics.iconSizeMedium, color: Color = AppColors.secondaryText) -> some View {
        self
            .font(.system(size: size))
            .foregroundColor(color)
    }
}

// MARK: - Artwork View Components
struct ArtworkView: View {
    let uiImage: UIImage?
    let size: CGFloat
    
    init(uiImage: UIImage?, size: CGFloat = AppMetrics.artworkSizeMedium) {
        self.uiImage = uiImage
        self.size = size
    }
    
    var body: some View {
        if let image = uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .cornerRadius(AppMetrics.cornerRadiusSmall)
                .applyShadow(AppShadows.small)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall)
                    .fill(AppColors.secondaryBackground)
                    .frame(width: size, height: size)
                
                Image(systemName: "music.note")
                    .iconStyle(size: size * 0.4)
            }
            .applyShadow(AppShadows.small)
        }
    }
}

struct AsyncArtworkView: View {
    let url: URL?
    let size: CGFloat
    
    init(url: URL?, size: CGFloat = AppMetrics.artworkSizeMedium) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall)
                    .fill(AppColors.secondaryBackground)
                
                Image(systemName: "music.note")
                    .iconStyle(size: size * 0.4)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(AppMetrics.cornerRadiusSmall)
        .applyShadow(AppShadows.small)
    }
}

// MARK: - Helper Struct for Shadow
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Helper Functions
struct AppHelpers {
    static func formatDuration(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func formatYear(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}