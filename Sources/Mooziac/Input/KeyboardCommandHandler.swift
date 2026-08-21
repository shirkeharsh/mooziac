import Foundation

// MARK: - Shared Keyboard Command Handling
// Single source of truth for the arrow/space media commands (key codes 123/124/126/125/49).
// Used both by StatusItemManager's live key event monitor and DynamicIslandPlayerView.keyDown.
enum KeyboardCommandHandler {
    static func handle(keyCode: UInt16,
                       isRepeat: Bool,
                       showOverlay: (String) -> Void) -> Bool {
        switch keyCode {
        case 123: // Left Arrow ←
            let step: Double = isRepeat ? 8.0 : 4.0
            NowPlayingManager.shared.rewind(seconds: step)
            let curr = NowPlayingManager.shared.currentState.getAccurateTime()
            let newTime = max(0, curr - step)
            showOverlay("Rewind \(Int(step))s: \(formatTime(newTime))")
            return true

        case 124: // Right Arrow →
            let step: Double = isRepeat ? 8.0 : 4.0
            NowPlayingManager.shared.fastForward(seconds: step)
            let curr = NowPlayingManager.shared.currentState.getAccurateTime()
            let newTime = min(NowPlayingManager.shared.currentState.duration, curr + step)
            showOverlay("Forward \(Int(step))s: \(formatTime(newTime))")
            return true

        case 126: // Up Arrow ↑
            let curr = AppVolumeManager.shared.getEffectiveVolume()
            let newVol = max(0.0, min(1.0, curr + 0.05))
            AppVolumeManager.shared.setEffectiveVolume(newVol)
            let volPercent = Int(round(newVol * 100))
            let prefix = AppVolumeManager.shared.isAppVolumeOnly ? "App Sound: " : "Volume: "
            showOverlay("\(prefix)\(volPercent)%")
            return true

        case 125: // Down Arrow ↓
            let curr = AppVolumeManager.shared.getEffectiveVolume()
            let newVol = max(0.0, min(1.0, curr - 0.05))
            AppVolumeManager.shared.setEffectiveVolume(newVol)
            let volPercent = Int(round(newVol * 100))
            let prefix = AppVolumeManager.shared.isAppVolumeOnly ? "App Sound: " : "Volume: "
            showOverlay("\(prefix)\(volPercent)%")
            return true

        case 49: // Spacebar
            NowPlayingManager.shared.togglePlayPause()
            let isPlaying = !NowPlayingManager.shared.currentState.isPlaying
            showOverlay(isPlaying ? "Play" : "Pause")
            return true

        default:
            return false
        }
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let sec = Int(seconds)
        let mins = sec / 60
        let secs = sec % 60
        return String(format: "%d:%02d", mins, secs)
    }
}