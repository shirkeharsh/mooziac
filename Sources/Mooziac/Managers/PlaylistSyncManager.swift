import Foundation
import AppKit

/// Orchestrates two-way sync between the app's local SQLite library and the
/// signed-in YouTube Music account.
///
/// - Pull: imports the account's playlists and liked songs into the local DB.
///   Merge semantics only — it never deletes local-only tracks or reorders rows.
/// - Push: creates in-app playlists on the account, adds locally-added tracks to
///   synced playlists, and backfills liked songs that were recorded while signed
///   out (or that the account never received).
///
/// The sync is fully additive to the local DB and posts the same notifications
/// the UI already observes (`Mooziac_LibraryUpdated` and
/// `LikedSongsManager.likedSongsUpdatedNotification`). It never touches playback,
/// WebView navigation, downloads, or the audio engines.
public final class PlaylistSyncManager {

    public static let shared = PlaylistSyncManager()

    private let stateLock = NSLock()
    private var isSyncing = false
    private var isPullInProgress = false
    private var isPushInProgress = false
    private let pushErrorLock = NSLock()
    private var pushErrors: [String] = []

    private init() {}

    public var isSignedIn: Bool {
        LikedSongsManager.shared.isSignedIn
    }

    public var isSyncInProgress: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isSyncing
    }

    // MARK: - Entry point

    /// Runs push then pull. Safe to call from any thread; the underlying network
    /// callbacks already run off the main thread, so the main thread is never
    /// blocked. Single-flight guarded.
    public func syncNow(completion: ((_ syncedPlaylists: Int, _ error: Error?) -> Void)? = nil) {
        stateLock.lock()
        guard !isSyncing else {
            stateLock.unlock()
            completion?(0, nil)
            return
        }
        guard isSignedIn,
              NetworkMonitor.shared.isReachable else {
            stateLock.unlock()
            completion?(0, YTMClient.YTMError.notSignedIn)
            return
        }
        isSyncing = true
        stateLock.unlock()

        pushLocalToAccountWithResult { [weak self] pushError in
            guard let self = self else { return }
            self.pullAccountToLocal { [weak self] count, error in
                guard let self = self else { return }
                self.stateLock.lock()
                self.isSyncing = false
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    self.postLibraryUpdated()
                    let combinedError: Error?
                    if let pushError, let error {
                        combinedError = PlaylistSyncFailure(messages: [pushError.localizedDescription, error.localizedDescription])
                    } else {
                        combinedError = pushError ?? error
                    }
                    completion?(count, combinedError)
                }
            }
        }
    }

    // MARK: - Pull (account -> local)

    public func pullAccountToLocal(completion: @escaping (_ importedPlaylistCount: Int, _ error: Error?) -> Void) {
        stateLock.lock()
        guard !isPullInProgress else {
            stateLock.unlock()
            completion(0, nil)
            return
        }
        isPullInProgress = true
        stateLock.unlock()
        YTMClient.shared.fetchAccountPlaylists { [weak self] result in
            guard let self = self else {
                completion(0, nil)
                return
            }
            switch result {
            case .failure(let error):
                Log.sync.error("Pull: failed to fetch account playlists: \(error)")
                self.pullLikedSongs {
                    completion(0, error)
                }
            case .success(let playlists):
                self.importPlaylists(playlists) {
                    self.pullLikedSongs {
                        completion(playlists.count, nil)
                    }
                }
            }
        }
    }

    private func importPlaylists(_ playlists: [YTMClient.PlaylistSummary], completion: @escaping () -> Void) {
        guard !playlists.isEmpty else {
            completion()
            return
        }
        var remaining = playlists
        let summary = remaining.removeFirst()
        importPlaylist(summary) { [weak self] in
            self?.importPlaylists(remaining, completion: completion)
        }
    }

    private func importPlaylist(_ summary: YTMClient.PlaylistSummary, completion: @escaping () -> Void) {
        guard let localID = LocalDatabaseManager.shared.upsertPlaylistFromYTM(
            ytPlaylistId: summary.playlistId,
            name: summary.title
        ) else {
            completion()
            return
        }

        YTMClient.shared.fetchTracks(browseId: summary.browseId) { result in
            switch result {
            case .failure(let error):
                Log.sync.error("Pull: failed to fetch tracks for '\(summary.title)': \(error)")
                completion()
            case .success(let tracks):
                let currentItems = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: localID)
                let existingByVid = Dictionary(uniqueKeysWithValues: currentItems.compactMap { item -> (String, PlaylistItemRecord)? in
                    guard let vid = item.ytVideoId, !vid.isEmpty else { return nil }
                    return (vid, item)
                })
                var sortOrder = currentItems.count
                let now = Date().timeIntervalSince1970
                var added = 0
                for track in tracks {
                    guard !track.videoId.isEmpty else { continue }
                    if let existing = existingByVid[track.videoId] {
                        if existing.ytSetVideoId == nil, let svid = track.setVideoId, !svid.isEmpty {
                            LocalDatabaseManager.shared.setPlaylistItemSetVideoId(itemID: existing.id, setVideoId: svid)
                        }
                        continue
                    }
                    LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                        playlistID: localID,
                        sortOrder: sortOrder,
                        refType: "yt",
                        refID: track.videoId,
                        ytVideoId: track.videoId,
                        ytSetVideoId: track.setVideoId,
                        title: track.title,
                        artist: track.artist,
                        artworkUrl: track.artworkUrl,
                        duration: track.duration,
                        isLiked: false,
                        dateAdded: now
                    ))
                    sortOrder += 1
                    added += 1
                }
                if added > 0 {
                    Log.sync.info("Pull: imported \(added) new track(s) into '\(summary.title)'")
                }
                completion()
            }
        }
    }

    private func pullLikedSongs(completion: @escaping () -> Void) {
        YTMClient.shared.fetchTracks(browseId: "FEmusic_liked_songs") { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            defer {
                self.stateLock.lock()
                self.isPullInProgress = false
                self.stateLock.unlock()
            }
            switch result {
            case .failure(let error):
                Log.sync.error("Pull: failed to fetch liked songs: \(error)")
                completion()
            case .success(let tracks):
                let now = Date().timeIntervalSince1970
                var added = 0
                for track in tracks {
                    guard !track.videoId.isEmpty else { continue }
                    if LocalDatabaseManager.shared.isLikedSong(videoId: track.videoId) { continue }
                    LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(
                        videoId: track.videoId,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        artworkUrl: track.artworkUrl,
                        duration: Self.parseDuration(track.duration),
                        dateLiked: now,
                        synced: true,
                        sourceType: "ytm"
                    ))
                    added += 1
                }
                if added > 0 {
                    Log.sync.info("Pull: imported \(added) liked song(s)")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
                    }
                }
                completion()
            }
        }
    }

    // MARK: - Push (local -> account)

    public func pushLocalToAccount(completion: @escaping () -> Void) {
        pushLocalToAccountWithResult { _ in completion() }
    }

    private func pushLocalToAccountWithResult(completion: @escaping (Error?) -> Void) {
        stateLock.lock()
        guard !isPushInProgress else {
            stateLock.unlock()
            completion(nil)
            return
        }
        isPushInProgress = true
        stateLock.unlock()
        pushErrorLock.lock()
        pushErrors.removeAll()
        pushErrorLock.unlock()
        pushSyncTombstones { [weak self] in
            self?.pushUnsyncedPlaylists { [weak self] in
                self?.pushDirtySyncedPlaylists {
                    self?.pushUnsyncedLikedSongs {
                        guard let self else { completion(nil); return }
                        self.pushErrorLock.lock()
                        let errors = self.pushErrors
                        self.pushErrorLock.unlock()
                        self.stateLock.lock()
                        self.isPushInProgress = false
                        self.stateLock.unlock()
                        completion(errors.isEmpty ? nil : PlaylistSyncFailure(messages: errors))
                    }
                }
            }
        }
    }

    private func recordPushFailure(_ error: Error, context: String) {
        recordPushFailure("\(context): \(error.localizedDescription)")
    }

    private func recordPushFailure(_ message: String) {
        pushErrorLock.lock()
        pushErrors.append(message)
        pushErrorLock.unlock()
        Log.sync.error("Push: \(message)")
    }

    private func pushSyncTombstones(completion: @escaping () -> Void) {
        let tombstones = LocalDatabaseManager.shared.fetchSyncTombstones()
        pushSyncTombstones(remaining: tombstones, completion: completion)
    }

    private func pushSyncTombstones(remaining: [PlaylistSyncTombstone], completion: @escaping () -> Void) {
        guard !remaining.isEmpty else {
            completion()
            return
        }
        var nextList = remaining
        let tomb = nextList.removeFirst()

        if tomb.entityType == "playlist" {
            YTMClient.shared.deletePlaylist(playlistId: tomb.ytPlaylistId) { [weak self] result in
                if case .success = result {
                    LocalDatabaseManager.shared.deleteSyncTombstone(id: tomb.id)
                    Log.sync.info("Push: deleted YTM playlist \(tomb.ytPlaylistId)")
                } else if case .failure(let error) = result {
                    self?.recordPushFailure(error, context: "Failed to delete playlist \(tomb.ytPlaylistId)")
                }
                self?.pushSyncTombstones(remaining: nextList, completion: completion)
            }
            return
        }

        if tomb.entityType == "item", let vid = tomb.ytVideoId, !vid.isEmpty {
            let removeWithSetVideoId: (String) -> Void = { [weak self] svid in
                YTMClient.shared.removeFromPlaylist(playlistId: tomb.ytPlaylistId, videoId: vid, setVideoId: svid) { result in
                    if case .success = result {
                        LocalDatabaseManager.shared.deleteSyncTombstone(id: tomb.id)
                        Log.sync.info("Push: removed \(vid) from YTM playlist \(tomb.ytPlaylistId)")
                    } else if case .failure(let error) = result {
                        self?.recordPushFailure(error, context: "Failed to remove track \(vid) from playlist \(tomb.ytPlaylistId)")
                    }
                    self?.pushSyncTombstones(remaining: nextList, completion: completion)
                }
            }

            if let svid = tomb.ytSetVideoId, !svid.isEmpty {
                removeWithSetVideoId(svid)
            } else {
                YTMClient.shared.fetchTracks(browseId: "VL\(tomb.ytPlaylistId)") { [weak self] res in
                    if case .success(let tracks) = res,
                       let match = tracks.first(where: { $0.videoId == vid }),
                       let svid = match.setVideoId, !svid.isEmpty {
                        removeWithSetVideoId(svid)
                    } else if case .failure(let error) = res {
                        self?.recordPushFailure(error, context: "Failed to resolve removed track \(vid)")
                        self?.pushSyncTombstones(remaining: nextList, completion: completion)
                    } else {
                        LocalDatabaseManager.shared.deleteSyncTombstone(id: tomb.id)
                        self?.pushSyncTombstones(remaining: nextList, completion: completion)
                    }
                }
            }
            return
        }

        LocalDatabaseManager.shared.deleteSyncTombstone(id: tomb.id)
        pushSyncTombstones(remaining: nextList, completion: completion)
    }

    private func pushUnsyncedPlaylists(completion: @escaping () -> Void) {
        let unsynced = LocalDatabaseManager.shared.fetchUnsyncedPlaylists()
        pushUnsyncedPlaylists(remaining: unsynced, completion: completion)
    }

    private func pushUnsyncedPlaylists(remaining: [PlaylistRecord], completion: @escaping () -> Void) {
        guard !remaining.isEmpty else {
            completion()
            return
        }
        var nextList = remaining
        let playlist = nextList.removeFirst()

        let items = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        let videoIds = items.compactMap { $0.ytVideoId }
        // Keep purely local playlists (such as picked local music folders) local instead of creating empty YTM playlists.
        if !items.isEmpty && videoIds.isEmpty {
            pushUnsyncedPlaylists(remaining: nextList, completion: completion)
            return
        }

        YTMClient.shared.createPlaylist(title: playlist.name,
                                        description: playlist.descriptionText,
                                        privacyStatus: playlist.privacyStatus,
                                        videoIds: videoIds) { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                self.recordPushFailure(error, context: "Failed to create playlist '\(playlist.name)'")
                // Left unsynced so a later run retries it.
                self.pushUnsyncedPlaylists(remaining: nextList, completion: completion)
            case .success(let plId):
                LocalDatabaseManager.shared.setPlaylistYTMID(id: playlist.id, ytPlaylistId: plId)
                LocalDatabaseManager.shared.setPlaylistSynced(id: playlist.id)
                Log.sync.info("Push: created YTM playlist '\(playlist.name)' (\(plId))")
                self.pushUnsyncedPlaylists(remaining: nextList, completion: completion)
            }
        }
    }

    private func pushDirtySyncedPlaylists(completion: @escaping () -> Void) {
        let dirty = LocalDatabaseManager.shared.fetchDirtySyncedPlaylists()
        pushDirtySyncedPlaylists(remaining: dirty, completion: completion)
    }

    private func pushDirtySyncedPlaylists(remaining: [PlaylistRecord], completion: @escaping () -> Void) {
        guard !remaining.isEmpty else {
            completion()
            return
        }
        var nextList = remaining
        let playlist = nextList.removeFirst()

        guard let ytId = playlist.ytPlaylistId else {
            pushDirtySyncedPlaylists(remaining: nextList, completion: completion)
            return
        }

        let localItems = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlist.id)
        let localVids = localItems.compactMap { $0.ytVideoId }

        YTMClient.shared.editPlaylistMetadata(
            playlistId: ytId,
            title: playlist.name,
            description: playlist.descriptionText,
            privacyStatus: playlist.privacyStatus
        ) { [weak self] metadataResult in
            guard let self = self else {
                completion()
                return
            }
            let metadataSucceeded: Bool
            if case .failure(let error) = metadataResult {
                metadataSucceeded = false
                self.recordPushFailure(error, context: "Failed to update metadata for '\(playlist.name)'")
            } else {
                metadataSucceeded = true
            }
            YTMClient.shared.fetchTracks(browseId: "VL\(ytId)") { [weak self] result in
                guard let self = self else {
                    completion()
                    return
                }
                switch result {
                case .failure(let error):
                    self.recordPushFailure(error, context: "Failed to fetch remote tracks for '\(playlist.name)'")
                    self.pushDirtySyncedPlaylists(remaining: nextList, completion: completion)
                case .success(let remoteTracks):
                    // Backfill setVideoId onto local items for future remove/reorder
                    self.backfillSetVideoIds(localItems: localItems, remoteTracks: remoteTracks)

                    let remoteVids = Set(remoteTracks.map { $0.videoId })
                    let missing = localVids.filter { !remoteVids.contains($0) }
                    YTMClient.shared.addToPlaylist(playlistId: ytId, videoIds: missing) { [weak self] addRes in
                        guard let self = self else {
                            completion()
                            return
                        }
                        switch addRes {
                        case .failure(let error):
                            self.recordPushFailure(error, context: "Failed to add tracks to '\(playlist.name)'")
                            self.pushDirtySyncedPlaylists(remaining: nextList, completion: completion)
                        case .success:
                            if !missing.isEmpty {
                                Log.sync.info("Push: added \(missing.count) track(s) to YTM playlist '\(playlist.name)'")
                            }
                            // Adding tracks can change the setVideoIds, so resolve order against a fresh snapshot.
                            YTMClient.shared.fetchTracks(browseId: "VL\(ytId)") { [weak self] refreshedResult in
                                guard let self else { completion(); return }
                                switch refreshedResult {
                                case .failure(let error):
                                    self.recordPushFailure(error, context: "Failed to refresh tracks for '\(playlist.name)' after adding")
                                    self.pushDirtySyncedPlaylists(remaining: nextList, completion: completion)
                                case .success(let refreshedTracks):
                                    self.backfillSetVideoIds(localItems: localItems, remoteTracks: refreshedTracks)
                                    self.pushRemoteOrderIfNeeded(ytPlaylistId: ytId, localItems: localItems, remoteTracks: refreshedTracks) { orderSucceeded in
                                        if metadataSucceeded && orderSucceeded {
                                            LocalDatabaseManager.shared.setPlaylistSynced(id: playlist.id)
                                        }
                                        self.pushDirtySyncedPlaylists(remaining: nextList, completion: completion)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func backfillSetVideoIds(localItems: [PlaylistItemRecord], remoteTracks: [YTMClient.Track]) {
        for (item, setVideoId) in PlaylistOrderPlanner.matches(localItems: localItems, remoteTracks: remoteTracks, requireComplete: false) ?? [] {
            if item.ytSetVideoId == nil {
                LocalDatabaseManager.shared.setPlaylistItemSetVideoId(itemID: item.id, setVideoId: setVideoId)
            }
        }
    }

    private func pushRemoteOrderIfNeeded(ytPlaylistId: String,
                                         localItems: [PlaylistItemRecord],
                                         remoteTracks: [YTMClient.Track],
                                         completion: @escaping (Bool) -> Void) {
        guard let actions = PlaylistOrderPlanner.moveActions(localItems: localItems, remoteTracks: remoteTracks) else {
            // A remote-only item or an unresolved setVideoId means we cannot safely reorder.
            recordPushFailure("Could not safely reconcile order for playlist \(ytPlaylistId); it will remain pending for retry")
            completion(false)
            return
        }
        guard !actions.isEmpty else { completion(true); return }
        YTMClient.shared.editPlaylist(playlistId: ytPlaylistId, actions: actions) { [weak self] result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                self?.recordPushFailure(error, context: "Failed to reorder playlist \(ytPlaylistId)")
                completion(false)
            }
        }
    }

    private func pushUnsyncedLikedSongs(completion: @escaping () -> Void) {
        let unsynced = LocalDatabaseManager.shared.fetchUnsyncedLikedSongs()
        pushUnsyncedLikedSongs(remaining: unsynced, completion: completion)
    }

    private func pushUnsyncedLikedSongs(remaining: [LikedSongRecord], completion: @escaping () -> Void) {
        guard !remaining.isEmpty else {
            completion()
            return
        }
        var nextList = remaining
        let record = nextList.removeFirst()

        YTMClient.shared.like(videoId: record.videoId, liked: true) { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                self.recordPushFailure(error, context: "Failed to like '\(record.title)'")
            case .success:
                LocalDatabaseManager.shared.setLikedSongSynced(videoId: record.videoId)
            }
            self.pushUnsyncedLikedSongs(remaining: nextList, completion: completion)
        }
    }

    // MARK: - Notifications

    private func postLibraryUpdated() {
        PlaylistManager.shared.invalidateAllSummariesPublic()
        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_PlaylistsUpdated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)
        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
    }

    // MARK: - Helpers

    /// Converts a YTM duration string like "3:45" or "1:02:03" to seconds.
    private static func parseDuration(_ string: String) -> Double {
        let parts = string.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return 0 }
        if parts.count == 1 { return parts[0] }
        if parts.count == 2 { return (parts[0] * 60) + parts[1] }
        if parts.count == 3 { return (parts[0] * 3600) + (parts[1] * 60) + parts[2] }
        return 0
    }
}

struct PlaylistSyncFailure: LocalizedError {
    let messages: [String]
    var errorDescription: String? { messages.joined(separator: "\n") }
}

enum PlaylistOrderPlanner {
    /// Resolves every remote playlist row to one local YouTube row. Requiring a
    /// complete match avoids moving a playlist whose remote-only rows we cannot order.
    static func matches(localItems: [PlaylistItemRecord],
                        remoteTracks: [YTMClient.Track],
                        requireComplete: Bool = true) -> [(PlaylistItemRecord, String)]? {
        guard remoteTracks.allSatisfy({ ($0.setVideoId?.isEmpty == false) }) else { return nil }

        var unusedRemoteIndices = Array(repeating: true, count: remoteTracks.count)
        var result: [(PlaylistItemRecord, String)] = []
        for item in localItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let videoId = item.ytVideoId, !videoId.isEmpty else { continue }
            let preferredIndex = item.ytSetVideoId.flatMap { setVideoId in
                remoteTracks.indices.first(where: { unusedRemoteIndices[$0] && remoteTracks[$0].setVideoId == setVideoId && remoteTracks[$0].videoId == videoId })
            }
            guard let index = preferredIndex ?? remoteTracks.indices.first(where: { unusedRemoteIndices[$0] && remoteTracks[$0].videoId == videoId }),
                  let setVideoId = remoteTracks[index].setVideoId else { return nil }
            unusedRemoteIndices[index] = false
            result.append((item, setVideoId))
        }
        guard !requireComplete || !unusedRemoteIndices.contains(true) else { return nil }
        return result
    }

    static func moveActions(localItems: [PlaylistItemRecord],
                            remoteTracks: [YTMClient.Track]) -> [[String: Any]]? {
        guard let matches = matches(localItems: localItems, remoteTracks: remoteTracks) else { return nil }
        let desired = matches.map { $0.1 }
        let current = remoteTracks.compactMap(\.setVideoId)
        guard desired.count >= 2, desired.count == current.count, desired != current else { return [] }

        return stride(from: desired.count - 2, through: 0, by: -1).map { index in
            [
                "action": "ACTION_MOVE_VIDEO_BEFORE",
                "setVideoId": desired[index],
                "movedSetVideoIdSuccessor": desired[index + 1]
            ]
        }
    }
}
