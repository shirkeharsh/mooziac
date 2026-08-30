import Foundation

public enum PlayerDesign: String, CaseIterable {
    case adaptive = "Adaptive (Ambient Dark)"
    case darkMode = "OLED Dark Mode"
    case glassMode = "Pure Crystal Glass Mode"
    case native = "macOS Native Vibrancy"
    case liquidFluid = "Liquid Fluid Glow"

    public var isGlass: Bool {
        return self == .glassMode
    }

    public var isNativeVibrancy: Bool {
        return self == .native
    }

    public var isLiquidFluid: Bool {
        return self == .liquidFluid
    }

    public static var current: PlayerDesign {
        get {
            let saved = UserDefaults.standard.string(forKey: "YTM_playerDesign") ?? PlayerDesign.adaptive.rawValue
            if saved == "Adaptive (Glass & Ambient)" { return .adaptive }
            return PlayerDesign(rawValue: saved) ?? .adaptive
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "YTM_playerDesign")
            NotificationCenter.default.post(name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        }
    }
}