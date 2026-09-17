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

    public var iconName: String {
        switch self {
        case .bottomRightDoubleTap: return "hand.tap"
        case .bottomRightTripleTap: return "hand.tap.fill"
        case .bottomLeftDoubleTap:  return "hand.tap"
        case .bottomLeftTripleTap:  return "hand.tap.fill"
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
    case seekForward     = "seekForward"
    case seekBackward    = "seekBackward"
    case seekForward15   = "seekForward15"
    case seekBackward15  = "seekBackward15"
    case seekForward30   = "seekForward30"
    case seekBackward30  = "seekBackward30"
    case toggleShuffle   = "toggleShuffle"
    case toggleRepeat    = "toggleRepeat"

    public var displayName: String {
        switch self {
        case .nextTrack:        return "Next Track"
        case .previousTrack:    return "Previous Track"
        case .togglePlayPause:  return "Play / Pause"
        case .toggleLyrics:     return "Toggle Centered Lyrics"
        case .volumeUp:         return "Volume Up"
        case .volumeDown:       return "Volume Down"
        case .toggleMute:       return "Toggle Mute"
        case .togglePlayer:     return "Toggle Player Panel"
        case .seekForward:      return "Seek Forward 10s"
        case .seekBackward:     return "Seek Backward 10s"
        case .seekForward15:    return "Seek Forward 15s"
        case .seekBackward15:   return "Seek Backward 15s"
        case .seekForward30:    return "Seek Forward 30s"
        case .seekBackward30:   return "Seek Backward 30s"
        case .toggleShuffle:    return "Toggle Shuffle"
        case .toggleRepeat:     return "Toggle Repeat"
        }
    }

    public var iconName: String {
        switch self {
        case .nextTrack:        return "forward.fill"
        case .previousTrack:    return "backward.fill"
        case .togglePlayPause:  return "playpause.fill"
        case .toggleLyrics:     return "quote.bubble"
        case .volumeUp:         return "speaker.wave.2.fill"
        case .volumeDown:       return "speaker.wave.1.fill"
        case .toggleMute:       return "speaker.slash.fill"
        case .togglePlayer:     return "sidebar.left"
        case .seekForward:      return "goforward.10"
        case .seekBackward:     return "gobackward.10"
        case .seekForward15:    return "goforward.15"
        case .seekBackward15:   return "gobackward.15"
        case .seekForward30:    return "goforward.30"
        case .seekBackward30:   return "gobackward.30"
        case .toggleShuffle:    return "shuffle"
        case .toggleRepeat:     return "repeat"
        }
    }
}