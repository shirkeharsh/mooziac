import AppKit
import Foundation

/// Manages eligibility, frequency, and presentation of the Bento Grid support prompt.
/// Adheres strictly to Mooziac's local-first, zero-telemetry architecture.
public final class RatingPromptManager {
    public static let shared = RatingPromptManager()
    
    // UserDefaults Keys (100% on-device local storage)
    private let keyFirstLaunchDate = "YTM_rating_firstLaunchDate"
    private let keyLaunchCount = "YTM_rating_launchCount"
    private let keySongsCompletedCount = "YTM_rating_songsCompletedCount"
    private let keyHasInteracted = "YTM_rating_hasInteracted"
    private let keyPromptShownCount = "YTM_rating_promptShownCount"
    private let keyLastPromptDate = "YTM_rating_lastPromptDate"
    
    // Eligibility Thresholds
    private let minDaysInstalled: Double = 3.0
    private let minLaunchCount: Int = 5
    private let minSongsCompleted: Int = 50
    private let maxPromptCountLifetime: Int = 2
    private let snoozeCooldownDays: Double = 14.0
    
    private init() {
        if UserDefaults.standard.double(forKey: keyFirstLaunchDate) == 0 {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: keyFirstLaunchDate)
        }
    }
    
    // MARK: - Lifecycle Tracking
    
    /// Records an application launch session.
    public func recordAppLaunch() {
        let current = UserDefaults.standard.integer(forKey: keyLaunchCount)
        UserDefaults.standard.set(current + 1, forKey: keyLaunchCount)
    }
    
    /// Records a song finishing cleanly to natural completion.
    public func recordSongCompleted() {
        let current = UserDefaults.standard.integer(forKey: keySongsCompletedCount)
        let updated = current + 1
        UserDefaults.standard.set(updated, forKey: keySongsCompletedCount)
        
        // Check if milestone triggers a prompt
        if shouldPresentPromptNow() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.presentPromptIfEligible()
            }
        }
    }
    
    // MARK: - Eligibility & Suppression Checks
    
    public var hasInteracted: Bool {
        get { UserDefaults.standard.bool(forKey: keyHasInteracted) }
        set { UserDefaults.standard.set(newValue, forKey: keyHasInteracted) }
    }
    
    public var promptShownCount: Int {
        get { UserDefaults.standard.integer(forKey: keyPromptShownCount) }
        set { UserDefaults.standard.set(newValue, forKey: keyPromptShownCount) }
    }
    
    public var lastPromptDate: TimeInterval {
        get { UserDefaults.standard.double(forKey: keyLastPromptDate) }
        set { UserDefaults.standard.set(newValue, forKey: keyLastPromptDate) }
    }
    
    /// Returns true if the user satisfies all "happy moment" conditions.
    public var isEligibleForPrompt: Bool {
        // 1. Permanently disabled if user already starred, supported, or wrote
        if hasInteracted { return false }
        
        // 2. Maximum 2 prompts lifetime
        if promptShownCount >= maxPromptCountLifetime { return false }
        
        let now = Date().timeIntervalSince1970
        let firstLaunch = UserDefaults.standard.double(forKey: keyFirstLaunchDate)
        let daysInstalled = (now - firstLaunch) / 86400.0
        let launches = UserDefaults.standard.integer(forKey: keyLaunchCount)
        let songs = UserDefaults.standard.integer(forKey: keySongsCompletedCount)
        
        // 3. Must meet usage maturity
        guard daysInstalled >= minDaysInstalled,
              launches >= minLaunchCount,
              songs >= minSongsCompleted else {
            return false
        }
        
        // 4. Must satisfy 14-day snooze cooldown if prompted before
        if lastPromptDate > 0 {
            let daysSinceLast = (now - lastPromptDate) / 86400.0
            if daysSinceLast < snoozeCooldownDays {
                return false
            }
        }
        
        return true
    }
    
    /// Strict contextual suppression checks (never interrupt active user workflows).
    public func shouldPresentPromptNow() -> Bool {
        guard isEligibleForPrompt else { return false }
        
        // Suppress if system is sleeping or screen locked
        if NowPlayingManager.shared.isSystemSleeping || NowPlayingManager.shared.isScreenLocked {
            return false
        }
        
        // Suppress if text search or editing is active
        if let mainVC = StatusItemManager.shared?.mainViewController,
           mainVC.dynamicIslandPlayer.isSearchFieldActive {
            return false
        }
        
        // Suppress if currently watching YouTube video in fullscreen
        if MainVideoWindowController.shared.isPlayerFullscreen {
            return false
        }
        
        return true
    }
    
    // MARK: - Presentation & User Actions
    
    public func presentPromptIfEligible() {
        guard shouldPresentPromptNow() else { return }
        showPrompt(force: false)
    }
    
    public func showPrompt(force: Bool = false) {
        if !force && !isEligibleForPrompt { return }
        
        promptShownCount += 1
        lastPromptDate = Date().timeIntervalSince1970
        
        RatingPromptWindowController.shared.showWindow(nil)
        RatingPromptWindowController.shared.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Called when the user clicks Star, Coffee, or Write Us.
    public func markInteracted() {
        hasInteracted = true
        if Thread.isMainThread && NSApp != nil {
            RatingPromptWindowController.shared.close()
        }
    }
    
    /// Called when the user clicks "Maybe Later" or closes the window without acting.
    public func snooze() {
        lastPromptDate = Date().timeIntervalSince1970
        if Thread.isMainThread && NSApp != nil {
            RatingPromptWindowController.shared.close()
        }
    }
}
