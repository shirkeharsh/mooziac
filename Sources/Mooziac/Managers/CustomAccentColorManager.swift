import AppKit

public enum CustomAccentColorManager {
    public static let notificationName = NSNotification.Name("Mooziac_CustomAccentColorChanged")
    private static let userDefaultsKey = "Mooziac_customAccentHex"

    public static var hasCustomColor: Bool {
        return customColor != nil
    }

    public static var customColor: NSColor? {
        get {
            guard let hex = UserDefaults.standard.string(forKey: userDefaultsKey), !hex.isEmpty else {
                return nil
            }
            return NSColor(hex: hex)
        }
        set {
            if let color = newValue {
                UserDefaults.standard.set(color.hexString, forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
            NotificationCenter.default.post(name: notificationName, object: newValue)
        }
    }

    public static func resetToDefault() {
        customColor = nil
    }
}
