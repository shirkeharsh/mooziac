import Foundation

/// Defines supported trackpad gesture triggers.
public enum GestureType: String, CaseIterable, Codable {
    case bottomRightDoubleTap = "bottomRightDoubleTap"
    case bottomRightTripleTap = "bottomRightTripleTap"
    case bottomLeftDoubleTap  = "bottomLeftDoubleTap"
    case bottomLeftTripleTap  = "bottomLeftTripleTap"

    public var displayName: String {
        switch self {
        case .bottomRightDoubleTap: return "Bottom-Right 2 Taps"
        case .bottomRightTripleTap: return "Bottom-Right 3 Taps"
        case .bottomLeftDoubleTap:  return "Bottom-Left 2 Taps"
        case .bottomLeftTripleTap:  return "Bottom-Left 3 Taps"
        }
    }

    public var defaultAction: GestureAction {
        switch self {
        case .bottomRightDoubleTap: return .nextTrack
        case .bottomRightTripleTap: return .previousTrack
        case .bottomLeftDoubleTap:  return .togglePlayPause
        case .bottomLeftTripleTap:  return .toggleLyrics
        }
    }
}

/// Defines available playback & interface actions mapable to trackpad gestures.
public enum GestureAction: String, CaseIterable, Codable {
    case nextTrack       = "nextTrack"
    case previousTrack   = "previousTrack"
    case togglePlayPause = "togglePlayPause"
    case toggleLyrics    = "toggleLyrics"
    case volumeUp        = "volumeUp"
    case volumeDown      = "volumeDown"
    case toggleMute      = "toggleMute"
    case togglePlayer    = "togglePlayer"

    public var displayName: String {
        switch self {
        case .nextTrack:       return "Next Track"
        case .previousTrack:   return "Previous Track"
        case .togglePlayPause: return "Play / Pause"
        case .toggleLyrics:    return "Toggle Centered Lyrics"
        case .volumeUp:        return "Volume Up"
        case .volumeDown:      return "Volume Down"
        case .toggleMute:      return "Toggle Mute"
        case .togglePlayer:    return "Toggle Player Panel"
        }
    }
}