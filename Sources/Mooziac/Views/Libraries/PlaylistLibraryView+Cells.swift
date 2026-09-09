import AppKit

// MARK: - Playlist Table View Subclass
public class PlaylistTableView: NSTableView {
    public var onReturnKey: (() -> Void)?
    public var onDeleteKey: (() -> Void)?

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return / Enter
            onReturnKey?()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 { // Delete / Forward Delete
            onDeleteKey?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Playlist Row Cell View (Title on Left, Chevron on Right, Enclosed in Container)
class PlaylistRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let iconImageView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let countLabel = NSTextField(labelWithString: "")
    let editButton = ReactiveIconButton()
    let chevronImageView = NSImageView()

    var onRowClicked: (() -> Void)?
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)? {
        get { return swipeContainer.onDelete }
        set { swipeContainer.onDelete = newValue }
    }
    var onRightSwipePlay: (() -> Bool)? {
        get { return swipeContainer.onRightSwipePlay }
        set { swipeContainer.onRightSwipePlay = newValue }
    }

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.onRowClicked = { [weak self] in
            self?.onRowClicked?()
        }
        addSubview(swipeContainer)

        NSLayoutConstraint.activate([
            swipeContainer.topAnchor.constraint(equalTo: topAnchor),
            swipeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            swipeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            swipeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let card = swipeContainer.contentCardView
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.masksToBounds = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconImageView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Playlist")?.withSymbolConfiguration(iconConfig)
        card.addSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        countLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        countLabel.maximumNumberOfLines = 1
        countLabel.usesSingleLineMode = true
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.refusesFirstResponder = true

        card.addSubview(titleLabel)
        card.addSubview(countLabel)

        editButton.translatesAutoresizingMaskIntoConstraints = false
        let editConfig = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)
        editButton.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename Playlist")?.withSymbolConfiguration(editConfig)
        editButton.toolTip = "Rename Playlist"
        editButton.target = self
        editButton.action = #selector(handleEditButtonTapped)
        editButton.isBordered = false
        editButton.wantsLayer = true
        editButton.layer?.cornerRadius = 4
        card.addSubview(editButton)

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .semibold)
        chevronImageView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Open")?.withSymbolConfiguration(chevronConfig)
        chevronImageView.contentTintColor = NSColor(white: 0.55, alpha: 0.6)
        card.addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),

            countLabel.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -6),
            countLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            editButton.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -6),
            editButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 20),
            editButton.heightAnchor.constraint(equalToConstant: 20),

            chevronImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            chevronImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    @objc private func handleEditButtonTapped() {
        onRename?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard !swipeContainer.isSwipedOpen else { return }
        let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        if isLight {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.05).cgColor
        } else if isLiquidDark {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.24).cgColor
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard !swipeContainer.isSwipedOpen else { return }
        let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        if isLight {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
        } else if isLiquidDark {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
        }
    }

    func configure(playlist: PlaylistRecord, summary: (countText: String, durationText: String), design: PlayerDesign) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = playlist.name
        countLabel.stringValue = summary.countText

        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (design == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        let isDark = (design == .darkMode)
        let cyan = isLight ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

        if isLight {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            titleLabel.textColor = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
            countLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
            iconImageView.contentTintColor = cyan
            editButton.contentTintColor = NSColor(white: 0.20, alpha: 0.70)
            chevronImageView.contentTintColor = NSColor(white: 0.20, alpha: 0.40)
        } else if isLiquidDark {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            titleLabel.textColor = NSColor.white
            countLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            iconImageView.contentTintColor = NSColor.white
            editButton.contentTintColor = NSColor(white: 0.90, alpha: 0.90)
            chevronImageView.contentTintColor = NSColor(white: 0.90, alpha: 0.70)
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            titleLabel.textColor = NSColor.white
            countLabel.textColor = isDark ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.60, alpha: 1.0)
            iconImageView.contentTintColor = cyan
            editButton.contentTintColor = isDark ? NSColor(white: 0.65, alpha: 0.80) : NSColor(white: 0.75, alpha: 0.80)
            chevronImageView.contentTintColor = NSColor(white: 0.80, alpha: 0.40)
        }
    }
}

// MARK: - Playlist Item Row Cell View (Detail Mode Song Row)
class PlaylistItemRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let containerView = NSView()
    let artImageView = NSImageView()
    let nowPlayingWave = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let artistLabel = NSTextField(labelWithString: "")
    let statusIcon = NSImageView()
    let durationLabel = NSTextField(labelWithString: "")
    let optionsButton = ReactiveIconButton()

    var onRowClicked: (() -> Void)?
    var onOptionsTapped: ((NSButton) -> Void)?
    var onDelete: (() -> Void)? {
        get { return swipeContainer.onDelete }
        set { swipeContainer.onDelete = newValue }
    }

    private var currentArtworkKey: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Remove"
        swipeContainer.onRowClicked = { [weak self] in
            self?.onRowClicked?()
        }
        addSubview(swipeContainer)

        NSLayoutConstraint.activate([
            swipeContainer.topAnchor.constraint(equalTo: topAnchor),
            swipeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            swipeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            swipeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let card = swipeContainer.contentCardView
        card.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.borderWidth = 0.5
        card.addSubview(containerView)

        artImageView.translatesAutoresizingMaskIntoConstraints = false
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 5
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently
        artImageView.image = AppArtworkHelper.defaultArtwork

        nowPlayingWave.translatesAutoresizingMaskIntoConstraints = false
        let waveConfig = NSImage.SymbolConfiguration(pointSize: 9.0, weight: .bold)
        nowPlayingWave.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Now Playing")?.withSymbolConfiguration(waveConfig)
        nowPlayingWave.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        nowPlayingWave.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true

        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.imageScaling = .scaleProportionallyUpOrDown

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        durationLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        durationLabel.alignment = .right
        durationLabel.isEditable = false
        durationLabel.isSelectable = false
        durationLabel.refusesFirstResponder = true

        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)
        optionsButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Options")?.withSymbolConfiguration(config)
        optionsButton.toolTip = "Track Options"
        optionsButton.target = self
        optionsButton.action = #selector(handleOptions)
        optionsButton.isBordered = false
        optionsButton.wantsLayer = true
        optionsButton.layer?.cornerRadius = 4

        containerView.addSubview(artImageView)
        containerView.addSubview(nowPlayingWave)
        containerView.addSubview(textStack)
        containerView.addSubview(statusIcon)
        containerView.addSubview(durationLabel)
        containerView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),

            artImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            artImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 28),
            artImageView.heightAnchor.constraint(equalToConstant: 28),

            nowPlayingWave.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 6),
            nowPlayingWave.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nowPlayingWave.widthAnchor.constraint(equalToConstant: 12),

            textStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 8),
            textStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusIcon.leadingAnchor, constant: -6),

            statusIcon.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -6),
            statusIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 12),
            statusIcon.heightAnchor.constraint(equalToConstant: 12),

            durationLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -4),
            durationLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 40),

            optionsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            optionsButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(item: PlaylistItemRecord, resolution: PlaylistManager.PlaylistItemSource, design: PlayerDesign, index: Int) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = item.title
        artistLabel.stringValue = item.artist.isEmpty ? "Unknown Artist" : item.artist
        durationLabel.stringValue = item.duration.isEmpty ? "--:--" : item.duration

        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (design == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        let isDark = (design == .darkMode)

        // Check if currently playing
        let isCurrent: Bool
        if NowPlayingManager.shared.engineMode == .offline {
            if case .local(let track) = resolution {
                isCurrent = (NativeAudioPlayer.shared.currentTrack?.id == track.id)
            } else {
                isCurrent = false
            }
        } else {
            let currentVid = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
            let currentTitle = UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? ""
            if !currentVid.isEmpty {
                isCurrent = (item.ytVideoId == currentVid || item.refID == currentVid)
            } else if !currentTitle.isEmpty && currentTitle != "Not Playing" {
                isCurrent = (item.title.lowercased() == currentTitle.lowercased())
            } else {
                isCurrent = false
            }
        }

        if isCurrent {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isLight ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isLight ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isLight {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        } else if isLiquidDark {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            containerView.layer?.borderWidth = 1.0
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            artistLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
        } else {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            artistLabel.textColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            durationLabel.textColor = isDark ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.55, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.65, alpha: 1.0)
        }

        // Status Badge
        switch resolution {
        case .local:
            let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
            statusIcon.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Downloaded")?.withSymbolConfiguration(config)
            statusIcon.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 0.40, alpha: 1.0)
            statusIcon.toolTip = "Downloaded (Offline Playback Available)"
        case .online:
            let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .regular)
            statusIcon.image = NSImage(systemSymbolName: "icloud", accessibilityDescription: "Online Stream")?.withSymbolConfiguration(config)
            statusIcon.contentTintColor = NSColor(white: 0.60, alpha: 0.8)
            statusIcon.toolTip = "Online Stream (YouTube Music)"
        case .unavailable:
            let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .regular)
            statusIcon.image = NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: "Unavailable")?.withSymbolConfiguration(config)
            statusIcon.contentTintColor = NSColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1.0)
            statusIcon.toolTip = "File missing or unavailable"
        }

        // Artwork loading
        switch resolution {
        case .local(let track):
            if let cached = AppArtworkHelper.shared.getCachedThumbnail(for: track, targetSize: 56) {
                artImageView.image = cached
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
                AppArtworkHelper.shared.loadThumbnail(for: track, targetSize: 56) { [weak self] img in
                    self?.artImageView.image = img ?? AppArtworkHelper.defaultArtwork
                }
            }
        case .online:
            if !item.artworkUrl.isEmpty, let url = URL(string: item.artworkUrl) {
                if let cached = AppArtworkHelper.shared.getMemoryCachedImage(forKey: item.artworkUrl) {
                    artImageView.image = cached
                } else {
                    artImageView.image = AppArtworkHelper.defaultArtwork
                    currentArtworkKey = item.artworkUrl
                    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                        guard let self = self, let d = data, let img = NSImage(data: d) else { return }
                        AppArtworkHelper.shared.setMemoryCachedImage(img, forKey: item.artworkUrl)
                        DispatchQueue.main.async {
                            if self.currentArtworkKey == item.artworkUrl {
                                self.artImageView.image = img
                            }
                        }
                    }.resume()
                }
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
            }
        case .unavailable:
            artImageView.image = AppArtworkHelper.defaultArtwork
        }
    }

    @objc private func handleOptions() {
        onOptionsTapped?(optionsButton)
    }
}

// MARK: - Download Row Cell View (Downloads Tab Song Row)
class DownloadRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let containerView = NSView()
    let artImageView = NSImageView()
    let nowPlayingWave = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let artistLabel = NSTextField(labelWithString: "")
    let durationLabel = NSTextField(labelWithString: "")
    let optionsButton = ReactiveIconButton()

    var onRowClicked: (() -> Void)?
    var onOptionsTapped: ((NSButton) -> Void)?
    var onDelete: (() -> Void)? {
        get { return swipeContainer.onDelete }
        set { swipeContainer.onDelete = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.onRowClicked = { [weak self] in
            self?.onRowClicked?()
        }
        addSubview(swipeContainer)

        NSLayoutConstraint.activate([
            swipeContainer.topAnchor.constraint(equalTo: topAnchor),
            swipeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            swipeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            swipeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let card = swipeContainer.contentCardView
        card.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.borderWidth = 0.5
        card.addSubview(containerView)

        artImageView.translatesAutoresizingMaskIntoConstraints = false
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 5
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently
        artImageView.image = AppArtworkHelper.defaultArtwork

        nowPlayingWave.translatesAutoresizingMaskIntoConstraints = false
        let waveConfig = NSImage.SymbolConfiguration(pointSize: 9.0, weight: .bold)
        nowPlayingWave.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Now Playing")?.withSymbolConfiguration(waveConfig)
        nowPlayingWave.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        nowPlayingWave.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true

        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        durationLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        durationLabel.alignment = .right
        durationLabel.isEditable = false
        durationLabel.isSelectable = false
        durationLabel.refusesFirstResponder = true

        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)
        optionsButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Options")?.withSymbolConfiguration(config)
        optionsButton.toolTip = "Track Options"
        optionsButton.target = self
        optionsButton.action = #selector(handleOptions)
        optionsButton.isBordered = false
        optionsButton.wantsLayer = true
        optionsButton.layer?.cornerRadius = 4

        containerView.addSubview(artImageView)
        containerView.addSubview(nowPlayingWave)
        containerView.addSubview(textStack)
        containerView.addSubview(durationLabel)
        containerView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),

            artImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            artImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 28),
            artImageView.heightAnchor.constraint(equalToConstant: 28),

            nowPlayingWave.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 6),
            nowPlayingWave.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nowPlayingWave.widthAnchor.constraint(equalToConstant: 12),

            textStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 8),
            textStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: durationLabel.leadingAnchor, constant: -6),

            durationLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -4),
            durationLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 40),

            optionsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            optionsButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(track: LocalTrack, design: PlayerDesign) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = track.title
        artistLabel.stringValue = track.artist.isEmpty ? "Offline Audio" : track.artist
        let mins = Int(track.duration) / 60
        let secs = Int(track.duration) % 60
        durationLabel.stringValue = track.duration > 0 ? String(format: "%d:%02d", mins, secs) : "--:--"

        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (design == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        let isDark = (design == .darkMode)

        let isCurrent = (NowPlayingManager.shared.engineMode == .offline && NativeAudioPlayer.shared.currentTrack?.id == track.id)

        if isCurrent {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isLight ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isLight ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isLight {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        } else if isLiquidDark {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            containerView.layer?.borderWidth = 1.0
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            artistLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
        } else {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            artistLabel.textColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            durationLabel.textColor = isDark ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.55, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.65, alpha: 1.0)
        }

        if let cached = AppArtworkHelper.shared.getCachedThumbnail(for: track, targetSize: 56) {
            artImageView.image = cached
        } else {
            artImageView.image = AppArtworkHelper.defaultArtwork
            AppArtworkHelper.shared.loadThumbnail(for: track, targetSize: 56) { [weak self] img in
                self?.artImageView.image = img ?? AppArtworkHelper.defaultArtwork
            }
        }
    }

    @objc private func handleOptions() {
        onOptionsTapped?(optionsButton)
    }
}

// MARK: - History Row Cell View (Listening History Mode Song Row)
class HistoryRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let containerView = NSView()
    let artImageView = NSImageView()
    let nowPlayingWave = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let artistLabel = NSTextField(labelWithString: "")
    let timeLabel = NSTextField(labelWithString: "")
    let optionsButton = ReactiveIconButton()

    var onRowClicked: (() -> Void)?
    var onOptionsTapped: ((NSButton) -> Void)?
    var onDelete: (() -> Void)? {
        get { return swipeContainer.onDelete }
        set { swipeContainer.onDelete = newValue }
    }

    private var currentArtworkKey: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.onRowClicked = { [weak self] in
            self?.onRowClicked?()
        }
        addSubview(swipeContainer)

        NSLayoutConstraint.activate([
            swipeContainer.topAnchor.constraint(equalTo: topAnchor),
            swipeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            swipeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            swipeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let card = swipeContainer.contentCardView
        card.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.borderWidth = 0.5
        card.addSubview(containerView)

        artImageView.translatesAutoresizingMaskIntoConstraints = false
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 5
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently
        artImageView.image = AppArtworkHelper.defaultArtwork

        nowPlayingWave.translatesAutoresizingMaskIntoConstraints = false
        let waveConfig = NSImage.SymbolConfiguration(pointSize: 9.0, weight: .bold)
        nowPlayingWave.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Now Playing")?.withSymbolConfiguration(waveConfig)
        nowPlayingWave.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        nowPlayingWave.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true

        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        timeLabel.textColor = NSColor(white: 0.50, alpha: 1.0)
        timeLabel.alignment = .right
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.refusesFirstResponder = true

        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)
        optionsButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Options")?.withSymbolConfiguration(config)
        optionsButton.toolTip = "Track Options"
        optionsButton.target = self
        optionsButton.action = #selector(handleOptions)
        optionsButton.isBordered = false
        optionsButton.wantsLayer = true
        optionsButton.layer?.cornerRadius = 4

        containerView.addSubview(artImageView)
        containerView.addSubview(nowPlayingWave)
        containerView.addSubview(textStack)
        containerView.addSubview(timeLabel)
        containerView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),

            artImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            artImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 28),
            artImageView.heightAnchor.constraint(equalToConstant: 28),

            nowPlayingWave.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 6),
            nowPlayingWave.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nowPlayingWave.widthAnchor.constraint(equalToConstant: 12),

            textStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 8),
            textStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -6),

            timeLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -6),
            timeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            optionsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            optionsButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(item: HistoryRecord, design: PlayerDesign) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = item.title
        artistLabel.stringValue = item.artist.isEmpty ? (item.sourceType == "local" ? "Offline Audio" : "YouTube Music") : item.artist
        timeLabel.stringValue = item.relativePlayedTimeString

        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (design == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        let isDark = (design == .darkMode)

        // Check if currently playing
        let isCurrent: Bool
        if NowPlayingManager.shared.engineMode == .offline {
            if let path = item.filePath {
                isCurrent = (NativeAudioPlayer.shared.currentTrack?.fileURL.path == path)
            } else {
                isCurrent = false
            }
        } else {
            let currentVid = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
            let currentTitle = UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? ""
            if let vid = item.ytVideoId, !vid.isEmpty && !currentVid.isEmpty {
                isCurrent = (vid == currentVid)
            } else if !currentTitle.isEmpty && currentTitle != "Not Playing" {
                isCurrent = (item.title.lowercased() == currentTitle.lowercased())
            } else {
                isCurrent = false
            }
        }

        if isCurrent {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isLight ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isLight ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isLight {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            timeLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        } else if isLiquidDark {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            containerView.layer?.borderWidth = 1.0
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            artistLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            timeLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
        } else {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            artistLabel.textColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            timeLabel.textColor = isDark ? NSColor(white: 0.45, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.65, alpha: 1.0)
        }

        // Artwork loading
        if item.sourceType == "local", let path = item.filePath {
            let url = URL(fileURLWithPath: path)
            let dummy = LocalTrack(id: item.id, title: item.title, artist: item.artist, album: item.album, duration: item.duration, fileURL: url, isLiked: false)
            if let cached = AppArtworkHelper.shared.getCachedThumbnail(for: dummy, targetSize: 56) {
                artImageView.image = cached
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
                AppArtworkHelper.shared.loadThumbnail(for: dummy, targetSize: 56) { [weak self] img in
                    self?.artImageView.image = img ?? AppArtworkHelper.defaultArtwork
                }
            }
        } else if !item.artworkUrl.isEmpty, let url = URL(string: item.artworkUrl) {
            if let cached = AppArtworkHelper.shared.getMemoryCachedImage(forKey: item.artworkUrl) {
                artImageView.image = cached
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
                currentArtworkKey = item.artworkUrl
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let self = self, let d = data, let img = NSImage(data: d) else { return }
                    AppArtworkHelper.shared.setMemoryCachedImage(img, forKey: item.artworkUrl)
                    DispatchQueue.main.async {
                        if self.currentArtworkKey == item.artworkUrl {
                            self.artImageView.image = img
                        }
                    }
                }.resume()
            }
        } else {
            artImageView.image = AppArtworkHelper.defaultArtwork
        }
    }

    @objc private func handleOptions() {
        onOptionsTapped?(optionsButton)
    }
}

// MARK: - Liked Song Row Cell View (Liked Songs Mode Row)
class LikedSongRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let containerView = NSView()
    let artImageView = NSImageView()
    let nowPlayingWave = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let artistLabel = NSTextField(labelWithString: "")
    let heartIcon = NSImageView()
    let optionsButton = ReactiveIconButton()

    var onRowClicked: (() -> Void)?
    var onOptionsTapped: ((NSButton) -> Void)?
    var onDelete: (() -> Void)? {
        get { return swipeContainer.onDelete }
        set { swipeContainer.onDelete = newValue }
    }

    private var currentArtworkKey: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Remove"
        swipeContainer.onRowClicked = { [weak self] in
            self?.onRowClicked?()
        }
        addSubview(swipeContainer)

        NSLayoutConstraint.activate([
            swipeContainer.topAnchor.constraint(equalTo: topAnchor),
            swipeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            swipeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            swipeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let card = swipeContainer.contentCardView
        card.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.borderWidth = 1.0
        containerView.layer?.masksToBounds = true
        card.addSubview(containerView)

        artImageView.translatesAutoresizingMaskIntoConstraints = false
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 5
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently
        artImageView.image = AppArtworkHelper.defaultArtwork

        nowPlayingWave.translatesAutoresizingMaskIntoConstraints = false
        let waveConfig = NSImage.SymbolConfiguration(pointSize: 9.0, weight: .bold)
        nowPlayingWave.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Now Playing")?.withSymbolConfiguration(waveConfig)
        nowPlayingWave.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        nowPlayingWave.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.0, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true

        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        let heartConfig = NSImage.SymbolConfiguration(pointSize: 11.0, weight: .semibold)
        heartIcon.image = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Liked")?.withSymbolConfiguration(heartConfig)
        heartIcon.contentTintColor = NSColor(red: 1.0, green: 0.28, blue: 0.38, alpha: 1.0)

        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)
        optionsButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Options")?.withSymbolConfiguration(config)
        optionsButton.toolTip = "Track Options"
        optionsButton.target = self
        optionsButton.action = #selector(handleOptions)
        optionsButton.isBordered = false

        containerView.addSubview(artImageView)
        containerView.addSubview(nowPlayingWave)
        containerView.addSubview(textStack)
        containerView.addSubview(heartIcon)
        containerView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),

            artImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            artImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 28),
            artImageView.heightAnchor.constraint(equalToConstant: 28),

            nowPlayingWave.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 6),
            nowPlayingWave.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nowPlayingWave.widthAnchor.constraint(equalToConstant: 12),
            nowPlayingWave.heightAnchor.constraint(equalToConstant: 12),

            textStack.leadingAnchor.constraint(equalTo: nowPlayingWave.trailingAnchor, constant: 4),
            textStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: heartIcon.leadingAnchor, constant: -8),

            heartIcon.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -6),
            heartIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 14),
            heartIcon.heightAnchor.constraint(equalToConstant: 14),

            optionsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            optionsButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(record: LikedSongRecord, design: PlayerDesign) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = record.title
        artistLabel.stringValue = record.artist.isEmpty ? "YouTube Music" : record.artist

        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let isLiquidDark = (design == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        let isDark = (design == .darkMode)

        let currentVid = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
        let currentTitle = UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? ""
        let isCurrent: Bool
        if !record.videoId.isEmpty && !currentVid.isEmpty {
            isCurrent = (record.videoId == currentVid)
        } else if !currentTitle.isEmpty && currentTitle != "Not Playing" {
            isCurrent = (record.title.lowercased() == currentTitle.lowercased())
        } else {
            isCurrent = false
        }

        if isCurrent {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isLight ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isLight ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isLight {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        } else if isLiquidDark {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            containerView.layer?.borderWidth = 1.0
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            artistLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
        } else {
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            artistLabel.textColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.65, alpha: 1.0)
        }

        // Artwork loading
        if let localTrack = LocalLibraryManager.shared.allTracks.first(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        }) {
            if let cached = AppArtworkHelper.shared.getCachedThumbnail(for: localTrack, targetSize: 56) {
                artImageView.image = cached
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
                AppArtworkHelper.shared.loadThumbnail(for: localTrack, targetSize: 56) { [weak self] img in
                    self?.artImageView.image = img ?? AppArtworkHelper.defaultArtwork
                }
            }
        } else if !record.artworkUrl.isEmpty, let url = URL(string: record.artworkUrl) {
            if let cached = AppArtworkHelper.shared.getMemoryCachedImage(forKey: record.artworkUrl) {
                artImageView.image = cached
            } else {
                artImageView.image = AppArtworkHelper.defaultArtwork
                currentArtworkKey = record.artworkUrl
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let self = self, let d = data, let img = NSImage(data: d) else { return }
                    AppArtworkHelper.shared.setMemoryCachedImage(img, forKey: record.artworkUrl)
                    DispatchQueue.main.async {
                        if self.currentArtworkKey == record.artworkUrl {
                            self.artImageView.image = img
                        }
                    }
                }.resume()
            }
        } else {
            artImageView.image = AppArtworkHelper.defaultArtwork
        }
    }

    @objc private func handleOptions() {
        onOptionsTapped?(optionsButton)
    }
}
