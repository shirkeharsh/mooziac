import AppKit

private final class SearchResultRow: NSView {
    var onSelect: (() -> Void)?
    var onQueue: (() -> Void)?
    var onToggleLike: (() -> Bool)?
    var onAddToPlaylist: ((String) -> Void)?
    private let track: YTMClient.Track
    private let artwork = NSImageView()
    private let videoBadge = NSTextField(labelWithString: "VIDEO")
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let playIndicator = NSImageView()
    private let queueButton = NSButton()
    private let likeButton = NSButton()
    private let moreButton = NSButton()
    private var isLiked: Bool
    private var isLightTheme = false

    init(track: YTMClient.Track, isLiked: Bool) {
        self.track = track
        self.isLiked = isLiked
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 7
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artwork.imageScaling = .scaleProportionallyUpOrDown
        artwork.wantsLayer = true
        artwork.layer?.cornerRadius = 5
        artwork.layer?.masksToBounds = true
        artwork.image = AppArtworkHelper.defaultArtwork
        playIndicator.translatesAutoresizingMaskIntoConstraints = false
        playIndicator.image = NSImage(systemSymbolName: track.isVideo ? "video.fill" : "play.fill", accessibilityDescription: track.isVideo ? "Video" : "Play")
        playIndicator.alphaValue = 0.8
        configureActionButton(queueButton, symbol: "text.badge.plus", tooltip: "Add to Queue", action: #selector(queuePressed))
        configureActionButton(likeButton, symbol: isLiked ? "heart.fill" : "heart", tooltip: isLiked ? "Remove from Liked Songs" : "Add to Liked Songs", action: #selector(likePressed))
        configureActionButton(moreButton, symbol: "ellipsis", tooltip: "Add to Playlist", action: #selector(morePressed(_:)))
        for label in [titleLabel, detailLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            label.isSelectable = false
            label.refusesFirstResponder = true
        }
        titleLabel.stringValue = track.title
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        detailLabel.stringValue = [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · ")
        detailLabel.font = .systemFont(ofSize: 9.5)
        detailLabel.textColor = .secondaryLabelColor
        addSubview(artwork)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(playIndicator)
        addSubview(queueButton)
        addSubview(likeButton)
        addSubview(moreButton)

        var titleLeadingAnchor = artwork.trailingAnchor
        var titleLeadingOffset: CGFloat = 8

        if track.isVideo {
            videoBadge.translatesAutoresizingMaskIntoConstraints = false
            videoBadge.font = .systemFont(ofSize: 8, weight: .bold)
            videoBadge.textColor = .white
            videoBadge.alignment = .center
            videoBadge.wantsLayer = true
            videoBadge.layer?.cornerRadius = 3
            videoBadge.layer?.masksToBounds = true
            videoBadge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
            addSubview(videoBadge)

            NSLayoutConstraint.activate([
                videoBadge.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 7),
                videoBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                videoBadge.widthAnchor.constraint(equalToConstant: 32),
                videoBadge.heightAnchor.constraint(equalToConstant: 13)
            ])
            titleLeadingAnchor = videoBadge.trailingAnchor
            titleLeadingOffset = 4
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 42),
            artwork.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            artwork.centerYAnchor.constraint(equalTo: centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 32), artwork.heightAnchor.constraint(equalToConstant: 32),
            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            moreButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 20), moreButton.heightAnchor.constraint(equalToConstant: 24),
            likeButton.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -1),
            likeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 20), likeButton.heightAnchor.constraint(equalToConstant: 24),
            queueButton.trailingAnchor.constraint(equalTo: likeButton.leadingAnchor, constant: -1),
            queueButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            queueButton.widthAnchor.constraint(equalToConstant: 20), queueButton.heightAnchor.constraint(equalToConstant: 24),
            playIndicator.trailingAnchor.constraint(equalTo: queueButton.leadingAnchor, constant: -5),
            playIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            playIndicator.widthAnchor.constraint(equalToConstant: 12), playIndicator.heightAnchor.constraint(equalToConstant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: titleLeadingAnchor, constant: titleLeadingOffset),
            titleLabel.trailingAnchor.constraint(equalTo: playIndicator.leadingAnchor, constant: -5),
            titleLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            detailLabel.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 1)
        ])
        applyTheme(isLight: PlayerDesign.current == .glassMode ||
                   (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        loadArtwork(for: track)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // NSView.hitTest receives the point in superview coordinates.
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        guard bounds.contains(localPoint) else { return nil }
        for button in [queueButton, likeButton, moreButton] where button.frame.contains(localPoint) {
            return button
        }
        return self
    }
    override func mouseDown(with event: NSEvent) { onSelect?() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    func applyTheme(isLight: Bool) {
        isLightTheme = isLight
        let primary = isLight ? NSColor(white: 0.08, alpha: 1) : NSColor(white: 0.96, alpha: 1)
        let secondary = isLight ? NSColor(white: 0.12, alpha: 0.68) : NSColor(white: 0.9, alpha: 0.68)
        titleLabel.textColor = primary
        detailLabel.textColor = secondary
        layer?.backgroundColor = NSColor(white: isLight ? 0 : 1, alpha: 0.025).cgColor
        playIndicator.contentTintColor = secondary
        queueButton.contentTintColor = secondary
        moreButton.contentTintColor = secondary
        likeButton.contentTintColor = isLiked ? NSColor.systemPink : secondary
    }

    private func configureActionButton(_ button: NSButton, symbol: String, tooltip: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .inline
        button.setButtonType(.momentaryChange)
        button.toolTip = tooltip
        button.target = self
        button.action = action
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium))
        button.focusRingType = .none
    }

    @objc private func queuePressed() { onQueue?() }

    @objc private func likePressed() {
        guard let nextValue = onToggleLike?() else { return }
        isLiked = nextValue
        likeButton.image = NSImage(systemSymbolName: isLiked ? "heart.fill" : "heart",
                                   accessibilityDescription: isLiked ? "Remove from Liked Songs" : "Add to Liked Songs")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium))
        likeButton.toolTip = isLiked ? "Remove from Liked Songs" : "Add to Liked Songs"
        applyTheme(isLight: isLightTheme)
    }

    @objc private func morePressed(_ sender: NSButton) {
        let menu = NSMenu(title: "Add to Playlist")
        let playlists = PlaylistManager.shared.fetchPlaylists()
        if playlists.isEmpty {
            let empty = NSMenuItem(title: "No playlists yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for playlist in playlists {
                let item = NSMenuItem(title: playlist.name, action: #selector(playlistPicked(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = playlist.id
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func playlistPicked(_ item: NSMenuItem) {
        guard let playlistID = item.representedObject as? String else { return }
        onAddToPlaylist?(playlistID)
    }

    private func loadArtwork(for track: YTMClient.Track) {
        let cache = AppArtworkHelper.shared
        let fallbackURL = URL(string: "https://i.ytimg.com/vi/\(track.videoId)/hqdefault.jpg")
        let cacheKey = track.artworkUrl.isEmpty ? (fallbackURL?.absoluteString ?? track.videoId) : track.artworkUrl
        if let cached = cache.getMemoryCachedImage(forKey: cacheKey) {
            artwork.image = cached
            return
        }
        var urls: [URL] = []
        if let primary = URL(string: track.artworkUrl) { urls.append(primary) }
        if let fallback = fallbackURL, !urls.contains(fallback) {
            urls.append(fallback)
        }
        func loadNext(_ index: Int) {
            guard index < urls.count else { return }
            URLSession.shared.dataTask(with: urls[index]) { [weak self] data, response, _ in
                let succeeded = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
                if succeeded, let data {
                    let thumb: NSImage
                    if let source = CGImageSourceCreateWithData(data as CFData, nil),
                       let rawCG = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 128] as CFDictionary) {
                        let squareCG = AppArtworkHelper.cropToCenterSquare(cgImage: rawCG)
                        thumb = NSImage(cgImage: squareCG, size: NSSize(width: 44, height: 44))
                    } else if let img = NSImage(data: data) {
                        thumb = img
                    } else {
                        thumb = AppArtworkHelper.defaultArtwork
                    }
                    cache.setMemoryCachedImage(thumb, forKey: cacheKey)
                    DispatchQueue.main.async { self?.artwork.image = thumb }
                } else {
                    loadNext(index + 1)
                }
            }.resume()
        }
        loadNext(0)
    }
}

extension DynamicIslandPlayerView {
    func updateSearchResultsTheme() {
        let isLight = PlayerDesign.current == .glassMode ||
            (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance)
        let color = isLight ? NSColor(white: 0.12, alpha: 0.78) : NSColor(white: 0.92, alpha: 0.78)
        searchResultsStatusLabel?.textColor = color
        searchResultsStack?.arrangedSubviews.compactMap { $0 as? SearchResultRow }.forEach { $0.applyTheme(isLight: isLight) }
    }

    func setupSearchResultsPanel() {
        let panel = NSView()
        panel.identifier = NSUserInterfaceItemIdentifier("SearchResultsPanel")
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true

        let status = NSTextField(labelWithString: "")
        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 10, weight: .medium)
        status.isHidden = true

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        document.addSubview(stack)
        scroll.documentView = document
        panel.addSubview(status)
        panel.addSubview(scroll)
        settingsContainerView.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: settingsContainerView.topAnchor, constant: 4),
            panel.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 4),
            panel.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -4),
            panel.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: -4),
            status.topAnchor.constraint(equalTo: panel.topAnchor, constant: 2),
            status.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            status.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 3),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])
        searchResultsStack = stack
        searchResultsStatusLabel = status
        updateSearchResultsTheme()
    }

    func searchTextChanged() {
        cancelLiveSearch()
        let rawQuery = searchField.stringValue
        let isVideoSearch = rawQuery.hasPrefix("/")
        let cleanQuery: String = {
            if rawQuery.hasPrefix("/video ") {
                return String(rawQuery.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if rawQuery.hasPrefix("/v ") {
                return String(rawQuery.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if rawQuery.hasPrefix("/ ") {
                return String(rawQuery.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if rawQuery.hasPrefix("/") {
                return String(rawQuery.dropFirst(1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        guard !cleanQuery.isEmpty else {
            if isVideoSearch {
                showSearchPanelStatus("🎬 Type song name to search videos (e.g. /songname)")
            } else {
                hideSearchResultsPanel()
                if isSettingsExpanded && activeSettingsMode == .search { collapseSettings() }
            }
            return
        }
        guard !URLFilter.containsLink(cleanQuery) else {
            showSearchPanelStatus("Search with a song title or artist")
            return
        }
        guard NetworkMonitor.shared.isReachable else {
            showSearchPanelStatus("You're offline. Connect to search YouTube Music.")
            return
        }
        showSearchPanelStatus(isVideoSearch ? "Searching YouTube Music Videos…" : "Searching YouTube Music…")
        let work = DispatchWorkItem { [weak self] in self?.runLiveSearch(cleanQuery, isVideo: isVideoSearch) }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func cancelLiveSearch() {
        searchDebounce?.cancel()
        searchDebounce = nil
        liveSearchRequest?.cancel()
        liveSearchRequest = nil
        searchResultsToken += 1
    }

    private func runLiveSearch(_ query: String, isVideo: Bool = false) {
        guard isSearchFieldActive, NetworkMonitor.shared.isReachable else { return }
        let token = searchResultsToken
        let filter: YTMClient.SearchFilter = isVideo ? .videos : .songs
        liveSearchRequest = YTMClient.shared.searchTracks(query: query, filter: filter) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, token == self.searchResultsToken, self.isSearchFieldActive else { return }
                self.liveSearchRequest = nil
                switch result {
                case .success(let tracks):
                    if tracks.isEmpty {
                        self.showSearchPanelStatus(isVideo ? "No video songs found. Try another search." : "No songs found. Try another search.")
                    } else {
                        self.showSearchResults(tracks, isVideo: isVideo)
                    }
                case .failure(let error):
                    if let error = error as? YTMClient.YTMError, case .notSignedIn = error {
                        self.showSearchPanelStatus("Sign in to YouTube Music to search.")
                    } else {
                        self.showSearchPanelStatus("Couldn't load results. Check your connection and try again.")
                    }
                }
            }
        }
    }

    func showSearchPanelStatus(_ message: String) {
        guard let status = searchResultsStatusLabel else { return }
        status.stringValue = message
        status.isHidden = false
        updateSearchResultsTheme()
        searchResultsStack?.arrangedSubviews.forEach { view in
            searchResultsStack?.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        presentSearchPanel()
    }

    private func showSearchResults(_ tracks: [YTMClient.Track], isVideo: Bool = false) {
        guard let stack = searchResultsStack, let status = searchResultsStatusLabel else { return }
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        status.stringValue = isVideo ? "VIDEOS ONLY" : "SONGS"
        status.isHidden = false
        for track in tracks {
            let row = SearchResultRow(track: track, isLiked: LikedSongsManager.shared.isLiked(videoId: track.videoId))
            row.onSelect = { [weak self] in self?.selectSearchResult(track) }
            row.onQueue = { [weak self] in self?.queueSearchResult(track) }
            row.onToggleLike = { [weak self] in
                guard let self else { return false }
                return self.toggleSearchResultLike(track)
            }
            row.onAddToPlaylist = { [weak self] playlistID in self?.addSearchResult(track, to: playlistID) }
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        updateSearchResultsTheme()
        presentSearchPanel()
    }

    private func presentSearchPanel() {
        if activeSettingsMode == .visual {
            delegate?.dynamicIslandDidToggleVisualStage(isActive: false, hostView: nil)
        }
        for identifier in ["MainSettingsStack", "PlaylistSubView", "GestureMappingSubView", "VisualStageSubView"] {
            settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier(identifier) })?.isHidden = true
        }
        updateArtworkHighlight()
        settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("SearchResultsPanel") })?.isHidden = false
        settingsHeaderLabel.isHidden = true
        activeSettingsMode = .search
        settingsContainerHeightConstraint?.constant = 272
        expandSettingsPanel()
    }

    func hideSearchResultsPanel() {
        settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("SearchResultsPanel") })?.isHidden = true
    }

    private func selectSearchResult(_ track: YTMClient.Track) {
        window?.makeFirstResponder(nil)
        delegate?.dynamicIslandDidSelectTrack(videoId: track.videoId, title: track.title, artist: track.artist)
    }

    private func queueSearchResult(_ track: YTMClient.Track) {
        let item = PlaylistItemRecord(playlistID: "search-results", sortOrder: 0, refType: "yt", refID: track.videoId,
                                      ytVideoId: track.videoId, title: track.title, artist: track.artist,
                                      artworkUrl: track.artworkUrl, duration: "", isLiked: false)
        PlaylistManager.shared.enqueueSearchResult(item)
        let count = PlaylistManager.shared.pendingSearchQueueCount
        showToastBanner(message: "➕ Added to Queue · \(count) waiting")
    }

    private func toggleSearchResultLike(_ track: YTMClient.Track) -> Bool {
        let liked = !LikedSongsManager.shared.isLiked(videoId: track.videoId)
        if liked {
            LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(videoId: track.videoId, title: track.title,
                artist: track.artist, album: track.album, artworkUrl: track.artworkUrl, duration: 0, synced: false))
            NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
            if LikedSongsManager.shared.isSignedIn {
                YTMClient.shared.like(videoId: track.videoId, liked: true) { result in
                    if case .success = result { LocalDatabaseManager.shared.setLikedSongSynced(videoId: track.videoId) }
                }
            }
        } else {
            LikedSongsManager.shared.removeLikedSong(videoId: track.videoId)
        }
        showToastBanner(message: liked ? "♥ Added to Liked Songs" : "Removed from Liked Songs")
        return liked
    }

    private func addSearchResult(_ track: YTMClient.Track, to playlistID: String) {
        let record = LikedSongRecord(videoId: track.videoId, title: track.title, artist: track.artist,
                                     album: track.album, artworkUrl: track.artworkUrl, duration: 0, synced: false)
        let result = PlaylistManager.shared.appendLikedSong(to: playlistID, record: record)
        showToastBanner(message: result.success ? result.message : result.message, isWarning: !result.success)
    }
}
