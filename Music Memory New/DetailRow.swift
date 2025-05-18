import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12)
            
            if !isLast {
                Divider()
            }
        }
    }
}
