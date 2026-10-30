import AppKit
import QuartzCore

public protocol MooziacHeaderBarDelegate: AnyObject {
    func headerBarDidTapClose()
    func headerBarDidTapQuit()
    func headerBarDidTapMinimize()
    func headerBarDidTapBack()
    func headerBarDidTapForward()
    func headerBarDidTapReload()
    func headerBarDidTapCaptions()
    func headerBarDidTapLike()
    func headerBarDidTapPlaylists(from sender: NSButton)
    func headerBarDidTapHistory(from sender: NSButton)
    func headerBarDidTapDownload()
    func headerBarDidTapSpeedPicker(from sender: NSButton)
    func headerBarDidTapBestPart()
    func headerBarDidTapQualityPicker(from sender: NSButton)
    func headerBarDidTapShield(from sender: NSButton)
    func headerBarDidTapPiP()
    func headerBarDidTapTheater()
    func headerBarDidTapFullscreen()
}

public class MooziacHeaderBarView: NSVisualEffectView {
    public weak var delegate: MooziacHeaderBarDelegate?

    private let closeButton = ReactiveIconButton()
    private let minimizeButton = ReactiveIconButton()
    private let fullscreenButton = ReactiveIconButton()
    private let backButton = ReactiveIconButton()
    private let forwardButton = ReactiveIconButton()
    private let reloadButton = ReactiveIconButton()

    let captionButton = ReactiveIconButton()
    let qualityButton = ReactiveIconButton()
    let playlistsButton = ReactiveIconButton()
    let historyButton = ReactiveIconButton()
    let downloadButton = ReactiveIconButton()
    let speedButton = ReactiveIconButton()
    let shieldButton = ReactiveIconButton()
    let pipButton = ReactiveIconButton()
    let theaterButton = ReactiveIconButton()

    private let bottomBorderLayer = CALayer()
    private let themeOverlayLayer = CALayer()
    public private(set) var isLightAppearance: Bool = false

    public static let cyanAccent = NSColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.95)
    public static let goldAccent = NSColor(red: 1.0, green: 0.76, blue: 0.28, alpha: 0.95)

    public private(set) var bestPartTime: Double = 0
    public private(set) var bestPartFormattedTime: String = ""

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlassBacking()
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassBacking()
        setupUI()
    }

    private func setupGlassBacking() {
        wantsLayer = true
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        appearance = NSAppearance(named: .darkAqua)

        themeOverlayLayer.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.40).cgColor
        themeOverlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        themeOverlayLayer.frame = bounds
        layer?.addSublayer(themeOverlayLayer)

        // Precision 1px bottom border
        bottomBorderLayer.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        layer?.addSublayer(bottomBorderLayer)
    }

    public func applyTheme(_ theme: PlayerTheme = .liquidFluid, ambientColor: NSColor? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            appearance = NSAppearance(named: .darkAqua)
            material = .hudWindow
            blendingMode = .behindWindow
            themeOverlayLayer.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.40).cgColor
            bottomBorderLayer.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor

            let btnTint = NSColor.white
            closeButton.contentTintColor = NSColor(red: 1.0, green: 0.38, blue: 0.34, alpha: 0.95)
            minimizeButton.contentTintColor = NSColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
            fullscreenButton.contentTintColor = NSColor(red: 0.18, green: 0.82, blue: 0.35, alpha: 0.95)
            backButton.contentTintColor = btnTint
            forwardButton.contentTintColor = btnTint
            reloadButton.contentTintColor = btnTint
            captionButton.contentTintColor = btnTint
            qualityButton.contentTintColor = btnTint
            playlistsButton.contentTintColor = btnTint
            historyButton.contentTintColor = btnTint
            downloadButton.contentTintColor = btnTint
            speedButton.contentTintColor = btnTint
            shieldButton.contentTintColor = btnTint
            pipButton.contentTintColor = btnTint
            theaterButton.contentTintColor = btnTint
        }
    }

    public override func layout() {
        super.layout()
        bottomBorderLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1.0)
    }

    private func setupUI() {
        // 0. Setup Close Control
        setupNavButton(closeButton, systemName: "xmark", toolTip: "Close YouTube (Return to Mooziac)", action: #selector(closeTapped))
        closeButton.contentTintColor = NSColor(red: 1.0, green: 0.38, blue: 0.34, alpha: 0.95)

        // 1. Setup Minimize Control
        setupNavButton(minimizeButton, systemName: "minus", toolTip: "Minimize Window (⌘M)", action: #selector(minimizeTapped))
        minimizeButton.contentTintColor = NSColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)

        // 2. Setup Window Fullscreen Control (Green traffic light control)
        setupNavButton(fullscreenButton, systemName: "arrow.up.left.and.arrow.down.right", toolTip: "Toggle Full Screen (⌃⌘F)", action: #selector(fullscreenTapped))
        fullscreenButton.contentTintColor = NSColor(red: 0.18, green: 0.82, blue: 0.35, alpha: 0.95)

        // 3. Setup Left Navigation Buttons (Back, Forward, Reload)
        setupNavButton(backButton, systemName: "chevron.left", toolTip: "Back (⌘[)", action: #selector(backTapped))
        setupNavButton(forwardButton, systemName: "chevron.right", toolTip: "Forward (⌘])", action: #selector(forwardTapped))
        setupNavButton(reloadButton, systemName: "arrow.clockwise", toolTip: "Reload Page (⌘R)", action: #selector(reloadTapped))

        backButton.isEnabled = false
        forwardButton.isEnabled = false

        let leftStack = NSStackView(views: [closeButton, minimizeButton, fullscreenButton, backButton, forwardButton, reloadButton])
        leftStack.orientation = .horizontal
        leftStack.spacing = 6
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.setCustomSpacing(10, after: fullscreenButton)

        // 3. Setup Captions Button (Placed directly beside qualityButton)
        setupNavButton(captionButton, systemName: "captions.bubble", toolTip: "Live Captions / Lyrics in Title Bar (C)", action: #selector(captionTapped))
        captionButton.isEnabled = false

        // 4. Setup Quality Button (Uniform 26x26 icon button, no bulky pill)
        setupQualityButton(qualityButton, action: #selector(qualityTapped))

        // 5. Setup Playlists Icon Button (Uniform 26x26)
        setupNavButton(playlistsButton, systemName: "music.note.list", toolTip: "Playlists & Watch History", action: #selector(playlistsTapped))

        // 6. Setup Download Icon Button (Uniform 26x26)
        setupNavButton(downloadButton, systemName: "arrow.down.circle", toolTip: "Download Video / Audio (⌘D)", action: #selector(downloadTapped))
        downloadButton.contentTintColor = NSColor.white

        // 7. Setup Playback Speed Icon Button (Uniform 26x26 timer icon)
        setupNavButton(speedButton, systemName: "timer", toolTip: "Playback Speed (Shortcuts: [ / ])", action: #selector(speedTapped))

        // 8. Setup Shield Icon Button (Uniform 26x26 icon, not pill)
        setupNavButton(shieldButton, systemName: "shield.lefthalf.filled", toolTip: "Shield & Tools", action: #selector(shieldTapped))

        // 9. Setup Action Buttons (Uniform 26x26)
        setupNavButton(pipButton, systemName: "pip.enter", toolTip: "Picture-in-Picture", action: #selector(pipTapped))
        setupNavButton(theaterButton, systemName: "rectangle.inset.filled.and.person.filled", toolTip: "Theater Mode (T)", action: #selector(theaterTapped))

        let rightStack = NSStackView(views: [captionButton, qualityButton, playlistsButton, downloadButton, speedButton, shieldButton, pipButton, theaterButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 7
        rightStack.alignment = .centerY
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftStack)
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -16)
        ])
    }

    private func setupNavButton(_ button: ReactiveIconButton, systemName: String, toolTip: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .semibold)
        if let img = NSImage(systemSymbolName: systemName, accessibilityDescription: toolTip)?.withSymbolConfiguration(config) {
            button.image = img
        }
        button.target = self
        button.action = action
        button.toolTip = toolTip

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 26),
            button.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func setupQualityButton(_ button: ReactiveIconButton, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.title = "AUTO"
        button.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        button.target = self
        button.action = action
        button.toolTip = "Video Quality & 4K Switcher"
        button.contentTintColor = NSColor.white

        if let cell = button.cell as? NSButtonCell {
            cell.wraps = false
            cell.isScrollable = false
            cell.lineBreakMode = .byClipping
        }

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 26),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    // MARK: - Public State Updates
    public func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
    }

    public func updateLikeState(isLiked: Bool) {}
    public func updateBestPart(time: Double, formattedTime: String) {}
    public func resetBestPart() {}

    public func updatePlaybackState(_ state: VideoPlaybackState) {
        let is4K = state.is4KActive || state.currentQuality == .uhd2160
        let isUHD = is4K || state.currentQuality == .qhd1440

        if is4K {
            qualityButton.title = "4K"
            qualityButton.font = NSFont.systemFont(ofSize: 12.0, weight: .heavy)
            qualityButton.contentTintColor = Self.cyanAccent
            qualityButton.toolTip = "Video Quality: 4K UHD"
        } else if isUHD {
            qualityButton.title = "2K"
            qualityButton.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
            qualityButton.contentTintColor = Self.cyanAccent.withAlphaComponent(0.85)
            qualityButton.toolTip = "Video Quality: 2K QHD (1440p)"
        } else if state.currentQuality == .fhd1080 {
            qualityButton.title = "FHD"
            qualityButton.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
            qualityButton.contentTintColor = NSColor.white
            qualityButton.toolTip = "Video Quality: 1080p Full HD"
        } else {
            qualityButton.title = state.currentQuality.shortLabel
            qualityButton.font = NSFont.systemFont(ofSize: 11.0, weight: .bold)
            qualityButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
            qualityButton.toolTip = "Video Quality: \(state.currentQuality.displayName)"
        }

        // Update caption button state
        captionButton.isEnabled = state.isCaptionsAvailable
        if state.isCaptionsActive {
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .semibold)
            captionButton.image = NSImage(systemSymbolName: "captions.bubble.fill", accessibilityDescription: "Captions Active")?.withSymbolConfiguration(config)
            captionButton.contentTintColor = Self.cyanAccent
            captionButton.toolTip = "Captions Active (C)"
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .semibold)
            captionButton.image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "Captions Inactive")?.withSymbolConfiguration(config)
            captionButton.contentTintColor = state.isCaptionsAvailable ? NSColor.white.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.30)
            captionButton.toolTip = state.isCaptionsAvailable ? "Toggle Captions / Subtitles (C)" : "Captions Unavailable"
        }

        // Update shield status
        let adBlock = AppSettings.shared.isAdBlockEnabled
        let sponsorBlock = AppSettings.shared.isSponsorBlockEnabled
        if adBlock && sponsorBlock {
            shieldButton.contentTintColor = NSColor.white
            shieldButton.toolTip = "Shield & Tools (AdBlock Active)"
        } else if adBlock || sponsorBlock {
            shieldButton.contentTintColor = NSColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1.0)
            shieldButton.toolTip = "Shield & Tools (Partial)"
        } else {
            shieldButton.contentTintColor = NSColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 1.0)
            shieldButton.toolTip = "Shield & Tools (Off)"
        }
    }

    public func updatePlaybackSpeed(_ speed: Double) {
        let speedText = speed == 1.0 ? "1.0×" : String(format: "%.2f×", speed)
        speedButton.toolTip = "Playback Speed: \(speedText) (Shortcuts: [ / ])"
        speedButton.contentTintColor = speed != 1.0 ? NSColor.controlAccentColor : NSColor.white
    }

    public func updateFullscreenState(isFullscreen: Bool) {
        blendingMode = isFullscreen ? .withinWindow : .behindWindow
        themeOverlayLayer.backgroundColor = isFullscreen
            ? NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.88).cgColor
            : NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.40).cgColor

        let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .semibold)
        let iconName = isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Full Screen")?.withSymbolConfiguration(config) {
            fullscreenButton.image = img
        }
        fullscreenButton.toolTip = isFullscreen ? "Exit Full Screen (⌃⌘F)" : "Enter Full Screen (⌃⌘F)"
    }

    // MARK: - Actions
    @objc private func closeTapped() { delegate?.headerBarDidTapClose() }
    @objc private func minimizeTapped() { delegate?.headerBarDidTapMinimize() }
    @objc private func fullscreenTapped() { delegate?.headerBarDidTapFullscreen() }
    @objc private func backTapped() { delegate?.headerBarDidTapBack() }
    @objc private func forwardTapped() { delegate?.headerBarDidTapForward() }
    @objc private func reloadTapped() { delegate?.headerBarDidTapReload() }
    @objc private func captionTapped() { delegate?.headerBarDidTapCaptions() }
    @objc private func playlistsTapped() { delegate?.headerBarDidTapPlaylists(from: playlistsButton) }
    @objc private func historyTapped() { delegate?.headerBarDidTapHistory(from: historyButton) }
    @objc private func downloadTapped() { delegate?.headerBarDidTapDownload() }
    @objc private func speedTapped() { delegate?.headerBarDidTapSpeedPicker(from: speedButton) }
    @objc private func qualityTapped() { delegate?.headerBarDidTapQualityPicker(from: qualityButton) }
    @objc private func shieldTapped() { delegate?.headerBarDidTapShield(from: shieldButton) }
    @objc private func pipTapped() { delegate?.headerBarDidTapPiP() }
    @objc private func theaterTapped() { delegate?.headerBarDidTapTheater() }

    // MARK: - Hover Tracking for Fullscreen Reveal
    private var hoverTrackingArea: NSTrackingArea?
    public var onHoverStateChanged: ((Bool) -> Void)?

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverStateChanged?(true)
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverStateChanged?(false)
    }

    // MARK: - Native Window Dragging
    public override func mouseDown(with event: NSEvent) {
        // hitTest expects a point in the SUPERVIEW's coordinates, not the view's own
        let location = superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
        // Only perform window drag or zoom if not clicking interactive controls
        if hitTest(location) === self {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        } else {
            super.mouseDown(with: event)
        }
    }
}
