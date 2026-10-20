import AppKit

/// Manager for persisting and executing custom trackpad gesture mappings.
public final class GestureMappingManager {
    public static let shared = GestureMappingManager()

    private init() {}

    /// True when Mooziac is in YouTube video mode or the YouTube window is active.
    public var isYouTubeMode: Bool {
        return StatusItemManager.shared?.currentMode == .youtube ||
               MainVideoWindowController.isWindowVisible
    }

    /// Retrieves the current mapped action for a specific gesture trigger in Music mode.
    public func getAction(for gesture: GestureType) -> GestureAction {
        let key = "YTM_gestureMapping_\(gesture.rawValue)"
        if let savedRaw = UserDefaults.standard.string(forKey: key),
           let action = GestureAction(rawValue: savedRaw) {
            return action
        }
        return gesture.defaultAction
    }

    /// Retrieves the mapped action for a specific gesture trigger in YouTube mode.
    public func getYouTubeAction(for gesture: GestureType) -> GestureAction {
        let key = "YouTube_gestureMapping_\(gesture.rawValue)"
        if let savedRaw = UserDefaults.standard.string(forKey: key),
           let action = GestureAction(rawValue: savedRaw) {
            return action
        }
        // Dedicated YouTube defaults: 2 taps = Play/Pause & Seek +10s; 3 taps = Seek -10s & Seek +30s
        switch gesture {
        case .bottomLeftDoubleTap:
            return .togglePlayPause
        case .bottomLeftTripleTap:
            return .seekBackward
        case .bottomRightDoubleTap:
            return .seekForward
        case .bottomRightTripleTap:
            return .seekForward30
        }
    }

    /// Persists a custom gesture mapping to UserDefaults for Music mode.
    public func setAction(_ action: GestureAction, for gesture: GestureType) {
        let key = "YTM_gestureMapping_\(gesture.rawValue)"
        UserDefaults.standard.set(action.rawValue, forKey: key)
    }

    /// Persists a custom gesture mapping to UserDefaults for YouTube mode.
    public func setYouTubeAction(_ action: GestureAction, for gesture: GestureType) {
        let key = "YouTube_gestureMapping_\(gesture.rawValue)"
        UserDefaults.standard.set(action.rawValue, forKey: key)
    }

    /// Resets all gesture mappings back to factory defaults.
    public func resetToDefaults() {
        for gesture in GestureType.allCases {
            UserDefaults.standard.removeObject(forKey: "YTM_gestureMapping_\(gesture.rawValue)")
            UserDefaults.standard.removeObject(forKey: "YouTube_gestureMapping_\(gesture.rawValue)")
        }
    }

    /// Executes the assigned action for a gesture trigger.
    public func executeAction(for gesture: GestureType) {
        if isYouTubeMode {
            let action = getYouTubeAction(for: gesture)
            executeYouTubeAction(action)
        } else {
            let action = getAction(for: gesture)
            executeAction(action)
        }
    }

    /// Executes a specific gesture action for Music mode.
    public func executeAction(_ action: GestureAction) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.executeAction(action)
            }
            return
        }

        if isYouTubeMode {
            executeYouTubeAction(action)
            return
        }

        switch action {
        case .nextTrack:
            NowPlayingManager.shared.nextTrack()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Next Track")
        case .previousTrack:
            NowPlayingManager.shared.previousTrack()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Previous Track")
        case .togglePlayPause:
            let targetPlaying = !NowPlayingManager.shared.currentState.isPlaying
            NowPlayingManager.shared.togglePlayPause()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
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
        case .seekForward:
            NowPlayingManager.shared.fastForward(seconds: 10)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek +10s")
        case .seekBackward:
            NowPlayingManager.shared.rewind(seconds: 10)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek -10s")
        case .seekForward15:
            NowPlayingManager.shared.fastForward(seconds: 15)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek +15s")
        case .seekBackward15:
            NowPlayingManager.shared.rewind(seconds: 15)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek -15s")
        case .seekForward30:
            NowPlayingManager.shared.fastForward(seconds: 30)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek +30s")
        case .seekBackward30:
            NowPlayingManager.shared.rewind(seconds: 30)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Seek -30s")
        case .toggleShuffle:
            NowPlayingManager.shared.toggleShuffle()
            let enabled = NowPlayingManager.shared.isShuffleActive
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: enabled ? "Shuffle On" : "Shuffle Off")
        case .toggleRepeat:
            NowPlayingManager.shared.toggleRepeat()
            let mode = NowPlayingManager.shared.repeatMode
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Repeat: \(mode.displayName)")
        }
    }

    /// Executes a specific gesture action routed exclusively to the YouTube Player.
    public func executeYouTubeAction(_ action: GestureAction) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.executeYouTubeAction(action)
            }
            return
        }

        switch action {
        case .nextTrack:
            VideoPlayerCoordinator.shared.nextVideo()
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Next Video")
        case .previousTrack:
            VideoPlayerCoordinator.shared.previousVideo()
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Previous Video")
        case .togglePlayPause:
            let isPlaying = VideoPlayerCoordinator.shared.currentState.isPlaying
            VideoPlayerCoordinator.shared.togglePlayPause()
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: isPlaying ? "Paused" : "Playing")
        case .toggleLyrics:
            VideoPlayerCoordinator.shared.toggleSubtitles()
        case .volumeUp:
            VideoPlayerCoordinator.shared.adjustVolume(by: 0.05)
        case .volumeDown:
            VideoPlayerCoordinator.shared.adjustVolume(by: -0.05)
        case .toggleMute:
            VideoPlayerCoordinator.shared.toggleMute()
        case .togglePlayer:
            if let win = MainVideoWindowController.shared.window {
                if win.isKeyWindow {
                    MainVideoWindowController.shared.performMinimize()
                } else {
                    MainVideoWindowController.shared.showWindow(nil)
                    win.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        case .seekForward:
            VideoPlayerCoordinator.shared.seekBy(seconds: 10)
        case .seekBackward:
            VideoPlayerCoordinator.shared.seekBy(seconds: -10)
        case .seekForward15:
            VideoPlayerCoordinator.shared.seekBy(seconds: 15)
        case .seekBackward15:
            VideoPlayerCoordinator.shared.seekBy(seconds: -15)
        case .seekForward30:
            VideoPlayerCoordinator.shared.seekBy(seconds: 30)
        case .seekBackward30:
            VideoPlayerCoordinator.shared.seekBy(seconds: -30)
        case .toggleShuffle:
            VideoPlayerCoordinator.shared.togglePictureInPicture()
        case .toggleRepeat:
            VideoPlayerCoordinator.shared.toggleTheaterMode()
        }
    }
}
