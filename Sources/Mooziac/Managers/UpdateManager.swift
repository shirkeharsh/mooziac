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
    private var pendingWebURL: URL?

    public override init() {
        super.init()
    }

    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.2"
    }

    private var releasesAPIURL: URL? {
        return URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")
    }

    /// Check for updates from GitHub Releases (runs on every app launch and user request)
    /// - Parameter userInitiated: If true, shows alerts even if already up to date or on network failure.
    public func checkForUpdates(userInitiated: Bool = false) {
        guard !isChecking else { return }

        // Query version check endpoint to sync active version status
        // (Non-blocking: fire-and-forget, zero reliance for updates)
        sendVersionCheckPing()

        guard let url = releasesAPIURL else { return }

        isChecking = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey)

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mooziac-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { self.isChecking = false }

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

            guard let data = data else {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Update Check Failed",
                            message: "No response data received from GitHub.",
                            style: .warning
                        )
                    }
                }
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "UpdateError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed response payload"])
                }
                self.processReleasePayload(json: json, userInitiated: userInitiated)
            } catch {
                Log.general.error("Failed to parse GitHub update release payload: \(error.localizedDescription)")
                if userInitiated {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Update Check Failed",
                            message: "Received an invalid response from GitHub.",
                            style: .warning
                        )
                    }
                }
            }
        }
        task.resume()
    }

    /// Standard version check endpoint ping (updates active status and mirrors releases)
    private func sendVersionCheckPing() {
        guard let checkURL = URL(string: "https://mooziac.pages.dev/api/version-check") else { return }
        var request = URLRequest(url: checkURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4.0)
        request.httpShouldHandleCookies = false
        request.setValue("Mooziac/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request).resume()
    }

    private func processReleasePayload(json: [String: Any], userInitiated: Bool) {
        // Check if error message returned
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

        // Support both GitHub tag_name and Cloudflare version/tag_name
        guard let tagName = (json["tag_name"] as? String) ?? (json["version"] as? String) else {
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

        let releaseNotes = (json["body"] as? String) ?? (json["release_notes"] as? String) ?? (json["releaseNotes"] as? String) ?? "No release notes provided."
        let releasePageURL = (json["html_url"] as? String).flatMap { URL(string: $0) } ?? URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)/releases/latest")

        // Find direct ZIP and DMG download URLs
        var zipDownloadURL: URL? = (json["zip_url"] as? String).flatMap { URL(string: $0) }
        var dmgDownloadURL: URL? = (json["dmg_url"] as? String).flatMap { URL(string: $0) } ?? (json["downloadUrl"] as? String).flatMap { URL(string: $0) }

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
                !line.contains("Minimum System Requirements") &&
                !line.lowercased().contains("buymeacoffee.com")
            }
        let bulletLines = lines.map { line -> String in
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
        alert.icon = NSImage(size: NSSize(width: 0.1, height: 0.1))

        _ = alert.addButton(withTitle: "Update Now (In-App)")
        let coffeeButton = alert.addButton(withTitle: "Buy Me a Coffee ☕️")
        let starButton = alert.addButton(withTitle: "Star on GitHub ⭐")
        _ = alert.addButton(withTitle: "Later")
        self.pendingWebURL = webURL

        coffeeButton.target = self
        coffeeButton.action = #selector(coffeeButtonClicked(_:))

        starButton.target = self
        starButton.action = #selector(starOnGitHubClicked(_:))

        alert.layout()

        let win = alert.window
        if let cv = win.contentView {
            var iconView: NSView?
            var titleField: NSTextField?
            var infoField: NSTextField?

            func findViews(_ v: NSView) {
                for sub in v.subviews {
                    if sub is NSImageView {
                        iconView = sub
                    } else if let tf = sub as? NSTextField {
                        if tf.stringValue.contains("New Update Available") {
                            titleField = tf
                        } else if tf.stringValue.contains("Highlights") || tf.stringValue.contains("currently running") {
                            infoField = tf
                        }
                    }
                    findViews(sub)
                }
            }
            findViews(cv)

            iconView?.isHidden = true
            iconView?.frame = .zero

            let margin: CGFloat = 28.0

            // Measure button intrinsic sizes to guarantee ample spacing with zero overlap
            var btnStarWidth: CGFloat = 135.0
            var btnCoffeeWidth: CGFloat = 160.0
            var btnLaterWidth: CGFloat = 75.0
            var btnUpdateWidth: CGFloat = 160.0

            if alert.buttons.count >= 4 {
                let btnUpdate = alert.buttons[0]
                let btnCoffee = alert.buttons[1]
                let btnStar = alert.buttons[2]
                let btnLater = alert.buttons[3]

                btnStar.sizeToFit()
                btnCoffee.sizeToFit()
                btnLater.sizeToFit()
                btnUpdate.sizeToFit()

                btnStarWidth = btnStar.frame.width
                btnCoffeeWidth = btnCoffee.frame.width
                btnLaterWidth = btnLater.frame.width
                btnUpdateWidth = max(btnUpdate.frame.width, 150.0)
            }

            let minGapBetweenGroups: CGFloat = 40.0
            let totalButtonsWidth = margin + btnStarWidth + 10.0 + btnCoffeeWidth + minGapBetweenGroups + btnLaterWidth + 12.0 + btnUpdateWidth + margin
            let customWidth: CGFloat = max(660.0, ceil(totalButtonsWidth))
            let targetWidth = customWidth - (margin * 2)

            var winFrame = win.frame
            winFrame.size.width = customWidth

            let pStyle = NSMutableParagraphStyle()
            pStyle.lineSpacing = 5.0
            let attrStr = NSMutableAttributedString(
                string: infoField?.stringValue ?? alert.informativeText,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14.0, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: pStyle
                ]
            )
            infoField?.attributedStringValue = attrStr

            let neededTextSize = attrStr.boundingRect(
                with: NSSize(width: targetWidth, height: 2000),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).size
            let neededInfoHeight = ceil(neededTextSize.height) + 12
            let titleHeight: CGFloat = 26.0

            let neededTotalHeight: CGFloat = 28 + titleHeight + 14 + neededInfoHeight + 24 + 32 + 20

            let heightDelta = neededTotalHeight - winFrame.size.height
            winFrame.size.height = neededTotalHeight
            winFrame.origin.y -= heightDelta
            win.setFrame(winFrame, display: true)

            // Layout 4 buttons neatly across customWidth:
            // Left side: Support actions [⭐ Star on GitHub] [☕️ Buy Me a Coffee]
            // Right side: Decision actions [Later] [Update Now (In-App)]
            if alert.buttons.count >= 4 {
                let btnUpdate = alert.buttons[0]
                let btnCoffee = alert.buttons[1]
                let btnStar = alert.buttons[2]
                let btnLater = alert.buttons[3]

                var starFrame = btnStar.frame
                starFrame.origin.x = margin
                starFrame.origin.y = 18.0
                btnStar.frame = starFrame

                var coffeeFrame = btnCoffee.frame
                coffeeFrame.origin.x = starFrame.maxX + 10.0
                coffeeFrame.origin.y = 18.0
                btnCoffee.frame = coffeeFrame

                var updateFrame = btnUpdate.frame
                updateFrame.size.width = btnUpdateWidth
                updateFrame.origin.x = customWidth - margin - updateFrame.size.width
                updateFrame.origin.y = 18.0
                btnUpdate.frame = updateFrame

                var laterFrame = btnLater.frame
                laterFrame.origin.x = updateFrame.minX - 12.0 - laterFrame.size.width
                laterFrame.origin.y = 18.0
                btnLater.frame = laterFrame
            }

            let totalH = cv.bounds.height
            if let title = titleField {
                title.font = NSFont.systemFont(ofSize: 18, weight: .bold)
                title.textColor = .labelColor
                title.frame = NSRect(x: margin, y: totalH - 28 - titleHeight, width: targetWidth, height: titleHeight)
            }

            if let info = infoField {
                let titleMinY = titleField?.frame.minY ?? (totalH - 28 - titleHeight)
                info.frame = NSRect(x: margin, y: titleMinY - 14 - neededInfoHeight, width: targetWidth, height: neededInfoHeight)
            }
        }

        win.center()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let zipURL = zipURL {
                self.startInAppDownloadAndInstall(newVersion: newVersion, zipURL: zipURL, fallbackURL: dmgURL ?? webURL)
            } else if let downloadURL = dmgURL {
                NSWorkspace.shared.open(downloadURL)
            }
        }
    }

    @objc private func coffeeButtonClicked(_ sender: Any) {
        if let coffeeURL = URL(string: "https://buymeacoffee.com/shirkeharsh") {
            NSWorkspace.shared.open(coffeeURL)
        }
    }

    @objc private func starOnGitHubClicked(_ sender: Any) {
        if let githubURL = self.pendingWebURL ?? URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)") {
            NSWorkspace.shared.open(githubURL)
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
            if FileManager.default.fileExists(atPath: tempZipURL.path) {
                try FileManager.default.removeItem(at: tempZipURL)
            }
            if FileManager.default.fileExists(atPath: extractDir.path) {
                try FileManager.default.removeItem(at: extractDir)
            }
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

                do {
                    try relaunchProcess.run()
                    NSApp.terminate(nil)
                } catch {
                    Log.general.error("Failed to execute update relaunch script: \(error.localizedDescription)")
                    self?.handleUpdateFailure(error: error)
                }
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
