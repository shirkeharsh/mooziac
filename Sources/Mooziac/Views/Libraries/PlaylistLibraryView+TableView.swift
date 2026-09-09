import AppKit
import UniformTypeIdentifiers

extension PlaylistLibraryView {
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
            cell?.onRename = { [weak self] in
                guard let self = self else { return }
                self.promptForName(title: "Rename Playlist", defaultName: playlist.name, actionTitle: "Rename") { [weak self] name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if trimmed != playlist.name {
                        PlaylistManager.shared.renamePlaylist(id: playlist.id, name: trimmed)
                        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Renamed to \"\(trimmed)\"")
                    }
                    self?.reload()
                }
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
                self?.showTrackMenu(for: item, in: playlist, from: sender)
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
                LikedSongsManager.shared.removeLikedSong(videoId: record.videoId)
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
                self.playDownloadedTrack(track)
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
                LikedSongsManager.shared.removeLikedSong(videoId: record.videoId)
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

    private func showTrackMenu(for item: PlaylistItemRecord, in playlist: PlaylistRecord, from sender: NSButton) {
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

        let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currentIndex = allPlaylistItems.firstIndex(where: { $0.id == item.id }) ?? -1

        let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpItem(_:)), keyEquivalent: "")
        moveUpItem.target = self
        moveUpItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
        moveUpItem.isEnabled = currentIndex > 0 && !isSearch
        menu.addItem(moveUpItem)

        let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownItem(_:)), keyEquivalent: "")
        moveDownItem.target = self
        moveDownItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
        moveDownItem.isEnabled = (currentIndex >= 0 && currentIndex < allPlaylistItems.count - 1) && !isSearch
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

        let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currentIndex = allDownloads.firstIndex(where: { $0.id == track.id }) ?? -1

        let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpDownload(_:)), keyEquivalent: "")
        moveUpItem.target = self
        moveUpItem.representedObject = track
        moveUpItem.isEnabled = currentIndex > 0 && !isSearch
        menu.addItem(moveUpItem)

        let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownDownload(_:)), keyEquivalent: "")
        moveDownItem.target = self
        moveDownItem.representedObject = track
        moveDownItem.isEnabled = (currentIndex >= 0 && currentIndex < allDownloads.count - 1) && !isSearch
        menu.addItem(moveDownItem)

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

        let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currentIndex = allLikedSongs.firstIndex(where: { $0.videoId == record.videoId }) ?? -1

        let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpLikedSong(_:)), keyEquivalent: "")
        moveUpItem.target = self
        moveUpItem.representedObject = record
        moveUpItem.isEnabled = currentIndex > 0 && !isSearch
        menu.addItem(moveUpItem)

        let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownLikedSong(_:)), keyEquivalent: "")
        moveDownItem.target = self
        moveDownItem.representedObject = record
        moveDownItem.isEnabled = (currentIndex >= 0 && currentIndex < allLikedSongs.count - 1) && !isSearch
        menu.addItem(moveDownItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove from Liked Songs", action: #selector(handleContextDeleteLikedSongItem(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = record
        menu.addItem(deleteItem)

        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc func handleContextNewPlaylistWithDetailItem(_ sender: NSMenuItem) {
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
        switch mode {
        case .detail, .likedSongs, .downloads:
            break
        default:
            return false
        }
        guard searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let row = rowIndexes.first else { return false }
        let data: Data
        do {
            data = try NSKeyedArchiver.archivedData(withRootObject: [NSNumber(value: row)], requiringSecureCoding: false)
        } catch {
            Log.general.error("Failed to archive drag row: \(error.localizedDescription)")
            return false
        }
        pboard.declareTypes([Self.dragType], owner: self)
        pboard.setData(data, forType: Self.dragType)
        return true
    }

    public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        switch mode {
        case .detail, .likedSongs, .downloads:
            break
        default:
            return []
        }
        guard searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }

    public func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let pboard = info.draggingPasteboard.data(forType: Self.dragType) else { return false }

        let rowNumbers: [NSNumber]
        do {
            guard let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSNumber.self], from: pboard) as? [NSNumber] else {
                return false
            }
            rowNumbers = unarchived
        } catch {
            Log.general.error("Failed to unarchive drop row: \(error.localizedDescription)")
            return false
        }
        guard let sourceRowNumber = rowNumbers.first else { return false }

        let sourceRow = sourceRowNumber.intValue
        var targetRow = row
        if targetRow > sourceRow {
            targetRow -= 1
        }

        switch mode {
        case .detail(let playlist):
            guard sourceRow != targetRow,
                  sourceRow >= 0, sourceRow < allPlaylistItems.count,
                  targetRow >= 0, targetRow < allPlaylistItems.count else { return false }

            let item = allPlaylistItems.remove(at: sourceRow)
            allPlaylistItems.insert(item, at: targetRow)
            filteredPlaylistItems = allPlaylistItems

            let itemIDs = allPlaylistItems.map { $0.id }
            PlaylistManager.shared.reorderItems(playlistID: playlist.id, orderedItemIDs: itemIDs)
            tableView.reloadData()
            return true

        case .likedSongs:
            guard sourceRow != targetRow,
                  sourceRow >= 0, sourceRow < allLikedSongs.count,
                  targetRow >= 0, targetRow < allLikedSongs.count else { return false }

            let item = allLikedSongs.remove(at: sourceRow)
            allLikedSongs.insert(item, at: targetRow)
            filteredLikedSongs = allLikedSongs

            let itemIDs = allLikedSongs.map { $0.videoId }
            PlaylistManager.shared.reorderItems(playlistID: "liked_songs", orderedItemIDs: itemIDs)
            tableView.reloadData()
            return true

        case .downloads:
            guard sourceRow != targetRow,
                  sourceRow >= 0, sourceRow < allDownloads.count,
                  targetRow >= 0, targetRow < allDownloads.count else { return false }

            let item = allDownloads.remove(at: sourceRow)
            allDownloads.insert(item, at: targetRow)
            filteredDownloads = allDownloads

            let itemIDs = allDownloads.map { $0.id }
            PlaylistManager.shared.reorderItems(playlistID: "downloads", orderedItemIDs: itemIDs)
            tableView.reloadData()
            return true

        default:
            return false
        }
    }
}

