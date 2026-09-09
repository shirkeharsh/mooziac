import AppKit
import Foundation
import UniformTypeIdentifiers

protocol PlaylistLibraryViewDelegate: AnyObject {
    func playlistLibraryDidRequestClose()
    func playlistLibraryDidPlayOnline(videoId: String)
}

public class PlaylistLibraryView: NSView, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {

    weak var delegate: PlaylistLibraryViewDelegate?

    static let dragType = NSPasteboard.PasteboardType("com.mooziac.playlist.reorder")

    public enum Tab: Int {
        case playlists = 0
        case likedSongs = 1
        case downloads = 2
        case history = 3
    }

    enum Mode {
        case list
        case detail(PlaylistRecord)
        case likedSongs
        case downloads
        case history
    }

    private let topBar = NSView()
    private let backButton = ReactiveIconButton()
    private let librarySegmentedControl = NSSegmentedControl(labels: ["Playlists", "Liked Songs", "Downloads", "History"], trackingMode: .selectOne, target: nil, action: nil)
    private let headerTitleLabel = NSTextField(labelWithString: "PLAYLISTS")
    private let headerSubtitleLabel = NSTextField(labelWithString: "")
    private var titleStack = NSStackView()
    
    // Header Action Buttons
    private let saveQueueButton = ReactiveIconButton()
    private let importHeaderButton = ReactiveIconButton()
    private let openFolderHeaderButton = ReactiveIconButton()
    private let downloadCurrentHeaderButton = ReactiveIconButton()
    private let addCurrentTrackButton = ReactiveIconButton()
    private let renameHeaderButton = ReactiveIconButton()
    private let downloadButton = ReactiveIconButton()
    private let moreMenuButton = ReactiveIconButton()
    private var actionStack = NSStackView()

    let searchField = GlassSearchField()
    private let visualEffectBackdrop = NSVisualEffectView()

    private let scrollView = NSScrollView()
    let tableView = PlaylistTableView()
    private let tableContainer = NSView()

    // Bottom Action Bar
    private let bottomBar = NSView()
    private let bottomNewPlaylistButton = NSButton()
    private let bottomAddCurrentTrackButton = NSButton()
    private let bottomImportButton = NSButton()

    let emptyStateView = NSView()
    private let emptyStateIcon = NSImageView()
    private let emptyStateLabel = NSTextField(labelWithString: "No playlists yet")
    private let emptyStateSubLabel = NSTextField(labelWithString: "Click '＋ New Playlist' below to create your first playlist")

    var mode: Mode = .list {
        didSet {
            currentSearchQuery = ""
            searchField.stringValue = ""
            reload()
        }
    }

    var allPlaylists: [PlaylistRecord] = []
    var filteredPlaylists: [PlaylistRecord] = []

    var allLikedSongs: [LikedSongRecord] = []
    var filteredLikedSongs: [LikedSongRecord] = []

    var allPlaylistItems: [PlaylistItemRecord] = []
    var filteredPlaylistItems: [PlaylistItemRecord] = []

    var allDownloads: [LocalTrack] = []
    var filteredDownloads: [LocalTrack] = []

    var allHistoryItems: [HistoryRecord] = []
    var filteredHistoryItems: [HistoryRecord] = []
    private var historyCurrentPage: Int = 0
    private let historyPageSize: Int = 50
    private var hasMoreHistory: Bool = true
    private var isLoadingHistory: Bool = false

    var currentSearchQuery: String = ""
    public override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupObservers()
        applyTheme()
        reload()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupObservers()
        applyTheme()
        reload()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

        // Drag & Drop
        registerForDraggedTypes([.fileURL, Self.dragType])

        // Visual Effect Backdrop for liquid glass theme
        visualEffectBackdrop.translatesAutoresizingMaskIntoConstraints = false
        visualEffectBackdrop.material = .hudWindow
        visualEffectBackdrop.blendingMode = .behindWindow
        visualEffectBackdrop.state = .active
        visualEffectBackdrop.wantsLayer = true
        visualEffectBackdrop.layer?.cornerRadius = 16
        visualEffectBackdrop.layer?.masksToBounds = true
        visualEffectBackdrop.isHidden = true
        addSubview(visualEffectBackdrop, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            visualEffectBackdrop.topAnchor.constraint(equalTo: topAnchor),
            visualEffectBackdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectBackdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectBackdrop.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Table Container (outlined card wrapping header + tracks + action bar)
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = 10
        tableContainer.layer?.borderWidth = 1.0
        tableContainer.layer?.masksToBounds = true
        addSubview(tableContainer)

        // Top Bar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(topBar)

        setupHeaderIconButton(backButton, systemName: "chevron.backward", toolTip: "Back", action: #selector(handleBackTapped), pointSize: 13.0)
        backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        topBar.addSubview(backButton)

        // Segmented Control
        librarySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        librarySegmentedControl.target = self
        librarySegmentedControl.action = #selector(handleSegmentChanged(_:))
        librarySegmentedControl.selectedSegment = 0
        librarySegmentedControl.segmentStyle = .texturedRounded
        librarySegmentedControl.font = NSFont.systemFont(ofSize: 11.0, weight: .medium)
        topBar.addSubview(librarySegmentedControl)

        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        headerTitleLabel.textColor = NSColor.white
        headerTitleLabel.isEditable = false
        headerTitleLabel.isSelectable = false
        headerTitleLabel.refusesFirstResponder = true
        headerTitleLabel.lineBreakMode = .byTruncatingTail

        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerSubtitleLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        headerSubtitleLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        headerSubtitleLabel.isEditable = false
        headerSubtitleLabel.isSelectable = false
        headerSubtitleLabel.refusesFirstResponder = true
        headerSubtitleLabel.lineBreakMode = .byTruncatingTail

        titleStack = NSStackView(views: [headerTitleLabel, headerSubtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 1
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        let titleClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleTitleClicked))
        titleStack.addGestureRecognizer(titleClickRecognizer)
        topBar.addSubview(titleStack)

        setupHeaderIconButton(saveQueueButton, systemName: "square.and.arrow.down", toolTip: "Save Current Queue as Playlist", action: #selector(handleSaveQueueTapped), pointSize: 12.0)
        setupHeaderIconButton(importHeaderButton, systemName: "plus", toolTip: "Import Audio Files…", action: #selector(handleImportTapped), pointSize: 13.0)
        importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        setupHeaderIconButton(openFolderHeaderButton, systemName: "folder", toolTip: "Open ~/Music/Mooziac in Finder", action: #selector(handleOpenFolderTapped), pointSize: 12.0)
        setupHeaderIconButton(downloadCurrentHeaderButton, systemName: "arrow.down.circle", toolTip: "Download Currently Playing Song", action: #selector(handleDownloadCurrentTapped), pointSize: 12.5)

        setupHeaderIconButton(addCurrentTrackButton, systemName: "plus", toolTip: "Add Currently Playing Track to Playlist", action: #selector(handleAddCurrentTrackToDetailPlaylist), pointSize: 13.0)
        addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

        setupHeaderIconButton(renameHeaderButton, systemName: "pencil", toolTip: "Rename Playlist", action: #selector(handleRenameCurrentPlaylist), pointSize: 12.0)
        renameHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

        setupHeaderIconButton(downloadButton, systemName: "arrow.down", toolTip: "Download Online Tracks", action: #selector(handleDownloadAllTapped), pointSize: 12.0)
        setupHeaderIconButton(moreMenuButton, systemName: "ellipsis", toolTip: "Options", action: #selector(handleMoreMenuTapped(_:)), pointSize: 12.5)

        actionStack = NSStackView(views: [importHeaderButton, downloadCurrentHeaderButton, openFolderHeaderButton, downloadButton, addCurrentTrackButton, renameHeaderButton, saveQueueButton, moreMenuButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 6
        actionStack.alignment = .centerY
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(actionStack)

        // Search Field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search playlists..."
        searchField.delegate = self
        tableContainer.addSubview(searchField)

        // Table View & Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleAction)
        tableView.registerForDraggedTypes([Self.dragType])

        tableView.onReturnKey = { [weak self] in
            self?.handleReturnAction()
        }
        tableView.onDeleteKey = { [weak self] in
            self?.handleDeleteKeyAction()
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PlaylistColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        tableContainer.addSubview(scrollView)

        // Bottom Bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.wantsLayer = true
        bottomBar.layer?.cornerRadius = 8
        tableContainer.addSubview(bottomBar)

        setupBottomLiquidButton(bottomNewPlaylistButton, title: "＋ New Playlist", action: #selector(handleNewPlaylistTapped))
        setupBottomLiquidButton(bottomAddCurrentTrackButton, title: "＋ Add Currently Playing Track", action: #selector(handleAddCurrentTrackToDetailPlaylist))
        setupBottomLiquidButton(bottomImportButton, title: "＋ Import Music Files", action: #selector(handleImportTapped))

        bottomBar.addSubview(bottomNewPlaylistButton)
        bottomBar.addSubview(bottomAddCurrentTrackButton)
        bottomBar.addSubview(bottomImportButton)

        NSLayoutConstraint.activate([
            bottomNewPlaylistButton.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomNewPlaylistButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomNewPlaylistButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomNewPlaylistButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),

            bottomAddCurrentTrackButton.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomAddCurrentTrackButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomAddCurrentTrackButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomAddCurrentTrackButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),

            bottomImportButton.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomImportButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomImportButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomImportButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor)
        ])

        // Empty State View
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
        emptyStateIcon.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Empty")?.withSymbolConfiguration(iconConfig)
        emptyStateIcon.contentTintColor = NSColor(white: 0.5, alpha: 1.0)
        emptyStateIcon.translatesAutoresizingMaskIntoConstraints = false

        emptyStateLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        emptyStateLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        emptyStateLabel.alignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateSubLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        emptyStateSubLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        emptyStateSubLabel.alignment = .center
        emptyStateSubLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)
        emptyStateView.addSubview(emptyStateSubLabel)
        addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableContainer.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            tableContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            tableContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            tableContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            topBar.topAnchor.constraint(equalTo: tableContainer.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            topBar.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            topBar.heightAnchor.constraint(equalToConstant: 32),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            librarySegmentedControl.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 2),
            librarySegmentedControl.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleStack.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: actionStack.leadingAnchor, constant: -8),
            titleStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            actionStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            actionStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            searchField.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 26),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -6),

            bottomBar.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            bottomBar.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            bottomBar.bottomAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: -8),
            bottomBar.heightAnchor.constraint(equalToConstant: 28),

            emptyStateView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 300),
            emptyStateView.heightAnchor.constraint(equalToConstant: 120),

            emptyStateIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 36),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 36),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateIcon.bottomAnchor, constant: 8),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            emptyStateSubLabel.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 4),
            emptyStateSubLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateSubLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor)
        ])
    }

    private func setupBottomLiquidButton(_ btn: NSButton, title: String, action: Selector) {
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        btn.target = self
        btn.action = action
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
    }

    private func setupHeaderIconButton(_ btn: ReactiveIconButton, systemName: String, toolTip: String, action: Selector, pointSize: CGFloat) {
        btn.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if let img = NSImage(systemSymbolName: systemName, accessibilityDescription: toolTip)?.withSymbolConfiguration(config) {
            btn.image = img
        }
        btn.toolTip = toolTip
        btn.target = self
        btn.action = action
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 5
        btn.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_ambientThemeChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHistoryUpdated), name: HistoryManager.historyUpdatedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDownloadsUpdated), name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLikedSongsUpdated), name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaylistsUpdated), name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("Mooziac_PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.reloadVisiblePlayingStates()
        }
    }

    @objc private func handleTitleClicked() {
        if case .detail = mode {
            handleRenameCurrentPlaylist()
        }
    }

    @objc private func handlePlaylistsUpdated() {
        switch mode {
        case .list:
            allPlaylists = PlaylistManager.shared.fetchPlaylists()
            applyFilter()
            emptyStateView.isHidden = !filteredPlaylists.isEmpty
            tableView.reloadData()
        case .detail(let pl):
            if let updated = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == pl.id }) {
                self.mode = .detail(updated)
            } else {
                self.mode = .list
            }
        default:
            break
        }
    }

    private func reloadVisiblePlayingStates() {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let maxIndex = min(visibleRange.location + visibleRange.length, numberOfRows(in: tableView))
        let design = PlayerDesign.current
        for rowIndex in visibleRange.location..<maxIndex {
            switch mode {
            case .detail:
                if rowIndex < filteredPlaylistItems.count,
                   let cell = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? PlaylistItemRowCellView {
                    let item = filteredPlaylistItems[rowIndex]
                    let resolution = PlaylistManager.shared.resolve(item)
                    cell.configure(item: item, resolution: resolution, design: design, index: rowIndex)
                }
            case .downloads:
                if rowIndex < filteredDownloads.count,
                   let cell = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? DownloadRowCellView {
                    let track = filteredDownloads[rowIndex]
                    cell.configure(track: track, design: design)
                }
            case .likedSongs:
                if rowIndex < filteredLikedSongs.count,
                   let cell = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? LikedSongRowCellView {
                    let record = filteredLikedSongs[rowIndex]
                    cell.configure(record: record, design: design)
                }
            case .history:
                if rowIndex < filteredHistoryItems.count,
                   let cell = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? HistoryRowCellView {
                    let item = filteredHistoryItems[rowIndex]
                    cell.configure(item: item, design: design)
                }
            default:
                break
            }
        }
    }

    private func loadInitialHistory() {
        historyCurrentPage = 0
        hasMoreHistory = true
        isLoadingHistory = false
        allHistoryItems = HistoryManager.shared.fetchHistory(limit: historyPageSize, offset: 0)
        if allHistoryItems.count < historyPageSize {
            hasMoreHistory = false
        }
        applyFilter()
    }

    func loadNextHistoryPage() {
        guard !isLoadingHistory, hasMoreHistory, currentSearchQuery.isEmpty else { return }
        isLoadingHistory = true
        historyCurrentPage += 1
        let offset = historyCurrentPage * historyPageSize
        let newItems = HistoryManager.shared.fetchHistory(limit: historyPageSize, offset: offset)
        if newItems.count < historyPageSize {
            hasMoreHistory = false
        }
        if !newItems.isEmpty {
            allHistoryItems.append(contentsOf: newItems)
            applyFilter()
            tableView.reloadData()
        }
        isLoadingHistory = false
    }

    @objc private func handleLikedSongsUpdated() {
        if case .likedSongs = mode {
            allLikedSongs = LikedSongsManager.shared.fetchLikedSongs()
            applyFilter()
            emptyStateView.isHidden = !filteredLikedSongs.isEmpty
            tableView.reloadData()
        }
    }

    @objc private func handleHistoryUpdated() {
        if case .history = mode {
            loadInitialHistory()
            emptyStateView.isHidden = !filteredHistoryItems.isEmpty
            tableView.reloadData()
        }
    }

    @objc private func handleDownloadsUpdated() {
        if case .downloads = mode {
            var tracks = LocalLibraryManager.shared.allTracks
            if let savedOrder = UserDefaults.standard.stringArray(forKey: "MooziacDownloadsCustomOrder"), !savedOrder.isEmpty {
                var rank: [String: Int] = [:]
                for (i, k) in savedOrder.enumerated() { rank[k] = i }
                let ordered = tracks.filter { rank[$0.id] != nil }.sorted { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
                let rest = tracks.filter { rank[$0.id] == nil }
                tracks = ordered + rest
            }
            allDownloads = tracks
            applyFilter()
            emptyStateView.isHidden = !filteredDownloads.isEmpty
            tableView.reloadData()
        }
    }

    @objc private func applyTheme() {
        let design = PlayerDesign.current
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            switch design {
            case .adaptive:
                visualEffectBackdrop.isHidden = true
                layer?.backgroundColor = (DynamicIslandPlayerView.sharedAmbientBgColor ?? NSColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 0.98).cgColor)
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
                headerTitleLabel.textColor = NSColor.white
                headerSubtitleLabel.textColor = SystemAppearanceHelper.secondaryTextColor(for: .adaptive)
                backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                saveQueueButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                openFolderHeaderButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                downloadCurrentHeaderButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                renameHeaderButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                downloadButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                moreMenuButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)

                bottomBar.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.06).cgColor
                bottomBar.layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
                bottomBar.layer?.borderWidth = 1.0

                tableContainer.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.03).cgColor
                tableContainer.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor

                bottomNewPlaylistButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                bottomAddCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                bottomImportButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

            case .darkMode:
                visualEffectBackdrop.isHidden = true
                layer?.backgroundColor = SystemAppearanceHelper.darkModeBackingColor.cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = SystemAppearanceHelper.darkModeBorderColor.cgColor
                headerTitleLabel.textColor = NSColor.white
                headerSubtitleLabel.textColor = SystemAppearanceHelper.secondaryTextColor(for: .darkMode)
                backButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                saveQueueButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
                openFolderHeaderButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                downloadCurrentHeaderButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
                renameHeaderButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                downloadButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                moreMenuButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)

                bottomBar.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
                bottomBar.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
                bottomBar.layer?.borderWidth = 1.0

                tableContainer.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.02).cgColor
                tableContainer.layer?.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor

                bottomNewPlaylistButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
                bottomAddCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
                bottomImportButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)

            case .glassMode:
                visualEffectBackdrop.isHidden = true
                layer?.backgroundColor = NSColor(red: 0.93725, green: 0.94902, blue: 0.94118, alpha: 0.98).cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(red: 0.78, green: 0.80, blue: 0.79, alpha: 0.90).cgColor
                let pitchBlack = SystemAppearanceHelper.primaryTextColor(for: .glassMode)
                headerTitleLabel.textColor = pitchBlack
                headerSubtitleLabel.textColor = SystemAppearanceHelper.secondaryTextColor(for: .glassMode)
                backButton.contentTintColor = pitchBlack
                saveQueueButton.contentTintColor = pitchBlack
                importHeaderButton.contentTintColor = NSColor.lightThemeSelector
                openFolderHeaderButton.contentTintColor = pitchBlack
                downloadCurrentHeaderButton.contentTintColor = pitchBlack
                addCurrentTrackButton.contentTintColor = NSColor.lightThemeSelector
                renameHeaderButton.contentTintColor = pitchBlack
                downloadButton.contentTintColor = pitchBlack
                moreMenuButton.contentTintColor = pitchBlack

                bottomBar.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.04).cgColor
                bottomBar.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
                bottomBar.layer?.borderWidth = 1.0

                tableContainer.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
                tableContainer.layer?.borderColor = NSColor(white: 0.0, alpha: 0.12).cgColor

                bottomNewPlaylistButton.contentTintColor = NSColor.lightThemeSelector
                bottomAddCurrentTrackButton.contentTintColor = NSColor.lightThemeSelector
                bottomImportButton.contentTintColor = NSColor.lightThemeSelector

            case .liquidFluid:
                let isDark = SystemAppearanceHelper.isDarkSystemAppearance
                visualEffectBackdrop.isHidden = false
                visualEffectBackdrop.material = isDark ? .hudWindow : .popover
                visualEffectBackdrop.blendingMode = .behindWindow
                visualEffectBackdrop.state = .active

                layer?.backgroundColor = SystemAppearanceHelper.liquidFluidBackingColor.cgColor
                layer?.borderWidth = 1.5
                layer?.borderColor = SystemAppearanceHelper.liquidFluidBorderColor.cgColor

                let primaryColor = SystemAppearanceHelper.primaryTextColor(for: .liquidFluid)
                let secondaryColor = SystemAppearanceHelper.secondaryTextColor(for: .liquidFluid)
                let btnTint = SystemAppearanceHelper.controlButtonTint(for: .liquidFluid)

                headerTitleLabel.textColor = primaryColor
                headerSubtitleLabel.textColor = secondaryColor
                backButton.contentTintColor = primaryColor
                saveQueueButton.contentTintColor = btnTint
                importHeaderButton.contentTintColor = btnTint
                openFolderHeaderButton.contentTintColor = btnTint
                downloadCurrentHeaderButton.contentTintColor = btnTint
                addCurrentTrackButton.contentTintColor = btnTint
                renameHeaderButton.contentTintColor = btnTint
                downloadButton.contentTintColor = btnTint
                moreMenuButton.contentTintColor = btnTint

                bottomBar.layer?.backgroundColor = isDark ? NSColor(white: 1.0, alpha: 0.12).cgColor : NSColor(white: 0.0, alpha: 0.04).cgColor
                bottomBar.layer?.borderColor = isDark ? NSColor(white: 1.0, alpha: 0.18).cgColor : NSColor(white: 0.0, alpha: 0.12).cgColor
                bottomBar.layer?.borderWidth = 1.0

                tableContainer.layer?.backgroundColor = isDark ? NSColor(white: 1.0, alpha: 0.05).cgColor : NSColor(white: 0.0, alpha: 0.02).cgColor
                tableContainer.layer?.borderColor = isDark ? NSColor(white: 1.0, alpha: 0.18).cgColor : NSColor(white: 0.0, alpha: 0.12).cgColor

                let selectorColor = isDark ? NSColor.white : NSColor.lightThemeSelector
                bottomNewPlaylistButton.contentTintColor = selectorColor
                bottomAddCurrentTrackButton.contentTintColor = selectorColor
                bottomImportButton.contentTintColor = selectorColor
            }
            searchField.applyTheme(design)
        }
        tableView.reloadData()
    }

    public func refresh() {
        reload()
    }

    public func openPlaylist(id: String) {
        let playlists = PlaylistManager.shared.fetchPlaylists()
        if let pl = playlists.first(where: { $0.id == id }) {
            self.mode = .detail(pl)
        } else {
            self.mode = .list
        }
    }

    public func openPlaylists() {
        librarySegmentedControl.selectedSegment = 0
        self.mode = .list
    }

    public func openLikedSongs() {
        librarySegmentedControl.selectedSegment = 1
        self.mode = .likedSongs
        if PlaylistSyncManager.shared.isSignedIn, !PlaylistSyncManager.shared.isSyncInProgress {
            PlaylistSyncManager.shared.syncNow()
        }
    }

    public func openDownloads() {
        librarySegmentedControl.selectedSegment = 2
        self.mode = .downloads
    }

    public func openHistory() {
        librarySegmentedControl.selectedSegment = 3
        self.mode = .history
    }

    @objc private func handleSegmentChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            self.mode = .list
        case 1:
            self.mode = .likedSongs
            if PlaylistSyncManager.shared.isSignedIn, !PlaylistSyncManager.shared.isSyncInProgress {
                PlaylistSyncManager.shared.syncNow()
            }
        case 2:
            self.mode = .downloads
        case 3:
            self.mode = .history
        default:
            break
        }
    }

    func reload() {
        switch mode {
        case .list:
            allPlaylists = PlaylistManager.shared.fetchPlaylists()
            applyFilter()

            librarySegmentedControl.selectedSegment = 0
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true

            searchField.placeholderString = "Search playlists..."
            saveQueueButton.isHidden = false
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = true
            renameHeaderButton.isHidden = true
            downloadButton.isHidden = true
            moreMenuButton.isHidden = true
            headerTitleLabel.toolTip = nil

            bottomBar.isHidden = false
            bottomNewPlaylistButton.isHidden = false
            bottomAddCurrentTrackButton.isHidden = true
            bottomImportButton.isHidden = true

            emptyStateIcon.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Empty")
            emptyStateLabel.stringValue = "No playlists yet"
            emptyStateSubLabel.stringValue = "Click '＋ New Playlist' below to create your first playlist"
            emptyStateView.isHidden = !filteredPlaylists.isEmpty

        case .detail(let playlist):
            allPlaylistItems = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
            applyFilter()

            librarySegmentedControl.isHidden = true
            backButton.isHidden = false
            titleStack.isHidden = false

            headerTitleLabel.stringValue = playlist.name.uppercased()
            headerTitleLabel.toolTip = "Click to rename \"\(playlist.name)\""
            let summary = PlaylistManager.shared.summaryForPlaylist(playlist)
            if !summary.durationText.isEmpty {
                headerSubtitleLabel.stringValue = "\(summary.countText) • \(summary.durationText)"
            } else {
                headerSubtitleLabel.stringValue = summary.countText
            }
            headerSubtitleLabel.isHidden = false

            searchField.placeholderString = "Search tracks in \(playlist.name)..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = false
            renameHeaderButton.isHidden = false
            downloadButton.isHidden = allPlaylistItems.isEmpty
            moreMenuButton.isHidden = false

            bottomBar.isHidden = false
            bottomNewPlaylistButton.isHidden = true
            bottomAddCurrentTrackButton.isHidden = false
            bottomImportButton.isHidden = true

            emptyStateIcon.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Empty")
            emptyStateLabel.stringValue = "Empty playlist"
            emptyStateSubLabel.stringValue = "Click '＋ Add Currently Playing Track' to add songs"
            emptyStateView.isHidden = !filteredPlaylistItems.isEmpty

        case .likedSongs:
            var liked = LikedSongsManager.shared.fetchLikedSongs()
            if let savedOrder = UserDefaults.standard.stringArray(forKey: "MooziacLikedSongsCustomOrder"), !savedOrder.isEmpty {
                var rank: [String: Int] = [:]
                for (i, k) in savedOrder.enumerated() { rank[k] = i }
                let ordered = liked.filter { rank[$0.videoId] != nil }.sorted { (rank[$0.videoId] ?? 0) < (rank[$1.videoId] ?? 0) }
                let rest = liked.filter { rank[$0.videoId] == nil }
                liked = ordered + rest
            }
            allLikedSongs = liked
            applyFilter()

            librarySegmentedControl.selectedSegment = 1
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true
            headerTitleLabel.toolTip = nil

            searchField.placeholderString = "Search liked songs..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = true
            renameHeaderButton.isHidden = true
            downloadButton.isHidden = true
            moreMenuButton.isHidden = true

            bottomBar.isHidden = true
            bottomNewPlaylistButton.isHidden = true
            bottomAddCurrentTrackButton.isHidden = true
            bottomImportButton.isHidden = true

            emptyStateIcon.image = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Liked Songs")
            emptyStateLabel.stringValue = "No liked songs yet"
            emptyStateSubLabel.stringValue = "Click the ♥ icon on any song to save it here"
            emptyStateView.isHidden = !filteredLikedSongs.isEmpty

        case .downloads:
            var tracks = LocalLibraryManager.shared.allTracks
            if let savedOrder = UserDefaults.standard.stringArray(forKey: "MooziacDownloadsCustomOrder"), !savedOrder.isEmpty {
                var rank: [String: Int] = [:]
                for (i, k) in savedOrder.enumerated() { rank[k] = i }
                let ordered = tracks.filter { rank[$0.id] != nil }.sorted { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
                let rest = tracks.filter { rank[$0.id] == nil }
                tracks = ordered + rest
            }
            allDownloads = tracks
            applyFilter()

            librarySegmentedControl.selectedSegment = 2
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true
            headerTitleLabel.toolTip = nil

            searchField.placeholderString = "Search downloaded tracks..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = false
            openFolderHeaderButton.isHidden = false
            downloadCurrentHeaderButton.isHidden = false
            addCurrentTrackButton.isHidden = true
            renameHeaderButton.isHidden = true
            downloadButton.isHidden = true
            moreMenuButton.isHidden = true

            bottomBar.isHidden = false
            bottomNewPlaylistButton.isHidden = true
            bottomAddCurrentTrackButton.isHidden = true
            bottomImportButton.isHidden = false

            emptyStateIcon.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Empty")
            emptyStateLabel.stringValue = "No downloaded tracks yet"
            emptyStateSubLabel.stringValue = "Click '＋ Import Music Files' below or drag & drop audio files here"
            emptyStateView.isHidden = !filteredDownloads.isEmpty

        case .history:
            loadInitialHistory()

            librarySegmentedControl.selectedSegment = 3
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true
            headerTitleLabel.toolTip = nil

            searchField.placeholderString = "Search listening history..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = true
            renameHeaderButton.isHidden = true
            downloadButton.isHidden = true
            moreMenuButton.isHidden = false

            bottomBar.isHidden = true
            bottomNewPlaylistButton.isHidden = true
            bottomAddCurrentTrackButton.isHidden = true
            bottomImportButton.isHidden = true

            emptyStateIcon.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Empty")
            emptyStateLabel.stringValue = "No listening history yet"
            emptyStateSubLabel.stringValue = "Songs you listen to will appear here automatically"
            emptyStateView.isHidden = !filteredHistoryItems.isEmpty
        }
        tableView.reloadData()
        if numberOfRows(in: tableView) > 0 {
            tableView.scrollRowToVisible(0)
        }
        scrollView.contentView.scroll(to: .zero)
    }

    func applyFilter() {
        let query = currentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch mode {
        case .list:
            if query.isEmpty {
                filteredPlaylists = allPlaylists
            } else {
                filteredPlaylists = allPlaylists.filter { $0.name.lowercased().contains(query) }
            }
        case .detail:
            if query.isEmpty {
                filteredPlaylistItems = allPlaylistItems
            } else {
                filteredPlaylistItems = allPlaylistItems.filter {
                    $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query)
                }
            }
        case .likedSongs:
            if query.isEmpty {
                filteredLikedSongs = allLikedSongs
            } else {
                filteredLikedSongs = allLikedSongs.filter {
                    $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query) || $0.album.lowercased().contains(query)
                }
            }
        case .downloads:
            if query.isEmpty {
                filteredDownloads = allDownloads
            } else {
                filteredDownloads = allDownloads.filter {
                    $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query) || $0.album.lowercased().contains(query)
                }
            }
        case .history:
            if query.isEmpty {
                filteredHistoryItems = allHistoryItems
            } else {
                filteredHistoryItems = allHistoryItems.filter {
                    $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func handleBackTapped() {
        switch mode {
        case .list, .likedSongs, .downloads, .history:
            delegate?.playlistLibraryDidRequestClose()
        case .detail:
            openPlaylists()
        }
    }

    @objc private func handleImportTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .mp3]
        panel.prompt = "Import Music"

        panel.begin { [weak self] response in
            if response == .OK {
                LocalLibraryManager.shared.importFiles(from: panel.urls) { _ in
                    self?.reload()
                }
            }
        }
    }

    @objc private func handleOpenFolderTapped() {
        LocalLibraryManager.shared.openMusicFolderInFinder()
    }

    @objc private func handleDownloadCurrentTapped() {
        let state = NowPlayingManager.shared.currentState
        guard !state.title.isEmpty && state.title != "Not Playing" else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ Play a song online first to download it")
            return
        }

        let targetUrl = state.pageUrl.isEmpty ? state.videoId : state.pageUrl
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⬇ Queued download: \(state.title)")
        DownloadManager.shared.downloadTrack(
            urlOrVideoId: targetUrl,
            title: state.title,
            artist: state.artist,
            artworkUrl: state.artworkUrl
        ) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.reload()
                }
            }
        }
    }

    @objc private func handleNewPlaylistTapped() {
        promptForName(title: "New Playlist", defaultName: "My Playlist", actionTitle: "Create") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                if let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == newID }) {
                    self.mode = .detail(playlist)
                    return
                }
            }
            self.reload()
        }
    }

    @objc private func handleAddCurrentTrackToDetailPlaylist() {
        guard case .detail(let playlist) = mode else { return }
        let res = PlaylistManager.shared.appendCurrentPlayingTrack(to: playlist.id)
        if res.success {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added to \(playlist.name)")
            reload()
        } else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: res.message)
        }
    }

    @objc private func handleSaveQueueTapped() {
        let nowPlaying = NowPlayingManager.shared.currentState
        let defaultName = nowPlaying.title.isEmpty || nowPlaying.title == "Not Playing"
            ? "Queue Playlist"
            : "\(nowPlaying.title) Radio"

        promptForName(title: "Save Current Queue as Playlist", defaultName: defaultName, actionTitle: "Save") { [weak self] name in
            PlaylistManager.shared.createPlaylistFromCurrentQueue(name: name) { playlistID, _ in
                DispatchQueue.main.async {
                    self?.mode = .list
                    if let id = playlistID, let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) {
                        self?.mode = .detail(playlist)
                    }
                }
            }
        }
    }

    @objc private func handleDownloadAllTapped() {
        guard case .detail(let playlist) = mode else { return }
        let plan = PlaylistManager.shared.planDownloads(for: playlist.id)
        guard !plan.toDownload.isEmpty else {
            if plan.offlineBlocked > 0 {
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ You're offline — go online to download \(plan.offlineBlocked) track(s)")
            } else {
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ All tracks are downloaded")
            }
            return
        }
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⬇ Queued \(plan.toDownload.count) tracks from \(playlist.name)")
        let queueTuples = plan.toDownload.map { item -> (id: String, urlOrVideoId: String, title: String, artist: String, artworkUrl: String) in
            let vid = item.ytVideoId ?? item.refID
            return (id: item.id, urlOrVideoId: vid, title: item.title, artist: item.artist, artworkUrl: item.artworkUrl)
        }
        DownloadManager.shared.queueTracks(queueTuples)
    }

    @objc private func handleMoreMenuTapped(_ sender: NSButton) {
        if case .history = mode {
            let menu = NSMenu(title: "History Options")
            let clearItem = NSMenuItem(title: "Clear Listening History…", action: #selector(handleClearHistoryPrompt), keyEquivalent: "")
            clearItem.target = self
            let trashConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            clearItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear")?.withSymbolConfiguration(trashConfig)
            menu.addItem(clearItem)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
            return
        }

        guard case .detail = mode else { return }
        let menu = NSMenu(title: "Playlist Options")
        
        let renameItem = NSMenuItem(title: "Rename Playlist...", action: #selector(handleRenameCurrentPlaylist), keyEquivalent: "r")
        renameItem.target = self
        menu.addItem(renameItem)

        let addCurrentItem = NSMenuItem(title: "Add Currently Playing Track", action: #selector(handleAddCurrentTrackToDetailPlaylist), keyEquivalent: "a")
        addCurrentItem.target = self
        menu.addItem(addCurrentItem)

        let downloadItem = NSMenuItem(title: "Download All Tracks", action: #selector(handleDownloadAllTapped), keyEquivalent: "d")
        downloadItem.target = self
        menu.addItem(downloadItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Delete Playlist", action: #selector(handleDeleteCurrentPlaylist), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func handleClearHistoryPrompt() {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Clear Listening History?"
        alert.informativeText = "Are you sure you want to clear your listening history? This action cannot be undone."
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Clear History")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearHistory()
            reload()
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "🗑 History Cleared")
        }
    }

    @objc private func handleRenameCurrentPlaylist() {
        guard case .detail(let playlist) = mode else { return }
        promptForName(title: "Rename Playlist", defaultName: playlist.name, actionTitle: "Rename") { [weak self] name in
            guard let self = self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if trimmed != playlist.name {
                PlaylistManager.shared.renamePlaylist(id: playlist.id, name: trimmed)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Renamed to \"\(trimmed)\"")
            }
            if let updated = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlist.id }) {
                self.mode = .detail(updated)
            } else {
                self.reload()
            }
        }
    }

    @objc private func handleDeleteCurrentPlaylist() {
        guard case .detail(let playlist) = mode else { return }
        confirmAndDeletePlaylist(playlist)
    }

    @objc private func handleDoubleAction() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 else { return }

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return }
            let playlist = filteredPlaylists[row]
            mode = .detail(playlist)
        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return }
            playPlaylist(playlistID: playlist.id, startingAt: filteredPlaylistItems[row].id)
        case .likedSongs:
            guard row < filteredLikedSongs.count else { return }
            let record = filteredLikedSongs[row]
            playLikedSongRecord(record)
        case .downloads:
            guard row < filteredDownloads.count else { return }
            playDownloadedTrack(filteredDownloads[row])
        case .history:
            guard row < filteredHistoryItems.count else { return }
            HistoryManager.shared.playHistoryItem(filteredHistoryItems[row])
        }
    }

    private func handleReturnAction() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return }
            let playlist = filteredPlaylists[row]
            mode = .detail(playlist)
        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return }
            playPlaylist(playlistID: playlist.id, startingAt: filteredPlaylistItems[row].id)
        case .likedSongs:
            guard row < filteredLikedSongs.count else { return }
            let record = filteredLikedSongs[row]
            playLikedSongRecord(record)
        case .downloads:
            guard row < filteredDownloads.count else { return }
            playDownloadedTrack(filteredDownloads[row])
        case .history:
            guard row < filteredHistoryItems.count else { return }
            HistoryManager.shared.playHistoryItem(filteredHistoryItems[row])
        }
    }

    private func handleDeleteKeyAction() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return }
            let playlist = filteredPlaylists[row]
            confirmAndDeletePlaylist(playlist)
        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return }
            let item = filteredPlaylistItems[row]
            PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
            reload()
        case .likedSongs:
            guard row < filteredLikedSongs.count else { return }
            let record = filteredLikedSongs[row]
            LikedSongsManager.shared.removeLikedSong(videoId: record.videoId)
            reload()
        case .downloads:
            guard row < filteredDownloads.count else { return }
            let track = filteredDownloads[row]
            LocalLibraryManager.shared.deleteTrack(track) { [weak self] _ in
                self?.reload()
            }
        case .history:
            guard row < filteredHistoryItems.count else { return }
            let item = filteredHistoryItems[row]
            HistoryManager.shared.deleteHistoryItem(id: item.id)
            reload()
        }
    }

    func promptForName(title: String, defaultName: String, actionTitle: String = "OK", completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = title
        alert.informativeText = "Enter a name for this playlist:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = defaultName
        textField.placeholderString = "Playlist Name"
        alert.accessoryView = textField
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: "Cancel")

        alert.window.initialFirstResponder = textField
        DispatchQueue.main.async {
            textField.selectText(nil)
        }

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name.isEmpty ? defaultName : name)
        }
    }

    func confirmAndDeletePlaylist(_ playlist: PlaylistRecord) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete \"\(playlist.name)\"?"
        alert.informativeText = "Are you sure you want to delete this playlist? This action cannot be undone."
        alert.alertStyle = .warning
        let deleteBtn = alert.addButton(withTitle: "Delete")
        deleteBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PlaylistManager.shared.deletePlaylist(id: playlist.id)
            if case .detail(let current) = mode, current.id == playlist.id {
                openPlaylists()
            } else {
                reload()
            }
        }
    }

    func playPlaylist(playlistID: String, startingAt itemID: String?) {
        PlaylistManager.shared.startPlaylist(playlistID: playlistID, startingAt: itemID, shuffle: false)
    }

    public func playLikedSongRecord(_ record: LikedSongRecord) {
        let records = filteredLikedSongs.isEmpty ? allLikedSongs : filteredLikedSongs
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: record.videoId, shuffle: false)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Playing \"\(record.title)\"")
    }

    public func playDownloadedTrack(_ track: LocalTrack) {
        let tracks = filteredDownloads.isEmpty ? allDownloads : filteredDownloads
        PlaylistManager.shared.startDownloadsPlayback(tracks: tracks, startingAt: track.id, shuffle: false)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Playing \"\(track.title)\"")
    }
}
