import AppKit
import QuartzCore
import ImageIO

protocol DynamicIslandPlayerViewDelegate: AnyObject {
    func dynamicIslandDidSearch(query: String)
    func dynamicIslandDidTapPlayPause()
    func dynamicIslandDidTapNext()
    func dynamicIslandDidTapPrevious()
    func dynamicIslandDidTapShuffle()
    func dynamicIslandDidTapRepeat()
    func dynamicIslandDidSeek(to seconds: Double)
    func dynamicIslandDidTapWebBrowser()
    func dynamicIslandDidTapResetPosition()
    func dynamicIslandDidTapOfflineLibrary()
    func dynamicIslandDidTapPlaylistLibrary(playlistID: String?)
    func dynamicIslandDidToggleExpanded(expanded: Bool)
}

class DynamicIslandPlayerView: NSView, NSSearchFieldDelegate, NSControlTextEditingDelegate {
    weak var delegate: DynamicIslandPlayerViewDelegate?
    
    let containerPill = PillContainerView()
    
    let artworkImageView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "Not Playing")
    let artistLabel = NSTextField(labelWithString: "YouTube Music")
    
    let addToPlaylistButton = ReactiveIconButton()
    let previousButton = ReactiveIconButton()
    let playPauseButton = ReactiveIconButton()
    let nextButton = ReactiveIconButton()
    let repeatButton = ReactiveIconButton()
    let likeButton = ReactiveIconButton()
    let searchIconButton = ReactiveIconButton()
    let downloadButton = CircularProgressDownloadButton()
    let browserButton = ReactiveIconButton()
    let fullScreenButton = ReactiveIconButton()
    let resetPositionButton = ReactiveIconButton()
    let visualEffectBackdrop = NSVisualEffectView()
    let glassSheenLayer = CAGradientLayer()
    let cylindricalLensLayer = CAGradientLayer()
    let liquidFluidMeshLayer = CAGradientLayer()
    var isLiked: Bool = false
    var isRepeatActive: Bool = false
    var repeatMode: RepeatMode = .off

    public enum ActiveSettingsMode {
        case preferences
        case playlist
    }
    public var activeSettingsMode: ActiveSettingsMode = .preferences

    public enum LibraryTab: Int, CaseIterable {
        case playlists = 0
        case likedSongs = 1
        case downloads = 2
        case history = 3

        public var title: String {
            switch self {
            case .playlists: return "Playlists"
            case .likedSongs: return "Liked Songs"
            case .downloads: return "Downloads"
            case .history: return "History"
            }
        }

        public var symbol: String {
            switch self {
            case .playlists: return "music.note"
            case .likedSongs: return "heart"
            case .downloads: return "arrow.down.circle"
            case .history: return "clock"
            }
        }
    }
    public var activeLibraryTab: LibraryTab = .playlists

    var containerPillBottomCollapsedConstraint: NSLayoutConstraint?
    var containerPillBottomSettingsConstraint: NSLayoutConstraint?
    var settingsContainerHeightConstraint: NSLayoutConstraint?

    var isSettingsExpanded: Bool = false
    let settingsContainerView = NSView()
    let settingsHeaderLabel = NSTextField(labelWithString: "SETTINGS & OPTIONS")

    let themeSlider = LiquidGlassSegmentedSlider()

    let themeSectionLabel = NSTextField(labelWithString: "PLAYER THEME")
    let playlistSectionLabel = NSTextField(labelWithString: "ADD CURRENT TRACK TO PLAYLIST")
    let libraryNavContainer = NSView()
    let libraryNavStack = NSStackView()
    var libraryNavButtons: [LibraryNavButton] = []
    let librarySectionHeaderLabel = NSTextField(labelWithString: "YOUR PLAYLISTS")
    var playlistCreateFooterButton: NSButton?
    var isPlaylistCreateOpen: Bool = false
    var playlistSearchWidthAnchor: NSLayoutConstraint?
    var playlistCreateWidthAnchor: NSLayoutConstraint?
    let downloadsPlayAllButton = ReactiveIconButton()
    let downloadsShuffleButton = ReactiveIconButton()
    let likedPlayAllButton = ReactiveIconButton()
    let likedShuffleButton = ReactiveIconButton()
    let historyPlayAllButton = ReactiveIconButton()
    let historyShuffleButton = ReactiveIconButton()
    let playlistsStackView = NSStackView()
    let detailStackView = NSStackView()
    let playlistDetailBackButton = ReactiveIconButton()
    let playlistDetailPlayAllButton = ReactiveIconButton()
    let playlistDetailShuffleButton = ReactiveIconButton()
    let playlistDetailDownloadAllButton = ReactiveIconButton()
    let playlistDetailCreateButton = ReactiveIconButton()
    let playlistDetailRenameButton = ReactiveIconButton()
    let playlistDetailDeleteButton = ReactiveIconButton()
    let playlistDetailAddButton = ReactiveIconButton()
    let playlistSearchToggleButton = ReactiveIconButton()
    let playlistBulkDeleteButton = ReactiveIconButton()
    let playlistSelectionDoneButton = ReactiveIconButton()
    var isPlaylistSelectionMode: Bool = false
    var selectedPlaylistIDs: Set<String> = []
    var isPlaylistSearchActive: Bool = false
    var searchFieldStateToken: Int = 0
    var createFieldStateToken: Int = 0
    var playlistBuildToken = 0
    var pendingRowBuilders: [() -> NSView] = []
    var playlistBuildStack: NSStackView?
    var playlistBuildChunkIndex = 0
    var playlistsStackTopConstraint: NSLayoutConstraint?
    var detailStackTopConstraint: NSLayoutConstraint?
    var playlistActiveStackTopConstraint: NSLayoutConstraint?
    var playlistWindowHeightConstraint: NSLayoutConstraint?
    var playlistMountedRows: [Int: NSView] = [:]
    var playlistRowHeight: CGFloat = 40
    var playlistWindowBuffer: CGFloat = 1.0
    var playlistIsReordering = false
    let inlineCreateContainer = NSView()
    let inlineCreateTextField = NSTextField()
    var playlistSearchField: GlassSearchField?
    var playlistScrollView: NSScrollView?
    var playlistActionRowStack: NSStackView?
    var playlistHeaderStack: NSStackView?
    var playlistDetailMode: PlaylistRecord?
    var playlistAddMode: Bool = false
    let featuresSectionLabel = NSTextField(labelWithString: "FEATURES")
    let settingsDivider = NSView()
    var featureIconViews: [NSImageView] = []
    var featureTitleLabels: [NSTextField] = []
    var featureDescLabels: [NSTextField] = []
    var featureChevronViews: [NSImageView] = []
    var featureRowContainers: [NSView] = []

    var masterGesturesToggle = NativeCapsuleToggleView()
    var appVolumeToggle = NativeCapsuleToggleView()
    var lyricsToggle = NativeCapsuleToggleView()
    var discordToggle = NativeCapsuleToggleView()
    var settingsVersionLabel: NSTextField?
    var themeToggle = NativeCapsuleStepToggleView()
    var progressToggle = NativeCapsuleStepToggleView()
    var progressDescLabel: NSTextField?
    var themeDescLabel: NSTextField?

    // Gesture Mapping Sub-View
    var gestureMappingSubView: NSView?
    var gestureMappingRows: [GestureMappingRowView] = []
    var gestureMappingSectionLabel: NSTextField?
    var gestureMappingBackButton: NSButton?
    var gestureMappingResetButton: NSButton?
    var gestureMappingStackView: NSStackView?
    var gestureMappingScrollView: NSScrollView?

    func updateRepeatButtonColor() {
        let iconName = (repeatMode == .one) ? "repeat.1" : "repeat"
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14.0, weight: .semibold)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Repeat")?.withSymbolConfiguration(iconConfig) {
            repeatButton.image = image
        }

        let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))

        if repeatMode != .off {
            if isLight {
                repeatButton.contentTintColor = NSColor.lightThemeSelector
            } else if PlayerDesign.current == .darkMode {
                repeatButton.contentTintColor = NSColor.darkThemeSelector
            } else {
                repeatButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
            }
        } else {
            repeatButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: PlayerDesign.current)
        }
    }
    public static var sharedAmbientBgColor: CGColor?
    public static var sharedAmbientAccentColor: NSColor?
    var lastAmbientBgColor: CGColor?
    var lastAmbientBorderColor: CGColor?
    var lastAmbientAccentColor: NSColor?
    
    var controlsStackCenterX: NSLayoutConstraint?
    var controlsStackLeading: NSLayoutConstraint?
    
    let controlsStack = NSStackView()
    let searchField = GlassSearchField()
    let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    let waveformProgressView = InteractiveWaveformProgressView()
    
    var lastArtworkUrl = ""
    var lastArtworkTrackID = ""
    var lastTrackTitle = ""
    var lastTrackArtist = ""


    
    let toastView = NSView()
    let toastLabel = NSTextField(labelWithString: "")
    var toastDismissTimer: Timer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        restoreSavedState()
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(appearanceChangedNotification), name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged(_:)), name: NetworkMonitor.statusChangedNotification, object: nil)
        applyTheme()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        restoreSavedState()
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(appearanceChangedNotification), name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged(_:)), name: NetworkMonitor.statusChangedNotification, object: nil)
        applyTheme()
    }
    
    func restoreSavedState() {
        if let savedVideoId = UserDefaults.standard.string(forKey: "YTM_lastVideoId"), !savedVideoId.isEmpty {
            lastArtworkTrackID = savedVideoId
        }
        if let savedTitle = UserDefaults.standard.string(forKey: "YTM_lastTitle"), !savedTitle.isEmpty {
            titleLabel.stringValue = savedTitle
        }
        if let savedArtist = UserDefaults.standard.string(forKey: "YTM_lastArtist"), !savedArtist.isEmpty {
            artistLabel.stringValue = savedArtist
        }
        if let savedArt = UserDefaults.standard.string(forKey: "YTM_lastArtwork"), !savedArt.isEmpty {
            lastArtworkUrl = savedArt
            loadArtwork(urlStr: savedArt)
        }
        
        let savedIsLiked = UserDefaults.standard.bool(forKey: "YTM_lastIsLiked")
        self.isLiked = savedIsLiked
        let iconName = savedIsLiked ? "heart.fill" : "heart"
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Like")?.withSymbolConfiguration(iconConfig) {
            likeButton.image = image
        }
        updateLikeButtonColor()
    }
    
    func updateLikeButtonColor() {
        if isLiked {
            likeButton.contentTintColor = NSColor(red: 0.98, green: 0.25, blue: 0.35, alpha: 1.0)
        } else {
            likeButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: PlayerDesign.current)
        }
    }
    
    func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        NotificationCenter.default.addObserver(forName: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil, queue: .main) { [weak self] _ in
            self?.refreshPlaylistsSection()
            self?.updateDownloadButtonState()
        }

        NotificationCenter.default.addObserver(forName: HistoryManager.historyUpdatedNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.isSettingsExpanded && self.activeSettingsMode == .playlist && self.activeLibraryTab == .history && self.playlistDetailMode == nil {
                self.refreshPlaylistsSection(filterQuery: self.playlistSearchField?.stringValue ?? "")
            }
        }

        NotificationCenter.default.addObserver(forName: LikedSongsManager.likedSongsUpdatedNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.isSettingsExpanded && self.activeSettingsMode == .playlist && self.activeLibraryTab == .likedSongs && self.playlistDetailMode == nil {
                self.refreshPlaylistsSection(filterQuery: self.playlistSearchField?.stringValue ?? "")
            }
        }

        NotificationCenter.default.addObserver(forName: DownloadManager.progressNotification, object: nil, queue: .main) { [weak self] notif in
            self?.updateDownloadButtonState()
            guard let self = self, let info = notif.userInfo else { return }
            let remaining = info["remaining"] as? Int ?? 0
            let total = info["total"] as? Int ?? 0
            let idx = info["index"] as? Int ?? 0
            let eta = info["eta"] as? String ?? ""
            let pct = info["progress"] as? Double ?? 0.0

            if remaining > 0 {
                let etaStr = eta.isEmpty ? "" : " • ETA \(eta)"
                self.playlistDetailDownloadAllButton.toolTip = "Queue (\(idx)/\(total)) • \(Int(pct * 100))%\(etaStr)"
            } else {
                self.playlistDetailDownloadAllButton.toolTip = "Download All Tracks"
            }
        }

        NotificationCenter.default.addObserver(forName: DownloadManager.queueNotification, object: nil, queue: .main) { [weak self] notif in
            self?.updateDownloadButtonState()
            guard let self = self, let info = notif.userInfo else { return }
            let remaining = info["remaining"] as? Int ?? 0
            let total = info["total"] as? Int ?? 0
            let idx = info["index"] as? Int ?? 0
            let eta = info["eta"] as? String ?? ""
            let pct = info["progress"] as? Double ?? 0.0

            if remaining > 0 {
                let etaStr = eta.isEmpty ? "" : " • ETA \(eta)"
                self.playlistDetailDownloadAllButton.toolTip = "Queue (\(idx)/\(total)) • \(Int(pct * 100))%\(etaStr)"
            } else {
                self.playlistDetailDownloadAllButton.toolTip = "Download All Tracks"
            }
        }
        
        containerPill.translatesAutoresizingMaskIntoConstraints = false
        containerPill.wantsLayer = true
        containerPill.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.98).cgColor
        containerPill.layer?.cornerRadius = 20
        containerPill.layer?.masksToBounds = true
        containerPill.layer?.borderWidth = 1.0
        containerPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        containerPill.onBackgroundClick = { [weak self] in
            self?.collapseSettingsForOutsideClick()
        }

        visualEffectBackdrop.translatesAutoresizingMaskIntoConstraints = false
        visualEffectBackdrop.material = .underWindowBackground
        visualEffectBackdrop.blendingMode = .behindWindow
        visualEffectBackdrop.state = .active
        visualEffectBackdrop.wantsLayer = true
        visualEffectBackdrop.layer?.cornerRadius = 20
        visualEffectBackdrop.layer?.masksToBounds = true
        visualEffectBackdrop.isHidden = true
        containerPill.addSubview(visualEffectBackdrop, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            visualEffectBackdrop.topAnchor.constraint(equalTo: containerPill.topAnchor),
            visualEffectBackdrop.leadingAnchor.constraint(equalTo: containerPill.leadingAnchor),
            visualEffectBackdrop.trailingAnchor.constraint(equalTo: containerPill.trailingAnchor),
            visualEffectBackdrop.bottomAnchor.constraint(equalTo: containerPill.bottomAnchor),
        ])

        glassSheenLayer.colors = [
            NSColor(white: 1.0, alpha: 0.14).cgColor,
            NSColor(white: 1.0, alpha: 0.03).cgColor,
            NSColor(white: 1.0, alpha: 0.00).cgColor
        ]
        glassSheenLayer.locations = [0.0, 0.45, 1.0]
        glassSheenLayer.cornerRadius = 20
        glassSheenLayer.masksToBounds = true
        glassSheenLayer.isHidden = true
        containerPill.layer?.addSublayer(glassSheenLayer)

        cylindricalLensLayer.cornerRadius = 20
        cylindricalLensLayer.masksToBounds = true
        cylindricalLensLayer.isHidden = true
        containerPill.layer?.addSublayer(cylindricalLensLayer)

        setupLiquidFluidLayer()
        containerPill.layer?.insertSublayer(liquidFluidMeshLayer, at: 0)
        
        artworkImageView.translatesAutoresizingMaskIntoConstraints = false
        artworkImageView.wantsLayer = true
        artworkImageView.layer?.cornerRadius = 8
        artworkImageView.layer?.masksToBounds = true
        artworkImageView.imageScaling = .scaleAxesIndependently
        
        artworkImageView.image = AppArtworkHelper.defaultArtwork
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.isScrollable = false
        titleLabel.cell?.truncatesLastVisibleLine = true
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true
        titleLabel.setContentCompressionResistancePriority(.init(240), for: .horizontal)
        titleLabel.setContentHuggingPriority(.init(240), for: .horizontal)
        
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        artistLabel.textColor = NSColor(white: 0.70, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.cell?.isScrollable = false
        artistLabel.cell?.truncatesLastVisibleLine = true
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true
        artistLabel.setContentCompressionResistancePriority(.init(240), for: .horizontal)
        artistLabel.setContentHuggingPriority(.init(240), for: .horizontal)
        
        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.setContentCompressionResistancePriority(.init(240), for: .horizontal)
        textStack.setContentHuggingPriority(.init(240), for: .horizontal)
        
        setupIconButton(addToPlaylistButton, systemName: "text.badge.plus", toolTip: "Add to Playlist", action: #selector(addToPlaylistButtonTapped), pointSize: 13.5)
        setupIconButton(repeatButton, systemName: "repeat", toolTip: "Repeat Track / Playlist", action: #selector(repeatTapped), pointSize: 14.0)
        setupIconButton(previousButton, systemName: "backward.fill", toolTip: "Previous", action: #selector(previousTapped), pointSize: 14.3)
        setupIconButton(playPauseButton, systemName: "play.fill", toolTip: "Play/Pause", action: #selector(playPauseTapped), pointSize: 16.0)
        setupIconButton(nextButton, systemName: "forward.fill", toolTip: "Next", action: #selector(nextTapped), pointSize: 14.3)
        setupIconButton(likeButton, systemName: "heart", toolTip: "Like Track", action: #selector(likeTapped), pointSize: 16.0)
        setupIconButton(searchIconButton, systemName: "magnifyingglass", toolTip: "Search YouTube Music", action: #selector(searchIconTapped), pointSize: 16.0)

        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.isBordered = false
        downloadButton.target = self
        downloadButton.action = #selector(downloadCurrentTrackTapped)
        downloadButton.toolTip = "Download Song"

        setupIconButton(fullScreenButton, systemName: "macwindow.on.rectangle", toolTip: "Open Full Web Browser View", action: #selector(fullScreenTapped), pointSize: 13.5)
        setupIconButton(browserButton, systemName: "ellipsis.circle.fill", toolTip: "Player Settings & Options", action: #selector(browserTapped), pointSize: 14.8)
        setupIconButton(resetPositionButton, systemName: "arrow.uturn.backward", toolTip: "Snap Player Back to Menu Bar", action: #selector(resetPositionTapped), pointSize: 13.5)
        resetPositionButton.isHidden = true
        
        playPauseButton.contentTintColor = NSColor.white
        previousButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        nextButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        addToPlaylistButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        repeatButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        likeButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        searchIconButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        fullScreenButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        browserButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        resetPositionButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        
        controlsStack.setViews([addToPlaylistButton, repeatButton, previousButton, playPauseButton, nextButton, likeButton, searchIconButton], in: .center)
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 7
        controlsStack.alignment = .centerY
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        [addToPlaylistButton, repeatButton, previousButton, playPauseButton, nextButton, likeButton, searchIconButton, downloadButton, fullScreenButton, browserButton].forEach { btn in
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            btn.setContentHuggingPriority(.required, for: .horizontal)
        }
        
        let topRightStack = NSStackView(views: [downloadButton, fullScreenButton, browserButton])
        topRightStack.orientation = .horizontal
        topRightStack.spacing = 6
        topRightStack.alignment = .centerY
        topRightStack.translatesAutoresizingMaskIntoConstraints = false
        topRightStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        topRightStack.setContentHuggingPriority(.required, for: .horizontal)
        
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search YouTube Music..."
        searchField.delegate = self
        searchField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        searchField.alphaValue = 0.0
        searchField.isHidden = true
        searchField.onFocusChange = { [weak self] isFocused in
            if !isFocused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self = self else { return }
                    if let firstResponder = self.window?.firstResponder as? NSView {
                        if firstResponder.isDescendant(of: self.searchField) || firstResponder == self.searchField {
                            return
                        }
                    }
                    self.collapseSearchField()
                }
            }
        }
        
        waveformProgressView.translatesAutoresizingMaskIntoConstraints = false
        waveformProgressView.onSeek = { [weak self] ratio in
            let duration = NowPlayingManager.shared.currentState.duration
            if duration > 0 {
                self?.delegate?.dynamicIslandDidSeek(to: ratio * duration)
            }
        }
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = NSColor(white: 0.60, alpha: 1.0)
        timeLabel.alignment = .right
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.refusesFirstResponder = true
        
        toastView.wantsLayer = true
        toastView.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 0.96).cgColor
        toastView.layer?.cornerRadius = 10
        toastView.layer?.borderWidth = 1.0
        toastView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
        toastView.alphaValue = 0.0
        toastView.isHidden = true
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        toastLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        toastLabel.textColor = .white
        toastLabel.alignment = .center
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.isEditable = false
        toastLabel.isSelectable = false
        toastLabel.refusesFirstResponder = true
        
        toastView.addSubview(toastLabel)
        
        setupSettingsContainerView()
        
        containerPill.addSubview(artworkImageView)
        containerPill.addSubview(textStack)
        containerPill.addSubview(topRightStack)
        containerPill.addSubview(controlsStack)
        containerPill.addSubview(searchField)
        containerPill.addSubview(waveformProgressView)
        containerPill.addSubview(timeLabel)
        containerPill.addSubview(settingsContainerView)
        containerPill.addSubview(toastView)
        
        addSubview(containerPill)
        
        let controlsCenterX = controlsStack.centerXAnchor.constraint(equalTo: containerPill.centerXAnchor)
        let controlsLeading = controlsStack.leadingAnchor.constraint(equalTo: containerPill.leadingAnchor, constant: 16)
        
        self.controlsStackCenterX = controlsCenterX
        self.controlsStackLeading = controlsLeading
        
        controlsCenterX.isActive = true // Default centered state!
        
        let collapsedConstraint = containerPill.bottomAnchor.constraint(equalTo: waveformProgressView.bottomAnchor, constant: 12)
        let settingsConstraint = containerPill.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: 12)
        let settingsHeight = settingsContainerView.heightAnchor.constraint(equalToConstant: 292)
        
        self.containerPillBottomCollapsedConstraint = collapsedConstraint
        self.containerPillBottomSettingsConstraint = settingsConstraint
        self.settingsContainerHeightConstraint = settingsHeight
        
        collapsedConstraint.isActive = true
        settingsConstraint.isActive = false
        
        NSLayoutConstraint.activate([
            containerPill.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            containerPill.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            containerPill.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            containerPill.widthAnchor.constraint(equalToConstant: 360),
            
            // Toast Notification Banner
            toastView.centerXAnchor.constraint(equalTo: containerPill.centerXAnchor),
            toastView.topAnchor.constraint(equalTo: containerPill.topAnchor, constant: 6),
            toastView.heightAnchor.constraint(equalToConstant: 24),
            
            toastLabel.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 12),
            toastLabel.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -12),
            toastLabel.centerYAnchor.constraint(equalTo: toastView.centerYAnchor),
            
            // ROW 1: Album Artwork
            artworkImageView.leadingAnchor.constraint(equalTo: containerPill.leadingAnchor, constant: 16),
            artworkImageView.topAnchor.constraint(equalTo: containerPill.topAnchor, constant: 12),
            artworkImageView.widthAnchor.constraint(equalToConstant: 44),
            artworkImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // ROW 1: Top Right Actions (Like, Theme, Browser) Aligned with Song Name
            topRightStack.trailingAnchor.constraint(equalTo: containerPill.trailingAnchor, constant: -16),
            topRightStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            
            // ROW 1: Title & Artist Column
            textStack.leadingAnchor.constraint(equalTo: artworkImageView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: artworkImageView.topAnchor, constant: 2),
            textStack.trailingAnchor.constraint(equalTo: topRightStack.leadingAnchor, constant: -8),
            textStack.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            
            // ROW 2: Playback Controls (Positioned vertically under artwork)
            controlsStack.topAnchor.constraint(equalTo: artworkImageView.bottomAnchor, constant: 10),
            
            // ROW 2: Expandable Search Bar (Positioned directly after search icon, leaving all buttons intact!)
            searchField.leadingAnchor.constraint(equalTo: controlsStack.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: containerPill.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: controlsStack.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            
            // ROW 3: Waveform Progress Bar Aligned with Left Edge & Artwork
            waveformProgressView.leadingAnchor.constraint(equalTo: containerPill.leadingAnchor, constant: 16),
            waveformProgressView.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),
            waveformProgressView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            waveformProgressView.heightAnchor.constraint(equalToConstant: 12),
            
            // ROW 3: Timestamp Label Baseline Aligned with Waveform
            timeLabel.trailingAnchor.constraint(equalTo: containerPill.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: waveformProgressView.centerYAnchor),

            // ROW 4: Settings & Options Container
            settingsContainerView.topAnchor.constraint(equalTo: waveformProgressView.bottomAnchor, constant: 12),
            settingsContainerView.leadingAnchor.constraint(equalTo: containerPill.leadingAnchor, constant: 12),
            settingsContainerView.trailingAnchor.constraint(equalTo: containerPill.trailingAnchor, constant: -12),
            settingsHeight
        ])
    }
    
    func setupIconButton(_ button: NSButton, systemName: String, toolTip: String, action: Selector, pointSize: CGFloat) {
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: toolTip)?.withSymbolConfiguration(config) {
            button.image = image
        } else {
            button.title = toolTip
        }
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.toolTip = toolTip
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            searchSubmitted()
            return true
        }
        return false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field == searchField else { return }
    }
    
    private var lastPlayPauseIcon: String = ""
    private var lastLikeState: Bool? = nil

    func updateState(_ state: PlaybackState) {
        var trackChanged = false
        if !state.title.isEmpty && state.title != "Not Playing" {
            trackChanged = (state.title != lastTrackTitle || state.artist != lastTrackArtist)
            if trackChanged {
                lastTrackTitle = state.title
                lastTrackArtist = state.artist
            }
        }
        
        guard let window = self.window, window.isVisible else { return }

        if !state.title.isEmpty && state.title != "Not Playing" {
            let cleanT = LyricsManager.cleanSongInfo(state.title)
            let displayT = cleanT.isEmpty ? state.title : cleanT
            let cleanA = LyricsManager.cleanSongInfo(state.artist)
            let displayA = cleanA.isEmpty ? state.artist : cleanA

            if titleLabel.stringValue != displayT {
                titleLabel.stringValue = displayT
                titleLabel.toolTip = state.title
            }
            if artistLabel.stringValue != displayA {
                artistLabel.stringValue = displayA
                artistLabel.toolTip = state.artist
            }
        } else {
            if titleLabel.stringValue != "Not Playing" {
                titleLabel.stringValue = "Not Playing"
                titleLabel.toolTip = nil
            }
            if artistLabel.stringValue != "YouTube Music" {
                artistLabel.stringValue = "YouTube Music"
                artistLabel.toolTip = nil
            }
        }

        let playIcon = state.isPlaying ? "pause.fill" : "play.fill"
        if lastPlayPauseIcon != playIcon {
            lastPlayPauseIcon = playIcon
            let config = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
            if let image = NSImage(systemSymbolName: playIcon, accessibilityDescription: "Play/Pause")?.withSymbolConfiguration(config) {
                playPauseButton.image = image
            }
        }

        waveformProgressView.isPlaying = state.isPlaying
        waveformProgressView.duration = state.duration

        if !waveformProgressView.isUserScrubbing {
            let accurateTime = state.getAccurateTime()
            if state.duration > 0 && accurateTime >= 0 {
                let ratio = max(0.0, min(1.0, accurateTime / state.duration))
                waveformProgressView.progress = ratio
                let timeStr = "\(formatTime(accurateTime)) / \(formatTime(state.duration))"
                if timeLabel.stringValue != timeStr {
                    timeLabel.stringValue = timeStr
                }
            } else {
                waveformProgressView.progress = 0.0
                if timeLabel.stringValue != "0:00 / 0:00" {
                    timeLabel.stringValue = "0:00 / 0:00"
                }
            }
        }

        if NowPlayingManager.shared.engineMode == .offline {
            if let offlineTrack = NativeAudioPlayer.shared.currentTrack {
                let art = offlineTrack.artwork ?? AppArtworkHelper.defaultArtwork
                if self.artworkImageView.image != art {
                    self.artworkImageView.image = art
                    self.artworkImageView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
                    if let cg = art.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        self.updateAmbientGlow(cgImage: cg)
                    }
                }
            } else if self.artworkImageView.image != AppArtworkHelper.defaultArtwork {
                self.artworkImageView.image = AppArtworkHelper.defaultArtwork
            }
        } else {
            // Online Mode (YouTube Music)
            // Key artwork loading by the track (videoId), not the URL —
            // YTM rotates its signed thumbnail URLs, so the URL string
            // changes even when the image is identical.
            if !state.artworkUrl.isEmpty {
                let trackKey = state.videoId.isEmpty ? state.artworkUrl : state.videoId
                if trackKey != lastArtworkTrackID || self.artworkImageView.image == nil {
                    lastArtworkTrackID = trackKey
                    lastArtworkUrl = state.artworkUrl
                    loadArtwork(urlStr: state.artworkUrl)
                }
            } else if self.artworkImageView.image == nil {
                self.artworkImageView.image = AppArtworkHelper.defaultArtwork
            }
        }
        
        if lastLikeState != state.isLiked {
            lastLikeState = state.isLiked
            self.isLiked = state.isLiked
            let iconName = state.isLiked ? "heart.fill" : "heart"
            let iconConfig = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Like")?.withSymbolConfiguration(iconConfig) {
                likeButton.image = image
            }
            updateLikeButtonColor()
        }

        if state.isRepeatOn && self.repeatMode == .off {
            self.repeatMode = .one
            updateRepeatButtonColor()
        } else if !state.isRepeatOn && self.repeatMode != .one {
            self.repeatMode = .off
            updateRepeatButtonColor()
        }

        updateDownloadButtonState()
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let sec = Int(seconds)
        let mins = sec / 60
        let secs = sec % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @objc func addToPlaylistButtonTapped() {
        addToPlaylistButton.animatePop()
        if isSettingsExpanded && activeSettingsMode == .playlist {
            collapseSettings()
        } else {
            expandAddToPlaylist()
        }
    }

    @objc func browserTapped() {
        browserButton.animatePop()
        if isSettingsExpanded && activeSettingsMode == .preferences {
            collapseSettings()
        } else {
            expandPreferences()
        }
    }

    public func collapseSettings() {
        guard isSettingsExpanded else {
            if !settingsContainerView.isHidden {
                settingsContainerView.isHidden = true
            }
            return
        }
        isSettingsExpanded = false
        if activeSettingsMode == .preferences {
            browserButton.animatePop()
        }
        updateBrowserButtonColor()
        updateAddToPlaylistButtonColor()

        settingsContainerView.isHidden = true
        containerPillBottomSettingsConstraint?.isActive = false
        containerPillBottomCollapsedConstraint?.isActive = true
        delegate?.dynamicIslandDidToggleExpanded(expanded: false)
    }

    private func collapseSettingsForOutsideClick() {
        if isSettingsExpanded && activeSettingsMode == .preferences {
            collapseSettings()
        }
    }

    public func expandPreferences() {
        activeSettingsMode = .preferences
        settingsContainerHeightConstraint?.constant = 272
        showMainSettingsView()
        expandSettingsPanel()
    }

    public func expandAddToPlaylist() {
        activeSettingsMode = .playlist
        settingsContainerHeightConstraint?.constant = 305
        showAddToPlaylistSubView()
        expandSettingsPanel()
    }

    private func expandSettingsPanel() {
        if isSettingsExpanded {
            updateBrowserButtonColor()
            updateAddToPlaylistButtonColor()
            updateSettingsThemeHighlight()
            return
        }
        isSettingsExpanded = true
        updateBrowserButtonColor()
        updateAddToPlaylistButtonColor()
        updateSettingsThemeHighlight()
        
        containerPillBottomCollapsedConstraint?.isActive = false
        containerPillBottomSettingsConstraint?.isActive = true
        delegate?.dynamicIslandDidToggleExpanded(expanded: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, self.isSettingsExpanded else { return }
            self.settingsContainerView.isHidden = false
        }
    }

    func flashGlowOnButton() {
        guard let layer = addToPlaylistButton.layer else { return }
        let baseColor = (PlayerDesign.current == .glassMode) ? NSColor.black : NSColor.white
        let glow = CABasicAnimation(keyPath: "shadowOpacity")
        glow.fromValue = 0.0
        glow.toValue = 0.9
        glow.duration = 0.18
        glow.autoreverses = true
        glow.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let radius = CABasicAnimation(keyPath: "shadowRadius")
        radius.fromValue = 0.0
        radius.toValue = 7.0
        radius.duration = 0.18
        radius.autoreverses = true

        layer.shadowColor = baseColor.cgColor
        layer.shadowOffset = CGSize.zero
        layer.shadowOpacity = 0.0
        layer.add(glow, forKey: "glowOpacity")
        layer.add(radius, forKey: "glowRadius")

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.25
        pulse.duration = 0.12
        pulse.autoreverses = true
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "glowPulse")
    }

    @objc func repeatTapped() {
        repeatButton.animatePop()
        repeatMode = (repeatMode == .off) ? .one : .off
        updateRepeatButtonColor()
        NowPlayingManager.shared.setRepeatMode(repeatMode)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: repeatMode.displayName)
    }

    @objc func previousTapped() {
        previousButton.animateBounce(direction: -1.0)
        delegate?.dynamicIslandDidTapPrevious()
    }
    
    @objc func nextTapped() {
        nextButton.animateBounce(direction: 1.0)
        delegate?.dynamicIslandDidTapNext()
    }
    
    
    @objc func searchIconTapped() {
        if searchField.isHidden || searchField.alphaValue < 0.5 {
            expandSearchField()
        } else {
            collapseSearchField()
        }
    }
    
    func expandSearchField() {
        searchField.isHidden = false
        searchField.alphaValue = 0.0
        
        let xConfig = NSImage.SymbolConfiguration(pointSize: 14.3, weight: .bold)
        if let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Search")?.withSymbolConfiguration(xConfig) {
            searchIconButton.image = image
        }
        searchIconButton.toolTip = "Close Search"
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            self.controlsStackCenterX?.isActive = false
            self.controlsStackLeading?.isActive = true
            self.searchField.animator().alphaValue = 1.0
            
            self.containerPill.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            self?.window?.makeFirstResponder(self?.searchField)
        })
    }
    
    var isCollapsingSearch = false
    
    func collapseSearchField() {
        guard !isCollapsingSearch else { return }
        isCollapsingSearch = true
        
        let searchConfig = NSImage.SymbolConfiguration(pointSize: 16.0, weight: .semibold)
        if let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search YouTube Music")?.withSymbolConfiguration(searchConfig) {
            searchIconButton.image = image
        }
        searchIconButton.toolTip = "Search YouTube Music"
        
        if window?.firstResponder == searchField {
            window?.makeFirstResponder(nil)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            self.controlsStackLeading?.isActive = false
            self.controlsStackCenterX?.isActive = true
            self.searchField.animator().alphaValue = 0.0
            
            self.containerPill.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            self?.searchField.isHidden = true
            self?.isCollapsingSearch = false
        })
    }
    
    @objc func networkStatusChanged(_ note: Notification) {
        let isReachable = note.userInfo?["isReachable"] as? Bool ?? true
        if !isReachable {
            showToastBanner(message: "⚡ Offline Mode - No Internet Connection", isWarning: true)
        } else {
            showToastBanner(message: "🟢 Internet Connection Restored!", isWarning: false)
        }
    }

    public func showToastBanner(message: String, isWarning: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.toastDismissTimer?.invalidate()
            
            self.toastLabel.stringValue = message
            self.toastView.layer?.borderColor = isWarning ?
                NSColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 0.70).cgColor :
                NSColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 0.70).cgColor
            
            self.toastView.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.toastView.animator().alphaValue = 1.0
            }
            
            self.toastDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    self.toastView.animator().alphaValue = 0.0
                }, completionHandler: {
                    self.toastView.isHidden = true
                })
            }
        }
    }
    
    @objc func searchSubmitted() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if URLFilter.containsLink(query) {
            searchField.stringValue = ""
            showToastBanner(message: "⚠️ Links/URLs are not allowed in search", isWarning: true)
            return
        }
        if !query.isEmpty && !NetworkMonitor.shared.isReachable {
            showToastBanner(message: "⚡ Offline: Internet connection required to search", isWarning: true)
            return
        }
        searchField.stringValue = ""
        collapseSearchField()
        window?.makeFirstResponder(nil)
        if !query.isEmpty {
            delegate?.dynamicIslandDidSearch(query: query)
        }
    }
    
    @objc func playPauseTapped() {
        playPauseButton.animatePop()
        let isPlaying = NowPlayingManager.shared.currentState.isPlaying
        let nextPlayState = !isPlaying
        let playIcon = nextPlayState ? "pause.fill" : "play.fill"
        lastPlayPauseIcon = playIcon
        let config = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
        if let image = NSImage(systemSymbolName: playIcon, accessibilityDescription: "Play/Pause")?.withSymbolConfiguration(config) {
            playPauseButton.image = image
        }
        delegate?.dynamicIslandDidTapPlayPause()
    }
    
    @objc func likeTapped() {
        isLiked.toggle()
        lastLikeState = isLiked
        likeButton.animateHeartPop()
        let iconName = isLiked ? "heart.fill" : "heart"
        let config = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Like")?.withSymbolConfiguration(config) {
            likeButton.image = image
        }
        updateLikeButtonColor()
        NowPlayingManager.shared.toggleLike()
    }
    
    public func updateDownloadButtonState() {
        let state = NowPlayingManager.shared.currentState
        guard !state.title.isEmpty, state.title != "Not Playing" else {
            downloadButton.downloadState = .idleDownload
            downloadButton.toolTip = "Download Song"
            return
        }

        if NowPlayingManager.shared.engineMode == .offline {
            downloadButton.downloadState = .completed
            downloadButton.toolTip = "Downloaded (Available Offline)"
            return
        }

        let cleanT = LyricsManager.cleanSongInfo(state.title)
        let cleanA = LyricsManager.cleanSongInfo(state.artist)
        let vid = state.videoId.isEmpty ? DownloadManager.extractVideoID(from: state.pageUrl) : state.videoId

        let isAlreadyDownloaded = LocalLibraryManager.shared.allTracks.contains { track in
            if let v = vid, let tv = track.ytVideoId, !tv.isEmpty, tv == v {
                return true
            }
            let matchTitle = track.title.lowercased() == cleanT.lowercased() || track.cleanTitle.lowercased() == cleanT.lowercased()
            let matchArtist = cleanA.isEmpty || track.artist.lowercased() == cleanA.lowercased() || track.cleanArtist.lowercased() == cleanA.lowercased()
            return matchTitle && (cleanA.isEmpty || matchArtist)
        }

        if isAlreadyDownloaded {
            downloadButton.downloadState = .completed
            downloadButton.toolTip = "Downloaded (Available Offline)"
            return
        }

        let idToLookup = vid ?? cleanT
        if let taskInfo = DownloadManager.shared.statusFor(id: idToLookup, videoId: vid) {
            switch taskInfo.status {
            case .queued:
                downloadButton.downloadState = .queued
            case .downloading(let progress, let eta, _):
                downloadButton.downloadState = .downloading(progress: progress, eta: eta)
            case .completed:
                downloadButton.downloadState = .completed
            case .failed:
                downloadButton.downloadState = .idleDownload
            }
        } else {
            downloadButton.downloadState = .idleDownload
        }
    }

    @objc func downloadCurrentTrackTapped() {
        downloadButton.animatePop()
        let state = NowPlayingManager.shared.currentState
        guard !state.title.isEmpty, state.title != "Not Playing" else {
            showToastBanner(message: "⚠️ Nothing playing right now", isWarning: true)
            return
        }

        if NowPlayingManager.shared.engineMode == .offline {
            showToastBanner(message: "✓ Currently playing offline track")
            return
        }

        let cleanT = LyricsManager.cleanSongInfo(state.title)
        let cleanA = LyricsManager.cleanSongInfo(state.artist)
        let vid = state.videoId.isEmpty ? (DownloadManager.extractVideoID(from: state.pageUrl) ?? "") : state.videoId
        let idToUse = vid.isEmpty ? "\(cleanT)_\(cleanA)" : vid

        switch downloadButton.downloadState {
        case .queued, .downloading:
            DownloadManager.shared.cancelTask(id: idToUse)
            downloadButton.downloadState = .idleDownload
        case .completed:
            break
        case .idleDownload, .unavailable:
            DownloadManager.shared.queueTrack(
                id: idToUse,
                urlOrVideoId: vid.isEmpty ? state.pageUrl : vid,
                title: state.title,
                artist: state.artist,
                artworkUrl: state.artworkUrl
            ) { [weak self] success, message in
                DispatchQueue.main.async {
                    if !success {
                        self?.showToastBanner(message: message, isWarning: true)
                    }
                    self?.updateDownloadButtonState()
                }
            }
            updateDownloadButtonState()
        }
    }

    @objc func offlineLibraryTapped() {
        collapseSettings()
        delegate?.dynamicIslandDidTapOfflineLibrary()
    }

    @objc func fullScreenTapped() {
        fullScreenButton.animatePop()
        collapseSettings()
        delegate?.dynamicIslandDidTapWebBrowser()
    }
    
    func updateBrowserButtonColor() {
        if isSettingsExpanded && activeSettingsMode == .preferences {
            let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
            let isDark = (PlayerDesign.current == .darkMode)
            browserButton.contentTintColor = isLight ? NSColor.lightThemeSelector : (isDark ? NSColor.darkThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))
        } else {
            switch PlayerDesign.current {
            case .glassMode:
                browserButton.contentTintColor = NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0)
            case .liquidFluid:
                browserButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .liquidFluid)
            case .adaptive:
                browserButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
            case .darkMode:
                browserButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
            }
        }
    }

    func updateAddToPlaylistButtonColor() {
        if isSettingsExpanded && activeSettingsMode == .playlist {
            let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
            let isDark = (PlayerDesign.current == .darkMode)
            addToPlaylistButton.contentTintColor = isLight ? NSColor.lightThemeSelector : (isDark ? NSColor.darkThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))
        } else {
            switch PlayerDesign.current {
            case .glassMode:
                addToPlaylistButton.contentTintColor = NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0)
            case .liquidFluid:
                addToPlaylistButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .liquidFluid)
            case .adaptive:
                addToPlaylistButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
            case .darkMode:
                addToPlaylistButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
            }
        }
    }

    @objc func resetPositionTapped() {
        resetPositionButton.animateSpinPop()
        delegate?.dynamicIslandDidTapResetPosition()
    }
    
    public func setResetPositionButtonHidden(_ isHidden: Bool) {
        resetPositionButton.isHidden = true
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            if isSettingsExpanded && activeSettingsMode == .preferences {
                collapseSettings()
            } else {
                expandPreferences()
            }
            return
        }
        if isSettingsExpanded {
            let location = convert(event.locationInWindow, from: nil)
            let settingsFrame = convert(settingsContainerView.bounds, from: settingsContainerView)
            let buttonFrame = convert(browserButton.bounds, from: browserButton)
            let playlistButtonFrame = convert(addToPlaylistButton.bounds, from: addToPlaylistButton)
            if settingsFrame.contains(location) {
                super.mouseDown(with: event)
                return
            }
            if !buttonFrame.contains(location) && !playlistButtonFrame.contains(location) {
                collapseSettings()
                return
            }
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        let hit = hitTest(localPoint)
        if hit == self || hit == containerPill {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func keyDown(with event: NSEvent) {
        if let responder = window?.firstResponder {
            if responder is NSText || responder is NSTextView || responder is NSTextField || responder is NSSearchField {
                super.keyDown(with: event)
                return
            }
        }

        if KeyboardCommandHandler.handle(keyCode: event.keyCode,
                                         isRepeat: event.isARepeat,
                                         showOverlay: { text in
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: text)
        }) {
            return
        }
        super.keyDown(with: event)
    }

    override func layout() {
        super.layout()
        glassSheenLayer.frame = containerPill.bounds
        cylindricalLensLayer.frame = containerPill.bounds
        liquidFluidMeshLayer.frame = containerPill.bounds
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
        updateSettingsThemeHighlight()
    }

    @objc func appearanceChangedNotification() {
        applyTheme()
        updateSettingsThemeHighlight()
    }
}

final class PillContainerView: NSView {
    var onBackgroundClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if hitTest(localPoint) == self {
            onBackgroundClick?()
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}
