//
//  Theme.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

/// Central theme definition for the application
enum Theme {
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
        
        // Special text
        static let rankNumber = Font.system(size: 16, weight: .bold)
    }
    
    /// Layout metrics for consistent spacing, sizing and layout
    enum Metrics {
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
                    .foregroundColor(.white)
                    .cornerRadius(Metrics.cornerRadiusMedium)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
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
                            .stroke(Colors.primary, lineWidth: 1.5)
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
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
            
            func body(content: Content) -> some View {
                content
                    .font(Typography.rankNumber)
                    .foregroundColor(color)
                    .frame(width: Metrics.rankWidth, alignment: .leading)
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
