import Foundation
import AppKit

// MARK: - YouTubeDownloadService

/// Robust downloader wrapping `yt-dlp` for YouTube videos and audio.
/// Checks bundled yt-dlp binary first, then Homebrew `/opt/homebrew/bin/yt-dlp`, `/usr/local/bin/yt-dlp`, and system PATH.
@MainActor
public final class YouTubeDownloadService {
    public static let shared = YouTubeDownloadService()

    public let downloadsDir: URL = {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MooziacTube")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var activeProcess: Process?

    private init() {}

    // MARK: - yt-dlp binary resolution

    public var ytdlpPath: String? {
        // 0. Mooziac Application Support bin directory (managed by DependencyManager)
        let depPath = DependencyManager().ytDlpExecutableURL.path
        if FileManager.default.isExecutableFile(atPath: depPath) {
            return depPath
        }

        // 1. App Bundle Resource directory
        if let resourcePath = Bundle.main.resourcePath {
            let bundled = (resourcePath as NSString).appendingPathComponent("yt-dlp")
            if FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }
        // 2. Bundle path for resource
        if let path = Bundle.main.path(forResource: "yt-dlp", ofType: nil),
           FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // 3. Homebrew & standard paths
        let standardPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        for p in standardPaths {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        // 4. PATH lookup via which
        let whichProc = Process()
        whichProc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        whichProc.arguments = ["which", "yt-dlp"]
        let pipe = Pipe()
        whichProc.standardOutput = pipe
        whichProc.standardError = FileHandle.nullDevice
        do {
            try whichProc.run()
            whichProc.waitUntilExit()
            let outStr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !outStr.isEmpty && FileManager.default.isExecutableFile(atPath: outStr) {
                return outStr
            }
        } catch {}

        return nil
    }

    public var isAvailable: Bool {
        guard let path = ytdlpPath else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    // MARK: - Formats

    public struct DownloadFormat: Identifiable, Sendable {
        public let id: String
        public let label: String
        public let isAudioOnly: Bool
        public let fileSize: Int64?
        public let height: Int?

        public init(id: String, label: String, isAudioOnly: Bool, fileSize: Int64? = nil, height: Int? = nil) {
            self.id = id
            self.label = label
            self.isAudioOnly = isAudioOnly
            self.fileSize = fileSize
            self.height = height
        }

        public var sizeLabel: String {
            guard let size = fileSize, size > 0 else { return "" }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }

    /// Fetches all available download formats for a given YouTube video ID.
    public func fetchFormats(videoId: String) async -> [DownloadFormat] {
        guard let execPath = ytdlpPath, let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else {
            return Self.defaultFallbackFormats()
        }

        return await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: execPath)
            proc.arguments = [
                "-J",
                "--no-playlist",
                "--socket-timeout", "15",
                url.absoluteString
            ]

            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            var outData = Data()
            do {
                try proc.run()
                // Read stdout asynchronously before exit to prevent pipe buffer deadlock
                outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
            } catch {
                return Self.defaultFallbackFormats()
            }

            guard !outData.isEmpty,
                  let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
                  let formats = json["formats"] as? [[String: Any]] else {
                return Self.defaultFallbackFormats()
            }

            let parsed = Self.parseFormats(formats)
            return parsed.isEmpty ? Self.defaultFallbackFormats() : parsed
        }.value
    }

    public nonisolated static func defaultFallbackFormats() -> [DownloadFormat] {
        [
            DownloadFormat(
                id: "bestaudio/best",
                label: "MP3 Audio (High Quality 320kbps)",
                isAudioOnly: true
            ),
            DownloadFormat(
                id: "bestvideo[height<=2160]+bestaudio/best",
                label: "4K Ultra HD (2160p)",
                isAudioOnly: false,
                height: 2160
            ),
            DownloadFormat(
                id: "bestvideo[height<=1440]+bestaudio/best",
                label: "1440p QHD (2K)",
                isAudioOnly: false,
                height: 1440
            ),
            DownloadFormat(
                id: "bestvideo[height<=1080]+bestaudio/best",
                label: "1080p Full HD (MP4)",
                isAudioOnly: false,
                height: 1080
            ),
            DownloadFormat(
                id: "bestvideo[height<=720]+bestaudio/best",
                label: "720p HD (MP4)",
                isAudioOnly: false,
                height: 720
            ),
            DownloadFormat(
                id: "bestvideo[height<=480]+bestaudio/best",
                label: "480p SD (MP4)",
                isAudioOnly: false,
                height: 480
            )
        ]
    }

    private nonisolated static func parseFormats(_ formats: [[String: Any]]) -> [DownloadFormat] {
        var results: [DownloadFormat] = []
        var seenHeights = Set<Int>()

        // 1. Audio Option (Always at top)
        results.append(DownloadFormat(
            id: "bestaudio/best",
            label: "MP3 Audio (High Quality 320kbps)",
            isAudioOnly: true
        ))

        // Find available video heights
        for fmt in formats {
            guard let formatId = fmt["format_id"] as? String,
                  !formatId.contains("storyboard") else { continue }

            let vcodec = fmt["vcodec"] as? String ?? ""
            if vcodec == "none" { continue }

            let height = fmt["height"] as? Int ?? 0
            guard height >= 360 else { continue }
            guard !seenHeights.contains(height) else { continue }
            seenHeights.insert(height)

            let filesize = fmt["filesize"] as? Int64 ?? fmt["filesize_approx"] as? Int64

            let label: String
            switch height {
            case 2160: label = "4K Ultra HD (2160p)"
            case 1440: label = "1440p QHD (2K)"
            case 1080: label = "1080p Full HD (MP4)"
            case 720: label = "720p HD (MP4)"
            case 480: label = "480p SD (MP4)"
            case 360: label = "360p (MP4)"
            default: label = "\(height)p (MP4)"
            }

            let selector = "bestvideo[height<=\(height)]+bestaudio/best[height<=\(height)]"
            results.append(DownloadFormat(
                id: selector,
                label: label,
                isAudioOnly: false,
                fileSize: filesize,
                height: height
            ))
        }

        // Sort: Audio first, then highest resolution descending
        return results.sorted { a, b in
            if a.isAudioOnly { return true }
            if b.isAudioOnly { return false }
            return (a.height ?? 0) > (b.height ?? 0)
        }
    }

    // MARK: - Download Lifecycle

    public enum DownloadState: Sendable {
        case idle
        case preparing
        case downloading(progress: Double, speed: String)
        case completed(filename: String, fileURL: URL)
        case failed(String)
    }

    /// Starts downloading the video in the specified format with real-time progress callbacks.
    public func download(
        videoId: String,
        videoTitle: String,
        format: DownloadFormat,
        downloadSubtitles: Bool = false,
        onUpdate: @escaping @Sendable (DownloadState) -> Void
    ) {
        cancelDownload()
        onUpdate(.preparing)

        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else {
            onUpdate(.failed("Invalid YouTube video URL"))
            return
        }

        guard let execPath = ytdlpPath else {
            onUpdate(.failed("yt-dlp helper not found. Please install via: brew install yt-dlp"))
            return
        }

        let proc = Process()
        self.activeProcess = proc
        proc.executableURL = URL(fileURLWithPath: execPath)

        let targetDir = self.downloadsDir
        var args = [
            "--no-playlist",
            "--no-mtime",
            "--concurrent-fragments", "4",
            "-o", "\(targetDir.path)/%(title)s.%(ext)s"
        ]

        if format.isAudioOnly {
            args.append(contentsOf: [
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "--embed-thumbnail"
            ])
        } else {
            args.append(contentsOf: [
                "-f", format.id,
                "--merge-output-format", "mp4"
            ])
        }

        if downloadSubtitles {
            let lang = Locale.current.language.languageCode?.identifier ?? "en"
            args.append(contentsOf: [
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs", "\(lang),\(lang).*,en,en.*",
                "--convert-subs", "srt"
            ])
            if !format.isAudioOnly {
                args.append("--embed-subs")
            }
        }

        args.append(url.absoluteString)
        proc.arguments = args

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        nonisolated(unsafe) var detectedFilename = ""
        let onUpdateSendable = onUpdate

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !chunk.isEmpty else { return }

            let lines = chunk.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.contains("[download] Destination:") {
                    detectedFilename = trimmed
                        .replacingOccurrences(of: "[download] Destination: ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.contains("[Merger] Merging formats into \"") {
                    let parts = trimmed.components(separatedBy: "\"")
                    if parts.count >= 2 {
                        detectedFilename = parts[1]
                    }
                } else if trimmed.contains("[ExtractAudio] Destination:") {
                    detectedFilename = trimmed
                        .replacingOccurrences(of: "[ExtractAudio] Destination: ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.contains("has already been downloaded") {
                    let parts = trimmed.components(separatedBy: " ")
                    if let first = parts.dropFirst().first {
                        detectedFilename = first
                    }
                }

                if trimmed.contains("%") {
                    let percent = Self.parsePercent(trimmed)
                    let speed = Self.parseSpeed(trimmed)
                    onUpdateSendable(.downloading(progress: percent, speed: speed))
                }
            }
        }

        let fallbackTitle = videoTitle.isEmpty ? "YouTube Video" : videoTitle
        proc.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self?.activeProcess = nil
            }

            var cleanName = (detectedFilename as NSString).lastPathComponent
            if cleanName.isEmpty {
                let ext = format.isAudioOnly ? "mp3" : "mp4"
                cleanName = "\(fallbackTitle).\(ext)"
            }

            let fileURL = targetDir.appendingPathComponent(cleanName)

            if process.terminationStatus == 0 {
                onUpdateSendable(.completed(filename: cleanName, fileURL: fileURL))
            } else {
                onUpdateSendable(.failed("Download failed or was canceled. Ensure yt-dlp is available: brew install yt-dlp"))
            }
        }

        do {
            try proc.run()
        } catch {
            self.activeProcess = nil
            onUpdate(.failed(error.localizedDescription))
        }
    }

    /// Cancels the current download by terminating the active process.
    public func cancelDownload() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
            activeProcess = nil
        }
    }

    // MARK: - Stream Parsing Helpers

    private nonisolated static func parsePercent(_ line: String) -> Double {
        guard let range = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) else {
            return 0
        }
        let str = String(line[range]).replacingOccurrences(of: "%", with: "")
        return (Double(str) ?? 0) / 100.0
    }

    private nonisolated static func parseSpeed(_ line: String) -> String {
        guard let range = line.range(of: #"at\s+\S+"#, options: .regularExpression) else {
            return ""
        }
        return String(line[range])
    }
}
