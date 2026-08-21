import AppKit

/// Manager for persisting and executing custom trackpad gesture mappings.
public final class GestureMappingManager {
    public static let shared = GestureMappingManager()

    private init() {}

    /// Retrieves the current mapped action for a specific gesture trigger.
    public func getAction(for gesture: GestureType) -> GestureAction {
        let key = "YTM_gestureMapping_\(gesture.rawValue)"
        if let savedRaw = UserDefaults.standard.string(forKey: key),
           let action = GestureAction(rawValue: savedRaw) {
            return action
        }
        return gesture.defaultAction
    }

    /// Persists a custom gesture mapping to UserDefaults.
    public func setAction(_ action: GestureAction, for gesture: GestureType) {
        let key = "YTM_gestureMapping_\(gesture.rawValue)"
        UserDefaults.standard.set(action.rawValue, forKey: key)
    }

    /// Resets all gesture mappings back to factory defaults.
    public func resetToDefaults() {
        for gesture in GestureType.allCases {
            let key = "YTM_gestureMapping_\(gesture.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Executes the assigned action for a gesture trigger.
    public func executeAction(for gesture: GestureType) {
        let action = getAction(for: gesture)
        executeAction(action)
    }

    /// Executes a specific gesture action.
    public func executeAction(_ action: GestureAction) {
        switch action {
        case .nextTrack:
            NowPlayingManager.shared.nextTrack()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Next Track")
        case .previousTrack:
            NowPlayingManager.shared.previousTrack()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Previous Track")
        case .togglePlayPause:
            let targetPlaying =
                !NowPlayingManager.shared.currentState.isPlaying

            NowPlayingManager.shared.togglePlayPause()

            CenteredMenuBarLyricsWindowController.shared
                .showCustomTextOverlay(
                    text: targetPlaying ? "Playing" : "Paused"
                )
        case .toggleLyrics:
            CenteredMenuBarLyricsWindowController.shared.toggleOverlay()
            let enabled = CenteredMenuBarLyricsWindowController.shared.isEnabled
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: enabled ? "Lyrics Enabled" : "Lyrics Disabled")
        case .volumeUp:
            NowPlayingManager.shared.adjustVolume(deltaPercent: 5.0)
        case .volumeDown:
            NowPlayingManager.shared.adjustVolume(deltaPercent: -5.0)
        case .toggleMute:
            let current = VolumeController.shared.getVolume()
            if current > 0.01 {
                UserDefaults.standard.set(Double(current), forKey: "YTM_preMuteVolume")
                VolumeController.shared.setVolume(0.0)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Muted")
            } else {
                let prev = Float(UserDefaults.standard.double(forKey: "YTM_preMuteVolume"))
                let restore = prev > 0.05 ? prev : 0.3
                VolumeController.shared.setVolume(restore)
                let pct = Int(round(restore * 100))
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Volume: \(pct)%")
            }
        case .togglePlayer:
            if let button = StatusItemManager.shared?.statusItem.button {
                StatusItemManager.shared?.togglePanel(button)
            }
        }
    }
}
