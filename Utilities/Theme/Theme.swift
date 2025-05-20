//
//  Theme.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

/// Central theme definition for the application
enum Theme {
    /// Font sizes used throughout the application
    enum FontSizes {
        static let tiny: CGFloat = 9
        static let small: CGFloat = 12
        static let medium: CGFloat = 14
        static let regular: CGFloat = 16
        static let large: CGFloat = 18
        static let extraLarge: CGFloat = 20
    }
    
    /// Color palette for the application
    enum Colors {
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
        static let buttonText = Color.white
        static let badgeText = Color.secondary
    }
    
    /// Animation values
    enum Animation {
        static let buttonPressScale: CGFloat = 0.95
        static let standardDuration: Double = 0.2
        static let menuDuration: Double = 0.3
    }
    
    /// Opacity values
    enum Opacities {
        static let secondary: Double = 0.2
    }
    
    /// Time intervals for various operations
    enum TimeIntervals {
        static let safetyTimeout: Double = 5.0
        static let searchDebounce: UInt64 = 100_000_000  // 100ms in nanoseconds
    }
    
    /// Typography definitions for the application
    enum Typography {
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
        
        // Section headers
        static let sectionHeader = Font.headline.weight(.semibold)
        
        // Apple Music style typography
        static let songTitle = Font.system(size: FontSizes.regular, weight: .regular)
        static let artistName = Font.system(size: FontSizes.medium, weight: .regular)
        static let rankNumber = Font.system(size: FontSizes.regular, weight: .medium)
        static let explicitBadge = Font.system(size: FontSizes.tiny, weight: .medium)
    }
    
    /// Layout metrics for consistent spacing, sizing and layout
    enum Metrics {
        // Padding
        static let paddingTiny: CGFloat = 4
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 16
        static let paddingLarge: CGFloat = 24
        
        // Spacing
        static let spacingMicro: CGFloat = 2
        static let spacingTiny: CGFloat = 4
        static let spacingXSmall: CGFloat = 4
        static let spacingSmall: CGFloat = 8
        static let spacingMedium: CGFloat = 12
        static let spacingLarge: CGFloat = 16
        static let spacingXLarge: CGFloat = 24
        
        // Song row specific spacing
        static let songRowSpacing: CGFloat = 12
        static let songInfoSpacing: CGFloat = 2
        static let badgeSpacing: CGFloat = 6
        
        // Sizes
        static let iconSizeSmall: CGFloat = 16
        static let iconSizeMedium: CGFloat = 24
        static let iconSizeLarge: CGFloat = 32
        static let iconSizeXLarge: CGFloat = 60
        
        // Artwork sizes
        static let artworkSizeSmall: CGFloat = 44
        static let artworkSizeMedium: CGFloat = 100
        static let artworkSizeLarge: CGFloat = 250
        
        // Corner radius
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        
        // Rank width
        static let rankWidth: CGFloat = 33
        static let rankWidthExtended: CGFloat = 45
        
        // Song row heights
        static let songRowVerticalPadding: CGFloat = 8
        static let contextButtonSize: CGFloat = 20
        
        // Progress view scales
        static let progressViewSmallScale: CGFloat = 0.8
        static let progressViewScale: CGFloat = 1.2
        static let progressViewLargeScale: CGFloat = 1.5
        
        // Explicit badge
        static let explicitBadgePadding: CGFloat = 4
        static let explicitBadgeVerticalPadding: CGFloat = 1
        static let explicitBadgeCornerRadius: CGFloat = 2
        
        // Line weights
        static let borderLineWidth: CGFloat = 1.5
    }
    
    /// Shadow definitions for depth and elevation
    enum Shadows {
        static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
    }
    
    /// Reusable modifier components for consistent styling
    enum Modifiers {
        struct CardStyle: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .padding(Metrics.paddingMedium)
                    .background(Colors.background)
                    .cornerRadius(Metrics.cornerRadiusMedium)
                    .shadow(color: Shadows.medium.color,
                           radius: Shadows.medium.radius,
                           x: Shadows.medium.x,
                           y: Shadows.medium.y)
            }
        }
        
        struct PrimaryButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .padding(.vertical, Metrics.paddingSmall)
                    .padding(.horizontal, Metrics.paddingMedium)
                    .background(Colors.primary)
                    .foregroundColor(Colors.buttonText)
                    .cornerRadius(Metrics.cornerRadiusMedium)
                    .scaleEffect(configuration.isPressed ? Animation.buttonPressScale : 1)
                    .animation(.easeOut(duration: Animation.standardDuration), value: configuration.isPressed)
            }
        }
        
        struct SecondaryButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .padding(.vertical, Metrics.paddingSmall)
                    .padding(.horizontal, Metrics.paddingMedium)
                    .background(Color.clear)
                    .foregroundColor(Colors.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cornerRadiusMedium)
                            .stroke(Colors.primary, lineWidth: Metrics.borderLineWidth)
                    )
                    .scaleEffect(configuration.isPressed ? Animation.buttonPressScale : 1)
                    .animation(.easeOut(duration: Animation.standardDuration), value: configuration.isPressed)
            }
        }
        
        struct SearchBarStyle: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .padding(Metrics.paddingSmall)
                    .background(Colors.searchBackground)
                    .cornerRadius(Metrics.cornerRadiusMedium)
                    .padding(.horizontal)
            }
        }
        
        struct RankStyle: ViewModifier {
            let color: Color
            let width: CGFloat
            
            init(color: Color, width: CGFloat = Metrics.rankWidth) {
                self.color = color
                self.width = width
            }
            
            func body(content: Content) -> some View {
                content
                    .font(Typography.rankNumber)
                    .foregroundColor(color)
                    .frame(width: width, alignment: .center)
            }
        }
        
        struct ExplicitBadgeStyle: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .font(Typography.explicitBadge)
                    .foregroundColor(Colors.badgeText)
                    .padding(.horizontal, Metrics.explicitBadgePadding)
                    .padding(.vertical, Metrics.explicitBadgeVerticalPadding)
                    .background(Colors.badgeText.opacity(Opacities.secondary))
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.explicitBadgeCornerRadius))
            }
        }
    }
}

// MARK: - Shadow Data Structure
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(Theme.Modifiers.CardStyle())
    }
    
    func rankStyle(color: Color = Theme.Colors.primary) -> some View {
        modifier(Theme.Modifiers.RankStyle(color: color))
    }
    
    func searchBarStyle() -> some View {
        modifier(Theme.Modifiers.SearchBarStyle())
    }
    
    func explicitBadgeStyle() -> some View {
        modifier(Theme.Modifiers.ExplicitBadgeStyle())
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
    func iconStyle(size: CGFloat = Theme.Metrics.iconSizeMedium, color: Color = Theme.Colors.secondaryText) -> some View {
        self
            .font(.system(size: size))
            .foregroundColor(color)
    }
}
