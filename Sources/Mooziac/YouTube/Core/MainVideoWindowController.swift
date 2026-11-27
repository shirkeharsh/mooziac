import AppKit
import UniformTypeIdentifiers
import WebKit

final class MainVideoContainerView: NSView {}

public class MainVideoWindowController: NSWindowController, NSWindowDelegate, MooziacHeaderBarDelegate, WKNavigationDelegate {
    public static let shared = MainVideoWindowController()
    public private(set) static var isWindowVisible: Bool = false

    public static func calculateDefaultFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 202, y: 398, width: 1012, height: 578)
        }
        let targetWidth: CGFloat = 1012.0
        let targetHeight: CGFloat = 578.0
        let x: CGFloat = 202.0
        let y = round(screen.frame.height - 118.0 - targetHeight)

        return NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    private var webView: YouTubeWebView?
    private var lastVisitedURL: URL? = URL(string: "https://www.youtube.com")
    private var webViewConstraints: [NSLayoutConstraint] = []
    private let playerBridge: YouTubePlayerBridge
    private let headerBarView: MooziacHeaderBarView
    private let visualEffectBackdrop = NSVisualEffectView()
    private var containerView: MainVideoContainerView?
    private var currentAmbientColor: NSColor?
    private var currentArtworkTask: URLSessionDataTask?
    private var lastProcessedVideoId: String = ""

    private var canGoBackObserver: NSKeyValueObservation?
    private var canGoForwardObserver: NSKeyValueObservation?
    private var headerBarHeightConstraint: NSLayoutConstraint?
    private var webViewTopConstraint: NSLayoutConstraint?
    private var mouseCheckTimer: Timer?
    private var headerBarHideTimer: Timer?
    public private(set) var isUserSignedIn: Bool = false
    public private(set) var isPlayerFullscreen: Bool = false
    private var wasWindowAlreadyInFullScreenBeforePlayer: Bool = false
    private var isTransitioningFullScreen: Bool = false
    /// Close / minimize requested while in (or entering) full screen: finish once the transition ends.
    private var pendingCloseAfterFullScreenExit: Bool = false
    private var pendingMinimizeAfterFullScreenExit: Bool = false
    private var wasInPictureInPicture: Bool = false

    init() {
        let bridge = YouTubePlayerBridge()
        self.playerBridge = bridge
        self.headerBarView = MooziacHeaderBarView()

        let initialRect = MainVideoWindowController.calculateDefaultFrame()
        let window = NSWindow(
            contentRect: initialRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Mooziac"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.isOpaque = true
        window.backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        window.minSize = NSSize(width: 520, height: 340)
        window.collectionBehavior = [.fullScreenPrimary]
        window.setFrame(initialRect, display: true)
        window.setFrameAutosaveName("MooziacMainWindow")

        super.init(window: window)
        hideDefaultTrafficLights(window: window)
        window.delegate = self
        headerBarView.delegate = self

        setupViews(window: window)
        setupCoordinator()
        checkAuthenticationStatus()
        setupKeyboardShortcuts()

        applyTheme(.liquidFluid)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(window: NSWindow) {
        let container = MainVideoContainerView(frame: window.contentView?.bounds ?? .zero)
        container.wantsLayer = true
        let darkBg = NSColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        container.layer?.backgroundColor = darkBg.cgColor
        self.containerView = container
        window.contentView = container

        visualEffectBackdrop.wantsLayer = true
        visualEffectBackdrop.material = .hudWindow
        visualEffectBackdrop.blendingMode = .behindWindow
        visualEffectBackdrop.state = .inactive
        visualEffectBackdrop.isHidden = true
        visualEffectBackdrop.translatesAutoresizingMaskIntoConstraints = false

        headerBarView.translatesAutoresizingMaskIntoConstraints = false
        headerBarView.onHoverStateChanged = { [weak self] isHovered in
            guard let self = self, let win = self.window, win.styleMask.contains(.fullScreen) else { return }
            if isHovered {
                self.showOverlayHeaderBar()
            } else {
                self.scheduleHeaderBarHide()
            }
        }

        container.addSubview(visualEffectBackdrop)
        container.addSubview(headerBarView)

        let heightConstraint = headerBarView.heightAnchor.constraint(equalToConstant: 44)
        self.headerBarHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            visualEffectBackdrop.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffectBackdrop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffectBackdrop.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffectBackdrop.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            headerBarView.topAnchor.constraint(equalTo: container.topAnchor),
            headerBarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerBarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            heightConstraint
        ])
    }

    @discardableResult
    public func ensureWebView() -> YouTubeWebView {
        if let existing = self.webView {
            return existing
        }

        let wv = YouTubeWebView(frame: .zero, bridge: playerBridge)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        self.webView = wv

        if let container = self.containerView {
            container.addSubview(wv)
            container.addSubview(headerBarView, positioned: .above, relativeTo: wv)
            headerBarView.wantsLayer = true
            headerBarView.layer?.zPosition = 1000

            let topConstraint = wv.topAnchor.constraint(equalTo: headerBarView.bottomAnchor)
            self.webViewTopConstraint = topConstraint

            let constraints = [
                topConstraint,
                wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                wv.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ]
            self.webViewConstraints = constraints
            NSLayoutConstraint.activate(constraints)
        }

        VideoPlayerCoordinator.shared.webView = wv
        setupNavigationObservers()

        let targetURL = lastVisitedURL ?? URL(string: "https://www.youtube.com")!
        wv.load(URLRequest(url: targetURL))
        return wv
    }

    public func teardownWebView() {
        guard let wv = self.webView else { return }

        // 1. Capture current URL to restore when user returns to YouTube
        if let currentURL = wv.url, currentURL.host?.contains("youtube.com") == true {
            lastVisitedURL = currentURL
        }

        // 2. Identify the specific WebContent PID for this web view so we can guarantee termination
        let pidNum = wv.value(forKey: "_webProcessIdentifier") as? NSNumber
        let webPID = pidNum?.int32Value ?? 0

        canGoBackObserver?.invalidate()
        canGoBackObserver = nil
        canGoForwardObserver?.invalidate()
        canGoForwardObserver = nil

        headerBarView.updateNavigationState(canGoBack: false, canGoForward: false)

        if #available(macOS 15.4, *) {
            WebExtensionManager.shared.detachWebView()
        }

        if #available(macOS 12.0, *) {
            wv.pauseAllMediaPlayback()
        }
        wv.stopLoading()

        VideoPlayerCoordinator.shared.webView = nil

        NSLayoutConstraint.deactivate(webViewConstraints)
        webViewConstraints.removeAll()
        wv.removeFromSuperview()

        // 3. Close media presentations and instruct WebKit to terminate the WebContent process
        if wv.responds(to: NSSelectorFromString("_closeAllMediaPresentations")) {
            wv.perform(NSSelectorFromString("_closeAllMediaPresentations"))
        }
        if wv.responds(to: NSSelectorFromString("_killWebContentProcess")) {
            wv.perform(NSSelectorFromString("_killWebContentProcess"))
        }
        if wv.responds(to: NSSelectorFromString("_close")) {
            wv.perform(NSSelectorFromString("_close"))
        }

        // 4. If the WebContent PID is still alive, send SIGKILL to ensure it disappears from Task Manager
        if webPID > 0 {
            kill(webPID, SIGKILL)
        }

        self.webView = nil
    }

    private func setupCoordinator() {
        playerBridge.delegate = VideoPlayerCoordinator.shared
        VideoPlayerCoordinator.shared.webView = webView
    }

    private func setupNavigationObservers() {
        guard let wv = self.webView else { return }
        canGoBackObserver = wv.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.headerBarView.updateNavigationState(canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
            }
        }

        canGoForwardObserver = wv.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.headerBarView.updateNavigationState(canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
            }
        }
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcutHandler.shared.startMonitoring()
    }

    // MARK: - Navigation & Refresh Actions
    @objc public func reload() {
        webView?.reload()
    }

    public func loadURL(_ url: URL) {
        lastVisitedURL = url
        ensureWebView().load(URLRequest(url: url))
    }

    @objc public func reconfigureAndReload() {
        guard let webView = self.webView else { return }
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.removeAllContentRuleLists()

        // Same installer as the first load, so nothing gets lost or swapped on reconfigure
        YouTubeWebView.installUserScripts(into: ucc)

        webView.reload()
    }

    @objc public func goBack() {
        guard let wv = self.webView else { return }
        wv.evaluateJavaScript("window.__mooziacMinimizeToMiniplayer ? window.__mooziacMinimizeToMiniplayer() : false;") { [weak self] result, _ in
            DispatchQueue.main.async {
                guard let self = self, let currentWv = self.webView else { return }
                if let handled = result as? Bool, handled { return }
                if currentWv.canGoBack { currentWv.goBack() }
            }
        }
    }

    @objc public func goForward() {
        if let wv = webView, wv.canGoForward { wv.goForward() }
    }

    @objc public func togglePiP() {
        VideoPlayerCoordinator.shared.togglePictureInPicture()
    }

    public func focusSearch() {
        guard let wv = self.webView else { return }
        let script = """
        (function() {
            var searchInput = document.querySelector('input#search') || document.querySelector('input[name="search_query"]');
            if (searchInput) {
                searchInput.focus();
                searchInput.select();
            }
        })();
        """
        wv.evaluateJavaScript(script, completionHandler: nil)
    }

    public func updatePlaybackState(_ state: VideoPlaybackState) {
        headerBarView.updatePlaybackState(state)

        if state.isPictureInPicture {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.applyPiPSpacesBehavior()
            }
        } else if wasInPictureInPicture {
            NSApp.presentationOptions = []
            restoreWindowFromMinimizeOrHidden()
        }
        wasInPictureInPicture = state.isPictureInPicture

        // NOTE: Do NOT touch the header bar's height/hidden/alpha here.
        // In fullscreen its visibility is fully controlled by the hover logic
        // (showOverlayHeaderBar / scheduleHeaderBarHide). Playback state updates
        // fire constantly and used to collapse the bar to 0pt height and re-hide it.
    }

    // MARK: - Theme Management
    public func applyTheme(_ theme: PlayerTheme = .liquidFluid, ambientColor: NSColor? = nil) {
        guard let window = self.window else { return }

        visualEffectBackdrop.isHidden = true
        visualEffectBackdrop.state = .inactive
        window.isOpaque = true
        let darkBg = NSColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        window.backgroundColor = darkBg
        containerView?.layer?.backgroundColor = darkBg.cgColor
        containerView?.layer?.drawsAsynchronously = true

        headerBarView.applyTheme(.liquidFluid)
        webView?.applyThemeUnderPage(.liquidFluid)
    }

    public func updateBestPart(time: Double, formattedTime: String) {
        headerBarView.updateBestPart(time: time, formattedTime: formattedTime)
    }

    public func resetBestPart() {
        headerBarView.resetBestPart()
    }

    // MARK: - MooziacHeaderBarDelegate
    public func headerBarDidTapClose() {
        closeYouTubeAndReturnToMooziac()
    }

    public override func showWindow(_ sender: Any?) {
        Self.isWindowVisible = true
        window?.alphaValue = 1.0
        window?.ignoresMouseEvents = false
        super.showWindow(sender)
    }

    public func closeYouTubeAndReturnToMooziac() {
        // Stop playback right away so nothing keeps playing while the window animates out
        VideoPlayerCoordinator.shared.pause()

        // Never hide a window that is still in a full-screen Space (that can leave a black screen).
        // Leave full screen first; the real close happens when the transition has finished.
        if isTransitioningFullScreen {
            pendingCloseAfterFullScreenExit = true
            return
        }
        if let win = window, win.styleMask.contains(.fullScreen) {
            pendingCloseAfterFullScreenExit = true
            win.toggleFullScreen(nil)
            return
        }
        finishClosingYouTube()
    }

    private func finishClosingYouTube() {
        pendingCloseAfterFullScreenExit = false
        pendingMinimizeAfterFullScreenExit = false
        Self.isWindowVisible = false
        KeyboardShortcutHandler.shared.stopMonitoring()
        VideoPlayerCoordinator.shared.pause()
        teardownWebView()
        isPlayerFullscreen = false
        wasWindowAlreadyInFullScreenBeforePlayer = false
        window?.alphaValue = 1.0
        window?.ignoresMouseEvents = false
        window?.orderOut(nil)
        StatusItemManager.shared?.resumeMooziacFromYouTube()
    }

    public func headerBarDidTapQuit() {
        closeYouTubeAndReturnToMooziac()
    }

    public func headerBarDidTapMinimize() {
        performMinimize()
    }

    public func headerBarDidTapFullscreen() {
        toggleWindowFullscreen()
    }

    public func toggleWindowFullscreen() {
        guard let win = window, !isTransitioningFullScreen else { return }
        if isPlayerFullscreen {
            // If the window only went full screen because of the player, leaving player mode
            // already leaves full screen. Toggling again would flip it straight back.
            let windowExitsWithPlayer = !wasWindowAlreadyInFullScreenBeforePlayer
            setPlayerFullscreen(false)
            if windowExitsWithPlayer { return }
        }
        wasWindowAlreadyInFullScreenBeforePlayer = false
        win.collectionBehavior = [.fullScreenPrimary]
        win.toggleFullScreen(nil)
    }

    public func setPlayerFullscreen(_ enabled: Bool) {
        isPlayerFullscreen = enabled
        updateFullscreenLayout(isFullscreen: window?.styleMask.contains(.fullScreen) == true)
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
        webView?.needsLayout = true
        webView?.layoutSubtreeIfNeeded()
        webView?.evaluateJavaScript("window.__mooziacSetFullscreenState && window.__mooziacSetFullscreenState(\(enabled));", completionHandler: nil)

        // If player fullscreen is exiting and the window was NOT in window fullscreen before player expanded,
        // exit window fullscreen back to windowed mode:
        if !enabled && !wasWindowAlreadyInFullScreenBeforePlayer {
            if let win = window, win.styleMask.contains(.fullScreen) {
                win.toggleFullScreen(nil)
            }
        }
    }

    public func updateFullscreenLayout(isFullscreen: Bool) {
        guard let container = self.containerView, let wv = self.webView else { return }
        NSLog("[Mooziac FS] updateFullscreenLayout isFullscreen=\(isFullscreen)")
        webViewTopConstraint?.isActive = false
        if isFullscreen {
            // In fullscreen: webview expands to 100% of the screen from top to bottom
            let topConstraint = wv.topAnchor.constraint(equalTo: container.topAnchor)
            self.webViewTopConstraint = topConstraint
            topConstraint.isActive = true
            headerBarHeightConstraint?.constant = 44
            headerBarView.layer?.zPosition = 1000
            headerBarView.alphaValue = 0.0
            headerBarView.isHidden = true
            startFullscreenMouseMonitoring()
        } else {
            stopFullscreenMouseMonitoring()
            let topConstraint = wv.topAnchor.constraint(equalTo: headerBarView.bottomAnchor)
            self.webViewTopConstraint = topConstraint
            topConstraint.isActive = true
            headerBarHeightConstraint?.constant = 44
            headerBarView.alphaValue = 1.0
            headerBarView.isHidden = false
        }
        container.layoutSubtreeIfNeeded()
    }

    public func startFullscreenMouseMonitoring() {
        stopFullscreenMouseMonitoring()

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.handleMouseMovementForTopEdge()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.mouseCheckTimer = timer
    }

    public func stopFullscreenMouseMonitoring() {
        mouseCheckTimer?.invalidate()
        mouseCheckTimer = nil
        headerBarHideTimer?.invalidate()
        headerBarHideTimer = nil
    }

    public func handleMouseMovementForTopEdge() {
        guard let win = window, win.styleMask.contains(.fullScreen) else { return }
        let mouseLoc = NSEvent.mouseLocation
        let screen = win.screen ?? NSScreen.main
        let screenFrame = screen?.frame ?? win.frame

        // Check if mouse is horizontally within the window's screen
        guard mouseLoc.x >= screenFrame.minX && mouseLoc.x <= screenFrame.maxX else { return }
        guard mouseLoc.y >= screenFrame.minY && mouseLoc.y <= screenFrame.maxY else { return }

        let distanceFromTop = screenFrame.maxY - mouseLoc.y

        // Top edge detection: mouse touches within 20 points of the top edge
        if distanceFromTop <= 20 {
            showOverlayHeaderBar()
        } else if distanceFromTop <= 52 {
            // Mouse is interacting with or hovering directly over the header bar (44pt)
            // Cancel any pending hide countdown so it stays steady
            if headerBarHideTimer != nil {
                headerBarHideTimer?.invalidate()
                headerBarHideTimer = nil
            }
        } else if distanceFromTop > 65 {
            // Mouse moved down into video content
            if !headerBarView.isHidden && headerBarView.alphaValue > 0.05 && headerBarHideTimer == nil {
                scheduleHeaderBarHide()
            }
        }
    }

    public func showOverlayHeaderBar() {
        headerBarHideTimer?.invalidate()
        headerBarHideTimer = nil
        guard let win = window, win.styleMask.contains(.fullScreen) else { return }
        if headerBarView.isHidden || headerBarView.alphaValue < 0.95 {
            NSLog("[Mooziac FS] showOverlayHeaderBar: revealing header bar")
            headerBarView.isHidden = false
            headerBarView.layer?.zPosition = 1000
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.headerBarView.animator().alphaValue = 1.0
            }
        }
    }

    public func scheduleHeaderBarHide() {
        guard let win = window, win.styleMask.contains(.fullScreen) else { return }
        headerBarHideTimer?.invalidate()
        NSLog("[Mooziac FS] scheduleHeaderBarHide: scheduling hide in 1.5s")
        headerBarHideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self, let win = self.window, win.styleMask.contains(.fullScreen) else { return }
            let mouseLoc = NSEvent.mouseLocation
            let screen = win.screen ?? NSScreen.main
            let screenFrame = screen?.frame ?? win.frame
            let distanceFromTop = screenFrame.maxY - mouseLoc.y

            // Safeguard: do not hide if mouse returned to or is hovering over the header bar
            if distanceFromTop <= 52 {
                NSLog("[Mooziac FS] scheduleHeaderBarHide cancelled: cursor is at top (dist=\(distanceFromTop))")
                return
            }

            NSLog("[Mooziac FS] scheduleHeaderBarHide: fading out header bar")
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.headerBarView.animator().alphaValue = 0.0
            } completionHandler: {
                if let win = self.window, win.styleMask.contains(.fullScreen) && self.headerBarView.alphaValue == 0.0 {
                    self.headerBarView.isHidden = true
                    NSLog("[Mooziac FS] headerBar is now hidden")
                }
            }
        }
    }

    public func handleBridgeFullscreenRequest(wantsFullscreen: Bool? = nil) {
        guard let win = window, !isTransitioningFullScreen else { return }
        let isWindowFs = win.styleMask.contains(.fullScreen)

        let targetPlayerFs: Bool
        if let wants = wantsFullscreen {
            targetPlayerFs = wants
        } else {
            targetPlayerFs = !isPlayerFullscreen
        }

        if isWindowFs {
            // Window is ALREADY in macOS fullscreen space
            if targetPlayerFs {
                wasWindowAlreadyInFullScreenBeforePlayer = true
                setPlayerFullscreen(true)
            } else {
                setPlayerFullscreen(false)
                wasWindowAlreadyInFullScreenBeforePlayer = false
            }
        } else {
            // Window is currently in WINDOWED mode
            if targetPlayerFs {
                wasWindowAlreadyInFullScreenBeforePlayer = false
                isPlayerFullscreen = true
                win.collectionBehavior = [.fullScreenPrimary]
                win.toggleFullScreen(nil)
            } else {
                setPlayerFullscreen(false)
            }
        }
    }

    public var isPiPActive: Bool {
        VideoPlayerCoordinator.shared.currentState.isPictureInPicture ||
            NSApp.windows.contains { w in
                guard w.isVisible else { return false }
                let cls = String(describing: type(of: w))
                return cls.contains("PIP") || cls.contains("PictureInPicture")
            }
    }

    public func performMinimize() {
        Self.isWindowVisible = false
        KeyboardShortcutHandler.shared.stopMonitoring()
        guard let win = window else { return }
        if isTransitioningFullScreen || win.styleMask.contains(.fullScreen) {
            // Minimize once the full-screen transition has really finished (no guessing with a timer)
            pendingMinimizeAfterFullScreenExit = true
            if !isTransitioningFullScreen {
                win.toggleFullScreen(nil)
            }
            return
        }
        // When Picture-in-Picture is active, both miniaturize(nil) and orderOut(nil)
        // mark the host NSWindow as off-screen/non-visible, causing macOS PIPViewController
        // to reject the "Return to Window" button. Keep the window in the window list
        // while making it completely transparent, click-through, and ordered behind other apps.
        if isPiPActive {
            win.alphaValue = 0.0
            win.ignoresMouseEvents = true
            win.orderBack(nil)
            return
        }
        let btn = win.standardWindowButton(.miniaturizeButton)
        let wasHidden = btn?.isHidden ?? false
        let wasAlpha = btn?.alphaValue ?? 0
        btn?.isHidden = false
        btn?.alphaValue = 1.0
        btn?.isEnabled = true
        win.miniaturize(nil)
        btn?.alphaValue = wasAlpha
        btn?.isHidden = wasHidden
    }

    public func handleBridgePiPDidExit() {
        NSApp.presentationOptions = []
        wasInPictureInPicture = false
        restoreWindowFromMinimizeOrHidden()
    }

    public func restoreWindowFromMinimizeOrHidden() {
        guard let win = window else { return }
        if win.isMiniaturized {
            win.deminiaturize(nil)
        }
        let needsRestore = !win.isVisible || !Self.isWindowVisible || win.alphaValue < 0.99 || win.ignoresMouseEvents
        win.alphaValue = 1.0
        win.ignoresMouseEvents = false
        if needsRestore {
            showWindow(nil)
            win.makeKeyAndOrderFront(nil)
            KeyboardShortcutHandler.shared.startMonitoring()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func headerBarDidTapBack() {
        goBack()
    }

    public func headerBarDidTapForward() {
        goForward()
    }

    public func headerBarDidTapReload() {
        reload()
    }

    public func headerBarDidTapShorts() {
        if isPlayerFullscreen {
            handleBridgeFullscreenRequest(wantsFullscreen: false)
        }
        let wv = ensureWebView()
        guard wv.url?.host?.contains("youtube.com") == true else {
            if let url = URL(string: "https://www.youtube.com/shorts") {
                loadURL(url)
            }
            return
        }

        let js = """
        (function() {
            var shortsLink = document.querySelector('ytd-mini-guide-entry-renderer a[href="/shorts"], ytd-guide-entry-renderer a[href="/shorts"], a[title="Shorts"]');
            if (shortsLink) {
                shortsLink.click();
                return true;
            }
            try {
                var a = document.createElement('a');
                a.href = '/shorts';
                a.className = 'yt-simple-endpoint';
                (document.querySelector('ytd-app') || document.body).appendChild(a);
                a.click();
                a.remove();
            } catch(e) {}
            setTimeout(function() {
                if (window.location.pathname.indexOf('/shorts') !== 0) {
                    window.location.href = 'https://www.youtube.com/shorts';
                }
            }, 250);
            return true;
        })();
        """
        wv.evaluateJavaScript(js) { [weak self] result, error in
            DispatchQueue.main.async {
                if error != nil || (result as? Bool) != true {
                    if let url = URL(string: "https://www.youtube.com/shorts") {
                        self?.loadURL(url)
                    }
                }
            }
        }
    }

    public func headerBarDidTapCaptions() {
        VideoPlayerCoordinator.shared.toggleSubtitles()
    }

    public func headerBarDidTapLike() {}

    public func headerBarDidTapPlaylists(from sender: NSButton) {
        let menu = NSMenu(title: "Playlists & Library")
        let current = VideoPlayerCoordinator.shared.currentState

        // 1. Watch History Submenu (Offline)
        let records = YouTubeDatabaseManager.shared.fetchHistory(limit: 30)
        let historyMenuItem = NSMenuItem(title: "Watch History (\(records.count))", action: nil, keyEquivalent: "")
        if let img = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Watch History") {
            historyMenuItem.image = img
        }
        let historySubmenu = NSMenu(title: "Watch History")
        if records.isEmpty {
            let emptyItem = NSMenuItem(title: "No Watch History Yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historySubmenu.addItem(emptyItem)
        } else {
            let subHeader = NSMenuItem(title: "Recent Watch History (Offline):", action: nil, keyEquivalent: "")
            subHeader.isEnabled = false
            historySubmenu.addItem(subHeader)

            for record in records {
                let cleanTitle = truncateText(record.title, maxLength: 42)
                let time = record.relativePlayedTimeString
                let item = NSMenuItem(title: "\(cleanTitle)  (\(time))", action: #selector(didSelectPlayVideoById(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = record.videoId
                item.toolTip = "\(record.title)\nChannel: \(record.channel)\nWatched: \(record.relativePlayedTimeString)"
                if let icon = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil) {
                    item.image = icon
                }
                historySubmenu.addItem(item)
            }

            historySubmenu.addItem(NSMenuItem.separator())

            let clearItem = NSMenuItem(title: "Clear Watch History…", action: #selector(didTapClearHistory), keyEquivalent: "")
            clearItem.target = self
            if let img = NSImage(systemSymbolName: "trash", accessibilityDescription: nil) {
                clearItem.image = img
            }
            historySubmenu.addItem(clearItem)
        }
        historyMenuItem.submenu = historySubmenu
        menu.addItem(historyMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 2. New & Import Playlist Actions
        let newPlaylistItem = NSMenuItem(title: "New Playlist…", action: #selector(didSelectCreatePlaylist), keyEquivalent: "")
        newPlaylistItem.target = self
        if let img = NSImage(systemSymbolName: "plus.rectangle.on.rectangle", accessibilityDescription: nil) {
            newPlaylistItem.image = img
        }
        menu.addItem(newPlaylistItem)

        let importPlItem = NSMenuItem(title: "Import Playlist (M3U8 / JSON)…", action: #selector(didSelectImportYouTubePlaylistFile), keyEquivalent: "")
        importPlItem.target = self
        if let img = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil) {
            importPlItem.image = img
        }
        menu.addItem(importPlItem)

        let searchPlItem = NSMenuItem(title: "Search Saved Videos…", action: #selector(didSelectSearchYouTubePlaylists), keyEquivalent: "")
        searchPlItem.target = self
        if let img = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) {
            searchPlItem.image = img
        }
        menu.addItem(searchPlItem)

        // 3. Add Current Video to Playlist (if a video is active)
        if !current.videoId.isEmpty {
            let addSubmenu = NSMenu(title: "Add to Playlist")
            let playlists = YouTubeDatabaseManager.shared.fetchPlaylists()
            for pl in playlists {
                let plItem = NSMenuItem(title: pl.name, action: #selector(didSelectAddCurrentToPlaylist(_:)), keyEquivalent: "")
                plItem.target = self
                plItem.representedObject = pl.id
                addSubmenu.addItem(plItem)
            }
            if playlists.isEmpty {
                let emptyItem = NSMenuItem(title: "No Playlists Yet", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                addSubmenu.addItem(emptyItem)
            }
            let addToItem = NSMenuItem(title: "Add Current Video to…", action: nil, keyEquivalent: "")
            addToItem.submenu = addSubmenu
            if let img = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: nil) {
                addToItem.image = img
            }
            menu.addItem(addToItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 5. User Playlists Section
        let headerItem = NSMenuItem(title: "Your Offline Playlists:", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let playlists = YouTubeDatabaseManager.shared.fetchPlaylists()
        if playlists.isEmpty {
            let emptyPl = NSMenuItem(title: "  (No playlists created)", action: nil, keyEquivalent: "")
            emptyPl.isEnabled = false
            menu.addItem(emptyPl)
        } else {
            for pl in playlists {
                let plItem = NSMenuItem(title: "\(pl.name) (\(pl.itemCount))", action: nil, keyEquivalent: "")
                if let img = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil) {
                    plItem.image = img
                }
                let plSubmenu = NSMenu(title: pl.name)

                let items = YouTubeDatabaseManager.shared.fetchPlaylistVideos(playlistId: pl.id)
                if !items.isEmpty {
                    let playAll = NSMenuItem(title: "Play All (Queue)", action: #selector(didSelectPlayAllInYouTubePlaylist(_:)), keyEquivalent: "")
                    playAll.target = self
                    playAll.representedObject = ["playlistId": pl.id, "shuffle": false]
                    if let playImg = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil) {
                        playAll.image = playImg
                    }
                    plSubmenu.addItem(playAll)

                    let shuffleAll = NSMenuItem(title: "Shuffle Play", action: #selector(didSelectPlayAllInYouTubePlaylist(_:)), keyEquivalent: "")
                    shuffleAll.target = self
                    shuffleAll.representedObject = ["playlistId": pl.id, "shuffle": true]
                    if let shufImg = NSImage(systemSymbolName: "shuffle", accessibilityDescription: nil) {
                        shuffleAll.image = shufImg
                    }
                    plSubmenu.addItem(shuffleAll)
                    plSubmenu.addItem(NSMenuItem.separator())

                    for (idx, item) in items.prefix(25).enumerated() {
                        let title = item.title.isEmpty ? item.videoId : item.title
                        let cleanTitle = truncateText(title, maxLength: 42)
                        let vi = NSMenuItem(title: cleanTitle, action: #selector(didSelectPlayVideoById(_:)), keyEquivalent: "")
                        vi.target = self
                        vi.representedObject = item.videoId
                        vi.toolTip = title

                        let itemSub = NSMenu(title: cleanTitle)
                        let playNow = NSMenuItem(title: "Play Now", action: #selector(didSelectPlayVideoById(_:)), keyEquivalent: "")
                        playNow.target = self
                        playNow.representedObject = item.videoId
                        itemSub.addItem(playNow)

                        if idx > 0 {
                            let moveUp = NSMenuItem(title: "Move Up", action: #selector(didSelectMoveYouTubePlaylistVideo(_:)), keyEquivalent: "")
                            moveUp.target = self
                            moveUp.representedObject = ["playlistId": pl.id, "videoId": item.videoId, "delta": -1]
                            itemSub.addItem(moveUp)
                        }
                        if idx < items.count - 1 {
                            let moveDown = NSMenuItem(title: "Move Down", action: #selector(didSelectMoveYouTubePlaylistVideo(_:)), keyEquivalent: "")
                            moveDown.target = self
                            moveDown.representedObject = ["playlistId": pl.id, "videoId": item.videoId, "delta": 1]
                            itemSub.addItem(moveDown)
                        }
                        itemSub.addItem(NSMenuItem.separator())
                        let removeVid = NSMenuItem(title: "Remove from Playlist", action: #selector(didSelectRemoveYouTubePlaylistVideo(_:)), keyEquivalent: "")
                        removeVid.target = self
                        removeVid.representedObject = ["playlistId": pl.id, "videoId": item.videoId]
                        itemSub.addItem(removeVid)

                        vi.submenu = itemSub
                        plSubmenu.addItem(vi)
                    }
                    plSubmenu.addItem(NSMenuItem.separator())
                } else {
                    let emptyVideos = NSMenuItem(title: "Empty Playlist", action: nil, keyEquivalent: "")
                    emptyVideos.isEnabled = false
                    plSubmenu.addItem(emptyVideos)
                    plSubmenu.addItem(NSMenuItem.separator())
                }

                let renamePl = NSMenuItem(title: "Rename \"\(pl.name)\"…", action: #selector(didSelectRenameYouTubePlaylist(_:)), keyEquivalent: "")
                renamePl.target = self
                renamePl.representedObject = pl
                plSubmenu.addItem(renamePl)

                let exportM3U = NSMenuItem(title: "Export as M3U8…", action: #selector(didSelectExportYouTubePlaylist(_:)), keyEquivalent: "")
                exportM3U.target = self
                exportM3U.representedObject = ["playlist": pl, "format": PlaylistFileCodec.Format.m3u8.rawValue]
                plSubmenu.addItem(exportM3U)

                let exportJSON = NSMenuItem(title: "Export as JSON…", action: #selector(didSelectExportYouTubePlaylist(_:)), keyEquivalent: "")
                exportJSON.target = self
                exportJSON.representedObject = ["playlist": pl, "format": PlaylistFileCodec.Format.json.rawValue]
                plSubmenu.addItem(exportJSON)

                let deletePl = NSMenuItem(title: "Delete \"\(pl.name)\"", action: #selector(didSelectDeletePlaylist(_:)), keyEquivalent: "")
                deletePl.target = self
                deletePl.representedObject = pl.id
                if let trashImg = NSImage(systemSymbolName: "trash", accessibilityDescription: nil) {
                    deletePl.image = trashImg
                }
                plSubmenu.addItem(deletePl)

                plItem.submenu = plSubmenu
                menu.addItem(plItem)
            }
        }

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    private func truncateText(_ text: String, maxLength: Int = 42) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength - 1)
        return String(trimmed[..<index]) + "…"
    }

    @objc private func didSelectCreatePlaylist() {
        let alert = NSAlert()
        alert.messageText = "New Offline Playlist"
        alert.informativeText = "Enter a name for your local playlist (never synced to Google):"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Playlist Name"
        alert.accessoryView = input

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            _ = YouTubeDatabaseManager.shared.createPlaylist(name: name)
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Playlist \"\(name)\" Created")
        }
    }

    @objc private func didSelectAddCurrentToPlaylist(_ sender: NSMenuItem) {
        guard let playlistId = sender.representedObject as? String else { return }
        let state = VideoPlayerCoordinator.shared.currentState
        guard !state.videoId.isEmpty else { return }

        let success = YouTubeDatabaseManager.shared.addVideoToPlaylist(
            playlistId: playlistId,
            videoId: state.videoId,
            title: state.title.isEmpty ? "YouTube Video" : state.title,
            channel: state.channel,
            duration: state.duration
        )
        if success {
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Added to \(sender.title)")
        } else {
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Already in \(sender.title)")
        }
    }

    @objc private func didSelectDeletePlaylist(_ sender: NSMenuItem) {
        guard let playlistId = sender.representedObject as? String else { return }
        YouTubeDatabaseManager.shared.deletePlaylist(id: playlistId)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Playlist Deleted")
    }

    @objc private func didSelectRenameYouTubePlaylist(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? LocalPlaylistRecord else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Playlist"
        alert.informativeText = "Enter a new name:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = playlist.name
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { return }
            YouTubeDatabaseManager.shared.renamePlaylist(id: playlist.id, name: newName)
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Renamed to \"\(newName)\"")
        }
    }

    @objc private func didSelectPlayAllInYouTubePlaylist(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let pid = info["playlistId"] as? String else { return }
        let shuffle = info["shuffle"] as? Bool ?? false
        var videos = YouTubeDatabaseManager.shared.fetchPlaylistVideos(playlistId: pid).map { $0.videoId }
        guard !videos.isEmpty else { return }
        if shuffle { videos.shuffle() }
        if videos.count == 1 {
            playVideoById(videos[0])
        } else if let url = URL(string: "https://www.youtube.com/watch_videos?video_ids=\(videos.prefix(50).joined(separator: ","))") {
            loadURL(url)
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: shuffle ? "Shuffling Playlist" : "Playing Playlist Queue")
        }
    }

    @objc private func didSelectMoveYouTubePlaylistVideo(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let pid = info["playlistId"] as? String,
              let vid = info["videoId"] as? String,
              let delta = info["delta"] as? Int else { return }
        var ids = YouTubeDatabaseManager.shared.fetchPlaylistVideos(playlistId: pid).map { $0.videoId }
        guard let idx = ids.firstIndex(of: vid) else { return }
        let target = idx + delta
        guard target >= 0 && target < ids.count else { return }
        ids.swapAt(idx, target)
        YouTubeDatabaseManager.shared.reorderPlaylistItems(playlistId: pid, orderedVideoIds: ids)
    }

    @objc private func didSelectRemoveYouTubePlaylistVideo(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let pid = info["playlistId"],
              let vid = info["videoId"] else { return }
        YouTubeDatabaseManager.shared.removeVideoFromPlaylist(playlistId: pid, videoId: vid)
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Removed from Playlist")
    }

    @objc private func didSelectSearchYouTubePlaylists() {
        let alert = NSAlert()
        alert.messageText = "Search Offline Playlists"
        alert.informativeText = "Enter a video or playlist title to play:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Find & Play")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Search keyword…"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let query = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return }

        for pl in YouTubeDatabaseManager.shared.fetchPlaylists() {
            let items = YouTubeDatabaseManager.shared.fetchPlaylistVideos(playlistId: pl.id)
            if let match = items.first(where: { $0.title.lowercased().contains(query) || $0.channel.lowercased().contains(query) }) {
                playVideoById(match.videoId)
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Playing \"\(match.title)\"")
                return
            }
        }
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: "No matching saved video found")
    }

    @objc private func didSelectImportYouTubePlaylistFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u8") ?? .plainText,
            UTType(filenameExtension: "m3u") ?? .plainText,
            .json
        ]
        panel.prompt = "Import"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { resp in
            guard resp == .OK, let fileURL = panel.url,
                  let data = try? Data(contentsOf: fileURL),
                  let decoded = try? PlaylistFileCodec.decode(data, from: fileURL) else { return }
            let ytTracks = decoded.document.tracks.filter { $0.ytVideoId != nil && !$0.ytVideoId!.isEmpty }
            guard !ytTracks.isEmpty else {
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "No YouTube tracks found in file")
                return
            }
            let pid = YouTubeDatabaseManager.shared.createPlaylist(name: decoded.document.name)
            for t in ytTracks {
                if let vid = t.ytVideoId {
                    YouTubeDatabaseManager.shared.addVideoToPlaylist(
                        playlistId: pid,
                        videoId: vid,
                        title: t.title.isEmpty ? vid : t.title,
                        channel: t.artist,
                        duration: 0
                    )
                }
            }
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Imported \"\(decoded.document.name)\" (\(ytTracks.count) videos)")
        }
    }

    @objc private func didSelectExportYouTubePlaylist(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let pl = info["playlist"] as? LocalPlaylistRecord,
              let rawFmt = info["format"] as? String,
              let fmt = PlaylistFileCodec.Format(rawValue: rawFmt) else { return }
        let items = YouTubeDatabaseManager.shared.fetchPlaylistVideos(playlistId: pl.id)
        let tracks = items.map {
            PlaylistFileCodec.Track(
                path: "https://www.youtube.com/watch?v=\($0.videoId)",
                title: $0.title,
                artist: $0.channel,
                ytVideoId: $0.videoId
            )
        }
        guard !tracks.isEmpty,
              let data = try? PlaylistFileCodec.encode(PlaylistFileCodec.Document(name: pl.name, tracks: tracks), as: fmt) else {
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Empty playlist")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: fmt.fileExtension) ?? .data]
        panel.nameFieldStringValue = "\(pl.name).\(fmt.fileExtension)"
        panel.prompt = "Export"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Exported \"\(pl.name)\"")
        }
    }

    @objc private func didSelectPlayVideoById(_ sender: NSMenuItem) {
        guard let videoId = sender.representedObject as? String, !videoId.isEmpty else { return }
        playVideoById(videoId)
    }

    public func playVideoById(_ videoId: String) {
        guard !videoId.isEmpty else { return }
        let js = """
        (function() {
            var vid = '\(videoId)';

            // If already on this video, seek to start and play cleanly
            if (window.location.href.includes(vid)) {
                var p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.seekTo === 'function') {
                    p.seekTo(0, true);
                    if (typeof p.playVideo === 'function') p.playVideo();
                    return true;
                }
            }

            // 1. Seamless YouTube Polymer navigation (SPA)
            var navigated = false;
            try {
                var ytdApp = document.querySelector('ytd-app');
                if (ytdApp && typeof ytdApp.fire === 'function') {
                    ytdApp.fire('yt-navigate', {
                        endpoint: {
                            commandMetadata: {
                                webCommandMetadata: {
                                    url: '/watch?v=' + vid,
                                    webPageType: 'WEB_PAGE_TYPE_WATCH',
                                    rootVe: 3832
                                }
                            },
                            watchEndpoint: {
                                videoId: vid
                            }
                        }
                    });
                    navigated = true;
                }
            } catch(e) {}

            // 2. Simulated link click on YouTube endpoint
            if (!navigated) {
                try {
                    var a = document.createElement('a');
                    a.href = '/watch?v=' + vid;
                    a.className = 'yt-simple-endpoint';
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    navigated = true;
                } catch(e) {}
            }

            // 3. Fallback: if URL didn't update after 300ms, detach media decoder and navigate
            setTimeout(function() {
                if (!window.location.href.includes(vid)) {
                    var v = document.querySelector('video');
                    if (v) {
                        try { v.pause(); v.removeAttribute('src'); v.load(); } catch(e) {}
                    }
                    window.location.href = 'https://www.youtube.com/watch?v=' + vid;
                }
            }, 300);
            return true;
        })();
        """
        ensureWebView().evaluateJavaScript(js) { [weak self] _, error in
            if error != nil {
                if let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                    self?.webView?.load(URLRequest(url: url))
                }
            }
        }
    }

    public func headerBarDidTapHistory(from sender: NSButton) {
        headerBarDidTapPlaylists(from: sender)
    }

    @objc private func didTapClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Watch History?"
        alert.informativeText = "This will remove all locally stored watch history records. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            YouTubeDatabaseManager.shared.clearHistory()
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Watch History Cleared")
        }
    }

    public func headerBarDidTapBestPart() {}

    public func headerBarDidTapQualityPicker(from sender: NSButton) {
        let menu = NSMenu(title: "Resolution")
        let qualities: [VideoQuality] = [
            .auto,
            .uhd2160,
            .qhd1440,
            .fhd1080,
            .hd720,
            .large,
            .medium
        ]

        let current = VideoPlayerCoordinator.shared.currentState.currentQuality

        for q in qualities {
            let item = NSMenuItem(title: q.displayName, action: #selector(didSelectQualityItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = q
            if q == current {
                item.state = .on
            }
            menu.addItem(item)
        }

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func didSelectQualityItem(_ sender: NSMenuItem) {
        guard let quality = sender.representedObject as? VideoQuality else { return }
        VideoPlayerCoordinator.shared.setQuality(quality)
        headerBarView.updatePlaybackState(VideoPlayerCoordinator.shared.currentState)
    }

    public func headerBarDidTapDownload() {
        presentDownloadSheet()
    }

    public func presentDownloadSheet() {
        let state = VideoPlayerCoordinator.shared.currentState
        guard !state.videoId.isEmpty else {
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "No active video to download")
            return
        }

        let title = state.title.isEmpty ? "YouTube Video (\(state.videoId))" : state.title

        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 410),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        sheetWindow.titlebarAppearsTransparent = true
        sheetWindow.titleVisibility = .hidden
        sheetWindow.isMovableByWindowBackground = true
        sheetWindow.backgroundColor = .clear
        sheetWindow.isOpaque = false
        sheetWindow.hasShadow = true

        let targetSheetWindow = sheetWindow
        let controller = YouTubeDownloadSheetController(videoId: state.videoId, videoTitle: title) { [weak self, weak targetSheetWindow] in
            if let sw = targetSheetWindow {
                self?.window?.endSheet(sw)
            }
        }

        sheetWindow.contentViewController = controller
        window?.beginSheet(sheetWindow) { _ in }
    }

    public func headerBarDidTapSpeedPicker(from sender: NSButton) {
        let menu = NSMenu(title: "Playback Speed")
        let speeds: [(Double, String)] = [
            (0.25, "0.25× (Quarter Speed)"),
            (0.50, "0.50× (Half Speed)"),
            (0.75, "0.75×"),
            (1.00, "1.00× (Normal)"),
            (1.25, "1.25×"),
            (1.50, "1.50×"),
            (1.75, "1.75×"),
            (2.00, "2.00× (Double Speed)"),
            (2.50, "2.50×"),
            (3.00, "3.00× (Triple Speed)")
        ]

        let currentSpeed = VideoPlayerCoordinator.shared.currentPlaybackSpeed

        for (rate, label) in speeds {
            let item = NSMenuItem(title: label, action: #selector(didSelectSpeedItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = rate
            if abs(rate - currentSpeed) < 0.01 {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let slowerItem = NSMenuItem(title: "Slower (-0.25×)", action: #selector(didSelectSlowerSpeed), keyEquivalent: "")
        slowerItem.target = self
        menu.addItem(slowerItem)

        let fasterItem = NSMenuItem(title: "Faster (+0.25×)", action: #selector(didSelectFasterSpeed), keyEquivalent: "")
        fasterItem.target = self
        menu.addItem(fasterItem)

        let resetItem = NSMenuItem(title: "Reset to Normal (1.0×)", action: #selector(didSelectResetSpeed), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func didSelectSpeedItem(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? Double else { return }
        VideoPlayerCoordinator.shared.setPlaybackSpeed(speed)
    }

    @objc private func didSelectSlowerSpeed() {
        VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: -0.25)
    }

    @objc private func didSelectFasterSpeed() {
        VideoPlayerCoordinator.shared.adjustPlaybackSpeed(by: 0.25)
    }

    @objc private func didSelectResetSpeed() {
        VideoPlayerCoordinator.shared.resetPlaybackSpeed()
    }

    public func updatePlaybackSpeed(_ speed: Double) {
        headerBarView.updatePlaybackSpeed(speed)
    }

    public func toggleDistractionFreeMode() {
        let current = AppSettings.shared.isDistractionFreeEnabled
        let newState = !current
        AppSettings.shared.isDistractionFreeEnabled = newState
        let js = "window.__mooziacSetDistractionFree && window.__mooziacSetDistractionFree(\(newState));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
        let msg = newState ? "Focus Mode: Enabled (Comments & Rail Hidden)" : "Focus Mode: Disabled"
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: msg)
    }

    public func checkAuthenticationStatus() {
        YouTubeWebView.isolatedDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let signedIn = cookies.contains { cookie in
                (cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com")) &&
                (cookie.name == "LOGIN_INFO" || cookie.name == "SAPISID" || cookie.name == "SSID" || cookie.name == "SID") &&
                !cookie.value.isEmpty
            }
            DispatchQueue.main.async {
                let previous = self.isUserSignedIn
                self.isUserSignedIn = signedIn
                let wasAdBlockEnabled = AppSettings.shared.isAdBlockEnabled
                if signedIn {
                    AppSettings.shared.applySignedInDefaultsIfNeeded()
                } else {
                    AppSettings.shared.restoreAdBlockDefaultOnSignOutIfNeeded()
                }
                let didAdBlockChange = (wasAdBlockEnabled != AppSettings.shared.isAdBlockEnabled)

                // Notify webview DOM about authentication state
                let js = "window.__mooziacUserSignedIn = \(signedIn); if (\(signedIn)) { document.documentElement.classList.add('mooziac-signed-in'); } else { document.documentElement.classList.remove('mooziac-signed-in'); }"
                self.webView?.evaluateJavaScript(js, completionHandler: nil)

                if previous != signedIn || didAdBlockChange {
                    if previous != signedIn {
                        LikedSongsManager.shared.refreshSignInStatus()
                    }
                    Log.app.info("Authentication state transitioned: signedIn = \(signedIn), adBlock = \(AppSettings.shared.isAdBlockEnabled). Reconfiguration triggered.")
                    // Clear memory & disk caches to eliminate any lingering ad rules or cached responses
                    YouTubeWebView.isolatedDataStore.removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: .distantPast) {}
                    if #available(macOS 15.4, *) {
                        Task { @MainActor in
                            await WebExtensionManager.shared.setAdBlockExtensionsEnabled(AppSettings.shared.isAdBlockEnabled)
                        }
                    }
                    self.reconfigureAndReload()
                }
            }
        }
    }

    public func headerBarDidTapShield(from sender: NSButton) {
        checkAuthenticationStatus()
        let menu = NSMenu(title: "Shield & Tools")

        let ident = AccountSessionManager.shared.displayIdentity.map { " (\($0))" } ?? ""
        let statusStr = isUserSignedIn ? "Signed In\(ident)" : "Signed Out"

        let activeSection = NSMenuItem(title: "Google Account (Shared)", action: nil, keyEquivalent: "")
        activeSection.isEnabled = false
        menu.addItem(activeSection)

        let accountHeader = NSMenuItem(title: statusStr, action: nil, keyEquivalent: "")
        accountHeader.isEnabled = false
        menu.addItem(accountHeader)

        if isUserSignedIn {
            let signOutItem = NSMenuItem(title: "Sign Out…", action: #selector(didSelectSignOut), keyEquivalent: "")
            signOutItem.target = self
            menu.addItem(signOutItem)
        } else {
            let signInItem = NSMenuItem(title: "Sign In with Google…", action: #selector(didSelectSignIn), keyEquivalent: "")
            signInItem.target = self
            menu.addItem(signInItem)
        }

        menu.addItem(NSMenuItem.separator())

        let adBlockItem = NSMenuItem(title: "Ad Blocker (Undetected)", action: #selector(didToggleShieldAdBlock), keyEquivalent: "")
        adBlockItem.target = self
        adBlockItem.state = AppSettings.shared.isAdBlockEnabled ? .on : .off
        adBlockItem.isEnabled = true
        menu.addItem(adBlockItem)

        let sponsorBlockItem = NSMenuItem(title: "SponsorBlock (Auto-Skip)", action: #selector(didToggleShieldSponsorBlock), keyEquivalent: "")
        sponsorBlockItem.target = self
        sponsorBlockItem.state = AppSettings.shared.isSponsorBlockEnabled ? .on : .off
        sponsorBlockItem.isEnabled = true
        menu.addItem(sponsorBlockItem)

        menu.addItem(NSMenuItem.separator())

        let focusItem = NSMenuItem(title: "Focus Mode (Hide Comments & Rail)", action: #selector(didToggleFocusMode), keyEquivalent: "F")
        focusItem.keyEquivalentModifierMask = [.command, .shift]
        focusItem.target = self
        focusItem.state = AppSettings.shared.isDistractionFreeEnabled ? .on : .off
        menu.addItem(focusItem)

        let ccItem = NSMenuItem(title: "Closed Captions (CC)", action: #selector(didToggleSubtitles), keyEquivalent: "")
        ccItem.target = self
        ccItem.state = VideoPlayerCoordinator.shared.currentState.isCaptionsActive ? .on : .off
        menu.addItem(ccItem)

        let pipSpacesItem = NSMenuItem(title: "Keep PiP Across All Spaces", action: #selector(didTogglePiPSpacesBehavior), keyEquivalent: "")
        pipSpacesItem.target = self
        pipSpacesItem.state = AppSettings.shared.isPiPKeepAcrossSpaces ? .on : .off
        menu.addItem(pipSpacesItem)

        menu.addItem(NSMenuItem.separator())

        let copyLinkItem = NSMenuItem(title: "Copy Video Link", action: #selector(didCopyVideoURL), keyEquivalent: "c")
        copyLinkItem.keyEquivalentModifierMask = [.command]
        copyLinkItem.target = self
        menu.addItem(copyLinkItem)

        let copyTimeLinkItem = NSMenuItem(title: "Copy Link at Current Timestamp", action: #selector(didCopyVideoURLWithTimestamp), keyEquivalent: "C")
        copyTimeLinkItem.keyEquivalentModifierMask = [.command, .shift]
        copyTimeLinkItem.target = self
        menu.addItem(copyTimeLinkItem)

        let downloadMenuItem = NSMenuItem(title: "Download Video / Audio…", action: #selector(didSelectDownloadMenu), keyEquivalent: "d")
        downloadMenuItem.keyEquivalentModifierMask = [.command]
        downloadMenuItem.target = self
        menu.addItem(downloadMenuItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func didSelectSignIn() {
        if let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F") {
            ensureWebView().load(URLRequest(url: url))
        }
    }

    @objc private func didSelectSignOut() {
        AccountSessionManager.shared.clearSharedSession { [weak self] in
            self?.lastVisitedURL = URL(string: "https://www.youtube.com")
            self?.teardownWebView()
            _ = self?.ensureWebView()
            self?.checkAuthenticationStatus()
            LikedSongsManager.shared.refreshSignInStatus()
            StatusItemManager.shared?.mainViewController.webViewContainer.loadMusicHome(autoPlayRandom: false)
            FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Signed Out")
        }
    }

    @objc private func didToggleFocusMode() {
        toggleDistractionFreeMode()
    }

    @objc private func didToggleSubtitles() {
        VideoPlayerCoordinator.shared.toggleSubtitles()
    }

    @objc private func didCopyVideoURL() {
        VideoPlayerCoordinator.shared.copyVideoURL(includeTimestamp: false)
    }

    @objc private func didCopyVideoURLWithTimestamp() {
        VideoPlayerCoordinator.shared.copyVideoURL(includeTimestamp: true)
    }

    @objc private func didSelectDownloadMenu() {
        presentDownloadSheet()
    }

    @objc private func didToggleShieldAdBlock() {
        let newState = !AppSettings.shared.isAdBlockEnabled
        AppSettings.shared.isAdBlockEnabled = newState
        let text = newState ? "Ad Blocker: Enabled" : "Ad Blocker: Disabled"
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: text)
        headerBarView.updatePlaybackState(VideoPlayerCoordinator.shared.currentState)
        if #available(macOS 15.4, *) {
            Task { @MainActor in
                await WebExtensionManager.shared.setAdBlockExtensionsEnabled(newState)
            }
        }
        reconfigureAndReload()
    }

    @objc private func didToggleShieldSponsorBlock() {
        let newState = !AppSettings.shared.isSponsorBlockEnabled
        AppSettings.shared.isSponsorBlockEnabled = newState
        let text = newState ? "SponsorBlock: Enabled" : "SponsorBlock: Disabled"
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: text)
        headerBarView.updatePlaybackState(VideoPlayerCoordinator.shared.currentState)
        reconfigureAndReload()
    }

    public func headerBarDidTapPiP() {
        togglePiP()
    }

    public func applyPiPSpacesBehavior() {
        let keepAcrossSpaces = AppSettings.shared.isPiPKeepAcrossSpaces
        DispatchQueue.main.async {
            for win in NSApp.windows {
                let className = String(describing: type(of: win))
                if className.contains("PIP") || className.contains("PictureInPicture") {
                    if keepAcrossSpaces {
                        win.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
                    } else {
                        win.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
                    }
                }
            }
        }
    }

    @objc private func didTogglePiPSpacesBehavior() {
        let current = AppSettings.shared.isPiPKeepAcrossSpaces
        let newState = !current
        AppSettings.shared.isPiPKeepAcrossSpaces = newState
        applyPiPSpacesBehavior()
        let text = newState ? "PiP: Keep Across Spaces (All Desktops)" : "PiP: This Desktop Only"
        FloatingHUDWindowController.shared.showCustomTextOverlay(text: text)
    }

    public func headerBarDidTapTheater() {
        VideoPlayerCoordinator.shared.toggleTheaterMode()
    }

    // MARK: - NSWindowDelegate Fullscreen Hooks
    public func windowWillEnterFullScreen(_ notification: Notification) {
        isTransitioningFullScreen = true
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
        updateFullscreenLayout(isFullscreen: true)
        headerBarView.updateFullscreenState(isFullscreen: true)
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
        webView?.needsLayout = true
        webView?.layoutSubtreeIfNeeded()
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        isTransitioningFullScreen = false
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
        updateFullscreenLayout(isFullscreen: true)
        startFullscreenMouseMonitoring()
        headerBarView.updateFullscreenState(isFullscreen: true)
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
        webView?.needsLayout = true
        webView?.layoutSubtreeIfNeeded()

        webView?.evaluateJavaScript("window.__mooziacSetFullscreenState && window.__mooziacSetFullscreenState(\(isPlayerFullscreen));", completionHandler: nil)

        // Close or minimize was requested while we were still entering full screen: leave again now
        if pendingCloseAfterFullScreenExit || pendingMinimizeAfterFullScreenExit {
            DispatchQueue.main.async { [weak self] in
                self?.window?.toggleFullScreen(nil)
            }
        }
    }

    public func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        // Without this the "transitioning" flag stays true forever and full screen stops working
        isTransitioningFullScreen = false
        isPlayerFullscreen = false
        wasWindowAlreadyInFullScreenBeforePlayer = false
        updateFullscreenLayout(isFullscreen: false)
        headerBarView.updateFullscreenState(isFullscreen: false)
        runPendingWindowActionAfterFullScreen()
    }

    public func windowDidFailToExitFullScreen(_ window: NSWindow) {
        isTransitioningFullScreen = false
        pendingCloseAfterFullScreenExit = false
        pendingMinimizeAfterFullScreenExit = false
        updateFullscreenLayout(isFullscreen: true)
        headerBarView.updateFullscreenState(isFullscreen: true)
    }

    private func runPendingWindowActionAfterFullScreen() {
        if pendingCloseAfterFullScreenExit {
            DispatchQueue.main.async { [weak self] in self?.finishClosingYouTube() }
        } else if pendingMinimizeAfterFullScreenExit {
            pendingMinimizeAfterFullScreenExit = false
            DispatchQueue.main.async { [weak self] in self?.performMinimize() }
        }
    }

    public func windowWillExitFullScreen(_ notification: Notification) {
        isTransitioningFullScreen = true
        stopFullscreenMouseMonitoring()
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
        updateFullscreenLayout(isFullscreen: false)
        headerBarView.updateFullscreenState(isFullscreen: false)
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
        webView?.needsLayout = true
        webView?.layoutSubtreeIfNeeded()
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        isTransitioningFullScreen = false
        isPlayerFullscreen = false
        wasWindowAlreadyInFullScreenBeforePlayer = false
        stopFullscreenMouseMonitoring()
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
        updateFullscreenLayout(isFullscreen: false)
        headerBarView.updateFullscreenState(isFullscreen: false)
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
        webView?.needsLayout = true
        webView?.layoutSubtreeIfNeeded()

        // Explicitly clear macOS presentation options so system menu bar & icons are never stuck hidden
        NSApp.presentationOptions = []

        webView?.evaluateJavaScript("window.__mooziacSetFullscreenState && window.__mooziacSetFullscreenState(false);", completionHandler: nil)

        runPendingWindowActionAfterFullScreen()
    }

    public func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.hideMenuBar, .hideDock, .fullScreen]
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        closeYouTubeAndReturnToMooziac()
        return false
    }

    public func windowWillClose(_ notification: Notification) {
        Self.isWindowVisible = false
        stopFullscreenMouseMonitoring()
        canGoBackObserver?.invalidate()
        canGoForwardObserver?.invalidate()
        KeyboardShortcutHandler.shared.stopMonitoring()
    }

    public func windowDidResize(_ notification: Notification) {
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        Self.isWindowVisible = true
        KeyboardShortcutHandler.shared.startMonitoring()
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
    }

    public func windowDidResignKey(_ notification: Notification) {
        KeyboardShortcutHandler.shared.stopMonitoring()
    }

    public func windowDidMiniaturize(_ notification: Notification) {
        Self.isWindowVisible = false
    }

    public func windowDidDeminiaturize(_ notification: Notification) {
        Self.isWindowVisible = true
        if let win = window {
            hideDefaultTrafficLights(window: win)
        }
    }

    public func hideDefaultTrafficLights(window: NSWindow) {
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            if let btn = window.standardWindowButton(type) {
                btn.isHidden = true
                btn.alphaValue = 0
                btn.isEnabled = false
            }
        }
    }

    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkAuthenticationStatus()
        let theme = AppSettings.shared.currentTheme
        applyTheme(theme, ambientColor: currentAmbientColor)
        if AppSettings.shared.isDistractionFreeEnabled {
            webView.evaluateJavaScript("window.__mooziacSetDistractionFree && window.__mooziacSetDistractionFree(true);", completionHandler: nil)
        }
        let speed = AppSettings.shared.defaultPlaybackSpeed
        if speed != 1.0 {
            webView.evaluateJavaScript("window.__mooziacPlayer && window.__mooziacPlayer.setPlaybackRate(\(speed));", completionHandler: nil)
        }
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard self.webView === webView else { return }
        Log.web.warning("WebKit WebContent process terminated; reloading to recover rendering...")
        webView.reload()
    }
}
