//
//  DetailRow.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                Text(value)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, Theme.Metrics.paddingSmall)
            
            if !isLast {
                Divider()
            }
        }
    }
}
