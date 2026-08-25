import AppKit
import WebKit

class StatusItemManager: NSObject {
    public static weak var shared: StatusItemManager?
    
    public private(set) var statusItem: NSStatusItem!
    var panel: StatusItemPanel!
    let mainViewController = MainViewController()
    public private(set) var isDraggedFromDock: Bool = false
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var keyEventMonitor: Any?
    
    public var statusButtonCenterInScreen: CGPoint? {
        guard let button = statusItem?.button else { return nil }
        
        if let window = button.window {
            let windowFrame = window.frame
            if windowFrame.width > 0 && windowFrame.height > 0 && windowFrame.minY > 0 {
                return CGPoint(x: windowFrame.midX, y: windowFrame.midY)
            }
            
            let rectInWindow = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(rectInWindow)
            if screenRect.minY > 0 {
                return CGPoint(x: screenRect.midX, y: screenRect.midY)
            }
        }
        return nil
    }
    
    override init() {
        super.init()
        StatusItemManager.shared = self
        setupStatusItem()
        setupPanel()
        observeEngineModeChanges()
    }

    private func observeEngineModeChanges() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("Mooziac_EngineModeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let mode =
                notification.userInfo?["mode"] as? String
            else { return }

            self?.updateEngineModeIndicator(mode: mode)
        }
    }

    private func updateEngineModeIndicator(mode: String) {
        let isOnline = (mode == "online")
        guard let button = statusItem?.button else { return }

        button.toolTip = isOnline
            ? "Mooziac Music Player (Scroll to adjust volume)"
            : "Mooziac Music Player — Offline Mode (Scroll to adjust volume)"

        if isOnline {
            restoreDefaultIcon(button)
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            if let image = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "Mooziac Offline")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            } else {
                restoreDefaultIcon(button)
            }
        }
    }
    
    public func playLaunchPopAnimation() {
        guard let button = statusItem?.button else { return }
        button.wantsLayer = true
        button.alphaValue = 0.0
        button.layer?.transform = CATransform3DMakeScale(0.4, 0.4, 1.0)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.38
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = 1.0
            button.layer?.transform = CATransform3DIdentity
        }
    }
    
    deinit {
        stopEventMonitors()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.alphaValue = 0.0
            restoreDefaultIcon(button)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Mooziac Music Player (Scroll to adjust volume)"
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if let button = self?.statusItem.button, event.window == button.window {
                let delta = event.deltaY
                if abs(delta) > 0.1 {
                    NowPlayingManager.shared.adjustVolume(deltaPercent: delta > 0 ? 4.0 : -4.0)
                    return nil
                }
            }
            return event
        }
    }
    
    private func restoreDefaultIcon(_ button: NSStatusBarButton) {
        if let customIcon = Bundle.main.image(forResource: "MenuBarIcon") ?? Bundle.main.image(forResource: "MOOZIAC_transparent") {
            let resized = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                customIcon.draw(in: rect)
                return true
            }
            resized.isTemplate = true
            button.image = resized
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Mooziac")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
        }
    }
    
    private func setupPanel() {
        panel = StatusItemPanel(contentViewController: mainViewController)
        
        // Always start docked directly under the status item on launch
        self.isDraggedFromDock = false
        UserDefaults.standard.set(false, forKey: "YTM_isDraggedFromDock")
        panel.level = .statusBar
        mainViewController.dynamicIslandPlayer.setResetPositionButtonHidden(true)
        
        mainViewController.onChangeSize = { [weak self] width, height in
            guard let self = self else { return }
            self.positionPanel(width: width, height: height)
        }
        
        mainViewController.onResetPosition = { [weak self] in
            guard let self = self else { return }
            self.isDraggedFromDock = false
            UserDefaults.standard.set(false, forKey: "YTM_isDraggedFromDock")
            self.panel.level = .statusBar
            let width = self.panel.frame.width
            let height = self.panel.frame.height
            self.positionPanel(width: width, height: height)
            self.mainViewController.dynamicIslandPlayer.setResetPositionButtonHidden(true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidMove), name: NSWindow.didMoveNotification, object: panel)
        
        // Handle connected display changes (reconnect, disconnect, resolution change)
        DisplayManager.shared.onDisplayConfigurationChanged = { [weak self] in
            self?.handleDisplayConfigurationChanged()
        }
    }
    
    @objc private func handleDisplayConfigurationChanged() {
        guard panel != nil else { return }
        
        let size = mainViewController.view.frame.size
        if isDraggedFromDock {
            let savedX = CGFloat(UserDefaults.standard.double(forKey: "YTM_playerFrameX"))
            let savedY = CGFloat(UserDefaults.standard.double(forKey: "YTM_playerFrameY"))
            let savedIDRaw = UserDefaults.standard.object(forKey: "YTM_savedDisplayID") as? UInt32
            let savedID = savedIDRaw != nil ? CGDirectDisplayID(savedIDRaw!) : nil
            
            let targetScreen = DisplayManager.shared.findScreen(forSavedID: savedID, fallbackOrigin: CGPoint(x: savedX, y: savedY))
            let unconstrainedFrame = NSRect(x: savedX, y: savedY, width: size.width, height: size.height)
            let clampedFrame = DisplayManager.shared.clampFrameToVisibleBounds(unconstrainedFrame, on: targetScreen, margin: 12)
            
            panel.setFrame(clampedFrame, display: true, animate: true)
        } else {
            positionPanel(width: size.width, height: size.height)
        }
        
        // Also update lyrics positioning for display change
        CenteredMenuBarLyricsWindowController.shared.repositionInCenter(contentWidth: 280)
    }
    
    private var isProgrammaticallyPositioning: Bool = false
    private var dragDebounceTimer: Timer?
    
    @objc private func panelDidMove() {
        guard !isProgrammaticallyPositioning else { return }
        guard panel != nil, let button = statusItem.button, let buttonWindow = button.window else { return }
        
        // Strictly ignore resize animations & only track when user is actively mouse-dragging the player
        guard !mainViewController.isBrowserMode, !mainViewController.isOfflineLibraryMode else { return }
        guard panel.frame.width <= 400.0 else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 || NSApp.currentEvent?.type == .leftMouseDragged else { return }
        
        let screen = panel.screen ?? buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let buttonBoundsInWindow = button.convert(button.bounds, to: nil)
        let buttonScreenFrame = buttonWindow.convertToScreen(buttonBoundsInWindow)
        
        var targetX: CGFloat
        var targetY: CGFloat
        let isValidPosition = buttonScreenFrame.origin.x > 50 && buttonScreenFrame.origin.x < (screenFrame.width - 5)
        
        let currentWidth = panel.frame.width
        let currentHeight = panel.frame.height
        
        if isValidPosition {
            let desiredX = buttonScreenFrame.midX - (currentWidth / 2.0)
            targetX = max(screen.visibleFrame.minX + 8, min(desiredX, screen.visibleFrame.maxX - currentWidth - 8))
            targetY = buttonScreenFrame.minY - currentHeight
        } else {
            targetX = screen.visibleFrame.maxX - currentWidth - 8
            let menuBarHeight = max(24, screenFrame.maxY - screen.visibleFrame.maxY)
            targetY = screenFrame.maxY - menuBarHeight - currentHeight
        }
        
        let currentPos = panel.frame.origin
        let distanceX = abs(currentPos.x - targetX)
        let distanceY = abs(currentPos.y - targetY)
        
        let isDragged = distanceX > 20 || distanceY > 20
        if isDragged != self.isDraggedFromDock {
            self.isDraggedFromDock = isDragged
            mainViewController.dynamicIslandPlayer.setResetPositionButtonHidden(!isDragged)
            if isDragged {
                panel.level = .floating
            } else {
                panel.level = .statusBar
            }
        }
        
        dragDebounceTimer?.invalidate()
        dragDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            guard let self = self, self.isDraggedFromDock else { return }
            let currentFrame = self.panel.frame
            let clampedFrame = DisplayManager.shared.clampFrameToVisibleBounds(currentFrame, on: screen, margin: 8)
            if currentFrame != clampedFrame {
                self.isProgrammaticallyPositioning = true
                self.panel.setFrame(clampedFrame, display: true, animate: true)
                self.isProgrammaticallyPositioning = false
            }
            
            let topY = clampedFrame.origin.y + clampedFrame.height
            UserDefaults.standard.set(true, forKey: "YTM_isDraggedFromDock")
            UserDefaults.standard.set(Double(clampedFrame.origin.x), forKey: "YTM_playerFrameX")
            UserDefaults.standard.set(Double(clampedFrame.origin.y), forKey: "YTM_playerFrameY")
            UserDefaults.standard.set(Double(topY), forKey: "YTM_playerTopY")
            if let displayID = DisplayManager.shared.displayID(for: screen) {
                UserDefaults.standard.set(displayID, forKey: "YTM_savedDisplayID")
            }
        }
    }
    
    func positionPanel(width: CGFloat, height: CGFloat) {
        positionCustomWindow(panel, width: width, height: height)
    }
    
    func positionCustomWindow(_ targetWindow: NSWindow, width: CGFloat, height: CGFloat) {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }
        
        isProgrammaticallyPositioning = true
        defer { isProgrammaticallyPositioning = false }
        
        let defaultScreen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screen = defaultScreen
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Exact status button frame in screen coordinates
        let buttonScreenFrame: NSRect
        if buttonWindow.frame.width > 0 && buttonWindow.frame.height > 0 && buttonWindow.frame.minY > 100 {
            buttonScreenFrame = buttonWindow.frame
        } else {
            let buttonBoundsInWindow = button.convert(button.bounds, to: nil)
            buttonScreenFrame = buttonWindow.convertToScreen(buttonBoundsInWindow)
        }
        
        // If in dragged/floating player mode and NOT in full-screen or offline library mode
        if isDraggedFromDock && width <= 360 && !mainViewController.isBrowserMode && !mainViewController.isOfflineLibraryMode,
           UserDefaults.standard.object(forKey: "YTM_playerFrameX") != nil {
            let savedX = CGFloat(UserDefaults.standard.double(forKey: "YTM_playerFrameX"))
            let savedTopY = CGFloat(UserDefaults.standard.double(forKey: "YTM_playerTopY"))
            let effectiveWidth = width
            let effectiveHeight = height
            
            let playerMidX = savedX + (360.0 / 2.0)
            let desiredX = playerMidX - (effectiveWidth / 2.0)
            let effectiveY = savedTopY > 0 ? (savedTopY - effectiveHeight) : CGFloat(UserDefaults.standard.double(forKey: "YTM_playerFrameY"))
            
            let savedIDRaw = UserDefaults.standard.object(forKey: "YTM_savedDisplayID") as? UInt32
            let savedID = savedIDRaw != nil ? CGDirectDisplayID(savedIDRaw!) : nil
            
            let targetScreen = DisplayManager.shared.findScreen(forSavedID: savedID, fallbackOrigin: CGPoint(x: desiredX, y: effectiveY))
            let rawFrame = NSRect(x: desiredX, y: effectiveY, width: effectiveWidth, height: effectiveHeight)
            let clampedFrame = DisplayManager.shared.clampFrameToVisibleBounds(rawFrame, on: targetScreen, margin: 8)
            
            targetWindow.setFrame(clampedFrame, display: true)
            return
        }
        
        var targetX: CGFloat
        var targetY: CGFloat
        
        let isValidPosition = buttonScreenFrame.origin.x > 50 && buttonScreenFrame.origin.x < (screenFrame.width - 5) && buttonScreenFrame.minY > 100
        
        if isValidPosition {
            // Center horizontally on the status button so every window size
            // (360 pill / 380 library / 800 browser) opens anchored under the icon
            let desiredX = buttonScreenFrame.midX - (width / 2.0)
            targetX = max(visibleFrame.minX + 8, min(desiredX, visibleFrame.maxX - width - 8))
            targetY = buttonScreenFrame.minY - height
        } else {
            targetX = visibleFrame.maxX - width - 8
            let menuBarHeight = max(24, screenFrame.maxY - visibleFrame.maxY)
            targetY = screenFrame.maxY - menuBarHeight - height
        }
        
        let rawFrame = NSRect(x: targetX, y: targetY, width: width, height: height)
        let clampedFrame = DisplayManager.shared.clampFrameToVisibleBounds(rawFrame, on: screen, margin: 0)
        targetWindow.setFrame(clampedFrame, display: true)
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.type == .rightMouseDown {
            showContextMenu(sender)
        } else if isDraggedFromDock {
            dockBackToMenuBar()
        } else if event?.clickCount == 2 {
            showPanel(sender)
        } else {
            togglePanel(sender)
        }
    }
    
    public func dockBackToMenuBar() {
        isDraggedFromDock = false
        UserDefaults.standard.set(false, forKey: "YTM_isDraggedFromDock")
        UserDefaults.standard.removeObject(forKey: "YTM_playerFrameX")
        UserDefaults.standard.removeObject(forKey: "YTM_playerFrameY")
        UserDefaults.standard.removeObject(forKey: "YTM_playerTopY")
        panel.level = .statusBar
        let size = mainViewController.view.frame.size
        positionCustomWindow(panel, width: size.width, height: size.height)
        mainViewController.dynamicIslandPlayer.setResetPositionButtonHidden(true)
    }

    func togglePanel(_ sender: NSStatusBarButton) {
        if isDraggedFromDock {
            dockBackToMenuBar()
            return
        }
        if panel.isVisible && panel.alphaValue > 0.5 {
            closePanel()
        } else {
            showPanel(sender)
        }
    }
    
    func showPanel(_ sender: NSStatusBarButton) {
        let size = mainViewController.view.frame.size
        positionPanel(width: size.width, height: size.height)
        
        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
        
        NowPlayingManager.shared.setPanelVisibility(true)
        startEventMonitors()
    }
    
    func closePanel() {
        NowPlayingManager.shared.setPanelVisibility(false)
        mainViewController.dynamicIslandPlayer.collapseSettings()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.stopEventMonitors()
        })
    }
    
    private func isClickInsidePanelOrStatusButton(mouseLoc: NSPoint) -> Bool {
        guard let panel = self.panel else { return false }
        
        // 0. If any modal window or alert sheet is currently active, do not dismiss panel
        if NSApp.modalWindow != nil {
            return true
        }
        
        // 1. Check if inside the main popup panel frame
        if panel.frame.contains(mouseLoc) {
            return true
        }
        
        // 2. Check if inside the status bar item button or its window
        if let button = statusItem?.button, let buttonWindow = button.window {
            let btnScreenFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if btnScreenFrame.contains(mouseLoc) || buttonWindow.frame.contains(mouseLoc) {
                return true
            }
        }
        
        // 3. Check any child/attached windows (like NSMenu popups, alert sheets, etc.)
        for child in panel.childWindows ?? [] {
            if child.frame.contains(mouseLoc) {
                return true
            }
        }
        
        // 4. Check any visible window belonging to our application (NSAlert, NSOpenPanel, sheet, popup, etc.)
        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(mouseLoc) {
                return true
            }
        }
        
        return false
    }
    
    private func startEventMonitors() {
        stopEventMonitors()
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return event }
            if self.isDraggedFromDock { return event }
            if NSApp.modalWindow != nil { return event }
            
            let mouseLoc = NSEvent.mouseLocation
            if self.isClickInsidePanelOrStatusButton(mouseLoc: mouseLoc) {
                return event
            }
            
            self.closePanel()
            return event
        }
        
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return event }
            
            // 1. If focus is on any native text input/editor, let the event pass through untouched
            if let responder = self.panel.firstResponder {
                if responder is NSText || responder is NSTextView || responder is NSTextField || responder is NSSearchField {
                    return event
                }
                // 2. If focus is inside WKWebView / WebKit content (such as YouTube Music search bar), let WebKit handle it natively
                let responderClass = String(describing: type(of: responder))
                if responderClass.contains("WK") || responderClass.contains("Web") || (responder as? NSView)?.isDescendant(of: self.mainViewController.webViewContainer.webView) == true {
                    return event
                }
            }

            if KeyboardCommandHandler.handle(keyCode: event.keyCode,
                                             isRepeat: event.isARepeat,
                                             showOverlay: { text in
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: text)
            }) {
                return nil
            }
            return event
        }
        
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }
            if self.isDraggedFromDock { return }
            if NSApp.modalWindow != nil { return }
            
            let mouseLoc = NSEvent.mouseLocation
            if self.isClickInsidePanelOrStatusButton(mouseLoc: mouseLoc) {
                return
            }
            
            self.closePanel()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidResignActive), name: NSApplication.didResignActiveNotification, object: nil)
    }
    
    func stopEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
    }
    
    @objc private func appDidResignActive() {
        guard panel.isVisible && !isDraggedFromDock else { return }
        if NSApp.modalWindow != nil { return }
        let mouseLoc = NSEvent.mouseLocation
        if isClickInsidePanelOrStatusButton(mouseLoc: mouseLoc) {
            return
        }
        closePanel()
    }
    @objc private func toggleFromMenu() {
        if let button = statusItem.button {
            togglePanel(button)
        }
    }
    
    @objc private func toggleCenteredLyricsFromMenu() {
        CenteredMenuBarLyricsWindowController.shared.toggleOverlay()
    }
    
    @objc func resetLoginFromMenu() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                DispatchQueue.main.async { [weak self] in
                    UserDefaults.standard.set(false, forKey: "YTM_hasLoggedInOnce")
                    NowPlayingManager.shared.flushSessionState(keepCookies: false)
                    self?.mainViewController.setBrowserVisible(false)
                    self?.mainViewController.webViewContainer.loadMusicHome(autoPlayRandom: true)
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Reset Login & Started Fresh")
                }
            }
        }
    }
    
    @objc func reloadFromMenu() {
        mainViewController.webViewContainer.reloadPlayerEngine(forceHome: false)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Reloaded Player Engine")
    }

    @objc func syncNowFromMenu() {
        guard PlaylistSyncManager.shared.isSignedIn else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ Sign in to sync with YouTube Music")
            return
        }
        if PlaylistSyncManager.shared.isSyncInProgress {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⟳ Sync already in progress")
            return
        }
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⟳ Syncing with YouTube Music…")
        PlaylistSyncManager.shared.syncNow()
    }
    
    @objc func quitFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Quit Mooziac?"
        alert.informativeText = "Are you sure you want to quit Mooziac?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
}
