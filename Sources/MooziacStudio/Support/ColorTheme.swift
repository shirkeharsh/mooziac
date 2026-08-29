import SwiftUI
import AppKit

public enum ColorTheme {
    public static let backgroundDark = Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
    public static let panelDark = Color(nsColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.15, alpha: 0.95))
    public static let panelBorder = Color.white.opacity(0.1)
    
    public static let accentOrange = Color(red: 1.0, green: 0.45, blue: 0.15)
    public static let accentBlue = Color(red: 0.20, green: 0.55, blue: 1.0)
    public static let accentPurple = Color(red: 0.65, green: 0.35, blue: 0.95)
    public static let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    public static let accentRed = Color(red: 1.0, green: 0.30, blue: 0.35)
    public static let accentTeal = Color(red: 0.15, green: 0.80, blue: 0.85)
    public static let accentYellow = Color(red: 1.0, green: 0.75, blue: 0.20)
    
    public static let terminalBackground = Color(nsColor: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1.0))
}

public struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    
    public init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ColorTheme.panelDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(ColorTheme.panelBorder, lineWidth: 1)
                    )
            )
    }
}
