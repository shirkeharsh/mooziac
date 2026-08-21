import AppKit
import WebKit

public class LikedSongsManager {
    public static let shared = LikedSongsManager()

    public static let likedSongsUpdatedNotification = NSNotification.Name("Mooziac_LikedSongsUpdated")
    public static let signInStatusChangedNotification = NSNotification.Name("Mooziac_SignInStatusChanged")

    public private(set) var isSignedIn: Bool = false
    private var isSyncing: Bool = false

    private init() {}

    // MARK: - Read

    public func isLiked(videoId: String) -> Bool {
        LocalDatabaseManager.shared.isLikedSong(videoId: videoId)
    }

    public func fetchLikedSongs() -> [LikedSongRecord] {
        LocalDatabaseManager.shared.fetchLikedSongs()
    }

    // MARK: - Sign-in Detection

    public func refreshSignInStatus() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            let authCookies = cookies.filter { cookie in
                let isAuth = cookie.name == "SAPISID" || cookie.name == "__Secure-3PAPISID" || cookie.name == "__Secure-1PAPISID"
                let isYoutube = cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com")
                return isAuth && isYoutube
            }
            let signedIn = !authCookies.isEmpty
            self?.updateSignedIn(signedIn)
        }
    }

    public func probeSignInFromDOM() {
        let js = """
        (function() {
            try {
                var el = document.querySelector('ytmusic-pivot-bar-renderer yt-avatar') ||
                         document.querySelector('ytmusic-account-chip-renderer') ||
                         document.querySelector('#avatar-btn') ||
                         document.querySelector('ytmusic-pivot-bar-renderer [class*="avatar"]');
                return !!el;
            } catch(e) { return false; }
        })();
        """
        NowPlayingManager.shared.evaluateJSWithResult(js) { [weak self] result in
            let domSignedIn = (result as? Bool) ?? false
            self?.updateSignedIn(domSignedIn)
        }
    }

    private func updateSignedIn(_ value: Bool) {
        DispatchQueue.main.async {
            let changed = self.isSignedIn != value
            self.isSignedIn = value
            if changed {
                NotificationCenter.default.post(name: LikedSongsManager.signInStatusChangedNotification, object: nil)
                print("[LikedSongsManager] isSignedIn = \(value)")
            }
        }
    }

    // MARK: - Toggle Core

    public func recordOnlineLikeToggle(desiredLiked: Bool,
                                       videoId: String,
                                       title: String,
                                       artist: String,
                                       album: String,
                                       artworkUrl: String,
                                       duration: Double) {
        if desiredLiked {
            LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(
                videoId: videoId,
                title: title,
                artist: artist,
                album: album,
                artworkUrl: artworkUrl,
                duration: duration,
                synced: isSignedIn
            ))
        } else {
            LocalDatabaseManager.shared.removeLikedSong(videoId: videoId)
        }
        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
    }

    public func mirrorOfflineLike(trackID: String) {
        let liked = LocalDatabaseManager.shared.isLiked(filePath: trackID)
        if liked {
            guard let track = LocalLibraryManager.shared.allTracks.first(where: {
                $0.id == trackID || $0.fileURL.path == trackID
            }) else { return }
            let key = track.ytVideoId ?? track.fileURL.path
            LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(
                videoId: key,
                title: track.title,
                artist: track.artist,
                album: track.album,
                artworkUrl: track.artworkURL?.absoluteString ?? "",
                duration: track.duration,
                synced: true,
                sourceType: "local"
            ))
        } else {
            if let track = LocalLibraryManager.shared.allTracks.first(where: {
                $0.id == trackID || $0.fileURL.path == trackID
            }) {
                let key = track.ytVideoId ?? track.fileURL.path
                LocalDatabaseManager.shared.removeLikedSong(videoId: key)
            } else {
                LocalDatabaseManager.shared.removeLikedSong(videoId: trackID)
            }
        }
        NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
    }

    // MARK: - One-Time Sync (local -> account)

    public func syncUnsyncedToAccount() {
        guard isSignedIn else {
            NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
            return
        }
        guard !isSyncing else { return }
        let unsynced = LocalDatabaseManager.shared.fetchUnsyncedLikedSongs()
        guard !unsynced.isEmpty else { return }
        isSyncing = true
        syncNext(unsynced)
    }

    private func syncNext(_ remaining: [LikedSongRecord]) {
        guard isSyncing, !remaining.isEmpty, NetworkMonitor.shared.isReachable else {
            isSyncing = false
            NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)
            return
        }
        var items = remaining
        let record = items.removeFirst()

        NowPlayingManager.shared.switchToOnlineMode()
        PlaylistManager.shared.playOnlineVideo(videoId: record.videoId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.isSyncing else { return }
            self.clickLikeButton()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.readLikeState { liked in
                    if liked {
                        LocalDatabaseManager.shared.setLikedSongSynced(videoId: record.videoId)
                    }
                    self?.syncNext(items)
                }
            }
        }
    }

    public func clickLikeButton() {
        let js = """
        (function() {
            var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
            var likeRenderer = playerBar ? (playerBar.querySelector('ytmusic-like-button-renderer') || playerBar.querySelector('#like-button-renderer')) : null;
            if (likeRenderer) {
                var likeBtn = likeRenderer.querySelector('#button-shape-like button, .like-button');
                if (!likeBtn) {
                    var btns = likeRenderer.querySelectorAll('button');
                    for (var i = 0; i < btns.length; i++) {
                        var label = (btns[i].getAttribute('aria-label') || btns[i].getAttribute('title') || '').toLowerCase();
                        if (!label.includes('dislike') && (label.includes('like') || label.includes('thumbs up'))) {
                            likeBtn = btns[i];
                            break;
                        }
                    }
                }
                if (likeBtn) {
                    likeBtn.click();
                    return true;
                }
            }
            return false;
        })();
        """
        NowPlayingManager.shared.evaluateJS(js)
    }

    public func readLikeState(completion: @escaping (Bool) -> Void) {
        let js = """
        (function() {
            var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
            var likeRenderer = playerBar ? (playerBar.querySelector('ytmusic-like-button-renderer') || playerBar.querySelector('#like-button-renderer')) : null;
            if (!likeRenderer) return false;
            var status = (likeRenderer.getAttribute('like-status') || '').toUpperCase();
            if (status === 'LIKE') return true;
            if (status === 'DISLIKE' || status === 'INDIFFERENT') return false;
            var likeBtn = likeRenderer.querySelector('#button-shape-like button') ||
                          likeRenderer.querySelector('button[aria-label*="Remove from your Liked Songs"]') ||
                          likeRenderer.querySelector('button[aria-label*="Undo like"]');
            if (likeBtn) {
                var ariaPressed = likeBtn.getAttribute('aria-pressed');
                var label = (likeBtn.getAttribute('aria-label') || likeBtn.getAttribute('title') || '').toLowerCase();
                return ariaPressed === 'true' || label.includes('undo like') || label.includes('remove from your liked');
            }
            return false;
        })();
        """
        NowPlayingManager.shared.evaluateJSWithResult(js) { result in
            completion((result as? Bool) ?? false)
        }
    }
}