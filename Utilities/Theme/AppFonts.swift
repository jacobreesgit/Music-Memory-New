//
//  AppFonts.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

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
