import AppKit

extension DynamicIslandPlayerView {

    var downloadsOrderKey: String { "MooziacDownloadsCustomOrder" }
    var likedSongsOrderKey: String { "MooziacLikedSongsCustomOrder" }
    var historyOrderKey: String { "MooziacHistoryCustomOrder" }

    var isLibrarySearchActive: Bool {
        let q = playlistSearchField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !q.isEmpty
    }

    func setupSettingsContainerView() {
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.wantsLayer = true
        settingsContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        settingsContainerView.layer?.masksToBounds = true
        settingsContainerView.isHidden = true

        // -------------------------
        // 1. MAIN PREFERENCES VIEW
        // -------------------------
        settingsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsHeaderLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        settingsHeaderLabel.textColor = NSColor(white: 0.92, alpha: 1.0)
        settingsHeaderLabel.isEditable = false
        settingsHeaderLabel.isSelectable = false
        settingsHeaderLabel.refusesFirstResponder = true

        featuresSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        featuresSectionLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        featuresSectionLabel.stringValue = "PLAYER PREFERENCES"
        featuresSectionLabel.isEditable = false
        featuresSectionLabel.isSelectable = false
        featuresSectionLabel.refusesFirstResponder = true

        let themeRow = makeThemeFeatureRow()
        let progressRow = makeProgressStyleFeatureRow()

        let volumeRow = makeFeatureRow(
            icon: "speaker.wave.2.fill",
            title: "Focused Audio",
            description: "Independent app media volume",
            isOn: AppVolumeManager.shared.isAppVolumeOnly,
            toggle: appVolumeToggle,
            onToggle: { AppVolumeManager.shared.isAppVolumeOnly = $0 }
        )
        let gesturesRow = makeFeatureRow(
            icon: "hand.tap",
            title: "Edge Gestures",
            description: "Edge swipes and trackpad taps",
            isOn: EdgeVolumeEngine.shared.isEnabled,
            toggle: masterGesturesToggle,
            onToggle: { EdgeVolumeEngine.shared.isEnabled = $0 }
        )
        let lyricsRow = makeFeatureRow(
            icon: "quote.bubble",
            title: "Live Lyric Flow",
            description: "Realtime synchronized lyric bar",
            isOn: CenteredMenuBarLyricsWindowController.shared.isEnabled,
            toggle: lyricsToggle,
            onToggle: { CenteredMenuBarLyricsWindowController.shared.isEnabled = $0 }
        )
        let discordRow = makeFeatureRow(
            icon: "number",
            title: "Discord Status",
            description: "Broadcast live track on Discord",
            isOn: DiscordRPCManager.shared.isEnabled,
            toggle: discordToggle,
            onToggle: { DiscordRPCManager.shared.isEnabled = $0 }
        )

        let featuresStack = NSStackView(views: [themeRow, progressRow, volumeRow, gesturesRow, lyricsRow, discordRow])
        featuresStack.orientation = .vertical
        featuresStack.alignment = .leading
        featuresStack.spacing = 3
        featuresStack.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "Mooziac v\(UpdateManager.shared.currentVersion)")
        versionLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        versionLabel.alignment = .center
        versionLabel.isEditable = false
        versionLabel.isSelectable = false
        versionLabel.refusesFirstResponder = true
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsVersionLabel = versionLabel

        let mainStack = NSStackView(views: [
            featuresSectionLabel,
            featuresStack,
            versionLabel
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 6
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.identifier = NSUserInterfaceItemIdentifier("MainSettingsStack")

        // -------------------------
        // 2. ADD TO PLAYLIST PICKER (Clean Vertical List with Search)
        // -------------------------
        let subView = NSView()
        subView.translatesAutoresizingMaskIntoConstraints = false
        subView.wantsLayer = true
        subView.layer?.masksToBounds = false
        subView.isHidden = true
        subView.identifier = NSUserInterfaceItemIdentifier("PlaylistSubView")

        playlistSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        playlistSectionLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        playlistSectionLabel.stringValue = "PLAYLISTS"
        playlistSectionLabel.isEditable = false
        playlistSectionLabel.isSelectable = false
        playlistSectionLabel.refusesFirstResponder = true
        playlistSectionLabel.isHidden = true
        let sectionClick = NSClickGestureRecognizer(target: self, action: #selector(handleSectionLabelClicked))
        playlistSectionLabel.addGestureRecognizer(sectionClick)

        libraryNavContainer.translatesAutoresizingMaskIntoConstraints = false
        libraryNavContainer.wantsLayer = true
        libraryNavContainer.layer?.backgroundColor = NSColor.clear.cgColor
        libraryNavContainer.layer?.borderWidth = 0

        libraryNavStack.orientation = .horizontal
        libraryNavStack.alignment = .centerY
        libraryNavStack.distribution = .fillEqually
        libraryNavStack.spacing = 6
        libraryNavStack.translatesAutoresizingMaskIntoConstraints = false
        libraryNavContainer.addSubview(libraryNavStack)

        libraryNavButtons = LibraryTab.allCases.map { tab in
            let btn = LibraryNavButton(tab: tab)
            btn.target = self
            btn.action = #selector(handleLibraryNavTapped(_:))
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
            libraryNavStack.addArrangedSubview(btn)
            return btn
        }
        libraryNavButtons.first?.isSelected = true

        librarySectionHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        librarySectionHeaderLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        librarySectionHeaderLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        librarySectionHeaderLabel.isEditable = false
        librarySectionHeaderLabel.isSelectable = false
        librarySectionHeaderLabel.refusesFirstResponder = true

        downloadsPlayAllButton.translatesAutoresizingMaskIntoConstraints = false
        let dlPlayConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        downloadsPlayAllButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play All")?.withSymbolConfiguration(dlPlayConfig)
        downloadsPlayAllButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        downloadsPlayAllButton.toolTip = "Play All Downloads"
        downloadsPlayAllButton.target = self
        downloadsPlayAllButton.action = #selector(handleDownloadsPlayAllTapped)
        downloadsPlayAllButton.isHidden = true
        downloadsPlayAllButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        downloadsPlayAllButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        downloadsShuffleButton.translatesAutoresizingMaskIntoConstraints = false
        let dlShuffleConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        downloadsShuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")?.withSymbolConfiguration(dlShuffleConfig)
        downloadsShuffleButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        downloadsShuffleButton.toolTip = "Shuffle Downloads"
        downloadsShuffleButton.target = self
        downloadsShuffleButton.action = #selector(handleDownloadsShuffleTapped)
        downloadsShuffleButton.isHidden = true
        downloadsShuffleButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        downloadsShuffleButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        likedPlayAllButton.translatesAutoresizingMaskIntoConstraints = false
        let likedPlayConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        likedPlayAllButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play All")?.withSymbolConfiguration(likedPlayConfig)
        likedPlayAllButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        likedPlayAllButton.toolTip = "Play All Liked Songs"
        likedPlayAllButton.target = self
        likedPlayAllButton.action = #selector(handleLikedSongsPlayAllTapped)
        likedPlayAllButton.isHidden = true
        likedPlayAllButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        likedPlayAllButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        likedShuffleButton.translatesAutoresizingMaskIntoConstraints = false
        let likedShuffleConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        likedShuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")?.withSymbolConfiguration(likedShuffleConfig)
        likedShuffleButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        likedShuffleButton.toolTip = "Shuffle Liked Songs"
        likedShuffleButton.target = self
        likedShuffleButton.action = #selector(handleLikedSongsShuffleTapped)
        likedShuffleButton.isHidden = true
        likedShuffleButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        likedShuffleButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        historyPlayAllButton.translatesAutoresizingMaskIntoConstraints = false
        let historyPlayConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        historyPlayAllButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play All")?.withSymbolConfiguration(historyPlayConfig)
        historyPlayAllButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        historyPlayAllButton.toolTip = "Play All History"
        historyPlayAllButton.target = self
        historyPlayAllButton.action = #selector(handleHistoryPlayAllTapped)
        historyPlayAllButton.isHidden = true
        historyPlayAllButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        historyPlayAllButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        historyShuffleButton.translatesAutoresizingMaskIntoConstraints = false
        let historyShuffleConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        historyShuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")?.withSymbolConfiguration(historyShuffleConfig)
        historyShuffleButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        historyShuffleButton.toolTip = "Shuffle History"
        historyShuffleButton.target = self
        historyShuffleButton.action = #selector(handleHistoryShuffleTapped)
        historyShuffleButton.isHidden = true
        historyShuffleButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        historyShuffleButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailBackButton.translatesAutoresizingMaskIntoConstraints = false
        let backConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        playlistDetailBackButton.image = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Back")?.withSymbolConfiguration(backConfig)
        playlistDetailBackButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailBackButton.toolTip = "Back to playlists"
        playlistDetailBackButton.target = self
        playlistDetailBackButton.action = #selector(handleBackFromPlaylistDetail)
        playlistDetailBackButton.isHidden = true
        playlistDetailBackButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailBackButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailPlayAllButton.translatesAutoresizingMaskIntoConstraints = false
        let playConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistDetailPlayAllButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play All")?.withSymbolConfiguration(playConfig)
        playlistDetailPlayAllButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailPlayAllButton.toolTip = "Play All"
        playlistDetailPlayAllButton.target = self
        playlistDetailPlayAllButton.action = #selector(handlePlayPlaylistFromDetail)
        playlistDetailPlayAllButton.isHidden = true
        playlistDetailPlayAllButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailPlayAllButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailShuffleButton.translatesAutoresizingMaskIntoConstraints = false
        let shuffleConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistDetailShuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")?.withSymbolConfiguration(shuffleConfig)
        playlistDetailShuffleButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailShuffleButton.toolTip = "Shuffle"
        playlistDetailShuffleButton.target = self
        playlistDetailShuffleButton.action = #selector(handleShufflePlaylistFromDetail)
        playlistDetailShuffleButton.isHidden = true
        playlistDetailShuffleButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailShuffleButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailDownloadAllButton.translatesAutoresizingMaskIntoConstraints = false
        let dlAllConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistDetailDownloadAllButton.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Download All Tracks")?.withSymbolConfiguration(dlAllConfig)
        playlistDetailDownloadAllButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailDownloadAllButton.toolTip = "Download All Tracks"
        playlistDetailDownloadAllButton.target = self
        playlistDetailDownloadAllButton.action = #selector(handleDownloadAllFromDetailHeader)
        playlistDetailDownloadAllButton.isHidden = true
        playlistDetailDownloadAllButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailDownloadAllButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailCreateButton.translatesAutoresizingMaskIntoConstraints = false
        let createConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        playlistDetailCreateButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Create New Playlist")?.withSymbolConfiguration(createConfig)
        playlistDetailCreateButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        playlistDetailCreateButton.toolTip = "Create New Playlist"
        playlistDetailCreateButton.target = self
        playlistDetailCreateButton.action = #selector(handleCreateNewPlaylistFromHeader)
        playlistDetailCreateButton.isBordered = false
        playlistDetailCreateButton.wantsLayer = true
        playlistDetailCreateButton.layer?.cornerRadius = 5
        playlistDetailCreateButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        playlistDetailCreateButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        playlistDetailDeleteButton.translatesAutoresizingMaskIntoConstraints = false
        let deleteConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        playlistDetailDeleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete Playlist")?.withSymbolConfiguration(deleteConfig)
        playlistDetailDeleteButton.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        playlistDetailDeleteButton.toolTip = "Delete Playlist"
        playlistDetailDeleteButton.target = self
        playlistDetailDeleteButton.action = #selector(handleDeletePlaylistFromHeader)
        playlistDetailDeleteButton.isHidden = true
        playlistDetailDeleteButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailDeleteButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailAddButton.translatesAutoresizingMaskIntoConstraints = false
        let addConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistDetailAddButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add Current Song")?.withSymbolConfiguration(addConfig)
        playlistDetailAddButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailAddButton.toolTip = "Add Currently Playing Song"
        playlistDetailAddButton.target = self
        playlistDetailAddButton.action = #selector(handleAddCurrentSongToDetailPlaylist)
        playlistDetailAddButton.isHidden = true
        playlistDetailAddButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailAddButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistDetailRenameButton.translatesAutoresizingMaskIntoConstraints = false
        let renameConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistDetailRenameButton.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename Playlist")?.withSymbolConfiguration(renameConfig)
        playlistDetailRenameButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistDetailRenameButton.toolTip = "Rename Playlist"
        playlistDetailRenameButton.target = self
        playlistDetailRenameButton.action = #selector(handleRenamePlaylistFromDetailHeader)
        playlistDetailRenameButton.isHidden = true
        playlistDetailRenameButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistDetailRenameButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistSearchToggleButton.translatesAutoresizingMaskIntoConstraints = false
        let searchToggleConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        playlistSearchToggleButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search Playlists")?.withSymbolConfiguration(searchToggleConfig)
        playlistSearchToggleButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        playlistSearchToggleButton.toolTip = "Search Playlists"
        playlistSearchToggleButton.target = self
        playlistSearchToggleButton.action = #selector(handlePlaylistSearchToggle)
        playlistSearchToggleButton.isBordered = false
        playlistSearchToggleButton.wantsLayer = true
        playlistSearchToggleButton.layer?.cornerRadius = 5
        playlistSearchToggleButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        playlistSearchToggleButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        playlistBulkDeleteButton.translatesAutoresizingMaskIntoConstraints = false
        let bulkDelConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playlistBulkDeleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete Selected Playlists")?.withSymbolConfiguration(bulkDelConfig)
        playlistBulkDeleteButton.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        playlistBulkDeleteButton.toolTip = "Delete Selected Playlists"
        playlistBulkDeleteButton.target = self
        playlistBulkDeleteButton.action = #selector(handleBulkDeletePlaylists)
        playlistBulkDeleteButton.isHidden = true
        playlistBulkDeleteButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playlistBulkDeleteButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

        playlistSelectionDoneButton.translatesAutoresizingMaskIntoConstraints = false
        playlistSelectionDoneButton.title = "Done"
        playlistSelectionDoneButton.font = NSFont.systemFont(ofSize: 10.5, weight: .bold)
        playlistSelectionDoneButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        playlistSelectionDoneButton.toolTip = "Exit Selection Mode"
        playlistSelectionDoneButton.target = self
        playlistSelectionDoneButton.action = #selector(handleTogglePlaylistSelectionMode)
        playlistSelectionDoneButton.isBordered = false
        playlistSelectionDoneButton.wantsLayer = true
        playlistSelectionDoneButton.layer?.cornerRadius = 11
        playlistSelectionDoneButton.layer?.borderWidth = 1.0
        playlistSelectionDoneButton.layer?.borderColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.35).cgColor
        playlistSelectionDoneButton.layer?.backgroundColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.12).cgColor
        playlistSelectionDoneButton.isHidden = true
        playlistSelectionDoneButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        playlistSelectionDoneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true

        let subHeaderSpacer = NSView()
        subHeaderSpacer.translatesAutoresizingMaskIntoConstraints = false
        subHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let subHeaderStack = NSStackView(views: [
            playlistDetailBackButton,
            playlistSectionLabel,
            subHeaderSpacer
        ])
        subHeaderStack.orientation = .horizontal
        subHeaderStack.alignment = .centerY
        subHeaderStack.spacing = 8
        subHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        playlistHeaderStack = subHeaderStack

        let actionsTrailingStack = NSStackView(views: [
            downloadsPlayAllButton,
            downloadsShuffleButton,
            likedPlayAllButton,
            likedShuffleButton,
            historyPlayAllButton,
            historyShuffleButton,
            playlistBulkDeleteButton,
            playlistSelectionDoneButton,
            playlistDetailPlayAllButton,
            playlistDetailShuffleButton,
            playlistDetailDownloadAllButton,
            playlistDetailRenameButton,
            playlistDetailAddButton,
            playlistDetailDeleteButton
        ])
        actionsTrailingStack.orientation = .horizontal
        actionsTrailingStack.alignment = .centerY
        actionsTrailingStack.spacing = 6
        actionsTrailingStack.translatesAutoresizingMaskIntoConstraints = false
        playlistActionRowStack = actionsTrailingStack

        // Search Field
        let playlistSearch = GlassSearchField()
        playlistSearch.translatesAutoresizingMaskIntoConstraints = false
        playlistSearch.placeholderString = "Search your library…"
        playlistSearch.identifier = NSUserInterfaceItemIdentifier("PlaylistPickerSearch")
        playlistSearch.target = self
        playlistSearch.action = #selector(handlePlaylistSearchChanged(_:))
        playlistSearch.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        playlistSearch.applyPlaylistContainerStyle(tone: currentSettingsTone())
        playlistSearch.wantsLayer = true
        playlistSearch.layer?.shadowColor = NSColor.black.cgColor
        playlistSearch.layer?.shadowOpacity = 0.22
        playlistSearch.layer?.shadowRadius = 5
        playlistSearch.layer?.shadowOffset = CGSize(width: 0, height: 1)
        if let searchCell = playlistSearch.cell as? NSSearchFieldCell {
            let iconCell = NSButtonCell()
            let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            iconCell.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(iconConfig)
            iconCell.isBordered = false
            iconCell.highlightsBy = []
            iconCell.showsStateBy = []
            iconCell.imageScaling = .scaleProportionallyDown
            searchCell.searchButtonCell = iconCell
        }
        playlistSearchField = playlistSearch

        // Inline Create Playlist Bar
        inlineCreateContainer.translatesAutoresizingMaskIntoConstraints = false
        inlineCreateContainer.wantsLayer = true
        inlineCreateContainer.layer?.cornerRadius = 14
        inlineCreateContainer.layer?.borderWidth = 1.0
        inlineCreateContainer.layer?.shadowColor = NSColor.black.cgColor
        inlineCreateContainer.layer?.shadowOpacity = 0.22
        inlineCreateContainer.layer?.shadowRadius = 5
        inlineCreateContainer.layer?.shadowOffset = CGSize(width: 0, height: 1)
        inlineCreateContainer.isHidden = true

        inlineCreateTextField.translatesAutoresizingMaskIntoConstraints = false
        inlineCreateTextField.placeholderString = "Enter playlist name..."
        inlineCreateTextField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        inlineCreateTextField.isBordered = false
        inlineCreateTextField.drawsBackground = false
        inlineCreateTextField.focusRingType = .none
        inlineCreateTextField.target = self
        inlineCreateTextField.action = #selector(handleInlineCreateConfirm)

        let inlineConfirmBtn = ReactiveIconButton()
        inlineConfirmBtn.translatesAutoresizingMaskIntoConstraints = false
        let confirmConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        inlineConfirmBtn.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Create")?.withSymbolConfiguration(confirmConfig)
        inlineConfirmBtn.contentTintColor = NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
        inlineConfirmBtn.toolTip = "Create (Return)"
        inlineConfirmBtn.target = self
        inlineConfirmBtn.action = #selector(handleInlineCreateConfirm)
        inlineConfirmBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        inlineConfirmBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let inlineCancelBtn = ReactiveIconButton()
        inlineCancelBtn.translatesAutoresizingMaskIntoConstraints = false
        let cancelConfig = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
        inlineCancelBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel")?.withSymbolConfiguration(cancelConfig)
        inlineCancelBtn.contentTintColor = NSColor(white: 0.60, alpha: 1.0)
        inlineCancelBtn.toolTip = "Cancel"
        inlineCancelBtn.target = self
        inlineCancelBtn.action = #selector(handleInlineCreateCancel)
        inlineCancelBtn.widthAnchor.constraint(equalToConstant: 18).isActive = true
        inlineCancelBtn.heightAnchor.constraint(equalToConstant: 18).isActive = true

        inlineCreateContainer.addSubview(inlineCreateTextField)
        inlineCreateContainer.addSubview(inlineConfirmBtn)
        inlineCreateContainer.addSubview(inlineCancelBtn)

        NSLayoutConstraint.activate([
            inlineCreateTextField.leadingAnchor.constraint(equalTo: inlineCreateContainer.leadingAnchor, constant: 6),
            inlineCreateTextField.centerYAnchor.constraint(equalTo: inlineCreateContainer.centerYAnchor),
            inlineCreateTextField.trailingAnchor.constraint(equalTo: inlineConfirmBtn.leadingAnchor, constant: -4),

            inlineConfirmBtn.trailingAnchor.constraint(equalTo: inlineCancelBtn.leadingAnchor, constant: -2),
            inlineConfirmBtn.centerYAnchor.constraint(equalTo: inlineCreateContainer.centerYAnchor),

            inlineCancelBtn.trailingAnchor.constraint(equalTo: inlineCreateContainer.trailingAnchor, constant: -4),
            inlineCancelBtn.centerYAnchor.constraint(equalTo: inlineCreateContainer.centerYAnchor)
        ])

        let createWidthAnchor = inlineCreateContainer.widthAnchor.constraint(equalToConstant: 0)
        createWidthAnchor.isActive = true
        playlistCreateWidthAnchor = createWidthAnchor

        // Dedicated Action Row with Search on Left and Context Actions on Right
        let dedicatedActionRow = NSView()
        dedicatedActionRow.translatesAutoresizingMaskIntoConstraints = false

        dedicatedActionRow.addSubview(playlistSearch)
        dedicatedActionRow.addSubview(inlineCreateContainer)
        dedicatedActionRow.addSubview(actionsTrailingStack)

        NSLayoutConstraint.activate([
            playlistSearch.leadingAnchor.constraint(equalTo: dedicatedActionRow.leadingAnchor, constant: 4),
            playlistSearch.centerYAnchor.constraint(equalTo: dedicatedActionRow.centerYAnchor),
            playlistSearch.trailingAnchor.constraint(equalTo: actionsTrailingStack.leadingAnchor, constant: -8),

            inlineCreateContainer.leadingAnchor.constraint(equalTo: dedicatedActionRow.leadingAnchor, constant: 4),
            inlineCreateContainer.trailingAnchor.constraint(equalTo: dedicatedActionRow.trailingAnchor),
            inlineCreateContainer.centerYAnchor.constraint(equalTo: dedicatedActionRow.centerYAnchor),

            actionsTrailingStack.trailingAnchor.constraint(equalTo: dedicatedActionRow.trailingAnchor),
            actionsTrailingStack.centerYAnchor.constraint(equalTo: dedicatedActionRow.centerYAnchor)
        ])

        let topControlsStack = NSStackView(views: [
            subHeaderStack,
            libraryNavContainer,
            dedicatedActionRow,
            librarySectionHeaderLabel
        ])
        topControlsStack.orientation = .vertical
        topControlsStack.spacing = 7
        topControlsStack.alignment = .leading
        topControlsStack.translatesAutoresizingMaskIntoConstraints = false

        // Vertical List in Scroll View
        playlistsStackView.orientation = .vertical
        playlistsStackView.alignment = .leading
        playlistsStackView.spacing = 5
        playlistsStackView.translatesAutoresizingMaskIntoConstraints = false

        let playlistScroll = NSScrollView()
        playlistScroll.translatesAutoresizingMaskIntoConstraints = false
        playlistScroll.hasVerticalScroller = false
        playlistScroll.drawsBackground = false
        playlistScroll.borderType = .noBorder

        let clipView = SettingsFlippedClipView()
        clipView.drawsBackground = false
        playlistScroll.contentView = clipView
        playlistScroll.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaylistScrollBoundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: clipView)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsPlaybackStateChanged(_:)), name: NSNotification.Name("Mooziac_PlaybackStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsDownloadProgress(_:)), name: DownloadManager.progressNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaylistsUpdated), name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)

        let docView = SettingsFlippedDocView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(playlistsStackView)
        detailStackView.orientation = .vertical
        detailStackView.alignment = .leading
        detailStackView.spacing = 5
        detailStackView.translatesAutoresizingMaskIntoConstraints = false
        detailStackView.isHidden = true
        docView.addSubview(detailStackView)
        playlistScroll.documentView = docView
        playlistScrollView = playlistScroll

        let playlistsTopConstraint = playlistsStackView.topAnchor.constraint(equalTo: docView.topAnchor)
        let detailTopConstraint = detailStackView.topAnchor.constraint(equalTo: docView.topAnchor)
        playlistsStackTopConstraint = playlistsTopConstraint
        detailStackTopConstraint = detailTopConstraint
        let docHeightConstraint = docView.heightAnchor.constraint(equalToConstant: 100)
        playlistWindowHeightConstraint = docHeightConstraint
        NSLayoutConstraint.activate([
            playlistsTopConstraint,
            playlistsStackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            playlistsStackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            detailTopConstraint,
            detailStackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            detailStackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            docHeightConstraint,
            docView.widthAnchor.constraint(equalTo: playlistScroll.widthAnchor)
        ])

        subView.addSubview(topControlsStack)
        subView.addSubview(playlistScroll)

        let isGlass = PlayerDesign.current == .glassMode
        let isDark = (PlayerDesign.current == .darkMode)
        let cyan = isGlass ? NSColor.lightThemeSelector : (isDark ? NSColor.darkThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))

        let footerButton = NSButton()
        footerButton.translatesAutoresizingMaskIntoConstraints = false
        footerButton.title = "+  Create Playlist"
        footerButton.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        footerButton.isBordered = false
        footerButton.wantsLayer = true
        footerButton.layer?.cornerRadius = 13
        footerButton.layer?.borderWidth = 1.0
        footerButton.contentTintColor = cyan
        footerButton.layer?.borderColor = cyan.withAlphaComponent(0.40).cgColor
        footerButton.layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.10 : 0.15).cgColor
        footerButton.layer?.shadowColor = NSColor.black.cgColor
        footerButton.layer?.shadowOpacity = 0.35
        footerButton.layer?.shadowRadius = 7
        footerButton.layer?.shadowOffset = CGSize(width: 0, height: 3)
        footerButton.target = self
        footerButton.action = #selector(handleCreateNewPlaylistFromHeader)
        playlistCreateFooterButton = footerButton
        subView.addSubview(footerButton)

        NSLayoutConstraint.activate([
            topControlsStack.topAnchor.constraint(equalTo: subView.topAnchor, constant: 4),
            topControlsStack.leadingAnchor.constraint(equalTo: subView.leadingAnchor),
            topControlsStack.trailingAnchor.constraint(equalTo: subView.trailingAnchor),

            subHeaderStack.widthAnchor.constraint(equalTo: topControlsStack.widthAnchor),
            subHeaderStack.heightAnchor.constraint(equalToConstant: 24),

            libraryNavContainer.widthAnchor.constraint(equalTo: topControlsStack.widthAnchor),
            libraryNavContainer.heightAnchor.constraint(equalToConstant: 48),

            libraryNavStack.topAnchor.constraint(equalTo: libraryNavContainer.topAnchor),
            libraryNavStack.leadingAnchor.constraint(equalTo: libraryNavContainer.leadingAnchor),
            libraryNavStack.trailingAnchor.constraint(equalTo: libraryNavContainer.trailingAnchor),
            libraryNavStack.bottomAnchor.constraint(equalTo: libraryNavContainer.bottomAnchor),

            librarySectionHeaderLabel.widthAnchor.constraint(equalTo: topControlsStack.widthAnchor),
            librarySectionHeaderLabel.heightAnchor.constraint(equalToConstant: 12),

            dedicatedActionRow.widthAnchor.constraint(equalTo: topControlsStack.widthAnchor),
            dedicatedActionRow.heightAnchor.constraint(equalToConstant: 32),

            playlistSearch.heightAnchor.constraint(equalToConstant: 28),
            inlineCreateContainer.heightAnchor.constraint(equalToConstant: 28),

            playlistScroll.topAnchor.constraint(equalTo: topControlsStack.bottomAnchor, constant: 8),
            playlistScroll.leadingAnchor.constraint(equalTo: subView.leadingAnchor),
            playlistScroll.trailingAnchor.constraint(equalTo: subView.trailingAnchor),
            playlistScroll.bottomAnchor.constraint(equalTo: subView.bottomAnchor, constant: -4),

            footerButton.centerXAnchor.constraint(equalTo: subView.centerXAnchor),
            footerButton.bottomAnchor.constraint(equalTo: subView.bottomAnchor, constant: -10),
            footerButton.heightAnchor.constraint(equalToConstant: 26),
            footerButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            footerButton.leadingAnchor.constraint(greaterThanOrEqualTo: subView.leadingAnchor, constant: 12),
            footerButton.trailingAnchor.constraint(lessThanOrEqualTo: subView.trailingAnchor, constant: -12)
        ])

        settingsContainerView.addSubview(mainStack)
        settingsContainerView.addSubview(subView)
        setupGestureMappingSubView()

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: settingsContainerView.topAnchor, constant: 4),
            mainStack.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: -4),

            subView.topAnchor.constraint(equalTo: settingsContainerView.topAnchor, constant: 4),
            subView.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 4),
            subView.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -4),
            subView.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: -4),

            featuresStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            versionLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            versionLabel.heightAnchor.constraint(equalToConstant: 14),

            themeRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor),
            progressRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor),
            volumeRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor),
            gesturesRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor),
            lyricsRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor),
            discordRow.widthAnchor.constraint(equalTo: featuresStack.widthAnchor)
        ])

        showMainSettingsView()
        updateSettingsThemeHighlight()
    }

    @objc private func handleClosePlaylistPanel() {
        collapseSettings()
    }

    @objc public func showMainSettingsView() {
        if let mainStack = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("MainSettingsStack") }) {
            mainStack.isHidden = false
        }
        if let subView = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("PlaylistSubView") }) {
            subView.isHidden = true
        }
        settingsHeaderLabel.isHidden = false
    }

    public func showAddToPlaylistSubView() {
        if let mainStack = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("MainSettingsStack") }) {
            mainStack.isHidden = true
        }
        if let subView = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("PlaylistSubView") }) {
            subView.isHidden = false
        }
        settingsHeaderLabel.isHidden = true
        playlistDetailMode = nil
        playlistAddMode = false
        isPlaylistSearchActive = true
        isPlaylistCreateOpen = false
        resetPlaylistSectionChrome()
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }
}
