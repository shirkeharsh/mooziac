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

    public func showMainSettingsView() {
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

    private func selectLibraryTab(_ tab: LibraryTab) {
        guard tab != activeLibraryTab else { return }
        activeLibraryTab = tab
        isPlaylistSearchActive = true
        isPlaylistCreateOpen = false
        isPlaylistSelectionMode = false
        selectedPlaylistIDs.removeAll()
        playlistSearchField?.stringValue = ""
        inlineCreateTextField.stringValue = ""
        resetPlaylistSectionChrome()
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handleLibraryNavTapped(_ sender: LibraryNavButton) {
        selectLibraryTab(sender.libraryTab)
    }

    private func resetPlaylistSectionChrome() {
        if let playlist = playlistDetailMode {
            playlistSectionLabel.isHidden = false
            playlistSectionLabel.stringValue = playlist.name.uppercased()
            playlistHeaderStack?.isHidden = false
            libraryNavContainer.isHidden = true
            playlistDetailBackButton.isHidden = false
            playlistDetailCreateButton.isHidden = true
            playlistSearchToggleButton.isHidden = true
            playlistBulkDeleteButton.isHidden = true
            playlistSelectionDoneButton.isHidden = true
            playlistActionRowStack?.isHidden = false
            downloadsPlayAllButton.isHidden = true
            downloadsShuffleButton.isHidden = true
            likedPlayAllButton.isHidden = true
            likedShuffleButton.isHidden = true
            historyPlayAllButton.isHidden = true
            historyShuffleButton.isHidden = true

            if playlistAddMode {
                playlistDetailDeleteButton.isHidden = true
                playlistDetailAddButton.isHidden = true
                playlistDetailPlayAllButton.isHidden = true
                playlistDetailShuffleButton.isHidden = true
                playlistDetailDownloadAllButton.isHidden = true
                playlistActionRowStack?.isHidden = true
                if let search = playlistSearchField {
                    search.placeholderString = "Search all songs..."
                }
            } else {
                playlistDetailDeleteButton.isHidden = false
                playlistDetailAddButton.isHidden = false
                playlistDetailPlayAllButton.isHidden = false
                playlistDetailShuffleButton.isHidden = false
                playlistDetailDownloadAllButton.isHidden = false
                if let search = playlistSearchField {
                    search.placeholderString = "Search \(playlist.name)..."
                }
            }
            playlistsStackView.isHidden = true
            detailStackView.isHidden = false
            playlistScrollView?.isHidden = false
        } else {
            playlistSectionLabel.isHidden = true
            playlistHeaderStack?.isHidden = true
            libraryNavContainer.isHidden = false
            for btn in libraryNavButtons {
                btn.isSelected = (btn.libraryTab == activeLibraryTab)
            }
            playlistDetailBackButton.isHidden = true
            playlistDetailPlayAllButton.isHidden = true
            playlistDetailShuffleButton.isHidden = true
            playlistDetailDownloadAllButton.isHidden = true
            playlistDetailDeleteButton.isHidden = true
            playlistDetailAddButton.isHidden = true
            playlistActionRowStack?.isHidden = false

            switch activeLibraryTab {
            case .playlists:
                playlistSearchToggleButton.isHidden = false
                playlistBulkDeleteButton.isHidden = !isPlaylistSelectionMode
                playlistSelectionDoneButton.isHidden = !isPlaylistSelectionMode
                downloadsPlayAllButton.isHidden = true
                downloadsShuffleButton.isHidden = true
                likedPlayAllButton.isHidden = true
                likedShuffleButton.isHidden = true
                historyPlayAllButton.isHidden = true
                historyShuffleButton.isHidden = true
                if let search = playlistSearchField {
                    search.placeholderString = "Search playlists..."
                }

            case .likedSongs:
                playlistDetailCreateButton.isHidden = true
                playlistSearchToggleButton.isHidden = false
                playlistBulkDeleteButton.isHidden = true
                playlistSelectionDoneButton.isHidden = true
                downloadsPlayAllButton.isHidden = true
                downloadsShuffleButton.isHidden = true
                likedPlayAllButton.isHidden = false
                likedShuffleButton.isHidden = false
                historyPlayAllButton.isHidden = true
                historyShuffleButton.isHidden = true
                if let search = playlistSearchField {
                    search.placeholderString = "Search liked songs..."
                }

            case .downloads:
                playlistDetailCreateButton.isHidden = true
                playlistSearchToggleButton.isHidden = false
                playlistBulkDeleteButton.isHidden = true
                playlistSelectionDoneButton.isHidden = true
                downloadsPlayAllButton.isHidden = false
                downloadsShuffleButton.isHidden = false
                likedPlayAllButton.isHidden = true
                likedShuffleButton.isHidden = true
                historyPlayAllButton.isHidden = true
                historyShuffleButton.isHidden = true
                if let search = playlistSearchField {
                    search.placeholderString = "Search downloaded tracks..."
                }

            case .history:
                playlistDetailCreateButton.isHidden = true
                playlistSearchToggleButton.isHidden = false
                playlistBulkDeleteButton.isHidden = true
                playlistSelectionDoneButton.isHidden = true
                downloadsPlayAllButton.isHidden = true
                downloadsShuffleButton.isHidden = true
                likedPlayAllButton.isHidden = true
                likedShuffleButton.isHidden = true
                historyPlayAllButton.isHidden = false
                historyShuffleButton.isHidden = false
                if let search = playlistSearchField {
                    search.placeholderString = "Search listening history..."
                }
            }

            playlistsStackView.isHidden = false
            detailStackView.isHidden = true
            playlistScrollView?.isHidden = false
        }
        playlistCreateFooterButton?.isHidden = (playlistDetailMode != nil) || (activeLibraryTab != .playlists) || isPlaylistSelectionMode || isPlaylistCreateOpen
        updatePlaylistSearchToggleIcon()
        updatePlaylistCreateButtonIcon(isCreating: isPlaylistCreateOpen)
    }

    private func applySearchCreateFieldState(animated: Bool) {
        var searchOpen = isPlaylistSearchActive
        var createOpen = isPlaylistCreateOpen
        if playlistDetailMode != nil {
            searchOpen = true
            createOpen = false
        } else {
            if createOpen { searchOpen = false }
            if searchOpen { createOpen = false }
        }
        if searchOpen {
            expandSearchField(animated: animated)
            collapseCreateField(animated: animated)
        } else if createOpen {
            collapseSearchField(animated: animated)
            expandCreateField(animated: animated)
        } else {
            collapseSearchField(animated: animated)
            collapseCreateField(animated: animated)
        }
    }

    private func expandSearchField(animated: Bool) {
        guard let field = playlistSearchField else { return }
        searchFieldStateToken += 1
        field.isHidden = false
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                field.animator().alphaValue = 1.0
            }
        } else {
            field.alphaValue = 1.0
        }
    }

    private func collapseSearchField(animated: Bool) {
        guard let field = playlistSearchField else { return }
        if animated {
            let token = searchFieldStateToken
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                field.animator().alphaValue = 0.0
            }, completionHandler: {
                if token == self.searchFieldStateToken {
                    field.isHidden = true
                }
            })
        } else {
            searchFieldStateToken += 1
            field.alphaValue = 0.0
            field.isHidden = true
        }
    }

    private func expandCreateField(animated: Bool) {
        createFieldStateToken += 1
        inlineCreateContainer.isHidden = false
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                inlineCreateContainer.animator().alphaValue = 1.0
            }
        } else {
            inlineCreateContainer.alphaValue = 1.0
        }
    }

    private func collapseCreateField(animated: Bool) {
        if animated {
            let token = createFieldStateToken
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                inlineCreateContainer.animator().alphaValue = 0.0
            }, completionHandler: {
                if token == self.createFieldStateToken {
                    self.inlineCreateContainer.isHidden = true
                }
            })
        } else {
            createFieldStateToken += 1
            inlineCreateContainer.alphaValue = 0.0
            inlineCreateContainer.isHidden = true
        }
    }

    @objc private func handlePlaylistSearchChanged(_ sender: NSSearchField) {
        refreshPlaylistsSection(filterQuery: sender.stringValue)
    }

    func updatePlaylistSearchToggleIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        playlistSearchToggleButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(config)
        playlistSearchToggleButton.toolTip = isPlaylistSearchActive ? "Close Search" : "Search Playlists"
    }

    @objc private func handlePlaylistSearchToggle() {
        if isPlaylistCreateOpen {
            isPlaylistCreateOpen = false
            updatePlaylistCreateButtonIcon(isCreating: false)
            collapseCreateField(animated: true)
        }
        isPlaylistSearchActive.toggle()
        if isPlaylistSearchActive {
            if isPlaylistSelectionMode {
                isPlaylistSelectionMode = false
                selectedPlaylistIDs.removeAll()
            }
            playlistSearchField?.stringValue = ""
            resetPlaylistSectionChrome()
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
            expandSearchField(animated: true)
            window?.makeFirstResponder(playlistSearchField)
        } else {
            playlistSearchField?.stringValue = ""
            window?.makeFirstResponder(nil)
            collapseSearchField(animated: true)
            resetPlaylistSectionChrome()
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    @objc private func handleTogglePlaylistSelectionMode() {
        isPlaylistSelectionMode.toggle()
        if !isPlaylistSelectionMode {
            selectedPlaylistIDs.removeAll()
        }
        if isPlaylistSearchActive {
            isPlaylistSearchActive = false
            playlistSearchField?.stringValue = ""
            window?.makeFirstResponder(nil)
            collapseSearchField(animated: true)
        }
        resetPlaylistSectionChrome()
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handlePlaylistContextAddCurrentPlaying(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) else { return }
        let res = PlaylistManager.shared.appendCurrentPlayingTrack(to: id)
        if res.success {
            showToastBanner(message: "✓ Added to \"\(playlist.name)\"")
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        } else {
            showToastBanner(message: res.message, isWarning: true)
        }
    }

    @objc private func handlePlaylistContextSelect(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        if !isPlaylistSelectionMode {
            isPlaylistSelectionMode = true
            if isPlaylistSearchActive {
                isPlaylistSearchActive = false
                playlistSearchField?.stringValue = ""
                window?.makeFirstResponder(nil)
                collapseSearchField(animated: true)
            }
        }
        if selectedPlaylistIDs.contains(id) {
            selectedPlaylistIDs.remove(id)
        } else {
            selectedPlaylistIDs.insert(id)
        }
        resetPlaylistSectionChrome()
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handlePlaylistContextDelete(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) else { return }
        confirmAndDeletePlaylistFromRow(playlist)
    }

    @objc private func handleBulkDeletePlaylists() {
        guard !selectedPlaylistIDs.isEmpty else {
            showToastBanner(message: "⚠️ No playlists selected", isWarning: true)
            return
        }
        let count = selectedPlaylistIDs.count
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete Playlists"
        alert.informativeText = "Delete \(count) selected playlist\(count == 1 ? "" : "s")? This cannot be undone."
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Delete")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            for id in selectedPlaylistIDs {
                PlaylistManager.shared.deletePlaylist(id: id)
            }
            selectedPlaylistIDs.removeAll()
            isPlaylistSelectionMode = false
            showToastBanner(message: "🗑 Deleted \(count) playlist\(count == 1 ? "" : "s")")
            resetPlaylistSectionChrome()
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    public func refreshPlaylistsSection(filterQuery: String = "") {
        playlistBuildToken += 1
        pendingRowBuilders = []
        playlistBuildStack = nil
        playlistMountedRows.removeAll()
        playlistIsReordering = false
        resetPlaylistSectionChrome()
        playlistsStackView.subviews.forEach { $0.removeFromSuperview() }
        detailStackView.subviews.forEach { $0.removeFromSuperview() }

        let tone = currentSettingsTone()

        if let playlist = playlistDetailMode {
            renderPlaylistDetail(playlist, tone: tone, filterQuery: filterQuery)
            return
        }

        let trimmedQuery = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        librarySectionHeaderLabel.isHidden = false
        switch activeLibraryTab {
        case .playlists:
            librarySectionHeaderLabel.stringValue = trimmedQuery.isEmpty ? "YOUR PLAYLISTS" : "SEARCH RESULTS"
        case .likedSongs:
            librarySectionHeaderLabel.stringValue = trimmedQuery.isEmpty ? "LIKED SONGS" : "SEARCH RESULTS"
        case .downloads:
            librarySectionHeaderLabel.stringValue = trimmedQuery.isEmpty ? "DOWNLOADS" : "SEARCH RESULTS"
        case .history:
            librarySectionHeaderLabel.stringValue = trimmedQuery.isEmpty ? "LISTENING HISTORY" : "SEARCH RESULTS"
        }

        var builders: [() -> NSView] = []
        var emptyText: String?

        switch activeLibraryTab {
        case .playlists:
            var playlists = PlaylistManager.shared.fetchPlaylists()
            if !trimmedQuery.isEmpty {
                playlists = playlists.filter { $0.name.lowercased().contains(trimmedQuery) }
            }
            if playlists.isEmpty {
                emptyText = trimmedQuery.isEmpty ? "No playlists yet. Click '+ Create Playlist' below to make one." : "No matching playlists found"
            } else {
                builders = playlists.map { playlist in
                    { [weak self] in self?.makePlaylistRow(playlist: playlist, tone: tone) ?? NSView() }
                }
            }

        case .likedSongs:
            var liked = LikedSongsManager.shared.fetchLikedSongs()
            if !isLibrarySearchActive {
                liked = applyCustomOrder(liked, storedOrder: storedOrder(for: likedSongsOrderKey)) { $0.videoId }
            }
            if !trimmedQuery.isEmpty {
                liked = liked.filter { $0.title.lowercased().contains(trimmedQuery) || $0.artist.lowercased().contains(trimmedQuery) }
            }
            if liked.isEmpty {
                emptyText = trimmedQuery.isEmpty ? "No liked songs yet. Like songs while playing to see them here." : "No matching liked songs found"
            } else {
                builders = liked.map { record in
                    { [weak self] in self?.makeLikedSongRow(record: record, tone: tone) ?? NSView() }
                }
            }

        case .downloads:
            var tracks = LocalLibraryManager.shared.allTracks
            if !isLibrarySearchActive {
                tracks = applyCustomOrder(tracks, storedOrder: storedOrder(for: downloadsOrderKey)) { $0.id }
            }
            let all = tracks
            if !trimmedQuery.isEmpty {
                tracks = tracks.filter { $0.title.lowercased().contains(trimmedQuery) || $0.artist.lowercased().contains(trimmedQuery) }
            }
            if tracks.isEmpty {
                emptyText = trimmedQuery.isEmpty ? "No downloaded songs yet." : "No matching downloaded songs found"
            } else {
                builders = tracks.map { track in
                    { [weak self] in self?.makeDownloadRow(track: track, allTracks: all, tone: tone) ?? NSView() }
                }
            }

        case .history:
            var history = HistoryManager.shared.fetchHistory(limit: 100)
            if !isLibrarySearchActive {
                history = applyCustomOrder(history, storedOrder: storedOrder(for: historyOrderKey)) { $0.id }
            }
            if !trimmedQuery.isEmpty {
                history = history.filter { $0.title.lowercased().contains(trimmedQuery) || $0.artist.lowercased().contains(trimmedQuery) }
            }
            if history.isEmpty {
                emptyText = trimmedQuery.isEmpty ? "No listening history yet." : "No matching history found"
            } else {
                builders = history.map { record in
                    { [weak self] in self?.makeHistoryRow(record: record, tone: tone) ?? NSView() }
                }
            }
        }

        if let empty = emptyText {
            let emptyLabel = NSTextField(labelWithString: empty)
            emptyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            emptyLabel.textColor = tone.secondaryText
            emptyLabel.isEditable = false
            emptyLabel.isSelectable = false
            emptyLabel.refusesFirstResponder = true
            playlistsStackView.addArrangedSubview(emptyLabel)
            setPlaylistDocViewHeight(emptyLabel.fittingSize.height + 8)
            return
        }
        scheduleIncrementalBuild(builders, into: playlistsStackView)
    }

    private func scheduleIncrementalBuild(_ builders: [() -> NSView], into stack: NSStackView, initialBatchSize: Int = 35) {
        pendingRowBuilders = builders
        playlistBuildStack = stack
        playlistBuildChunkIndex = 0
        playlistMountedRows.removeAll()
        stack.subviews.forEach { $0.removeFromSuperview() }
        playlistRowHeight = (stack === playlistsStackView) ? 44 : 40
        playlistActiveStackTopConstraint = (stack === playlistsStackView) ? playlistsStackTopConstraint : detailStackTopConstraint
        setPlaylistDocViewHeight(CGFloat(builders.count) * (playlistRowHeight + 5) + 46)
        playlistScrollView?.contentView.scroll(to: .zero)
        updateMountedPlaylistWindow()
    }

    private func setPlaylistDocViewHeight(_ height: CGFloat) {
        if let constraint = playlistWindowHeightConstraint {
            constraint.constant = max(height, 1)
        }
    }

    private func updateMountedPlaylistWindow() {
        guard let stack = playlistBuildStack, !pendingRowBuilders.isEmpty else { return }
        if playlistIsReordering { return }
        guard let clipView = playlistScrollView?.contentView else {
            mountAllPlaylistRows()
            return
        }
        let stride = playlistRowHeight + 5
        let visibleMin = clipView.bounds.minY
        let visibleMax = clipView.bounds.maxY
        let buffer = clipView.bounds.height * playlistWindowBuffer
        let startIndex = max(0, Int(floor((visibleMin - buffer) / stride)))
        let endIndex = min(pendingRowBuilders.count - 1, Int(ceil((visibleMax + buffer) / stride)))
        guard startIndex <= endIndex else { return }

        let removeKeys = playlistMountedRows.filter { $0.key < startIndex || $0.key > endIndex }.map { $0.key }
        for idx in removeKeys {
            if let view = playlistMountedRows.removeValue(forKey: idx) {
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        var mountedIndices = playlistMountedRows.keys.sorted()
        for idx in startIndex...endIndex where playlistMountedRows[idx] == nil {
            let row = pendingRowBuilders[idx]()
            row.translatesAutoresizingMaskIntoConstraints = false
            let insertPos = mountedIndices.filter { $0 < idx }.count
            stack.insertArrangedSubview(row, at: min(insertPos, stack.arrangedSubviews.count))
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            playlistMountedRows[idx] = row
            mountedIndices.insert(idx, at: insertPos)
            applyMountedRowState(row)
        }

        if let first = playlistMountedRows.keys.min() {
            playlistActiveStackTopConstraint?.constant = CGFloat(first) * stride
        }
    }

    private func mountAllPlaylistRows() {
        guard let stack = playlistBuildStack else { return }
        var mountedIndices = playlistMountedRows.keys.sorted()
        for idx in 0..<pendingRowBuilders.count where playlistMountedRows[idx] == nil {
            let row = pendingRowBuilders[idx]()
            row.translatesAutoresizingMaskIntoConstraints = false
            let insertPos = mountedIndices.filter { $0 < idx }.count
            stack.insertArrangedSubview(row, at: min(insertPos, stack.arrangedSubviews.count))
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            playlistMountedRows[idx] = row
            mountedIndices.insert(idx, at: insertPos)
            applyMountedRowState(row)
        }
        playlistActiveStackTopConstraint?.constant = 0
    }

    private func applyMountedRowState(_ row: NSView) {
        guard let container = row as? SwipeToDeleteContainerView else { return }
        let tone = currentSettingsTone()
        for sub in container.contentCardView.subviews {
            if let r = sub as? LikedSongRowView { r.updatePlayingAppearance(tone: tone) }
            else if let r = sub as? DownloadRowView { r.updatePlayingAppearance(tone: tone) }
            else if let r = sub as? DetailItemRowView { r.updatePlayingAppearance(tone: tone) }
            else if let r = sub as? HistoryRowView { r.updatePlayingAppearance(tone: tone) }
        }
        for sub in container.contentCardView.subviews {
            if let r = sub as? DetailItemRowView {
                if let info = DownloadManager.shared.statusFor(id: r.item.id, videoId: r.item.ytVideoId ?? r.item.refID) {
                    r.applyDownloadProgress(statusStr: downloadStatusString(info.status), progress: info.progress, eta: info.eta)
                }
            } else if let r = sub as? HistoryRowView {
                if let info = DownloadManager.shared.statusFor(id: r.record.id, videoId: r.record.ytVideoId) {
                    r.applyDownloadProgress(statusStr: downloadStatusString(info.status), progress: info.progress, eta: info.eta)
                }
            }
        }
    }

    private func downloadStatusString(_ status: DownloadStatus) -> String {
        switch status {
        case .queued: return "queued"
        case .downloading: return "downloading"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }

    @objc private func handlePlaylistScrollBoundsDidChange(_ notification: Notification) {
        updateMountedPlaylistWindow()
    }

    @objc private func handleSettingsPlaybackStateChanged(_ notification: Notification) {
        updatePlayingRowHighlight()
    }

    @objc private func handleSettingsDownloadProgress(_ notification: Notification) {
        updateDownloadProgressInVisibleRows(notif: notification)
    }

    public func updatePlayingRowHighlight() {
        let tone = currentSettingsTone()
        let activeStack = (playlistDetailMode != nil || playlistAddMode) ? detailStackView : playlistsStackView
        for view in activeStack.arrangedSubviews {
            if let container = view as? SwipeToDeleteContainerView {
                for sub in container.contentCardView.subviews {
                    if let row = sub as? LikedSongRowView { row.updatePlayingAppearance(tone: tone) }
                    else if let row = sub as? DownloadRowView { row.updatePlayingAppearance(tone: tone) }
                    else if let row = sub as? DetailItemRowView { row.updatePlayingAppearance(tone: tone) }
                    else if let row = sub as? HistoryRowView { row.updatePlayingAppearance(tone: tone) }
                }
            }
        }
    }

    public func updateDownloadProgressInVisibleRows(notif: Notification) {
        guard let info = notif.userInfo else { return }
        let noteID = info["id"] as? String
        let noteVid = info["videoId"] as? String
        let statusStr = info["status"] as? String ?? ""
        let progress = info["progress"] as? Double ?? 0.0
        let eta = info["eta"] as? String ?? ""

        let activeStack = (playlistDetailMode != nil || playlistAddMode) ? detailStackView : playlistsStackView
        for view in activeStack.arrangedSubviews {
            if let container = view as? SwipeToDeleteContainerView {
                for sub in container.contentCardView.subviews {
                    if let row = sub as? DetailItemRowView {
                        let myVid = row.item.ytVideoId ?? row.item.refID
                        if (noteID != nil && noteID == row.item.id) || (noteVid != nil && noteVid == myVid) {
                            row.applyDownloadProgress(statusStr: statusStr, progress: progress, eta: eta)
                        }
                    } else if let row = sub as? HistoryRowView {
                        let myVid = row.record.ytVideoId
                        if (noteID != nil && noteID == row.record.id) || (noteVid != nil && noteVid == myVid) {
                            row.applyDownloadProgress(statusStr: statusStr, progress: progress, eta: eta)
                        }
                    }
                }
            }
        }
    }

    func storedOrder(for key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func applyCustomOrder<T>(_ items: [T], storedOrder: [String], key: (T) -> String) -> [T] {
        guard !storedOrder.isEmpty else { return items }
        var rank: [String: Int] = [:]
        for (i, k) in storedOrder.enumerated() { rank[k] = i }
        let ordered = items.filter { rank[key($0)] != nil }.sorted { (rank[key($0)]!) < (rank[key($1)]!) }
        let rest = items.filter { rank[key($0)] == nil }
        return rest + ordered
    }

    func handleLibraryRowReorderPan(_ gesture: NSPanGestureRecognizer, keyPrefix: String?, storageKey: String?, playlistID: String?) {
        guard let gestureView = gesture.view else { return }

        var containerView: NSView = gestureView
        while let parent = containerView.superview, !(parent is NSStackView) {
            containerView = parent
        }
        guard let stack = containerView.superview as? NSStackView else { return }

        let location = gesture.location(in: stack)

        switch gesture.state {
        case .began:
            gestureView.layer?.zPosition = 100
            gestureView.layer?.shadowColor = NSColor.black.cgColor
            gestureView.layer?.shadowOpacity = 0.4
            gestureView.layer?.shadowOffset = CGSize(width: 0, height: -2)
            gestureView.layer?.shadowRadius = 6
            playlistIsReordering = true
            mountAllPlaylistRows()

        case .changed:
            let arranged = stack.arrangedSubviews
            guard let currentIndex = arranged.firstIndex(of: containerView) else { return }

            for (idx, otherView) in arranged.enumerated() where otherView != containerView {
                let otherFrame = otherView.frame
                if location.y >= otherFrame.minY && location.y <= otherFrame.maxY {
                    if idx != currentIndex {
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.2
                            context.allowsImplicitAnimation = true
                            stack.removeArrangedSubview(containerView)
                            stack.insertArrangedSubview(containerView, at: idx)
                            stack.layoutSubtreeIfNeeded()
                        }
                    }
                    break
                }
            }

        case .ended, .cancelled:
            playlistIsReordering = false
            gestureView.layer?.zPosition = 0
            gestureView.layer?.shadowOpacity = 0
            let newOrder = stack.arrangedSubviews.compactMap { view -> String? in
                guard let container = view as? SwipeToDeleteContainerView else { return nil }
                return container.identifier?.rawValue
            }
            if !newOrder.isEmpty {
                var keys = newOrder
                if let keyPrefix {
                    keys = newOrder.map { String($0.dropFirst(keyPrefix.count)) }
                }
                if let storageKey {
                    UserDefaults.standard.set(keys, forKey: storageKey)
                    if storageKey == self.downloadsOrderKey {
                        let allTracks = LocalLibraryManager.shared.allTracks
                        let ordered = self.applyCustomOrder(allTracks, storedOrder: keys) { $0.id }
                        NativeAudioPlayer.shared.updateQueueOrder(newOrder: ordered)
                    } else if storageKey == self.likedSongsOrderKey {
                        let liked = LikedSongsManager.shared.fetchLikedSongs()
                        let orderedLiked = self.applyCustomOrder(liked, storedOrder: keys) { $0.videoId }
                        let allTracks = LocalLibraryManager.shared.allTracks
                        let orderedTracks = orderedLiked.compactMap { item -> LocalTrack? in
                            allTracks.first(where: {
                                if let v = $0.ytVideoId, !v.isEmpty, v == item.videoId { return true }
                                return $0.fileURL.path == item.videoId
                            })
                        }
                        if !orderedTracks.isEmpty {
                            NativeAudioPlayer.shared.updateQueueOrder(newOrder: orderedTracks)
                        }
                    } else if storageKey == self.historyOrderKey {
                        let history = HistoryManager.shared.fetchHistory(limit: 100)
                        let orderedHistory = self.applyCustomOrder(history, storedOrder: keys) { $0.id }
                        let orderedTracks = self.resolveHistoryTracks(orderedHistory)
                        if !orderedTracks.isEmpty {
                            NativeAudioPlayer.shared.updateQueueOrder(newOrder: orderedTracks)
                        }
                    }
                    refreshPlaylistsSection()
                }
                if let playlistID {
                    PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: keys)
                    refreshPlaylistsSection()
                }
            }

        default:
            break
        }
    }

    private func renderPlaylistDetail(_ playlist: PlaylistRecord, tone: SettingsTone, filterQuery: String) {
        let trimmedQuery = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        playlistSectionLabel.stringValue = playlist.name.uppercased()
        playlistHeaderStack?.isHidden = false
        playlistDetailBackButton.isHidden = false
        playlistDetailCreateButton.isHidden = true
        playlistSearchToggleButton.isHidden = true
        playlistBulkDeleteButton.isHidden = true
        playlistSelectionDoneButton.isHidden = true
        playlistActionRowStack?.isHidden = false
        playlistDetailDeleteButton.isHidden = false
        playlistDetailAddButton.isHidden = false
        playlistSearchField?.isHidden = false

        if playlistAddMode {
            playlistDetailCreateButton.isHidden = true
            playlistDetailDeleteButton.isHidden = true
            playlistDetailAddButton.isHidden = true
            playlistDetailPlayAllButton.isHidden = true
            playlistDetailShuffleButton.isHidden = true
            playlistDetailDownloadAllButton.isHidden = true
            playlistActionRowStack?.isHidden = true
            if let search = playlistSearchField {
                search.placeholderString = "Search all songs..."
            }
            playlistsStackView.isHidden = true
            detailStackView.isHidden = false
            playlistScrollView?.isHidden = false

            var tracks = LocalLibraryManager.shared.allTracks
            if !trimmedQuery.isEmpty {
                tracks = tracks.filter { $0.title.lowercased().contains(trimmedQuery) || $0.artist.lowercased().contains(trimmedQuery) }
            }
            if tracks.isEmpty {
                let emptyLabel = NSTextField(labelWithString: trimmedQuery.isEmpty ? "No songs found in local library" : "No matching songs")
                emptyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
                emptyLabel.textColor = tone.secondaryText
                emptyLabel.isEditable = false
                emptyLabel.isSelectable = false
                emptyLabel.refusesFirstResponder = true
                detailStackView.addArrangedSubview(emptyLabel)
                setPlaylistDocViewHeight(emptyLabel.fittingSize.height + 8)
                return
            }
            let builders = tracks.map { track in
                { [weak self] in self?.makeAddSongRow(track: track, tone: tone) ?? NSView() }
            }
            scheduleIncrementalBuild(builders, into: detailStackView)
            return
        }

        playlistDetailPlayAllButton.isHidden = false
        playlistDetailShuffleButton.isHidden = false
        playlistDetailDownloadAllButton.isHidden = false
        if let search = playlistSearchField {
            search.placeholderString = "Search \(playlist.name)..."
        }
        playlistsStackView.isHidden = true
        detailStackView.isHidden = false
        playlistScrollView?.isHidden = false

        var items = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        if !trimmedQuery.isEmpty {
            items = items.filter { $0.title.lowercased().contains(trimmedQuery) || $0.artist.lowercased().contains(trimmedQuery) }
        }
        if items.isEmpty {
            let emptyLabel = NSTextField(labelWithString: trimmedQuery.isEmpty ? "No songs in this playlist yet. Tap '+ Add Songs' to add some." : "No matching songs in playlist")
            emptyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            emptyLabel.textColor = tone.secondaryText
            emptyLabel.isEditable = false
            emptyLabel.isSelectable = false
            emptyLabel.refusesFirstResponder = true
            detailStackView.addArrangedSubview(emptyLabel)
            setPlaylistDocViewHeight(emptyLabel.fittingSize.height + 8)
            return
        }
        let total = items.count
        let builders = items.enumerated().map { (idx, item) in
            { [weak self] in self?.makeDetailItemRow(item: item, index: idx, total: total, tone: tone) ?? NSView() }
        }
        scheduleIncrementalBuild(builders, into: detailStackView)
    }

    private func playlistFirstTrack(_ playlist: PlaylistRecord) -> LocalTrack? {
        let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        guard let first = items.min(by: { $0.dateAdded < $1.dateAdded }) ?? items.first else { return nil }
        let tracks = LocalLibraryManager.shared.allTracks
        if first.refType == "local" {
            return tracks.first(where: { $0.fileURL.path == first.refID })
        }
        if let vid = first.ytVideoId {
            return tracks.first(where: { $0.ytVideoId == vid })
        }
        return nil
    }

    private func playlistFirstItem(_ playlist: PlaylistRecord) -> PlaylistItemRecord? {
        let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        return items.min(by: { $0.dateAdded < $1.dateAdded }) ?? items.first
    }

    @objc private func handlePlaylistRowPlay(_ sender: ReactiveIconButton) {
        guard let id = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) else { return }
        let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: id)
        if items.isEmpty {
            showToastBanner(message: "⚠️ \"\(playlist.name)\" is empty", isWarning: true)
            return
        }
        PlaylistManager.shared.startPlaylist(playlistID: id, startingAt: nil, shuffle: false)
        showToastBanner(message: "▶ Playing \"\(playlist.name)\"")
    }

    private func makePlaylistRow(playlist: PlaylistRecord, tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier(playlist.id)

        let row = swipeContainer.contentCardView
        row.wantsLayer = true
        row.layer?.cornerRadius = 14
        row.layer?.borderWidth = 1.0
        row.layer?.borderColor = tone.dividerColor.cgColor
        row.layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor

        swipeContainer.onRowClicked = { [weak self] in
            guard let self = self else { return }
            if self.isPlaylistSelectionMode {
                if self.selectedPlaylistIDs.contains(playlist.id) {
                    self.selectedPlaylistIDs.remove(playlist.id)
                } else {
                    self.selectedPlaylistIDs.insert(playlist.id)
                }
                self.refreshPlaylistsSection()
                self.updateSettingsThemeHighlight()
            } else {
                self.playlistDetailMode = playlist
                self.playlistAddMode = false
                self.isPlaylistSearchActive = true
                self.isPlaylistCreateOpen = false
                self.playlistSearchField?.stringValue = ""
                self.resetPlaylistSectionChrome()
                self.applySearchCreateFieldState(animated: false)
                self.refreshPlaylistsSection()
                self.updateSettingsThemeHighlight()
            }
        }

        if isPlaylistSelectionMode {
            swipeContainer.onDelete = nil
            swipeContainer.onRightSwipePlay = nil
        } else {
            swipeContainer.onDelete = { [weak self] in
                self?.confirmAndDeletePlaylistFromRow(playlist)
            }

            swipeContainer.onRightSwipePlay = { [weak self] in
                guard let self = self else { return false }
                let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: playlist.id)
                if items.isEmpty {
                    self.showToastBanner(message: "⚠️ \"\(playlist.name)\" is empty", isWarning: true)
                    return false
                }
                PlaylistManager.shared.startPlaylist(playlistID: playlist.id, startingAt: nil, shuffle: false)
                self.showToastBanner(message: "▶ Playing \"\(playlist.name)\"")
                return true
            }
        }

        let artworkView = NSImageView()
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.imageScaling = .scaleProportionallyDown
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 7
        artworkView.layer?.masksToBounds = true
        artworkView.layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.06) : NSColor(white: 1.0, alpha: 0.08)).cgColor
        if let firstTrack = playlistFirstTrack(playlist), let art = firstTrack.artwork {
            artworkView.image = art
        } else if let firstItem = playlistFirstItem(playlist), !firstItem.artworkUrl.isEmpty {
            if FileManager.default.fileExists(atPath: firstItem.artworkUrl),
               let img = NSImage(contentsOfFile: firstItem.artworkUrl) {
                artworkView.image = img
            } else if let url = URL(string: firstItem.artworkUrl), url.scheme?.hasPrefix("http") == true {
                let placeholderConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                artworkView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)?.withSymbolConfiguration(placeholderConfig)
                artworkView.contentTintColor = tone.secondaryText.withAlphaComponent(0.6)
                URLSession.shared.dataTask(with: url) { [weak artworkView] data, _, _ in
                    guard let data = data, let img = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        artworkView?.image = img
                    }
                }.resume()
            } else {
                let placeholderConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                artworkView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)?.withSymbolConfiguration(placeholderConfig)
                artworkView.contentTintColor = tone.secondaryText.withAlphaComponent(0.6)
            }
        } else {
            let placeholderConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            artworkView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)?.withSymbolConfiguration(placeholderConfig)
            artworkView.contentTintColor = tone.secondaryText.withAlphaComponent(0.6)
        }

        let titleLbl = NSTextField(labelWithString: playlist.name)
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let countString = playlist.itemCount == 0 ? "Empty" : "\(playlist.itemCount) tracks"
        let countLbl = NSTextField(labelWithString: countString)
        countLbl.font = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        countLbl.textColor = tone.secondaryText
        countLbl.maximumNumberOfLines = 1
        countLbl.usesSingleLineMode = true
        countLbl.isEditable = false
        countLbl.isSelectable = false
        countLbl.refusesFirstResponder = true
        countLbl.translatesAutoresizingMaskIntoConstraints = false

        let chevronImageView = NSImageView()
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .semibold)
        chevronImageView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Open")?.withSymbolConfiguration(chevronConfig)
        chevronImageView.contentTintColor = tone.secondaryText.withAlphaComponent(0.6)

        let selectionCheckbox = NSButton(checkboxWithTitle: "", target: self, action: nil)
        selectionCheckbox.translatesAutoresizingMaskIntoConstraints = false
        selectionCheckbox.state = selectedPlaylistIDs.contains(playlist.id) ? .on : .off
        selectionCheckbox.isHighlighted = false
        selectionCheckbox.isHidden = !isPlaylistSelectionMode

        let playBtn = ReactiveIconButton()
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        let playConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playBtn.contentTintColor = rowPlayIconColor(tone: tone)
        playBtn.toolTip = "Play Playlist"
        playBtn.target = self
        playBtn.action = #selector(handlePlaylistRowPlay(_:))
        playBtn.representedObject = playlist.id
        playBtn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        playBtn.isHidden = (playlist.itemCount == 0)

        row.addSubview(artworkView)
        row.addSubview(titleLbl)
        row.addSubview(countLbl)
        row.addSubview(chevronImageView)
        row.addSubview(selectionCheckbox)
        row.addSubview(playBtn)

        swipeContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true

        if isPlaylistSelectionMode {
            playBtn.isHidden = true
            chevronImageView.isHidden = true
            NSLayoutConstraint.activate([
                selectionCheckbox.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                selectionCheckbox.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                selectionCheckbox.widthAnchor.constraint(equalToConstant: 16),
                selectionCheckbox.heightAnchor.constraint(equalToConstant: 16),

                artworkView.leadingAnchor.constraint(equalTo: selectionCheckbox.trailingAnchor, constant: 7),
                artworkView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                artworkView.widthAnchor.constraint(equalToConstant: 30),
                artworkView.heightAnchor.constraint(equalToConstant: 30),

                titleLbl.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 8),
                titleLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: countLbl.leadingAnchor, constant: -8),

                countLbl.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
                countLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
        } else if playlist.itemCount == 0 {
            NSLayoutConstraint.activate([
                artworkView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                artworkView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                artworkView.widthAnchor.constraint(equalToConstant: 30),
                artworkView.heightAnchor.constraint(equalToConstant: 30),

                titleLbl.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 8),
                titleLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: countLbl.leadingAnchor, constant: -8),

                countLbl.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -6),
                countLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

                chevronImageView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
                chevronImageView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                chevronImageView.widthAnchor.constraint(equalToConstant: 12),
                chevronImageView.heightAnchor.constraint(equalToConstant: 12)
            ])
        } else {
            chevronImageView.isHidden = true
            NSLayoutConstraint.activate([
                artworkView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                artworkView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                artworkView.widthAnchor.constraint(equalToConstant: 30),
                artworkView.heightAnchor.constraint(equalToConstant: 30),

                titleLbl.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 8),
                titleLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: countLbl.leadingAnchor, constant: -8),

                countLbl.trailingAnchor.constraint(equalTo: playBtn.leadingAnchor, constant: -8),
                countLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

                playBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
                playBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
        }

        let contextMenu = NSMenu()
        let addCurrentItem = NSMenuItem(title: "Add Currently Playing Track", action: #selector(handlePlaylistContextAddCurrentPlaying(_:)), keyEquivalent: "")
        addCurrentItem.target = self
        addCurrentItem.representedObject = playlist.id
        contextMenu.addItem(addCurrentItem)
        contextMenu.addItem(NSMenuItem.separator())

        let selectItem = NSMenuItem(title: "Select", action: #selector(handlePlaylistContextSelect(_:)), keyEquivalent: "")
        selectItem.target = self
        selectItem.representedObject = playlist.id
        selectItem.state = selectedPlaylistIDs.contains(playlist.id) ? .on : .off
        contextMenu.addItem(selectItem)
        contextMenu.addItem(NSMenuItem.separator())
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handlePlaylistContextDelete(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = playlist.id
        contextMenu.addItem(deleteItem)
        swipeContainer.menu = contextMenu
        row.menu = contextMenu

        return swipeContainer
    }

    private func confirmAndDeletePlaylistFromRow(_ playlist: PlaylistRecord) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete Playlist"
        alert.informativeText = "Delete \"\(playlist.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Delete")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            PlaylistManager.shared.deletePlaylist(id: playlist.id)
            if playlistDetailMode?.id == playlist.id {
                playlistDetailMode = nil
                playlistAddMode = false
                resetPlaylistSectionChrome()
                applySearchCreateFieldState(animated: false)
            }
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
            showToastBanner(message: "🗑 Deleted \"\(playlist.name)\"")
        }
    }

    private func makeDetailItemRow(item: PlaylistItemRecord, index: Int, total: Int, tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Remove"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier(item.id)

        let rowView = DetailItemRowView(item: item, tone: tone, delegate: self)
        rowView.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.contentCardView.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: swipeContainer.contentCardView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: swipeContainer.contentCardView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: swipeContainer.contentCardView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: swipeContainer.contentCardView.bottomAnchor),
            swipeContainer.heightAnchor.constraint(equalToConstant: 40)
        ])

        swipeContainer.onDelete = { [weak self] in
            self?.removeItemFromPlaylist(item)
        }

        return swipeContainer
    }

    func removeItemFromPlaylist(_ item: PlaylistItemRecord) {
        guard let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
        showToastBanner(message: "🗑 Removed \"\(item.title)\"")
    }

    private func makeAddSongRow(track: LocalTrack, tone: SettingsTone) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 14
        row.layer?.borderWidth = 1.0
        row.layer?.borderColor = tone.dividerColor.cgColor
        row.layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = NSTextField(labelWithString: track.title)
        titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLbl.textColor = tone.primaryText
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let artistLbl = NSTextField(labelWithString: track.artist)
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

        let addBtn = ReactiveIconButton()
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.isBordered = false
        addBtn.representedObject = track
        let addConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        addBtn.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")?.withSymbolConfiguration(addConfig)
        addBtn.contentTintColor = rowPlayIconColor(tone: tone)
        addBtn.toolTip = "Add to \"\(playlistDetailMode?.name ?? "playlist")\""
        addBtn.target = self
        addBtn.action = #selector(handleAddSongTrack(_:))
        addBtn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        addBtn.heightAnchor.constraint(equalToConstant: 22).isActive = true

        row.addSubview(textCol)
        row.addSubview(addBtn)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 40),
            textCol.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            textCol.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: addBtn.leadingAnchor, constant: -6),
            addBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            addBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeDownloadRow(track: LocalTrack, allTracks: [LocalTrack], tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier("download-\(track.id)")

        let rowView = DownloadRowView(track: track, tone: tone, delegate: self)
        rowView.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.contentCardView.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: swipeContainer.contentCardView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: swipeContainer.contentCardView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: swipeContainer.contentCardView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: swipeContainer.contentCardView.bottomAnchor),
            swipeContainer.heightAnchor.constraint(equalToConstant: 40)
        ])

        swipeContainer.onDelete = { [weak self] in
            self?.confirmAndDeleteDownloadedTrack(track)
        }

        return swipeContainer
    }

    private func makeHistoryRow(record: HistoryRecord, tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Delete"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier("history-\(record.id)")

        let rowView = HistoryRowView(record: record, tone: tone, delegate: self)
        rowView.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.contentCardView.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: swipeContainer.contentCardView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: swipeContainer.contentCardView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: swipeContainer.contentCardView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: swipeContainer.contentCardView.bottomAnchor),
            swipeContainer.heightAnchor.constraint(equalToConstant: 40)
        ])

        swipeContainer.onDelete = { [weak self] in
            self?.removeHistoryRecord(record)
        }

        return swipeContainer
    }

    func removeHistoryRecord(_ record: HistoryRecord) {
        HistoryManager.shared.deleteHistoryItem(id: record.id)
        showToastBanner(message: "🗑 Removed from history")
        refreshPlaylistsSection()
    }

    private func makeLikedSongRow(record: LikedSongRecord, tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Remove"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier("liked-\(record.videoId)")

        let rowView = LikedSongRowView(record: record, tone: tone, delegate: self)
        rowView.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.contentCardView.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: swipeContainer.contentCardView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: swipeContainer.contentCardView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: swipeContainer.contentCardView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: swipeContainer.contentCardView.bottomAnchor),
            swipeContainer.heightAnchor.constraint(equalToConstant: 40)
        ])

        swipeContainer.onDelete = { [weak self] in
            self?.removeLikedSong(record)
        }

        return swipeContainer
    }

    func removeLikedSong(_ record: LikedSongRecord) {
        LocalDatabaseManager.shared.removeLikedSong(videoId: record.videoId)
        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
        showToastBanner(message: "♥ Removed from liked songs")
        refreshPlaylistsSection()
    }

    private func downloadedTracksForPlayback() -> [LocalTrack] {
        var tracks = LocalLibraryManager.shared.allTracks
        if !isLibrarySearchActive {
            tracks = applyCustomOrder(tracks, storedOrder: storedOrder(for: downloadsOrderKey)) { $0.id }
        }
        return tracks
    }

    @objc func handlePlayLikedSong(_ sender: ReactiveIconButton) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        let records = likedSongsForPlayback()
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: record.videoId, shuffle: false)
        showToastBanner(message: "▶ Playing \"\(record.title)\"")
    }

    @objc func handlePlayDownloadedTrack(_ sender: ReactiveIconButton) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        let tracks = downloadedTracksForPlayback()
        NowPlayingManager.shared.playOfflineTrack(track, in: tracks)
        showToastBanner(message: "▶ Playing \"\(track.title)\"")
    }

    func confirmAndDeleteDownloadedTrack(_ track: LocalTrack) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete Download"
        alert.informativeText = "Delete \"\(track.title)\" from your offline library?"
        alert.alertStyle = .warning
        let delBtn = alert.addButton(withTitle: "Delete")
        delBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            LocalLibraryManager.shared.deleteTrack(track) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.showToastBanner(message: "🗑 Deleted \"\(track.title)\"")
                    }
                    self?.refreshPlaylistsSection()
                    self?.updateDownloadButtonState()
                }
            }
        }
    }

    @objc func handleDownloadsImportTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .mp3]
        panel.prompt = "Import Music"

        panel.begin { [weak self] response in
            if response == .OK {
                LocalLibraryManager.shared.importFiles(from: panel.urls) { count in
                    DispatchQueue.main.async {
                        self?.showToastBanner(message: "✓ Imported \(count) audio track(s)")
                        self?.refreshPlaylistsSection()
                        self?.updateDownloadButtonState()
                    }
                }
            }
        }
    }

    @objc func handleDownloadsPlayAllTapped() {
        let tracks = downloadedTracksForPlayback()
        guard !tracks.isEmpty else {
            showToastBanner(message: "⚠️ No downloaded tracks to play", isWarning: true)
            return
        }
        NowPlayingManager.shared.playOfflineTrack(tracks[0], in: tracks)
        showToastBanner(message: "▶ Playing all downloaded tracks")
    }

    @objc func handleDownloadsShuffleTapped() {
        let tracks = downloadedTracksForPlayback()
        guard !tracks.isEmpty else {
            showToastBanner(message: "⚠️ No downloaded tracks to shuffle", isWarning: true)
            return
        }
        let shuffled = tracks.shuffled()
        NowPlayingManager.shared.playOfflineTrack(shuffled[0], in: shuffled)
        showToastBanner(message: "🔀 Shuffling downloaded tracks")
    }

    @objc func handleLikedSongsPlayAllTapped() {
        let records = likedSongsForPlayback()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No liked songs to play", isWarning: true)
            return
        }
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: nil, shuffle: false)
        showToastBanner(message: "▶ Playing all liked songs")
    }

    @objc func handleLikedSongsShuffleTapped() {
        let records = likedSongsForPlayback()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No liked songs to shuffle", isWarning: true)
            return
        }
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: nil, shuffle: true)
        showToastBanner(message: "🔀 Shuffling liked songs")
    }

    private func likedSongsForPlayback() -> [LikedSongRecord] {
        var records = LikedSongsManager.shared.fetchLikedSongs()
        if !isLibrarySearchActive {
            records = applyCustomOrder(records, storedOrder: storedOrder(for: likedSongsOrderKey)) { $0.videoId }
        }
        return records
    }

    private func resolveLikedSongs(_ records: [LikedSongRecord]) -> [LocalTrack] {
        let allTracks = LocalLibraryManager.shared.allTracks
        return records.compactMap { record in
            allTracks.first(where: { track in
                if let v = track.ytVideoId, !v.isEmpty, v == record.videoId { return true }
                return track.fileURL.path == record.videoId
            })
        }
    }

    private func historyForPlayback() -> [HistoryRecord] {
        var records = HistoryManager.shared.fetchHistory(limit: 100)
        if !isLibrarySearchActive {
            records = applyCustomOrder(records, storedOrder: storedOrder(for: historyOrderKey)) { $0.id }
        }
        return records
    }

    @objc func handleHistoryPlayAllTapped() {
        let records = historyForPlayback()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No listening history to play", isWarning: true)
            return
        }
        let tracks = resolveHistoryTracks(records)
        if tracks.isEmpty {
            if let vid = records.first(where: { $0.ytVideoId != nil && !$0.ytVideoId!.isEmpty })?.ytVideoId {
                NowPlayingManager.shared.switchToOnlineMode()
                PlaylistManager.shared.playOnlineVideo(videoId: vid)
            } else {
                showToastBanner(message: "⚠️ Nothing to play", isWarning: true)
                return
            }
        } else {
            NowPlayingManager.shared.playOfflineTrack(tracks[0], in: tracks)
        }
        showToastBanner(message: "▶ Playing all listening history")
    }

    @objc func handleHistoryShuffleTapped() {
        let records = historyForPlayback().shuffled()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No listening history to shuffle", isWarning: true)
            return
        }
        let tracks = resolveHistoryTracks(records)
        if tracks.isEmpty {
            if let vid = records.first(where: { $0.ytVideoId != nil && !$0.ytVideoId!.isEmpty })?.ytVideoId {
                NowPlayingManager.shared.switchToOnlineMode()
                PlaylistManager.shared.playOnlineVideo(videoId: vid)
            } else {
                showToastBanner(message: "⚠️ Nothing to shuffle", isWarning: true)
                return
            }
        } else {
            NowPlayingManager.shared.playOfflineTrack(tracks[0], in: tracks)
        }
        showToastBanner(message: "🔀 Shuffling listening history")
    }

    private func resolveHistoryTracks(_ records: [HistoryRecord]) -> [LocalTrack] {
        let allTracks = LocalLibraryManager.shared.allTracks
        return records.compactMap { record in
            if record.sourceType == "local", let path = record.filePath, FileManager.default.fileExists(atPath: path) {
                if let existing = allTracks.first(where: { $0.fileURL.path == path }) { return existing }
                return LocalTrack(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    album: record.album,
                    duration: record.duration,
                    fileURL: URL(fileURLWithPath: path)
                )
            }
            if let vid = record.ytVideoId, !vid.isEmpty {
                return allTracks.first(where: { $0.ytVideoId == vid })
            }
            return nil
        }
    }

    // MARK: - Drawer Context Menus

    func contextMenu(for track: LocalTrack) -> NSMenu {
        let menu = NSMenu(title: "Download Options")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleDrawerPlayDownloadItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = track
        let playConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleDrawerPlayNextDownloadItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = track
        let nextConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playNextItem.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Play Next")?.withSymbolConfiguration(nextConfig)
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleDrawerAddToQueueDownloadItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = track
        let queueConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        queueItem.image = NSImage(systemSymbolName: "text.append", accessibilityDescription: "Add to Queue")?.withSymbolConfiguration(queueConfig)
        menu.addItem(queueItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleDrawerAddDownloadToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["track": track, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleDrawerNewPlaylistWithDownload(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = track
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        let plConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addToPlaylistItem.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Add to Playlist")?.withSymbolConfiguration(plConfig)
        menu.addItem(addToPlaylistItem)

        let isLiked = track.isLiked
        let likeItem = NSMenuItem(title: isLiked ? "Unlike Track" : "Like Track", action: #selector(handleDrawerToggleLikeDownloadItem(_:)), keyEquivalent: "")
        likeItem.target = self
        likeItem.representedObject = track
        let likeConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        likeItem.image = NSImage(systemSymbolName: isLiked ? "heart.slash" : "heart.fill", accessibilityDescription: "Like")?.withSymbolConfiguration(likeConfig)
        menu.addItem(likeItem)

        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleDrawerShowDownloadInFinder(_:)), keyEquivalent: "")
        finderItem.target = self
        finderItem.representedObject = track
        let finderConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        finderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Show in Finder")?.withSymbolConfiguration(finderConfig)
        menu.addItem(finderItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Delete Download", action: #selector(handleDrawerDeleteDownloadItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = track
        let delConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")?.withSymbolConfiguration(delConfig)
        menu.addItem(deleteItem)

        return menu
    }

    func contextMenu(for record: LikedSongRecord) -> NSMenu {
        let menu = NSMenu(title: "Liked Song Options")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleDrawerPlayLikedSongItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = record
        let playConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleDrawerPlayNextLikedSongItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = record
        let nextConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playNextItem.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Play Next")?.withSymbolConfiguration(nextConfig)
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleDrawerAddToQueueLikedSongItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = record
        let queueConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        queueItem.image = NSImage(systemSymbolName: "text.append", accessibilityDescription: "Add to Queue")?.withSymbolConfiguration(queueConfig)
        menu.addItem(queueItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleDrawerAddLikedSongToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["record": record, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleDrawerNewPlaylistWithLikedSong(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = record
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        let plConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addToPlaylistItem.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Add to Playlist")?.withSymbolConfiguration(plConfig)
        menu.addItem(addToPlaylistItem)

        let isDownloaded = LocalLibraryManager.shared.allTracks.contains(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        })

        if !isDownloaded && !record.videoId.isEmpty {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleDrawerDownloadLikedSongItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = record
            let dlConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            dlItem.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Download")?.withSymbolConfiguration(dlConfig)
            menu.addItem(dlItem)
        }

        if isDownloaded, let localTrack = LocalLibraryManager.shared.allTracks.first(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        }) {
            let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(handleDrawerShowDownloadInFinder(_:)), keyEquivalent: "")
            finderItem.target = self
            finderItem.representedObject = localTrack
            let finderConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            finderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Show in Finder")?.withSymbolConfiguration(finderConfig)
            menu.addItem(finderItem)
        }

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from Liked Songs", action: #selector(handleDrawerDeleteLikedSongItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = record
        let delConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        deleteItem.image = NSImage(systemSymbolName: "heart.slash", accessibilityDescription: "Unlike")?.withSymbolConfiguration(delConfig)
        menu.addItem(deleteItem)

        return menu
    }

    func contextMenu(for record: HistoryRecord) -> NSMenu {
        let menu = NSMenu(title: "History Options")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleDrawerPlayHistoryItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = record
        let playConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleDrawerPlayNextHistoryItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = record
        let nextConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playNextItem.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Play Next")?.withSymbolConfiguration(nextConfig)
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleDrawerAddToQueueHistoryItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = record
        let queueConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        queueItem.image = NSImage(systemSymbolName: "text.append", accessibilityDescription: "Add to Queue")?.withSymbolConfiguration(queueConfig)
        menu.addItem(queueItem)

        let playlists = PlaylistManager.shared.fetchPlaylists()
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in playlists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleDrawerAddHistoryToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["historyItem": record, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !playlists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleDrawerNewPlaylistWithHistory(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = record
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        let plConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addToPlaylistItem.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Add to Playlist")?.withSymbolConfiguration(plConfig)
        menu.addItem(addToPlaylistItem)

        if record.sourceType == "online", let vid = record.ytVideoId, !vid.isEmpty {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleDrawerDownloadHistoryItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = record
            let dlConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            dlItem.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Download")?.withSymbolConfiguration(dlConfig)
            menu.addItem(dlItem)
        }

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from History", action: #selector(handleDrawerDeleteHistoryItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = record
        let delConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")?.withSymbolConfiguration(delConfig)
        menu.addItem(deleteItem)

        return menu
    }

    func contextMenu(for item: PlaylistItemRecord) -> NSMenu {
        let menu = NSMenu(title: "Playlist Track Options")

        let playItem = NSMenuItem(title: "Play Track", action: #selector(handleDrawerPlayPlaylistItem(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = item
        let playConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        menu.addItem(playItem)

        let playNextItem = NSMenuItem(title: "Play Next", action: #selector(handleDrawerPlayNextPlaylistItem(_:)), keyEquivalent: "")
        playNextItem.target = self
        playNextItem.representedObject = item
        let nextConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        playNextItem.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Play Next")?.withSymbolConfiguration(nextConfig)
        menu.addItem(playNextItem)

        let queueItem = NSMenuItem(title: "Add to Queue", action: #selector(handleDrawerAddToQueuePlaylistItem(_:)), keyEquivalent: "")
        queueItem.target = self
        queueItem.representedObject = item
        let queueConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        queueItem.image = NSImage(systemSymbolName: "text.append", accessibilityDescription: "Add to Queue")?.withSymbolConfiguration(queueConfig)
        menu.addItem(queueItem)

        let otherPlaylists = PlaylistManager.shared.fetchPlaylists().filter { $0.id != item.playlistID }
        let addToPlaylistItem = NSMenuItem(title: "Copy to Playlist", action: nil, keyEquivalent: "")
        let playlistSubmenu = NSMenu(title: "Playlists")
        for pl in otherPlaylists {
            let subItem = NSMenuItem(title: pl.name, action: #selector(handleDrawerCopyPlaylistItemToPlaylist(_:)), keyEquivalent: "")
            subItem.target = self
            subItem.representedObject = ["item": item, "playlistID": pl.id]
            playlistSubmenu.addItem(subItem)
        }
        if !otherPlaylists.isEmpty {
            playlistSubmenu.addItem(NSMenuItem.separator())
        }
        let newPLItem = NSMenuItem(title: "+ New Playlist…", action: #selector(handleDrawerNewPlaylistWithPlaylistItem(_:)), keyEquivalent: "")
        newPLItem.target = self
        newPLItem.representedObject = item
        playlistSubmenu.addItem(newPLItem)
        addToPlaylistItem.submenu = playlistSubmenu
        let plConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addToPlaylistItem.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Copy to Playlist")?.withSymbolConfiguration(plConfig)
        menu.addItem(addToPlaylistItem)

        let resolution = PlaylistManager.shared.resolve(item)
        if case .online = resolution {
            let dlItem = NSMenuItem(title: "Download Track", action: #selector(handleDrawerDownloadPlaylistItem(_:)), keyEquivalent: "")
            dlItem.target = self
            dlItem.representedObject = item
            let dlConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            dlItem.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Download")?.withSymbolConfiguration(dlConfig)
            menu.addItem(dlItem)
        }

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from Playlist", action: #selector(handleDrawerDeletePlaylistItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = item
        let delConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")?.withSymbolConfiguration(delConfig)
        menu.addItem(deleteItem)

        return menu
    }

    // MARK: - Drawer Context Menu Actions

    @objc private func handleDrawerPlayDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NowPlayingManager.shared.playOfflineTrack(track, in: LocalLibraryManager.shared.allTracks)
        showToastBanner(message: "▶ Playing \"\(track.title)\"")
    }

    @objc private func handleDrawerPlayNextDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.playNext(track: track)
        showToastBanner(message: "⏭ Playing Next: \(track.title)")
    }

    @objc private func handleDrawerAddToQueueDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.appendToQueue(track: track)
        showToastBanner(message: "➕ Added to Queue: \(track.title)")
    }

    @objc private func handleDrawerAddDownloadToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let track = dict["track"] as? LocalTrack,
              let playlistID = dict["playlistID"] as? String else { return }
        let res = PlaylistManager.shared.appendTrack(to: playlistID, track: track)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        if res.success {
            showToastBanner(message: "✓ Added to \(plName)")
            refreshPlaylistsSection()
        } else {
            showToastBanner(message: res.message, isWarning: true)
        }
    }

    @objc private func handleDrawerNewPlaylistWithDownload(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        promptForDrawerPlaylistName(title: "New Playlist", defaultName: "\(track.title) Playlist") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendTrack(to: newID, track: track)
                self.showToastBanner(message: "✓ Created \"\(name)\"")
                self.refreshPlaylistsSection()
            }
        }
    }

    @objc private func handleDrawerToggleLikeDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        LocalLibraryManager.shared.toggleLike(for: track.id)

        let isLikedNow =
            LocalLibraryManager.shared.isLiked(trackID: track.id)

        showToastBanner(message: isLikedNow ? "♥ Liked Track" : "Removed Like")
        refreshPlaylistsSection()
    }

    @objc private func handleDrawerShowDownloadInFinder(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        if FileManager.default.fileExists(atPath: track.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
        } else {
            LocalLibraryManager.shared.openMusicFolderInFinder()
        }
    }

    @objc private func handleDrawerDeleteDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        confirmAndDeleteDownloadedTrack(track)
    }

    @objc private func handleDrawerPlayLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = record
        handlePlayLikedSong(fakeBtn)
    }

    @objc private func handleDrawerPlayNextLikedSongItem(_ sender: NSMenuItem) {
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
        showToastBanner(message: "⏭ Playing Next: \(record.title)")
    }

    @objc private func handleDrawerAddToQueueLikedSongItem(_ sender: NSMenuItem) {
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
        showToastBanner(message: "➕ Added to Queue: \(record.title)")
    }

    @objc private func handleDrawerAddLikedSongToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let record = dict["record"] as? LikedSongRecord,
              let playlistID = dict["playlistID"] as? String else { return }
        let res = PlaylistManager.shared.appendLikedSong(to: playlistID, record: record)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        if res.success {
            showToastBanner(message: "✓ Added to \(plName)")
            refreshPlaylistsSection()
        } else {
            showToastBanner(message: res.message, isWarning: true)
        }
    }

    @objc private func handleDrawerNewPlaylistWithLikedSong(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        promptForDrawerPlaylistName(title: "New Playlist", defaultName: "\(record.title) Playlist") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendLikedSong(to: newID, record: record)
                self.showToastBanner(message: "✓ Created \"\(name)\"")
                self.refreshPlaylistsSection()
            }
        }
    }

    @objc private func handleDrawerDownloadLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord, !record.videoId.isEmpty else { return }
        DownloadManager.shared.downloadTrack(
            urlOrVideoId: record.videoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.refreshPlaylistsSection()
            }
        }
        showToastBanner(message: "⬇ Queued download: \(record.title)")
    }

    @objc private func handleDrawerDeleteLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        removeLikedSong(record)
    }

    @objc private func handleDrawerPlayHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = record
        handlePlayHistoryRecord(fakeBtn)
    }

    @objc private func handleDrawerPlayNextHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: record.sourceType == "local" ? "local" : "online",
            refID: record.sourceType == "local" ? (record.filePath ?? record.id) : (record.ytVideoId ?? record.id),
            ytVideoId: record.ytVideoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl,
            duration: "",
            isLiked: false
        )
        PlaylistManager.shared.playNext(item: fakeItem)
        showToastBanner(message: "⏭ Playing Next: \(record.title)")
    }

    @objc private func handleDrawerAddToQueueHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        let fakeItem = PlaylistItemRecord(
            playlistID: "",
            sortOrder: 0,
            refType: record.sourceType == "local" ? "local" : "online",
            refID: record.sourceType == "local" ? (record.filePath ?? record.id) : (record.ytVideoId ?? record.id),
            ytVideoId: record.ytVideoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl,
            duration: "",
            isLiked: false
        )
        PlaylistManager.shared.addToQueue(item: fakeItem)
        showToastBanner(message: "➕ Added to Queue: \(record.title)")
    }

    @objc private func handleDrawerAddHistoryToPlaylist(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let item = dict["historyItem"] as? HistoryRecord,
              let playlistID = dict["playlistID"] as? String else { return }
        let res = PlaylistManager.shared.appendHistoryItem(to: playlistID, item: item)
        let plName = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID })?.name ?? "Playlist"
        if res.success {
            showToastBanner(message: "✓ Added to \(plName)")
            refreshPlaylistsSection()
        } else {
            showToastBanner(message: res.message, isWarning: true)
        }
    }

    @objc private func handleDrawerNewPlaylistWithHistory(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        promptForDrawerPlaylistName(title: "New Playlist", defaultName: "\(item.title) Playlist") { [weak self] name in
            guard let self = self else { return }
            if let newID = PlaylistManager.shared.createPlaylist(name: name) {
                PlaylistManager.shared.appendHistoryItem(to: newID, item: item)
                self.showToastBanner(message: "✓ Created \"\(name)\"")
                self.refreshPlaylistsSection()
            }
        }
    }

    @objc private func handleDrawerDownloadHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = item
        handleDownloadHistoryButtonTapped(fakeBtn)
    }

    @objc private func handleDrawerDeleteHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        removeHistoryRecord(record)
    }

    @objc private func handleDrawerPlayPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord,
              let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.startPlaylist(playlistID: playlist.id, startingAt: item.id, shuffle: false)
    }

    @objc private func handleDrawerPlayNextPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.playNext(item: item)
        showToastBanner(message: "⏭ Playing Next: \(item.title)")
    }

    @objc private func handleDrawerAddToQueuePlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.addToQueue(item: item)
        showToastBanner(message: "➕ Added to Queue: \(item.title)")
    }

    @objc private func handleDrawerCopyPlaylistItemToPlaylist(_ sender: NSMenuItem) {
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
        showToastBanner(message: "✓ Copied to \(plName)")
    }

    @objc private func handleDrawerNewPlaylistWithPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        promptForDrawerPlaylistName(title: "New Playlist", defaultName: "\(item.title) Playlist") { [weak self] name in
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
                self.showToastBanner(message: "✓ Created \"\(name)\"")
                self.refreshPlaylistsSection()
            }
        }
    }

    @objc private func handleDrawerDownloadPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = item
        handleDownloadDetailItem(fakeBtn)
    }

    @objc private func handleDrawerDeletePlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord,
              let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.removeItem(itemID: item.id, from: playlist.id)
        showToastBanner(message: "🗑 Removed from playlist")
        refreshPlaylistsSection()
    }

    private func promptForDrawerPlaylistName(title: String, defaultName: String, completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = title
        alert.informativeText = "Enter a name for this playlist:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = defaultName
        textField.placeholderString = "Playlist Name"
        alert.accessoryView = textField
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name.isEmpty ? "My Playlist" : name)
        }
    }

    @objc func handlePlayHistoryRecord(_ sender: ReactiveIconButton) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        let records = historyForPlayback()
        let tracks = resolveHistoryTracks(records)
        if let path = record.filePath, FileManager.default.fileExists(atPath: path),
           let track = tracks.first(where: { $0.fileURL.path == path || $0.id == record.id }) {
            NowPlayingManager.shared.playOfflineTrack(track, in: tracks.isEmpty ? [track] : tracks)
        } else {
            HistoryManager.shared.playHistoryItem(record)
        }
        showToastBanner(message: "▶ Playing \"\(record.title)\"")
    }

    @objc func handleDownloadHistoryButtonTapped(_ sender: ReactiveIconButton) {
        guard let record = sender.representedObject as? HistoryRecord,
              let btn = sender as? CircularProgressDownloadButton else { return }

        switch btn.downloadState {
        case .queued, .downloading:
            DownloadManager.shared.cancelTask(id: record.id)
            btn.downloadState = .idleDownload
            showToastBanner(message: "✕ Cancelled download")
        case .completed:
            showToastBanner(message: "✓ \"\(record.title)\" is already saved offline")
        case .idleDownload, .unavailable:
            let vid = record.ytVideoId ?? ""
            let targetUrl = vid.isEmpty ? "\(record.title) \(record.artist)" : vid
            showToastBanner(message: "⬇ Added \"\(record.title)\" to download queue")
            DownloadManager.shared.queueTrack(
                id: record.id,
                urlOrVideoId: targetUrl,
                title: record.title,
                artist: record.artist,
                artworkUrl: record.artworkUrl
            ) { [weak self] success, message in
                DispatchQueue.main.async {
                    if success {
                        self?.showToastBanner(message: "✓ Saved \"\(record.title)\" offline")
                    } else {
                        self?.showToastBanner(message: message, isWarning: true)
                    }
                    self?.refreshPlaylistsSection()
                    self?.updateDownloadButtonState()
                }
            }
        }
    }

    @objc private func handlePlayPlaylistFromRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        PlaylistManager.shared.play(playlistID: playlist.id) { [weak self] res in
            self?.showToastBanner(message: res.message, isWarning: !res.started)
        }
    }

    @objc private func handleShufflePlaylistFromRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        PlaylistManager.shared.shufflePlay(playlistID: playlist.id) { [weak self] res in
            self?.showToastBanner(message: res.message, isWarning: !res.started)
        }
    }

    @objc private func handleTogglePlaylistRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        let result = PlaylistManager.shared.toggleCurrentPlayingTrack(in: playlist.id)
        showToastBanner(message: result.added ? "✓ Added to \(playlist.name)" : "✕ Removed from \(playlist.name)")
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handleOpenFullPlaylistLibrary() {
        collapseSettings()
        delegate?.dynamicIslandDidTapPlaylistLibrary(playlistID: nil)
    }

    @objc private func handleOpenPlaylistDetail(_ sender: NSClickGestureRecognizer) {
        guard let playlistID = sender.view?.identifier?.rawValue, !playlistID.isEmpty,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID }) else { return }
        playlistDetailMode = playlist
        playlistAddMode = false
        isPlaylistSearchActive = true
        isPlaylistCreateOpen = false
        resetPlaylistSectionChrome()
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handleBackFromPlaylistDetail() {
        if playlistAddMode {
            playlistAddMode = false
            isPlaylistSearchActive = true
            applySearchCreateFieldState(animated: false)
            refreshPlaylistsSection()
            return
        }
        playlistDetailMode = nil
        playlistAddMode = false
        isPlaylistCreateOpen = false
        isPlaylistSearchActive = true
        resetPlaylistSectionChrome()
        if let search = playlistSearchField {
            search.stringValue = ""
        }
        applySearchCreateFieldState(animated: false)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handlePlayPlaylistFromDetail() {
        guard let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.play(playlistID: playlist.id) { [weak self] res in
            self?.showToastBanner(message: res.message, isWarning: !res.started)
        }
    }

    @objc private func handleShufflePlaylistFromDetail() {
        guard let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.shufflePlay(playlistID: playlist.id) { [weak self] res in
            self?.showToastBanner(message: res.message, isWarning: !res.started)
        }
    }

    @objc func handlePlayItemFromDetail(_ sender: ReactiveIconButton) {
        guard let item = sender.representedObject as? PlaylistItemRecord,
              let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.startPlaylist(playlistID: playlist.id, startingAt: item.id, shuffle: false)
    }

    @objc func handleDownloadDetailItem(_ sender: ReactiveIconButton) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        let vid = item.ytVideoId ?? item.refID
        guard !vid.isEmpty else { return }

        showToastBanner(message: "⬇ Added \"\(item.title)\" to download queue")

        DownloadManager.shared.queueTrack(
            id: item.id,
            urlOrVideoId: vid,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl
        ) { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                    self?.showToastBanner(message: "✓ Saved \"\(item.title)\" offline")
                } else {
                    self?.showToastBanner(message: message, isWarning: true)
                }
                self?.refreshPlaylistsSection()
            }
        }
    }

    @objc func handleDownloadButtonTapped(_ sender: ReactiveIconButton) {
        guard let item = sender.representedObject as? PlaylistItemRecord,
              let btn = sender as? CircularProgressDownloadButton else { return }

        switch btn.downloadState {
        case .queued, .downloading:
            DownloadManager.shared.cancelTask(id: item.id)
            btn.downloadState = .idleDownload
            showToastBanner(message: "✕ Cancelled \"\(item.title)\" download")
        case .idleDownload:
            handleDownloadDetailItem(sender)
        case .completed:
            handleDownloadedItemClicked(sender)
        case .unavailable:
            break
        }
    }

    @objc func handleDownloadedItemClicked(_ sender: ReactiveIconButton) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        showToastBanner(message: "✓ \"\(item.title)\" is already saved offline")
    }

    @objc private func handleDownloadAllFromDetailHeader() {
        guard let playlist = playlistDetailMode else { return }
        let plan = PlaylistManager.shared.planDownloads(for: playlist.id)
        guard !plan.toDownload.isEmpty else {
            if plan.offlineBlocked > 0 {
                showToastBanner(message: "⚠️ You're offline — go online to download \(plan.offlineBlocked) track(s)", isWarning: true)
            } else {
                showToastBanner(message: "✓ All tracks are already downloaded")
            }
            return
        }
        showToastBanner(message: "⬇ Queued \(plan.toDownload.count) tracks from \"\(playlist.name)\"")

        let queueTuples = plan.toDownload.map { item -> (id: String, urlOrVideoId: String, title: String, artist: String, artworkUrl: String) in
            let vid = item.ytVideoId ?? item.refID
            return (id: item.id, urlOrVideoId: vid, title: item.title, artist: item.artist, artworkUrl: item.artworkUrl)
        }
        DownloadManager.shared.queueTracks(queueTuples)
    }

    @objc func handleAddSongTrack(_ sender: ReactiveIconButton) {
        guard let track = sender.representedObject as? LocalTrack,
              let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.appendLocalTracks([track], to: playlist.id)
        showToastBanner(message: "✓ Added \"\(track.title)\"")
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handleAddToPlaylistRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        let result = PlaylistManager.shared.appendCurrentPlayingTrack(to: playlist.id)
        if result.success {
            showToastBanner(message: "✓ Added to \(playlist.name)")
        } else {
            showToastBanner(message: result.message, isWarning: true)
        }
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    func updatePlaylistCreateButtonIcon(isCreating: Bool) {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        playlistDetailCreateButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Create New Playlist")?.withSymbolConfiguration(config)
        playlistDetailCreateButton.toolTip = isCreating ? "Cancel" : "Create New Playlist"
    }

    @objc private func handleCreateNewPlaylistFromHeader() {
        if isPlaylistCreateOpen {
            handleInlineCreateCancel()
            return
        }
        isPlaylistCreateOpen = true
        playlistSearchField?.stringValue = ""
        inlineCreateTextField.stringValue = ""
        updatePlaylistCreateButtonIcon(isCreating: true)
        resetPlaylistSectionChrome()
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
        applySearchCreateFieldState(animated: true)
        window?.makeFirstResponder(inlineCreateTextField)
    }

    @objc private func handleInlineCreateConfirm() {
        let name = inlineCreateTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            handleInlineCreateCancel()
            return
        }
        isPlaylistCreateOpen = false
        isPlaylistSearchActive = true
        updatePlaylistCreateButtonIcon(isCreating: false)
        applySearchCreateFieldState(animated: false)
        window?.makeFirstResponder(nil)
        if let _ = PlaylistManager.shared.createPlaylist(name: name) {
            showToastBanner(message: "✓ Created \"\(name)\"")
            resetPlaylistSectionChrome()
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    @objc private func handleInlineCreateCancel() {
        isPlaylistCreateOpen = false
        isPlaylistSearchActive = true
        inlineCreateTextField.stringValue = ""
        updatePlaylistCreateButtonIcon(isCreating: false)
        applySearchCreateFieldState(animated: false)
        window?.makeFirstResponder(nil)
        resetPlaylistSectionChrome()
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc private func handleDeletePlaylistFromHeader() {
        guard let playlist = playlistDetailMode else { return }
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Delete Playlist"
        alert.informativeText = "Delete \"\(playlist.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            PlaylistManager.shared.deletePlaylist(id: playlist.id)
            playlistDetailMode = nil
            playlistAddMode = false
            resetPlaylistSectionChrome()
            if let search = playlistSearchField {
                search.stringValue = ""
            }
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    @objc private func handleAddCurrentSongToDetailPlaylist() {
        guard let playlist = playlistDetailMode else { return }
        let result = PlaylistManager.shared.appendCurrentPlayingTrack(to: playlist.id)
        if result.success {
            showToastBanner(message: "✓ Added to \(playlist.name)")
        } else {
            showToastBanner(message: result.message, isWarning: true)
        }
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    func currentThemeDisplayName() -> String {
        switch PlayerDesign.current {
        case .glassMode: return "Translucent frosted glass panel"
        case .adaptive, .native: return "Live dynamic artwork backdrop"
        case .darkMode: return "Deep pitch-black dark contrast"
        }
    }

    func makeThemeFeatureRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: "Player Themes")?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: "Player Themes")
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: currentThemeDisplayName())
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true
        self.themeDescLabel = descLbl

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        themeToggle.totalSteps = 3
        let currentThemeStep: Int
        switch PlayerDesign.current {
        case .adaptive, .native: currentThemeStep = 0
        case .darkMode: currentThemeStep = 1
        case .glassMode: currentThemeStep = 2
        }
        themeToggle.stepIndex = currentThemeStep
        themeToggle.onStep = { [weak self] step in
            switch step {
            case 0:
                PlayerDesign.current = .adaptive
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Adaptive")
            case 1:
                PlayerDesign.current = .darkMode
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: OLED Dark")
            case 2:
                PlayerDesign.current = .glassMode
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Crystal Glass")
            default:
                break
            }
            self?.applyTheme()
            self?.themeDescLabel?.stringValue = self?.currentThemeDisplayName() ?? ""
            self?.updateSettingsThemeHighlight()
        }
        themeToggle.translatesAutoresizingMaskIntoConstraints = false
        themeToggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        themeToggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, themeToggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        themeToggle.setContentHuggingPriority(.required, for: .horizontal)
        themeToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    @objc func themeCycleTapped() {
        switch PlayerDesign.current {
        case .glassMode:
            PlayerDesign.current = .adaptive
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Adaptive")
        case .adaptive, .native:
            PlayerDesign.current = .darkMode
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: OLED Dark")
        case .darkMode:
            PlayerDesign.current = .glassMode
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Crystal Glass")
        }
        applyTheme()
        themeDescLabel?.stringValue = currentThemeDisplayName()
        updateSettingsThemeHighlight()
    }

    func makeProgressStyleFeatureRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Timeline Track")?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: "Timeline Track")
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: ProgressStyle.current.displayName)
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true
        self.progressDescLabel = descLbl

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        let allStyles = ProgressStyle.allCases
        progressToggle.totalSteps = allStyles.count
        let currentProgressStep = allStyles.firstIndex(of: ProgressStyle.current) ?? 0
        progressToggle.stepIndex = currentProgressStep
        progressToggle.onStep = { [weak self] step in
            guard step >= 0 && step < allStyles.count else { return }
            let next = allStyles[step]
            ProgressStyle.current = next
            self?.progressDescLabel?.stringValue = next.displayName
            self?.waveformProgressView.needsDisplay = true
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Progress Bar: \(next.displayName)")
        }
        progressToggle.translatesAutoresizingMaskIntoConstraints = false
        progressToggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        progressToggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, progressToggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        progressToggle.setContentHuggingPriority(.required, for: .horizontal)
        progressToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    @objc func progressStyleCycleTapped() {
        let all = ProgressStyle.allCases
        let current = ProgressStyle.current
        guard let idx = all.firstIndex(of: current) else { return }
        let next = all[(idx + 1) % all.count]
        ProgressStyle.current = next
        progressDescLabel?.stringValue = next.displayName
        waveformProgressView.needsDisplay = true
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Progress Bar: \(next.displayName)")
    }

    func makeFeatureRow(icon: String, title: String, description: String, isOn: Bool, toggle: NativeCapsuleToggleView, onToggle: @escaping (Bool) -> Void) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title)?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: title)
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: description)
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        toggle.isOn = isOn
        toggle.onToggle = onToggle
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        toggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, toggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }


    func currentSettingsTone() -> SettingsTone {
        switch PlayerDesign.current {
        case .darkMode:
            return .dark
        case .glassMode:
            return .light
        case .adaptive, .native:
            let appearance = NSApp.effectiveAppearance
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark ? .dark : .light
        }
    }

    func updateSettingsThemeHighlight() {
        let tone = currentSettingsTone()
        settingsHeaderLabel.textColor = tone.primaryText
        playlistSectionLabel.textColor = tone.primaryText
        featuresSectionLabel.textColor = tone.secondaryText
        settingsDivider.layer?.backgroundColor = tone.dividerColor.cgColor

        themeDescLabel?.stringValue = currentThemeDisplayName()
        progressDescLabel?.stringValue = ProgressStyle.current.displayName

        themeToggle.updateVisuals()
        progressToggle.updateVisuals()
        masterGesturesToggle.updateVisuals()
        appVolumeToggle.updateVisuals()
        lyricsToggle.updateVisuals()
        discordToggle.updateVisuals()

        let currentThemeStep: Int
        switch PlayerDesign.current {
        case .adaptive, .native: currentThemeStep = 0
        case .darkMode: currentThemeStep = 1
        case .glassMode: currentThemeStep = 2
        }
        themeToggle.stepIndex = currentThemeStep
        let allStyles = ProgressStyle.allCases
        progressToggle.stepIndex = allStyles.firstIndex(of: ProgressStyle.current) ?? 0

        for icon in featureIconViews {
            icon.contentTintColor = tone.iconColor
        }
        for title in featureTitleLabels {
            title.textColor = tone.primaryText
        }
        for desc in featureDescLabels {
            desc.textColor = tone.secondaryText
        }

        settingsVersionLabel?.textColor = tone.secondaryText.withAlphaComponent(0.6)

        playlistSearchField?.applyPlaylistContainerStyle(tone: tone)

        librarySectionHeaderLabel.textColor = tone.secondaryText

        libraryNavContainer.layer?.borderWidth = 0
        libraryNavContainer.layer?.backgroundColor = NSColor.clear.cgColor

        let isGlass = (PlayerDesign.current == .glassMode)
        let isDark = (PlayerDesign.current == .darkMode || tone == .dark)
        let cyan = isGlass ? NSColor.lightThemeSelector : (isDark ? NSColor.darkThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))
        for btn in libraryNavButtons {
            btn.refresh(tone: tone, isGlass: isGlass, cyan: cyan)
        }
        playlistDetailCreateButton.contentTintColor = isPlaylistCreateOpen ? cyan : tone.iconColor

        if let footerBtn = playlistCreateFooterButton {
            footerBtn.contentTintColor = cyan
            footerBtn.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
            footerBtn.layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.08 : 0.12).cgColor
        }

        downloadsPlayAllButton.contentTintColor = cyan
        downloadsShuffleButton.contentTintColor = cyan

        likedPlayAllButton.contentTintColor = cyan
        likedShuffleButton.contentTintColor = cyan

        historyPlayAllButton.contentTintColor = cyan
        historyShuffleButton.contentTintColor = cyan

        playlistDetailBackButton.contentTintColor = cyan
        playlistDetailPlayAllButton.contentTintColor = cyan
        playlistDetailShuffleButton.contentTintColor = cyan
        playlistDetailDownloadAllButton.contentTintColor = cyan
        playlistDetailAddButton.contentTintColor = cyan

        playlistSearchToggleButton.contentTintColor = isPlaylistSearchActive ? cyan : tone.iconColor
        playlistBulkDeleteButton.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        playlistSelectionDoneButton.contentTintColor = cyan
        playlistSelectionDoneButton.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
        playlistSelectionDoneButton.layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.08 : 0.14).cgColor

        inlineCreateTextField.textColor = tone.primaryText
        inlineCreateContainer.layer?.borderColor = tone.dividerColor.cgColor
        inlineCreateContainer.layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
    }
}

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
private class DownloadRowView: NSView {
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
            layer?.borderColor = tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play Offline"
        }
    }

    private func setupUI(tone: SettingsTone) {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = tone.dividerColor.cgColor
        layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
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
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "download-", storageKey: delegate.downloadsOrderKey, playlistID: nil)
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

private class DetailItemRowView: NSView {
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
            layer?.borderColor = tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = tone.dividerColor.cgColor
        layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
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

        let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        addGestureRecognizer(pan)
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
private class HistoryRowView: NSView {
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
            layer?.borderColor = tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = tone.dividerColor.cgColor
        layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
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

private class LikedSongRowView: NSView {
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
            layer?.borderColor = tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)

            let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play"
        }
    }

    private func setupUI(tone: SettingsTone) {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1.0
        layer?.borderColor = tone.dividerColor.cgColor
        layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
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
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "liked-", storageKey: delegate.likedSongsOrderKey, playlistID: nil)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let delegate = delegate else { return nil }
        return delegate.contextMenu(for: record)
    }
}


