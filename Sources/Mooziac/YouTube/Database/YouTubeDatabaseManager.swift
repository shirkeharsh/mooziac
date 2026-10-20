import AppKit
import Foundation
import SQLite3

public struct VideoHistoryRecord: Equatable {
    public let id: String
    public let videoId: String
    public let title: String
    public let channel: String
    public let artworkUrl: String
    public let duration: Double
    public let playedAt: Double
    public let lastPosition: Double

    public init(
        id: String = UUID().uuidString,
        videoId: String,
        title: String,
        channel: String = "",
        artworkUrl: String = "",
        duration: Double = 0.0,
        playedAt: Double = Date().timeIntervalSince1970,
        lastPosition: Double = 0.0
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.channel = channel
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.playedAt = playedAt
        self.lastPosition = lastPosition
    }

    public var relativePlayedTimeString: String {
        let diff = Date().timeIntervalSince1970 - playedAt
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: playedAt))
    }
}

public struct LocalPlaylistRecord: Equatable {
    public let id: String
    public let name: String
    public let createdAt: Double
    public let updatedAt: Double
    public let itemCount: Int

    public init(id: String = UUID().uuidString, name: String, createdAt: Double = Date().timeIntervalSince1970, updatedAt: Double = Date().timeIntervalSince1970, itemCount: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemCount = itemCount
    }
}

public struct LocalPlaylistItemRecord: Equatable {
    public let id: String
    public let playlistId: String
    public let videoId: String
    public let title: String
    public let channel: String
    public let artworkUrl: String
    public let duration: Double
    public let dateAdded: Double

    public init(
        id: String = UUID().uuidString,
        playlistId: String,
        videoId: String,
        title: String,
        channel: String = "",
        artworkUrl: String = "",
        duration: Double = 0.0,
        dateAdded: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.playlistId = playlistId
        self.videoId = videoId
        self.title = title
        self.channel = channel
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.dateAdded = dateAdded
    }
}

public struct LikedVideoRecord: Equatable {
    public let videoId: String
    public let title: String
    public let channel: String
    public let artworkUrl: String
    public let duration: Double
    public let dateLiked: Double

    public init(videoId: String, title: String, channel: String = "", artworkUrl: String = "", duration: Double = 0.0, dateLiked: Double = Date().timeIntervalSince1970) {
        self.videoId = videoId
        self.title = title
        self.channel = channel
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.dateLiked = dateLiked
    }
}

public final class YouTubeDatabaseManager {
    public static let shared = YouTubeDatabaseManager()

    public static let historyDidChangeNotification = Notification.Name("LocalDatabaseHistoryDidChange")
    public static let playlistsDidChangeNotification = Notification.Name("LocalDatabasePlaylistsDidChange")
    public static let likedVideosDidChangeNotification = Notification.Name("LocalDatabaseLikedVideosDidChange")

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "app.mooziac.localdatabase", qos: .userInitiated)

    public var databaseFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let folder = appSupport.appendingPathComponent("Mooziac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("mooziactube.sqlite3")
    }

    private init() {
        openAndInitializeDatabase()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func openAndInitializeDatabase() {
        let path = databaseFileURL.path
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(path, &dbPointer, flags, nil) != SQLITE_OK {
            Log.app.error("Failed to open SQLite database at \(path)")
            return
        }

        self.db = dbPointer

        executeRaw(sql: "PRAGMA journal_mode = WAL;")
        executeRaw(sql: "PRAGMA synchronous = NORMAL;")
        executeRaw(sql: "PRAGMA foreign_keys = ON;")
        executeRaw(sql: "PRAGMA busy_timeout = 5000;")

        applySchema()
    }

    private func executeRaw(sql: String) {
        guard let db = db else { return }
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                Log.app.error("SQLite Exec error: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
        }
    }

    private func applySchema() {
        let schemaSQL = """
        CREATE TABLE IF NOT EXISTS history (
            id TEXT PRIMARY KEY,
            video_id TEXT NOT NULL,
            title TEXT NOT NULL,
            channel TEXT DEFAULT '',
            artwork_url TEXT DEFAULT '',
            duration REAL DEFAULT 0,
            played_at REAL NOT NULL,
            last_position REAL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_history_played_at ON history(played_at DESC);
        CREATE INDEX IF NOT EXISTS idx_history_video_id ON history(video_id);

        CREATE TABLE IF NOT EXISTS playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            item_count INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS playlist_items (
            id TEXT PRIMARY KEY,
            playlist_id TEXT NOT NULL,
            video_id TEXT NOT NULL,
            title TEXT NOT NULL,
            channel TEXT DEFAULT '',
            artwork_url TEXT DEFAULT '',
            duration REAL DEFAULT 0,
            date_added REAL NOT NULL,
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist ON playlist_items(playlist_id);

        CREATE TABLE IF NOT EXISTS liked_videos (
            video_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            channel TEXT DEFAULT '',
            artwork_url TEXT DEFAULT '',
            duration REAL DEFAULT 0,
            date_liked REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_liked_videos_date ON liked_videos(date_liked DESC);
        """
        executeRaw(sql: schemaSQL)

        // Seed default "Favorites" playlist if no playlists exist
        if fetchPlaylists().isEmpty {
            _ = createPlaylist(name: "Favorites")
        }
    }

    // MARK: - History Operations
    private var lastLoggedKey = ""

    public func recordHistory(videoId: String, title: String, channel: String, duration: Double, lastPosition: Double) {
        let cleanVid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVid.isEmpty, !cleanTitle.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        let key = "\(cleanVid)__\(Int(now / 15))" // 15-second debounce
        if key == lastLoggedKey { return }
        lastLoggedKey = key

        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }

            // Delete previous duplicate entry if it exists to keep history deduplicated and top-recent
            let deleteSQL = "DELETE FROM history WHERE video_id = ?;"
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delStmt, 1, (cleanVid as NSString).utf8String, -1, nil)
                sqlite3_step(delStmt)
                sqlite3_finalize(delStmt)
            }

            let insertSQL = """
            INSERT INTO history (id, video_id, title, channel, artwork_url, duration, played_at, last_position)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                let id = UUID().uuidString
                let artwork = "https://i.ytimg.com/vi/\(cleanVid)/hqdefault.jpg"
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (cleanVid as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (cleanTitle as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (channel as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (artwork as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 6, duration)
                sqlite3_bind_double(stmt, 7, now)
                sqlite3_bind_double(stmt, 8, lastPosition)

                if sqlite3_step(stmt) == SQLITE_DONE {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
                    }
                }
                sqlite3_finalize(stmt)
            }
        }
    }

    public func fetchHistory(limit: Int = 100) -> [VideoHistoryRecord] {
        var results: [VideoHistoryRecord] = []
        dbQueue.sync {
            guard let db = db else { return }
            let sql = "SELECT id, video_id, title, channel, artwork_url, duration, played_at, last_position FROM history ORDER BY played_at DESC LIMIT ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let vid = String(cString: sqlite3_column_text(stmt, 1))
                    let title = String(cString: sqlite3_column_text(stmt, 2))
                    let channel = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : ""
                    let artwork = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
                    let duration = sqlite3_column_double(stmt, 5)
                    let playedAt = sqlite3_column_double(stmt, 6)
                    let lastPos = sqlite3_column_double(stmt, 7)

                    results.append(VideoHistoryRecord(
                        id: id,
                        videoId: vid,
                        title: title,
                        channel: channel,
                        artworkUrl: artwork,
                        duration: duration,
                        playedAt: playedAt,
                        lastPosition: lastPos
                    ))
                }
                sqlite3_finalize(stmt)
            }
        }
        return results
    }

    public func clearHistory() {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            self.executeRaw(sql: "DELETE FROM history;")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
            }
        }
    }

    // MARK: - Liked Videos (100% Local, Offline)
    public func isVideoLiked(videoId: String) -> Bool {
        guard !videoId.isEmpty else { return false }
        var liked = false
        dbQueue.sync {
            guard let db = db else { return }
            let sql = "SELECT 1 FROM liked_videos WHERE video_id = ? LIMIT 1;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (videoId as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    liked = true
                }
                sqlite3_finalize(stmt)
            }
        }
        return liked
    }

    @discardableResult
    public func toggleLike(videoId: String, title: String, channel: String, duration: Double) -> Bool {
        let cleanVid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVid.isEmpty else { return false }

        let currentlyLiked = isVideoLiked(videoId: cleanVid)
        let now = Date().timeIntervalSince1970

        dbQueue.sync { [weak self] in
            guard let self = self, let db = self.db else { return }
            if currentlyLiked {
                let delSQL = "DELETE FROM liked_videos WHERE video_id = ?;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, delSQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (cleanVid as NSString).utf8String, -1, nil)
                    sqlite3_step(stmt)
                    sqlite3_finalize(stmt)
                }
            } else {
                let insertSQL = """
                INSERT OR REPLACE INTO liked_videos (video_id, title, channel, artwork_url, duration, date_liked)
                VALUES (?, ?, ?, ?, ?, ?);
                """
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                    let artwork = "https://i.ytimg.com/vi/\(cleanVid)/hqdefault.jpg"
                    sqlite3_bind_text(stmt, 1, (cleanVid as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (title as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 3, (channel as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 4, (artwork as NSString).utf8String, -1, nil)
                    sqlite3_bind_double(stmt, 5, duration)
                    sqlite3_bind_double(stmt, 6, now)
                    sqlite3_step(stmt)
                    sqlite3_finalize(stmt)
                }
            }
        }

        let newState = !currentlyLiked
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.likedVideosDidChangeNotification, object: newState)
        }
        return newState
    }

    public func fetchLikedVideos() -> [LikedVideoRecord] {
        var results: [LikedVideoRecord] = []
        dbQueue.sync {
            guard let db = db else { return }
            let sql = "SELECT video_id, title, channel, artwork_url, duration, date_liked FROM liked_videos ORDER BY date_liked DESC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let vid = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))
                    let channel = sqlite3_column_text(stmt, 2) != nil ? String(cString: sqlite3_column_text(stmt, 2)) : ""
                    let artwork = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : ""
                    let duration = sqlite3_column_double(stmt, 4)
                    let dateLiked = sqlite3_column_double(stmt, 5)

                    results.append(LikedVideoRecord(
                        videoId: vid,
                        title: title,
                        channel: channel,
                        artworkUrl: artwork,
                        duration: duration,
                        dateLiked: dateLiked
                    ))
                }
                sqlite3_finalize(stmt)
            }
        }
        return results
    }

    // MARK: - Playlists (100% Local, Offline)
    public func createPlaylist(name: String) -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = cleanName.isEmpty ? "New Playlist" : cleanName
        let id = UUID().uuidString
        let now = Date().timeIntervalSince1970

        dbQueue.sync { [weak self] in
            guard let self = self, let db = self.db else { return }
            let sql = "INSERT INTO playlists (id, name, created_at, updated_at, item_count) VALUES (?, ?, ?, ?, 0);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (resolvedName as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, now)
                sqlite3_bind_double(stmt, 4, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.playlistsDidChangeNotification, object: nil)
        }
        return id
    }

    public func fetchPlaylists() -> [LocalPlaylistRecord] {
        var results: [LocalPlaylistRecord] = []
        dbQueue.sync {
            guard let db = db else { return }
            let sql = """
            SELECT p.id, p.name, p.created_at, p.updated_at, COUNT(pi.id) as count
            FROM playlists p
            LEFT JOIN playlist_items pi ON p.id = pi.playlist_id
            GROUP BY p.id
            ORDER BY p.updated_at DESC;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let name = String(cString: sqlite3_column_text(stmt, 1))
                    let createdAt = sqlite3_column_double(stmt, 2)
                    let updatedAt = sqlite3_column_double(stmt, 3)
                    let count = Int(sqlite3_column_int(stmt, 4))

                    results.append(LocalPlaylistRecord(
                        id: id,
                        name: name,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemCount: count
                    ))
                }
                sqlite3_finalize(stmt)
            }
        }
        return results
    }

    public func deletePlaylist(id: String) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            let sql1 = "DELETE FROM playlist_items WHERE playlist_id = ?;"
            var stmt1: OpaquePointer?
            if sqlite3_prepare_v2(db, sql1, -1, &stmt1, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt1, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt1)
                sqlite3_finalize(stmt1)
            }

            let sql2 = "DELETE FROM playlists WHERE id = ?;"
            var stmt2: OpaquePointer?
            if sqlite3_prepare_v2(db, sql2, -1, &stmt2, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt2, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt2)
                sqlite3_finalize(stmt2)
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.playlistsDidChangeNotification, object: nil)
            }
        }
    }

    @discardableResult
    public func addVideoToPlaylist(playlistId: String, videoId: String, title: String, channel: String, duration: Double) -> Bool {
        let cleanVid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !playlistId.isEmpty, !cleanVid.isEmpty else { return false }

        var success = false
        let now = Date().timeIntervalSince1970
        let itemId = UUID().uuidString

        dbQueue.sync { [weak self] in
            guard let self = self, let db = self.db else { return }

            // Check if already in playlist
            let checkSQL = "SELECT 1 FROM playlist_items WHERE playlist_id = ? AND video_id = ? LIMIT 1;"
            var checkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, (playlistId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(checkStmt, 2, (cleanVid as NSString).utf8String, -1, nil)
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    sqlite3_finalize(checkStmt)
                    return // Already exists
                }
                sqlite3_finalize(checkStmt)
            }

            let insertSQL = """
            INSERT INTO playlist_items (id, playlist_id, video_id, title, channel, artwork_url, duration, date_added)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                let artwork = "https://i.ytimg.com/vi/\(cleanVid)/hqdefault.jpg"
                sqlite3_bind_text(stmt, 1, (itemId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (playlistId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (cleanVid as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (title as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (channel as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 6, (artwork as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 7, duration)
                sqlite3_bind_double(stmt, 8, now)
                if sqlite3_step(stmt) == SQLITE_DONE {
                    success = true
                }
                sqlite3_finalize(stmt)
            }

            // Update playlist updated_at
            let updateSQL = "UPDATE playlists SET updated_at = ? WHERE id = ?;"
            var upStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &upStmt, nil) == SQLITE_OK {
                sqlite3_bind_double(upStmt, 1, now)
                sqlite3_bind_text(upStmt, 2, (playlistId as NSString).utf8String, -1, nil)
                sqlite3_step(upStmt)
                sqlite3_finalize(upStmt)
            }
        }

        if success {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.playlistsDidChangeNotification, object: nil)
            }
        }
        return success
    }

    public func fetchPlaylistVideos(playlistId: String) -> [LocalPlaylistItemRecord] {
        var results: [LocalPlaylistItemRecord] = []
        dbQueue.sync {
            guard let db = db else { return }
            let sql = "SELECT id, playlist_id, video_id, title, channel, artwork_url, duration, date_added FROM playlist_items WHERE playlist_id = ? ORDER BY date_added DESC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (playlistId as NSString).utf8String, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let plId = String(cString: sqlite3_column_text(stmt, 1))
                    let vid = String(cString: sqlite3_column_text(stmt, 2))
                    let title = String(cString: sqlite3_column_text(stmt, 3))
                    let channel = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
                    let artwork = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : ""
                    let duration = sqlite3_column_double(stmt, 6)
                    let dateAdded = sqlite3_column_double(stmt, 7)

                    results.append(LocalPlaylistItemRecord(
                        id: id,
                        playlistId: plId,
                        videoId: vid,
                        title: title,
                        channel: channel,
                        artworkUrl: artwork,
                        duration: duration,
                        dateAdded: dateAdded
                    ))
                }
                sqlite3_finalize(stmt)
            }
        }
        return results
    }

    public func removeVideoFromPlaylist(playlistId: String, videoId: String) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            let sql = "DELETE FROM playlist_items WHERE playlist_id = ? AND video_id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (playlistId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (videoId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.playlistsDidChangeNotification, object: nil)
            }
        }
    }
}
