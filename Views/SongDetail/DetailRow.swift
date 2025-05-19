import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
                
                Text(value)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, AppMetrics.paddingSmall)
            
            if !isLast {
                Divider()
            }
        }
    }
}
