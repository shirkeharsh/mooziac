import AppKit

extension PlaylistLibraryView {
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

            let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpItem(_:)), keyEquivalent: "")
            moveUpItem.target = self
            moveUpItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
            moveUpItem.isEnabled = row > 0 && !isSearch
            menu.addItem(moveUpItem)

            let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownItem(_:)), keyEquivalent: "")
            moveDownItem.target = self
            moveDownItem.representedObject = ["itemID": item.id, "playlistID": playlist.id]
            moveDownItem.isEnabled = (row < filteredPlaylistItems.count - 1) && !isSearch
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

            let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpLikedSong(_:)), keyEquivalent: "")
            moveUpItem.target = self
            moveUpItem.representedObject = record
            moveUpItem.isEnabled = row > 0 && !isSearch
            menu.addItem(moveUpItem)

            let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownLikedSong(_:)), keyEquivalent: "")
            moveDownItem.target = self
            moveDownItem.representedObject = record
            moveDownItem.isEnabled = (row < filteredLikedSongs.count - 1) && !isSearch
            menu.addItem(moveDownItem)

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

            let isSearch = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let moveUpDlItem = NSMenuItem(title: "Move Up", action: #selector(handleContextMoveUpDownload(_:)), keyEquivalent: "")
            moveUpDlItem.target = self
            moveUpDlItem.representedObject = track
            moveUpDlItem.isEnabled = row > 0 && !isSearch
            menu.addItem(moveUpDlItem)

            let moveDownDlItem = NSMenuItem(title: "Move Down", action: #selector(handleContextMoveDownDownload(_:)), keyEquivalent: "")
            moveDownDlItem.target = self
            moveDownDlItem.representedObject = track
            moveDownDlItem.isEnabled = (row < filteredDownloads.count - 1) && !isSearch
            menu.addItem(moveDownDlItem)

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

    @objc func handleContextOpenPlaylist(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        self.mode = .detail(playlist)
    }

    @objc func handleContextAddCurrentFromList(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        let res = PlaylistManager.shared.appendCurrentPlayingTrack(to: playlist.id)
        if res.success {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Added to \(playlist.name)")
            reload()
        } else {
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: res.message)
        }
    }

    @objc func handleContextRename(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        promptForName(title: "Rename Playlist", defaultName: playlist.name, actionTitle: "Rename") { [weak self] name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if trimmed != playlist.name {
                PlaylistManager.shared.renamePlaylist(id: playlist.id, name: trimmed)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "✓ Renamed to \"\(trimmed)\"")
            }
            self?.reload()
        }
    }

    @objc func handleContextDeletePlaylist(_ sender: NSMenuItem) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        confirmAndDeletePlaylist(playlist)
    }

    @objc func handleContextPlayItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let itemID = dict["itemID"],
              let playlistID = dict["playlistID"] else { return }
        playPlaylist(playlistID: playlistID, startingAt: itemID)
    }

    @objc func handleContextPlayNextItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.playNext(item: item)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(item.title)")
    }

    @objc func handleContextAddToQueueItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.addToQueue(item: item)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "➕ Added to Queue: \(item.title)")
    }

    @objc func handleContextDownloadItem(_ sender: NSMenuItem) {
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

    @objc func handleContextMoveUpItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let playlistID = dict["playlistID"] as? String else { return }

        let itemID = (dict["itemID"] as? String) ?? ((dict["index"] as? Int).flatMap { idx in
            idx >= 0 && idx < filteredPlaylistItems.count ? filteredPlaylistItems[idx].id : nil
        })
        guard let targetItemID = itemID,
              let currentIdx = allPlaylistItems.firstIndex(where: { $0.id == targetItemID }),
              currentIdx > 0 else { return }

        let targetIdx = currentIdx - 1
        allPlaylistItems.swapAt(currentIdx, targetIdx)
        filteredPlaylistItems = allPlaylistItems

        let itemIDs = allPlaylistItems.map { $0.id }
        PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: itemIDs)
        tableView.reloadData()
    }

    @objc func handleContextMoveDownItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let playlistID = dict["playlistID"] as? String else { return }

        let itemID = (dict["itemID"] as? String) ?? ((dict["index"] as? Int).flatMap { idx in
            idx >= 0 && idx < filteredPlaylistItems.count ? filteredPlaylistItems[idx].id : nil
        })
        guard let targetItemID = itemID,
              let currentIdx = allPlaylistItems.firstIndex(where: { $0.id == targetItemID }),
              currentIdx < allPlaylistItems.count - 1 else { return }

        let targetIdx = currentIdx + 1
        allPlaylistItems.swapAt(currentIdx, targetIdx)
        filteredPlaylistItems = allPlaylistItems

        let itemIDs = allPlaylistItems.map { $0.id }
        PlaylistManager.shared.reorderItems(playlistID: playlistID, orderedItemIDs: itemIDs)
        tableView.reloadData()
    }

    @objc func handleContextRemoveItem(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: String],
              let itemID = dict["itemID"],
              let playlistID = dict["playlistID"] else { return }
        PlaylistManager.shared.removeItem(itemID: itemID, from: playlistID)
        reload()
    }

    @objc func handleContextPlayDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        playDownloadedTrack(track)
    }

    @objc func handleContextPlayNextDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.playNext(track: track)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⏭ Playing Next: \(track.title)")
    }

    @objc func handleContextAddDownloadToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleContextShowDownloadInFinder(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        if FileManager.default.fileExists(atPath: track.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
        } else {
            LocalLibraryManager.shared.openMusicFolderInFinder()
        }
    }

    @objc func handleContextDeleteDownloadItem(_ sender: NSMenuItem) {
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

    @objc func handleContextPlayHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        HistoryManager.shared.playHistoryItem(item)
    }

    @objc func handleContextPlayNextHistoryItem(_ sender: NSMenuItem) {
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

    @objc func handleContextAddToQueueHistoryItem(_ sender: NSMenuItem) {
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

    @objc func handleContextAddHistoryToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleContextDownloadHistoryItem(_ sender: NSMenuItem) {
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

    @objc func handleContextDeleteHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        HistoryManager.shared.deleteHistoryItem(id: item.id)
        reload()
    }

    @objc func handleContextCopyDetailItemToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleContextPlayLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        playLikedSongRecord(record)
    }

    @objc func handleContextPlayNextLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleContextAddToQueueLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleContextAddLikedSongToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleContextNewPlaylistWithLikedSong(_ sender: NSMenuItem) {
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

    @objc func handleContextNewPlaylistWithDownload(_ sender: NSMenuItem) {
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

    @objc func handleContextNewPlaylistWithHistory(_ sender: NSMenuItem) {
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

    @objc func handleContextDownloadLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleContextDeleteLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        LikedSongsManager.shared.removeLikedSong(videoId: record.videoId)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "♥ Removed from Liked Songs")
        reload()
    }

    @objc func handleContextToggleLikeDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        LocalLibraryManager.shared.toggleLike(for: track.id)
        let isLikedNow = !track.isLiked
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: isLikedNow ? "Liked Track" : "Removed Like")
        reload()
    }

    @objc func handleContextMoveUpLikedSong(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord,
              let currentIdx = allLikedSongs.firstIndex(where: { $0.videoId == record.videoId }),
              currentIdx > 0 else { return }

        let targetIdx = currentIdx - 1
        allLikedSongs.swapAt(currentIdx, targetIdx)
        filteredLikedSongs = allLikedSongs

        let itemIDs = allLikedSongs.map { $0.videoId }
        PlaylistManager.shared.reorderItems(playlistID: "liked_songs", orderedItemIDs: itemIDs)
        tableView.reloadData()
    }

    @objc func handleContextMoveDownLikedSong(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord,
              let currentIdx = allLikedSongs.firstIndex(where: { $0.videoId == record.videoId }),
              currentIdx < allLikedSongs.count - 1 else { return }

        let targetIdx = currentIdx + 1
        allLikedSongs.swapAt(currentIdx, targetIdx)
        filteredLikedSongs = allLikedSongs

        let itemIDs = allLikedSongs.map { $0.videoId }
        PlaylistManager.shared.reorderItems(playlistID: "liked_songs", orderedItemIDs: itemIDs)
        tableView.reloadData()
    }

    @objc func handleContextMoveUpDownload(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack,
              let currentIdx = allDownloads.firstIndex(where: { $0.id == track.id }),
              currentIdx > 0 else { return }

        let targetIdx = currentIdx - 1
        allDownloads.swapAt(currentIdx, targetIdx)
        filteredDownloads = allDownloads

        let itemIDs = allDownloads.map { $0.id }
        PlaylistManager.shared.reorderItems(playlistID: "downloads", orderedItemIDs: itemIDs)
        tableView.reloadData()
    }

    @objc func handleContextMoveDownDownload(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack,
              let currentIdx = allDownloads.firstIndex(where: { $0.id == track.id }),
              currentIdx < allDownloads.count - 1 else { return }

        let targetIdx = currentIdx + 1
        allDownloads.swapAt(currentIdx, targetIdx)
        filteredDownloads = allDownloads

        let itemIDs = allDownloads.map { $0.id }
        PlaylistManager.shared.reorderItems(playlistID: "downloads", orderedItemIDs: itemIDs)
        tableView.reloadData()
    }
}
