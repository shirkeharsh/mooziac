import AppKit

extension StatusItemManager {
    private func makeCapsuleToggleMenuItem(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> (menuItem: NSMenuItem, toggleView: NativeCapsuleToggleView) {
        let menuItem = NSMenuItem()
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 12, y: 3, width: 220, height: 20)
        label.font = NSFont.systemFont(ofSize: 12.0, weight: .regular)
        label.textColor = NSColor.labelColor
        
        let toggle = NativeCapsuleToggleView(frame: NSRect(x: 236, y: 4, width: 32, height: 18))
        toggle.isOn = isOn
        toggle.onToggle = onToggle
        
        containerView.addSubview(label)
        containerView.addSubview(toggle)
        
        menuItem.view = containerView
        return (menuItem, toggle)
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
        if panel.isVisible {
            mainViewController.dynamicIslandPlayer.collapseSettings()
            panel.alphaValue = 0.0
            panel.orderOut(nil)
            stopEventMonitors()
        }
        
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
        
        let gestureParent = NSMenuItem(title: "Trackpad Gestures Settings", action: nil, keyEquivalent: "")
        gestureParent.submenu = gestureMenu
        menu.addItem(gestureParent)
        
        menu.addItem(NSMenuItem.separator())

        let settingsParent = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu(title: "Settings")
        settingsMenu.addItem(NSMenuItem(title: "Download Location", action: nil, keyEquivalent: ""))
        let downloadLocationItem = NSMenuItem(title: "📁 \(currentDownloadLocationTitle())", action: nil, keyEquivalent: "")
        downloadLocationItem.isEnabled = false
        settingsMenu.addItem(downloadLocationItem)
        settingsMenu.addItem(NSMenuItem.separator())
        let selectLocationItem = NSMenuItem(title: "Select Download Location…", action: #selector(selectDownloadLocationFromMenu), keyEquivalent: "")
        selectLocationItem.target = self
        settingsMenu.addItem(selectLocationItem)
        let importAudioItem = NSMenuItem(title: "Import Audio Files to Location…", action: #selector(importAudioFilesFromMenu), keyEquivalent: "")
        importAudioItem.target = self
        settingsMenu.addItem(importAudioItem)
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
        settingsParent.submenu = settingsMenu
        menu.addItem(settingsParent)

        menu.addItem(NSMenuItem(title: "Reset Login (Fresh Start)", action: #selector(resetLoginFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reload Player Engine", action: #selector(reloadFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        let syncItem = NSMenuItem(title: "Sync with YouTube Music", action: #selector(syncNowFromMenu), keyEquivalent: "")
        syncItem.isEnabled = LikedSongsManager.shared.isSignedIn
        menu.addItem(syncItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u"))
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
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "📁 Download location set to \(url.lastPathComponent)")
            if self.panel.isVisible {
                self.mainViewController.dynamicIslandPlayer.refreshPlaylistsSection()
            }
        }
    }

    @objc private func resetDownloadLocationFromMenu() {
        LocalLibraryManager.shared.resetMusicFolderToDefault()
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "📁 Download location reset to default")
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
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "🗑 Listening history cleared")
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
}