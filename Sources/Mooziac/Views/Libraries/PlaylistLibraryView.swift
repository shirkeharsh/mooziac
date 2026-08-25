import AppKit
import Foundation
import UniformTypeIdentifiers

protocol PlaylistLibraryViewDelegate: AnyObject {
    func playlistLibraryDidRequestClose()
    func playlistLibraryDidPlayOnline(videoId: String)
}

public class PlaylistLibraryView: NSView, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {

    weak var delegate: PlaylistLibraryViewDelegate?

    private static let dragType = NSPasteboard.PasteboardType("com.mooziac.playlist.reorder")

    public enum Tab: Int {
        case playlists = 0
        case likedSongs = 1
        case downloads = 2
        case history = 3
    }

    private enum Mode {
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
    private let downloadButton = ReactiveIconButton()
    private let moreMenuButton = ReactiveIconButton()
    private var actionStack = NSStackView()

    private let searchField = GlassSearchField()

    private let scrollView = NSScrollView()
    private let tableView = PlaylistTableView()
    private let tableContainer = NSView()

    // Bottom Action Bar
    private let bottomBar = NSView()
    private let bottomNewPlaylistButton = NSButton()
    private let bottomAddCurrentTrackButton = NSButton()
    private let bottomImportButton = NSButton()

    private let emptyStateView = NSView()
    private let emptyStateIcon = NSImageView()
    private let emptyStateLabel = NSTextField(labelWithString: "No playlists yet")
    private let emptyStateSubLabel = NSTextField(labelWithString: "Click '＋ New Playlist' below to create your first playlist")

    private var mode: Mode = .list {
        didSet {
            currentSearchQuery = ""
            searchField.stringValue = ""
            reload()
        }
    }

    private var allPlaylists: [PlaylistRecord] = []
    private var filteredPlaylists: [PlaylistRecord] = []

    private var allLikedSongs: [LikedSongRecord] = []
    private var filteredLikedSongs: [LikedSongRecord] = []

    private var allPlaylistItems: [PlaylistItemRecord] = []
    private var filteredPlaylistItems: [PlaylistItemRecord] = []

    private var allDownloads: [LocalTrack] = []
    private var filteredDownloads: [LocalTrack] = []

    private var allHistoryItems: [HistoryRecord] = []
    private var filteredHistoryItems: [HistoryRecord] = []
    private var historyCurrentPage: Int = 0
    private let historyPageSize: Int = 50
    private var hasMoreHistory: Bool = true
    private var isLoadingHistory: Bool = false

    private var currentSearchQuery: String = ""
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
        topBar.addSubview(titleStack)

        setupHeaderIconButton(saveQueueButton, systemName: "square.and.arrow.down", toolTip: "Save Current Queue as Playlist", action: #selector(handleSaveQueueTapped), pointSize: 12.0)
        setupHeaderIconButton(importHeaderButton, systemName: "plus", toolTip: "Import Audio Files…", action: #selector(handleImportTapped), pointSize: 13.0)
        importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        setupHeaderIconButton(openFolderHeaderButton, systemName: "folder", toolTip: "Open ~/Music/Mooziac in Finder", action: #selector(handleOpenFolderTapped), pointSize: 12.0)
        setupHeaderIconButton(downloadCurrentHeaderButton, systemName: "arrow.down.circle", toolTip: "Download Currently Playing Song", action: #selector(handleDownloadCurrentTapped), pointSize: 12.5)

        setupHeaderIconButton(addCurrentTrackButton, systemName: "plus", toolTip: "Add Currently Playing Track to Playlist", action: #selector(handleAddCurrentTrackToDetailPlaylist), pointSize: 13.0)
        addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

        setupHeaderIconButton(downloadButton, systemName: "arrow.down", toolTip: "Download Online Tracks", action: #selector(handleDownloadAllTapped), pointSize: 12.0)
        setupHeaderIconButton(moreMenuButton, systemName: "ellipsis", toolTip: "Options", action: #selector(handleMoreMenuTapped(_:)), pointSize: 12.5)

        actionStack = NSStackView(views: [importHeaderButton, downloadCurrentHeaderButton, openFolderHeaderButton, downloadButton, addCurrentTrackButton, saveQueueButton, moreMenuButton])
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
        NotificationCenter.default.addObserver(forName: NSNotification.Name("Mooziac_PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.reloadVisiblePlayingStates()
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
            allDownloads = LocalLibraryManager.shared.allTracks
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
            case .adaptive, .native:
                layer?.backgroundColor = DynamicIslandPlayerView.sharedAmbientBgColor ?? NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.98).cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
                headerTitleLabel.textColor = NSColor.white
                headerSubtitleLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
                backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                saveQueueButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                openFolderHeaderButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                downloadCurrentHeaderButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                downloadButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                moreMenuButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)

                bottomBar.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.06).cgColor
                bottomBar.layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
                bottomBar.layer?.borderWidth = 1.0

                tableContainer.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.03).cgColor
                tableContainer.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor

                bottomNewPlaylistButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                bottomAddCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                bottomImportButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

            case .darkMode:
                layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 0.98).cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor
                headerTitleLabel.textColor = NSColor.white
                headerSubtitleLabel.textColor = NSColor(white: 0.60, alpha: 1.0)
                backButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                saveQueueButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                importHeaderButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
                openFolderHeaderButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                downloadCurrentHeaderButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                addCurrentTrackButton.contentTintColor = NSColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0)
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
                layer?.backgroundColor = NSColor(red: 0.93725, green: 0.94902, blue: 0.94118, alpha: 0.98).cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(red: 0.80, green: 0.82, blue: 0.81, alpha: 0.85).cgColor
                let pitchBlack = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
                headerTitleLabel.textColor = pitchBlack
                headerSubtitleLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
                backButton.contentTintColor = pitchBlack
                saveQueueButton.contentTintColor = pitchBlack
                importHeaderButton.contentTintColor = NSColor.lightThemeSelector
                openFolderHeaderButton.contentTintColor = pitchBlack
                downloadCurrentHeaderButton.contentTintColor = pitchBlack
                addCurrentTrackButton.contentTintColor = NSColor.lightThemeSelector
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
        case 2:
            self.mode = .downloads
        case 3:
            self.mode = .history
        default:
            break
        }
    }

    private func reload() {
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
            downloadButton.isHidden = true
            moreMenuButton.isHidden = true

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
            allLikedSongs = LikedSongsManager.shared.fetchLikedSongs()
            applyFilter()

            librarySegmentedControl.selectedSegment = 1
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true

            searchField.placeholderString = "Search liked songs..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = true
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
            allDownloads = LocalLibraryManager.shared.allTracks
            applyFilter()

            librarySegmentedControl.selectedSegment = 2
            librarySegmentedControl.isHidden = false
            backButton.isHidden = true
            titleStack.isHidden = true

            searchField.placeholderString = "Search downloaded tracks..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = false
            openFolderHeaderButton.isHidden = false
            downloadCurrentHeaderButton.isHidden = false
            addCurrentTrackButton.isHidden = true
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

            searchField.placeholderString = "Search listening history..."
            saveQueueButton.isHidden = true
            importHeaderButton.isHidden = true
            openFolderHeaderButton.isHidden = true
            downloadCurrentHeaderButton.isHidden = true
            addCurrentTrackButton.isHidden = true
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

    private func applyFilter() {
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
            PlaylistManager.shared.renamePlaylist(id: playlist.id, name: name)
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
            NowPlayingManager.shared.playOfflineTrack(filteredDownloads[row], in: filteredDownloads)
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
            NowPlayingManager.shared.playOfflineTrack(filteredDownloads[row], in: filteredDownloads)
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
            confirmAndDeletePlaylist(filteredPlaylists[row])
        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return }
            let item = filteredPlaylistItems[row]
            PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
            reload()
        case .likedSongs:
            guard row < filteredLikedSongs.count else { return }
            let record = filteredLikedSongs[row]
            LocalDatabaseManager.shared.removeLikedSong(videoId: record.videoId)
            NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
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

    private func promptForName(title: String, defaultName: String, actionTitle: String = "OK", completion: @escaping (String) -> Void) {
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

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name.isEmpty ? "My Playlist" : name)
        }
    }

    private func confirmAndDeletePlaylist(_ playlist: PlaylistRecord) {
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

    private func playPlaylist(playlistID: String, startingAt itemID: String?) {
        PlaylistManager.shared.startPlaylist(playlistID: playlistID, startingAt: itemID, shuffle: false)
    }

    public func playLikedSongRecord(_ record: LikedSongRecord) {
        let records = filteredLikedSongs.isEmpty ? allLikedSongs : filteredLikedSongs
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: record.videoId, shuffle: false)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "▶ Playing \"\(record.title)\"")
    }

    // MARK: - Context Menu

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        guard row >= 0 else { return super.menu(for: event) }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        let menu = NSMenu(title: "Context Menu")

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return nil }
            let playlist = filteredPlaylists[row]

            let openItem = NSMenuItem(title: "Open Playlist", action: #selector(handleContextOpenPlaylist(_:)), keyEquivalent: "")
            openItem.target = self
            openItem.representedObject = playlist
            menu.addItem(openItem)

            let addCurrentItem = NSMenuItem(title: "Add Current Track", action: #selector(handleContextAddCurrentFromList(_:)), keyEquivalent: "")
            addCurrentItem.target = self
            addCurrentItem.representedObject = playlist
            menu.addItem(addCurrentItem)

            menu.addItem(NSMenuItem.separator())

            let renameItem = NSMenuItem(title: "Rename Playlist…", action: #selector(handleContextRename(_:)), keyEquivalent: "")
            renameItem.target = self
            renameItem.representedObject = playlist
            menu.addItem(renameItem)

            let deleteItem = NSMenuItem(title: "Delete Playlist", action: #selector(handleContextDeletePlaylist(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = playlist
            menu.addItem(deleteItem)

        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return nil }
            let item = filteredPlaylistItems[row]

            let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayItem(_:)), keyEquivalent: "")
            playItem.target = self
            playItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
            menu.addItem(playItem)

            let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextItem(_:)), keyEquivalent: "")
            playNextItem.target = self
            playNextItem.representedObject = item
            menu.addItem(playNextItem)

            let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueItem(_:)), keyEquivalent: "")
            queueItem.target = self
            queueItem.representedObject = item
            menu.addItem(queueItem)

            let otherPlaylists = PlaylistManager.shared.fetchPlaylists().filter { $0.id != playlist.id }
            let addToPlaylistItem = NSMenuItem(title: "Copy to Playlist", action: nil, keyEquivalent: "")
            let playlistSubmenu = NSMenu(title: "Playlists")
            for pl in otherPlaylists {
                let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextCopyDetailItemToPlaylist(_:)), keyEquivalent: "")
                subItem.target = self
                subItem.representedObject = ["item": item, "playlistID": pl.id]
                playlistSubmenu.addItem(subItem)
            }
            if !otherPlaylists.isEmpty {
                playlistSubmenu.addItem(NSMenuItem.separator())
            }
            let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithDetailItem(_:)), keyEquivalent: "")
            newPLItem.target = self
            newPLItem.representedObject = item
            playlistSubmenu.addItem(newPLItem)
            addToPlaylistItem.submenu = playlistSubmenu
            menu.addItem(addToPlaylistItem)

            let resolution = PlaylistManager.shared.resolve(item)
            if case .online = resolution {
                let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadItem(_:)), keyEquivalent: "")
                dlItem.target = self
                dlItem.representedObject = item
                menu.addItem(dlItem)
            }

            menu.addItem(NSMenuItem.separator())

            let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpItem(_:)), keyEquivalent: "")
            moveUpItem.target = self
            moveUpItem.representedObject = ["index": row, "playlistID": playlist.id]
            moveUpItem.isEnabled = row > 0
            menu.addItem(moveUpItem)

            let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownItem(_:)), keyEquivalent: "")
            moveDownItem.target = self
            moveDownItem.representedObject = ["index": row, "playlistID": playlist.id]
            moveDownItem.isEnabled = row < filteredPlaylistItems.count - 1
            menu.addItem(moveDownItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "Remove from Playlist", action: #selector(handleContextRemoveItem(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
            menu.addItem(deleteItem)

        case .likedSongs:
            guard row < filteredLikedSongs.count else { return nil }
            let record = filteredLikedSongs[row]

            let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayLikedSongItem(_:)), keyEquivalent: "")
            playItem.target = self
            playItem.representedObject = record
            menu.addItem(playItem)

            let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextLikedSongItem(_:)), keyEquivalent: "")
            playNextItem.target = self
            playNextItem.representedObject = record
            menu.addItem(playNextItem)

            let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueLikedSongItem(_:)), keyEquivalent: "")
            queueItem.target = self
            queueItem.representedObject = record
            menu.addItem(queueItem)

            let playlists = PlaylistManager.shared.fetchPlaylists()
            let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
            let playlistSubmenu = NSMenu(title: "Playlists")
            for pl in playlists {
                let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddLikedSongToPlaylist(_:)), keyEquivalent: "")
                subItem.target = self
                subItem.representedObject = ["record": record, "playlistID": pl.id]
                playlistSubmenu.addItem(subItem)
            }
            if !playlists.isEmpty {
                playlistSubmenu.addItem(NSMenuItem.separator())
            }
            let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithLikedSong(_:)), keyEquivalent: "")
            newPLItem.target = self
            newPLItem.representedObject = record
            playlistSubmenu.addItem(newPLItem)
            addToPlaylistItem.submenu = playlistSubmenu
            menu.addItem(addToPlaylistItem)

            let isDownloaded = LocalLibraryManager.shared.allTracks.contains(where: {
                if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
                return $0.fileURL.path == record.videoId
            })

            if !isDownloaded && !record.videoId.isEmpty {
                let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadLikedSongItem(_:)), keyEquivalent: "")
                dlItem.target = self
                dlItem.representedObject = record
                menu.addItem(dlItem)
            }

            if isDownloaded, let localTrack = LocalLibraryManager.shared.allTracks.first(where: {
                if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
                return $0.fileURL.path == record.videoId
            }) {
                let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleContextShowDownloadInFinder(_:)), keyEquivalent: "")
                finderItem.target = self
                finderItem.representedObject = localTrack
                menu.addItem(finderItem)
            }

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "Remove from Liked Songs", action: #selector(handleContextDeleteLikedSongItem(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = record
            menu.addItem(deleteItem)

        case .downloads:
            guard row < filteredDownloads.count else { return nil }
            let track = filteredDownloads[row]

            let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayDownloadItem(_:)), keyEquivalent: "")
            playItem.target = self
            playItem.representedObject = track
            menu.addItem(playItem)

            let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextDownloadItem(_:)), keyEquivalent: "")
            playNextItem.target = self
            playNextItem.representedObject = track
            menu.addItem(playNextItem)

            let playlists = PlaylistManager.shared.fetchPlaylists()
            let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
            let playlistSubmenu = NSMenu(title: "Playlists")
            for pl in playlists {
                let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddDownloadToPlaylist(_:)), keyEquivalent: "")
                subItem.target = self
                subItem.representedObject = ["track": track, "playlistID": pl.id]
                playlistSubmenu.addItem(subItem)
            }
            if !playlists.isEmpty {
                playlistSubmenu.addItem(NSMenuItem.separator())
            }
            let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithDownload(_:)), keyEquivalent: "")
            newPLItem.target = self
            newPLItem.representedObject = track
            playlistSubmenu.addItem(newPLItem)
            addToPlaylistItem.submenu = playlistSubmenu
            menu.addItem(addToPlaylistItem)

            let isLiked = track.isLiked
            let likeItem = NSMenuItem(title: isLiked ? "Unlike Track" : "Like Track", action: #selector(handleContextToggleLikeDownloadItem(_:)), keyEquivalent: "")
            likeItem.target = self
            likeItem.representedObject = track
            menu.addItem(likeItem)

            let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleContextShowDownloadInFinder(_:)), keyEquivalent: "")
            finderItem.target = self
            finderItem.representedObject = track
            menu.addItem(finderItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "Delete Download", action: #selector(handleContextDeleteDownloadItem(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = track
            menu.addItem(deleteItem)

        case .history:
            guard row < filteredHistoryItems.count else { return nil }
            let item = filteredHistoryItems[row]

            let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayHistoryItem(_:)), keyEquivalent: "")
            playItem.target = self
            playItem.representedObject = item
            menu.addItem(playItem)

            let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextHistoryItem(_:)), keyEquivalent: "")
            playNextItem.target = self
            playNextItem.representedObject = item
            menu.addItem(playNextItem)

            let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueHistoryItem(_:)), keyEquivalent: "")
            queueItem.target = self
            queueItem.representedObject = item
            menu.addItem(queueItem)

            let playlists = PlaylistManager.shared.fetchPlaylists()
            let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
            let playlistSubmenu = NSMenu(title: "Playlists")
            for pl in playlists {
                let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddHistoryToPlaylist(_:)), keyEquivalent: "")
                subItem.target = self
                subItem.representedObject = ["historyItem": item, "playlistID": pl.id]
                playlistSubmenu.addItem(subItem)
            }
            if !playlists.isEmpty {
                playlistSubmenu.addItem(NSMenuItem.separator())
            }
            let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithHistory(_:)), keyEquivalent: "")
            newPLItem.target = self
            newPLItem.representedObject = item
            playlistSubmenu.addItem(newPLItem)
            addToPlaylistItem.submenu = playlistSubmenu
            menu.addItem(addToPlaylistItem)

            if item.sourceType == "online", let vid = item.ytVideoId, !vid.isEmpty {
                let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadHistoryItem(_:)), keyEquivalent: "")
                dlItem.target = self
                dlItem.representedObject = item
                menu.addItem(dlItem)
            }

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "Remove from History", action: #selector(handleContextDeleteHistoryItem(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = item
            menu.addItem(deleteItem)
        }

        return menu
    }

    @objc private func handleContextOpenPlaylist(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        self.mode = .detail(playlist)
    }

    @objc private func handleContextAddCurrentFromList(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        let res = PlaylistManager.shared.appendCurrentPlayingTrack(to: playlist.id)
        if res.success {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added to \(playlist.name)")
            reload()
        } else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: res.message)
        }
    }

    @objc private func handleContextRename(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        promptForName(title: "Rename Playlist", defaultName: playlist.name, actionTitle: "Rename") { [weak self] name in
            PlaylistManager.shared.renamePlaylist(id: playlist.id, name: name)
            self?.reload()
        }
    }

    @objc private func handleContextDeletePlaylist(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        confirmAndDeletePlaylist(playlist)
    }

    @objc private func handleContextPlayItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let itemID = dict["itemID"],
              let playlistID = dict["playlistID"] else { return }
        playPlaylist(playlistID: playlistID, startingAt: itemID)
    }

    @objc private func handleContextPlayNextItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.playNext(item: item)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(item.title)")
    }

    @objc private func handleContextAddToQueueItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.addToQueue(item: item)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "➕ Added to Queue: \(item.title)")
    }

    @objc private func handleContextDownloadItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        let vid = item.ytVideoId ?? item.refID
        DownloadManager.shared.queueTrack(
            id: item.id,
            urlOrVideoId: vid,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl
        ) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.reload()
                }
            }
        }
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⬇ Queued download: \(item.title)")
    }

    @objc private func handleContextMoveUpItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let idx = dict["index"] as? Int,
              let playlistID = dict["playlistID"] as? String,
              idx > 0, idx < allPlaylistItems.count else { return }
        allPlaylistItems.swapAt(idx, idx - 1)
        PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: allPlaylistItems.map { $0.id })
        reload()
    }

    @objc private func handleContextMoveDownItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let idx = dict["index"] as? Int,
              let playlistID = dict["playlistID"] as? String,
              idx >= 0, idx < allPlaylistItems.count - 1 else { return }
        allPlaylistItems.swapAt(idx, idx + 1)
        PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: allPlaylistItems.map { $0.id })
        reload()
    }

    @objc private func handleContextRemoveItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let itemID = dict["itemID"],
              let playlistID = dict["playlistID"] else { return }
        PlaylistManager.shared.removeItem(itemID: itemID, from: playlistID)
        reload()
    }

    @objc private func handleContextPlayDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NowPlayingManager.shared.playOfflineTrack(track, in: filteredDownloads)
    }

    @objc private func handleContextPlayNextDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.playNext(track: track)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(track.title)")
    }

    @objc private func handleContextAddDownloadToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let track = dict["track"] as? LocalTrack,
              let playlistID = dict["playlistID"] as? String else { return }

        let mins = Int(track.duration) / 60
        let secs = Int(track.duration) % 60
        let durStr = track.duration > 0 ? String(format: "%d:%02d", mins, secs) : "--:--"

        let item = PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: 0,
            refType: "local",
            refID: track.fileURL.path,
            ytVideoId: track.ytVideoId,
            title: track.title,
            artist: track.artist,
            artworkUrl: track.fileURL.path,
            duration: durStr,
            isLiked: false
        )
        PlaylistManager.shared.appendPlaylistItem(item, to: playlistID)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added \"\(track.title)\" to \(plName)")
    }

    @objc private func handleContextShowDownloadInFinder(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        if FileManager.default.fileExists(atPath: track.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
        } else {
            LocalLibraryManager.shared.openMusicFolderInFinder()
        }
    }

    @objc private func handleContextDeleteDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete \"\(track.title)\"?"
        alert.informativeText = "This will remove the downloaded audio file and lyrics from Mooziac."
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Delete")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            LocalLibraryManager.shared.deleteTrack(track) { [weak self] _ in
                self?.reload()
            }
        }
    }

    @objc private func handleContextPlayHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        HistoryManager.shared.playHistoryItem(item)
    }

    @objc private func handleContextPlayNextHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: item.sourceType == "local" ? "local" : "online",
            refID: item.sourceType == "local" ? (item.filePath ?? item.id) : (item.ytVideoId ?? item.id),
            ytVideoId: item.ytVideoId,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl,
            duration: "",
            isLiked: false
        )
        PlaylistManager.shared.playNext(item: fakeItem)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(item.title)")
    }

    @objc private func handleContextAddToQueueHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: item.sourceType == "local" ? "local" : "online",
            refID: item.sourceType == "local" ? (item.filePath ?? item.id) : (item.ytVideoId ?? item.id),
            ytVideoId: item.ytVideoId,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl,
            duration: "",
            isLiked: false
        )
        PlaylistManager.shared.addToQueue(item: fakeItem)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "➕ Added to Queue: \(item.title)")
    }

    @objc private func handleContextAddHistoryToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let item = dict["historyItem"] as? HistoryRecord,
              let playlistID = dict["playlistID"] as? String else { return }
        
        let playlistItem = PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: 0,
            refType: item.sourceType == "local" ? "local" : "online",
            refID: item.sourceType == "local" ? (item.filePath ?? item.id) : (item.ytVideoId ?? item.id),
            ytVideoId: item.ytVideoId,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl,
            duration: "",
            isLiked: false
        )
        PlaylistManager.shared.appendPlaylistItem(playlistItem, to: playlistID)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added \"\(item.title)\" to \(plName)")
    }

    @objc private func handleContextDownloadHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord,
              let vid = item.ytVideoId, !vid.isEmpty else { return }
        DownloadManager.shared.queueTrack(
            id: item.id,
            urlOrVideoId: vid,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl
        ) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.reload()
                }
            }
        }
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⬇ Queued download: \(item.title)")
    }

    @objc private func handleContextDeleteHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        HistoryManager.shared.deleteHistoryItem(id: item.id)
        reload()
    }

    @objc private func handleContextCopyDetailItemToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let item = dict["item"] as? PlaylistItemRecord,
              let playlistID = dict["playlistID"] as? String else { return }
        
        let newItem = PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: 0,
            refType: item.refType,
            refID: item.refID,
            ytVideoId: item.ytVideoId,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl,
            duration: item.duration,
            isLiked: item.isLiked
        )
        PlaylistManager.shared.appendPlaylistItem(newItem, to: playlistID)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added \"\(item.title)\" to \(plName)")
    }

    @objc private func handleContextPlayLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        playLikedSongRecord(record)
    }

    @objc private func handleContextPlayNextLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: "yt",
            refID: record.videoId,
            ytVideoId: record.videoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl,
            duration: "",
            isLiked: true
        )
        PlaylistManager.shared.playNext(item: fakeItem)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(record.title)")
    }

    @objc private func handleContextAddToQueueLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: "yt",
            refID: record.videoId,
            ytVideoId: record.videoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl,
            duration: "",
            isLiked: true
        )
        PlaylistManager.shared.addToQueue(item: fakeItem)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "➕ Added to Queue: \(record.title)")
    }

    @objc private func handleContextAddLikedSongToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let record = dict["record"] as? LikedSongRecord,
              let playlistID = dict["playlistID"] as? String else { return }
        
        let res = PlaylistManager.shared.appendLikedSong(to: playlistID, record: record)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        if res.success {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added \"\(record.title)\" to \(plName)")
        } else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: res.message)
        }
    }

    @objc private func handleContextNewPlaylistWithLikedSong(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        promptForName(title: "New Playlist", defaultName: "\(record.title) Playlist", actionTitle: "Create") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendLikedSong(to: newID, record: record)
                if let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == newID }) {
                    self.mode = .detail(playlist)
                    return
                }
            }
            self.reload()
        }
    }

    @objc private func handleContextNewPlaylistWithDownload(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        promptForName(title: "New Playlist", defaultName: "\(track.title) Playlist", actionTitle: "Create") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendTrack(to: newID, track: track)
                if let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == newID }) {
                    self.mode = .detail(playlist)
                    return
                }
            }
            self.reload()
        }
    }

    @objc private func handleContextNewPlaylistWithHistory(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        promptForName(title: "New Playlist", defaultName: "\(item.title) Playlist", actionTitle: "Create") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendHistoryItem(to: newID, item: item)
                if let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == newID }) {
                    self.mode = .detail(playlist)
                    return
                }
            }
            self.reload()
        }
    }

    @objc private func handleContextDownloadLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord,
              !record.videoId.isEmpty else { return }
        DownloadManager.shared.downloadTrack(
            urlOrVideoId: record.videoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl
        ) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.reload()
                }
            }
        }
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⬇ Queued download: \(record.title)")
    }

    @objc private func handleContextDeleteLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        LocalDatabaseManager.shared.removeLikedSong(videoId: record.videoId)
        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "♥ Removed from Liked Songs")
        reload()
    }

    @objc private func handleContextToggleLikeDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        LocalLibraryManager.shared.toggleLike(for: track.id)
        let isLikedNow = !track.isLiked
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: isLikedNow ? "♥ Liked Track" : "Removed Like")
        reload()
    }

    // MARK: - Search Field Delegate

    public func controlTextDidChange(_ obj: Notification) {
        currentSearchQuery = searchField.stringValue
        applyFilter()
        switch mode {
        case .list:
            emptyStateView.isHidden = !filteredPlaylists.isEmpty
        case .detail:
            emptyStateView.isHidden = !filteredPlaylistItems.isEmpty
        case .likedSongs:
            emptyStateView.isHidden = !filteredLikedSongs.isEmpty
        case .downloads:
            emptyStateView.isHidden = !filteredDownloads.isEmpty
        case .history:
            emptyStateView.isHidden = !filteredHistoryItems.isEmpty
        }
        tableView.reloadData()
    }

    // MARK: - Drag & Drop Support for External Audio Files

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.types?.contains(.fileURL) == true {
            return .copy
        }
        return []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        LocalLibraryManager.shared.importFiles(from: pasteboard) { [weak self] _ in
            self?.reload()
        }
        return true
    }

    // MARK: - NSTableView DataSource & Delegate

    public func numberOfRows(in tableView: NSTableView) -> Int {
        switch mode {
        case .list: return filteredPlaylists.count
        case .detail: return filteredPlaylistItems.count
        case .likedSongs: return filteredLikedSongs.count
        case .downloads: return filteredDownloads.count
        case .history: return filteredHistoryItems.count
        }
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let design = PlayerDesign.current

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return nil }
            let playlist = filteredPlaylists[row]
            let cellID = NSUserInterfaceItemIdentifier("PlaylistRowCell")
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? PlaylistRowCellView
            if cell == nil {
                cell = PlaylistRowCellView()
                cell?.identifier = cellID
            }
            let summary = PlaylistManager.shared.summaryForPlaylist(playlist)
            cell?.configure(playlist: playlist, summary: summary, design: design)
            cell?.onRowClicked = { [weak self] in
                self?.mode = .detail(playlist)
            }
            cell?.onDelete = { [weak self] in
                self?.confirmAndDeletePlaylist(playlist)
            }
            cell?.onRightSwipePlay = { [weak self] in
                guard let self = self else { return false }
                let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
                if items.isEmpty {
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ \"\(playlist.name)\" is empty")
                    return false
                }
                self.playPlaylist(playlistID: playlist.id, startingAt: nil)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "▶ Playing \"\(playlist.name)\"")
                return true
            }
            return cell

        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return nil }
            let item = filteredPlaylistItems[row]
            let resolution = PlaylistManager.shared.resolve(item)
            let cellID = NSUserInterfaceItemIdentifier("PlaylistItemRowCell")
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? PlaylistItemRowCellView
            if cell == nil {
                cell = PlaylistItemRowCellView()
                cell?.identifier = cellID
            }
            cell?.configure(item: item, resolution: resolution, design: design, index: row)
            cell?.onRowClicked = { [weak self] in
                self?.playPlaylist(playlistID: playlist.id, startingAt: item.id)
            }
            cell?.onDelete = { [weak self] in
                PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
                self?.reload()
            }
            cell?.onOptionsTapped = { [weak self] sender in
                self?.showTrackMenu(for: item, in: playlist, from: sender, index: row)
            }
            return cell

        case .likedSongs:
            guard row < filteredLikedSongs.count else { return nil }
            let record = filteredLikedSongs[row]
            let cellID = NSUserInterfaceItemIdentifier("LikedSongRowCell")
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? LikedSongRowCellView
            if cell == nil {
                cell = LikedSongRowCellView()
                cell?.identifier = cellID
            }
            cell?.configure(record: record, design: design)
            cell?.onRowClicked = { [weak self] in
                self?.playLikedSongRecord(record)
            }
            cell?.onDelete = { [weak self] in
                LocalDatabaseManager.shared.removeLikedSong(videoId: record.videoId)
                NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
                self?.reload()
            }
            cell?.onOptionsTapped = { [weak self] sender in
                self?.showLikedSongTrackMenu(for: record, from: sender, index: row)
            }
            return cell

        case .downloads:
            guard row < filteredDownloads.count else { return nil }
            let track = filteredDownloads[row]
            let cellID = NSUserInterfaceItemIdentifier("DownloadRowCell")
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? DownloadRowCellView
            if cell == nil {
                cell = DownloadRowCellView()
                cell?.identifier = cellID
            }
            cell?.configure(track: track, design: design)
            cell?.onRowClicked = { [weak self] in
                guard let self = self else { return }
                NowPlayingManager.shared.playOfflineTrack(track, in: self.filteredDownloads)
            }
            cell?.onDelete = { [weak self] in
                LocalLibraryManager.shared.deleteTrack(track) { [weak self] _ in
                    self?.reload()
                }
            }
            cell?.onOptionsTapped = { [weak self] sender in
                self?.showDownloadTrackMenu(for: track, from: sender)
            }
            return cell

        case .history:
            guard row < filteredHistoryItems.count else { return nil }
            if row >= filteredHistoryItems.count - 10 {
                loadNextHistoryPage()
            }
            let item = filteredHistoryItems[row]
            let cellID = NSUserInterfaceItemIdentifier("HistoryRowCell")
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? HistoryRowCellView
            if cell == nil {
                cell = HistoryRowCellView()
                cell?.identifier = cellID
            }
            cell?.configure(item: item, design: design)
            cell?.onRowClicked = {
                HistoryManager.shared.playHistoryItem(item)
            }
            cell?.onDelete = { [weak self] in
                HistoryManager.shared.deleteHistoryItem(id: item.id)
                self?.reload()
            }
            cell?.onOptionsTapped = { [weak self] sender in
                self?.showHistoryTrackMenu(for: item, from: sender, index: row)
            }
            return cell
        }
    }

    public func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        guard edge == .trailing else { return [] }

        switch mode {
        case .list:
            guard row < filteredPlaylists.count else { return [] }
            let playlist = filteredPlaylists[row]
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { [weak self] _, _ in
                self?.confirmAndDeletePlaylist(playlist)
            }
            deleteAction.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0)
            deleteAction.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Delete")
            return [deleteAction]

        case .detail(let playlist):
            guard row < filteredPlaylistItems.count else { return [] }
            let item = filteredPlaylistItems[row]
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Remove") { [weak self] _, _ in
                PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
                self?.reload()
            }
            deleteAction.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0)
            deleteAction.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Remove")
            return [deleteAction]

        case .likedSongs:
            guard row < filteredLikedSongs.count else { return [] }
            let record = filteredLikedSongs[row]
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Unlike") { [weak self] _, _ in
                LocalDatabaseManager.shared.removeLikedSong(videoId: record.videoId)
                NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
                self?.reload()
            }
            deleteAction.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0)
            deleteAction.image = NSImage(systemSymbolName: "heart.slash", accessibilityDescription: "Unlike")
            return [deleteAction]

        case .downloads:
            guard row < filteredDownloads.count else { return [] }
            let track = filteredDownloads[row]
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { [weak self] _, _ in
                LocalLibraryManager.shared.deleteTrack(track) { [weak self] _ in
                    self?.reload()
                }
            }
            deleteAction.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0)
            deleteAction.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Delete")
            return [deleteAction]

        case .history:
            guard row < filteredHistoryItems.count else { return [] }
            let item = filteredHistoryItems[row]
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { [weak self] _, _ in
                HistoryManager.shared.deleteHistoryItem(id: item.id)
                self?.reload()
            }
            deleteAction.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0)
            deleteAction.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Delete")
            return [deleteAction]
        }
    }

    private func showTrackMenu(for item: PlaylistItemRecord, in playlist: PlaylistRecord, from sender: NSButton, index: Int) {
        let menu = NSMenu(title: "Track Actions")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = item
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = item
        menu.addItem(queueItem)

        let resolution = PlaylistManager.shared.resolve(item)
        if case .online = resolution {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = item
            menu.addItem(dlItem)
        }

        menu.addItem(NSMenuItem.separator())

        let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpItem(_:)), keyEquivalent: "")
        moveUpItem.target = self
        moveUpItem.representedObject = ["index": index, "playlistID": playlist.id]
        moveUpItem.isEnabled = index > 0
        menu.addItem(moveUpItem)

        let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownItem(_:)), keyEquivalent: "")
        moveDownItem.target = self
        moveDownItem.representedObject = ["index": index, "playlistID": playlist.id]
        moveDownItem.isEnabled = index < filteredPlaylistItems.count - 1
        menu.addItem(moveDownItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from Playlist", action: #selector(handleContextRemoveItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    private func showDownloadTrackMenu(for track: LocalTrack, from sender: NSButton) {
        let menu = NSMenu(title: "Download Actions")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayDownloadItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = track
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextDownloadItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = track
        menu.addItem(playNextItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddDownloadToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["track": track, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithDownload(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = track
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        menu.addItem(addToPlaylistItem)

        let isLiked = track.isLiked
        let likeItem = NSMenuItem(title: isLiked ? "Unlike Track" : "Like Track", action: #selector(handleContextToggleLikeDownloadItem(_:)), keyEquivalent: "")
        likeItem.target = self
        likeItem.representedObject = track
        menu.addItem(likeItem)

        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleContextShowDownloadInFinder(_:)), keyEquivalent: "")
        finderItem.target = self
        finderItem.representedObject = track
        menu.addItem(finderItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Delete Download", action: #selector(handleContextDeleteDownloadItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = track
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    private func showLikedSongTrackMenu(for record: LikedSongRecord, from sender: NSButton, index: Int) {
        let menu = NSMenu(title: "Liked Song Actions")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayLikedSongItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = record
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextLikedSongItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = record
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueLikedSongItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = record
        menu.addItem(queueItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddLikedSongToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["record": record, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithLikedSong(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = record
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        menu.addItem(addToPlaylistItem)

        let isDownloaded = LocalLibraryManager.shared.allTracks.contains(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        })

        if !isDownloaded && !record.videoId.isEmpty {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadLikedSongItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = record
            menu.addItem(dlItem)
        }

        if isDownloaded, let localTrack = LocalLibraryManager.shared.allTracks.first(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        }) {
            let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleContextShowDownloadInFinder(_:)), keyEquivalent: "")
            finderItem.target = self
            finderItem.representedObject = localTrack
            menu.addItem(finderItem)
        }

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from Liked Songs", action: #selector(handleContextDeleteLikedSongItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = record
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func handleContextNewPlaylistWithDetailItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        promptForName(title: "New Playlist", defaultName: "\(item.title) Playlist", actionTitle: "Create") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                let newItem = PlaylistItemRecord(
                    playlistID: newID,
                    sortOrder: 0,
                    refType: item.refType,
                    refID: item.refID,
                    ytVideoId: item.ytVideoId,
                    title: item.title,
                    artist: item.artist,
                    artworkUrl: item.artworkUrl,
                    duration: item.duration,
                    isLiked: item.isLiked
                )
                PlaylistManager.shared.appendPlaylistItem(newItem, to: newID)
                if let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == newID }) {
                    self.mode = .detail(playlist)
                    return
                }
            }
            self.reload()
        }
    }

    private func showHistoryTrackMenu(for item: HistoryRecord, from sender: NSButton, index: Int) {
        let menu = NSMenu(title: "History Actions")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleContextPlayHistoryItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = item
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleContextPlayNextHistoryItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = item
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleContextAddToQueueHistoryItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = item
        menu.addItem(queueItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleContextAddHistoryToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["historyItem": item, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleContextNewPlaylistWithHistory(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = item
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        menu.addItem(addToPlaylistItem)

        if item.sourceType == "online", let vid = item.ytVideoId, !vid.isEmpty {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleContextDownloadHistoryItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = item
            menu.addItem(dlItem)
        }

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from History", action: #selector(handleContextDeleteHistoryItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = item
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    // MARK: - Drag & Drop Reordering

    public func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        guard case .detail = mode else { return false }
        guard let row = rowIndexes.first else { return false }
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: [NSNumber(value: row)], requiringSecureCoding: false) else { return false }
        pboard.declareTypes([Self.dragType], owner: self)
        pboard.setData(data, forType: Self.dragType)
        return true
    }

    public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard case .detail = mode else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }

    public func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard case .detail(let playlist) = mode else { return false }
        guard let pboard = info.draggingPasteboard.data(forType: Self.dragType),
              let rowNumbers = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSNumber.self], from: pboard)) as? [NSNumber],
              let sourceRowNumber = rowNumbers.first else { return false }

        let sourceRow = sourceRowNumber.intValue
        var targetRow = row
        if targetRow > sourceRow {
            targetRow -= 1
        }
        guard sourceRow != targetRow, sourceRow >= 0, sourceRow < allPlaylistItems.count, targetRow >= 0, targetRow < allPlaylistItems.count else { return false }

        let item = allPlaylistItems.remove(at: sourceRow)
        allPlaylistItems.insert(item, at: targetRow)

        PlaylistManager.shared.reorderItems(playlistID: playlist.id, orderedItemIDs: allPlaylistItems.map { $0.id })
        reload()
        return true
    }
}

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
private class PlaylistRowCellView: NSTableCellView {

    let swipeContainer = SwipeToDeleteContainerView()
    let iconImageView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let countLabel = NSTextField(labelWithString: "")
    let chevronImageView = NSImageView()

    var onRowClicked: (() -> Void)?
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

            countLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            chevronImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
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
        let isGlass = (PlayerDesign.current == .glassMode)
        swipeContainer.contentCardView.layer?.backgroundColor = isGlass ? NSColor(white: 0.0, alpha: 0.05).cgColor : NSColor(white: 1.0, alpha: 0.08).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        guard !swipeContainer.isSwipedOpen else { return }
        let isGlass = (PlayerDesign.current == .glassMode)
        swipeContainer.contentCardView.layer?.backgroundColor = isGlass ? NSColor(white: 0.0, alpha: 0.02).cgColor : NSColor(white: 1.0, alpha: 0.04).cgColor
    }

    func configure(playlist: PlaylistRecord, summary: (countText: String, durationText: String), design: PlayerDesign) {
        swipeContainer.close(animated: false)
        titleLabel.stringValue = playlist.name
        countLabel.stringValue = summary.countText

        let isGlass = (design == .glassMode)
        let isDark = (design == .darkMode)
        let cyan = isGlass ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

        if isGlass {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            titleLabel.textColor = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
            countLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
            iconImageView.contentTintColor = cyan
            chevronImageView.contentTintColor = NSColor(white: 0.20, alpha: 0.40)
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            titleLabel.textColor = NSColor.white
            countLabel.textColor = isDark ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.60, alpha: 1.0)
            iconImageView.contentTintColor = cyan
            chevronImageView.contentTintColor = NSColor(white: 0.80, alpha: 0.40)
        }
    }
}

// MARK: - Playlist Item Row Cell View (Detail Mode Song Row)
private class PlaylistItemRowCellView: NSTableCellView {

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

        let isGlass = (design == .glassMode)
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
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isGlass ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isGlass ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isGlass {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
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
private class DownloadRowCellView: NSTableCellView {

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

        let isGlass = (design == .glassMode)
        let isDark = (design == .darkMode)

        let isCurrent = (NowPlayingManager.shared.engineMode == .offline && NativeAudioPlayer.shared.currentTrack?.id == track.id)

        if isCurrent {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isGlass ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isGlass ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isGlass {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
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
private class HistoryRowCellView: NSTableCellView {

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

        let isGlass = (design == .glassMode)
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
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isGlass ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isGlass ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isGlass {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            timeLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
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
private class LikedSongRowCellView: NSTableCellView {

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
        swipeContainer.deleteButtonTitle = "Unlike"
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

        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        let heartConfig = NSImage.SymbolConfiguration(pointSize: 10.0, weight: .medium)
        heartIcon.image = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Liked")?.withSymbolConfiguration(heartConfig)
        heartIcon.contentTintColor = NSColor(red: 1.0, green: 0.22, blue: 0.38, alpha: 1.0)

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
        containerView.addSubview(heartIcon)
        containerView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),

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

        let isGlass = (design == .glassMode)
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
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isGlass ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
            nowPlayingWave.isHidden = false
            nowPlayingWave.contentTintColor = accentColor
        } else {
            titleLabel.textColor = isGlass ? NSColor.black : NSColor.white
            nowPlayingWave.isHidden = true
        }

        if isGlass {
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            containerView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
            optionsButton.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
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
