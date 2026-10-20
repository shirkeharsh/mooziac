import AppKit
import WebKit
import MediaPlayer

public final class VideoPlayerCoordinator: NSObject, YouTubePlayerBridgeDelegate {
    public static let shared = VideoPlayerCoordinator()

    public private(set) var currentState: VideoPlaybackState = VideoPlaybackState()
    public var isTypingInTextField: Bool = false
    public private(set) var currentPlaybackSpeed: Double = 1.0

    public weak var webView: YouTubeWebView?

    public override init() {
        super.init()
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextVideo()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousVideo()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seekTo(seconds: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        var info: [String: Any] = [:]

        if !currentState.title.isEmpty {
            info[MPMediaItemPropertyTitle] = currentState.title
        }
        if !currentState.channel.isEmpty {
            info[MPMediaItemPropertyArtist] = currentState.channel
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentState.currentTime
        info[MPMediaItemPropertyPlaybackDuration] = currentState.duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = currentState.isPlaying ? 1.0 : 0.0

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = currentState.isPlaying ? .playing : .paused
    }

    // MARK: - YouTubePlayerBridgeDelegate
    public func bridgeDidUpdatePlaybackState(_ state: VideoPlaybackState) {
        self.currentState = state

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateNowPlayingInfo()
            MainVideoWindowController.shared.updatePlaybackState(state)

            if state.playbackRate > 0 && abs(state.playbackRate - self.currentPlaybackSpeed) > 0.01 {
                self.currentPlaybackSpeed = state.playbackRate
                MainVideoWindowController.shared.updatePlaybackSpeed(state.playbackRate)
            }

            if state.isPlaying && !state.videoId.isEmpty && !state.title.isEmpty {
                YouTubeDatabaseManager.shared.recordHistory(
                    videoId: state.videoId,
                    title: state.title,
                    channel: state.channel,
                    duration: state.duration,
                    lastPosition: state.currentTime
                )
            }
        }
    }

    public func bridgeDidChangeEditableFocus(isEditable: Bool) {
        self.isTypingInTextField = isEditable
    }

    // MARK: - Safe Main-Thread JavaScript Evaluation
    private func evaluateOnMain(_ script: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        if Thread.isMainThread {
            webView?.evaluateJavaScript(script, completionHandler: completionHandler)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(script, completionHandler: completionHandler)
            }
        }
    }

    // MARK: - Commands
    public func play() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.play();")
    }

    public func pause() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.pause();")
    }

    public func togglePlayPause() {
        // All toggling (and its debounce) lives in one JS function so keyboard, menu,
        // media keys and gestures can never double-fire and cancel each other.
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.togglePlayPause();", completionHandler: nil)
    }

    public func seekTo(seconds: Double) {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.seekTo(\(seconds));")
    }

    public func seekBy(seconds: Double) {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.seekBy(\(seconds));")
        let sign = seconds > 0 ? "+" : ""
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "\(sign)\(Int(seconds))s")
    }

    public func nextVideo() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.nextVideo();")
    }

    public func previousVideo() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.prevVideo();")
    }

    public func setVolume(_ vol: Float) {
        let clamped = max(0.0, min(1.0, vol))
        currentState.volume = clamped
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.setVolume(\(clamped));")
    }

    public func adjustVolume(by delta: Float) {
        let current = AppVolumeManager.shared.getEffectiveVolume()
        let newVol = max(0.0, min(1.0, current + delta))
        AppVolumeManager.shared.setEffectiveVolume(newVol)
        setVolume(newVol)
        let percent = Int(round(newVol * 100))
        FloatingHUDWindowController.shared.showVolumeOverlay(volumePercent: percent)
    }

    public func toggleMute() {
        let current = AppVolumeManager.shared.getEffectiveVolume()
        if current > 0.01 {
            UserDefaults.standard.set(Double(current), forKey: "YTM_preMuteVolume")
            AppVolumeManager.shared.setEffectiveVolume(0.0)
            setVolume(0.0)
            currentState.isMuted = true
            evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.toggleMute();")
            FloatingHUDWindowController.shared.showVolumeOverlay(volumePercent: 0)
        } else {
            let prev = Float(UserDefaults.standard.double(forKey: "YTM_preMuteVolume"))
            let restore = prev > 0.05 ? prev : 0.3
            AppVolumeManager.shared.setEffectiveVolume(restore)
            setVolume(restore)
            currentState.isMuted = false
            evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.toggleMute();")
            let percent = Int(round(restore * 100))
            FloatingHUDWindowController.shared.showVolumeOverlay(volumePercent: percent)
        }
    }

    public func togglePictureInPicture() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.togglePiP();")
    }

    public func toggleTheaterMode() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.toggleTheater();")
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Theater Mode Toggled")
    }

    public func toggleFullscreen() {
        if Thread.isMainThread {
            MainVideoWindowController.shared.handleBridgeFullscreenRequest()
        } else {
            DispatchQueue.main.async {
                MainVideoWindowController.shared.handleBridgeFullscreenRequest()
            }
        }
    }

    public func setQuality(_ quality: VideoQuality) {
        if Thread.isMainThread {
            guard let wv = webView else { return }
            YouTubeQualityManager.shared.setQuality(quality, in: wv)
            let msg = quality == .uhd2160 ? "4K Ultra HD Enabled" : "Quality: \(quality.displayName)"
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: msg)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setQuality(quality)
            }
        }
    }

    // MARK: - Playback Speed
    public func setPlaybackSpeed(_ speed: Double) {
        let clamped = max(0.25, min(3.0, (speed * 20).rounded() / 20))
        currentPlaybackSpeed = clamped
        AppSettings.shared.defaultPlaybackSpeed = clamped
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.setPlaybackRate(\(clamped));", completionHandler: nil)
        let label = clamped == 1.0 ? "Normal (1.0×)" : String(format: "%.2f×", clamped)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "\(label) Playback Speed")
        if Thread.isMainThread {
            MainVideoWindowController.shared.updatePlaybackSpeed(clamped)
        } else {
            DispatchQueue.main.async {
                MainVideoWindowController.shared.updatePlaybackSpeed(clamped)
            }
        }
    }

    public func adjustPlaybackSpeed(by delta: Double) {
        setPlaybackSpeed(currentPlaybackSpeed + delta)
    }

    public func resetPlaybackSpeed() {
        setPlaybackSpeed(1.0)
    }

    // MARK: - Subtitles & Captions
    public func toggleSubtitles() {
        evaluateOnMain("window.__mooziacPlayer && window.__mooziacPlayer.toggleSubtitles();", completionHandler: nil)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Captions Toggled")
    }

    // MARK: - Share & Link Copy
    public func copyVideoURL(includeTimestamp: Bool = false) {
        guard !currentState.videoId.isEmpty else {
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "No active video to share")
            return
        }
        var urlStr = "https://youtu.be/\(currentState.videoId)"
        if includeTimestamp && currentState.currentTime > 1.0 {
            urlStr += "?t=\(Int(currentState.currentTime))"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlStr, forType: .string)
        let msg = includeTimestamp ? "Copied Link at \(currentState.formattedCurrentTime)" : "Copied Video Link"
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: msg)
    }

    // MARK: - Distraction-Free Focus Mode
    public func toggleDistractionFreeMode() {
        MainVideoWindowController.shared.toggleDistractionFreeMode()
    }
}
