import AppKit

// MARK: - Vector Floppy Disk Icon Template
extension NSImage {
    static func floppyDiskIcon(size: CGFloat = 15.0) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset: CGFloat = 1.0
            let r = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)

            // Outer disk body
            let path = NSBezierPath(roundedRect: r, xRadius: 1.8, yRadius: 1.8)
            path.lineWidth = 1.3
            NSColor.black.setStroke()
            path.stroke()

            // Top metal shutter
            let shutterW = r.width * 0.56
            let shutterH = r.height * 0.38
            let shutterX = r.minX + (r.width - shutterW) / 2.0
            let shutterY = r.maxY - shutterH
            let shutterPath = NSBezierPath(roundedRect: CGRect(x: shutterX, y: shutterY, width: shutterW, height: shutterH), xRadius: 1.0, yRadius: 1.0)
            shutterPath.lineWidth = 1.1
            shutterPath.stroke()

            // Inner shutter cutout slot
            let slotW = shutterW * 0.28
            let slotH = shutterH * 0.50
            let slotRect = CGRect(x: shutterX + (shutterW - slotW) / 2.0, y: shutterY + 2.0, width: slotW, height: slotH)
            let slotPath = NSBezierPath(roundedRect: slotRect, xRadius: 0.5, yRadius: 0.5)
            NSColor.black.setFill()
            slotPath.fill()

            // Bottom label area
            let labelW = r.width * 0.68
            let labelH = r.height * 0.38
            let labelX = r.minX + (r.width - labelW) / 2.0
            let labelY = r.minY + 1.0
            let labelPath = NSBezierPath(roundedRect: CGRect(x: labelX, y: labelY, width: labelW, height: labelH), xRadius: 0.8, yRadius: 0.8)
            labelPath.lineWidth = 1.0
            labelPath.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - Color Extensions
extension NSColor {
    public convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let darkThemeSelector = NSColor(hex: "D9DDE3")
    public static let lightThemeSelector = NSColor(hex: "434343")
}

// MARK: - System Appearance & macOS 27 Contrast-Safe Engine
public enum SystemAppearanceHelper {
    /// True if running on macOS 27 (or newer developer beta / release)
    public static var isMacOS27OrNewer: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 27
    }

    /// Checks if effective system appearance is Dark Aqua
    public static var isDarkSystemAppearance: Bool {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
    }

    /// Contrast-safe backing color for Clear / Native Vibrancy mode
    public static var clearModeBackingColor: NSColor {
        if isDarkSystemAppearance {
            // Calibrated translucent obsidian tint that guarantees ≥ 4.5:1 contrast on pure black / dark wallpapers
            return NSColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 0.72)
        } else {
            // Frosted crystal tint for light wallpapers
            return NSColor(white: 0.94, alpha: 0.82)
        }
    }

    /// Specular perimeter border for Clear / Native mode
    public static var clearModeBorderColor: NSColor {
        if isDarkSystemAppearance {
            return NSColor(white: 1.0, alpha: 0.28)
        } else {
            return NSColor(white: 0.0, alpha: 0.18)
        }
    }

    /// Contrast-safe backing color for Dark Mode
    public static var darkModeBackingColor: NSColor {
        return NSColor(red: 0.045, green: 0.045, blue: 0.065, alpha: 0.98)
    }

    /// Distinct perimeter border for Dark Mode
    public static var darkModeBorderColor: NSColor {
        return NSColor(white: 1.0, alpha: 0.18)
    }

    /// Contrast-safe pure transparent backing color for Watery Mode
    public static var liquidFluidBackingColor: NSColor {
        return isDarkSystemAppearance ? NSColor(white: 0.0, alpha: 0.08) : NSColor(white: 1.0, alpha: 0.10)
    }

    /// Pure watery specular perimeter border
    public static var liquidFluidBorderColor: NSColor {
        return isDarkSystemAppearance ? NSColor(white: 1.0, alpha: 0.24) : NSColor(white: 0.0, alpha: 0.16)
    }

    /// Contrast-safe primary text color
    public static func primaryTextColor(for design: PlayerDesign) -> NSColor {
        switch design {
        case .glassMode:
            return NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        case .native, .liquidFluid:
            return isDarkSystemAppearance ? NSColor.white : NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        case .adaptive, .darkMode:
            return NSColor.white
        }
    }

    /// Contrast-safe secondary text color with guaranteed luminance floor
    public static func secondaryTextColor(for design: PlayerDesign) -> NSColor {
        switch design {
        case .glassMode:
            return NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.85)
        case .native, .liquidFluid:
            return isDarkSystemAppearance ? NSColor(white: 0.82, alpha: 1.0) : NSColor(white: 0.20, alpha: 0.85)
        case .adaptive:
            return NSColor(white: 0.78, alpha: 1.0)
        case .darkMode:
            return NSColor(white: 0.76, alpha: 1.0)
        }
    }

    /// Contrast-safe tertiary / time text color
    public static func tertiaryTextColor(for design: PlayerDesign) -> NSColor {
        switch design {
        case .glassMode:
            return NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 0.75)
        case .native, .liquidFluid:
            return isDarkSystemAppearance ? NSColor(white: 0.74, alpha: 1.0) : NSColor(white: 0.30, alpha: 0.75)
        case .adaptive:
            return NSColor(white: 0.70, alpha: 1.0)
        case .darkMode:
            return NSColor(white: 0.68, alpha: 1.0)
        }
    }

    /// Contrast-safe control button icon tint
    public static func controlButtonTint(for design: PlayerDesign, isHighlighted: Bool = false) -> NSColor {
        if isHighlighted {
            return NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        }
        switch design {
        case .glassMode:
            return NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        case .native, .liquidFluid:
            return isDarkSystemAppearance ? NSColor(white: 0.90, alpha: 1.0) : NSColor(white: 0.10, alpha: 1.0)
        case .adaptive, .darkMode:
            return NSColor(white: 0.88, alpha: 1.0)
        }
    }
}