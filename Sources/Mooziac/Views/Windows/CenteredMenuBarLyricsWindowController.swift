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
            NowPlayingManager.shared.setLyricsActive(newValue)
            if newValue {
                if lastState.isPlaying && !lastState.title.isEmpty && lastState.title != "Not Playing" {
                    startLoop()
                    showOverlay()
                }
            } else {
                stopLoop()
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
        if isEnabled {
            NowPlayingManager.shared.setLyricsActive(true)
        } else {
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineModeChanged(_:)),
            name: NSNotification.Name("Mooziac_EngineModeChanged"),
            object: nil
        )
    }

    @objc private func handleDisplayChange() {
        repositionInCenter(contentWidth: window?.frame.width ?? 280)
    }

    @objc private func handleEngineModeChanged(_ notification: Notification) {
        let mode = notification.userInfo?["mode"] as? String ?? ""
        if mode == "online" {
            currentTrackKey = ""
            currentLRCLines = []
            LyricsManager.shared.clearSession()
            if !lastState.isPlaying {
                stopLoop()
                if !isShowingVolumeOverlay {
                    lyricsLabel.stringValue = ""
                    window?.orderOut(nil)
                }
            } else {
                startLoop()
            }
        }
    }

    private func handleStateUpdate(_ state: PlaybackState) {
        if state.isAd {
            return
        }
        self.lastState = state

        if isEnabled && state.isPlaying && !state.title.isEmpty && state.title != "Not Playing" {
            startLoop()
        } else {
            stopLoop()
            if window?.isVisible == true && !isShowingVolumeOverlay {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
        }

        guard isEnabled else { return }

        let cleanTitle = LyricsManager.cleanSongInfo(state.title).lowercased()
        let cleanArtist = LyricsManager.cleanSongInfo(state.artist).lowercased()
        let trackKey = state.trackID.isEmpty ? "\(cleanTitle)|\(cleanArtist)" : "VID:\(state.trackID)|\(cleanTitle)"

        if trackKey != currentTrackKey && !state.title.isEmpty && state.title != "Not Playing" {
            currentTrackKey = trackKey
            let requestKey = trackKey

            // Zero-latency instant cache check for songs with immediate lyrics at 0:00:
            if let instant = LyricsManager.shared.getCachedLRCLines(trackID: state.trackID, title: state.title, artist: state.artist, duration: state.duration), !instant.isEmpty {
                currentLRCLines = instant
            } else {
                currentLRCLines = []
                lyricsLabel.stringValue = ""
            }
            updateLyricsFrame()

            LyricsManager.shared.fetchLyrics(
                artist: state.artist,
                title: state.title,
                duration: state.duration,
                trackID: state.trackID,
                videoId: state.videoId.isEmpty ? nil : state.videoId
            ) { [weak self] _, lrcLines in
                // Silently discard completions that no longer belong to the displayed track
                guard let self = self, requestKey == self.currentTrackKey else { return }
                self.currentLRCLines = lrcLines
                self.updateLyricsFrame()
                NowPlayingManager.shared.prefetchNextQueueLyrics()
            }
        }
    }

    private func startLoop() {
        guard isEnabled, lastState.isPlaying else {
            stopLoop()
            return
        }
        updateLyricsFrame()
    }

    private func stopLoop() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func scheduleNextLyricsFrame() {
        displayTimer?.invalidate()
        displayTimer = nil

        guard isEnabled, lastState.isPlaying else { return }

        let accurateTime = lastState.getAccurateTime()
        let delay: TimeInterval = {
            guard !currentLRCLines.isEmpty else { return 1.0 }

            let lead = 0.15
            let effectiveTime = accurateTime + lead

            // If before first line:
            if effectiveTime < currentLRCLines[0].timestamp {
                let diff = currentLRCLines[0].timestamp - effectiveTime
                return max(0.04, min(diff, 1.0))
            }

            var foundIndex = -1
            for (i, line) in currentLRCLines.enumerated() {
                if effectiveTime >= line.timestamp {
                    foundIndex = i
                } else {
                    break
                }
            }

            guard foundIndex >= 0 && foundIndex < currentLRCLines.count else { return 1.0 }
            let line = currentLRCLines[foundIndex]

            // If there is a next line:
            if foundIndex + 1 < currentLRCLines.count {
                let nextTs = currentLRCLines[foundIndex + 1].timestamp
                let lineDuration: Double = {
                    if let lastWord = line.words.last {
                        return max(2.0, lastWord.endTime - line.timestamp)
                    }
                    return min(6.0, max(2.0, (nextTs - line.timestamp) * 0.75))
                }()
                let lineEndTime = line.timestamp + lineDuration
                let interludeTime = lineEndTime + 1.2

                // If instrumental gap is upcoming:
                if (nextTs - lineEndTime) > 3.0 && effectiveTime < interludeTime {
                    let diffToInterlude = interludeTime - effectiveTime
                    return max(0.04, min(diffToInterlude, 1.0))
                }

                // Diff to next line:
                let diffToNext = nextTs - effectiveTime
                return max(0.04, min(diffToNext, 1.0))
            }

            return 1.5
        }()

        displayTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.updateLyricsFrame()
        }
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func updateLyricsFrame() {
        guard isEnabled && !isShowingVolumeOverlay else {
            if !isShowingVolumeOverlay && window?.isVisible == true {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
            stopLoop()
            return
        }
        let state = lastState

        guard state.isPlaying && !state.title.isEmpty && state.title != "Not Playing" else {
            if window?.isVisible == true && !isShowingVolumeOverlay {
                lyricsLabel.stringValue = ""
                window?.orderOut(nil)
            }
            stopLoop()
            return
        }

        showOverlay()

        let accurateTime = state.getAccurateTime()
        var textToDisplay = ""

        if !currentLRCLines.isEmpty {
            if let activeInfo = SyncedLyricsParser.activeLineAndWord(at: accurateTime, in: currentLRCLines, leadOffset: 0.15) {
                let trimmed = activeInfo.line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "♪" || trimmed == "♪♪" || trimmed == "(Instrumental)" || trimmed == "[Instrumental]" {
                    let shortTitle = state.title.count > 30 ? String(state.title.prefix(30)) + "…" : state.title
                    let shortArtist = state.artist.count > 30 ? String(state.artist.prefix(30)) + "…" : state.artist
                    textToDisplay = "♪ \(shortTitle) • \(shortArtist)"
                } else {
                    textToDisplay = activeInfo.line.text
                }
            } else {
                // If playback is before the first line timestamp (initial intro) or in an instrumental break
                let shortTitle = state.title.count > 30 ? String(state.title.prefix(30)) + "…" : state.title
                let shortArtist = state.artist.count > 30 ? String(state.artist.prefix(30)) + "…" : state.artist
                textToDisplay = "\(shortTitle) • \(shortArtist)"
            }
        } else {
            let shortTitle = state.title.count > 30 ? String(state.title.prefix(30)) + "…" : state.title
            let shortArtist = state.artist.count > 30 ? String(state.artist.prefix(30)) + "…" : state.artist
            textToDisplay = "\(shortTitle) • \(shortArtist)"
        }

        if lyricsLabel.stringValue != textToDisplay {
            lyricsLabel.stringValue = textToDisplay

            let fontAttributes = [NSAttributedString.Key.font: lyricsLabel.font!]
            let textWidth = (textToDisplay as NSString).size(withAttributes: fontAttributes).width
            let targetWidth = min(max(ceil(textWidth / 30.0) * 30.0 + 30.0, 160), 260)

            repositionInCenter(contentWidth: targetWidth)
        }

        scheduleNextLyricsFrame()
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

        if isEnabled && lastState.isPlaying && !lastState.title.isEmpty && lastState.title != "Not Playing" {
            lyricsLabel.stringValue = ""
            updateLyricsFrame()
        } else if window?.isVisible == true {
            window?.orderOut(nil)
        }
    }

    public func repositionInCenter(contentWidth: CGFloat) {
        let targetScreen: NSScreen? = {
            if let buttonScreen = StatusItemManager.shared?.statusItem.button?.window?.screen {
                return buttonScreen
            }
            return NSScreen.screens.first ?? NSScreen.main
        }()
        guard let screen = targetScreen else { return }
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
            window?.setFrame(targetFrame, display: true)
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
