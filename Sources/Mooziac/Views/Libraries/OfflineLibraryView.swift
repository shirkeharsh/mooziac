import AppKit
import Foundation

protocol OfflineLibraryViewDelegate: AnyObject {
    func offlineLibraryDidSelectTrack(_ track: LocalTrack, in queue: [LocalTrack])
    func offlineLibraryDidRequestClose()
    func offlineLibraryDidRequestImport()
}

public class OfflineLibraryView: NSView, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    weak var delegate: OfflineLibraryViewDelegate?

    private let topBar = NSView()
    private let backButton = ReactiveIconButton()
    private let headerTitleLabel = NSTextField(labelWithString: "DOWNLOADS")
    private let searchField = GlassSearchField()

    private let importButton = ReactiveIconButton()
    private let openFolderButton = ReactiveIconButton()

    private let scrollView = NSScrollView()
    private let tableView = OfflineTableView()

    private let emptyStateView = NSView()
    private let emptyStateIcon = NSImageView()
    private let emptyStateLabel = NSTextField(labelWithString: "No downloaded tracks")
    private let emptyStateSubLabel = NSTextField(labelWithString: "Downloaded tracks from YouTube Music will appear here")

    private let downloadStatusBar = NSView()
    private let downloadStatusLabel = NSTextField(labelWithString: "")
    private let downloadSpinner = NSProgressIndicator()
    private let visualEffectBackdrop = NSVisualEffectView()

    private var displayedTracks: [LocalTrack] = []
    private var currentSearchQuery: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupObservers()
        applyTheme()
        refreshLibrary()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupObservers()
        applyTheme()
        refreshLibrary()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

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

        // Enable Drag & Drop
        registerForDraggedTypes([.fileURL])

        // Top Bar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)

        // Back to Player Button
        setupIconButton(backButton, systemName: "chevron.backward.circle.fill", toolTip: "Back to Player", action: #selector(handleBackTapped), pointSize: 16.0)
        backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        topBar.addSubview(backButton)

        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        headerTitleLabel.textColor = NSColor.white
        headerTitleLabel.isEditable = false
        headerTitleLabel.isSelectable = false
        headerTitleLabel.refusesFirstResponder = true
        topBar.addSubview(headerTitleLabel)

        // Action Buttons
        setupIconButton(importButton, systemName: "plus.circle.fill", toolTip: "Import Audio Files...", action: #selector(handleImportTapped), pointSize: 15.0)
        setupIconButton(openFolderButton, systemName: "folder", toolTip: "Open ~/Music/Mooziac in Finder", action: #selector(handleOpenFolderTapped), pointSize: 14.0)

        let actionStack = NSStackView(views: [openFolderButton, importButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 6
        actionStack.alignment = .centerY
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(actionStack)

        // Search Field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search downloads..."
        searchField.delegate = self
        addSubview(searchField)

        // Download Status Bar (Only visible when actively downloading)
        downloadStatusBar.translatesAutoresizingMaskIntoConstraints = false
        downloadStatusBar.wantsLayer = true
        downloadStatusBar.layer?.backgroundColor = NSColor(red: 0.0, green: 0.55, blue: 0.95, alpha: 0.22).cgColor
        downloadStatusBar.layer?.cornerRadius = 6
        let isBusy = DownloadManager.shared.isDownloading && DownloadManager.shared.remainingQueueCount > 0
        downloadStatusBar.isHidden = !isBusy
        addSubview(downloadStatusBar)

        downloadSpinner.translatesAutoresizingMaskIntoConstraints = false
        downloadSpinner.style = .spinning
        downloadSpinner.controlSize = .small
        if isBusy {
            downloadSpinner.startAnimation(nil)
        }

        downloadStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        downloadStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        downloadStatusLabel.textColor = NSColor(white: 0.95, alpha: 1.0)
        downloadStatusLabel.isEditable = false
        downloadStatusLabel.isSelectable = false
        downloadStatusLabel.refusesFirstResponder = true

        downloadStatusBar.addSubview(downloadSpinner)
        downloadStatusBar.addSubview(downloadStatusLabel)

        // Table View
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

        tableView.onReturnKey = { [weak self] in
            self?.handleReturnAction()
        }
        tableView.onDeleteKey = { [weak self] in
            self?.handleDeleteKeyAction()
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TrackColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        addSubview(scrollView)

        setupTableViewMenu()

        // Empty State View
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 34, weight: .light)
        emptyStateIcon.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Empty")?.withSymbolConfiguration(iconConfig)
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
            topBar.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            topBar.heightAnchor.constraint(equalToConstant: 32),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            headerTitleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            headerTitleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            actionStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            actionStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            searchField.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 26),

            downloadStatusBar.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            downloadStatusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            downloadStatusBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            downloadStatusBar.heightAnchor.constraint(equalToConstant: 22),

            downloadSpinner.leadingAnchor.constraint(equalTo: downloadStatusBar.leadingAnchor, constant: 8),
            downloadSpinner.centerYAnchor.constraint(equalTo: downloadStatusBar.centerYAnchor),
            downloadStatusLabel.leadingAnchor.constraint(equalTo: downloadSpinner.trailingAnchor, constant: 8),
            downloadStatusLabel.trailingAnchor.constraint(equalTo: downloadStatusBar.trailingAnchor, constant: -8),
            downloadStatusLabel.centerYAnchor.constraint(equalTo: downloadStatusBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            emptyStateView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 280),
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

    private func setupIconButton(_ btn: ReactiveIconButton, systemName: String, toolTip: String, action: Selector, pointSize: CGFloat) {
        btn.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if let img = NSImage(systemSymbolName: systemName, accessibilityDescription: toolTip)?.withSymbolConfiguration(config) {
            btn.image = img
        }
        btn.toolTip = toolTip
        btn.target = self
        btn.action = action
        btn.isBordered = false
        btn.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        btn.widthAnchor.constraint(equalToConstant: 26).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    private func setupObservers() {
        LocalLibraryManager.shared.onLibraryUpdated = { [weak self] _ in
            self?.refreshLibrary()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_playerDesignChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: NSNotification.Name("YTM_ambientThemeChanged"), object: nil)

        DownloadManager.shared.onDownloadStatusChanged = { [weak self] isDownloading, message in
            guard let self = self else { return }
            let isBusy = isDownloading && DownloadManager.shared.remainingQueueCount > 0
            self.downloadStatusBar.isHidden = !isBusy
            self.downloadSpinner.isHidden = !isBusy
            if isBusy {
                self.downloadSpinner.startAnimation(nil)
                self.downloadStatusLabel.stringValue = message
            } else {
                self.downloadSpinner.stopAnimation(nil)
                self.downloadStatusLabel.stringValue = ""
            }
        }

        NotificationCenter.default.addObserver(forName: DownloadManager.queueNotification, object: nil, queue: .main) { [weak self] notif in
            guard let self = self else { return }
            let remaining = notif.userInfo?["remaining"] as? Int ?? 0
            let displayText = notif.userInfo?["displayText"] as? String ?? ""
            let isBusy = remaining > 0 && DownloadManager.shared.isDownloading

            self.downloadStatusBar.isHidden = !isBusy
            self.downloadSpinner.isHidden = !isBusy
            if isBusy {
                self.downloadSpinner.startAnimation(nil)
                self.downloadStatusLabel.stringValue = displayText
            } else {
                self.downloadSpinner.stopAnimation(nil)
                self.downloadStatusLabel.stringValue = ""
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("Mooziac_PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.reloadVisiblePlayingStates()
        }
    }

    private func reloadVisiblePlayingStates() {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let maxIndex = min(visibleRange.location + visibleRange.length, displayedTracks.count)
        let design = PlayerDesign.current
        for rowIndex in visibleRange.location..<maxIndex {
            let track = displayedTracks[rowIndex]
            if let cell = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? OfflineTrackCellView {
                let isCurrent = (NativeAudioPlayer.shared.currentTrack?.id == track.id)
                cell.configure(track: track, isPlaying: isCurrent && NativeAudioPlayer.shared.isPlaying, design: design)
            }
        }
    }

    @objc public func applyTheme() {
        let design = PlayerDesign.current

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35

            switch design {
            case .adaptive:
                visualEffectBackdrop.isHidden = true
                let bg = DynamicIslandPlayerView.sharedAmbientBgColor ?? NSColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 0.98).cgColor
                layer?.backgroundColor = bg
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor

                headerTitleLabel.textColor = NSColor.white
                backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                importButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                openFolderButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .adaptive)

            case .darkMode:
                visualEffectBackdrop.isHidden = true
                layer?.backgroundColor = SystemAppearanceHelper.darkModeBackingColor.cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = SystemAppearanceHelper.darkModeBorderColor.cgColor

                headerTitleLabel.textColor = NSColor.white
                backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                importButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .darkMode)
                openFolderButton.contentTintColor = SystemAppearanceHelper.controlButtonTint(for: .darkMode)

            case .glassMode:
                visualEffectBackdrop.isHidden = true
                layer?.backgroundColor = NSColor(red: 0.93725, green: 0.94902, blue: 0.94118, alpha: 0.98).cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(red: 0.78, green: 0.80, blue: 0.79, alpha: 0.90).cgColor

                let pitchBlack = SystemAppearanceHelper.primaryTextColor(for: .glassMode)
                headerTitleLabel.textColor = pitchBlack
                backButton.contentTintColor = pitchBlack
                importButton.contentTintColor = pitchBlack
                openFolderButton.contentTintColor = pitchBlack

            case .liquidFluid:
                visualEffectBackdrop.isHidden = false
                visualEffectBackdrop.material = .hudWindow
                visualEffectBackdrop.blendingMode = .behindWindow
                visualEffectBackdrop.state = .active

                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 1.0
                layer?.borderColor = NSColor(white: 1.0, alpha: 0.32).cgColor

                headerTitleLabel.textColor = NSColor.white
                backButton.contentTintColor = NSColor.white
                importButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
                openFolderButton.contentTintColor = NSColor(white: 0.90, alpha: 1.0)
            }

            searchField.applyTheme(design)
            emptyStateLabel.textColor = (design == .glassMode) ? NSColor(white: 0.15, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)
            emptyStateSubLabel.textColor = (design == .glassMode) ? NSColor(white: 0.35, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            emptyStateIcon.contentTintColor = (design == .glassMode) ? NSColor(white: 0.30, alpha: 1.0) : NSColor(white: 0.60, alpha: 1.0)
        }

        tableView.reloadData()
    }

    public func refreshLibrary() {
        let isBusy = DownloadManager.shared.isDownloading && DownloadManager.shared.remainingQueueCount > 0
        downloadStatusBar.isHidden = !isBusy
        downloadSpinner.isHidden = !isBusy
        if !isBusy {
            downloadSpinner.stopAnimation(nil)
            downloadStatusLabel.stringValue = ""
        }
        applyFilter()
    }

    private func applyFilter() {
        let base = LocalLibraryManager.shared.allTracks

        let query = currentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            displayedTracks = base
        } else {
            displayedTracks = base.filter {
                $0.title.lowercased().contains(query) ||
                $0.artist.lowercased().contains(query) ||
                $0.album.lowercased().contains(query)
            }
        }

        let totalCount = LocalLibraryManager.shared.allTracks.count
        headerTitleLabel.stringValue = "DOWNLOADS (\(totalCount))"

        emptyStateView.isHidden = !displayedTracks.isEmpty
        emptyStateLabel.stringValue = "No downloaded tracks"
        emptyStateSubLabel.stringValue = "Downloaded tracks from YouTube Music will appear here"

        tableView.reloadData()
    }

    // MARK: - Actions
    @objc private func handleBackTapped() {
        delegate?.offlineLibraryDidRequestClose()
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
                LocalLibraryManager.shared.importFiles(from: panel.urls) { count in
                    self?.refreshLibrary()
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
            downloadStatusBar.isHidden = false
            downloadSpinner.isHidden = true
            downloadStatusLabel.stringValue = "⚠️ Play a song online first to download it"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.downloadStatusBar.isHidden = true
                self?.downloadStatusLabel.stringValue = ""
            }
            return
        }

        let targetUrl = state.pageUrl.isEmpty ? state.videoId : state.pageUrl
        DownloadManager.shared.downloadTrack(
            urlOrVideoId: targetUrl,
            title: state.title,
            artist: state.artist,
            artworkUrl: state.artworkUrl
        ) { [weak self] success, msg in
            self?.refreshLibrary()
        }
    }

    // MARK: - Context Menu Setup & Actions
    private func setupTableViewMenu() {
        tableView.onRightClickTrack = { [weak self] row in
            guard let self = self, row < self.displayedTracks.count else { return nil }
            return self.displayedTracks[row]
        }

        tableView.onMenuAction = { [weak self] action, track in
            guard let self = self else { return }
            switch action {
            case .play:
                self.delegate?.offlineLibraryDidSelectTrack(track, in: self.displayedTracks)
            case .playNext:
                NativeAudioPlayer.shared.playNext(track: track)
            case .toggleLike:
                LocalLibraryManager.shared.toggleLike(for: track.id)
                self.refreshLibrary()
            case .showInFinder:
                self.showInFinder(track: track)
            case .delete:
                self.confirmAndDeleteTrack(track)
            }
        }
    }

    private func showInFinder(track: LocalTrack) {
        if FileManager.default.fileExists(atPath: track.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
        } else {
            LocalLibraryManager.shared.openMusicFolderInFinder()
        }
    }

    private func confirmAndDeleteTrack(_ track: LocalTrack) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete \"\(track.title)\"?"
        alert.informativeText = "This will remove the downloaded audio and lyrics from Mooziac."
        alert.alertStyle = .warning
        let deleteBtn = alert.addButton(withTitle: "Delete")
        deleteBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            LocalLibraryManager.shared.deleteTrack(track) { [weak self] _ in
                self?.refreshLibrary()
            }
        }
    }

    // MARK: - Search Field Delegate
    public func controlTextDidChange(_ obj: Notification) {
        currentSearchQuery = searchField.stringValue
        refreshLibrary()
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let selected = tableView.selectedRow

            let targetTrack =
                (selected >= 0 && selected < displayedTracks.count)
                ? displayedTracks[selected]
                : displayedTracks.first

            if let track = targetTrack {
                NowPlayingManager.shared.playOfflineTrack(
                    track,
                    in: displayedTracks
                )

                CenteredMenuBarLyricsWindowController.shared
                    .showCustomTextOverlay(
                        text: " Playing: \"\(track.title)\""
                    )

                return true
            }
        }
        return false
    }

    // MARK: - Drag & Drop Support
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        LocalLibraryManager.shared.importFiles(from: pasteboard) { [weak self] _ in
            self?.refreshLibrary()
        }
        return true
    }

    // MARK: - NSTableView DataSource & Delegate
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedTracks.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayedTracks.count else { return nil }
        let track = displayedTracks[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("OfflineTrackCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? OfflineTrackCellView
        if cell == nil {
            cell = OfflineTrackCellView()
            cell?.identifier = cellIdentifier
        }

        let isCurrent = (NativeAudioPlayer.shared.currentTrack?.id == track.id)
        cell?.configure(track: track, isPlaying: isCurrent && NativeAudioPlayer.shared.isPlaying, design: PlayerDesign.current)
        cell?.onRowClicked = { [weak self] in
            guard let self = self else { return }
            self.delegate?.offlineLibraryDidSelectTrack(track, in: self.displayedTracks)
        }
        cell?.onLikeTapped = { [weak self] in
            LocalLibraryManager.shared.toggleLike(for: track.id)
            self?.refreshLibrary()
        }
        cell?.onDelete = { [weak self] in
            self?.confirmAndDeleteTrack(track)
        }

        return cell
    }

    public func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        guard edge == .trailing, row < displayedTracks.count else { return [] }
        let track = displayedTracks[row]
        let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { [weak self] _, _ in
            self?.confirmAndDeleteTrack(track)
        }
        deleteAction.backgroundColor = NSColor(red: 0.93, green: 0.20, blue: 0.22, alpha: 1.0)
        deleteAction.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Delete")
        return [deleteAction]
    }

    @objc private func handleDoubleAction() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedTracks.count else { return }
        let track = displayedTracks[row]
        delegate?.offlineLibraryDidSelectTrack(track, in: displayedTracks)
    }

    private func handleReturnAction() {
        let row = tableView.selectedRow
        guard row >= 0 && row < displayedTracks.count else { return }
        let track = displayedTracks[row]
        delegate?.offlineLibraryDidSelectTrack(track, in: displayedTracks)
    }

    private func handleDeleteKeyAction() {
        let row = tableView.selectedRow
        guard row >= 0 && row < displayedTracks.count else { return }
        let track = displayedTracks[row]
        confirmAndDeleteTrack(track)
    }
}

// MARK: - Custom Cell View
private class OfflineTrackCellView: NSTableCellView {
    let swipeContainer = SwipeToDeleteContainerView()
    let artImageView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let artistLabel = NSTextField(labelWithString: "")
    let durationLabel = NSTextField(labelWithString: "")
    let likeButton = ReactiveIconButton()

    private var currentTrackID: String = ""
    private var trackingArea: NSTrackingArea?

    var onLikeTapped: (() -> Void)?
    var onRowClicked: (() -> Void)?
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

    deinit {
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
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

        artImageView.translatesAutoresizingMaskIntoConstraints = false
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 6
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        artistLabel.maximumNumberOfLines = 1
        artistLabel.usesSingleLineMode = true
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.isEditable = false
        artistLabel.isSelectable = false
        artistLabel.refusesFirstResponder = true

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        durationLabel.alignment = .right
        durationLabel.isEditable = false
        durationLabel.isSelectable = false
        durationLabel.refusesFirstResponder = true

        likeButton.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        likeButton.image = NSImage(systemSymbolName: "heart", accessibilityDescription: "Like")?.withSymbolConfiguration(config)
        likeButton.isBordered = false
        likeButton.target = self
        likeButton.action = #selector(likeTapped)

        let textStack = NSStackView(views: [titleLabel, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(artImageView)
        card.addSubview(textStack)
        card.addSubview(durationLabel)
        card.addSubview(likeButton)

        NSLayoutConstraint.activate([
            artImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            artImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 32),
            artImageView.heightAnchor.constraint(equalToConstant: 32),

            textStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 8),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),

            durationLabel.trailingAnchor.constraint(equalTo: likeButton.leadingAnchor, constant: -6),
            durationLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 45),

            likeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            likeButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 22),
            likeButton.heightAnchor.constraint(equalToConstant: 22)
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
        let isLiquid = (PlayerDesign.current == .liquidFluid)
        if isGlass {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.05).cgColor
        } else if isLiquid {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.24).cgColor
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard !swipeContainer.isSwipedOpen else { return }
        let isGlass = (PlayerDesign.current == .glassMode)
        let isLiquid = (PlayerDesign.current == .liquidFluid)
        if isGlass {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
        } else if isLiquid {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
        }
    }

    public func configure(track: LocalTrack, isPlaying: Bool, design: PlayerDesign) {
        swipeContainer.close(animated: false)
        currentTrackID = track.id
        titleLabel.stringValue = track.title
        artistLabel.stringValue = track.artist

        // Asynchronous / Cached thumbnail loading (32x32 view -> 64px 2x retina thumbnail)
        if let cached = AppArtworkHelper.shared.getCachedThumbnail(for: track, targetSize: 64) {
            artImageView.image = cached
        } else {
            artImageView.image = AppArtworkHelper.defaultArtwork
            AppArtworkHelper.shared.loadThumbnail(for: track, targetSize: 64) { [weak self] thumbnail in
                guard let self = self, self.currentTrackID == track.id else { return }
                self.artImageView.image = thumbnail ?? AppArtworkHelper.defaultArtwork
            }
        }

        if track.duration > 0 {
            let mins = Int(track.duration) / 60
            let secs = Int(track.duration) % 60
            durationLabel.stringValue = String(format: "%d:%02d", mins, secs)
        } else {
            durationLabel.stringValue = "--:--"
        }

        let isGlass = (design == .glassMode)
        let isLiquid = (design == .liquidFluid)
        let isDark = (design == .darkMode)

        if isPlaying {
            let accentColor = DynamicIslandPlayerView.sharedAmbientAccentColor ?? (isGlass ? NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0) : NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0))
            titleLabel.textColor = accentColor
        } else {
            titleLabel.textColor = isGlass ? NSColor.black : NSColor.white
        }

        if isGlass {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
            artistLabel.textColor = NSColor(white: 0.30, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
        } else if isLiquid {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
            artistLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
            durationLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
        } else {
            swipeContainer.contentCardView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
            swipeContainer.contentCardView.layer?.borderWidth = 1.0
            swipeContainer.contentCardView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            artistLabel.textColor = isDark ? NSColor(white: 0.60, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            durationLabel.textColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.60, alpha: 1.0)
        }

        let likeIconName = track.isLiked ? "heart.fill" : "heart"
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        likeButton.image = NSImage(systemSymbolName: likeIconName, accessibilityDescription: "Like")?.withSymbolConfiguration(config)
        if track.isLiked {
            likeButton.contentTintColor = NSColor(red: 0.98, green: 0.25, blue: 0.35, alpha: 1.0)
        } else {
            likeButton.contentTintColor = isGlass ? NSColor(white: 0.25, alpha: 1.0) : NSColor(white: 0.60, alpha: 1.0)
        }
    }

    @objc private func likeTapped() {
        onLikeTapped?()
    }
}

// MARK: - Context Menu Enabled Table View
public class OfflineTableView: NSTableView {
    public var onRightClickTrack: ((Int) -> LocalTrack?)?
    public var onMenuAction: ((OfflineMenuAction, LocalTrack) -> Void)?
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

    public enum OfflineMenuAction {
        case play
        case playNext
        case toggleLike
        case showInFinder
        case delete
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        guard clickedRow >= 0, let track = onRightClickTrack?(clickedRow) else {
            return super.menu(for: event)
        }

        selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)

        let menu = NSMenu(title: "Track Context Menu")

        let playItem = NSMenuItem(title: "Play", action: #selector(handlePlayItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = track
        let playConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handlePlayNextItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = track
        let nextConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playNextItem.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Play Next")?.withSymbolConfiguration(nextConfig)
        menu.addItem(playNextItem)

        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubMenu = NSMenu(title: "Add to Playlist")
        let list = PlaylistManager.shared.fetchPlaylists()
        for pl in list {
            let item = NSMenuItem(title: pl.name, action: #selector(handleAddToPlaylistSubmenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["playlistID": pl.id, "track": track]
            playlistSubMenu.addItem(item)
        }
        if !list.isEmpty {
            playlistSubMenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleNewPlaylistWithTrackSubmenuItem(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = track
        playlistSubMenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubMenu
        let playlistConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addToPlaylistItem.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Add to Playlist")?.withSymbolConfiguration(playlistConfig)
        menu.addItem(addToPlaylistItem)

        menu.addItem(NSMenuItem.separator())

        let isLiked = track.isLiked
        let likeTitle = isLiked ? "Unlike Track" : "Like Track"
        let likeIcon = isLiked ? "heart.slash" : "heart"
        let likeItem = NSMenuItem(title: likeTitle, action: #selector(handleToggleLikeItem(_:)), keyEquivalent: "")
        likeItem.target = self
        likeItem.representedObject = track
        let likeConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        likeItem.image = NSImage(systemSymbolName: likeIcon, accessibilityDescription: likeTitle)?.withSymbolConfiguration(likeConfig)
        menu.addItem(likeItem)

        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleShowInFinderItem(_:)), keyEquivalent: "")
        finderItem.target = self
        finderItem.representedObject = track
        let finderConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        finderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Show in Finder")?.withSymbolConfiguration(finderConfig)
        menu.addItem(finderItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Delete Download…", action: #selector(handleDeleteItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = track
        let trashConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete Download")?.withSymbolConfiguration(trashConfig)
        menu.addItem(deleteItem)

        return menu
    }

    @objc private func handlePlayItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        onMenuAction?(.play, track)
    }

    @objc private func handlePlayNextItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        onMenuAction?(.playNext, track)
    }

    @objc private func handleToggleLikeItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        onMenuAction?(.toggleLike, track)
    }

    @objc private func handleShowInFinderItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        onMenuAction?(.showInFinder, track)
    }

    @objc private func handleDeleteItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        onMenuAction?(.delete, track)
    }

    @objc private func handleAddToPlaylistSubmenuItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let playlistID = dict["playlistID"] as? String,
              let track = dict["track"] as? LocalTrack else { return }
        PlaylistManager.shared.appendLocalTracks([track], to: playlistID)
    }

    @objc private func handleNewPlaylistWithTrackSubmenuItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "New Playlist"
        alert.informativeText = "Enter a name for this playlist:"
        alert.alertStyle = .informational
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = "My Playlist"
        alert.accessoryView = textField
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newID = PlaylistManager.shared.createPlaylist(name: name.isEmpty ? "My Playlist" : name) {
                PlaylistManager.shared.appendLocalTracks([track], to: newID)
            }
        }
    }
}
