import AppKit
import QuartzCore

public class CenteredMenuBarLyricsWindowController: NSWindowController {
    public static let shared = CenteredMenuBarLyricsWindowController()

    private let containerView = NSView()
    private let lyricsLabel = NSTextField(labelWithString: "")

    private var displayTimer: Timer?
    private var volumeOverlayTimer: Timer?
    private var isShowingVolumeOverlay: Bool = false

    private var currentLRCLines: [LRCLine] = []
    private var currentTrackKey: String = ""
    private var lastState: PlaybackState = PlaybackState()

    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_v3_isCenteredLyricsEnabled") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "YTM_v3_isCenteredLyricsEnabled")
            if newValue {
                if lastState.isPlaying && !lastState.title.isEmpty && lastState.title != "Not Playing" {
                    startLoop()
                    showOverlay()
                }
            } else {
                displayTimer?.invalidate()
                displayTimer = nil
                lyricsLabel.stringValue = ""
                if !isShowingVolumeOverlay {
                    window?.orderOut(nil)
                }
            }
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 22),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false

        super.init(window: window)
        setupUI()
        setupObservers()
        repositionInCenter(contentWidth: 280)
        if !isEnabled {
            window.orderOut(nil)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayTimer?.invalidate()
        volumeOverlayTimer?.invalidate()
    }

    private func setupUI() {
        guard let window = window else { return }
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        window.contentView = contentView

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        lyricsLabel.translatesAutoresizingMaskIntoConstraints = false
        lyricsLabel.wantsLayer = true
        lyricsLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        lyricsLabel.textColor = NSColor(white: 0.95, alpha: 0.95)
        lyricsLabel.alignment = .center
        lyricsLabel.maximumNumberOfLines = 1
        lyricsLabel.usesSingleLineMode = true
        lyricsLabel.lineBreakMode = .byTruncatingTail
        lyricsLabel.stringValue = ""

        containerView.addSubview(lyricsLabel)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            lyricsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lyricsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lyricsLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    private func setupObservers() {
        NowPlayingManager.shared.addObserver { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateUpdate(state)
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleDisplayChange() {
        repositionInCenter(contentWidth: window?.frame.width ?? 280)
    }

    private func handleStateUpdate(_ state: PlaybackState) {
        self.lastState = state

        if isEnabled && state.isPlaying && !state.title.isEmpty && state.title != "Not Playing" {
            if displayTimer == nil {
                startLoop()
            }
        } else {
            if displayTimer != nil {
                displayTimer?.invalidate()
                displayTimer = nil
            }
            if window?.isVisible == true && !isShowingVolumeOverlay {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
        }

        guard isEnabled else { return }

        let trackKey = state.trackID.isEmpty ? "\(state.title.lowercased())|\(state.artist.lowercased())" : "VID:" + state.trackID
        if trackKey != currentTrackKey && !state.title.isEmpty && state.title != "Not Playing" {
            currentTrackKey = trackKey
            currentLRCLines = []
            let requestKey = trackKey

            LyricsManager.shared.fetchLyrics(artist: state.artist, title: state.title, duration: state.duration, trackID: state.trackID) { [weak self] _, lrcLines in
                // Silently discard completions that no longer belong to the displayed track
                guard let self = self, requestKey == self.currentTrackKey else { return }
                self.currentLRCLines = lrcLines
            }
        }
    }

    private func startLoop() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateLyricsFrame()
        }
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    private func updateLyricsFrame() {
        guard isEnabled && !isShowingVolumeOverlay else {
            if !isShowingVolumeOverlay && window?.isVisible == true {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
            return
        }
        let state = lastState

        guard state.isPlaying && !state.title.isEmpty && state.title != "Not Playing" else {
            if window?.isVisible == true && !isShowingVolumeOverlay {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
            return
        }

        showOverlay()

        let accurateTime = state.getAccurateTime()
        var textToDisplay = ""

        if !currentLRCLines.isEmpty,
           let activeInfo = SyncedLyricsParser.activeLineAndWord(at: accurateTime, in: currentLRCLines, leadOffset: 0.35) {
            textToDisplay = activeInfo.line.text
        } else {
            let shortTitle = state.title.count > 30 ? String(state.title.prefix(30)) + "…" : state.title
            let shortArtist = state.artist.count > 30 ? String(state.artist.prefix(30)) + "…" : state.artist
            textToDisplay = "\(shortTitle) • \(shortArtist)"
        }

        if lyricsLabel.stringValue != textToDisplay {
            let transition = CATransition()
            transition.duration = 0.06
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .fade
            lyricsLabel.layer?.add(transition, forKey: "subtleFadeLyrics")

            lyricsLabel.stringValue = textToDisplay

            let fontAttributes = [NSAttributedString.Key.font: lyricsLabel.font!]
            let textWidth = (textToDisplay as NSString).size(withAttributes: fontAttributes).width
            let targetWidth = min(max(ceil(textWidth / 30.0) * 30.0 + 30.0, 160), 260)

            repositionInCenter(contentWidth: targetWidth)
        }
    }

    public func showVolumeOverlay(volumePercent: Int, isAppOnly: Bool = false) {
        let prefix = isAppOnly ? "App Sound: " : "Volume: "
        let textToDisplay = volumePercent == 0 ? (isAppOnly ? "App Muted" : "Muted") : "\(prefix)\(volumePercent)%"
        showCustomTextOverlay(text: textToDisplay)
    }

    public func showCustomTextOverlay(text: String, duration: TimeInterval = 1.5) {
        volumeOverlayTimer?.invalidate()
        isShowingVolumeOverlay = true
        showOverlay()

        lyricsLabel.stringValue = text

        let fontAttributes = [NSAttributedString.Key.font: lyricsLabel.font!]
        let textWidth = (text as NSString).size(withAttributes: fontAttributes).width
        let targetWidth = min(max(ceil(textWidth / 30.0) * 30.0 + 30.0, 180), 300)

        repositionInCenter(contentWidth: targetWidth)

        volumeOverlayTimer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.completeOverlayDismissal()
        }
        RunLoop.main.add(volumeOverlayTimer!, forMode: .common)
    }

    private func completeOverlayDismissal() {
        volumeOverlayTimer?.invalidate()
        volumeOverlayTimer = nil
        isShowingVolumeOverlay = false

        if !(isEnabled && lastState.isPlaying) && window?.isVisible == true {
            window?.orderOut(nil)
        }
    }

    public func repositionInCenter(contentWidth: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let visibleRect = screen.visibleFrame
        let menuBarHeight = max(24, screenRect.maxY - visibleRect.maxY)

        let textContainerWidth = contentWidth
        let textContainerHeight: CGFloat = 22

        let hasNotch: Bool = {
            if #available(macOS 12.0, *) {
                return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
            }
            return false
        }()

        let x = screenRect.midX - (textContainerWidth / 2.0)
        let y: CGFloat

        if hasNotch {
            // Float right under the hardware notch cutout as a sleek Dynamic Island capsule HUD
            y = screenRect.maxY - menuBarHeight - textContainerHeight - 3
            containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
            containerView.layer?.cornerRadius = 11.0
            containerView.layer?.masksToBounds = true
        } else {
            // Standard center alignment directly within the menu bar
            y = screenRect.maxY - menuBarHeight + ((menuBarHeight - textContainerHeight) / 2.0)
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.cornerRadius = 0.0
            containerView.layer?.masksToBounds = false
        }

        let targetFrame = NSRect(x: x, y: y, width: textContainerWidth, height: textContainerHeight)

        if window?.frame != targetFrame {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window?.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    public func showOverlay() {
        if window?.isVisible == false {
            window?.orderFront(nil)
        }
    }

    public func toggleOverlay() {
        isEnabled.toggle()
    }
}
