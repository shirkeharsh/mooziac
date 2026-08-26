import AppKit
import Foundation

public struct PlaylistLibraryIndex {
    public let byFilePath: [String: LocalTrack]
    public let byVideoId: [String: LocalTrack]
    public let byId: [String: LocalTrack]

    public init(tracks: [LocalTrack]) {
        var paths: [String: LocalTrack] = [:]
        var vids: [String: LocalTrack] = [:]
        var ids: [String: LocalTrack] = [:]
        for track in tracks {
            paths[track.fileURL.path] = track
            ids[track.id] = track
            if let vid = track.ytVideoId, !vid.isEmpty {
                vids[vid] = track
            }
        }
        byFilePath = paths
        byVideoId = vids
        byId = ids
    }
}

public final class PlaylistManager: NSObject {

    public static let shared = PlaylistManager()

    public enum PlaylistItemSource {
        case local(LocalTrack)
        case online(videoId: String)
        case unavailable
    }

    public struct PlaylistPlayResult {
        public let started: Bool
        public let localCount: Int
        public let onlineOnlyCount: Int
        public let unavailableCount: Int
        public let message: String
    }

    public static func metaFor(playlistName: String) -> (emoji: String, icon: String, color: NSColor) {
        return ("", "music.note.list", NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))
    }

    public static func iconAndColorFor(playlistName: String) -> (icon: String, color: NSColor) {
        return ("music.note.list", NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0))
    }

    private var _libraryIndex: PlaylistLibraryIndex?
    private let indexLock = NSLock()
    private var summaryCache: [String: (countText: String, durationText: String)] = [:]
    private let summaryCacheLock = NSLock()

    private func libraryIndex() -> PlaylistLibraryIndex {
        indexLock.lock()
        defer { indexLock.unlock() }
        if let idx = _libraryIndex { return idx }
        let idx = PlaylistLibraryIndex(tracks: LocalLibraryManager.shared.allTracks)
        _libraryIndex = idx
        return idx
    }

    private func invalidateLibraryIndex() {
        indexLock.lock()
        _libraryIndex = nil
        indexLock.unlock()
    }

    public func invalidateSummary(for playlistID: String) {
        summaryCacheLock.lock()
        summaryCache.removeValue(forKey: playlistID)
        summaryCacheLock.unlock()
    }

    private func invalidateAllSummaries() {
        summaryCacheLock.lock()
        summaryCache.removeAll()
        summaryCacheLock.unlock()
    }

    /// Marks a playlist as needing a push if it is linked to a YouTube Music
    /// playlist. Pure local playlists are left untouched.
    private func markSyncedDirtyIfNeeded(playlistID: String) {
        guard let pl = LocalDatabaseManager.shared.fetchPlaylists().first(where: { $0.id == playlistID }),
              pl.ytPlaylistId != nil else { return }
        LocalDatabaseManager.shared.markPlaylistDirty(playlistID: playlistID)
    }

    private override init() {
        super.init()
        cleanPresetPlaylistsOnceIfNeeded()
        NotificationCenter.default.addObserver(forName: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil, queue: .main) { [weak self] _ in
            self?.invalidateLibraryIndex()
            self?.invalidateAllSummaries()
        }
    }

    private func cleanPresetPlaylistsOnceIfNeeded() {
        let key = "Mooziac_CleanedPresetPlaylists_v1"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            let presetNames: Set<String> = [
                "chill vibes", "workout & gym", "night drive", "deep focus",
                "lo-fi beats", "top hits", "rock & indie", "rainy acoustic",
                "morning energy", "relax & sleep", "party & dance"
            ]
            let existing = LocalDatabaseManager.shared.fetchPlaylists()
            for pl in existing {
                if presetNames.contains(pl.name.lowercased()) && pl.itemCount == 0 {
                    LocalDatabaseManager.shared.deletePlaylist(id: pl.id)
                }
            }
        }
    }

    // MARK: - Playlist CRUD

    public func fetchPlaylists() -> [PlaylistRecord] {
        return LocalDatabaseManager.shared.fetchPlaylists()
    }

    @discardableResult
    public func createPlaylist(name: String) -> String? {
        let id = LocalDatabaseManager.shared.createPlaylist(name: name)
        if let id = id {
            invalidateSummary(for: id)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
            }
        }
        return id
    }

    public func renamePlaylist(id: String, name: String) {
        LocalDatabaseManager.shared.renamePlaylist(id: id, name: name)
        markSyncedDirtyIfNeeded(playlistID: id)
        invalidateSummary(for: id)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
        }
    }

    public func deletePlaylist(id: String) {
        LocalDatabaseManager.shared.deletePlaylist(id: id)
        invalidateSummary(for: id)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
        }
    }

    // MARK: - Items

    public func fetchPlaylistItems(playlistID: String) -> [PlaylistItemRecord] {
        return LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
    }

    public func appendPlaylistItem(_ item: PlaylistItemRecord, to playlistID: String) {
        LocalDatabaseManager.shared.appendPlaylistItem(item)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
    }

    public func removeItem(itemID: String, from playlistID: String) {
        LocalDatabaseManager.shared.removePlaylistItem(itemID: itemID, playlistID: playlistID)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        if var ctx = activeContext, ctx.playlistID == playlistID {
            let currentItem = (ctx.currentIndex >= 0 && ctx.currentIndex < ctx.items.count) ? ctx.items[ctx.currentIndex] : nil
            let newItems = fetchPlaylistItems(playlistID: playlistID)
            ctx.items = newItems
            if let current = currentItem, let newIdx = newItems.firstIndex(where: { $0.id == current.id }) {
                ctx.currentIndex = newIdx
            } else if ctx.currentIndex >= newItems.count {
                ctx.currentIndex = max(0, newItems.count - 1)
            }
            rebuildLocalQueue(for: &ctx)
            activeContext = ctx
        }
    }

    public func reorderItems(playlistID: String, orderedItemIDs: [String]) {
        LocalDatabaseManager.shared.reorderPlaylistItems(playlistID: playlistID, orderedItemIDs: orderedItemIDs)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        if var ctx = activeContext, ctx.playlistID == playlistID {
            let currentTrackID = (ctx.currentIndex >= 0 && ctx.currentIndex < ctx.items.count) ? ctx.items[ctx.currentIndex].id : nil
            let newItems = fetchPlaylistItems(playlistID: playlistID)
            ctx.items = newItems
            if let curID = currentTrackID, let newIdx = newItems.firstIndex(where: { $0.id == curID }) {
                ctx.currentIndex = newIdx
            }
            rebuildLocalQueue(for: &ctx)
            activeContext = ctx
            if NowPlayingManager.shared.engineMode == .offline && !ctx.localQueue.isEmpty {
                NativeAudioPlayer.shared.updateQueueOrder(newOrder: ctx.localQueue)
            }
        }
    }

    public func appendLocalTracks(_ tracks: [LocalTrack], to playlistID: String) {
        let existing = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        var nextOrder = existing.count
        for track in tracks {
            let refID = track.fileURL.path
            if existing.contains(where: { $0.refType == "local" && $0.refID == refID }) {
                continue
            }
            LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                playlistID: playlistID,
                sortOrder: nextOrder,
                refType: "local",
                refID: refID,
                ytVideoId: track.ytVideoId,
                title: track.title,
                artist: track.artist,
                artworkUrl: track.artworkURL?.path ?? "",
                duration: PlaylistManager.formattedDuration(track.duration),
                isLiked: track.isLiked
            ))
            nextOrder += 1
        }
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
    }

    @discardableResult
    public func appendTrack(to playlistID: String, track: LocalTrack) -> (success: Bool, message: String) {
        let existing = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        let refID = track.fileURL.path
        if existing.contains(where: {
            ($0.refType == "local" && ($0.refID == refID || $0.refID == track.id)) ||
            (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
            (!$0.title.isEmpty && $0.title.lowercased() == track.title.lowercased())
        }) {
            return (false, "Already in playlist")
        }
        LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: existing.count,
            refType: "local",
            refID: refID,
            ytVideoId: track.ytVideoId,
            title: track.title,
            artist: track.artist,
            artworkUrl: track.artworkURL?.path ?? "",
            duration: PlaylistManager.formattedDuration(track.duration),
            isLiked: track.isLiked
        ))
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        return (true, "Added \"\(track.title)\" to playlist")
    }

    @discardableResult
    public func appendHistoryItem(to playlistID: String, item: HistoryRecord) -> (success: Bool, message: String) {
        let existing = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        let isLocal = item.sourceType == "local" || (item.filePath != nil && !item.filePath!.isEmpty)
        let refType = isLocal ? "local" : "yt"
        let refID = isLocal ? (item.filePath ?? item.id) : (item.ytVideoId ?? item.id)

        if existing.contains(where: {
            ($0.refID == refID) ||
            (item.ytVideoId != nil && !item.ytVideoId!.isEmpty && $0.ytVideoId == item.ytVideoId) ||
            (!item.title.isEmpty && $0.title.lowercased() == item.title.lowercased() && $0.artist.lowercased() == item.artist.lowercased())
        }) {
            return (false, "Already in playlist")
        }

        let playlistItem = PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: existing.count,
            refType: refType,
            refID: refID,
            ytVideoId: item.ytVideoId,
            title: item.title,
            artist: item.artist,
            artworkUrl: item.artworkUrl,
            duration: "",
            isLiked: false
        )
        LocalDatabaseManager.shared.appendPlaylistItem(playlistItem)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        return (true, "Added \"\(item.title)\" to playlist")
    }

    @discardableResult
    public func appendLikedSong(to playlistID: String, record: LikedSongRecord) -> (success: Bool, message: String) {
        let existing = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        let isLocal = LocalLibraryManager.shared.allTracks.first(where: {
            if let v = $0.ytVideoId, !v.isEmpty, v == record.videoId { return true }
            return $0.fileURL.path == record.videoId
        })
        
        let refType = (isLocal != nil) ? "local" : "yt"
        let refID = isLocal != nil ? (isLocal?.fileURL.path ?? record.videoId) : record.videoId

        if existing.contains(where: {
            ($0.refID == refID) ||
            (!record.videoId.isEmpty && $0.ytVideoId == record.videoId) ||
            (!record.title.isEmpty && $0.title.lowercased() == record.title.lowercased() && $0.artist.lowercased() == record.artist.lowercased())
        }) {
            return (false, "Already in playlist")
        }

        let item = PlaylistItemRecord(
            playlistID: playlistID,
            sortOrder: existing.count,
            refType: refType,
            refID: refID,
            ytVideoId: record.videoId.isEmpty ? nil : record.videoId,
            title: record.title,
            artist: record.artist,
            artworkUrl: record.artworkUrl,
            duration: "",
            isLiked: true
        )
        LocalDatabaseManager.shared.appendPlaylistItem(item)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        return (true, "Added \"\(record.title)\" to playlist")
    }

    // MARK: - Capture Current Online Queue into a Playlist

    public func createPlaylistFromCurrentQueue(name: String, completion: @escaping (String?, Int) -> Void) {
        NowPlayingManager.shared.fetchUpNextSnapshot { snapshot in
            guard let playlistID = LocalDatabaseManager.shared.createPlaylist(name: name) else {
                completion(nil, 0)
                return
            }
            let items = snapshot.items.enumerated().map { index, item -> PlaylistItemRecord in
                let videoId = item.videoId.isEmpty ? nil : item.videoId
                return PlaylistItemRecord(
                    playlistID: playlistID,
                    sortOrder: index,
                    refType: "yt",
                    refID: item.videoId,
                    ytVideoId: videoId,
                    title: item.title,
                    artist: item.artist,
                    artworkUrl: item.artworkUrl,
                    duration: item.duration
                )
            }
            LocalDatabaseManager.shared.replacePlaylistItems(playlistID: playlistID, items: items)
            self.invalidateSummary(for: playlistID)
            completion(playlistID, items.count)
        }
    }

    @discardableResult
    public func appendCurrentPlayingTrack(to playlistID: String) -> (success: Bool, message: String) {
        let existing = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)

        // 1. If NativeAudioPlayer has a current track (offline engine or active local playback)
        if let track = NativeAudioPlayer.shared.currentTrack,
           (NowPlayingManager.shared.engineMode == .offline || NowPlayingManager.shared.currentState.title.isEmpty || NowPlayingManager.shared.currentState.title == "Not Playing") {
            let refID = track.fileURL.path
            if existing.contains(where: { 
                ($0.refType == "local" && ($0.refID == refID || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            }) {
                return (false, "Already in playlist")
            }
            LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                playlistID: playlistID,
                sortOrder: existing.count,
                refType: "local",
                refID: refID,
                ytVideoId: track.ytVideoId,
                title: track.title,
                artist: track.artist,
                artworkUrl: track.artworkURL?.path ?? "",
                duration: PlaylistManager.formattedDuration(track.duration),
                isLiked: track.isLiked
            ))
            invalidateSummary(for: playlistID)
            markSyncedDirtyIfNeeded(playlistID: playlistID)
            return (true, "Added \"\(track.title)\" to playlist")
        }

        // 2. Online playback from YouTube Music / NowPlaying state
        let state = NowPlayingManager.shared.currentState
        let title = !state.title.isEmpty && state.title != "Not Playing" ? state.title : (UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? "")
        let artist = !state.artist.isEmpty && state.artist != "YouTube Music" ? state.artist : (UserDefaults.standard.string(forKey: "YTM_lastArtist") ?? "")
        let videoId = !state.videoId.isEmpty ? state.videoId : (UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? "")
        let artworkUrl = !state.artworkUrl.isEmpty ? state.artworkUrl : (UserDefaults.standard.string(forKey: "YTM_lastArtwork") ?? "")
        let duration = state.duration > 0 ? PlaylistManager.formattedDuration(state.duration) : ""

        if !title.isEmpty && title != "Not Playing" {
            if !videoId.isEmpty, existing.contains(where: { ($0.refType == "yt" && $0.refID == videoId) || $0.ytVideoId == videoId }) {
                return (false, "Already in playlist")
            }
            if videoId.isEmpty, existing.contains(where: { $0.title.lowercased() == title.lowercased() }) {
                return (false, "Already in playlist")
            }

            LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                playlistID: playlistID,
                sortOrder: existing.count,
                refType: "yt",
                refID: videoId.isEmpty ? title : videoId,
                ytVideoId: videoId.isEmpty ? nil : videoId,
                title: title,
                artist: artist,
                artworkUrl: artworkUrl,
                duration: duration
            ))
            invalidateSummary(for: playlistID)
            markSyncedDirtyIfNeeded(playlistID: playlistID)
            return (true, "Added \"\(title)\" to playlist")
        }

        // 3. Fallback to NativeAudioPlayer if title was empty
        if let track = NativeAudioPlayer.shared.currentTrack {
            let refID = track.fileURL.path
            if existing.contains(where: { 
                ($0.refType == "local" && ($0.refID == refID || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            }) {
                return (false, "Already in playlist")
            }
            LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                playlistID: playlistID,
                sortOrder: existing.count,
                refType: "local",
                refID: refID,
                ytVideoId: track.ytVideoId,
                title: track.title,
                artist: track.artist,
                artworkUrl: track.artworkURL?.path ?? "",
                duration: PlaylistManager.formattedDuration(track.duration),
                isLiked: track.isLiked
            ))
            invalidateSummary(for: playlistID)
            markSyncedDirtyIfNeeded(playlistID: playlistID)
            return (true, "Added \"\(track.title)\" to playlist")
        }

        return (false, "No song currently playing")
    }

    public func isCurrentTrackInPlaylist(playlistID: String) -> Bool {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)

        if let track = NativeAudioPlayer.shared.currentTrack,
           (NowPlayingManager.shared.engineMode == .offline || NowPlayingManager.shared.currentState.title.isEmpty || NowPlayingManager.shared.currentState.title == "Not Playing") {
            return items.contains(where: { 
                ($0.refType == "local" && ($0.refID == track.fileURL.path || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            })
        }

        let state = NowPlayingManager.shared.currentState
        let videoId = !state.videoId.isEmpty ? state.videoId : (UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? "")
        let title = !state.title.isEmpty ? state.title : (UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? "")
        if !videoId.isEmpty {
            return items.contains(where: { $0.refID == videoId || $0.ytVideoId == videoId })
        }
        if !title.isEmpty && title != "Not Playing" {
            return items.contains(where: { $0.title.lowercased() == title.lowercased() })
        }

        if let track = NativeAudioPlayer.shared.currentTrack {
            return items.contains(where: { 
                ($0.refType == "local" && ($0.refID == track.fileURL.path || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            })
        }
        return false
    }

    public func removeCurrentPlayingTrackFromPlaylist(playlistID: String) -> (removed: Bool, message: String) {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        var found: PlaylistItemRecord?

        if let track = NativeAudioPlayer.shared.currentTrack,
           (NowPlayingManager.shared.engineMode == .offline || NowPlayingManager.shared.currentState.title.isEmpty || NowPlayingManager.shared.currentState.title == "Not Playing") {
            found = items.first(where: { 
                ($0.refType == "local" && ($0.refID == track.fileURL.path || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            })
        }

        if found == nil {
            let state = NowPlayingManager.shared.currentState
            let videoId = !state.videoId.isEmpty ? state.videoId : (UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? "")
            let title = !state.title.isEmpty ? state.title : (UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? "")
            if !videoId.isEmpty {
                found = items.first(where: { $0.refID == videoId || $0.ytVideoId == videoId })
            } else if !title.isEmpty && title != "Not Playing" {
                found = items.first(where: { $0.title.lowercased() == title.lowercased() })
            }
        }

        if found == nil, let track = NativeAudioPlayer.shared.currentTrack {
            found = items.first(where: { 
                ($0.refType == "local" && ($0.refID == track.fileURL.path || $0.refID == track.id)) ||
                (track.ytVideoId != nil && $0.ytVideoId == track.ytVideoId) ||
                ($0.title.lowercased() == track.title.lowercased() && !$0.title.isEmpty)
            })
        }

        guard let item = found else {
            return (false, "Track not found in playlist")
        }
        LocalDatabaseManager.shared.removePlaylistItem(itemID: item.id, playlistID: playlistID)
        markSyncedDirtyIfNeeded(playlistID: playlistID)
        invalidateSummary(for: playlistID)
        return (true, "Removed from playlist")
    }

    public func toggleCurrentPlayingTrack(in playlistID: String) -> (added: Bool, message: String) {
        if isCurrentTrackInPlaylist(playlistID: playlistID) {
            let res = removeCurrentPlayingTrackFromPlaylist(playlistID: playlistID)
            return (false, res.message)
        } else {
            let res = appendCurrentPlayingTrack(to: playlistID)
            return (true, res.message)
        }
    }

    public func playNext(item: PlaylistItemRecord) {
        if var ctx = activeContext {
            // If item is already in queue after currentIndex, remove it so it moves to next
            let currentID = (ctx.currentIndex >= 0 && ctx.currentIndex < ctx.items.count) ? ctx.items[ctx.currentIndex].id : ""
            ctx.items.removeAll(where: { $0.id == item.id && $0.id != currentID })
            let insertIndex = min(ctx.currentIndex + 1, ctx.items.count)
            ctx.items.insert(item, at: insertIndex)
            rebuildLocalQueue(for: &ctx)
            activeContext = ctx
        }

        switch resolve(item) {
        case .local(let track):
            NativeAudioPlayer.shared.playNext(track: track)
        case .online:
            break
        case .unavailable:
            break
        }
    }

    public func addToQueue(item: PlaylistItemRecord) {
        if var ctx = activeContext {
            ctx.items.append(item)
            rebuildLocalQueue(for: &ctx)
            activeContext = ctx
        }

        switch resolve(item) {
        case .local(let track):
            NativeAudioPlayer.shared.appendToQueue(track: track)
        case .online:
            if let vid = item.ytVideoId ?? (item.refType == "yt" ? item.refID : nil), !vid.isEmpty {
                // Online queue append simulation
                let js = "try { document.querySelector('ytmusic-player-bar').dispatchEvent(new CustomEvent('addToQueue', { detail: { videoId: '\(vid)' } })); } catch(e){}"
                NowPlayingManager.shared.evaluateJS(js)
            }
        case .unavailable:
            break
        }
    }

    public func appendCurrentTrack(to playlistID: String) {
        appendCurrentPlayingTrack(to: playlistID)
    }

    public var currentNowPlayingVideoID: String? {
        let vid = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
        return vid.isEmpty ? nil : vid
    }

    // MARK: - Resolution

    public func resolve(_ item: PlaylistItemRecord) -> PlaylistItemSource {
        return resolve(item, index: libraryIndex())
    }

    private func resolve(_ item: PlaylistItemRecord, index: PlaylistLibraryIndex) -> PlaylistItemSource {
        if item.refType == "local" {
            if let track = index.byFilePath[item.refID] ?? index.byId[item.refID] {
                return .local(track)
            }
            if let vid = item.ytVideoId, !vid.isEmpty,
               let track = index.byVideoId[vid] {
                return .local(track)
            }
            return .unavailable
        }

        // refType == "yt" or online
        let vid: String
        if let yvid = item.ytVideoId, !yvid.isEmpty {
            vid = yvid
        } else if item.refType == "yt" && !item.refID.isEmpty {
            vid = item.refID
        } else {
            vid = item.refID
        }

        if !vid.isEmpty {
            if let track = index.byVideoId[vid] ?? index.byId[vid] {
                return .local(track)
            }
            if NetworkMonitor.shared.isReachable {
                return .online(videoId: vid)
            }
            return .unavailable
        }
        return .unavailable
    }

    public func localTracks(in playlistID: String) -> [LocalTrack] {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        let index = libraryIndex()
        return items.compactMap { item -> LocalTrack? in
            if case let .local(track) = resolve(item, index: index) { return track }
            return nil
        }
    }

    public struct PlaylistDownloadPlan {
        public let toDownload: [PlaylistItemRecord]
        public let alreadyLocal: Int
        public let offlineBlocked: Int
    }

    public func planDownloads(for playlistID: String) -> PlaylistDownloadPlan {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        let index = libraryIndex()
        var toDownload: [PlaylistItemRecord] = []
        var alreadyLocal = 0
        var offlineBlocked = 0

        for item in items {
            switch resolve(item, index: index) {
            case .local:
                alreadyLocal += 1
            case .online:
                toDownload.append(item)
            case .unavailable:
                let vid = item.ytVideoId ?? (item.refType == "yt" ? item.refID : nil)
                if item.refType == "yt", let vid = vid, !vid.isEmpty {
                    if NetworkMonitor.shared.isReachable {
                        toDownload.append(item)
                    } else {
                        offlineBlocked += 1
                    }
                } else {
                    alreadyLocal += 1
                }
            }
        }

        return PlaylistDownloadPlan(toDownload: toDownload, alreadyLocal: alreadyLocal, offlineBlocked: offlineBlocked)
    }

    // MARK: - Playback

    public func play(playlistID: String, completion: ((PlaylistPlayResult) -> Void)? = nil) {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        guard !items.isEmpty else {
            completion?(PlaylistPlayResult(started: false, localCount: 0, onlineOnlyCount: 0, unavailableCount: 0, message: "Playlist is empty"))
            return
        }

        startPlaylist(playlistID: playlistID, startingAt: nil, shuffle: false)
        completion?(PlaylistPlayResult(started: true, localCount: 0, onlineOnlyCount: 0, unavailableCount: 0, message: "Playing playlist"))
    }

    public func shufflePlay(playlistID: String, completion: ((PlaylistPlayResult) -> Void)? = nil) {
        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlistID)
        guard !items.isEmpty else {
            completion?(PlaylistPlayResult(started: false, localCount: 0, onlineOnlyCount: 0, unavailableCount: 0, message: "Playlist is empty"))
            return
        }

        startPlaylist(playlistID: playlistID, startingAt: nil, shuffle: true)
        completion?(PlaylistPlayResult(started: true, localCount: 0, onlineOnlyCount: 0, unavailableCount: 0, message: "Shuffling playlist"))
    }

    public func summaryForPlaylist(_ playlist: PlaylistRecord) -> (countText: String, durationText: String) {
        summaryCacheLock.lock()
        if let cached = summaryCache[playlist.id] {
            summaryCacheLock.unlock()
            return cached
        }
        summaryCacheLock.unlock()

        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        let count = items.count
        let countText = count == 1 ? "1 track" : "\(count) tracks"

        let index = libraryIndex()
        var totalSeconds: Double = 0
        for item in items {
            if let track = index.byFilePath[item.refID] ?? index.byId[item.refID] {
                totalSeconds += track.duration
            } else if !item.duration.isEmpty {
                let parts = item.duration.split(separator: ":").compactMap { Double($0) }
                if parts.count == 2 {
                    totalSeconds += (parts[0] * 60) + parts[1]
                } else if parts.count == 3 {
                    totalSeconds += (parts[0] * 3600) + (parts[1] * 60) + parts[2]
                }
            }
        }

        var durationText = ""
        if totalSeconds > 0 {
            let totalMins = Int(totalSeconds.rounded()) / 60
            if totalMins < 60 {
                durationText = "\(totalMins) mins"
            } else {
                let hrs = totalMins / 60
                let mins = totalMins % 60
                durationText = mins > 0 ? "\(hrs) hr \(mins) mins" : "\(hrs) hr"
            }
        }

        let result = (countText, durationText)
        summaryCacheLock.lock()
        summaryCache[playlist.id] = result
        summaryCacheLock.unlock()
        return result
    }

    // MARK: - Active Playlist Playback Queue Management

    public struct ActivePlaylistPlaybackContext {
        public let playlistID: String
        public var items: [PlaylistItemRecord]
        public var currentIndex: Int
        public var localQueue: [LocalTrack]
        public var localQueueIndexByItemID: [String: Int]
    }

    public private(set) var activeContext: ActivePlaylistPlaybackContext?

    public var hasActiveContext: Bool {
        return activeContext != nil
    }

    public func clearActiveContext() {
        activeContext = nil
    }

    private func buildLocalQueue(for items: [PlaylistItemRecord], index: PlaylistLibraryIndex) -> (queue: [LocalTrack], map: [String: Int]) {
        var queue: [LocalTrack] = []
        var map: [String: Int] = [:]
        for item in items {
            if case .local(let t) = resolve(item, index: index) {
                map[item.id] = queue.count
                queue.append(t)
            }
        }
        return (queue, map)
    }

    private func rebuildLocalQueue(for ctx: inout ActivePlaylistPlaybackContext) {
        let index = libraryIndex()
        let (queue, map) = buildLocalQueue(for: ctx.items, index: index)
        ctx.localQueue = queue
        ctx.localQueueIndexByItemID = map
    }

    public func startPlaylist(playlistID: String, startingAt itemID: String?, shuffle: Bool = false) {
        var items = fetchPlaylistItems(playlistID: playlistID)
        guard !items.isEmpty else { return }

        if shuffle {
            if let startID = itemID, let startItem = items.first(where: { $0.id == startID }) {
                items.removeAll(where: { $0.id == startID })
                items.shuffle()
                items.insert(startItem, at: 0)
            } else {
                items.shuffle()
            }
        }

        var startIndex = 0
        if let startID = itemID, !shuffle, let idx = items.firstIndex(where: { $0.id == startID }) {
            startIndex = idx
        }

        let index = libraryIndex()
        let (localQueue, localMap) = buildLocalQueue(for: items, index: index)
        activeContext = ActivePlaylistPlaybackContext(
            playlistID: playlistID,
            items: items,
            currentIndex: startIndex,
            localQueue: localQueue,
            localQueueIndexByItemID: localMap
        )

        playTrackAtCurrentContextIndex()
    }

    public func startLikedSongsPlayback(records: [LikedSongRecord], startingAt videoId: String? = nil, shuffle: Bool = false) {
        guard !records.isEmpty else { return }

        var items: [PlaylistItemRecord] = records.enumerated().map { index, record in
            let durStr = record.duration > 0 ? "\(Int(record.duration) / 60):\(String(format: "%02d", Int(record.duration) % 60))" : ""
            return PlaylistItemRecord(
                id: record.videoId,
                playlistID: "liked_songs",
                sortOrder: index,
                refType: "yt",
                refID: record.videoId,
                ytVideoId: record.videoId,
                title: record.title,
                artist: record.artist,
                artworkUrl: record.artworkUrl,
                duration: durStr,
                isLiked: true,
                dateAdded: record.dateLiked
            )
        }

        if shuffle {
            if let startID = videoId, let startItem = items.first(where: { $0.id == startID || $0.ytVideoId == startID }) {
                items.removeAll(where: { $0.id == startID || $0.ytVideoId == startID })
                items.shuffle()
                items.insert(startItem, at: 0)
            } else {
                items.shuffle()
            }
        }

        var startIndex = 0
        if let startID = videoId, !shuffle, let idx = items.firstIndex(where: { $0.id == startID || $0.ytVideoId == startID }) {
            startIndex = idx
        }

        let index = libraryIndex()
        let (localQueue, localMap) = buildLocalQueue(for: items, index: index)
        activeContext = ActivePlaylistPlaybackContext(
            playlistID: "liked_songs",
            items: items,
            currentIndex: startIndex,
            localQueue: localQueue,
            localQueueIndexByItemID: localMap
        )

        playTrackAtCurrentContextIndex()
    }

    public func playTrackAtCurrentContextIndex() {
        guard let ctx = activeContext, ctx.currentIndex >= 0, ctx.currentIndex < ctx.items.count else {
            activeContext = nil
            return
        }

        let item = ctx.items[ctx.currentIndex]
        switch resolve(item, index: libraryIndex()) {
        case .local(let track):
            let localIdx = ctx.localQueueIndexByItemID[item.id] ?? 0
            let remainingLocal = localIdx < ctx.localQueue.count ? Array(ctx.localQueue[localIdx...]) : []
            let localQueue = remainingLocal.isEmpty ? [track] : remainingLocal
            DispatchQueue.main.async {
                NowPlayingManager.shared.playOfflineTrack(track, in: localQueue)
            }

        case .online(let videoId):
            playOnlineVideo(videoId: videoId)

        case .unavailable:
            _ = playNextTrackInPlaylist()
        }
    }

    @discardableResult
    public func playNextTrackInPlaylist() -> Bool {
        if NowPlayingManager.shared.repeatMode == .one {
            playTrackAtCurrentContextIndex()
            return true
        }
        guard var ctx = activeContext else { return false }
        let nextIndex = ctx.currentIndex + 1
        if nextIndex < ctx.items.count {
            ctx.currentIndex = nextIndex
            activeContext = ctx
            playTrackAtCurrentContextIndex()
            return true
        } else {
            // Playlist has ended! Let random/recommended autoplay take over smoothly
            activeContext = nil
            return false
        }
    }

    @discardableResult
    public func playPreviousTrackInPlaylist() -> Bool {
        guard var ctx = activeContext else { return false }
        let prevIndex = ctx.currentIndex - 1
        if prevIndex >= 0 {
            ctx.currentIndex = prevIndex
            activeContext = ctx
            playTrackAtCurrentContextIndex()
            return true
        }
        return false
    }

    public func playOnlineVideo(videoId: String) {
        guard !videoId.isEmpty else { return }
        NowPlayingManager.shared.switchToOnlineMode()
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else { return }
            let loadVideoJS = """
            (function() {
                try {
                    var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                    if (player && typeof player.loadVideoById === 'function') {
                        player.loadVideoById('\(videoId)');
                        if (typeof player.playVideo === 'function') player.playVideo();
                        return true;
                    }
                } catch(e) {}
                return false;
            })();
            """
            mainVC.webViewContainer.webView.evaluateJavaScript(loadVideoJS) { res, _ in
                if (res as? Bool) != true {
                    guard let url = URL(string: "https://music.youtube.com/watch?v=\(videoId)&list=RDAMVM\(videoId)") else { return }
                    mainVC.webViewContainer.webView.load(URLRequest(url: url))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak mainVC] in
                        mainVC?.webViewContainer.selectSongTab()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak mainVC] in
                        mainVC?.webViewContainer.selectSongTab()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    public static func formattedDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Playlist & Song Import via Link

    public static func extractPlaylistID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If direct playlist ID (e.g. PL... or RD...)
        if (trimmed.hasPrefix("PL") || trimmed.hasPrefix("VLPL") || trimmed.hasPrefix("RD")) && trimmed.count >= 12 {
            let clean = trimmed.hasPrefix("VL") ? String(trimmed.dropFirst(2)) : trimmed
            return clean.components(separatedBy: "&").first?.components(separatedBy: "?").first
        }

        // Try extracting from URL components
        if let components = URLComponents(string: trimmed) {
            if let listParam = components.queryItems?.first(where: { $0.name == "list" })?.value, !listParam.isEmpty {
                return listParam
            }
        }

        // Regex fallback for URL strings
        let pattern = "[?&]list=([A-Za-z0-9_-]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = trimmed as NSString
            let results = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }

        return nil
    }

    public static func extractVideoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If direct 11-char video ID
        if trimmed.count == 11 && trimmed.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil {
            return trimmed
        }

        // Try extracting from URL components
        if let components = URLComponents(string: trimmed) {
            if let vParam = components.queryItems?.first(where: { $0.name == "v" })?.value, !vParam.isEmpty {
                return vParam
            }
            if components.host?.contains("youtu.be") == true {
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let candidate = path.components(separatedBy: "?").first?.components(separatedBy: "&").first ?? ""
                if candidate.count == 11 {
                    return candidate
                }
            }
            let parts = components.path.split(separator: "/")
            if let last = parts.last, last.count == 11 {
                return String(last)
            }
        }

        // Regex fallback for v=
        let pattern = "[?&]v=([A-Za-z0-9_-]{11})"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = trimmed as NSString
            let results = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }

        return nil
    }

    public func importPlaylist(from urlOrID: String, completion: @escaping (Result<(playlistID: String, title: String, trackCount: Int), Error>) -> Void) {
        // Case 1: Playlist URL / ID
        if let playlistID = Self.extractPlaylistID(from: urlOrID) {
            YTMClient.shared.fetchPlaylistDetails(playlistId: playlistID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                case .success(let detail):
                    guard !detail.tracks.isEmpty else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "PlaylistManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist is empty, private, or not found"])))
                        }
                        return
                    }

                    let existingPlaylists = LocalDatabaseManager.shared.fetchPlaylists()
                    let playlistTitle = detail.title.isEmpty ? "Imported Playlist" : detail.title
                    let targetLocalID: String

                    if let existing = existingPlaylists.first(where: { $0.ytPlaylistId == detail.playlistId }) {
                        targetLocalID = existing.id
                    } else if let newID = LocalDatabaseManager.shared.createPlaylist(name: playlistTitle) {
                        targetLocalID = newID
                        LocalDatabaseManager.shared.setPlaylistYTMID(id: newID, ytPlaylistId: detail.playlistId)
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "PlaylistManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create playlist in database"])))
                        }
                        return
                    }

                    let currentItems = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: targetLocalID)
                    var existingVids = Set(currentItems.compactMap { $0.ytVideoId })
                    var sortOrder = currentItems.count
                    let now = Date().timeIntervalSince1970
                    var addedCount = 0

                    for track in detail.tracks {
                        guard !track.videoId.isEmpty, !existingVids.contains(track.videoId) else { continue }
                        existingVids.insert(track.videoId)
                        LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                            playlistID: targetLocalID,
                            sortOrder: sortOrder,
                            refType: "yt",
                            refID: track.videoId,
                            ytVideoId: track.videoId,
                            title: track.title,
                            artist: track.artist,
                            artworkUrl: track.artworkUrl,
                            duration: track.duration,
                            isLiked: false,
                            dateAdded: now
                        ))
                        sortOrder += 1
                        addedCount += 1
                    }

                    self.invalidateSummary(for: targetLocalID)
                    self.markSyncedDirtyIfNeeded(playlistID: targetLocalID)

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
                        completion(.success((playlistID: targetLocalID, title: playlistTitle, trackCount: sortOrder)))
                    }
                }
            }
            return
        }

        // Case 2: Single Song / Video URL or ID
        if let videoID = Self.extractVideoID(from: urlOrID) {
            YTMClient.shared.fetchTrackDetails(videoId: videoID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                case .success(let track):
                    let existingPlaylists = LocalDatabaseManager.shared.fetchPlaylists()
                    let targetPlaylistName = "Imported Tracks"
                    let targetLocalID: String

                    if let existing = existingPlaylists.first(where: { $0.name == targetPlaylistName }) {
                        targetLocalID = existing.id
                    } else if let newID = LocalDatabaseManager.shared.createPlaylist(name: targetPlaylistName) {
                        targetLocalID = newID
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "PlaylistManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create playlist in database"])))
                        }
                        return
                    }

                    let currentItems = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: targetLocalID)
                    let now = Date().timeIntervalSince1970

                    if !currentItems.contains(where: { $0.ytVideoId == track.videoId || $0.refID == track.videoId }) {
                        LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                            playlistID: targetLocalID,
                            sortOrder: currentItems.count,
                            refType: "yt",
                            refID: track.videoId,
                            ytVideoId: track.videoId,
                            title: track.title,
                            artist: track.artist,
                            artworkUrl: track.artworkUrl,
                            duration: track.duration,
                            isLiked: false,
                            dateAdded: now
                        ))
                    }

                    self.invalidateSummary(for: targetLocalID)
                    self.markSyncedDirtyIfNeeded(playlistID: targetLocalID)

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
                        completion(.success((playlistID: targetLocalID, title: track.title, trackCount: currentItems.count + 1)))
                    }
                }
            }
            return
        }

        completion(.failure(NSError(domain: "PlaylistManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid playlist or song link"])))
    }
}
