//
//  AppMetrics.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

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

// MARK: - Helper Struct for Shadow
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct AppShadows {
    static let small = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    static let large = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
}
