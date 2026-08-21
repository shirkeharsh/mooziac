import AppKit
import Foundation

public final class HistoryManager {
    public static let shared = HistoryManager()

    public static let historyUpdatedNotification = Notification.Name("Mooziac_historyUpdated")

    private var pendingTrackKey: String = ""
    private var pendingStartTime: CFAbsoluteTime = 0
    private var pendingRecord: HistoryRecord?
    private var hasCommittedCurrentPending = false
    private var commitTimer: Timer?
    private var hasSeededInitialHistory = false

    private init() {}

    // MARK: - Track Playback Logging

    /// Tracks online track playback with deduplication.
    public func trackDidStartOnline(
        title: String,
        artist: String,
        album: String,
        artworkUrl: String,
        videoId: String,
        duration: Double
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle != "Not Playing" else { return }

        let trackKey = "\(trimmedTitle.lowercased())__\(artist.lowercased())__\(videoId)"

        // If it's the same track continuing, don't re-log repeatedly
        if trackKey == pendingTrackKey {
            return
        }
        pendingTrackKey = trackKey

        let record = HistoryRecord(
            title: trimmedTitle,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            album: album.trimmingCharacters(in: .whitespacesAndNewlines),
            artworkUrl: artworkUrl,
            ytVideoId: videoId.isEmpty ? nil : videoId,
            filePath: nil,
            playedAt: Date().timeIntervalSince1970,
            duration: duration,
            sourceType: "online"
        )

        LocalDatabaseManager.shared.recordHistoryItem(record)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: HistoryManager.historyUpdatedNotification, object: nil)
        }
    }

    /// Tracks offline track playback with deduplication.
    public func trackDidStartOffline(_ track: LocalTrack) {
        let trackKey = "local__\(track.id)__\(track.fileURL.path)"

        if trackKey == pendingTrackKey {
            return
        }
        pendingTrackKey = trackKey

        let record = HistoryRecord(
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkUrl: track.fileURL.path,
            ytVideoId: track.ytVideoId,
            filePath: track.fileURL.path,
            playedAt: Date().timeIntervalSince1970,
            duration: track.duration,
            sourceType: "local"
        )

        LocalDatabaseManager.shared.recordHistoryItem(record)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: HistoryManager.historyUpdatedNotification, object: nil)
        }
    }

    // MARK: - Query & Management

    public func fetchHistory(limit: Int = 200, offset: Int = 0) -> [HistoryRecord] {
        var records = LocalDatabaseManager.shared.fetchHistory(limit: limit, offset: offset)
        if records.isEmpty && !hasSeededInitialHistory {
            hasSeededInitialHistory = true
            // Seed with currently playing track if available
            let state = NowPlayingManager.shared.currentState
            let title = !state.title.isEmpty && state.title != "Not Playing" ? state.title : (UserDefaults.standard.string(forKey: "YTM_lastTitle") ?? "")
            let artist = !state.artist.isEmpty && state.artist != "YouTube Music" ? state.artist : (UserDefaults.standard.string(forKey: "YTM_lastArtist") ?? "")
            let videoId = !state.videoId.isEmpty ? state.videoId : (UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? "")
            let artworkUrl = !state.artworkUrl.isEmpty ? state.artworkUrl : (UserDefaults.standard.string(forKey: "YTM_lastArtwork") ?? "")
            let duration = state.duration > 0 ? state.duration : UserDefaults.standard.double(forKey: "YTM_lastDuration")
            
            if !title.isEmpty && title != "Not Playing" {
                let initialRecord = HistoryRecord(
                    title: title,
                    artist: artist,
                    album: "",
                    artworkUrl: artworkUrl,
                    ytVideoId: videoId.isEmpty ? nil : videoId,
                    filePath: nil,
                    playedAt: Date().timeIntervalSince1970,
                    duration: duration,
                    sourceType: "online"
                )
                LocalDatabaseManager.shared.recordHistoryItem(initialRecord)
                records = [initialRecord]
            }
        }
        return records
    }

    @discardableResult
    public func deleteHistoryItem(id: String) -> Bool {
        let success = LocalDatabaseManager.shared.deleteHistoryItem(id: id)
        if success {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HistoryManager.historyUpdatedNotification, object: nil)
            }
        }
        return success
    }

    @discardableResult
    public func clearHistory() -> Bool {
        let success = LocalDatabaseManager.shared.clearHistory()
        if success {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HistoryManager.historyUpdatedNotification, object: nil)
            }
        }
        return success
    }

    public func fetchHistoryCount() -> Int {
        return LocalDatabaseManager.shared.fetchHistoryCount()
    }

    // MARK: - Playback Routing

    public func playHistoryItem(_ item: HistoryRecord) {
        if item.sourceType == "local", let path = item.filePath, FileManager.default.fileExists(atPath: path) {
            let localTrack: LocalTrack
            if let existing = LocalLibraryManager.shared.allTracks.first(where: { $0.fileURL.path == path }) {
                localTrack = existing
            } else {
                localTrack = LocalTrack(
                    id: item.id,
                    title: item.title,
                    artist: item.artist,
                    album: item.album,
                    duration: item.duration,
                    fileURL: URL(fileURLWithPath: path),
                    isLiked: LocalDatabaseManager.shared.isLiked(filePath: path)
                )
            }
            NowPlayingManager.shared.playOfflineTrack(localTrack, in: [localTrack])
        } else if let vid = item.ytVideoId, !vid.isEmpty {
            NowPlayingManager.shared.switchToOnlineMode()
            PlaylistManager.shared.playOnlineVideo(videoId: vid)
        } else {
            // Fallback online search or playback
            NowPlayingManager.shared.switchToOnlineMode()
            let query = "\(item.title) \(item.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
            if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://music.youtube.com/search?q=\(encoded)") {
                DispatchQueue.main.async {
                    StatusItemManager.shared?.mainViewController.webViewContainer.webView.load(URLRequest(url: url))
                }
            }
        }
    }
}
