import AppKit

public final class KeyboardShortcutHandler {
    public static let shared = KeyboardShortcutHandler()

    private var localMonitor: Any?
    private var keyUpMonitor: Any?
    /// Key codes whose keyDown we consumed. Their keyUp must be swallowed too, otherwise
    /// YouTube (which toggles on Space keyup) toggles playback a second time.
    private var consumedKeyCodes = Set<UInt16>()

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyDown(event: event) == true {
                self?.consumedKeyCodes.insert(event.keyCode)
                return nil // Handled, suppress further propagation
            }
            return event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if self?.consumedKeyCodes.remove(event.keyCode) != nil {
                return nil
            }
            return event
        }
    }

    public func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        consumedKeyCodes.removeAll()
    }

    private func handleKeyDown(event: NSEvent) -> Bool {
        // If an AppKit modal sheet is presented (e.g. Download sheet), don't intercept keys
        if NSApp.keyWindow?.attachedSheet != nil {
            return false
        }

        let isWindowFullscreen = MainVideoWindowController.shared.window?.styleMask.contains(.fullScreen) == true

        // When in fullscreen, the video takes over the entire display (no text inputs are visible).
        // Only guard against text field typing when NOT in fullscreen mode.
        if !isWindowFullscreen {
            // If the user is currently typing in an input field (like YouTube's search bar), do not steal keystrokes
            if VideoPlayerCoordinator.shared.isTypingInTextField {
                if event.keyCode == 53 { // Escape: reset typing focus
                    VideoPlayerCoordinator.shared.isTypingInTextField = false
                }
                return false
            }

            // If a native AppKit field editor is currently focused, do not steal keystrokes
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSText || responder is NSTextField {
                return false
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)

        // Command + Shift shortcuts
        if isCmd && isShift {
            switch event.keyCode {
            case 11: // Cmd + Shift + B -> Toggle Ad Blocker
                let newState = !AppSettings.shared.isAdBlockEnabled
                AppSettings.shared.isAdBlockEnabled = newState
                let text = newState ? "Ad Blocker: Enabled" : "Ad Blocker: Disabled"
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: text)
                MainVideoWindowController.shared.reconfigureAndReload()
                return true

            case 1: // Cmd + Shift + S -> Toggle SponsorBlock
                let newState = !AppSettings.shared.isSponsorBlockEnabled
                AppSettings.shared.isSponsorBlockEnabled = newState
                let text = newState ? "SponsorBlock: Enabled" : "SponsorBlock: Disabled"
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: text)
                MainVideoWindowController.shared.reconfigureAndReload()
                return true

            case 3: // Cmd + Shift + F -> Toggle Distraction-Free Focus Mode
                VideoPlayerCoordinator.shared.toggleDistractionFreeMode()
                return true

            case 8: // Cmd + Shift + C -> Copy Video Link with Timestamp
                VideoPlayerCoordinator.shared.copyVideoURL(includeTimestamp: true)
                return true

            default:
                break
            }
        }

        // Command shortcuts
        if isCmd {
            switch event.keyCode {
            case 2: // Cmd + D -> Download Video / Audio
                MainVideoWindowController.shared.presentDownloadSheet()
                return true

            case 8: // Cmd + C -> Copy Clean Video Link (when not copying text in input field)
                VideoPlayerCoordinator.shared.copyVideoURL(includeTimestamp: false)
                return true

            case 124: // Cmd + Right Arrow -> Next Video
                VideoPlayerCoordinator.shared.nextVideo()
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Next Video")
                return true

            case 123: // Cmd + Left Arrow -> Previous Video
                VideoPlayerCoordinator.shared.previousVideo()
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Previous Video")
                return true

            case 15: // Cmd + R -> Reload
                MainVideoWindowController.shared.reload()
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Reloading...")
                return true

            case 37, 40: // Cmd + L or Cmd + K -> Focus Omnibar
                MainVideoWindowController.shared.focusSearch()
                return true

            case 33: // Cmd + [ -> Back
                MainVideoWindowController.shared.goBack()
                return true

            case 30: // Cmd + ] -> Forward
                MainVideoWindowController.shared.goForward()
                return true

            case 46: // Cmd + M -> Minimize Window
                MainVideoWindowController.shared.performMinimize()
                return true

            case 13: // Cmd + W -> Close Window and return to Mooziac
                MainVideoWindowController.shared.closeYouTubeAndReturnToMooziac()
                return true

            default:
                return false
            }
        }

        // Shift shortcuts (without Cmd)
        if isShift && !isCmd {
            switch event.keyCode {
            case 43: // Shift + , (<) -> Slower Playback Speed
                VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: -0.25)
                return true

            case 47: // Shift + . (>) -> Faster Playback Speed
                VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: 0.25)
                return true

            default:
                break
            }
        }

        // Dedicated single-key shortcuts (when not in search / text field)
        if !isCmd && !isShift && flags.intersection([.control, .option]).isEmpty {
            switch event.keyCode {
            case 49, 40: // Spacebar or K -> Toggle Play / Pause
                // Holding the key must not keep flipping playback
                if !event.isARepeat {
                    VideoPlayerCoordinator.shared.togglePlayPause()
                }
                return true

            case 38: // J -> Seek Backward 10 Seconds
                VideoPlayerCoordinator.shared.seekBy(seconds: -10)
                return true

            case 37: // L -> Seek Forward 10 Seconds
                VideoPlayerCoordinator.shared.seekBy(seconds: 10)
                return true

            case 123: // Left Arrow -> Seek Backward 5 Seconds
                VideoPlayerCoordinator.shared.seekBy(seconds: -5)
                return true

            case 124: // Right Arrow -> Seek Forward 5 Seconds
                VideoPlayerCoordinator.shared.seekBy(seconds: 5)
                return true

            case 126: // Up Arrow -> Volume Up 5%
                VideoPlayerCoordinator.shared.adjustVolume(by: 0.05)
                return true

            case 125: // Down Arrow -> Volume Down 5%
                VideoPlayerCoordinator.shared.adjustVolume(by: -0.05)
                return true

            case 46: // M -> Toggle Mute
                VideoPlayerCoordinator.shared.toggleMute()
                return true

            case 3: // F -> Toggle Fullscreen
                VideoPlayerCoordinator.shared.toggleFullscreen()
                return true

            case 17: // T -> Toggle Theater Mode
                VideoPlayerCoordinator.shared.toggleTheaterMode()
                return true

            case 33: // [ -> Slower Playback Speed (-0.25x)
                VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: -0.25)
                return true

            case 30: // ] -> Faster Playback Speed (+0.25x)
                VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: 0.25)
                return true

            case 8: // C -> Toggle Captions / Subtitles
                VideoPlayerCoordinator.shared.toggleSubtitles()
                return true

            case 53: // Escape -> Exit Fullscreen if active
                if isWindowFullscreen {
                    MainVideoWindowController.shared.handleBridgeFullscreenRequest(wantsFullscreen: false)
                    return true
                }
                return false

            default:
                break
            }
        }

        return false
    }
}
