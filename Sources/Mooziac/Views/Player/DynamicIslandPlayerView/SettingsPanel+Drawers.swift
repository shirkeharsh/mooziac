import AppKit

extension DynamicIslandPlayerView {


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
        if tab == .likedSongs, PlaylistSyncManager.shared.isSignedIn, !PlaylistSyncManager.shared.isSyncInProgress {
            PlaylistSyncManager.shared.syncNow()
        }
    }

    @objc func handleLibraryNavTapped(_ sender: LibraryNavButton) {
        selectLibraryTab(sender.libraryTab)
    }

    func resetPlaylistSectionChrome() {
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
                playlistDetailRenameButton.isHidden = true
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
                playlistDetailRenameButton.isHidden = false
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
            playlistDetailRenameButton.isHidden = true
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

    func applySearchCreateFieldState(animated: Bool) {
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

    @objc func handlePlaylistSearchChanged(_ sender: NSSearchField) {
        refreshPlaylistsSection(filterQuery: sender.stringValue)
    }

    func updatePlaylistSearchToggleIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        playlistSearchToggleButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(config)
        playlistSearchToggleButton.toolTip = isPlaylistSearchActive ? "Close Search" : "Search Playlists"
    }

    @objc func handlePlaylistSearchToggle() {
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

    @objc func handleTogglePlaylistSelectionMode() {
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

    @objc func handlePlaylistContextAddCurrentPlaying(_ sender: NSMenuItem) {
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

    @objc func handlePlaylistContextSelect(_ sender: NSMenuItem) {
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

    @objc func handlePlaylistContextDelete(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) else { return }
        confirmAndDeletePlaylistFromRow(playlist)
    }

    @objc func handleBulkDeletePlaylists() {
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
        pendingRowItemIDs = []
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
        var itemIDs: [String] = []
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
                itemIDs = playlists.map { $0.id }
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
                itemIDs = liked.map { "liked-\($0.videoId)" }
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
                itemIDs = tracks.map { "download-\($0.id)" }
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
                itemIDs = history.map { "history-\($0.id)" }
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
        scheduleIncrementalBuild(builders, itemIDs: itemIDs, into: playlistsStackView)
    }

    private func scheduleIncrementalBuild(_ builders: [() -> NSView], itemIDs: [String] = [], into stack: NSStackView, initialBatchSize: Int = 35) {
        pendingRowBuilders = builders
        pendingRowItemIDs = itemIDs
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
        let limit = min(pendingRowBuilders.count, 40)
        var mountedIndices = playlistMountedRows.keys.sorted()
        for idx in 0..<limit where playlistMountedRows[idx] == nil {
            let row = pendingRowBuilders[idx]()
            row.translatesAutoresizingMaskIntoConstraints = false
            let insertPos = mountedIndices.filter { $0 < idx }.count
            stack.insertArrangedSubview(row, at: min(insertPos, stack.arrangedSubviews.count))
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            playlistMountedRows[idx] = row
            mountedIndices.insert(idx, at: insertPos)
            applyMountedRowState(row)
        }
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

    @objc func handlePlaylistScrollBoundsDidChange(_ notification: Notification) {
        updateMountedPlaylistWindow()
    }

    @objc func handleSettingsPlaybackStateChanged(_ notification: Notification) {
        updatePlayingRowHighlight()
    }

    @objc func handleSettingsDownloadProgress(_ notification: Notification) {
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
        guard !isLibrarySearchActive else { return }
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

        case .changed:
            let arranged = stack.arrangedSubviews
            guard let currentArrangedIndex = arranged.firstIndex(of: containerView) else { return }
            guard let currentID = (containerView as? SwipeToDeleteContainerView)?.identifier?.rawValue ?? containerView.identifier?.rawValue,
                  let currentMasterIndex = pendingRowItemIDs.firstIndex(of: currentID) else { return }

            for (targetArrangedIndex, otherView) in arranged.enumerated() where otherView != containerView {
                let otherFrame = otherView.frame
                if location.y >= otherFrame.minY && location.y <= otherFrame.maxY {
                    if targetArrangedIndex != currentArrangedIndex {
                        guard let targetID = (otherView as? SwipeToDeleteContainerView)?.identifier?.rawValue ?? otherView.identifier?.rawValue,
                              let targetMasterIndex = pendingRowItemIDs.firstIndex(of: targetID) else { break }

                        let movedID = pendingRowItemIDs.remove(at: currentMasterIndex)
                        pendingRowItemIDs.insert(movedID, at: targetMasterIndex)

                        if currentMasterIndex < pendingRowBuilders.count && targetMasterIndex < pendingRowBuilders.count {
                            let movedBuilder = pendingRowBuilders.remove(at: currentMasterIndex)
                            pendingRowBuilders.insert(movedBuilder, at: targetMasterIndex)
                        }

                        var newMounted: [Int: NSView] = [:]
                        for sub in stack.arrangedSubviews {
                            if let sid = (sub as? SwipeToDeleteContainerView)?.identifier?.rawValue ?? sub.identifier?.rawValue,
                               let sidx = pendingRowItemIDs.firstIndex(of: sid) {
                                newMounted[sidx] = sub
                            }
                        }
                        playlistMountedRows = newMounted

                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.15
                            context.allowsImplicitAnimation = true
                            stack.removeArrangedSubview(containerView)
                            stack.insertArrangedSubview(containerView, at: targetArrangedIndex)
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

            guard !pendingRowItemIDs.isEmpty else { return }

            var keys = pendingRowItemIDs
            if let keyPrefix {
                keys = keys.map { $0.hasPrefix(keyPrefix) ? String($0.dropFirst(keyPrefix.count)) : $0 }
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
            }

            if let playlistID {
                PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: keys)
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
            playlistDetailRenameButton.isHidden = true
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
            let itemIDs = tracks.map { $0.id }
            let builders = tracks.map { track in
                { [weak self] in self?.makeAddSongRow(track: track, tone: tone) ?? NSView() }
            }
            scheduleIncrementalBuild(builders, itemIDs: itemIDs, into: detailStackView)
            return
        }

        playlistDetailRenameButton.isHidden = false
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
        let itemIDs = items.map { $0.id }
        let builders = items.enumerated().map { (idx, item) in
            { [weak self] in self?.makeDetailItemRow(item: item, index: idx, total: total, tone: tone) ?? NSView() }
        }
        scheduleIncrementalBuild(builders, itemIDs: itemIDs, into: detailStackView)
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

    @objc func handlePlaylistRowPlay(_ sender: ReactiveIconButton) {
        guard let id = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == id }) else { return }
        let items = PlaylistManager.shared.fetchPlaylistItems(playlistID: id)
        if items.isEmpty {
            showToastBanner(message: "⚠️ \"\(playlist.name)\" is empty", isWarning: true)
            return
        }
        PlaylistManager.shared.startPlaylist(playlistID: id, startingAt: nil, shuffle: false)
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
        let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
        row.layer?.borderColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.20) : tone.dividerColor).cgColor
        row.layer?.backgroundColor = (isLiquidDark ? NSColor(white: 1.0, alpha: 0.16) : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06))).cgColor

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

        let renameItem = NSMenuItem(title: "Rename Playlist…", action: #selector(handlePlaylistContextRename(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = playlist.id
        contextMenu.addItem(renameItem)

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
        LikedSongsManager.shared.removeLikedSong(videoId: record.videoId)
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
    }

    @objc func handlePlayDownloadedTrack(_ sender: ReactiveIconButton) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        let tracks = downloadedTracksForPlayback()
        PlaylistManager.shared.startDownloadsPlayback(tracks: tracks, startingAt: track.id, shuffle: false)
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
                        self?.showToastBanner(message: "Deleted \"\(track.title)\"")
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
                        self?.showToastBanner(message: "Imported \(count) audio track(s)")
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
            showToastBanner(message: "No downloaded tracks to play", isWarning: true)
            return
        }
        PlaylistManager.shared.startDownloadsPlayback(tracks: tracks, startingAt: nil, shuffle: false)
    }

    @objc func handleDownloadsShuffleTapped() {
        let tracks = downloadedTracksForPlayback()
        guard !tracks.isEmpty else {
            showToastBanner(message: "No downloaded tracks to shuffle", isWarning: true)
            return
        }
        PlaylistManager.shared.startDownloadsPlayback(tracks: tracks, startingAt: nil, shuffle: true)
    }

    @objc func handleLikedSongsPlayAllTapped() {
        let records = likedSongsForPlayback()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No liked songs to play", isWarning: true)
            return
        }
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: nil, shuffle: false)
    }

    @objc func handleLikedSongsShuffleTapped() {
        let records = likedSongsForPlayback()
        guard !records.isEmpty else {
            showToastBanner(message: "⚠️ No liked songs to shuffle", isWarning: true)
            return
        }
        PlaylistManager.shared.startLikedSongsPlayback(records: records, startingAt: nil, shuffle: true)
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

    func historyForPlayback() -> [HistoryRecord] {
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
    }

    func resolveHistoryTracks(_ records: [HistoryRecord]) -> [LocalTrack] {
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
}
