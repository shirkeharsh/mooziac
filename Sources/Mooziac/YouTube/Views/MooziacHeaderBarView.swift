import AppKit
import QuartzCore

public protocol MooziacHeaderBarDelegate: AnyObject {
    func headerBarDidTapClose()
    func headerBarDidTapQuit()
    func headerBarDidTapMinimize()
    func headerBarDidTapBack()
    func headerBarDidTapForward()
    func headerBarDidTapReload()
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
    private let backButton = ReactiveIconButton()
    private let forwardButton = ReactiveIconButton()
    private let reloadButton = ReactiveIconButton()

    public let qualityButton = NSButton()
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
            backButton.contentTintColor = btnTint
            forwardButton.contentTintColor = btnTint
            reloadButton.contentTintColor = btnTint
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

        // 2. Setup Left Navigation Buttons (Back, Forward, Reload)
        setupNavButton(backButton, systemName: "chevron.left", toolTip: "Back (⌘[)", action: #selector(backTapped))
        setupNavButton(forwardButton, systemName: "chevron.right", toolTip: "Forward (⌘])", action: #selector(forwardTapped))
        setupNavButton(reloadButton, systemName: "arrow.clockwise", toolTip: "Reload Page (⌘R)", action: #selector(reloadTapped))

        backButton.isEnabled = false
        forwardButton.isEnabled = false

        let leftStack = NSStackView(views: [closeButton, minimizeButton, backButton, forwardButton, reloadButton])
        leftStack.orientation = .horizontal
        leftStack.spacing = 6
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        // 3. Setup Quality Pill Button (Placed at start of rightStack)
        setupPillButton(qualityButton, title: "Auto", systemName: nil, action: #selector(qualityTapped))
        qualityButton.toolTip = "Video Quality & 4K Switcher"

        // 4. Setup Playlists Icon Button (Uniform 26x26)
        setupNavButton(playlistsButton, systemName: "music.note.list", toolTip: "Playlists & Watch History", action: #selector(playlistsTapped))

        // 5. Setup Download Icon Button (Uniform 26x26)
        setupNavButton(downloadButton, systemName: "arrow.down.circle", toolTip: "Download Video / Audio (⌘D)", action: #selector(downloadTapped))
        downloadButton.contentTintColor = NSColor.white

        // 6. Setup Playback Speed Icon Button (Uniform 26x26 timer icon)
        setupNavButton(speedButton, systemName: "timer", toolTip: "Playback Speed (Shortcuts: [ / ])", action: #selector(speedTapped))

        // 7. Setup Shield Icon Button (Uniform 26x26 icon, not pill)
        setupNavButton(shieldButton, systemName: "shield.lefthalf.filled", toolTip: "Shield & Tools", action: #selector(shieldTapped))

        // 8. Setup Action Buttons (Uniform 26x26)
        setupNavButton(pipButton, systemName: "pip.enter", toolTip: "Picture-in-Picture (P)", action: #selector(pipTapped))
        setupNavButton(theaterButton, systemName: "rectangle.inset.filled.and.person.filled", toolTip: "Theater Mode (T)", action: #selector(theaterTapped))

        let rightStack = NSStackView(views: [qualityButton, playlistsButton, downloadButton, speedButton, shieldButton, pipButton, theaterButton])
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

    private func setupPillButton(_ button: NSButton, title: String, systemName: String?, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.title = title
        button.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        button.target = self
        button.action = action

        if let sysName = systemName {
            let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
            button.image = NSImage(systemSymbolName: sysName, accessibilityDescription: title)?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
        }

        button.layer?.cornerRadius = 12.0
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        button.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        button.contentTintColor = NSColor.white

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 24),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 46)
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
            qualityButton.title = "4K UHD"
            qualityButton.layer?.borderColor = Self.cyanAccent.cgColor
            qualityButton.layer?.backgroundColor = NSColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.18).cgColor
            qualityButton.contentTintColor = Self.cyanAccent
        } else if isUHD {
            qualityButton.title = "1440p"
            qualityButton.layer?.borderColor = Self.cyanAccent.withAlphaComponent(0.6).cgColor
            qualityButton.layer?.backgroundColor = NSColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.12).cgColor
            qualityButton.contentTintColor = Self.cyanAccent
        } else if state.currentQuality == .fhd1080 {
            qualityButton.title = "1080p"
            qualityButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.35).cgColor
            qualityButton.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.10).cgColor
            qualityButton.contentTintColor = NSColor.white
        } else {
            qualityButton.title = state.currentQuality.shortLabel
            qualityButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
            qualityButton.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            qualityButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
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
        // Fullscreen button removed from header bar
    }

    // MARK: - Actions
    @objc private func closeTapped() { delegate?.headerBarDidTapClose() }
    @objc private func minimizeTapped() { delegate?.headerBarDidTapMinimize() }
    @objc private func backTapped() { delegate?.headerBarDidTapBack() }
    @objc private func forwardTapped() { delegate?.headerBarDidTapForward() }
    @objc private func reloadTapped() { delegate?.headerBarDidTapReload() }
    @objc private func playlistsTapped() { delegate?.headerBarDidTapPlaylists(from: playlistsButton) }
    @objc private func historyTapped() { delegate?.headerBarDidTapHistory(from: historyButton) }
    @objc private func downloadTapped() { delegate?.headerBarDidTapDownload() }
    @objc private func speedTapped() { delegate?.headerBarDidTapSpeedPicker(from: speedButton) }
    @objc private func qualityTapped() { delegate?.headerBarDidTapQualityPicker(from: qualityButton) }
    @objc private func shieldTapped() { delegate?.headerBarDidTapShield(from: shieldButton) }
    @objc private func pipTapped() { delegate?.headerBarDidTapPiP() }
    @objc private func theaterTapped() { delegate?.headerBarDidTapTheater() }

    // MARK: - Native Window Dragging
    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        // Only perform window drag if not clicking interactive controls
        if hitTest(location) === self {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}
