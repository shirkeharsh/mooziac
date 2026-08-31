import AppKit
import Foundation
import AVFoundation
import Darwin

public enum DownloadStatus: Equatable {
    case queued
    case downloading(progress: Double, eta: String, speed: String)
    case completed
    case failed(String)
}

public struct DownloadProgressInfo {
    public let id: String
    public let videoId: String?
    public let title: String
    public let artist: String
    public let progress: Double
    public let eta: String
    public let speed: String
    public let status: DownloadStatus
}

public final class DownloadManager: NSObject {
    public static let shared = DownloadManager()

    public static let progressNotification = NSNotification.Name("Mooziac_DownloadProgress")
    public static let queueNotification = NSNotification.Name("Mooziac_DownloadQueueChanged")

    public struct QueueTask {
        public let id: String
        public let urlOrVideoId: String
        public let title: String
        public let artist: String
        public let artworkUrl: String
        public var progress: Double = 0.0
        public var eta: String = ""
        public var speed: String = ""
        public var status: DownloadStatus = .queued
        public var completion: ((Bool, String) -> Void)?
    }

    public private(set) var isDownloading: Bool = false
    public private(set) var currentDownloadTitle: String = ""
    public private(set) var currentProgress: Double = 0.0
    public private(set) var currentETA: String = ""
    public private(set) var currentSpeed: String = ""
    public private(set) var currentItemCountInBatch: Int = 0
    public private(set) var totalBatchCount: Int = 0

    public var remainingQueueCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return tasksQueue.count + (activeTask != nil ? 1 : 0)
    }

    public var onDownloadStatusChanged: ((Bool, String) -> Void)?
    public var onProgressUpdated: ((DownloadProgressInfo) -> Void)?

    private let workQueue = DispatchQueue(label: "com.mooziac.downloader.work", qos: .userInitiated)
    private let timeoutQueue = DispatchQueue(label: "com.mooziac.downloader.timeout", qos: .utility)
    private let queueLock = NSLock()
    private var tasksQueue: [QueueTask] = []
    private var activeTask: QueueTask?
    private var currentActiveJobDirURL: URL?
    private var lastProgressNotificationTime: TimeInterval = 0
    private var lastBroadcastProgress: Double = -1.0

    private static let downloadTimeout: TimeInterval = 1200
    private var activeProcess: Process?
    private var ytDlpPath: String?
    private var cancelledTaskIDs = Set<String>()

    public var downloadingBaseURL: URL {
        let musicDir = LocalLibraryManager.shared.musicFolderURL
        let folder = musicDir.appendingPathComponent(".downloading", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private override init() {
        super.init()
        cleanupStaleDownloads()
        observeQueueChanges()
    }

    private func observeQueueChanges() {
        NotificationCenter.default.addObserver(
            forName: DownloadManager.queueNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistQueue()
        }
    }

    private func persistQueue() {
        queueLock.lock()
        var snapshot: [QueueTask] = tasksQueue
        if let active = activeTask {
            snapshot.append(active)
        }
        queueLock.unlock()

        let jobs = snapshot.compactMap { task -> PersistedDownloadJob? in
            let videoId = DownloadManager.extractVideoID(from: task.urlOrVideoId)
            guard let videoId = videoId, !videoId.isEmpty else { return nil }
            return PersistedDownloadJob(
                taskID: task.id,
                ytVideoId: videoId,
                title: task.title,
                artist: task.artist,
                artworkUrl: task.artworkUrl,
                queuedAt: Date()
            )
        }

        if jobs.isEmpty {
            DownloadQueuePersistence.clear()
        } else {
            DownloadQueuePersistence.save(jobs)
        }
    }

    public func resumePendingDownloadsFromDisk() {
        let jobs = DownloadQueuePersistence.load()
        guard !jobs.isEmpty else { return }

        for job in jobs {
            queueTrack(
                id: job.taskID,
                urlOrVideoId: job.ytVideoId,
                title: job.title,
                artist: job.artist,
                artworkUrl: job.artworkUrl
            )
        }

        print(
            "[DownloadManager] Resumed \(jobs.count) pending download(s) from previous session."
        )
    }

    // MARK: - Startup Stale Downloads Cleanup
    public func cleanupStaleDownloads() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let baseDir = self.downloadingBaseURL
            guard FileManager.default.fileExists(atPath: baseDir.path) else { return }

            if let subdirs = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) {
                for dir in subdirs {
                    if dir != self.currentActiveJobDirURL {
                        try? FileManager.default.removeItem(at: dir)
                        print("[DownloadManager] Cleaned stale download sandbox: \(dir.lastPathComponent)")
                    }
                }
            }
        }
    }

    // MARK: - Queue Inspection
    public func statusFor(id: String, videoId: String? = nil) -> DownloadProgressInfo? {
        queueLock.lock()
        defer { queueLock.unlock() }

        if let active = activeTask, active.id == id || (videoId != nil && active.urlOrVideoId.contains(videoId!)) {
            return DownloadProgressInfo(
                id: active.id,
                videoId: videoId,
                title: active.title,
                artist: active.artist,
                progress: active.progress,
                eta: active.eta,
                speed: active.speed,
                status: active.status
            )
        }

        if let queued = tasksQueue.first(where: { $0.id == id || (videoId != nil && $0.urlOrVideoId.contains(videoId!)) }) {
            return DownloadProgressInfo(
                id: queued.id,
                videoId: videoId,
                title: queued.title,
                artist: queued.artist,
                progress: 0.0,
                eta: "",
                speed: "",
                status: .queued
            )
        }

        return nil
    }

    // MARK: - Single Track Download (Queued)
    public func downloadTrack(
        urlOrVideoId: String,
        title: String,
        artist: String,
        artworkUrl: String = "",
        completion: @escaping (Bool, String) -> Void
    ) {
        queueTrack(
            id: UUID().uuidString,
            urlOrVideoId: urlOrVideoId,
            title: title,
            artist: artist,
            artworkUrl: artworkUrl,
            completion: completion
        )
    }

    public func queueTrack(
        id: String,
        urlOrVideoId: String,
        title: String,
        artist: String,
        artworkUrl: String = "",
        completion: ((Bool, String) -> Void)? = nil
    ) {
        let cleanT = LyricsManager.cleanSongInfo(title)
        let cleanA = LyricsManager.cleanSongInfo(artist)
        let videoId = DownloadManager.extractVideoID(from: urlOrVideoId)

        // Check if already in library
        let alreadyExists = LocalLibraryManager.shared.allTracks.contains(where: { track in
            if let vid = videoId, let trackVid = track.ytVideoId, !trackVid.isEmpty, trackVid == vid {
                return true
            }
            let matchTitle = track.title.lowercased() == cleanT.lowercased() || track.cleanTitle.lowercased() == cleanT.lowercased()
            let matchArtist = cleanA.isEmpty || track.artist.lowercased() == cleanA.lowercased() || track.cleanArtist.lowercased() == cleanA.lowercased()
            return matchTitle && (cleanA.isEmpty || matchArtist)
        })

        if alreadyExists {
            DispatchQueue.main.async {
                self.broadcastProgress(id: id, videoId: videoId, title: cleanT, progress: 1.0, eta: "", speed: "", status: .completed)
                completion?(true, "Already in offline library")
            }
            return
        }

        queueLock.lock()
        // Check if already in queue or active
        if activeTask?.id == id || tasksQueue.contains(where: { $0.id == id }) {
            queueLock.unlock()
            return
        }

        let task = QueueTask(
            id: id,
            urlOrVideoId: urlOrVideoId,
            title: cleanT,
            artist: cleanA,
            artworkUrl: artworkUrl,
            completion: completion
        )
        tasksQueue.append(task)
        totalBatchCount = max(totalBatchCount, tasksQueue.count + (activeTask != nil ? 1 : 0))
        queueLock.unlock()

        DispatchQueue.main.async {
            self.broadcastProgress(id: id, videoId: videoId, title: cleanT, progress: 0.0, eta: "", speed: "", status: .queued)
            self.broadcastQueueStatus()
        }

        processNextQueueTask()
    }

    // MARK: - Batch Download
    public func queueTracks(_ tracks: [(id: String, urlOrVideoId: String, title: String, artist: String, artworkUrl: String)]) {
        guard !tracks.isEmpty else { return }

        // Build a library dedup index ONCE instead of scanning per track
        let library = LocalLibraryManager.shared.allTracks
        var existingVideoIds = Set<String>()
        var existingSignatures = Set<String>()
        for track in library {
            if let vid = track.ytVideoId, !vid.isEmpty {
                existingVideoIds.insert(vid)
            }
            existingSignatures.insert(DownloadManager.librarySignature(title: track.title, artist: track.artist))
        }

        queueLock.lock()
        var queuedIDs = Set<String>(tasksQueue.map { $0.id })
        if let active = activeTask {
            queuedIDs.insert(active.id)
        }
        var newlyQueuedCount = 0

        for t in tracks {
            let cleanT = LyricsManager.cleanSongInfo(t.title)
            let cleanA = LyricsManager.cleanSongInfo(t.artist)
            let videoId = DownloadManager.extractVideoID(from: t.urlOrVideoId)

            var isDuplicate = false
            if let vid = videoId, existingVideoIds.contains(vid) {
                isDuplicate = true
            } else if existingSignatures.contains(DownloadManager.librarySignature(title: cleanT, artist: cleanA)) {
                isDuplicate = true
            } else if queuedIDs.contains(t.id) {
                isDuplicate = true
            }

            if isDuplicate {
                DispatchQueue.main.async {
                    self.broadcastProgress(id: t.id, videoId: videoId, title: cleanT, progress: 1.0, eta: "", speed: "", status: .completed)
                }
                continue
            }

            let task = QueueTask(
                id: t.id,
                urlOrVideoId: t.urlOrVideoId,
                title: cleanT,
                artist: cleanA,
                artworkUrl: t.artworkUrl
            )
            tasksQueue.append(task)
            queuedIDs.insert(t.id)
            newlyQueuedCount += 1

            DispatchQueue.main.async {
                self.broadcastProgress(id: t.id, videoId: videoId, title: cleanT, progress: 0.0, eta: "", speed: "", status: .queued)
            }
        }
        totalBatchCount = max(totalBatchCount, tasksQueue.count + (activeTask != nil ? 1 : 0))
        queueLock.unlock()

        DispatchQueue.main.async {
            self.broadcastQueueStatus()
        }

        if newlyQueuedCount > 0 {
            processNextQueueTask()
        }
    }

    private static func librarySignature(title: String, artist: String) -> String {
        let cleanT = LyricsManager.cleanSongInfo(title).lowercased()
        let cleanA = LyricsManager.cleanSongInfo(artist).lowercased()
        return "\(cleanT)|\(cleanA)"
    }

    // MARK: - Queue Worker
    private func processNextQueueTask() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            self.queueLock.lock()
            if self.activeTask != nil {
                self.queueLock.unlock()
                return
            }

            guard !self.tasksQueue.isEmpty else {
                self.queueLock.unlock()
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.currentDownloadTitle = ""
                    self.currentProgress = 0.0
                    self.currentETA = ""
                    self.currentSpeed = ""
                    self.totalBatchCount = 0
                    self.currentItemCountInBatch = 0
                    self.lastBroadcastProgress = -1.0
                    self.onDownloadStatusChanged?(false, "")
                    self.broadcastQueueStatus()
                }
                return
            }

            var nextTask = self.tasksQueue.removeFirst()
            nextTask.status = .downloading(progress: 0.0, eta: "", speed: "")
            self.activeTask = nextTask
            self.currentItemCountInBatch += 1
            self.queueLock.unlock()

            self.scheduleTimeout(for: nextTask)
            self.executeDownloadTask(task: nextTask)
        }
    }

    private func scheduleTimeout(for task: QueueTask) {
        timeoutQueue.asyncAfter(deadline: .now() + DownloadManager.downloadTimeout) { [weak self] in
            self?.handleTaskTimeout(taskID: task.id)
        }
    }

    private func handleTaskTimeout(taskID: String) {
        queueLock.lock()
        let isActive = activeTask?.id == taskID
        let process = activeProcess
        queueLock.unlock()
        guard isActive, let process = process else { return }

        print("[DownloadManager] Download timed out after \(Int(DownloadManager.downloadTimeout))s, terminating yt-dlp")
        let pid = process.processIdentifier
        kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    // MARK: - Execute Download
    private func executeDownloadTask(task: QueueTask) {
        let cleanT = task.title
        let cleanA = task.artist
        let videoId = DownloadManager.extractVideoID(from: task.urlOrVideoId)

        let targetQuery: String
        if task.urlOrVideoId.hasPrefix("http://") || task.urlOrVideoId.hasPrefix("https://") {
            if task.urlOrVideoId.contains("watch?v=") || task.urlOrVideoId.contains("youtu.be/") {
                targetQuery = task.urlOrVideoId
            } else if !cleanT.isEmpty {
                targetQuery = "ytsearch1:\(cleanA) - \(cleanT)"
            } else {
                targetQuery = task.urlOrVideoId
            }
        } else if !task.urlOrVideoId.isEmpty && !task.urlOrVideoId.contains(" ") && task.urlOrVideoId.count == 11 {
            targetQuery = "https://music.youtube.com/watch?v=\(task.urlOrVideoId)"
        } else if !cleanT.isEmpty {
            targetQuery = "ytsearch1:\(cleanA) - \(cleanT)"
        } else {
            finishTask(task: task, success: false, message: "Invalid track query")
            return
        }

        DispatchQueue.main.async {
            self.isDownloading = true
            self.currentDownloadTitle = cleanT
            self.currentProgress = 0.0
            self.currentETA = ""
            self.currentSpeed = ""
            self.lastBroadcastProgress = -1.0
            self.onDownloadStatusChanged?(true, "Downloading \(cleanT)...")
            self.broadcastProgress(id: task.id, videoId: videoId, title: cleanT, progress: 0.05, eta: "", speed: "", status: .downloading(progress: 0.05, eta: "", speed: ""))
            self.broadcastQueueStatus()
        }

        let musicDir = LocalLibraryManager.shared.musicFolderURL
        let safeFilename = "\(cleanA.isEmpty ? "Unknown" : cleanA) - \(cleanT.isEmpty ? "Track" : cleanT)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        // 1. Create Isolated Temporary Sandbox Job Directory
        let jobId = UUID().uuidString
        let jobDir = self.downloadingBaseURL.appendingPathComponent(jobId, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: jobDir, withIntermediateDirectories: true)
        } catch {
            finishTask(task: task, success: false, message: "Failed to create sandbox")
            return
        }

        self.currentActiveJobDirURL = jobDir
        let outputTemplate = jobDir.appendingPathComponent("\(safeFilename).%(ext)s").path

        let process = Process()
        guard let ytDlpExecutable = resolveYtDlpPath() else {
            self.onDownloadStatusChanged?(true, "Setting up helper...")
            self.broadcastProgress(id: task.id, videoId: videoId, title: cleanT, progress: 0.05, eta: "", speed: "Installing helper...", status: .downloading(progress: 0.05, eta: "", speed: "Installing helper..."))
            
            DependencyManager.shared.installHelper(progress: { [weak self] pct in
                self?.broadcastProgress(id: task.id, videoId: videoId, title: cleanT, progress: pct, eta: "", speed: "\(Int(pct * 100))%", status: .downloading(progress: pct, eta: "", speed: "Helper Setup"))
            }) { [weak self] success, error in
                guard let self = self else { return }
                if success, self.resolveYtDlpPath() != nil {
                    self.executeDownloadTask(task: task)
                } else {
                    self.cleanupJobDir(jobDir)
                    self.finishTask(task: task, success: false, message: error ?? "Helper installation failed")
                }
            }
            return
        }

        process.executableURL = URL(fileURLWithPath: ytDlpExecutable)
        var arguments = [
            "--newline",
            "--no-update",
            "--extractor-args", "youtube:player_client=mweb,web_safari,tv_embedded,web",
            "--no-playlist"
        ]
        if let ffmpegLoc = resolveFFmpegLocation() {
            arguments.append(contentsOf: [
                "-x",
                "--audio-format", "m4a",
                "--audio-quality", "0",
                "--embed-thumbnail",
                "--embed-metadata",
                "--ffmpeg-location", ffmpegLoc
            ])
        } else {
            arguments.append(contentsOf: [
                "-f", "ba[ext=m4a]/ba/b"
            ])
        }
        arguments.append(contentsOf: ["-o", outputTemplate, targetQuery])
        process.arguments = arguments
        process.environment = DownloadManager.makeProcessEnvironment()

        queueLock.lock()
        self.activeProcess = process
        queueLock.unlock()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        var outputBuffer = ""
        var allOutputLines: [String] = []

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            outputBuffer += chunk
            let lines = outputBuffer.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
            if lines.count > 1 {
                outputBuffer = lines.last ?? ""
                for line in lines.dropLast() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        allOutputLines.append(trimmed)
                    }
                    if let (pct, eta, spd) = DownloadManager.parseYtDlpProgress(line: line) {
                        self.handleStreamingProgress(taskID: task.id, videoId: videoId, title: cleanT, progress: pct, eta: eta, speed: spd)
                    }
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil

            queueLock.lock()
            let isCancelled = cancelledTaskIDs.contains(task.id) || (activeTask?.id != task.id)
            cancelledTaskIDs.remove(task.id)
            if self.activeProcess === process {
                self.activeProcess = nil
            }
            queueLock.unlock()

            if isCancelled || process.terminationStatus == 15 || process.terminationStatus == -15 {
                cleanupJobDir(jobDir)
                finishTask(task: task, success: false, message: "Download cancelled")
                return
            }

            let success = (process.terminationStatus == 0)
            guard success else {
                cleanupJobDir(jobDir)
                let errorMsg = DownloadManager.extractErrorMessage(from: allOutputLines) ?? "Download failed. Check connection."
                print("[DownloadManager] yt-dlp failed (exit code \(process.terminationStatus)): \(errorMsg)")
                for l in allOutputLines.suffix(15) {
                    print("[DownloadManager | yt-dlp] \(l)")
                }
                finishTask(task: task, success: false, message: errorMsg)
                return
            }

            // 2. Validate Resulting Audio File in Job Sandbox
            guard let validatedAudioURL = self.validateJobAudioFile(in: jobDir) else {
                cleanupJobDir(jobDir)
                finishTask(task: task, success: false, message: "Downloaded file corrupted or invalid")
                return
            }

            // 3. Stage Artwork
            let tempArtworkURL = jobDir.appendingPathComponent("\(safeFilename).jpg")
            if !task.artworkUrl.isEmpty, let artURL = URL(string: task.artworkUrl), artURL.scheme?.hasPrefix("http") == true {
                if let imgData = try? Data(contentsOf: artURL), !imgData.isEmpty {
                    try? imgData.write(to: tempArtworkURL, options: .atomic)
                }
            }

            // 4. Finalize to ~/Music/Mooziac/
            let finalAudioURL = musicDir.appendingPathComponent("\(safeFilename).\(validatedAudioURL.pathExtension)")
            let finalLrcURL = musicDir.appendingPathComponent("\(safeFilename).lrc")
            let finalArtworkURL = musicDir.appendingPathComponent("\(safeFilename).jpg")

            do {
                if FileManager.default.fileExists(atPath: finalAudioURL.path) {
                    try FileManager.default.removeItem(at: finalAudioURL)
                }
                try FileManager.default.moveItem(at: validatedAudioURL, to: finalAudioURL)

                if FileManager.default.fileExists(atPath: tempArtworkURL.path) {
                    if FileManager.default.fileExists(atPath: finalArtworkURL.path) {
                        try? FileManager.default.removeItem(at: finalArtworkURL)
                    }
                    try? FileManager.default.moveItem(at: tempArtworkURL, to: finalArtworkURL)
                }
            } catch {
                cleanupJobDir(jobDir)
                finishTask(task: task, success: false, message: "Failed to save audio file")
                return
            }

            cleanupJobDir(jobDir)

            // 5. Fetch synced lyrics in the background (non-blocking) directly to the final path
            if !cleanT.isEmpty {
                LyricsManager.shared.fetchRawSyncedLRC(artist: cleanA, title: cleanT) { lrc in
                    guard let lrc = lrc, !lrc.isEmpty else { return }
                    DispatchQueue.global(qos: .utility).async {
                        if FileManager.default.fileExists(atPath: finalLrcURL.path) {
                            try? FileManager.default.removeItem(at: finalLrcURL)
                        }
                        try? lrc.write(to: finalLrcURL, atomically: true, encoding: .utf8)
                    }
                }
            }

            // 6. Rescan the library and assign yt_video_id immediately so playlist views and local library resolve the track as downloaded
            LocalLibraryManager.shared.scanLibrary { _ in
                if let vid = videoId {
                    LocalLibraryManager.shared.assignYTVideoID(vid, toFileAt: finalAudioURL.path)
                }
                self.finishTask(task: task, success: true, message: "✓ Downloaded \(cleanT)", resultDetail: "Saved to ~/Music/Mooziac")
            }
        } catch {
            cleanupJobDir(jobDir)
            queueLock.lock()
            self.activeProcess = nil
            queueLock.unlock()
            finishTask(task: task, success: false, message: "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Streaming Progress Handler
    private func handleStreamingProgress(taskID: String, videoId: String?, title: String, progress: Double, eta: String, speed: String) {
        let now = Date().timeIntervalSince1970

        queueLock.lock()

        let elapsedOK =
            now - lastProgressNotificationTime >= 0.08 ||
            progress >= 0.99

        let deltaOK =
            abs(progress - lastBroadcastProgress) >= 0.02 ||
            progress >= 0.99 ||
            lastBroadcastProgress < 0

        if elapsedOK && deltaOK {
            lastProgressNotificationTime = now
            lastBroadcastProgress = progress
        }

        queueLock.unlock()

        guard elapsedOK && deltaOK else { return }

        DispatchQueue.main.async {
            self.currentProgress = progress
            self.currentETA = eta
            self.currentSpeed = speed

            self.broadcastProgress(
                id: taskID,
                videoId: videoId,
                title: title,
                progress: progress,
                eta: eta,
                speed: speed,
                status: .downloading(progress: progress, eta: eta, speed: speed)
            )
            self.broadcastQueueStatus()
        }
    }

    // MARK: - Task Finalization
    private func finishTask(task: QueueTask, success: Bool, message: String, resultDetail: String? = nil) {
        let videoId = DownloadManager.extractVideoID(from: task.urlOrVideoId)

        // Idempotency guard: a task may be finalised by cancellation while the
        // worker is still unwinding, so only the first finalisation wins.
        queueLock.lock()
        guard activeTask?.id == task.id else {
            queueLock.unlock()
            return
        }
        queueLock.unlock()

        DispatchQueue.main.async {
            self.broadcastProgress(
                id: task.id,
                videoId: videoId,
                title: task.title,
                progress: success ? 1.0 : 0.0,
                eta: "",
                speed: "",
                status: success ? .completed : .failed(message)
            )

            task.completion?(success, resultDetail ?? message)

            self.queueLock.lock()
            self.activeTask = nil
            let queueEmpty = self.tasksQueue.isEmpty
            self.queueLock.unlock()

            if queueEmpty {
                self.isDownloading = false
                self.onDownloadStatusChanged?(false, "")
            }

            self.broadcastQueueStatus()
            self.processNextQueueTask()
        }
    }

    // MARK: - Progress & Queue Broadcasting
    private func broadcastProgress(id: String, videoId: String?, title: String, progress: Double, eta: String, speed: String, status: DownloadStatus) {
        let info = DownloadProgressInfo(
            id: id,
            videoId: videoId,
            title: title,
            artist: "",
            progress: progress,
            eta: eta,
            speed: speed,
            status: status
        )

        onProgressUpdated?(info)

        var userInfo: [String: Any] = [
            "id": id,
            "title": title,
            "progress": progress,
            "eta": eta,
            "speed": speed,
            "status": "\(status)"
        ]
        if let vid = videoId {
            userInfo["videoId"] = vid
        }

        NotificationCenter.default.post(name: DownloadManager.progressNotification, object: self, userInfo: userInfo)
    }

    private func broadcastQueueStatus() {
        let remaining = tasksQueue.count + (activeTask != nil ? 1 : 0)
        let total = totalBatchCount > 0 ? totalBatchCount : remaining
        let currentIdx = currentItemCountInBatch

        var queueText = ""
        if let active = activeTask {
            if total > 1 {
                let etaStr = active.eta.isEmpty ? "" : " • ETA \(active.eta)"
                queueText = "Downloading \(currentIdx)/\(total): \(active.title) (\(Int(active.progress * 100))%\(etaStr))"
            } else {
                let etaStr = active.eta.isEmpty ? "" : " • ETA \(active.eta)"
                queueText = "Downloading \(active.title) (\(Int(active.progress * 100))%\(etaStr))"
            }
        }

        NotificationCenter.default.post(
            name: DownloadManager.queueNotification,
            object: self,
            userInfo: [
                "activeTitle": currentDownloadTitle,
                "progress": currentProgress,
                "eta": currentETA,
                "speed": currentSpeed,
                "remaining": remaining,
                "total": total,
                "index": currentIdx,
                "displayText": queueText
            ]
        )
    }

    // MARK: - Process Environment & Tool Resolution
    public static func makeProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let standardCandidatePaths = [
            "\(home)/.local/bin",
            "\(home)/.pyenv/shims",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.cargo/bin",
            "/Library/Frameworks/Python.framework/Versions/Current/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let currentPath = env["PATH"] ?? ""
        let currentSegments = currentPath.components(separatedBy: ":")
        var combined: [String] = []
        for p in (standardCandidatePaths + currentSegments) where !p.isEmpty {
            if !combined.contains(p) {
                combined.append(p)
            }
        }
        env["PATH"] = combined.joined(separator: ":")
        env["PYTHONUNBUFFERED"] = "1"
        return env
    }

    private static func runShellPathResolution(_ cmd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", cmd]
        p.environment = DownloadManager.makeProcessEnvironment()
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if p.terminationStatus == 0, !str.isEmpty, FileManager.default.isExecutableFile(atPath: str) {
                return str
            }
        } catch {}
        return nil
    }

    private func resolveYtDlpPath() -> String? {
        if let cached = ytDlpPath, FileManager.default.isExecutableFile(atPath: cached) {
            return cached
        }

        // 0. Check Application Support / Mooziac helper location first
        let helperPath = DependencyManager.shared.ytDlpExecutableURL.path
        if FileManager.default.isExecutableFile(atPath: helperPath) {
            ytDlpPath = helperPath
            return helperPath
        }

        // 1. Try resolving via user login shell first (picks up pyenv/brew/pip envs)
        if let shellFound = DownloadManager.runShellPathResolution("command -v yt-dlp || which yt-dlp || command -v youtube-dl || which youtube-dl") {
            ytDlpPath = shellFound
            return shellFound
        }

        // 2. Direct candidate checks
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/yt-dlp",
            "\(home)/.pyenv/shims/yt-dlp",
            "/opt/homebrew/bin/yt-dlp",
            "/opt/homebrew/sbin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "\(home)/.cargo/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            "/opt/homebrew/bin/youtube-dl",
            "/usr/local/bin/youtube-dl"
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            ytDlpPath = c
            return c
        }

        return nil
    }

    private func resolveFFmpegLocation() -> String? {
        if let shellFound = DownloadManager.runShellPathResolution("command -v ffmpeg || which ffmpeg") {
            return URL(fileURLWithPath: shellFound).deletingLastPathComponent().path
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "/usr/bin"
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: "\(c)/ffmpeg") {
            return c
        }
        return nil
    }

    public static func extractErrorMessage(from lines: [String]) -> String? {
        let errorLines = lines.filter { line in
            let l = line.lowercased()
            // Ignore benign warnings and deprecation notices
            if line.contains("WARNING:") || line.contains("[youtube] WARNING") || line.contains("Deprecated Feature") {
                return false
            }
            return line.contains("ERROR:") || line.contains("[youtube] ERROR") || l.contains("ffmpeg is not installed")
        }
        if let lastErr = errorLines.last {
            var clean = lastErr
            if let r = clean.range(of: "ERROR:", options: .caseInsensitive) {
                clean = String(clean[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            if clean.contains("403: Forbidden") {
                return "Access forbidden (403). yt-dlp update recommended."
            }
            if clean.contains("Requested format is not available") {
                return "Audio format unavailable for this track."
            }
            if clean.contains("Sign in to confirm") || clean.contains("bot") {
                return "YouTube bot check triggered. Try again later."
            }
            if clean.contains("ffmpeg") {
                return "FFmpeg missing. Install via: brew install ffmpeg"
            }
            if !clean.isEmpty {
                return clean.count > 60 ? String(clean.prefix(57)) + "..." : clean
            }
        }
        return nil
    }

    // MARK: - Cancellation
    public func cancelQueuedTask(id: String) {
        queueLock.lock()
        cancelledTaskIDs.insert(id)
        tasksQueue.removeAll(where: { $0.id == id })
        queueLock.unlock()
        DispatchQueue.main.async {
            self.broadcastQueueStatus()
        }
    }

    public func cancelTask(id: String) {
        queueLock.lock()
        cancelledTaskIDs.insert(id)
        let before = tasksQueue.count
        tasksQueue.removeAll(where: { $0.id == id })
        let removedCount = tasksQueue.count - before
        let isActive = activeTask?.id == id
        let process = activeProcess
        let active = isActive ? activeTask : nil
        queueLock.unlock()

        if removedCount > 0 {
            DispatchQueue.main.async {
                self.broadcastQueueStatus()
            }
            return
        }

        guard isActive, let process = process, process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }

        if let active = active {
            DispatchQueue.main.async {
                self.finishTask(task: active, success: false, message: "Download cancelled")
            }
        }
    }

    public func cancelAllDownloads() {
        queueLock.lock()
        for t in tasksQueue {
            cancelledTaskIDs.insert(t.id)
        }
        if let active = activeTask {
            cancelledTaskIDs.insert(active.id)
        }
        tasksQueue.removeAll()
        let active = activeTask
        let process = activeProcess
        queueLock.unlock()

        if let process = process, process.isRunning {
            process.terminate()
            let pid = process.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
            }
        }

        if let active = active {
            DispatchQueue.main.async {
                self.finishTask(task: active, success: false, message: "Download cancelled")
            }
        } else {
            DispatchQueue.main.async {
                self.broadcastQueueStatus()
            }
        }
    }

    // MARK: - Parsing
    public static func parseYtDlpProgress(line: String) -> (percent: Double, eta: String, speed: String)? {
        guard line.contains("[download]") && line.contains("%") else { return nil }

        var percent: Double = 0.0
        if let pctRange = line.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
            let pctStr = line[pctRange].dropLast()
            if let val = Double(pctStr) {
                percent = min(max(val / 100.0, 0.0), 1.0)
            }
        }

        var eta = ""
        if let etaRange = line.range(of: #"ETA\s+(\S+)"#, options: .regularExpression) {
            let match = line[etaRange]
            eta = match.replacingOccurrences(of: "ETA", with: "").trimmingCharacters(in: .whitespaces)
            if eta.hasPrefix("00:") {
                let sec = eta.dropFirst(3)
                eta = "\(Int(sec) ?? 0)s"
            }
        }

        var speed = ""
        if let spdRange = line.range(of: #"at\s+(\S+/s)"#, options: .regularExpression) {
            let match = line[spdRange]
            speed = match.replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces)
        }

        return (percent, eta, speed)
    }

    // MARK: - Audio File Validation
    private func validateJobAudioFile(in jobDir: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(at: jobDir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }

        let supportedAudioExts: Set<String> = ["m4a", "mp3", "aac", "wav", "flac", "ogg", "opus"]
        let candidates = items.filter { url in
            let ext = url.pathExtension.lowercased()
            return supportedAudioExts.contains(ext)
        }

        for candidate in candidates {
            guard let resourceValues = try? candidate.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let size = resourceValues.fileSize,
                  size > 10240 else {
                continue
            }

            let asset = AVURLAsset(url: candidate)
            let durationSec = CMTimeGetSeconds(asset.duration)
            guard !durationSec.isNaN, !durationSec.isInfinite, durationSec > 1.0 else {
                continue
            }

            guard asset.isPlayable else {
                continue
            }

            return candidate
        }

        return nil
    }

    // MARK: - Safe Job Directory Cleanup
    private func cleanupJobDir(_ jobDir: URL) {
        if currentActiveJobDirURL == jobDir {
            currentActiveJobDirURL = nil
        }
        if FileManager.default.fileExists(atPath: jobDir.path) {
            try? FileManager.default.removeItem(at: jobDir)
        }
    }

    // MARK: - YouTube Video ID Extraction
    public static func extractVideoID(from urlOrVideoId: String) -> String? {
        let trimmed = urlOrVideoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count == 11, !trimmed.contains("/"), !trimmed.contains(" ") {
            return trimmed
        }

        let patterns = [
            "[?&]v=([A-Za-z0-9_-]{11})",
            "youtu\\.be/([A-Za-z0-9_-]{11})",
            "music\\.youtube\\.com/(?:playlist|watch|embed)/([A-Za-z0-9_-]{11})",
            "youtube\\.com/embed/([A-Za-z0-9_-]{11})"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = regex.firstMatch(in: trimmed, options: [], range: nsRange),
               match.numberOfRanges > 1,
               let groupRange = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[groupRange])
            }
        }
        return nil
    }
}
