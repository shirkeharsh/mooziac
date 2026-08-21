import Foundation
import IOKit.pwr_mgt
import AVFoundation

/// Keeps music audio playback active on macOS even when display locks or sleeps (while lid is open).
final class BackgroundMediaController {
    static let shared = BackgroundMediaController()

    private var assertionID: IOPMAssertionID = 0
    private var processActivity: NSObjectProtocol?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?

    init() {
        startPreventingSleep()
    }

    func startPreventingSleep() {
        guard assertionID == 0 else { return }

        // 1. Create IOPMAssertion to prevent system/media sleep while lid is open
        let reason = "Background Music Playback" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            print("[BackgroundMediaController] IOPMAssertion created successfully! ID: \(assertionID)")
        }

        // 2. Prevent App Nap during screen lock
        processActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Background Music Playback"
        )
    }

    func stopPreventingSleep() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        if let activity = processActivity {
            ProcessInfo.processInfo.endActivity(activity)
            processActivity = nil
        }
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioPlayerNode = nil
        audioEngine = nil
    }
}
