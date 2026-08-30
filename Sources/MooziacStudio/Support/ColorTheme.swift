import SwiftUI
import AppKit

public enum StudioThemeMode: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case mooziac = "Mooziac"
    
    public var id: String { rawValue }
}

public class StudioThemeManager: ObservableObject {
    public static let shared = StudioThemeManager()
    
    @Published public var currentTheme: StudioThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "mooziac_studio_theme_mode")
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "mooziac_studio_theme_mode"),
           let mode = StudioThemeMode(rawValue: saved) {
            self.currentTheme = mode
        } else {
            self.currentTheme = .mooziac
        }
    }
    
    public func toggleTheme() {
        currentTheme = (currentTheme == .mooziac) ? .dark : .mooziac
    }
    
    public var background: Color {
        switch currentTheme {
        case .dark:
            return Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.05, alpha: 1.0))
        case .mooziac:
            return Color(red: 0.035, green: 0.043, blue: 0.063) // #090B10
        }
    }
    
    public var panelDark: Color {
        switch currentTheme {
        case .dark:
            return Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 0.98))
        case .mooziac:
            return Color(red: 0.063, green: 0.078, blue: 0.114, opacity: 0.94) // #10141D
        }
    }
    
    public var panelHover: Color {
        switch currentTheme {
        case .dark:
            return Color(nsColor: NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0))
        case .mooziac:
            return Color(red: 0.086, green: 0.110, blue: 0.157, opacity: 1.0) // #161C28
        }
    }
    
    public var panelBorder: Color {
        switch currentTheme {
        case .dark:
            return Color.white.opacity(0.12)
        case .mooziac:
            return Color(red: 0.54, green: 0.25, blue: 0.99, opacity: 0.26) // #8A3FFC glow border
        }
    }
    
    public var topBarBackground: Color {
        switch currentTheme {
        case .dark:
            return Color.black.opacity(0.65)
        case .mooziac:
            return Color(red: 0.035, green: 0.043, blue: 0.063, opacity: 0.85)
        }
    }
    
    public var brandAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.18, blue: 0.33), // #FF2D55 Pink
                Color(red: 0.54, green: 0.25, blue: 0.99), // #8A3FFC Purple
                Color(red: 0.0, green: 0.48, blue: 1.0)     // #007AFF Blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public enum ColorTheme {
    public static var backgroundDark: Color {
        StudioThemeManager.shared.background
    }
    public static var panelDark: Color {
        StudioThemeManager.shared.panelDark
    }
    public static var panelHover: Color {
        StudioThemeManager.shared.panelHover
    }
    public static var panelBorder: Color {
        StudioThemeManager.shared.panelBorder
    }
    
    // Monochrome Primary Structure
    public static let primaryWhite = Color(white: 0.98)
    public static let secondaryGray = Color(white: 0.65)
    public static let dimGray = Color(white: 0.40)
    public static let darkButtonFill = Color(white: 0.14)
    public static let solidButtonFill = Color(white: 0.95)
    public static let solidButtonText = Color(white: 0.05)
    
    // Micro Accents for Icons & Status Indicators
    public static let goldStar = Color(red: 1.0, green: 0.82, blue: 0.15)        // ⭐ Rich Gold
    public static let warningYellow = Color(red: 0.98, green: 0.72, blue: 0.16)   // ⚠️ Amber Yellow
    public static let statusGreen = Color(red: 0.20, green: 0.85, blue: 0.45)     // 🟢 Emerald Online
    public static let accentTeal = Color(red: 0.22, green: 0.74, blue: 0.97)      // 🍴 Cyan/Teal
    public static let accentPurple = Color(red: 0.72, green: 0.45, blue: 0.98)    // 🔔 Purple Bell
    public static let accentBlue = Color(red: 0.25, green: 0.60, blue: 1.0)       // 🔨 Blue Hammer
    public static let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.20)     // ⚡ Orange Bolt
    public static let accentPink = Color(red: 1.0, green: 0.18, blue: 0.33)       // 🌸 Website Pink
    public static let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    public static let accentRed = Color(red: 1.0, green: 0.35, blue: 0.38)
    public static let accentYellow = Color(red: 0.98, green: 0.72, blue: 0.16)
    
    public static let terminalBackground = Color(nsColor: NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1.0))
}

public struct GlassCard<Content: View>: View {
    @ObservedObject var theme: StudioThemeManager = .shared
    let content: Content
    var cornerRadius: CGFloat = 10
    
    public init(cornerRadius: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(theme.panelDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(theme.panelBorder, lineWidth: 1)
                    )
            )
    }
}

public struct StudioThemeBackground: View {
    @ObservedObject var theme: StudioThemeManager = .shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.background
            
            if theme.currentTheme == .mooziac {
                // Radial Glows matching mooziac.threeten.site
                RadialGradient(
                    gradient: Gradient(colors: [Color(red: 0.54, green: 0.25, blue: 0.99, opacity: 0.13), Color.clear]),
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [Color(red: 1.0, green: 0.18, blue: 0.33, opacity: 0.08), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [Color(red: 0.0, green: 0.48, blue: 1.0, opacity: 0.08), Color.clear]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 350
                )
            }
        }
        .ignoresSafeArea()
    }
}
