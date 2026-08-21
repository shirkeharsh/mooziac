import AppKit
import Foundation

public final class UpdateManager: NSObject, URLSessionDownloadDelegate {
    public static let shared = UpdateManager()

    /// Public GitHub repository for release updates
    public var repositoryOwner: String = "shirkeharsh"
    public var repositoryName: String = "mooziac"

    private let lastCheckKey = "Mooziac_lastUpdateCheckTimestamp"
    private var isChecking = false

    private var activeDownloadTask: URLSessionDownloadTask?
    private var progressWindow: NSWindow?
    private var progressIndicator: NSProgressIndicator?
    private var statusLabel: NSTextField?
    private var percentLabel: NSTextField?
    private var pendingNewVersion: String = ""
    private var pendingFallbackURL: URL?

    public override init() {
        super.init()
    }

    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var releasesAPIURL: URL? {
        return URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")
    }

    /// Check for updates from GitHub Releases
    /// - Parameter userInitiated: If true, shows alerts even if already up to date or on network failure.
    public func checkForUpdates(userInitiated: Bool = false) {
        guard !isChecking else { return }

        // Throttle background checks to once every 24 hours
        if !userInitiated {
            let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
            let now = Date().timeIntervalSince1970
            if lastCheck > 0 && (now - lastCheck) < 86400 {
                return
            }
        }

        guard let url = releasesAPIURL else { return }

        isChecking = true

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mooziac-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { self.isChecking = false }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey)

            if let error = error {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Update Check Failed",
                            message: "Unable to check for updates: \(error.localizedDescription)\n\nPlease check your internet connection.",
                            style: .warning
                        )
                    }
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Update Check Failed",
                            message: "Received an invalid response from GitHub.",
                            style: .warning
                        )
                    }
                }
                return
            }

            // Check if GitHub returned a "Not Found" error
            if let message = json["message"] as? String, message.lowercased().contains("not found") {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "You're up to date!",
                            message: "Mooziac \(self.currentVersion) is currently the newest version available.",
                            style: .informational
                        )
                    }
                }
                return
            }

            guard let tagName = json["tag_name"] as? String else {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "You're up to date!",
                            message: "Mooziac \(self.currentVersion) is currently the newest version available.",
                            style: .informational
                        )
                    }
                }
                return
            }

            let releaseNotes = json["body"] as? String ?? "No release notes provided."
            let releasePageURL = (json["html_url"] as? String).flatMap { URL(string: $0) }

            // Find direct ZIP and DMG download URLs
            var zipDownloadURL: URL?
            var dmgDownloadURL: URL?
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       let downloadStr = asset["browser_download_url"] as? String,
                       let assetURL = URL(string: downloadStr) {
                        if name.hasSuffix(".zip") {
                            zipDownloadURL = assetURL
                        } else if name.hasSuffix(".dmg") {
                            dmgDownloadURL = assetURL
                        }
                    }
                }
            }

            let isNewer = self.isVersion(tagName, newerThan: self.currentVersion)

            DispatchQueue.main.async {
                if isNewer {
                    self.showUpdateAvailableAlert(
                        newVersion: tagName,
                        releaseNotes: releaseNotes,
                        zipURL: zipDownloadURL,
                        dmgURL: dmgDownloadURL ?? releasePageURL,
                        webURL: releasePageURL
                    )
                } else if userInitiated {
                    self.showAlert(
                        title: "You're up to date!",
                        message: "Mooziac \(self.currentVersion) is currently the newest version available.",
                        style: .informational
                    )
                }
            }
        }

        task.resume()
    }

    /// Compare semantic versions (e.g. "v1.0.1" vs "1.0.0")
    public func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    private func formatCompactReleaseNotes(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty &&
                !line.starts(with: "##") &&
                !line.starts(with: "###") &&
                !line.starts(with: "---") &&
                !line.starts(with: "|") &&
                !line.contains("Minimum System Requirements")
            }
        let bulletLines = lines.prefix(5).map { line -> String in
            var l = line
            if l.starts(with: "- ") {
                l = "• " + l.dropFirst(2)
            } else if l.starts(with: "* ") {
                l = "• " + l.dropFirst(2)
            } else if !l.starts(with: "•") {
                l = "• " + l
            }
            return l
        }
        if bulletLines.isEmpty {
            return "• Performance improvements and bug fixes."
        }
        return bulletLines.joined(separator: "\n")
    }

    private func showUpdateAvailableAlert(newVersion: String, releaseNotes: String, zipURL: URL?, dmgURL: URL?, webURL: URL?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "🎉 New Update Available! (\(newVersion))"

        let formattedNotes = formatCompactReleaseNotes(releaseNotes)
        alert.informativeText = "You are currently running Mooziac \(currentVersion).\n\nHighlights:\n\(formattedNotes)"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Update Now (In-App)")
        alert.addButton(withTitle: "View on GitHub")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let zipURL = zipURL {
                self.startInAppDownloadAndInstall(newVersion: newVersion, zipURL: zipURL, fallbackURL: dmgURL ?? webURL)
            } else if let downloadURL = dmgURL {
                NSWorkspace.shared.open(downloadURL)
            }
        } else if response == .alertSecondButtonReturn {
            if let githubURL = webURL {
                NSWorkspace.shared.open(githubURL)
            }
        }
    }

    // MARK: - In-App Seamless Download & Installation

    public func startInAppDownloadAndInstall(newVersion: String, zipURL: URL, fallbackURL: URL?) {
        self.pendingNewVersion = newVersion
        self.pendingFallbackURL = fallbackURL

        showProgressUI(version: newVersion)

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.downloadTask(with: zipURL)
        self.activeDownloadTask = task
        task.resume()
    }

    private func showProgressUI(version: String) {
        if progressWindow != nil {
            progressWindow?.close()
        }

        let width: CGFloat = 360
        let height: CGFloat = 130
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Updating Mooziac"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView.wantsLayer = true

        let iconView = NSImageView(frame: NSRect(x: 18, y: height - 58, width: 44, height: 44))
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            iconView.image = appIcon
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
            iconView.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Updating")?.withSymbolConfiguration(config)
        }
        contentView.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "Downloading Mooziac \(version)...")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.frame = NSRect(x: 72, y: height - 36, width: width - 88, height: 18)
        contentView.addSubview(titleLabel)
        self.statusLabel = titleLabel

        let pIndicator = NSProgressIndicator(frame: NSRect(x: 72, y: height - 62, width: width - 148, height: 14))
        pIndicator.isIndeterminate = false
        pIndicator.minValue = 0.0
        pIndicator.maxValue = 100.0
        pIndicator.doubleValue = 0.0
        contentView.addSubview(pIndicator)
        self.progressIndicator = pIndicator

        let pctLabel = NSTextField(labelWithString: "0%")
        pctLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        pctLabel.alignment = .right
        pctLabel.textColor = NSColor.secondaryLabelColor
        pctLabel.frame = NSRect(x: width - 70, y: height - 64, width: 52, height: 16)
        contentView.addSubview(pctLabel)
        self.percentLabel = pctLabel

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelDownload))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: width - 90, y: 12, width: 74, height: 26)
        contentView.addSubview(cancelButton)

        window.contentView = contentView
        self.progressWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func cancelDownload() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        progressWindow?.close()
        progressWindow = nil
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let percent = Int(progress * 100)

        DispatchQueue.main.async { [weak self] in
            self?.progressIndicator?.doubleValue = progress * 100.0
            self?.percentLabel?.stringValue = "\(percent)%"
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.stringValue = "Installing update & restarting..."
            self?.progressIndicator?.isIndeterminate = true
            self?.progressIndicator?.startAnimation(nil)
            self?.percentLabel?.stringValue = ""
        }

        let tempZipURL = URL(fileURLWithPath: "/tmp/mooziac_update_\(UUID().uuidString).zip")
        let extractDir = URL(fileURLWithPath: "/tmp/mooziac_extract_\(UUID().uuidString)")

        do {
            try? FileManager.default.removeItem(at: tempZipURL)
            try? FileManager.default.removeItem(at: extractDir)
            try FileManager.default.copyItem(at: location, to: tempZipURL)
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            // Extract using macOS ditto to preserve attributes & code signature
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProcess.arguments = ["-xk", tempZipURL.path, extractDir.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            guard unzipProcess.terminationStatus == 0 else {
                throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract update package."])
            }

            // Locate Mooziac.app inside the extracted directory
            let extractedAppURL = extractDir.appendingPathComponent("Mooziac.app")
            guard FileManager.default.fileExists(atPath: extractedAppURL.path) else {
                throw NSError(domain: "UpdateError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Extracted update is missing Mooziac.app bundle."])
            }

            // Determine target installation path
            var targetAppPath = Bundle.main.bundleURL.path
            if !targetAppPath.hasSuffix(".app") || targetAppPath.contains("/.build/") || targetAppPath.contains("/var/folders/") {
                targetAppPath = (NSHomeDirectory() as NSString).appendingPathComponent("Applications/Mooziac.app")
            }

            // Generate relaunch helper script
            let scriptPath = "/tmp/mooziac_relaunch.sh"
            let scriptContent = """
            #!/bin/bash
            sleep 0.8
            rm -rf "\(targetAppPath)"
            cp -R "\(extractedAppURL.path)" "\(targetAppPath)"
            xattr -d -r com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
            open "\(targetAppPath)"
            rm -rf "\(extractDir.path)" "\(tempZipURL.path)" "\(scriptPath)"
            """

            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", scriptPath]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()

            // Run detached relaunch script & terminate current app
            DispatchQueue.main.async { [weak self] in
                self?.progressWindow?.close()
                self?.progressWindow = nil

                let relaunchProcess = Process()
                relaunchProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                relaunchProcess.arguments = [scriptPath]
                try? relaunchProcess.run()

                NSApp.terminate(nil)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.progressWindow?.close()
                self?.progressWindow = nil
                self?.handleUpdateFailure(error: error)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        // Ignore user cancellation
        if (error as NSError).code == NSURLErrorCancelled { return }

        DispatchQueue.main.async { [weak self] in
            self?.progressWindow?.close()
            self?.progressWindow = nil
            self?.handleUpdateFailure(error: error)
        }
    }

    private func handleUpdateFailure(error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "In-App Update Failed"
        alert.informativeText = "Unable to install update automatically: \(error.localizedDescription)\n\nWould you like to open the release on GitHub instead?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open on GitHub")
        alert.addButton(withTitle: "Cancel")

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn, let fallback = pendingFallbackURL {
            NSWorkspace.shared.open(fallback)
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
