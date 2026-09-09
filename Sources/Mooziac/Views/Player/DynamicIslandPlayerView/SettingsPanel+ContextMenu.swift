import AppKit

extension DynamicIslandPlayerView {
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

    @objc func handleDrawerPlayDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NowPlayingManager.shared.playOfflineTrack(track, in: LocalLibraryManager.shared.allTracks)
    }

    @objc func handleDrawerPlayNextDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.playNext(track: track)
        showToastBanner(message: "⏭ Playing Next: \(track.title)")
    }

    @objc func handleDrawerAddToQueueDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        NativeAudioPlayer.shared.appendToQueue(track: track)
        showToastBanner(message: "➕ Added to Queue: \(track.title)")
    }

    @objc func handleDrawerAddDownloadToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleDrawerNewPlaylistWithDownload(_ sender: NSMenuItem) {
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

    @objc func handleDrawerToggleLikeDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        LocalLibraryManager.shared.toggleLike(for: track.id)

        let isLikedNow =
            LocalLibraryManager.shared.isLiked(trackID: track.id)

        showToastBanner(message: isLikedNow ? "♥ Liked Track" : "Removed Like")
        refreshPlaylistsSection()
    }

    @objc func handleDrawerShowDownloadInFinder(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        if FileManager.default.fileExists(atPath: track.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
        } else {
            LocalLibraryManager.shared.openMusicFolderInFinder()
        }
    }

    @objc func handleDrawerDeleteDownloadItem(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? LocalTrack else { return }
        confirmAndDeleteDownloadedTrack(track)
    }

    @objc func handleDrawerPlayLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = record
        handlePlayLikedSong(fakeBtn)
    }

    @objc func handleDrawerPlayNextLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerAddToQueueLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerAddLikedSongToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleDrawerNewPlaylistWithLikedSong(_ sender: NSMenuItem) {
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

    @objc func handleDrawerDownloadLikedSongItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerDeleteLikedSongItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? LikedSongRecord else { return }
        removeLikedSong(record)
    }

    @objc func handleDrawerPlayHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = record
        handlePlayHistoryRecord(fakeBtn)
    }

    @objc func handleDrawerPlayNextHistoryItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerAddToQueueHistoryItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerAddHistoryToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleDrawerNewPlaylistWithHistory(_ sender: NSMenuItem) {
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

    @objc func handleDrawerDownloadHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = item
        handleDownloadHistoryButtonTapped(fakeBtn)
    }

    @objc func handleDrawerDeleteHistoryItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? HistoryRecord else { return }
        removeHistoryRecord(record)
    }

    @objc func handleDrawerPlayPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord,
              let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.startPlaylist(playlistID: playlist.id, startingAt: item.id, shuffle: false)
    }

    @objc func handleDrawerPlayNextPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.playNext(item: item)
        showToastBanner(message: "⏭ Playing Next: \(item.title)")
    }

    @objc func handleDrawerAddToQueuePlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        PlaylistManager.shared.addToQueue(item: item)
        showToastBanner(message: "➕ Added to Queue: \(item.title)")
    }

    @objc func handleDrawerCopyPlaylistItemToPlaylist(_ sender: NSMenuItem) {
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

    @objc func handleDrawerNewPlaylistWithPlaylistItem(_ sender: NSMenuItem) {
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

    @objc func handleDrawerDownloadPlaylistItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PlaylistItemRecord else { return }
        let fakeBtn = ReactiveIconButton()
        fakeBtn.representedObject = item
        handleDownloadDetailItem(fakeBtn)
    }

    @objc func handleDrawerDeletePlaylistItem(_ sender: NSMenuItem) {
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

    @objc func handlePlayPlaylistFromRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        PlaylistManager.shared.play(playlistID: playlist.id) { [weak self] res in
            if !res.started {
                self?.showToastBanner(message: res.message, isWarning: true)
            }
        }
    }

    @objc func handleShufflePlaylistFromRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        PlaylistManager.shared.shufflePlay(playlistID: playlist.id) { [weak self] res in
            if !res.started {
                self?.showToastBanner(message: res.message, isWarning: true)
            }
        }
    }

    @objc func handleTogglePlaylistRow(_ sender: ReactiveIconButton) {
        guard let playlist = sender.representedObject as? PlaylistRecord else { return }
        let result = PlaylistManager.shared.toggleCurrentPlayingTrack(in: playlist.id)
        showToastBanner(message: result.added ? "✓ Added to \(playlist.name)" : "✕ Removed from \(playlist.name)")
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

    @objc func handleOpenFullPlaylistLibrary() {
        collapseSettings()
        delegate?.dynamicIslandDidTapPlaylistLibrary(playlistID: nil)
    }

    @objc func handleOpenPlaylistDetail(_ sender: NSClickGestureRecognizer) {
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

    @objc func handleBackFromPlaylistDetail() {
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

    @objc func handlePlayPlaylistFromDetail() {
        guard let playlist = playlistDetailMode else { return }
        PlaylistManager.shared.play(playlistID: playlist.id) { [weak self] res in
            self?.showToastBanner(message: res.message, isWarning: !res.started)
        }
    }

    @objc func handleShufflePlaylistFromDetail() {
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

    @objc func handleDownloadAllFromDetailHeader() {
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

    @objc func handleAddToPlaylistRow(_ sender: ReactiveIconButton) {
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

    @objc func handleCreateNewPlaylistFromHeader() {
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

    @objc func handleInlineCreateConfirm() {
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

    @objc func handleInlineCreateCancel() {
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

    @objc func handleDeletePlaylistFromHeader() {
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

    @objc func handleAddCurrentSongToDetailPlaylist() {
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

    @objc func handleSectionLabelClicked() {
        if playlistDetailMode != nil {
            handleRenamePlaylistFromDetailHeader()
        }
    }

    @objc func handleRenamePlaylistFromDetailHeader() {
        guard let playlist = playlistDetailMode else { return }
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Rename Playlist"
        alert.informativeText = "Enter a new name for this playlist:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = playlist.name
        textField.placeholderString = "Playlist Name"
        alert.accessoryView = textField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = textField
        DispatchQueue.main.async {
            textField.selectText(nil)
        }

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty && newName != playlist.name else { return }
            PlaylistManager.shared.renamePlaylist(id: playlist.id, name: newName)
            if let updated = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlist.id }) {
                self.playlistDetailMode = updated
                self.playlistSectionLabel.stringValue = updated.name.uppercased()
            }
            showToastBanner(message: "✓ Renamed to \"\(newName)\"")
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    @objc func handlePlaylistContextRename(_ sender: NSMenuItem) {
        guard let playlistID = sender.representedObject as? String,
              let playlist = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlistID }) else { return }
        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Rename Playlist"
        alert.informativeText = "Enter a new name for this playlist:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = playlist.name
        textField.placeholderString = "Playlist Name"
        alert.accessoryView = textField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = textField
        DispatchQueue.main.async {
            textField.selectText(nil)
        }

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty && newName != playlist.name else { return }
            PlaylistManager.shared.renamePlaylist(id: playlist.id, name: newName)
            if self.playlistDetailMode?.id == playlist.id,
               let updated = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == playlist.id }) {
                self.playlistDetailMode = updated
                self.playlistSectionLabel.stringValue = updated.name.uppercased()
            }
            showToastBanner(message: "✓ Renamed to \"\(newName)\"")
            refreshPlaylistsSection()
            updateSettingsThemeHighlight()
        }
    }

    @objc func handlePlaylistsUpdated() {
        if let currentDetail = playlistDetailMode {
            if let updated = PlaylistManager.shared.fetchPlaylists().first(where: { $0.id == currentDetail.id }) {
                self.playlistDetailMode = updated
                self.playlistSectionLabel.stringValue = updated.name.uppercased()
            }
        }
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
    }

}
