import Foundation
import AppKit

public final class DependencyManager: NSObject, URLSessionDownloadDelegate {
    public static let shared = DependencyManager()

    public let binDirectory: URL
    public let ytDlpExecutableURL: URL

    private var currentDownloadTask: URLSessionDownloadTask?
    private var progressCallback: ((Double) -> Void)?
    private var completionCallback: ((Bool, String?) -> Void)?
    private var isInstalling: Bool = false

    private override init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mooziacDir = appSupport.appendingPathComponent("Mooziac", isDirectory: true)
        self.binDirectory = mooziacDir.appendingPathComponent("bin", isDirectory: true)
        self.ytDlpExecutableURL = binDirectory.appendingPathComponent("yt-dlp")
        super.init()

        try? FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    }

    public var isHelperInstalled: Bool {
        return FileManager.default.isExecutableFile(atPath: ytDlpExecutableURL.path)
    }

    public func installHelper(
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        if isInstalling {
            completion(false, "Helper installation already in progress")
            return
        }

        if isHelperInstalled {
            completion(true, nil)
            return
        }

        self.isInstalling = true
        self.progressCallback = progress
        self.completionCallback = completion

        // Standalone Universal binary for macOS (runs on Intel and Apple Silicon with zero dependencies)
        let downloadURLString = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
        guard let url = URL(string: downloadURLString) else {
            self.isInstalling = false
            completion(false, "Invalid helper URL")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        let task = session.downloadTask(with: url)
        self.currentDownloadTask = task
        task.resume()
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressCallback?(fraction)
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: ytDlpExecutableURL.path) {
                try FileManager.default.removeItem(at: ytDlpExecutableURL)
            }

            try FileManager.default.moveItem(at: location, to: ytDlpExecutableURL)

            // Set POSIX permissions to rwxr-xr-x (0o755)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: ytDlpExecutableURL.path
            )

            // Strip quarantine attribute if macOS added it
            let xattrProcess = Process()
            xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrProcess.arguments = ["-d", "com.apple.quarantine", ytDlpExecutableURL.path]
            try? xattrProcess.run()
            xattrProcess.waitUntilExit()

            self.isInstalling = false
            completionCallback?(true, nil)
        } catch {
            self.isInstalling = false
            completionCallback?(false, error.localizedDescription)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            self.isInstalling = false
            completionCallback?(false, error.localizedDescription)
        }
    }
}
