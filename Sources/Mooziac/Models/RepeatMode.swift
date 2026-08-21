import Foundation

public enum RepeatMode: Int, Codable {
    case off = 0
    case one = 1

    public var displayName: String {
        switch self {
        case .off: return "Repeat: Off"
        case .one: return "Repeat: Song"
        }
    }
}