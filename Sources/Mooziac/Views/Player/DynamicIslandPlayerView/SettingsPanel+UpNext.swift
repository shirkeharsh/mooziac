import AppKit

// MARK: - Model

/// One row of the "Up Next" library tab.
/// `sourceIndex` is the position in the engine's own list (YouTube Music queue,
/// autoplay suggestions, or the native offline queue) and is what playback actions use.
struct UpNextEntry: Equatable {
    enum Kind { case queue, autoplay, offline }

    var id: String
    var kind: Kind
    var sourceIndex: Int
    var title: String
    var artist: String
    var duration: String
    var videoId: String
    var isCurrent: Bool
    var track: LocalTrack?

    /// Only upcoming queue / offline songs can be removed or reordered.
    var canModify: Bool { kind != .autoplay && !isCurrent }
}

// MARK: - Loading & Refresh

extension DynamicIslandPlayerView {

    var isUpNextVisible: Bool {
        return isSettingsExpanded
            && activeSettingsMode == .playlist
            && activeLibraryTab == .upNext
            && playlistDetailMode == nil
    }

    /// Fetches the current queue from whichever engine is active and refreshes the tab if it changed.
    /// - Parameters:
    ///   - force: rebuild the rows even if nothing changed.
    ///   - preserveScroll: keep the scroll position (used for background refreshes).
    ///   - delay: wait before reading (lets YouTube Music finish a queue edit).
    ///   - completion: called with whatever was read, even if a newer refresh superseded the UI update.
    func reloadUpNext(force: Bool = false,
                      preserveScroll: Bool = true,
                      delay: TimeInterval = 0,
                      completion: (([UpNextEntry]) -> Void)? = nil) {
        upNextLoadToken += 1
        let token = upNextLoadToken
        let run: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.loadUpNextEntries { entries in
                if token == self.upNextLoadToken, self.isUpNextVisible {
                    self.applyUpNext(entries: entries, force: force, preserveScroll: preserveScroll)
                }
                completion?(entries)
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
        } else {
            run()
        }
    }

    private func loadUpNextEntries(completion: @escaping ([UpNextEntry]) -> Void) {
        if NowPlayingManager.shared.engineMode == .offline {
            let entries = offlineUpNextEntries()
            DispatchQueue.main.async { completion(entries) }
            return
        }
        NowPlayingManager.shared.fetchUpNextSnapshot { snapshot in
            var entries = DynamicIslandPlayerView.makeUpNextEntries(from: snapshot)
            if entries.isEmpty {
                NSLog("[UpNext] YouTube Music returned no queue items; showing the playing song only")
                entries = DynamicIslandPlayerView.playingSongOnlyEntries()
            }
            completion(entries)
        }
    }

    /// Used when the queue can't be read yet, so the tab is never blank while a song is playing.
    private static func playingSongOnlyEntries() -> [UpNextEntry] {
        let state = NowPlayingManager.shared.currentState
        guard !state.title.isEmpty, state.title != "Not Playing" else { return [] }
        return [UpNextEntry(id: "c0", kind: .queue, sourceIndex: 0, title: state.title, artist: state.artist,
                            duration: "", videoId: "", isCurrent: true, track: nil)]
    }

    private static func makeUpNextEntries(from snapshot: NowPlayingManager.UpNextSnapshot) -> [UpNextEntry] {
        var result: [UpNextEntry] = []
        let items = snapshot.items
        var currentPos = items.firstIndex(where: { $0.isSelected })
        if currentPos == nil {
            // The page didn't mark a selected row: match the playing song by title instead.
            let playing = NowPlayingManager.shared.currentState.title.lowercased()
            if !playing.isEmpty {
                currentPos = items.firstIndex(where: { $0.title.lowercased() == playing })
            }
        }
        let startPos = currentPos ?? 0

        if !items.isEmpty {
            for pos in startPos..<items.count {
                let item = items[pos]
                result.append(UpNextEntry(
                    id: "q\(item.index)",
                    kind: .queue,
                    sourceIndex: item.index,
                    title: item.title,
                    artist: item.artist,
                    duration: item.duration,
                    videoId: item.videoId,
                    isCurrent: (pos == currentPos),
                    track: nil
                ))
            }
        }

        // Nothing queued after the current song: show YouTube Music's autoplay suggestions instead.
        let upcomingCount = result.filter { !$0.isCurrent }.count
        if upcomingCount == 0 {
            for item in snapshot.automixItems {
                result.append(UpNextEntry(
                    id: "a\(item.index)",
                    kind: .autoplay,
                    sourceIndex: item.index,
                    title: item.title,
                    artist: item.artist,
                    duration: "",
                    videoId: "",
                    isCurrent: false,
                    track: nil
                ))
            }
        }
        return result
    }

    private func offlineUpNextEntries() -> [UpNextEntry] {
        let player = NativeAudioPlayer.shared
        let list = player.isShuffleActive ? player.shuffledQueue : player.currentQueue
        guard !list.isEmpty else { return [] }
        let current = player.currentIndex
        let start = (current >= 0 && current < list.count) ? current : 0
        var result: [UpNextEntry] = []
        for idx in start..<list.count {
            let t = list[idx]
            result.append(UpNextEntry(
                id: "o\(idx)",
                kind: .offline,
                sourceIndex: idx,
                title: t.title,
                artist: t.artist,
                duration: DynamicIslandPlayerView.formatUpNextDuration(t.duration),
                videoId: t.ytVideoId ?? "",
                isCurrent: (idx == current),
                track: t
            ))
        }
        return result
    }

    private static func formatUpNextDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func applyUpNext(entries: [UpNextEntry], force: Bool, preserveScroll: Bool) {
        let signature = entries.map { "\($0.id)|\($0.videoId)|\($0.title)|\($0.isCurrent)" }.joined(separator: "§")
        // Never rebuild the list under the user's finger while they are dragging a row.
        if playlistIsReordering { return }
        if !force && signature == upNextRenderedSignature { return }
        upNextRenderedSignature = signature
        upNextEntries = entries

        let savedY = playlistScrollView?.contentView.bounds.origin.y ?? 0
        refreshPlaylistsSection(filterQuery: playlistSearchField?.stringValue ?? "")
        if preserveScroll, savedY > 0, let scroll = playlistScrollView {
            let estimatedHeight = CGFloat(entries.count) * 49 + 46
            let maxY = max(0, estimatedHeight - scroll.contentView.bounds.height)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: min(savedY, maxY)))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    // MARK: Polling

    func startUpNextPolling() {
        stopUpNextPolling()
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if self.isUpNextVisible {
                self.reloadUpNext()
            } else {
                self.stopUpNextPolling()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        upNextTimer = timer
    }

    func stopUpNextPolling() {
        upNextTimer?.invalidate()
        upNextTimer = nil
    }

    /// Called whenever the tab is drawn: makes sure the list is live (polling) while it is on screen.
    func ensureUpNextLive() {
        guard isUpNextVisible, upNextTimer == nil else { return }
        startUpNextPolling()
        reloadUpNext(force: false)
    }

    // MARK: Row building (used by refreshPlaylistsSection)

    func upNextRowBuilders(query: String, tone: SettingsTone) -> (builders: [() -> NSView], ids: [String], empty: String?) {
        var entries = upNextEntries
        if !query.isEmpty {
            entries = entries.filter { $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query) }
        }
        if entries.isEmpty {
            if !query.isEmpty { return ([], [], "No matching songs in Up Next") }
            let offline = NowPlayingManager.shared.engineMode == .offline
            let text = offline
                ? "Nothing queued. Play a downloaded song and the songs after it show here."
                : "Nothing in Up Next yet. Play a song and what plays next shows here."
            return ([], [], text)
        }
        let ids = entries.map { "upnext-\($0.id)" }
        let builders: [() -> NSView] = entries.map { entry in
            { [weak self] in self?.makeUpNextRow(entry: entry, tone: tone) ?? NSView() }
        }
        return (builders, ids, nil)
    }

    func upNextHeaderText(query: String) -> String {
        if !query.isEmpty { return "SEARCH RESULTS" }
        let upcoming = upNextEntries.filter { !$0.isCurrent }
        if upNextEntries.contains(where: { $0.kind == .autoplay }) { return "UP NEXT · AUTOPLAY SUGGESTIONS" }
        if upcoming.isEmpty {
            return upNextEntries.first?.id == "c0" ? "UP NEXT · QUEUE NOT LOADED YET" : "UP NEXT"
        }
        return "UP NEXT · \(upcoming.count) SONG\(upcoming.count == 1 ? "" : "S")"
    }

    private func makeUpNextRow(entry: UpNextEntry, tone: SettingsTone) -> NSView {
        let swipeContainer = SwipeToDeleteContainerView()
        swipeContainer.translatesAutoresizingMaskIntoConstraints = false
        swipeContainer.deleteButtonTitle = "Remove"
        swipeContainer.layer?.cornerRadius = 14
        swipeContainer.layer?.masksToBounds = true
        swipeContainer.identifier = NSUserInterfaceItemIdentifier("upnext-\(entry.id)")

        let rowView = UpNextRowView(entry: entry, tone: tone, delegate: self)
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
            self?.removeUpNextEntry(entry)
        }
        swipeContainer.onRightSwipePlay = { [weak self] in
            self?.playUpNextEntry(entry)
            return true
        }
        swipeContainer.onRowClicked = { [weak self] in
            self?.playUpNextEntry(entry)
        }
        return swipeContainer
    }

    // MARK: Actions

    @objc func handlePlayUpNextEntry(_ sender: ReactiveIconButton) {
        guard let entry = sender.representedObject as? UpNextEntry else { return }
        playUpNextEntry(entry)
    }

    func playUpNextEntry(_ entry: UpNextEntry) {
        if entry.isCurrent {
            NowPlayingManager.shared.togglePlayPause()
            return
        }
        switch entry.kind {
        case .queue:
            NowPlayingManager.shared.playQueueTarget(index: entry.sourceIndex, videoId: entry.videoId)
            ensureQueueSongStarted(entry)
        case .autoplay:
            NowPlayingManager.shared.playAutomixItem(at: entry.sourceIndex)
        case .offline:
            if let track = entry.track {
                NativeAudioPlayer.shared.play(track: track)
            }
        }
        // Playback notifications refresh the list too; this is a safety net for slow page updates.
        reloadUpNext(force: true, preserveScroll: false, delay: 0.8)
    }

    /// If the tap on the queue row didn't start the song, start it by video id instead.
    private func ensureQueueSongStarted(_ entry: UpNextEntry) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let playing = NowPlayingManager.shared.currentState.title.lowercased()
            guard playing != entry.title.lowercased() else { return }
            guard let container = StatusItemManager.shared?.mainViewController.webViewContainer else {
                return
            }
            if !entry.videoId.isEmpty {
                container.navigateToVideo(videoId: entry.videoId)
            } else if !entry.title.isEmpty {
                let query = entry.artist.isEmpty ? entry.title : "\(entry.title) \(entry.artist)"
                StatusItemManager.shared?.mainViewController.playSearchQuery(query)
            }
        }
    }

    func removeUpNextEntry(_ entry: UpNextEntry) {
        guard entry.canModify else {
            showToastBanner(message: entry.isCurrent ? "⚠️ Can't remove the song that's playing" : "⚠️ Autoplay suggestions can't be removed", isWarning: true)
            refreshPlaylistsSection(filterQuery: playlistSearchField?.stringValue ?? "")
            return
        }

        switch entry.kind {
        case .queue:
            NowPlayingManager.shared.removeQueueItem(at: entry.sourceIndex)
        case .offline:
            if let track = entry.track {
                NativeAudioPlayer.shared.removeFromQueue(trackID: track.id)
            }
        case .autoplay:
            return
        }

        // Update immediately; the follow-up read below confirms what the player really did.
        var updated = upNextEntries
        updated.removeAll { $0.id == entry.id }
        upNextEntries = reindexed(updated, slots: upNextEntries.map { $0.sourceIndex })
        upNextRenderedSignature = ""
        refreshPlaylistsSection(filterQuery: playlistSearchField?.stringValue ?? "")
        showToastBanner(message: "🗑 Removed from Up Next")

        let removedVideoId = entry.videoId
        reloadUpNext(force: true, preserveScroll: true, delay: 0.8) { [weak self] fresh in
            guard let self = self, !removedVideoId.isEmpty, entry.kind == .queue else { return }
            let upcomingIDs = fresh.filter { !$0.isCurrent }.map { $0.videoId }
            if upcomingIDs.contains(removedVideoId) {
                self.showToastBanner(message: "⚠️ YouTube Music didn't remove it — list refreshed", isWarning: true)
            }
        }
    }

    /// Called when a drag ends. `newOrderIDs` is the full list of row ids (without the "upnext-" prefix) in display order.
    func applyUpNextReorder(newOrderIDs: [String]) {
        let old = upNextEntries
        let oldIDs = old.map { $0.id }
        guard newOrderIDs.count == oldIDs.count, Set(newOrderIDs) == Set(oldIDs), newOrderIDs != oldIDs else { return }

        // A drag moves exactly one row: find it from the first and last positions that differ.
        var first = -1
        var last = -1
        for i in 0..<oldIDs.count where oldIDs[i] != newOrderIDs[i] {
            if first < 0 { first = i }
            last = i
        }
        guard first >= 0 else { return }

        let movedID: String
        if newOrderIDs[first] == oldIDs[last] {
            movedID = oldIDs[last]      // moved up
        } else {
            movedID = oldIDs[first]     // moved down
        }
        guard let fromPos = oldIDs.firstIndex(of: movedID),
              let toPos = newOrderIDs.firstIndex(of: movedID) else { return }

        let moved = old[fromPos]
        let destination = old[toPos]

        // The playing song stays on top and suggestions can't move: put things back.
        guard moved.canModify, destination.kind == moved.kind, !destination.isCurrent else {
            showToastBanner(message: "⚠️ Songs can only be moved below the playing song", isWarning: true)
            upNextRenderedSignature = ""
            refreshPlaylistsSection(filterQuery: playlistSearchField?.stringValue ?? "")
            return
        }

        switch moved.kind {
        case .queue:
            NowPlayingManager.shared.moveQueueItem(from: moved.sourceIndex, to: destination.sourceIndex)
        case .offline:
            NativeAudioPlayer.shared.moveInQueue(from: moved.sourceIndex, to: destination.sourceIndex)
        case .autoplay:
            return
        }

        // Keep the new order on screen, then confirm against the player.
        let byID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        let reordered = newOrderIDs.compactMap { byID[$0] }
        upNextEntries = reindexed(reordered, slots: old.map { $0.sourceIndex })
        upNextRenderedSignature = ""

        let expected = reordered.map { $0.videoId }
        let canVerify = moved.kind == .queue && !expected.contains(where: { $0.isEmpty })
        reloadUpNext(force: true, preserveScroll: true, delay: 0.8) { [weak self] fresh in
            guard let self = self, canVerify else { return }
            let actual = fresh.filter { $0.kind == .queue }.map { $0.videoId }
            if actual != expected {
                self.showToastBanner(message: "⚠️ YouTube Music kept its own order — list refreshed", isWarning: true)
            }
        }
    }

    /// Gives each entry the engine position that its slot used to have, so repeated edits stay correct before the next refresh.
    private func reindexed(_ entries: [UpNextEntry], slots: [Int]) -> [UpNextEntry] {
        let sortedSlots = slots.sorted()
        var out = entries
        for i in out.indices {
            if i < sortedSlots.count, out[i].kind != .autoplay {
                out[i].sourceIndex = sortedSlots[i]
            }
        }
        return out
    }

    @objc func handleUpNextRadioTapped() {
        guard NowPlayingManager.shared.engineMode != .offline else {
            showToastBanner(message: "⚠️ Autoplay radio needs online playback", isWarning: true)
            return
        }
        NowPlayingManager.shared.triggerAutoplayRadio()
        showToastBanner(message: "📻 Autoplay radio on")
        reloadUpNext(force: true, preserveScroll: false, delay: 1.2)
    }

    @objc func handleUpNextSaveTapped() {
        guard NowPlayingManager.shared.engineMode != .offline else {
            showToastBanner(message: "⚠️ Saving the queue works for online playback", isWarning: true)
            return
        }
        guard upNextEntries.contains(where: { $0.kind == .queue }) else {
            showToastBanner(message: "⚠️ No songs in Up Next to save", isWarning: true)
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"

        let alert = NSAlert()
        alert.window.level = .statusBar + 1
        alert.messageText = "Save Queue as Playlist"
        alert.informativeText = "Give the new playlist a name."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = "Queue \(formatter.string(from: Date()))"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        PlaylistManager.shared.createPlaylistFromCurrentQueue(name: name) { [weak self] playlistID, count in
            DispatchQueue.main.async {
                if playlistID != nil, count > 0 {
                    self?.showToastBanner(message: "✓ Saved \(count) song\(count == 1 ? "" : "s") to \"\(name)\"")
                } else {
                    self?.showToastBanner(message: "⚠️ Couldn't save the queue", isWarning: true)
                }
            }
        }
    }
}

// MARK: - Row View

final class UpNextRowView: NSView {
    let entry: UpNextEntry
    weak var delegate: DynamicIslandPlayerView?
    private var currentTone: SettingsTone

    let playBtn = ReactiveIconButton()
    let titleLbl = NSTextField(labelWithString: "")
    let metaLbl = NSTextField(labelWithString: "")
    let durationLbl = NSTextField(labelWithString: "")

    init(entry: UpNextEntry, tone: SettingsTone, delegate: DynamicIslandPlayerView) {
        self.entry = entry
        self.delegate = delegate
        self.currentTone = tone
        super.init(frame: .zero)
        setupUI(tone: tone)
        updatePlayingAppearance(tone: tone)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePlayingAppearance(tone: SettingsTone) {
        self.currentTone = tone
        let accent = settingsAccentColor(tone: tone)
        let isGlass = (PlayerDesign.current == .glassMode)
        let playConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)

        if entry.isCurrent {
            let isPlaybackActive: Bool
            if NowPlayingManager.shared.engineMode == .offline {
                isPlaybackActive = NativeAudioPlayer.shared.isPlaying
            } else {
                isPlaybackActive = NowPlayingManager.shared.currentState.isPlaying
            }
            layer?.borderColor = accent.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1.2
            layer?.backgroundColor = accent.withAlphaComponent(isGlass ? 0.12 : 0.14).cgColor
            titleLbl.textColor = accent
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
            let symbol = isPlaybackActive ? "speaker.wave.2.fill" : "pause.fill"
            playBtn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Now playing")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = accent
            playBtn.toolTip = isPlaybackActive ? "Pause" : "Resume"
        } else {
            let isLiquidDark = (PlayerDesign.current == .liquidFluid && SystemAppearanceHelper.isDarkSystemAppearance)
            layer?.borderColor = isLiquidDark ? NSColor(white: 1.0, alpha: 0.20).cgColor : tone.dividerColor.cgColor
            layer?.borderWidth = 1.0
            layer?.backgroundColor = isLiquidDark
                ? NSColor(white: 1.0, alpha: 0.16).cgColor
                : (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor
            titleLbl.textColor = tone.primaryText
            titleLbl.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            playBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
            playBtn.contentTintColor = rowPlayIconColor(tone: tone)
            playBtn.toolTip = "Play now"
        }
    }

    private func setupUI(tone: SettingsTone) {
        wantsLayer = true
        layer?.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.isBordered = false
        playBtn.representedObject = entry
        playBtn.target = delegate
        playBtn.action = #selector(DynamicIslandPlayerView.handlePlayUpNextEntry(_:))
        playBtn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(playBtn)

        titleLbl.stringValue = entry.title
        titleLbl.maximumNumberOfLines = 1
        titleLbl.usesSingleLineMode = true
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let artistText: String
        switch entry.kind {
        case .autoplay: artistText = entry.artist.isEmpty ? "Autoplay suggestion" : "\(entry.artist) • Autoplay"
        case .offline: artistText = entry.artist.isEmpty ? "Offline Audio" : entry.artist
        case .queue: artistText = entry.artist.isEmpty ? "YouTube Music" : entry.artist
        }
        metaLbl.stringValue = entry.isCurrent ? "Now playing • \(artistText)" : artistText
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

        durationLbl.translatesAutoresizingMaskIntoConstraints = false
        durationLbl.stringValue = entry.duration
        durationLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        durationLbl.textColor = tone.secondaryText
        durationLbl.alignment = .right
        durationLbl.isEditable = false
        durationLbl.isSelectable = false
        durationLbl.refusesFirstResponder = true
        durationLbl.setContentHuggingPriority(.required, for: .horizontal)
        durationLbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(durationLbl)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            playBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            playBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            textCol.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 8),
            textCol.centerYAnchor.constraint(equalTo: centerYAnchor),
            textCol.trailingAnchor.constraint(lessThanOrEqualTo: durationLbl.leadingAnchor, constant: -6),

            durationLbl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            durationLbl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Single-click anywhere on the row to play it.
        let singleClick = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(singleClick)

        // Double-click anywhere on the row to play it.
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClick)

        // Drag to reorder: upcoming songs only, and not while a search filter is active.
        if let delegate, !delegate.isLibrarySearchActive, entry.canModify {
            let pan = VerticalPanGestureRecognizer(target: self, action: #selector(handleReorderPan(_:)))
            addGestureRecognizer(pan)
        }
    }

    @objc private func handleClick() {
        delegate?.playUpNextEntry(entry)
    }

    @objc private func handleDoubleClick() {
        delegate?.playUpNextEntry(entry)
    }

    @objc private func handleReorderPan(_ gesture: NSPanGestureRecognizer) {
        guard let delegate = delegate else { return }
        delegate.handleLibraryRowReorderPan(gesture, keyPrefix: "upnext-", storageKey: nil, playlistID: nil)
    }
}
