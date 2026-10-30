import Foundation
import IOKit.pwr_mgt
import AVFoundation

/// Intelligently keeps media playback active on macOS by preventing system idle sleep
/// ONLY while audio or video is actively playing. Releases the sleep assertion when paused or idle
/// to protect MacBook battery life.
final class BackgroundMediaController {
    static let shared = BackgroundMediaController()

    private var assertionID: IOPMAssertionID = 0
    private var processActivity: NSObjectProtocol?
    private var releaseTimer: Timer?
    private var isMonitoring: Bool = false

    init() {
        // Do not blindly prevent sleep on launch; wait for active playback
    }

    /// Starts monitoring playback state notifications for both audio and YouTube video.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged),
            name: NSNotification.Name("Mooziac_PlaybackStateChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged),
            name: NSNotification.Name("Mooziac_VideoPlaybackStateChanged"),
            object: nil
        )

        evaluatePlaybackState()
    }

    func stopMonitoring() {
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
        stopPreventingSleepImmediate()
    }

    @objc private func handlePlaybackStateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.evaluatePlaybackState()
        }
    }

    /// Evaluates whether audio or YouTube video is actively playing.
    func evaluatePlaybackState() {
        let isAudioPlaying = NowPlayingManager.shared.currentState.isPlaying
        let isVideoPlaying = VideoPlayerCoordinator.shared.currentState.isPlaying
        let isAnyPlaying = isAudioPlaying || isVideoPlaying

        if isAnyPlaying {
            releaseTimer?.invalidate()
            releaseTimer = nil
            startPreventingSleep()
        } else {
            scheduleSleepAssertionRelease()
        }
    }

    private func scheduleSleepAssertionRelease() {
        guard assertionID != 0 || processActivity != nil else { return }
        guard releaseTimer == nil else { return }

        releaseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.stopPreventingSleepImmediate()
        }
    }

    func startPreventingSleep() {
        guard assertionID == 0 else { return }

        // 1. Create IOPMAssertion to prevent system/media sleep while active playback is occurring
        let reason = "Active Media Playback" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            Log.playback.debug("IOPMAssertion created for active playback, ID: \(self.assertionID)")
        }

        // 2. Prevent App Nap during screen lock while actively playing
        if processActivity == nil {
            processActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Active Media Playback"
            )
        }
    }

    func stopPreventingSleep() {
        stopPreventingSleepImmediate()
    }

    private func stopPreventingSleepImmediate() {
        releaseTimer?.invalidate()
        releaseTimer = nil

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            Log.playback.debug("IOPMAssertion released - Mac can sleep normally")
        }
        if let activity = processActivity {
            ProcessInfo.processInfo.endActivity(activity)
            processActivity = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}
