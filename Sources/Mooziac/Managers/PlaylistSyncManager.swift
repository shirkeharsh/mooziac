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

    private var isSyncing = false
    private var isPullInProgress = false
    private var isPushInProgress = false

    private init() {}

    public var isSignedIn: Bool {
        LikedSongsManager.shared.isSignedIn
    }

    public var isSyncInProgress: Bool {
        isSyncing
    }

    // MARK: - Entry point

    /// Runs push then pull. Safe to call from any thread; the underlying network
    /// callbacks already run off the main thread, so the main thread is never
    /// blocked. Single-flight guarded.
    public func syncNow() {
        guard !isSyncing,
              isSignedIn,
              NetworkMonitor.shared.isReachable else { return }
        isSyncing = true
        pushLocalToAccount { [weak self] in
            self?.pullAccountToLocal { [weak self] in
                self?.isSyncing = false
                DispatchQueue.main.async {
                    self?.postLibraryUpdated()
                }
            }
        }
    }

    // MARK: - Pull (account -> local)

    public func pullAccountToLocal(completion: @escaping () -> Void) {
        guard !isPullInProgress else {
            completion()
            return
        }
        isPullInProgress = true
        YTMClient.shared.fetchAccountPlaylists { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                print("[PlaylistSyncManager] Pull: failed to fetch account playlists: \(error)")
                self.pullLikedSongs(completion: completion)
            case .success(let playlists):
                self.importPlaylists(playlists) {
                    self.pullLikedSongs(completion: completion)
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
                print("[PlaylistSyncManager] Pull: failed to fetch tracks for '\(summary.title)': \(error)")
                completion()
            case .success(let tracks):
                let currentItems = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: localID)
                let existingVids = Set(currentItems.compactMap { $0.ytVideoId })
                var sortOrder = currentItems.count
                let now = Date().timeIntervalSince1970
                var added = 0
                for track in tracks {
                    guard !track.videoId.isEmpty, !existingVids.contains(track.videoId) else { continue }
                    LocalDatabaseManager.shared.appendPlaylistItem(PlaylistItemRecord(
                        playlistID: localID,
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
                    added += 1
                }
                if added > 0 {
                    print("[PlaylistSyncManager] Pull: imported \(added) new track(s) into '\(summary.title)'")
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
            defer { self.isPullInProgress = false }
            switch result {
            case .failure(let error):
                print("[PlaylistSyncManager] Pull: failed to fetch liked songs: \(error)")
                completion()
            case .success(let tracks):
                let now = Date().timeIntervalSince1970
                var added = 0
                for track in tracks {
                    guard !track.videoId.isEmpty else { continue }
                    if LikedSongsManager.shared.isLiked(videoId: track.videoId) { continue }
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
                    print("[PlaylistSyncManager] Pull: imported \(added) liked song(s)")
                }
                completion()
            }
        }
    }

    // MARK: - Push (local -> account)

    public func pushLocalToAccount(completion: @escaping () -> Void) {
        guard !isPushInProgress else {
            completion()
            return
        }
        isPushInProgress = true
        pushUnsyncedPlaylists { [weak self] in
            self?.pushDirtySyncedPlaylists {
                self?.pushUnsyncedLikedSongs {
                    self?.isPushInProgress = false
                    completion()
                }
            }
        }
    }

    private func pushUnsyncedPlaylists(completion: @escaping () -> Void) {
        let unsynced = LocalDatabaseManager.shared.fetchUnsyncedPlaylists()
        guard !unsynced.isEmpty else {
            completion()
            return
        }
        var remaining = unsynced
        let playlist = remaining.removeFirst()

        let videoIds = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlist.id)
            .compactMap { $0.ytVideoId }

        YTMClient.shared.createPlaylist(title: playlist.name, videoIds: videoIds) { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                print("[PlaylistSyncManager] Push: failed to create playlist '\(playlist.name)': \(error)")
                // Left unsynced so a later run retries it.
                self.pushUnsyncedPlaylists(completion: completion)
            case .success(let plId):
                LocalDatabaseManager.shared.setPlaylistYTMID(id: playlist.id, ytPlaylistId: plId)
                LocalDatabaseManager.shared.setPlaylistSynced(id: playlist.id)
                print("[PlaylistSyncManager] Push: created YTM playlist '\(playlist.name)' (\(plId))")
                self.pushUnsyncedPlaylists(completion: completion)
            }
        }
    }

    private func pushDirtySyncedPlaylists(completion: @escaping () -> Void) {
        let dirty = LocalDatabaseManager.shared.fetchDirtySyncedPlaylists()
        guard !dirty.isEmpty else {
            completion()
            return
        }
        var remaining = dirty
        let playlist = remaining.removeFirst()

        guard let ytId = playlist.ytPlaylistId else {
            self.pushDirtySyncedPlaylists(completion: completion)
            return
        }

        let localVids = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: playlist.id)
            .compactMap { $0.ytVideoId }

        YTMClient.shared.fetchTracks(browseId: "VL\(ytId)") { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                print("[PlaylistSyncManager] Push: failed to fetch remote tracks for '\(playlist.name)': \(error)")
                self.pushDirtySyncedPlaylists(completion: completion)
            case .success(let remoteTracks):
                let remoteVids = Set(remoteTracks.map { $0.videoId })
                let missing = localVids.filter { !remoteVids.contains($0) }
                YTMClient.shared.addToPlaylist(playlistId: ytId, videoIds: missing) { [weak self] result in
                    guard let self = self else {
                        completion()
                        return
                    }
                    switch result {
                    case .failure(let error):
                        print("[PlaylistSyncManager] Push: failed to add tracks to '\(playlist.name)': \(error)")
                    case .success:
                        if !missing.isEmpty {
                            print("[PlaylistSyncManager] Push: added \(missing.count) track(s) to YTM playlist '\(playlist.name)'")
                        }
                        LocalDatabaseManager.shared.setPlaylistSynced(id: playlist.id)
                    }
                    self.pushDirtySyncedPlaylists(completion: completion)
                }
            }
        }
    }

    private func pushUnsyncedLikedSongs(completion: @escaping () -> Void) {
        let unsynced = LocalDatabaseManager.shared.fetchUnsyncedLikedSongs()
        guard !unsynced.isEmpty else {
            completion()
            return
        }
        var remaining = unsynced
        let record = remaining.removeFirst()

        YTMClient.shared.like(videoId: record.videoId, liked: true) { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            switch result {
            case .failure(let error):
                print("[PlaylistSyncManager] Push: failed to like '\(record.title)': \(error)")
            case .success:
                LocalDatabaseManager.shared.setLikedSongSynced(videoId: record.videoId)
            }
            self.pushUnsyncedLikedSongs(completion: completion)
        }
    }

    // MARK: - Notifications

    private func postLibraryUpdated() {
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