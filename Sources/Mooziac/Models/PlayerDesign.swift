import Foundation

public enum PlayerDesign: String, CaseIterable {
    case adaptive = "Adaptive (Ambient Dark)"
    case darkMode = "OLED Dark Mode"
    case glassMode = "Pure Crystal Glass Mode"
    case liquidFluid = "Watery Pure Transparent"

    public var isGlass: Bool {
        return self == .glassMode
    }

    public var isLiquidFluid: Bool {
        return self == .liquidFluid
    }

    public static var current: PlayerDesign {
        get {
            let saved = UserDefaults.standard.string(forKey: "YTM_playerDesign") ?? PlayerDesign.adaptive.rawValue
            if saved == "Adaptive (Glass & Ambient)" { return .adaptive }
            if saved == "macOS Native Vibrancy" { return .liquidFluid }
            if saved == "Liquid Fluid Glow" || saved == "Watery Pure Transparent" { return .liquidFluid }
            return PlayerDesign(rawValue: saved) ?? .adaptive
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "YTM_playerDesign")
            NotificationCenter.default.post(name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        }
    }
}