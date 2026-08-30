import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemManager: StatusItemManager?
    private var signInObserver: NSObjectProtocol?

    static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.contains("--generate-screenshots") {
            VisualMatrixSnapshotGenerator.run()
            exit(0)
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run in menu bar mode without cluttering the macOS Dock
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        
        // Purge legacy v1/v2 settings keys so clean v3 keys default to OFF
        let legacyKeys = [
            "YTM_isEdgeEngineEnabled", "YTM_isCenteredLyricsEnabled",
            "YTM_isRightEdgeVolumeEnabled", "YTM_isRightCornerTapsEnabled",
            "YTM_isLeftCornerTapsEnabled", "YTM_hasInitializedDefaultSettingsV2",
            "YTM_isDraggedFromDock", "YTM_playerFrameX", "YTM_playerFrameY", "YTM_playerTopY",
            "MooziacVoiceAssistantEnabled", "Mooziac_AI_enabled"
        ]
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Prevent music audio playback from stopping when display locks/sleeps
        BackgroundMediaController.shared.startPreventingSleep()

        // Initialize Trackpad Right-Edge Volume Control (0.01mm edge)
        EdgeVolumeEngine.shared.start()

        // Start Audio Route & Lock Auto-Pause Monitor
        AudioRouteMonitor.shared.startMonitoring()

        // Resume any downloads that were still queued when the app quit
        DownloadManager.shared.resumePendingDownloadsFromDisk()

        // Start Real-time Network Monitoring
        NetworkMonitor.shared.startMonitoring()

        // Start Discord Rich Presence
        DiscordRPCManager.shared.startReconnectLoop()
        DiscordRPCManager.shared.tryConnect()

        // Initialize menu bar status item & webview popover
        statusItemManager = StatusItemManager()
        
        // Play visual launch animation (haptic feedback & sound disabled)
        LaunchAnimationController.shared.play()

        setupAutoSync()

        // Check for updates in background (throttled to once every 24h)
        DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) {
            UpdateManager.shared.checkForUpdates(userInitiated: false)
        }
    }

    /// Auto-sync the library with the YouTube Music account once the session is
    /// available. Runs on cold start if already signed in, and again whenever the
    /// sign-in status flips to signed-in. Purely additive to the local DB; the
    /// rest of the app is untouched.
    private func setupAutoSync() {
        LikedSongsManager.shared.refreshSignInStatus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, PlaylistSyncManager.shared.isSignedIn else { return }
            PlaylistSyncManager.shared.syncNow()
        }

        signInObserver = NotificationCenter.default.addObserver(
            forName: LikedSongsManager.signInStatusChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard LikedSongsManager.shared.isSignedIn else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                PlaylistSyncManager.shared.syncNow()
            }
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        BackgroundMediaController.shared.stopPreventingSleep()
        if let observer = signInObserver {
            NotificationCenter.default.removeObserver(observer)
            signInObserver = nil
        }
    }
}
