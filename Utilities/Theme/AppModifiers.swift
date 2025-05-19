//
//  AppModifiers.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

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
