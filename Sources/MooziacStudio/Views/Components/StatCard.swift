import SwiftUI

public struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtext: String? = nil
    
    public init(title: String, value: String, icon: String, color: Color, subtext: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtext = subtext
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
                
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let subtext = subtext {
                Text(subtext)
                    .font(.system(size: 9))
                    .foregroundColor(color.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.panelDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ColorTheme.panelBorder, lineWidth: 1)
                )
        )
    }
}
