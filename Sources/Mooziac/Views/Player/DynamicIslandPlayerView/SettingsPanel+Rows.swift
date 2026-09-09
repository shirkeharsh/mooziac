import AppKit

// MARK: - Flipped Coordinate Helpers for Scroll Views
class SettingsFlippedDocView: NSView {
    override var isFlipped: Bool { true }
}

class SettingsFlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

// MARK: - Color & Playing State Helpers
func settingsAccentColor(tone: SettingsTone) -> NSColor {
    if PlayerDesign.current == .glassMode {
        return NSColor.lightThemeSelector
    }
    if tone == .dark || PlayerDesign.current == .darkMode {
        return NSColor.darkThemeSelector
    }
    return NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
}

func rowPlayIconColor(tone: SettingsTone) -> NSColor {
    return settingsAccentColor(tone: tone)
}

func isTrackPlaying(title: String, artist: String, videoId: String?, refID: String?) -> Bool {
    let state = NowPlayingManager.shared.currentState
    if NowPlayingManager.shared.engineMode == .offline {
        if let current = NativeAudioPlayer.shared.currentTrack {
            if let refID = refID, !refID.isEmpty && (current.fileURL.path == refID || current.id == refID) {
                return true
            }
            if let vid = videoId, !vid.isEmpty, let cvid = current.ytVideoId, !cvid.isEmpty, vid == cvid {
                return true
            }
            let cleanT = LyricsManager.cleanSongInfo(title).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanCurrentT = current.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanT.isEmpty && (cleanT == cleanCurrentT || title.lowercased() == current.title.lowercased()) {
                return true
            }
        }
        return false
    } else {
        if let vid = videoId, !vid.isEmpty, !state.videoId.isEmpty, vid == state.videoId {
            return true
        }
        let cleanT = LyricsManager.cleanSongInfo(title).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanStateT = LyricsManager.cleanSongInfo(state.title).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanT.isEmpty && cleanT == cleanStateT {
            return true
        }
        return false
    }
}

class VerticalPanGestureRecognizer: NSPanGestureRecognizer {
    private var startLocation: NSPoint = .zero
    private var directionLocked = false
    private var isHorizontalDrag = false

    override func mouseDown(with event: NSEvent) {
        startLocation = event.locationInWindow
        directionLocked = false
        isHorizontalDrag = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = event.locationInWindow.x - startLocation.x
        let dy = event.locationInWindow.y - startLocation.y

        if !directionLocked {
            if abs(dx) >= 3.0 && abs(dx) > abs(dy) * 0.7 {
                directionLocked = true
                isHorizontalDrag = true
                state = .failed
                return
            } else if abs(dy) >= 6.0 && abs(dy) > abs(dx) * 0.7 {
                directionLocked = true
                isHorizontalDrag = false
            } else {
                return
            }
        }

        if isHorizontalDrag {
            return
        }
        super.mouseDragged(with: event)
    }
}

// MARK: - Download Item Row View
class DownloadRowView: NSView {
    let track: LocalTrack
    weak var delegate: DynamicIslandPlayerView?
    private var currentTone: SettingsTone

    let playBtn = ReactiveIconButton()
    let titleLbl = NSTextField(labelWithString: "")
    let artistLbl = NSTextField(labelWithString: "")
    let checkmarkImg = NSImageView()

    init(track: LocalTrack, tone: SettingsTone, delegate: DynamicIslandPlayerView) {
        self.track = track
        self.delegate = delegate
        self.currentTone = tone
        super.init(frame: .zero)
        setupUI(tone: tone)
        updatePlayingAppearance(tone: tone)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    func updatePlayingAppearance(tone: SettingsTone) {
        self.currentTone = tone
        let isPlayingThisTrack = isTrackPlaying(title: track.title, artist: track.artist, videoId: track.ytVideoId, refID: track.fileURL.path)
        let isPlaybackActive = NowPlayingManager.shared.currentState.isPlaying
        let accent = settingsAccentColor(tone: tone)
        let isGlass = (PlayerDesign.current == .glassMode)

        if isPlayingThisTrack {
            layer?.borderColor = accent.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1.2
            layer?.backgroundColor = accent.withAlphaComponent(isGlass ? 0.12 : 0.14).cgColor
            titleLbl.textColor = accent
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)

            let symbol = isPlaybackActive ? "speaker.wave.2.fill" : "pause.fill"
            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Playing")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = accent
            playBtn.toolTip = isPlaybackActive ? "Pause" : "Resume"
        } else {
            let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
            layer?.borderColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.20).cgColor : tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.16).cgColor : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play Offline"
        }
    }

    private func setupUI(tone: SettingsTone) {
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.20).cgColor : tone.dividerColor.cgColor
        layer?.backgroundColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.16).cgColor : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Play Button
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.isBordered = false
        playBtn.representedObject = track
        let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playBtn.contentTintColor = rowPlayIconColor(tone: tone)
        playBtn.toolTip = "Play Offline"
        playBtn.target = delegate
        playBtn.action = #selector(DynamicIslandPlayerView.handlePlayDownloadedTrack(_:))
        playBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(playBtn)

        // Title & Artist
        titleLbl.stringValue = track.title
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        artistLbl.stringValue = track.artist.isEmpty ? "Offline Audio" : track.artist
        artistLbl.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        artistLbl.textColor = tone.secondaryText
        artistLbl.maximumNumberOfLines = 1
        artistLbl.usesSingleLineMode = true
        artistLbl.lineBreakMode = .byTruncatingTail
        artistLbl.isEditable = false
        artistLbl.isSelectable = false
        artistLbl.refusesFirstResponder = true

        let textCol = NSStackView(views: [titleLbl, artistLbl])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 0
        textCol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textCol)

        // Downloaded Checkmark Badge
        checkmarkImg.translatesAutoresizingMaskIntoConstraints = false
        let checkConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        checkmarkImg.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Downloaded")?.withSymbolConfiguration(checkConfig)
        checkmarkImg.contentTintColor = NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
        checkmarkImg.toolTip = "Downloaded (Available Offline)"
        checkmarkImg.widthAnchor.constraint(equalToConstant: 20).isActive = true
        checkmarkImg.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(checkmarkImg)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            playBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            playBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            textCol.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 8),
            textCol.centerYAnchor.constraint(equalTo: centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImg.leadingAnchor, constant: -6),

            checkmarkImg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkmarkImg.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if let delegate, !delegate.isLibrarySearchActive {
            let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handleReorderPan(_:)))
            addGestureRecognizer(pan)
        }
    }

    @objc private func handleReorderPan(_ gesture: NSPanGestureRecognizer) {
        guard let delegate = delegate else { return }
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "download-", storageKey: delegate.downloadsOrderKey, playlistID: "downloads")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let delegate = delegate else { return nil }
        return delegate.contextMenu(for: track)
    }
}

// MARK: - Draggable Detail Item Row View

class LibraryNavButton: NSControl {
    let libraryTab: DynamicIslandPlayerView.LibraryTab
    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }
    private var isHovered: Bool = false {
        didSet { updateAppearance() }
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stackView = NSStackView()
    private var trackingArea: NSTrackingArea?

    private var cachedTone: SettingsTone?
    private var cachedIsGlass: Bool = false
    private var cachedCyan: NSColor = NSColor.darkThemeSelector

    init(tab: DynamicIslandPlayerView.LibraryTab) {
        self.libraryTab = tab
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: libraryTab.symbol, accessibilityDescription: libraryTab.title)?.withSymbolConfiguration(config)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.widthAnchor.constraint(equalToConstant: 17).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 17).isActive = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = libraryTab.title
        titleLabel.font = NSFont.systemFont(ofSize: 9.0, weight: .medium)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byClipping
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 3
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addView(iconView, in: .top)
        stackView.addView(titleLabel, in: .bottom)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    func refresh(tone: SettingsTone, isGlass: Bool, cyan: NSColor) {
        self.cachedTone = tone
        self.cachedIsGlass = isGlass
        self.cachedCyan = cyan
        updateAppearance()
    }

    private func updateAppearance() {
        let isGlass = cachedIsGlass
        let cyan = cachedCyan
        let tone = cachedTone ?? .dark
        let baseBg = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.055))

        if isSelected {
            iconView.contentTintColor = cyan
            titleLabel.textColor = cyan
            titleLabel.font = NSFont.systemFont(ofSize: 9.0, weight: .semibold)
            layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.12 : 0.16).cgColor
            layer?.borderWidth = 1.0
            layer?.borderColor = cyan.withAlphaComponent(0.45).cgColor
        } else if isHovered {
            iconView.contentTintColor = tone.primaryText
            titleLabel.textColor = tone.primaryText
            titleLabel.font = NSFont.systemFont(ofSize: 9.0, weight: .medium)
            layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.06 : 0.09).cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = cyan.withAlphaComponent(0.25).cgColor
        } else {
            iconView.contentTintColor = tone.iconColor
            titleLabel.textColor = tone.secondaryText
            titleLabel.font = NSFont.systemFont(ofSize: 9.0, weight: .medium)
            layer?.backgroundColor = baseBg.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = NSColor.clear.cgColor
        }
    }
}

class DetailItemRowView: NSView {
    let item: PlaylistItemRecord
    weak var delegate: DynamicIslandPlayerView?
    private var currentTone: SettingsTone

    let playBtn = ReactiveIconButton()
    let titleLbl = NSTextField(labelWithString: "")
    let metaLbl = NSTextField(labelWithString: "")
    let downloadBtn = CircularProgressDownloadButton()

    init(item: PlaylistItemRecord, tone: SettingsTone, delegate: DynamicIslandPlayerView) {
        self.item = item
        self.delegate = delegate
        self.currentTone = tone
        super.init(frame: .zero)
        setupUI(tone: tone)
        updatePlayingAppearance(tone: tone)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    func applyDownloadProgress(statusStr: String, progress: Double, eta: String) {
        if statusStr.contains("completed") {
            downloadBtn.downloadState = .completed
            metaLbl.stringValue = item.artist.isEmpty ? "Unknown Artist" : item.artist
            downloadBtn.animatePop()
        } else if statusStr.contains("downloading") {
            downloadBtn.downloadState = .downloading(progress: progress, eta: eta)
            let pctInt = Int(progress * 100)
            let etaStr = eta.isEmpty ? "" : " • ETA \(eta)"
            metaLbl.stringValue = "Downloading \(pctInt)%\(etaStr)"
        } else if statusStr.contains("queued") {
            downloadBtn.downloadState = .queued
            metaLbl.stringValue = "Queued in download list..."
        } else if statusStr.contains("failed") {
            downloadBtn.downloadState = .idleDownload
            metaLbl.stringValue = item.artist.isEmpty ? "Unknown Artist" : item.artist
        }
    }

    func updatePlayingAppearance(tone: SettingsTone) {
        self.currentTone = tone
        let isPlayingThisTrack = isTrackPlaying(title: item.title, artist: item.artist, videoId: item.ytVideoId, refID: item.refID)
        let isPlaybackActive = NowPlayingManager.shared.currentState.isPlaying
        let accent = settingsAccentColor(tone: tone)
        let isGlass = (PlayerDesign.current == .glassMode)

        if isPlayingThisTrack {
            layer?.borderColor = accent.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1.2
            layer?.backgroundColor = accent.withAlphaComponent(isGlass ? 0.12 : 0.14).cgColor
            titleLbl.textColor = accent
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)

            let symbol = isPlaybackActive ? "speaker.wave.2.fill" : "pause.fill"
            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Playing")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = accent
            playBtn.toolTip = isPlaybackActive ? "Pause" : "Resume"
        } else {
            let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
            layer?.borderColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.20) : tone.dividerColor).cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.16) : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06))).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.20) : tone.dividerColor).cgColor
        layer?.backgroundColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.16) : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06))).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Play Button
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.isBordered = false
        playBtn.representedObject = item
        let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playBtn.contentTintColor = rowPlayIconColor(tone: tone)
        playBtn.toolTip = "Play"
        playBtn.target = delegate
        playBtn.action = #selector(DynamicIslandPlayerView.handlePlayItemFromDetail(_:))
        playBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(playBtn)

        // Title & Artist
        titleLbl.stringValue = item.title
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        metaLbl.stringValue = item.artist.isEmpty ? "Unknown Artist" : item.artist
        metaLbl.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        metaLbl.textColor = tone.secondaryText
        metaLbl.maximumNumberOfLines = 1
        metaLbl.usesSingleLineMode = true
        metaLbl.lineBreakMode = .byTruncatingTail
        metaLbl.isEditable = false
        metaLbl.isSelectable = false
        metaLbl.refusesFirstResponder = true

        let textCol = NSStackView(views: [titleLbl, metaLbl])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 0
        textCol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textCol)

        // Download Button with Circular Progress Ring
        downloadBtn.translatesAutoresizingMaskIntoConstraints = false
        downloadBtn.isBordered = false
        downloadBtn.representedObject = item

        let resolution = PlaylistManager.shared.resolve(item)
        switch resolution {
        case .local:
            downloadBtn.downloadState = .completed
            downloadBtn.target = delegate
            downloadBtn.action = #selector(DynamicIslandPlayerView.handleDownloadButtonTapped(_:))
        case .online:
            let vid = item.ytVideoId ?? item.refID
            if let activeInfo = DownloadManager.shared.statusFor(id: item.id, videoId: vid) {
                switch activeInfo.status {
                case .queued:
                    downloadBtn.downloadState = .queued
                    metaLbl.stringValue = "Queued in download list..."
                case .downloading(let progress, let eta, _):
                    downloadBtn.downloadState = .downloading(progress: progress, eta: eta)
                    let pctInt = Int(progress * 100)
                    let etaStr = eta.isEmpty ? "" : " • ETA \(eta)"
                    metaLbl.stringValue = "Downloading \(pctInt)%\(etaStr)"
                case .completed:
                    downloadBtn.downloadState = .completed
                case .failed:
                    downloadBtn.downloadState = .idleDownload
                }
            } else {
                downloadBtn.downloadState = .idleDownload
            }
            downloadBtn.target = delegate
            downloadBtn.action = #selector(DynamicIslandPlayerView.handleDownloadButtonTapped(_:))
        case .unavailable:
            downloadBtn.downloadState = .unavailable
        }
        downloadBtn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        downloadBtn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        addSubview(downloadBtn)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            playBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            playBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            textCol.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 8),
            textCol.centerYAnchor.constraint(equalTo: centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: downloadBtn.leadingAnchor, constant: -6),

            downloadBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            downloadBtn.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if let delegate, !delegate.isLibrarySearchActive {
            let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            addGestureRecognizer(pan)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let delegate = delegate else { return nil }
        return delegate.contextMenu(for: item)
    }

    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        delegate?.handleLibraryRowReorderPan(gesture, keyPrefix: nil, storageKey: nil, playlistID: delegate?.playlistDetailMode?.id)
    }
}

// MARK: - History Item Row View
class HistoryRowView: NSView {
    let record: HistoryRecord
    weak var delegate: DynamicIslandPlayerView?
    private var currentTone: SettingsTone

    let playBtn = ReactiveIconButton()
    let titleLbl = NSTextField(labelWithString: "")
    let metaLbl = NSTextField(labelWithString: "")
    let downloadBtn = CircularProgressDownloadButton()

    init(record: HistoryRecord, tone: SettingsTone, delegate: DynamicIslandPlayerView) {
        self.record = record
        self.delegate = delegate
        self.currentTone = tone
        super.init(frame: .zero)
        setupUI(tone: tone)
        updatePlayingAppearance(tone: tone)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    func applyDownloadProgress(statusStr: String, progress: Double, eta: String) {
        if statusStr.contains("completed") {
            downloadBtn.downloadState = .completed
            downloadBtn.animatePop()
        } else if statusStr.contains("downloading") {
            downloadBtn.downloadState = .downloading(progress: progress, eta: eta)
        } else if statusStr.contains("queued") {
            downloadBtn.downloadState = .queued
        } else if statusStr.contains("failed") {
            downloadBtn.downloadState = .idleDownload
        }
    }

    func updatePlayingAppearance(tone: SettingsTone) {
        self.currentTone = tone
        let isPlayingThisTrack = isTrackPlaying(title: record.title, artist: record.artist, videoId: record.ytVideoId, refID: record.sourceType == "local" ? record.id : nil)
        let isPlaybackActive = NowPlayingManager.shared.currentState.isPlaying
        let accent = settingsAccentColor(tone: tone)
        let isGlass = (PlayerDesign.current == .glassMode)

        if isPlayingThisTrack {
            layer?.borderColor = accent.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1.2
            layer?.backgroundColor = accent.withAlphaComponent(isGlass ? 0.12 : 0.14).cgColor
            titleLbl.textColor = accent
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)

            let symbol = isPlaybackActive ? "speaker.wave.2.fill" : "pause.fill"
            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Playing")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = accent
            playBtn.toolTip = isPlaybackActive ? "Pause" : "Resume"
        } else {
            let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
            layer?.borderColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.20).cgColor : tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.16).cgColor : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.20).cgColor : tone.dividerColor.cgColor
        layer?.backgroundColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.16).cgColor : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Play Button
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.isBordered = false
        playBtn.representedObject = record
        let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playBtn.contentTintColor = rowPlayIconColor(tone: tone)
        playBtn.toolTip = "Play"
        playBtn.target = delegate
        playBtn.action = #selector(DynamicIslandPlayerView.handlePlayHistoryRecord(_:))
        playBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(playBtn)

        // Title & Meta
        titleLbl.stringValue = record.title
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let artistText = record.artist.isEmpty ? (record.sourceType == "local" ? "Offline Audio" : "YouTube Music") : record.artist
        let relativeTime = record.relativePlayedTimeString
        metaLbl.stringValue = "\(artistText) • \(relativeTime)"
        metaLbl.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        metaLbl.textColor = tone.secondaryText
        metaLbl.maximumNumberOfLines = 1
        metaLbl.usesSingleLineMode = true
        metaLbl.lineBreakMode = .byTruncatingTail
        metaLbl.isEditable = false
        metaLbl.isSelectable = false
        metaLbl.refusesFirstResponder = true

        let textCol = NSStackView(views: [titleLbl, metaLbl])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 0
        textCol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textCol)

        // Download Button
        downloadBtn.translatesAutoresizingMaskIntoConstraints = false
        downloadBtn.isBordered = false
        downloadBtn.representedObject = record

        if record.sourceType == "local" {
            downloadBtn.downloadState = .completed
            downloadBtn.toolTip = "Downloaded (Available Offline)"
        } else {
            let vid = record.ytVideoId
            let cleanT = LyricsManager.cleanSongInfo(record.title)
            let cleanA = LyricsManager.cleanSongInfo(record.artist)
            let isAlreadySaved = LocalLibraryManager.shared.allTracks.contains { t in
                if let v = vid, let tv = t.ytVideoId, !tv.isEmpty, tv == v { return true }
                let matchT = t.title.lowercased() == cleanT.lowercased() || t.cleanTitle.lowercased() == cleanT.lowercased()
                let matchA = cleanA.isEmpty || t.artist.lowercased() == cleanA.lowercased() || t.cleanArtist.lowercased() == cleanA.lowercased()
                return matchT && (cleanA.isEmpty || matchA)
            }

            if isAlreadySaved {
                downloadBtn.downloadState = .completed
            } else if let active = DownloadManager.shared.statusFor(id: record.id, videoId: vid) {
                switch active.status {
                case .queued:
                    downloadBtn.downloadState = .queued
                case .downloading(let progress, let eta, _):
                    downloadBtn.downloadState = .downloading(progress: progress, eta: eta)
                case .completed:
                    downloadBtn.downloadState = .completed
                case .failed:
                    downloadBtn.downloadState = .idleDownload
                }
            } else {
                downloadBtn.downloadState = .idleDownload
            }
        }

        downloadBtn.target = delegate
        downloadBtn.action = #selector(DynamicIslandPlayerView.handleDownloadHistoryButtonTapped(_:))
        downloadBtn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        downloadBtn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        addSubview(downloadBtn)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            playBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            playBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            textCol.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 8),
            textCol.centerYAnchor.constraint(equalTo: centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: downloadBtn.leadingAnchor, constant: -6),

            downloadBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            downloadBtn.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if let delegate, !delegate.isLibrarySearchActive {
            let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handleReorderPan(_:)))
            addGestureRecognizer(pan)
        }
    }

    @objc private func handleReorderPan(_ gesture: NSPanGestureRecognizer) {
        guard let delegate = delegate else { return }
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "history-", storageKey: delegate.historyOrderKey, playlistID: nil)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let delegate = delegate else { return nil }
        return delegate.contextMenu(for: record)
    }
}

class LikedSongRowView: NSView {
    let record: LikedSongRecord
    weak var delegate: DynamicIslandPlayerView?
    private var currentTone: SettingsTone

    let playBtn = ReactiveIconButton()
    let titleLbl = NSTextField(labelWithString: "")
    let metaLbl = NSTextField(labelWithString: "")

    init(record: LikedSongRecord, tone: SettingsTone, delegate: DynamicIslandPlayerView) {
        self.record = record
        self.delegate = delegate
        self.currentTone = tone
        super.init(frame: .zero)
        setupUI(tone: tone)
        updatePlayingAppearance(tone: tone)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    func updatePlayingAppearance(tone: SettingsTone) {
        self.currentTone = tone
        let isPlayingThisTrack = isTrackPlaying(title: record.title, artist: record.artist, videoId: record.videoId, refID: record.videoId)
        let isPlaybackActive = NowPlayingManager.shared.currentState.isPlaying
        let accent = settingsAccentColor(tone: tone)
        let isGlass = (PlayerDesign.current == .glassMode)

        if isPlayingThisTrack {
            layer?.borderColor = accent.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1.2
            layer?.backgroundColor = accent.withAlphaComponent(isGlass ? 0.12 : 0.14).cgColor
            titleLbl.textColor = accent
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)

            let symbol = isPlaybackActive ? "speaker.wave.2.fill" : "pause.fill"
            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Playing")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = accent
            playBtn.toolTip = isPlaybackActive ? "Pause" : "Resume"
        } else {
            let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
            layer?.borderColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.20) : tone.dividerColor).cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.16) : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06))).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.20) : tone.dividerColor).cgColor
        layer?.backgroundColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.16) : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06))).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.isBordered = false
        playBtn.representedObject = record
        let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playBtn.contentTintColor = rowPlayIconColor(tone: tone)
        playBtn.toolTip = "Play"
        playBtn.target = delegate
        playBtn.action = #selector(DynamicIslandPlayerView.handlePlayLikedSong(_:))
        playBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(playBtn)

        titleLbl.stringValue = record.title
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let artistText = record.artist.isEmpty ? "YouTube Music" : record.artist
        metaLbl.stringValue = "\(artistText) • ♥ Saved"
        metaLbl.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        metaLbl.textColor = tone.secondaryText
        metaLbl.maximumNumberOfLines = 1
        metaLbl.usesSingleLineMode = true
        metaLbl.lineBreakMode = .byTruncatingTail
        metaLbl.isEditable = false
        metaLbl.isSelectable = false
        metaLbl.refusesFirstResponder = true

        let textCol = NSStackView(views: [titleLbl, metaLbl])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 0
        textCol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textCol)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            playBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            playBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            textCol.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 8),
            textCol.centerYAnchor.constraint(equalTo: centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        ])

        if let delegate, !delegate.isLibrarySearchActive {
            let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handleReorderPan(_:)))
            addGestureRecognizer(pan)
        }
    }

    @objc private func handleReorderPan(_ gesture: NSPanGestureRecognizer) {
        guard let delegate = delegate else { return }
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "liked-", storageKey: delegate.likedSongsOrderKey, playlistID: "liked_songs")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let delegate = delegate else { return nil }
        return delegate.contextMenu(for: record)
    }
}


