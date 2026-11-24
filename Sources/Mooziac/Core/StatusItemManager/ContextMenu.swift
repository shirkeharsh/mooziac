import AppKit
import UniformTypeIdentifiers

final class MenuCapsuleToggleRowView: NSView {
    let titleLabel: NSTextField
    let toggle: NativeCapsuleToggleView
    var onToggle: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    
    private(set) var isHighlighted: Bool = false {
        didSet {
            guard isHighlighted != oldValue else { return }
            titleLabel.textColor = isHighlighted ? .selectedMenuItemTextColor : .labelColor
            needsDisplay = true
        }
    }
    
    init(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        self.toggle = NativeCapsuleToggleView(frame: NSRect(x: 236, y: 4, width: 32, height: 18))
        self.toggle.isMenuContext = true
        self.titleLabel = NSTextField(labelWithString: title)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        
        autoresizingMask = [.width]
        
        titleLabel.font = NSFont.menuFont(ofSize: 0)
        titleLabel.textColor = .labelColor
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingTail
        
        toggle.isOn = isOn
        toggle.updateVisuals(animated: false)
        toggle.onToggle = { [weak self] state in
            self?.onToggle?(state)
        }
        
        addSubview(titleLabel)
        addSubview(toggle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        // Standard macOS menu text margin is 14pt (aligned with standard NSMenuItem)
        let leftMargin: CGFloat = 14.0
        let rightMargin: CGFloat = 14.0
        let toggleWidth: CGFloat = 32.0
        let toggleHeight: CGFloat = 18.0
        
        let toggleX = bounds.width - rightMargin - toggleWidth
        let toggleY = round((bounds.height - toggleHeight) / 2.0)
        toggle.frame = NSRect(x: max(leftMargin + 60, toggleX), y: toggleY, width: toggleWidth, height: toggleHeight)
        
        let labelHeight: CGFloat = 18.0
        let labelY = round((bounds.height - labelHeight) / 2.0)
        let labelWidth = max(0, toggle.frame.minX - leftMargin - 10.0)
        titleLabel.frame = NSRect(x: leftMargin, y: labelY, width: labelWidth, height: labelHeight)
    }
    
    override var intrinsicContentSize: NSSize {
        let textWidth = titleLabel.attributedStringValue.size().width
        let minWidth: CGFloat = 14.0 + textWidth + 16.0 + 32.0 + 14.0
        return NSSize(width: max(280, minWidth), height: 26)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHighlighted = true
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHighlighted = false
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            isHighlighted = false
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            let highlightRect = NSRect(x: 5, y: 1, width: bounds.width - 10, height: bounds.height - 2)
            let path = NSBezierPath(roundedRect: highlightRect, xRadius: 4.5, yRadius: 4.5)
            NSColor.selectedContentBackgroundColor.setFill()
            path.fill()
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if bounds.contains(point) {
            return self
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        toggle.isOn.toggle()
        toggle.updateVisuals(animated: true)
        onToggle?(toggle.isOn)
    }
}

extension StatusItemManager {
    private func makeCapsuleToggleMenuItem(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> (menuItem: NSMenuItem, toggleView: NativeCapsuleToggleView) {
        let rowView = MenuCapsuleToggleRowView(title: title, isOn: isOn, onToggle: onToggle)
        let menuItem = NSMenuItem()
        menuItem.view = rowView
        return (menuItem, rowView.toggle)
    }

    // MARK: Scrobbling (Quick Controls)

    private func addScrobbleToggle(for provider: ScrobbleProvider, to menu: NSMenu) {
        let manager = ScrobbleManager.shared
        let connected = manager.isConnected(provider)

        let toggleRes = makeCapsuleToggleMenuItem(
            title: "\(provider.displayName) Scrobble",
            isOn: connected && manager.isEnabled(provider),
            onToggle: { enabled in
                if enabled && !manager.isConnected(provider) {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                        text: "Connect \(provider.displayName) first"
                    )
                    ScrobbleConnectUI.connect(provider)
                    return
                }
                manager.setEnabled(enabled, for: provider)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                    text: enabled ? "✓ \(provider.displayName) Scrobbling: On" : "\(provider.displayName) Scrobbling: Off"
                )
            }
        )
        menu.addItem(toggleRes.menuItem)
    }

    private func addScrobbleAccountItems(for provider: ScrobbleProvider, to menu: NSMenu) {
        let manager = ScrobbleManager.shared
        let connected = manager.isConnected(provider)

        if connected {
            let name = manager.username(for: provider).map { " (@\($0))" } ?? ""
            let status = NSMenuItem(title: "\(provider.displayName): Connected\(name)", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)

            let disconnect = NSMenuItem(title: "Disconnect \(provider.displayName)", action: #selector(disconnectScrobbleProviderFromMenu(_:)), keyEquivalent: "")
            disconnect.target = self
            disconnect.representedObject = provider.rawValue
            menu.addItem(disconnect)
        } else {
            let connect = NSMenuItem(title: "Connect \(provider.displayName)…", action: #selector(connectScrobbleProviderFromMenu(_:)), keyEquivalent: "")
            connect.target = self
            connect.representedObject = provider.rawValue
            menu.addItem(connect)
        }
    }

    @objc private func connectScrobbleProviderFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let provider = ScrobbleProvider(rawValue: raw) else { return }
        ScrobbleConnectUI.connect(provider)
    }

    @objc private func disconnectScrobbleProviderFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let provider = ScrobbleProvider(rawValue: raw) else { return }
        ScrobbleManager.shared.disconnect(provider)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "\(provider.displayName) disconnected")
    }
    
    private func makeGestureMappingMenuItem(for gesture: GestureType) -> NSMenuItem {
        let parentItem = NSMenuItem(title: gesture.displayName, action: nil, keyEquivalent: "")
        let subMenu = NSMenu(title: gesture.displayName)
        
        let currentAction = GestureMappingManager.shared.getAction(for: gesture)
        
        for action in GestureAction.allCases {
            let item = NSMenuItem(title: action.displayName, action: #selector(didSelectGestureMapping(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [
                "gestureRaw": gesture.rawValue,
                "actionRaw": action.rawValue
            ]
            item.state = (action == currentAction) ? .on : .off
            subMenu.addItem(item)
        }
        
        parentItem.submenu = subMenu
        return parentItem
    }
    
    @objc private func didSelectGestureMapping(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let gRaw = dict["gestureRaw"], let aRaw = dict["actionRaw"],
              let gesture = GestureType(rawValue: gRaw),
              let action = GestureAction(rawValue: aRaw) else { return }
        
        GestureMappingManager.shared.setAction(action, for: gesture)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "\(gesture.displayName): \(action.displayName)")
    }

    func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        let gestureMenu = NSMenu()
        
        var volumeSwipeToggle: NativeCapsuleToggleView?
        var rightCornerToggle: NativeCapsuleToggleView?
        var leftCornerToggle: NativeCapsuleToggleView?
        
        let masterGestureRes = makeCapsuleToggleMenuItem(
            title: "Trackpad Gestures (Master)",
            isOn: EdgeVolumeEngine.shared.isEnabled,
            onToggle: { enabled in
                EdgeVolumeEngine.shared.isEnabled = enabled
                volumeSwipeToggle?.isOn = enabled
                rightCornerToggle?.isOn = enabled
                leftCornerToggle?.isOn = enabled
            }
        )
        gestureMenu.addItem(masterGestureRes.menuItem)
        
        gestureMenu.addItem(NSMenuItem.separator())
        
        let volumeSwipeRes = makeCapsuleToggleMenuItem(
            title: "Right Edge Volume Swipe",
            isOn: EdgeVolumeEngine.shared.isRightEdgeVolumeEnabled,
            onToggle: { enabled in
                EdgeVolumeEngine.shared.isRightEdgeVolumeEnabled = enabled
            }
        )
        volumeSwipeToggle = volumeSwipeRes.toggleView
        gestureMenu.addItem(volumeSwipeRes.menuItem)
        
        let rightCornerRes = makeCapsuleToggleMenuItem(
            title: "Bottom-Right Corner Taps",
            isOn: EdgeVolumeEngine.shared.isRightCornerTapsEnabled,
            onToggle: { enabled in
                EdgeVolumeEngine.shared.isRightCornerTapsEnabled = enabled
            }
        )
        rightCornerToggle = rightCornerRes.toggleView
        gestureMenu.addItem(rightCornerRes.menuItem)
        
        let leftCornerRes = makeCapsuleToggleMenuItem(
            title: "Bottom-Left Corner Taps",
            isOn: EdgeVolumeEngine.shared.isLeftCornerTapsEnabled,
            onToggle: { enabled in
                EdgeVolumeEngine.shared.isLeftCornerTapsEnabled = enabled
            }
        )
        leftCornerToggle = leftCornerRes.toggleView
        gestureMenu.addItem(leftCornerRes.menuItem)
        
        gestureMenu.addItem(NSMenuItem.separator())
        
        let mappingParent = NSMenuItem(title: "Custom Gesture Mappings", action: nil, keyEquivalent: "")
        let mappingMenu = NSMenu(title: "Custom Gesture Mappings")
        
        for gesture in GestureType.allCases {
            mappingMenu.addItem(makeGestureMappingMenuItem(for: gesture))
        }
        
        mappingParent.submenu = mappingMenu
        gestureMenu.addItem(mappingParent)
        
        gestureMenu.addItem(NSMenuItem.separator())
        let showTutorialItem = NSMenuItem(title: "Show Gesture Tutorial", action: #selector(showGestureTutorialFromMenu), keyEquivalent: "t")
        showTutorialItem.target = self
        gestureMenu.addItem(showTutorialItem)
        
        let quickMenu = NSMenu(title: "Quick Controls")
        let playbackMenu = NSMenu(title: "Playback & Options")
        let accountMenu = NSMenu(title: "Account & Sync")
        let playerMenu = NSMenu(title: "Player")

        let openYouTubeItem = NSMenuItem(title: "Open YouTube", action: #selector(openYouTubeFromMenu), keyEquivalent: "y")
        openYouTubeItem.target = self
        menu.addItem(openYouTubeItem)

        let pinRes = makeCapsuleToggleMenuItem(
            title: "Pin Player on Top",
            isOn: isPinnedOnTop,
            onToggle: { [weak self] enabled in
                self?.setPinnedOnTop(enabled)
            }
        )
        quickMenu.addItem(pinRes.menuItem)

        let focusAudioRes = makeCapsuleToggleMenuItem(
            title: "Focus Audio",
            isOn: AppVolumeManager.shared.isAppVolumeOnly,
            onToggle: { enabled in
                AppVolumeManager.shared.isAppVolumeOnly = enabled
            }
        )
        quickMenu.addItem(focusAudioRes.menuItem)

        let shortcutsRes = makeCapsuleToggleMenuItem(
            title: "Global Shortcuts",
            isOn: GlobalHotKeyManager.shared.isEnabled,
            onToggle: { enabled in
                GlobalHotKeyManager.shared.isEnabled = enabled
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                    text: enabled ? "✓ Global Shortcuts: Enabled" : "Global Shortcuts: Disabled"
                )
            }
        )
        quickMenu.addItem(shortcutsRes.menuItem)

        let launchRes = makeCapsuleToggleMenuItem(
            title: "Launch at Login",
            isOn: LaunchAtLoginManager.isEnabled,
            onToggle: { enabled in
                if let error = LaunchAtLoginManager.setEnabled(enabled) {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                        text: "Launch at Login failed: \(error)"
                    )
                } else {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                        text: enabled ? "✓ Launch at Login: On" : "Launch at Login: Off"
                    )
                }
            }
        )
        quickMenu.addItem(launchRes.menuItem)

        quickMenu.addItem(NSMenuItem.separator())
        addScrobbleToggle(for: .lastFM, to: quickMenu)
        addScrobbleToggle(for: .listenBrainz, to: quickMenu)
        quickMenu.addItem(NSMenuItem.separator())

        let wakeRes = makeCapsuleToggleMenuItem(
            title: "Prevent Wake Auto-Play",
            isOn: NowPlayingManager.shared.isPreventAutoplayOnWakeEnabled,
            onToggle: { enabled in
                NowPlayingManager.shared.isPreventAutoplayOnWakeEnabled = enabled
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                    text: enabled ? "✓ Prevent Wake Auto-Play: Enabled" : "Prevent Wake Auto-Play: Disabled"
                )
            }
        )
        playbackMenu.addItem(wakeRes.menuItem)

        let discordBrandingRes = makeCapsuleToggleMenuItem(
            title: "Hide Mooziac Branding",
            isOn: DiscordRPCManager.shared.isBrandingHidden,
            onToggle: { enabled in
                DiscordRPCManager.shared.isBrandingHidden = enabled
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                    text: enabled ? "✓ Mooziac Branding: Hidden" : "Mooziac Branding: Visible"
                )
            }
        )
        playbackMenu.addItem(discordBrandingRes.menuItem)

        let upNextRes = makeCapsuleToggleMenuItem(
            title: "Up Next Alerts",
            isOn: UpNextAlertManager.shared.isEnabled,
            onToggle: { enabled in UpNextAlertManager.shared.isEnabled = enabled }
        )
        playbackMenu.addItem(upNextRes.menuItem)
        let playbackParent = NSMenuItem(title: "Playback & Options", action: nil, keyEquivalent: "")
        playbackParent.submenu = playbackMenu
        quickMenu.addItem(playbackParent)
        let quickParent = NSMenuItem(title: "Quick Controls", action: nil, keyEquivalent: "")
        quickParent.submenu = quickMenu
        menu.addItem(quickParent)

        menu.addItem(NSMenuItem.separator())

        let gestureParent = NSMenuItem(title: "Trackpad Gestures", action: nil, keyEquivalent: "")
        gestureParent.submenu = gestureMenu
        menu.addItem(gestureParent)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem.separator())

        let settingsParent = NSMenuItem(title: "Library & Downloads", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu(title: "Library & Downloads")

        settingsMenu.addItem(NSMenuItem(title: "Download Location", action: nil, keyEquivalent: ""))
        let downloadLocationItem = NSMenuItem(title: currentDownloadLocationTitle(), action: nil, keyEquivalent: "")
        downloadLocationItem.isEnabled = false
        settingsMenu.addItem(downloadLocationItem)
        settingsMenu.addItem(NSMenuItem.separator())
        let selectLocationItem = NSMenuItem(title: "Select Download Location…", action: #selector(selectDownloadLocationFromMenu), keyEquivalent: "")
        selectLocationItem.target = self
        settingsMenu.addItem(selectLocationItem)
        let importAudioItem = NSMenuItem(title: "Import Audio Files to Location…", action: #selector(importAudioFilesFromMenu), keyEquivalent: "")
        importAudioItem.target = self
        settingsMenu.addItem(importAudioItem)
        let importPlaylistFileItem = NSMenuItem(title: "Import Playlist File… (.m3u8, .json)", action: #selector(importPlaylistFileFromMenu), keyEquivalent: "")
        importPlaylistFileItem.target = self
        settingsMenu.addItem(importPlaylistFileItem)
        let importPlaylistMenuItem = NSMenuItem(title: "Import Playlist from Link…", action: #selector(importPlaylistFromMenu), keyEquivalent: "i")
        importPlaylistMenuItem.target = self
        settingsMenu.addItem(importPlaylistMenuItem)
        let resetLocationItem = NSMenuItem(title: "Reset to Default Location", action: #selector(resetDownloadLocationFromMenu), keyEquivalent: "")
        resetLocationItem.target = self
        settingsMenu.addItem(resetLocationItem)
        settingsMenu.addItem(NSMenuItem.separator())
        let clearHistoryItem = NSMenuItem(title: "Clear Listening History", action: #selector(clearListeningHistoryFromMenu), keyEquivalent: "")
        clearHistoryItem.target = self
        settingsMenu.addItem(clearHistoryItem)
        settingsMenu.addItem(NSMenuItem.separator())
        let settingsUpdateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u")
        settingsUpdateItem.target = self
        settingsMenu.addItem(settingsUpdateItem)
        let settingsSupportItem = NSMenuItem(title: "Help & Support", action: #selector(openSupportFromMenu), keyEquivalent: "")
        settingsSupportItem.target = self
        settingsMenu.addItem(settingsSupportItem)
        settingsMenu.removeItem(settingsUpdateItem)
        settingsMenu.removeItem(settingsSupportItem)
        settingsParent.submenu = settingsMenu
        menu.addItem(settingsParent)

        let syncItem = NSMenuItem(title: "Sync with YouTube Music", action: #selector(syncNowFromMenu), keyEquivalent: "")
        syncItem.isEnabled = LikedSongsManager.shared.isSignedIn
        syncItem.target = self
        accountMenu.addItem(syncItem)
        let resetLoginItem = NSMenuItem(title: "Reset Login…", action: #selector(confirmResetLoginFromMenu), keyEquivalent: "")
        resetLoginItem.target = self
        accountMenu.addItem(resetLoginItem)

        accountMenu.addItem(NSMenuItem.separator())
        addScrobbleAccountItems(for: .lastFM, to: accountMenu)
        accountMenu.addItem(NSMenuItem.separator())
        addScrobbleAccountItems(for: .listenBrainz, to: accountMenu)

        let accountParent = NSMenuItem(title: "Account & Sync", action: nil, keyEquivalent: "")
        accountParent.submenu = accountMenu
        menu.addItem(accountParent)

        let reloadItem = NSMenuItem(title: "Reload Player Engine…", action: #selector(confirmReloadFromMenu), keyEquivalent: "r")
        reloadItem.target = self
        playerMenu.addItem(reloadItem)
        let playerParent = NSMenuItem(title: "Player", action: nil, keyEquivalent: "")
        playerParent.submenu = playerMenu
        menu.addItem(playerParent)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u"))
        menu.addItem(NSMenuItem(title: "Help & Support", action: #selector(openSupportFromMenu), keyEquivalent: ""))

        menu.addItem(NSMenuItem(title: "Quit Mooziac", action: #selector(quitFromMenu), keyEquivalent: "q"))
        
        for item in menu.items {
            if item.target == nil {
                item.target = self
            }
        }
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func confirmResetLoginFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Reset YouTube Music Login?"
        alert.informativeText = "This clears the saved YouTube Music sign-in and starts a fresh session."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset Login")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { resetLoginFromMenu() }
    }

    @objc private func confirmReloadFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Reload the Player Engine?"
        alert.informativeText = "Playback may pause briefly while the player reloads."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { reloadFromMenu() }
    }
    
    @objc private func showGestureTutorialFromMenu() {
        NativeGestureTutorialWindowController.shared.showTutorial()
    }

    private func currentDownloadLocationTitle() -> String {
        let custom = UserDefaults.standard.string(forKey: "YTM_downloadsFolder")
        let folder = LocalLibraryManager.shared.musicFolderURL
        if let custom = custom, !custom.isEmpty {
            return "\(folder.path)"
        }
        return "Default — \(LocalLibraryManager.shared.defaultMusicFolderURL.path)"
    }

    @objc private func selectDownloadLocationFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "Select Download Location"
        panel.message = "Choose where Mooziac should save downloaded songs. Files already downloaded stay in their current folder."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.directoryURL = LocalLibraryManager.shared.musicFolderURL

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            LocalLibraryManager.shared.setMusicFolder(url)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Download location set to \(url.lastPathComponent)")
            if self.panel.isVisible {
                self.mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
            }
        }
    }

    @objc private func resetDownloadLocationFromMenu() {
        LocalLibraryManager.shared.resetMusicFolderToDefault()
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Download location reset to default")
        if panel.isVisible {
            mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
        }
    }

    @objc private func importAudioFilesFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "Import Audio Files to Download Location"
        panel.prompt = "Import Music"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .mp3]
        panel.directoryURL = LocalLibraryManager.shared.musicFolderURL

        panel.begin { [weak self] response in
            guard let self = self, response == .OK else { return }
            LocalLibraryManager.shared.importFiles(from: panel.urls) { count in
                DispatchQueue.main.async {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Imported \(count) audio track(s)")
                    if self.panel.isVisible {
                        self.mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
                        self.mainViewController.dynamicIslandPlayer.updateDownloadButtonState()
                    }
                }
            }
        }
    }

    @objc private func clearListeningHistoryFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Clear Listening History?"
        alert.informativeText = "Are you sure you want to clear your listening history? This action cannot be undone."
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Clear History")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearHistory()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Listening history cleared")
            if panel.isVisible {
                mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
            }
        }
    }

    @objc private func toggleMasterGestures() {
        EdgeVolumeEngine.shared.isEnabled.toggle()
    }
    
    @objc private func toggleAutoPauseOnDisconnect() {
        AudioRouteMonitor.shared.isAutoPauseOnDisconnectEnabled.toggle()
    }
    
    @objc private func toggleRightEdgeVolume() {
        EdgeVolumeEngine.shared.isRightEdgeVolumeEnabled.toggle()
    }
    
    @objc private func toggleRightCornerTaps() {
        EdgeVolumeEngine.shared.isRightCornerTapsEnabled.toggle()
    }
    
    @objc private func toggleLeftCornerTaps() {
        EdgeVolumeEngine.shared.isLeftCornerTapsEnabled.toggle()
    }
    
    @objc private func checkForUpdatesFromMenu() {
        UpdateManager.shared.checkForUpdates(userInitiated: true)
    }

    @objc private func openSupportFromMenu() {
        if let url = URL(string: "https://mooziac.pages.dev/support.html") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func importPlaylistFileFromMenu() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u8") ?? .plainText,
            UTType(filenameExtension: "m3u") ?? .plainText,
            .json
        ]
        panel.prompt = "Import Playlist"

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let fileURL = panel.url else { return }
            do {
                let data = try Data(contentsOf: fileURL)
                let result = try PlaylistFileCodec.decode(data, from: fileURL)
                guard !result.document.tracks.isEmpty else {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ No local tracks found in playlist")
                    return
                }
                guard let _ = PlaylistManager.shared.importPlaylistFile(result.document) else {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✕ Couldn't create playlist")
                    return
                }
                let skippedNote = result.skippedEntryCount > 0 ? " (\(result.skippedEntryCount) skipped)" : ""
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Imported \"\(result.document.name)\" (\(result.document.tracks.count) tracks)\(skippedNote)")
                if self?.panel.isVisible == true {
                    self?.mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
                }
            } catch {
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✕ \(error.localizedDescription)")
            }
        }
    }

    @objc private func importPlaylistFromMenu() {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Import Playlist from Link"
        alert.informativeText = "Paste a YouTube Music or YouTube playlist link:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "https://music.youtube.com/playlist?list=..."
        if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           clip.contains("list=") || clip.hasPrefix("PL") || clip.hasPrefix("RD") {
            textField.stringValue = clip
        }
        alert.accessoryView = textField
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let url = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return }

            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏳ Fetching playlist tracks...")
            PlaylistManager.shared.importPlaylist(from: url) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ \(error.localizedDescription)")
                case .success(let info):
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Imported: \"\(info.title)\" (\(info.trackCount) tracks)")
                    if self.panel.isVisible {
                        self.mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
                    }
                }
            }
        }
    }

    // MARK: - YouTube Mode Integration
    @objc func openYouTubeFromMenu() {
        presentYouTubeWindow()
    }

    @objc func switchToMusicPlayerFromMenu() {
        MainVideoWindowController.shared.closeYouTubeAndReturnToMooziac()
    }

    func showYouTubeContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Mooziac YouTube (Active)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Ad Blocker toggle
        let isAdBlock = YouTubeSettings.shared.isAdBlockEnabled
        let adBlockItem = NSMenuItem(title: "Ad Blocker", action: #selector(toggleYouTubeAdBlockerFromMenu(_:)), keyEquivalent: "")
        adBlockItem.state = isAdBlock ? .on : .off
        adBlockItem.target = self
        menu.addItem(adBlockItem)

        // SponsorBlock toggle
        let isSponsorBlock = YouTubeSettings.shared.isSponsorBlockEnabled
        let sponsorItem = NSMenuItem(title: "SponsorBlock (Auto-Skip)", action: #selector(toggleYouTubeSponsorBlockFromMenu(_:)), keyEquivalent: "")
        sponsorItem.state = isSponsorBlock ? .on : .off
        sponsorItem.target = self
        menu.addItem(sponsorItem)

        // Global Shortcuts toggle
        let isShortcuts = GlobalHotKeyManager.shared.isEnabled
        let shortcutsItem = NSMenuItem(title: "Global Shortcuts", action: #selector(toggleYouTubeGlobalShortcutsFromMenu(_:)), keyEquivalent: "")
        shortcutsItem.state = isShortcuts ? .on : .off
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        menu.addItem(NSMenuItem.separator())

        // Video Quality Submenu
        let qualityParent = NSMenuItem(title: "Video Quality", action: nil, keyEquivalent: "")
        let qualityMenu = NSMenu(title: "Video Quality")
        let qualities: [(String, VideoQuality)] = [
            ("Auto (Recommended)", .auto),
            ("4K Ultra HD (2160p)", .uhd2160),
            ("1440p QHD", .qhd1440),
            ("1080p Full HD", .fhd1080),
            ("720p HD", .hd720)
        ]
        let currentQuality = VideoPlayerCoordinator.shared.currentState.currentQuality
        for (qTitle, qVal) in qualities {
            let qItem = NSMenuItem(title: qTitle, action: #selector(selectYouTubeQualityFromMenu(_:)), keyEquivalent: "")
            qItem.representedObject = qVal.rawValue
            qItem.state = (currentQuality == qVal) ? .on : .off
            qItem.target = self
            qualityMenu.addItem(qItem)
        }
        qualityParent.submenu = qualityMenu
        menu.addItem(qualityParent)

        // Playback Speed Submenu
        let speedParent = NSMenuItem(title: "Playback Speed", action: nil, keyEquivalent: "")
        let speedMenu = NSMenu(title: "Playback Speed")
        let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let currentSpeed = VideoPlayerCoordinator.shared.currentState.playbackRate
        for sp in speeds {
            let label = sp == 1.0 ? "1.0× (Normal)" : String(format: "%.2f×", sp)
            let spItem = NSMenuItem(title: label, action: #selector(selectYouTubeSpeedFromMenu(_:)), keyEquivalent: "")
            spItem.representedObject = sp
            spItem.state = (abs(currentSpeed - sp) < 0.05) ? .on : .off
            spItem.target = self
            speedMenu.addItem(spItem)
        }
        speedParent.submenu = speedMenu
        menu.addItem(speedParent)

        // Trackpad Gestures Submenu for YouTube
        let gestureParent = NSMenuItem(title: "Trackpad Gestures", action: nil, keyEquivalent: "")
        let gestureMenu = NSMenu(title: "Trackpad Gestures")

        for gesture in GestureType.allCases {
            let action = GestureMappingManager.shared.getYouTubeAction(for: gesture)
            let item = NSMenuItem(title: "\(gesture.displayName) → \(action.displayName)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            gestureMenu.addItem(item)
        }
        gestureMenu.addItem(NSMenuItem.separator())
        let edgeItem = NSMenuItem(title: "Right Edge Slide → Volume Up/Down", action: nil, keyEquivalent: "")
        edgeItem.isEnabled = false
        gestureMenu.addItem(edgeItem)
        let menuBarScrollItem = NSMenuItem(title: "Menu Bar Scroll → Volume Up/Down", action: nil, keyEquivalent: "")
        menuBarScrollItem.isEnabled = false
        gestureMenu.addItem(menuBarScrollItem)

        gestureParent.submenu = gestureMenu
        menu.addItem(gestureParent)

        menu.addItem(NSMenuItem.separator())

        let switchItem = NSMenuItem(title: "Switch to Music Player", action: #selector(switchToMusicPlayerFromMenu), keyEquivalent: "")
        switchItem.target = self
        menu.addItem(switchItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Mooziac", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleYouTubeAdBlockerFromMenu(_ sender: NSMenuItem) {
        let newState = !YouTubeSettings.shared.isAdBlockEnabled
        YouTubeSettings.shared.isAdBlockEnabled = newState
        sender.state = newState ? .on : .off
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: newState ? "Ad Blocker: Enabled" : "Ad Blocker: Disabled")
        MainVideoWindowController.shared.reconfigureAndReload()
    }

    @objc private func toggleYouTubeSponsorBlockFromMenu(_ sender: NSMenuItem) {
        let newState = !YouTubeSettings.shared.isSponsorBlockEnabled
        YouTubeSettings.shared.isSponsorBlockEnabled = newState
        sender.state = newState ? .on : .off
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: newState ? "SponsorBlock: Enabled" : "SponsorBlock: Disabled")
        MainVideoWindowController.shared.reconfigureAndReload()
    }

    @objc private func selectYouTubeQualityFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let quality = VideoQuality(rawValue: raw) else { return }
        VideoPlayerCoordinator.shared.setQuality(quality)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Quality: \(quality.displayName)")
    }

    @objc private func selectYouTubeSpeedFromMenu(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? Double else { return }
        VideoPlayerCoordinator.shared.setPlaybackSpeed(speed)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: String(format: "Speed: %.2f×", speed))
    }

    @objc private func toggleYouTubeGlobalShortcutsFromMenu(_ sender: NSMenuItem) {
        let newState = !GlobalHotKeyManager.shared.isEnabled
        GlobalHotKeyManager.shared.isEnabled = newState
        sender.state = newState ? .on : .off
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: newState ? "Global Shortcuts: Enabled" : "Global Shortcuts: Disabled")
    }
}
