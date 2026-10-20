import Foundation

public enum VideoQuality: String, CaseIterable, Codable {
    case auto = "auto"
    case uhd2160 = "hd2160" // 4K 2160p
    case qhd1440 = "hd1440" // 2K 1440p
    case fhd1080 = "hd1080" // 1080p Full HD
    case hd720 = "hd720"    // 720p HD
    case large = "large"    // 480p
    case medium = "medium"  // 360p
    case small = "small"    // 240p
    case tiny = "tiny"      // 144p

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .uhd2160: return "4K (2160p)"
        case .qhd1440: return "1440p (2K)"
        case .fhd1080: return "1080p (Full HD)"
        case .hd720: return "720p (HD)"
        case .large: return "480p"
        case .medium: return "360p"
        case .small: return "240p"
        case .tiny: return "144p"
        }
    }

    public var shortLabel: String {
        switch self {
        case .uhd2160: return "4K"
        case .qhd1440: return "2K"
        case .fhd1080: return "1080p"
        case .hd720: return "720p"
        case .large: return "480p"
        case .medium: return "360p"
        case .small: return "240p"
        case .tiny: return "144p"
        case .auto: return "Auto"
        }
    }

    public var is4K: Bool {
        return self == .uhd2160
    }
}
