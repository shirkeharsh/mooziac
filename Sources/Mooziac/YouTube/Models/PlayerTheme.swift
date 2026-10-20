import AppKit

public enum PlayerTheme: String, CaseIterable {
    case liquidFluid = "Liquid Transparent Vibrancy"

    public var id: String {
        return "liquid"
    }

    public var displayName: String {
        return rawValue
    }

    public var systemSymbolName: String {
        return "drop.fill"
    }
}
