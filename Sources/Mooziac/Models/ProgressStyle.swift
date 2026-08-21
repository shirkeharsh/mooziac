import Foundation

public enum ProgressStyle: String, CaseIterable, Codable {
    case waveform = "waveform"       // Dynamic Equalizer Waveform (32 bars)
    case neonGlow = "neonGlow"       // Neon Liquid Capsule with glowing head node
    case cyberDots = "cyberDots"     // Pulsing LED Dot Matrix Nodes
    case minimalLine = "minimalLine" // Sleek Precision Line

    public var displayName: String {
        switch self {
        case .waveform: return "Dynamic 32-bar reactive waves"
        case .neonGlow: return "Glowing neon capsule progress"
        case .cyberDots: return "Pulsing LED dot-matrix counter"
        case .minimalLine: return "Ultra-clean precision audio line"
        }
    }

    public static var current: ProgressStyle {
        get {
            if let raw = UserDefaults.standard.string(forKey: "YTM_progressStyle"),
               let style = ProgressStyle(rawValue: raw) {
                return style
            }
            return .waveform
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "YTM_progressStyle")
            UserDefaults.standard.set(newValue == .waveform, forKey: "YTM_v3_useWaveformProgress")
            NotificationCenter.default.post(name: NSNotification.Name("ProgressStyleDidChange"), object: nil)
        }
    }
}