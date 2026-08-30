import AppKit
import Foundation
import AVFoundation

public final class LocalLibraryManager: NSObject {
    public static let shared = LocalLibraryManager()

    // MARK: - Thread-Safe State
    private var _allTracks: [LocalTrack] = []
    private let stateLock = NSLock()

    public var allTracks: [LocalTrack] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _allTracks
    }

    // MARK: - Scan Coordination & Coalescing
    private let scanLock = NSLock()
    private var isScanningInProgress: Bool = false
    private var hasPendingScanRequest: Bool = false
    private var activeCompletions: [([LocalTrack]) -> Void] = []
    private var pendingCompletions: [([LocalTrack]) -> Void] = []
    private var scanGeneration: UInt64 = 0
    private var committedGeneration: UInt64 = 0

    public var isScanning: Bool {
        scanLock.lock()
        defer { scanLock.unlock() }
        return isScanningInProgress
    }

    public var onLibraryUpdated: (([LocalTrack]) -> Void)?

    private let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "aiff", "aif", "ogg", "opus"]
    private let queue = DispatchQueue(label: "com.mooziac.locallibrary", qos: .userInitiated)

    public var musicFolderURL: URL {
        if let custom = UserDefaults.standard.string(forKey: "YTM_downloadsFolder"), !custom.isEmpty {
            let folder = URL(fileURLWithPath: custom, isDirectory: true)
            if !FileManager.default.fileExists(atPath: folder.path) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            return folder
        }
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let folder = musicDir.appendingPathComponent("Mooziac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    public var defaultMusicFolderURL: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        return musicDir.appendingPathComponent("Mooziac", isDirectory: true)
    }

    public func setMusicFolder(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        UserDefaults.standard.set(url.path, forKey: "YTM_downloadsFolder")
        scanLibrary()
    }

    public func resetMusicFolderToDefault() {
        UserDefaults.standard.removeObject(forKey: "YTM_downloadsFolder")
        scanLibrary()
    }

    public var appSupportOfflineURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let folder = appSupport.appendingPathComponent("Mooziac/Offline", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private override init() {
        super.init()
        ensureDirectoriesExist()
        scanLibrary()
    }

    public func ensureDirectoriesExist() {
        _ = musicFolderURL
        _ = appSupportOfflineURL
    }

    // MARK: - Coalesced & Thread-Safe Scan Library
    public func scanLibrary(completion: (([LocalTrack]) -> Void)? = nil) {
        scanLock.lock()
        if let completion = completion {
            if isScanningInProgress {
                pendingCompletions.append(completion)
            } else {
                activeCompletions.append(completion)
            }
        }

        if isScanningInProgress {
            hasPendingScanRequest = true
            scanLock.unlock()
            return
        }

        isScanningInProgress = true
        scanGeneration += 1
        let currentGen = scanGeneration
        scanLock.unlock()

        performScan(generation: currentGen)
    }

    private func performScan(generation: UInt64) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let foundTracks = self.enumerateFilesystemTracks()

            var completionsToFire: [([LocalTrack]) -> Void] = []
            var shouldRunNextScan = false
            var nextGeneration: UInt64 = 0

            self.scanLock.lock()
            if generation >= self.committedGeneration {
                self.committedGeneration = generation
                self.stateLock.lock()
                self._allTracks = foundTracks
                self.stateLock.unlock()
            }

            completionsToFire = self.activeCompletions
            self.activeCompletions = []

            if self.hasPendingScanRequest {
                self.hasPendingScanRequest = false
                self.activeCompletions = self.pendingCompletions
                self.pendingCompletions = []
                self.scanGeneration += 1
                nextGeneration = self.scanGeneration
                shouldRunNextScan = true
            } else {
                self.isScanningInProgress = false
            }
            self.scanLock.unlock()

            DispatchQueue.main.async {
                self.onLibraryUpdated?(foundTracks)
                NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: foundTracks)

                if !foundTracks.isEmpty && !NetworkMonitor.shared.isReachable {
                    if NativeAudioPlayer.shared.currentTrack == nil {
                        NativeAudioPlayer.shared.primeLastOrFirstTrack()
                    }
                }

                for comp in completionsToFire {
                    comp(foundTracks)
                }
            }

            if shouldRunNextScan {
                self.performScan(generation: nextGeneration)
            }
        }
    }

    // MARK: - Filesystem Reconciliation with Persistent SQLite Cache
    private func enumerateFilesystemTracks() -> [LocalTrack] {
        // 1. Fetch current SQLite cached metadata map and run one-time migration if needed
        let cachedRecords = LocalDatabaseManager.shared.fetchAllRecords()
        LocalDatabaseManager.shared.migrateLikedKeysFromUserDefaultsIfNeeded()

        var foundTracks: [LocalTrack] = []
        var foundPaths = Set<String>()
        var recordsToUpsert: [CachedTrackRecord] = []

        let searchDirs = [self.musicFolderURL, self.appSupportOfflineURL]

        for dir in searchDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard self.supportedExtensions.contains(ext) else { continue }
                let filePath = fileURL.path
                guard !filePath.contains("/.downloading/"), !foundPaths.contains(filePath) else { continue }

                // Safe check: verify regular file still exists
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true else {
                    continue
                }

                foundPaths.insert(filePath)

                let fileModDate = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0.0
                let fileSize = Int64(resourceValues.fileSize ?? 0)

                // 2. Reconciliation: check if unchanged in SQLite cache
                if let cached = cachedRecords[filePath],
                   abs(cached.dateModified - fileModDate) < 0.001,
                   cached.fileSize == fileSize {
                    // UNCHANGED: Instant reuse from SQLite! 0 AVURLAsset calls!
                    foundTracks.append(cached.toLocalTrack())
                } else {
                    // NEW OR MODIFIED: Extract metadata via AVURLAsset & prepare SQLite upsert
                    let isLiked = cachedRecords[filePath]?.isLiked ?? LocalDatabaseManager.shared.isLiked(filePath: filePath)
                    let ytVideoId = cachedRecords[filePath]?.ytVideoId
                    let track = self.extractMetadata(from: fileURL, isLiked: isLiked, ytVideoId: ytVideoId)
                    foundTracks.append(track)

                    let rec = CachedTrackRecord(
                        id: track.id,
                        filePath: track.fileURL.path,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: track.duration,
                        dateAdded: track.dateAdded.timeIntervalSince1970,
                        dateModified: fileModDate,
                        fileSize: fileSize,
                        isLiked: track.isLiked,
                        lrcPath: track.lrcURL?.path,
                        ytVideoId: track.ytVideoId
                    )
                    recordsToUpsert.append(rec)
                }
            }
        }

        // 3. Identify Stale Records in SQLite (files deleted externally in Finder)
        let stalePaths = cachedRecords.keys.filter { !foundPaths.contains($0) }
        if !stalePaths.isEmpty {
            LocalDatabaseManager.shared.deleteTracks(filePaths: Array(stalePaths))
        }

        // 4. Commit new / modified records to SQLite in a single transaction
        if !recordsToUpsert.isEmpty {
            LocalDatabaseManager.shared.upsertTracks(recordsToUpsert)
        }

        // 5. Deduplicate tracks by normalized title and artist signature
        var seenSignatures = Set<String>()
        var deduplicatedTracks: [LocalTrack] = []

        for track in foundTracks {
            let cleanT = LyricsManager.cleanSongInfo(track.title).lowercased()
            let cleanA = LyricsManager.cleanSongInfo(track.artist).lowercased()
            let signature = "\(cleanT)|\(cleanA)"

            if !seenSignatures.contains(signature) {
                seenSignatures.insert(signature)
                deduplicatedTracks.append(track)
            }
        }

        // 6. Sort newest first
        deduplicatedTracks.sort { $0.dateAdded > $1.dateAdded }
        return deduplicatedTracks
    }

    // MARK: - Metadata Extraction
    private func extractMetadata(from fileURL: URL, isLiked: Bool, ytVideoId: String? = nil) -> LocalTrack {
        var title = ""
        var artist = ""
        var album = ""
        var duration: Double = 0.0

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let asset = AVURLAsset(url: fileURL)
            let durationSeconds = CMTimeGetSeconds(asset.duration)

            if !durationSeconds.isNaN &&
               !durationSeconds.isInfinite {
                duration = durationSeconds
            }

            let metadata = asset.commonMetadata

            for item in metadata {
                guard let commonKey = item.commonKey else { continue }

                switch commonKey {
                case .commonKeyTitle:
                    title = item.stringValue ?? ""
                case .commonKeyArtist:
                    artist = item.stringValue ?? ""
                case .commonKeyAlbumName:
                    album = item.stringValue ?? ""
                default:
                    break
                }
            }
        }

        // Fallback title from filename
        if title.isEmpty {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            if filename.contains(" - ") {
                let parts = filename.components(separatedBy: " - ")
                if parts.count >= 2 {
                    artist = parts[0].trimmingCharacters(in: .whitespaces)
                    title = parts[1].trimmingCharacters(in: .whitespaces)
                } else {
                    title = filename
                }
            } else {
                title = filename
            }
        }

        if artist.isEmpty {
            artist = "Local Audio"
        }

        // Check for sidecar .lrc file
        let lrcSidecar = fileURL.deletingPathExtension().appendingPathExtension("lrc")
        let lrcURL = FileManager.default.fileExists(atPath: lrcSidecar.path) ? lrcSidecar : nil

        // Check for sidecar artwork image file (.jpg, .png, .jpeg, .webp)
        var artworkURL: URL? = nil
        for ext in ["jpg", "png", "jpeg", "webp"] {
            let imgSidecar = fileURL.deletingPathExtension().appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: imgSidecar.path) {
                artworkURL = imgSidecar
                break
            }
        }

        let dateAdded = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let trackID = fileURL.path

        return LocalTrack(
            id: trackID,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileURL: fileURL,
            artwork: nil,
            artworkURL: artworkURL,
            lrcURL: lrcURL,
            isLiked: isLiked,
            dateAdded: dateAdded,
            ytVideoId: ytVideoId
        )
    }

    // MARK: - yt_video_id Assignment (called after a download is finalized)
    public func assignYTVideoID(_ videoId: String, toFileAt path: String) {
        guard !videoId.isEmpty else { return }
        LocalDatabaseManager.shared.setYTVideoID(videoId, for: path)

        stateLock.lock()
        for i in 0..<_allTracks.count {
            if _allTracks[i].fileURL.path == path || _allTracks[i].id == path {
                _allTracks[i].ytVideoId = videoId
            }
        }
        let snapshot = _allTracks
        stateLock.unlock()

        DispatchQueue.main.async {
            self.onLibraryUpdated?(snapshot)
        }
    }

    // MARK: - Thread-Safe Sub-millisecond Search (<0.5ms)
    public func search(query: String) -> [LocalTrack] {
        let snapshot = allTracks // Thread-safe snapshot under stateLock
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return snapshot }

        return snapshot.filter { track in
            track.title.lowercased().contains(trimmed) ||
            track.artist.lowercased().contains(trimmed) ||
            track.album.lowercased().contains(trimmed)
        }
    }

    // MARK: - Import Files
    public func importFiles(from sourceURLs: [URL], completion: @escaping (Int) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var importedCount = 0
            let destFolder = self.musicFolderURL

            for src in sourceURLs {
                let ext = src.pathExtension.lowercased()
                guard self.supportedExtensions.contains(ext) || ext == "lrc" else { continue }

                let targetURL = destFolder.appendingPathComponent(src.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: src, to: targetURL)
                    if ext != "lrc" { importedCount += 1 }
                } catch {
                    print("[LocalLibraryManager] Error copying \(src.lastPathComponent): \(error)")
                }
            }

            self.scanLibrary { tracks in
                completion(importedCount)
            }
        }
    }

    // MARK: - Toggle Favorite / Like
    public func toggleLike(for trackID: String) {
        let currentLiked = LocalDatabaseManager.shared.isLiked(filePath: trackID)
        let isNowLiked = !currentLiked
        LocalDatabaseManager.shared.setLiked(filePath: trackID, isLiked: isNowLiked)

        // Update in-memory snapshot
        stateLock.lock()
        for i in 0..<_allTracks.count {
            if _allTracks[i].id == trackID || _allTracks[i].fileURL.path == trackID {
                _allTracks[i].isLiked = isNowLiked
            }
        }
        let snapshot = _allTracks
        stateLock.unlock()

        // Synchronize active track in NativeAudioPlayer if playing this track
        if NativeAudioPlayer.shared.currentTrack?.id == trackID {
            NativeAudioPlayer.shared.updateLikedState(isLiked: isNowLiked)
        }

        DispatchQueue.main.async {
            self.onLibraryUpdated?(snapshot)
        }
    }

    public func isLiked(trackID: String) -> Bool {
        return LocalDatabaseManager.shared.isLiked(filePath: trackID)
    }

    // MARK: - Open Folder in Finder
    public func openMusicFolderInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: musicFolderURL.path)
    }

    // MARK: - Delete Track
    public func deleteTrack(_ track: LocalTrack, completion: ((Bool) -> Void)? = nil) {
        // 1. Safely handle player/queue updates on main thread first if this track is active/queued
        DispatchQueue.main.async {
            NativeAudioPlayer.shared.handleTrackDeleted(trackID: track.id)
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                // 2. Remove audio file if exists
                if FileManager.default.fileExists(atPath: track.fileURL.path) {
                    try FileManager.default.removeItem(at: track.fileURL)
                }

                // 3. Remove sidecar .lrc if exists
                let lrcSidecar = track.lrcURL ?? track.fileURL.deletingPathExtension().appendingPathExtension("lrc")
                if FileManager.default.fileExists(atPath: lrcSidecar.path) {
                    try? FileManager.default.removeItem(at: lrcSidecar)
                }

                // 4. Remove record from SQLite
                LocalDatabaseManager.shared.deleteTracks(filePaths: [track.fileURL.path])

                // 5. Clean uniquely associated artwork cache
                AppArtworkHelper.shared.removeCachedThumbnails(for: track)

                // 6. Rescan library and notify
                self.scanLibrary { _ in
                    DispatchQueue.main.async {
                        completion?(true)
                    }
                }
            } catch {
                print("[LocalLibraryManager] Failed to delete track: \(error)")
                LocalDatabaseManager.shared.deleteTracks(filePaths: [track.fileURL.path])
                AppArtworkHelper.shared.removeCachedThumbnails(for: track)
                self.scanLibrary { _ in
                    DispatchQueue.main.async {
                        completion?(false)
                    }
                }
            }
        }
    }
}
