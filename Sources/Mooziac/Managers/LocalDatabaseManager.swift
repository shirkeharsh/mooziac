import AppKit
import Foundation
import SQLite3

public struct CachedTrackRecord {
    public let id: String
    public let filePath: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let dateAdded: Double
    public let dateModified: Double
    public let fileSize: Int64
    public var isLiked: Bool
    public let lrcPath: String?
    public var ytVideoId: String?

    public init(
        id: String,
        filePath: String,
        title: String,
        artist: String,
        album: String,
        duration: Double,
        dateAdded: Double,
        dateModified: Double,
        fileSize: Int64,
        isLiked: Bool,
        lrcPath: String?,
        ytVideoId: String? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.fileSize = fileSize
        self.isLiked = isLiked
        self.lrcPath = lrcPath
        self.ytVideoId = ytVideoId
    }

    public func toLocalTrack() -> LocalTrack {
        let fileURL = URL(fileURLWithPath: filePath)
        let lrcURL: URL? = (lrcPath != nil && !lrcPath!.isEmpty) ? URL(fileURLWithPath: lrcPath!) : nil
        return LocalTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileURL: fileURL,
            artwork: nil,
            artworkURL: nil,
            lrcURL: lrcURL,
            isLiked: isLiked,
            dateAdded: Date(timeIntervalSince1970: dateAdded),
            ytVideoId: ytVideoId
        )
    }
}

public struct PlaylistRecord {
    public let id: String
    public let name: String
    public let createdAt: Double
    public let updatedAt: Double
    public let itemCount: Int
    public let ytPlaylistId: String?
    public let synced: Bool
    public let dirty: Bool

    public init(id: String, name: String, createdAt: Double, updatedAt: Double, itemCount: Int,
                ytPlaylistId: String? = nil, synced: Bool = false, dirty: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemCount = itemCount
        self.ytPlaylistId = ytPlaylistId
        self.synced = synced
        self.dirty = dirty
    }
}

public struct PlaylistItemRecord {
    public let id: String
    public let playlistID: String
    public let sortOrder: Int
    public let refType: String
    public let refID: String
    public let ytVideoId: String?
    public let title: String
    public let artist: String
    public let artworkUrl: String
    public let duration: String
    public let isLiked: Bool
    public let dateAdded: Double

    public init(
        id: String = UUID().uuidString,
        playlistID: String,
        sortOrder: Int,
        refType: String,
        refID: String,
        ytVideoId: String? = nil,
        title: String,
        artist: String = "",
        artworkUrl: String = "",
        duration: String = "",
        isLiked: Bool = false,
        dateAdded: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.playlistID = playlistID
        self.sortOrder = sortOrder
        self.refType = refType
        self.refID = refID
        self.ytVideoId = ytVideoId
        self.title = title
        self.artist = artist
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.isLiked = isLiked
        self.dateAdded = dateAdded
    }
}

public struct HistoryRecord: Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let artworkUrl: String
    public let ytVideoId: String?
    public let filePath: String?
    public let playedAt: Double
    public let duration: Double
    public let sourceType: String // "online" or "local"

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "",
        album: String = "",
        artworkUrl: String = "",
        ytVideoId: String? = nil,
        filePath: String? = nil,
        playedAt: Double = Date().timeIntervalSince1970,
        duration: Double = 0.0,
        sourceType: String = "online"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkUrl = artworkUrl
        self.ytVideoId = ytVideoId
        self.filePath = filePath
        self.playedAt = playedAt
        self.duration = duration
        self.sourceType = sourceType
    }

    public var relativePlayedTimeString: String {
        let diff = Date().timeIntervalSince1970 - playedAt
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            let mins = max(1, Int(diff / 60))
            return "\(mins)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else if diff < 172800 {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: Date(timeIntervalSince1970: playedAt))
        }
    }
}

public final class LocalDatabaseManager {
    public static let shared = LocalDatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.mooziac.localdatabase", qos: .userInitiated)
    private let currentSchemaVersion: Int32 = 3

    public var databaseFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let folder = appSupport.appendingPathComponent("Mooziac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("library.sqlite3")
    }

    private init() {
        openAndInitializeDatabase()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Open & Rebuild
    private func openAndInitializeDatabase() {
        let path = databaseFileURL.path
        var dbPointer: OpaquePointer?

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &dbPointer, flags, nil) != SQLITE_OK {
            print("[LocalDatabaseManager] Failed to open SQLite database at \(path)")
            recoverCorruptDatabase()
            return
        }

        self.db = dbPointer

        executeRaw(sql: "PRAGMA journal_mode = WAL;")
        executeRaw(sql: "PRAGMA synchronous = NORMAL;")
        executeRaw(sql: "PRAGMA foreign_keys = ON;")
        executeRaw(sql: "PRAGMA busy_timeout = 5000;")
        executeRaw(sql: "PRAGMA mmap_size = 16777216;")
        executeRaw(sql: "PRAGMA cache_size = -2000;")
        executeRaw(sql: "PRAGMA temp_store = MEMORY;")

        applySchemaIfNeeded()
    }

    public func recoverCorruptDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }

        let baseURL = databaseFileURL
        let walURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite3-wal")
        let shmURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite3-shm")

        let backupDir = baseURL.deletingLastPathComponent()
            .appendingPathComponent("Corrupt_Backups", isDirectory: true)
            .appendingPathComponent("\(Int(Date().timeIntervalSince1970))",
                                    isDirectory: true)

        try? FileManager.default.createDirectory(
            at: backupDir,
            withIntermediateDirectories: true
        )

        if let dbData = try? Data(contentsOf: baseURL) {
            try? dbData.write(
                to: backupDir.appendingPathComponent(baseURL.lastPathComponent)
            )
        }

        try? FileManager.default.removeItem(at: baseURL)
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)

        print("[LocalDatabaseManager] Rebuilding database from scratch...")

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(baseURL.path, &dbPointer, flags, nil) == SQLITE_OK {
            self.db = dbPointer
            executeRaw(sql: "PRAGMA journal_mode = WAL;")
            executeRaw(sql: "PRAGMA synchronous = NORMAL;")
            executeRaw(sql: "PRAGMA foreign_keys = ON;")
            executeRaw(sql: "PRAGMA busy_timeout = 5000;")
            executeRaw(sql: "PRAGMA mmap_size = 16777216;")
            executeRaw(sql: "PRAGMA cache_size = -2000;")
            executeRaw(sql: "PRAGMA temp_store = MEMORY;")
            applySchemaIfNeeded()
        }
    }

    private func applySchemaIfNeeded() {
        let userVersion = getUserVersion()
        if userVersion < 1 {
            let schema = """
            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                file_path TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT NOT NULL,
                duration REAL NOT NULL,
                date_added REAL NOT NULL,
                date_modified REAL NOT NULL,
                file_size INTEGER NOT NULL,
                is_liked INTEGER NOT NULL DEFAULT 0,
                lrc_path TEXT,
                yt_video_id TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_tracks_file_path ON tracks(file_path);
            CREATE INDEX IF NOT EXISTS idx_tracks_date_added ON tracks(date_added);
            CREATE INDEX IF NOT EXISTS idx_tracks_yt_video_id ON tracks(yt_video_id);
            """
            if executeRaw(sql: schema) {
                setUserVersion(1)
            }
        }

        if userVersion < 2 {
            migrateToV2()
        }

        if userVersion < 3 {
            migrateToV3()
        }

        if userVersion < 4 {
            migrateToV4()
        }

        if userVersion < 5 {
            migrateToV5()
        }
    }

    private func columnExists(table: String, column: String) -> Bool {
        guard let db = db else { return false }
        let query = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        var found = false
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cName = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: cName)
                    if name == column {
                        found = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return found
    }

    private func migrateToV2() {
        // 1. Add yt_video_id to tracks (idempotent for fresh installs already on v1 schema)
        if !columnExists(table: "tracks", column: "yt_video_id") {
            executeRaw(sql: "ALTER TABLE tracks ADD COLUMN yt_video_id TEXT;")
        }
        executeRaw(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_yt_video_id ON tracks(yt_video_id);")

        // 2. Playlists + playlist_items tables
        let schema = """
        CREATE TABLE IF NOT EXISTS playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS playlist_items (
            id TEXT PRIMARY KEY,
            playlist_id TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            ref_type TEXT NOT NULL,
            ref_id TEXT NOT NULL,
            yt_video_id TEXT,
            title TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            artwork_url TEXT NOT NULL DEFAULT '',
            duration TEXT NOT NULL DEFAULT '',
            is_liked INTEGER NOT NULL DEFAULT 0,
            date_added REAL NOT NULL,
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist ON playlist_items(playlist_id, sort_order);
        CREATE INDEX IF NOT EXISTS idx_playlist_items_yt_video ON playlist_items(yt_video_id);
        """
        if executeRaw(sql: schema) {
            setUserVersion(2)
            print("[LocalDatabaseManager] Schema migrated to v2 (playlists + yt_video_id)")
        }
    }

    private func migrateToV3() {
        let schema = """
        CREATE TABLE IF NOT EXISTS listening_history (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            artwork_url TEXT NOT NULL DEFAULT '',
            yt_video_id TEXT,
            file_path TEXT,
            played_at REAL NOT NULL,
            duration REAL NOT NULL DEFAULT 0.0,
            source_type TEXT NOT NULL DEFAULT 'online'
        );
        CREATE INDEX IF NOT EXISTS idx_history_played_at ON listening_history(played_at DESC);
        CREATE INDEX IF NOT EXISTS idx_history_video_id ON listening_history(yt_video_id);
        CREATE INDEX IF NOT EXISTS idx_history_file_path ON listening_history(file_path);
        """
        if executeRaw(sql: schema) {
            setUserVersion(3)
            print("[LocalDatabaseManager] Schema migrated to v3 (listening_history)")
        }
    }

    private func migrateToV4() {
        let schema = """
        CREATE TABLE IF NOT EXISTS liked_songs (
            video_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            artwork_url TEXT NOT NULL DEFAULT '',
            duration REAL NOT NULL DEFAULT 0.0,
            date_liked REAL NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            source_type TEXT NOT NULL DEFAULT 'ytm'
        );
        CREATE INDEX IF NOT EXISTS idx_liked_songs_date ON liked_songs(date_liked DESC);
        """
        if executeRaw(sql: schema) {
            setUserVersion(4)
            print("[LocalDatabaseManager] Schema migrated to v4 (liked_songs)")
        }
    }

    private func migrateToV5() {
        // YTM sync columns for playlists (purely additive; existing rows unaffected)
        if !columnExists(table: "playlists", column: "yt_playlist_id") {
            executeRaw(sql: "ALTER TABLE playlists ADD COLUMN yt_playlist_id TEXT;")
        }
        if !columnExists(table: "playlists", column: "synced") {
            executeRaw(sql: "ALTER TABLE playlists ADD COLUMN synced INTEGER NOT NULL DEFAULT 0;")
        }
        if !columnExists(table: "playlists", column: "dirty") {
            executeRaw(sql: "ALTER TABLE playlists ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0;")
        }
        executeRaw(sql: "CREATE INDEX IF NOT EXISTS idx_playlists_yt_playlist_id ON playlists(yt_playlist_id);")
        setUserVersion(5)
        print("[LocalDatabaseManager] Schema migrated to v5 (YTM sync columns)")
    }

    private func getUserVersion() -> Int32 {
        var version: Int32 = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = sqlite3_column_int(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return version
    }

    private func setUserVersion(_ version: Int32) {
        executeRaw(sql: "PRAGMA user_version = \(version);")
    }

    @discardableResult
    private func executeRaw(sql: String) -> Bool {
        guard let db = db else { return false }
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                let errStr = String(cString: errMsg)
                print("[LocalDatabaseManager] SQL Error: \(errStr) in SQL: \(sql)")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }

    // MARK: - Fetch All Cached Records
    public func fetchAllRecords() -> [String: CachedTrackRecord] {
        var map: [String: CachedTrackRecord] = [:]
        guard let db = db else { return map }

        let query = "SELECT id, file_path, title, artist, album, duration, date_added, date_modified, file_size, is_liked, lrc_path, yt_video_id FROM tracks;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let filePath = String(cString: sqlite3_column_text(stmt, 1))
                let title = String(cString: sqlite3_column_text(stmt, 2))
                let artist = String(cString: sqlite3_column_text(stmt, 3))
                let album = String(cString: sqlite3_column_text(stmt, 4))
                let duration = sqlite3_column_double(stmt, 5)
                let dateAdded = sqlite3_column_double(stmt, 6)
                let dateModified = sqlite3_column_double(stmt, 7)
                let fileSize = sqlite3_column_int64(stmt, 8)
                let isLiked = sqlite3_column_int(stmt, 9) == 1
                var lrcPath: String? = nil
                if let cLrc = sqlite3_column_text(stmt, 10) {
                    lrcPath = String(cString: cLrc)
                }
                var ytVideoId: String? = nil
                if let cVid = sqlite3_column_text(stmt, 11) {
                    let vid = String(cString: cVid)
                    if !vid.isEmpty { ytVideoId = vid }
                }

                let record = CachedTrackRecord(
                    id: id,
                    filePath: filePath,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    dateAdded: dateAdded,
                    dateModified: dateModified,
                    fileSize: fileSize,
                    isLiked: isLiked,
                    lrcPath: lrcPath,
                    ytVideoId: ytVideoId
                )
                map[filePath] = record
            }
        }
        sqlite3_finalize(stmt)
        return map
    }

    // MARK: - Batched Upsert Tracks
    public func upsertTracks(_ records: [CachedTrackRecord]) {
        guard !records.isEmpty, let db = db else { return }

        let sql = """
        INSERT INTO tracks (id, file_path, title, artist, album, duration, date_added, date_modified, file_size, is_liked, lrc_path, yt_video_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(file_path) DO UPDATE SET
            id = excluded.id,
            title = excluded.title,
            artist = excluded.artist,
            album = excluded.album,
            duration = excluded.duration,
            date_added = excluded.date_added,
            date_modified = excluded.date_modified,
            file_size = excluded.file_size,
            is_liked = excluded.is_liked,
            lrc_path = excluded.lrc_path,
            yt_video_id = COALESCE(excluded.yt_video_id, tracks.yt_video_id);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }

        executeRaw(sql: "BEGIN TRANSACTION;")

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        for rec in records {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)

            sqlite3_bind_text(stmt, 1, (rec.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (rec.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (rec.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, (rec.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, (rec.album as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 6, rec.duration)
            sqlite3_bind_double(stmt, 7, rec.dateAdded)
            sqlite3_bind_double(stmt, 8, rec.dateModified)
            sqlite3_bind_int64(stmt, 9, rec.fileSize)
            sqlite3_bind_int(stmt, 10, rec.isLiked ? 1 : 0)
            if let lrc = rec.lrcPath {
                sqlite3_bind_text(stmt, 11, (lrc as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 11)
            }
            if let vid = rec.ytVideoId, !vid.isEmpty {
                sqlite3_bind_text(stmt, 12, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 12)
            }

            if sqlite3_step(stmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                print("[LocalDatabaseManager] step failed: \(msg)")
            }
        }

        executeRaw(sql: "COMMIT;")
        sqlite3_finalize(stmt)
    }

    // MARK: - Batched Delete Tracks
    public func deleteTracks(filePaths: [String]) {
        guard !filePaths.isEmpty, let db = db else { return }

        let sql = "DELETE FROM tracks WHERE file_path = ?;"
        let cleanupItemsSQL =
            "DELETE FROM playlist_items " +
            "WHERE (ref_type = 'local' AND ref_id = ?) " +
            "OR (ref_type = 'yt' AND ref_id = ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }

        var cleanupStmt: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, cleanupItemsSQL, -1, &cleanupStmt, nil) != SQLITE_OK {
            cleanupStmt = nil
        }

        let allRecords = self.fetchAllRecords()
        executeRaw(sql: "BEGIN TRANSACTION;")
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        for path in filePaths {
            // Remove any playlist items that referenced the deleted local file or its YouTube video ID
            if let cleanupStmt = cleanupStmt {
                sqlite3_reset(cleanupStmt)
                sqlite3_clear_bindings(cleanupStmt)
                sqlite3_bind_text(cleanupStmt, 1, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let vid = allRecords[path]?.ytVideoId, !vid.isEmpty {
                    sqlite3_bind_text(cleanupStmt, 2, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(cleanupStmt, 2)
                }
                if sqlite3_step(cleanupStmt) != SQLITE_DONE {
                    let msg = String(cString: sqlite3_errmsg(db))
                    print("[LocalDatabaseManager] step failed: \(msg)")
                }
            }

            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                print("[LocalDatabaseManager] step failed: \(msg)")
            }
        }

        executeRaw(sql: "COMMIT;")
        sqlite3_finalize(stmt)
        if let cleanupStmt = cleanupStmt {
            sqlite3_finalize(cleanupStmt)
        }
    }

    // MARK: - Toggle / Set Liked
    public func setLiked(filePath: String, isLiked: Bool) {
        guard let db = db else { return }
        let sql = "UPDATE tracks SET is_liked = ? WHERE file_path = ? OR id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int(stmt, 1, isLiked ? 1 : 0)
            sqlite3_bind_text(stmt, 2, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func isLiked(filePath: String) -> Bool {
        guard let db = db else { return false }
        let sql = "SELECT is_liked FROM tracks WHERE file_path = ? OR id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        var liked = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                liked = sqlite3_column_int(stmt, 0) == 1
            }
        }
        sqlite3_finalize(stmt)
        return liked
    }

    // MARK: - Safe Migration of Legacy UserDefaults Liked Keys
    public func migrateLikedKeysFromUserDefaultsIfNeeded() {
        let migrationKey = "Mooziac_SQLite_Liked_Migration_V1_Done"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let legacyKeys = UserDefaults.standard.stringArray(forKey: "Mooziac_OfflineLikedKeys") ?? []
        if !legacyKeys.isEmpty {
            for key in legacyKeys {
                setLiked(filePath: key, isLiked: true)
            }
            print("[LocalDatabaseManager] Successfully migrated \(legacyKeys.count) liked tracks from UserDefaults to SQLite")
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Liked Songs (account + signed-out mirror)
    public func addLikedSong(_ record: LikedSongRecord) {
        guard let db = db else { return }
        let sql = """
        INSERT INTO liked_songs (video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(video_id) DO UPDATE SET
            title = excluded.title,
            artist = excluded.artist,
            album = excluded.album,
            artwork_url = excluded.artwork_url,
            duration = excluded.duration,
            synced = excluded.synced;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (record.videoId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (record.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (record.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, (record.album as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, (record.artworkUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 6, record.duration)
            sqlite3_bind_double(stmt, 7, record.dateLiked)
            sqlite3_bind_int(stmt, 8, record.synced ? 1 : 0)
            sqlite3_bind_text(stmt, 9, (record.sourceType as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func removeLikedSong(videoId: String) {
        guard let db = db else { return }
        let sql = "DELETE FROM liked_songs WHERE video_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (videoId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func isLikedSong(videoId: String) -> Bool {
        guard let db = db else { return false }
        let sql = "SELECT video_id FROM liked_songs WHERE video_id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (videoId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                exists = true
            }
        }
        sqlite3_finalize(stmt)
        return exists
    }

    public func setLikedSongSynced(videoId: String) {
        guard let db = db else { return }
        let sql = "UPDATE liked_songs SET synced = 1 WHERE video_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (videoId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func fetchLikedSongs() -> [LikedSongRecord] {
        var records: [LikedSongRecord] = []
        guard let db = db else { return records }
        let sql = "SELECT video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type FROM liked_songs ORDER BY date_liked DESC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let videoId = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let artist = String(cString: sqlite3_column_text(stmt, 2))
                let album = String(cString: sqlite3_column_text(stmt, 3))
                let artworkUrl = String(cString: sqlite3_column_text(stmt, 4))
                let duration = sqlite3_column_double(stmt, 5)
                let dateLiked = sqlite3_column_double(stmt, 6)
                let synced = sqlite3_column_int(stmt, 7) == 1
                let sourceType = String(cString: sqlite3_column_text(stmt, 8))
                records.append(LikedSongRecord(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    album: album,
                    artworkUrl: artworkUrl,
                    duration: duration,
                    dateLiked: dateLiked,
                    synced: synced,
                    sourceType: sourceType
                ))
            }
        }
        sqlite3_finalize(stmt)
        return records
    }

    public func fetchUnsyncedLikedSongs() -> [LikedSongRecord] {
        var records: [LikedSongRecord] = []
        guard let db = db else { return records }
        let sql = "SELECT video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type FROM liked_songs WHERE synced = 0 ORDER BY date_liked DESC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let videoId = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let artist = String(cString: sqlite3_column_text(stmt, 2))
                let album = String(cString: sqlite3_column_text(stmt, 3))
                let artworkUrl = String(cString: sqlite3_column_text(stmt, 4))
                let duration = sqlite3_column_double(stmt, 5)
                let dateLiked = sqlite3_column_double(stmt, 6)
                let synced = sqlite3_column_int(stmt, 7) == 1
                let sourceType = String(cString: sqlite3_column_text(stmt, 8))
                records.append(LikedSongRecord(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    album: album,
                    artworkUrl: artworkUrl,
                    duration: duration,
                    dateLiked: dateLiked,
                    synced: synced,
                    sourceType: sourceType
                ))
            }
        }
        sqlite3_finalize(stmt)
        return records
    }

    public func countLikedSongs() -> Int {
        guard let db = db else { return 0 }
        let sql = "SELECT COUNT(*) FROM liked_songs;"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // MARK: - yt_video_id Assignment & Lookup
    public func setYTVideoID(_ videoId: String?, for filePath: String) {
        guard let db = db else { return }
        let sql = "UPDATE tracks SET yt_video_id = ? WHERE file_path = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            if let vid = videoId, !vid.isEmpty {
                sqlite3_bind_text(stmt, 1, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_text(stmt, 2, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func filePaths(byVideoID videoId: String) -> [String] {
        var result: [String] = []
        guard let db = db, !videoId.isEmpty else { return result }
        let sql = "SELECT file_path FROM tracks WHERE yt_video_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (videoId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cPath = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: cPath))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Playlist CRUD
    public func fetchPlaylists() -> [PlaylistRecord] {
        var result: [PlaylistRecord] = []
        guard let db = db else { return result }
        let query = """
        SELECT p.id, p.name, p.created_at, p.updated_at, COUNT(pi.id) AS item_count,
               p.yt_playlist_id, p.synced, p.dirty
        FROM playlists p
        LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
        GROUP BY p.id
        ORDER BY p.updated_at DESC, p.created_at DESC;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let createdAt = sqlite3_column_double(stmt, 2)
                let updatedAt = sqlite3_column_double(stmt, 3)
                let itemCount = Int(sqlite3_column_int(stmt, 4))
                let ytPlaylistId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let synced = sqlite3_column_int(stmt, 6) == 1
                let dirty = sqlite3_column_int(stmt, 7) == 1
                result.append(PlaylistRecord(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, itemCount: itemCount,
                                             ytPlaylistId: ytPlaylistId, synced: synced, dirty: dirty))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    @discardableResult
    public func createPlaylist(name: String) -> String? {
        guard let db = db else { return nil }
        let id = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let sql = "INSERT INTO playlists (id, name, created_at, updated_at) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, now)
            sqlite3_bind_double(stmt, 4, now)
            success = sqlite3_step(stmt) == SQLITE_DONE
        }
        sqlite3_finalize(stmt)
        return success ? id : nil
    }

    public func renamePlaylist(id: String, name: String) {
        guard let db = db else { return }
        let sql = "UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func deletePlaylist(id: String) {
        guard let db = db else { return }
        let sql = "DELETE FROM playlists WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func touchPlaylist(id: String, updatedAt: Double = Date().timeIntervalSince1970) {
        guard let db = db else { return }
        let sql = "UPDATE playlists SET updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_double(stmt, 1, updatedAt)
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Playlist Items
    public func fetchPlaylistItems(playlistID: String) -> [PlaylistItemRecord] {
        var result: [PlaylistItemRecord] = []
        guard let db = db else { return result }
        let query = """
        SELECT id, playlist_id, sort_order, ref_type, ref_id, yt_video_id, title, artist, artwork_url, duration, is_liked, date_added
        FROM playlist_items
        WHERE playlist_id = ?
        ORDER BY sort_order ASC;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let playlistID = String(cString: sqlite3_column_text(stmt, 1))
                let sortOrder = Int(sqlite3_column_int(stmt, 2))
                let refType = String(cString: sqlite3_column_text(stmt, 3))
                let refID = String(cString: sqlite3_column_text(stmt, 4))
                var ytVideoId: String? = nil
                if let cVid = sqlite3_column_text(stmt, 5) {
                    let vid = String(cString: cVid)
                    if !vid.isEmpty { ytVideoId = vid }
                }
                let title = String(cString: sqlite3_column_text(stmt, 6))
                let artist = String(cString: sqlite3_column_text(stmt, 7))
                let artworkUrl = String(cString: sqlite3_column_text(stmt, 8))
                let duration = String(cString: sqlite3_column_text(stmt, 9))
                let isLiked = sqlite3_column_int(stmt, 10) == 1
                let dateAdded = sqlite3_column_double(stmt, 11)
                result.append(PlaylistItemRecord(
                    id: id, playlistID: playlistID, sortOrder: sortOrder,
                    refType: refType, refID: refID, ytVideoId: ytVideoId,
                    title: title, artist: artist, artworkUrl: artworkUrl,
                    duration: duration, isLiked: isLiked, dateAdded: dateAdded
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    public func replacePlaylistItems(playlistID: String, items: [PlaylistItemRecord]) {
        guard let db = db else { return }
        let deleteSQL = "DELETE FROM playlist_items WHERE playlist_id = ?;"
        let insertSQL = """
        INSERT INTO playlist_items (id, playlist_id, sort_order, ref_type, ref_id, yt_video_id, title, artist, artwork_url, duration, is_liked, date_added)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let now = Date().timeIntervalSince1970
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        executeRaw(sql: "BEGIN TRANSACTION;")

        var delStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &delStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(delStmt, 1, (playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(delStmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                print("[LocalDatabaseManager] step failed: \(msg)")
            }
        }
        sqlite3_finalize(delStmt)

        var insStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &insStmt, nil) == SQLITE_OK {
            for item in items {
                sqlite3_reset(insStmt)
                sqlite3_clear_bindings(insStmt)
                sqlite3_bind_text(insStmt, 1, (item.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insStmt, 2, (item.playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(insStmt, 3, Int32(item.sortOrder))
                sqlite3_bind_text(insStmt, 4, (item.refType as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insStmt, 5, (item.refID as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let vid = item.ytVideoId, !vid.isEmpty {
                    sqlite3_bind_text(insStmt, 6, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(insStmt, 6)
                }
                sqlite3_bind_text(insStmt, 7, (item.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insStmt, 8, (item.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insStmt, 9, (item.artworkUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insStmt, 10, (item.duration as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(insStmt, 11, item.isLiked ? 1 : 0)
                sqlite3_bind_double(insStmt, 12, item.dateAdded)
                if sqlite3_step(insStmt) != SQLITE_DONE {
                    let msg = String(cString: sqlite3_errmsg(db))
                    print("[LocalDatabaseManager] step failed: \(msg)")
                }
            }
        }
        sqlite3_finalize(insStmt)

        executeRaw(sql: "COMMIT;")
        touchPlaylist(id: playlistID, updatedAt: now)
    }

    public func appendPlaylistItem(_ item: PlaylistItemRecord) {
        guard let db = db else { return }
        let sql = """
        INSERT INTO playlist_items (id, playlist_id, sort_order, ref_type, ref_id, yt_video_id, title, artist, artwork_url, duration, is_liked, date_added)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (item.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (item.playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(item.sortOrder))
            sqlite3_bind_text(stmt, 4, (item.refType as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, (item.refID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if let vid = item.ytVideoId, !vid.isEmpty {
                sqlite3_bind_text(stmt, 6, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_bind_text(stmt, 7, (item.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 8, (item.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, (item.artworkUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 10, (item.duration as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 11, item.isLiked ? 1 : 0)
            sqlite3_bind_double(stmt, 12, item.dateAdded)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        touchPlaylist(id: item.playlistID)
    }

    public func removePlaylistItem(itemID: String, playlistID: String) {
        guard let db = db else { return }
        let sql = "DELETE FROM playlist_items WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (itemID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        touchPlaylist(id: playlistID)
    }

    public func reorderPlaylistItems(playlistID: String, orderedItemIDs: [String]) {
        guard let db = db else { return }
        let sql = "UPDATE playlist_items SET sort_order = ? WHERE id = ? AND playlist_id = ?;"
        var stmt: OpaquePointer?
        executeRaw(sql: "BEGIN TRANSACTION;")
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (index, itemID) in orderedItemIDs.enumerated() {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                sqlite3_bind_int(stmt, 1, Int32(index))
                sqlite3_bind_text(stmt, 2, (itemID as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, (playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
        }
        sqlite3_finalize(stmt)
        executeRaw(sql: "COMMIT;")
        touchPlaylist(id: playlistID)
    }

    // MARK: - YTM Sync Support

    /// Insert a playlist imported from YouTube Music, or return the existing local
    /// playlist's id if it was already imported. `synced` is set to 1 so the push
    /// direction never re-creates it. Name is only set on first import so a local
    /// rename of a synced playlist is not clobbered by later pulls.
    public func upsertPlaylistFromYTM(ytPlaylistId: String, name: String) -> String? {
        guard let db = db else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Date().timeIntervalSince1970

        var existingID: String? = nil
        let lookupSQL = "SELECT id FROM playlists WHERE yt_playlist_id = ? LIMIT 1;"
        var lookupStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, lookupSQL, -1, &lookupStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(lookupStmt, 1, (ytPlaylistId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(lookupStmt) == SQLITE_ROW {
                existingID = String(cString: sqlite3_column_text(lookupStmt, 0))
            }
        }
        sqlite3_finalize(lookupStmt)

        if let existingID = existingID {
            let sql = "UPDATE playlists SET name = ?, synced = 1, dirty = 0, updated_at = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 2, now)
                sqlite3_bind_text(stmt, 3, (existingID as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            return existingID
        }

        let id = UUID().uuidString
        let sql = "INSERT INTO playlists (id, name, created_at, updated_at, yt_playlist_id, synced, dirty) VALUES (?, ?, ?, ?, ?, 1, 0);"
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, now)
            sqlite3_bind_double(stmt, 4, now)
            sqlite3_bind_text(stmt, 5, (ytPlaylistId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            success = sqlite3_step(stmt) == SQLITE_DONE
        }
        sqlite3_finalize(stmt)
        return success ? id : nil
    }

    public func setPlaylistSynced(id: String) {
        guard let db = db else { return }
        let sql = "UPDATE playlists SET synced = 1, dirty = 0 WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func setPlaylistYTMID(id: String, ytPlaylistId: String) {
        guard let db = db else { return }
        let sql = "UPDATE playlists SET yt_playlist_id = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (ytPlaylistId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func markPlaylistDirty(playlistID: String) {
        guard let db = db else { return }
        let sql = "UPDATE playlists SET dirty = 1 WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, (playlistID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func fetchUnsyncedPlaylists() -> [PlaylistRecord] {
        return fetchPlaylists().filter { !$0.synced }
    }

    public func fetchSyncedPlaylists() -> [PlaylistRecord] {
        return fetchPlaylists().filter { $0.ytPlaylistId != nil }
    }

    public func fetchDirtySyncedPlaylists() -> [PlaylistRecord] {
        return fetchPlaylists().filter { $0.ytPlaylistId != nil && $0.dirty }
    }

    // MARK: - Listening History

    public func recordHistoryItem(_ item: HistoryRecord) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }

            // 1. Delete existing duplicates matching this song to guarantee uniqueness
            if let vid = item.ytVideoId, !vid.isEmpty {
                let deleteSql = "DELETE FROM listening_history WHERE yt_video_id = ?;"
                var delStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, deleteSql, -1, &delStmt, nil) == SQLITE_OK {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    sqlite3_bind_text(delStmt, 1, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    sqlite3_step(delStmt)
                }
                sqlite3_finalize(delStmt)
            }

            if let path = item.filePath, !path.isEmpty {
                let deleteSql = "DELETE FROM listening_history WHERE file_path = ?;"
                var delStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, deleteSql, -1, &delStmt, nil) == SQLITE_OK {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    sqlite3_bind_text(delStmt, 1, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    sqlite3_step(delStmt)
                }
                sqlite3_finalize(delStmt)
            }

            let titleArtistDelSql = "DELETE FROM listening_history WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND LOWER(TRIM(artist)) = LOWER(TRIM(?));"
            var titleDelStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, titleArtistDelSql, -1, &titleDelStmt, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(titleDelStmt, 1, (item.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(titleDelStmt, 2, (item.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_step(titleDelStmt)
            }
            sqlite3_finalize(titleDelStmt)

            // 2. Insert fresh unique record with updated played_at timestamp
            let sql = """
            INSERT INTO listening_history (id, title, artist, album, artwork_url, yt_video_id, file_path, played_at, duration, source_type)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, 1, (item.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, (item.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, (item.artist as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, (item.album as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 5, (item.artworkUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let vid = item.ytVideoId, !vid.isEmpty {
                    sqlite3_bind_text(stmt, 6, (vid as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                if let path = item.filePath, !path.isEmpty {
                    sqlite3_bind_text(stmt, 7, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                sqlite3_bind_double(stmt, 8, item.playedAt)
                sqlite3_bind_double(stmt, 9, item.duration)
                sqlite3_bind_text(stmt, 10, (item.sourceType as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func fetchHistory(limit: Int = 200, offset: Int = 0) -> [HistoryRecord] {
        var results: [HistoryRecord] = []
        dbQueue.sync {
            guard let db = db else { return }
            let sql = """
            SELECT id, title, artist, album, artwork_url, yt_video_id, file_path, played_at, duration, source_type
            FROM listening_history
            WHERE id IN (
                SELECT id FROM (
                    SELECT id, MAX(played_at) as max_played
                    FROM listening_history
                    GROUP BY CASE 
                        WHEN yt_video_id IS NOT NULL AND yt_video_id != '' THEN yt_video_id
                        WHEN file_path IS NOT NULL AND file_path != '' THEN file_path
                        ELSE LOWER(TRIM(title)) || '|||' || LOWER(TRIM(artist))
                    END
                )
            )
            ORDER BY played_at DESC
            LIMIT ? OFFSET ?;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                sqlite3_bind_int(stmt, 2, Int32(offset))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))
                    let artist = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let album = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                    let artworkUrl = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                    let ytVideoId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let filePath = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                    let playedAt = sqlite3_column_double(stmt, 7)
                    let duration = sqlite3_column_double(stmt, 8)
                    let sourceType = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? "online"

                    results.append(HistoryRecord(
                        id: id,
                        title: title,
                        artist: artist,
                        album: album,
                        artworkUrl: artworkUrl,
                        ytVideoId: ytVideoId,
                        filePath: filePath,
                        playedAt: playedAt,
                        duration: duration,
                        sourceType: sourceType
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }

    public func fetchHistoryCount() -> Int {
        var count = 0
        dbQueue.sync {
            guard let db = db else { return }
            let sql = """
            SELECT COUNT(DISTINCT CASE 
                WHEN yt_video_id IS NOT NULL AND yt_video_id != '' THEN yt_video_id
                WHEN file_path IS NOT NULL AND file_path != '' THEN file_path
                ELSE LOWER(TRIM(title)) || '|||' || LOWER(TRIM(artist))
            END) FROM listening_history;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
        }
        return count
    }

    @discardableResult
    public func deleteHistoryItem(id: String) -> Bool {
        var success = false
        dbQueue.sync {
            guard let db = db else { return }
            let sql = "DELETE FROM listening_history WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_DONE {
                    success = true
                }
            }
            sqlite3_finalize(stmt)
        }
        return success
    }

    @discardableResult
    public func clearHistory() -> Bool {
        var success = false
        dbQueue.sync {
            success = executeRaw(sql: "DELETE FROM listening_history;")
        }
        return success
    }
}
