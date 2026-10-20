import AppKit
import Foundation
import WebKit

@available(macOS 15.4, *)
@MainActor
public final class WebExtensionManager: NSObject {
    public static let shared = WebExtensionManager()

    public let webExtensionController = WKWebExtensionController()
    public private(set) var installedExtensions: [ManagedExtension] = []
    private var activeContexts: [String: WKWebExtensionContext] = [:]

    public private(set) var currentTab: (any WKWebExtensionTab)?
    public private(set) var currentWindow: (any WKWebExtensionWindow)?

    private var extensionsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MooziacTube/Extensions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var extensionsJSONURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MooziacTube/extensions.json")
    }

    private override init() {
        super.init()
        self.webExtensionController.delegate = self
        self.loadPersistedList()
    }

    public func attachWebView(_ webView: WKWebView) {
        let tab = MooziacExtensionTab(webView: webView)
        let win = MooziacExtensionWindow()
        tab.window = win
        win.tab = tab
        self.currentTab = tab
        self.currentWindow = win
    }

    public func detachWebView() {
        self.currentTab = nil
        self.currentWindow = nil
    }

    private func ensureBundledExtensionsInstalled() {
        var bundledURLs: [URL] = []
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("Extensions/uBlockOriginLite", isDirectory: true),
           FileManager.default.fileExists(atPath: resURL.path) {
            bundledURLs.append(resURL)
        }
        let devURL = URL(fileURLWithPath: "Resources/Extensions/uBlockOriginLite")
        if bundledURLs.isEmpty && FileManager.default.fileExists(atPath: devURL.path) {
            bundledURLs.append(devURL)
        }

        for sourceURL in bundledURLs {
            let relativePath = "uBlockOriginLite"
            let destURL = extensionsBaseURL.appendingPathComponent(relativePath, isDirectory: true)

            if !FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.copyItem(at: sourceURL, to: destURL)
            }

            if !installedExtensions.contains(where: { $0.relativePath == relativePath || $0.id == "ublock-origin-lite" }) {
                let managed = ManagedExtension(
                    id: "ublock-origin-lite",
                    name: "uBlock Origin Lite",
                    version: "2026.1012.1545",
                    isEnabled: true,
                    relativePath: relativePath,
                    optionsPath: "dashboard.html",
                    popupPath: "popup.html"
                )
                installedExtensions.insert(managed, at: 0)
                savePersistedList()
            }
        }
    }

    private func loadPersistedList() {
        if let data = try? Data(contentsOf: extensionsJSONURL),
           let decoded = try? JSONDecoder().decode([ManagedExtension].self, from: data) {
            self.installedExtensions = decoded
        }
        self.ensureBundledExtensionsInstalled()
    }

    private func savePersistedList() {
        if let data = try? JSONEncoder().encode(installedExtensions) {
            try? data.write(to: extensionsJSONURL, options: .atomic)
        }
        NotificationCenter.default.post(name: AppSettings.extensionsDidChangeNotification, object: nil)
    }

    public func loadAllExtensions() async {
        self.ensureBundledExtensionsInstalled()
        for ext in installedExtensions where ext.isEnabled {
            await loadSingleExtension(ext)
        }
    }

    public func loadSingleExtension(_ ext: ManagedExtension) async {
        let folderURL = extensionsBaseURL.appendingPathComponent(ext.relativePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            Log.app.warning("Extension files missing at \(folderURL.path)")
            return
        }

        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: folderURL)
            let context = WKWebExtensionContext(for: webExtension)
            context.uniqueIdentifier = ext.id

            for permission in webExtension.requestedPermissions {
                context.setPermissionStatus(.grantedExplicitly, for: permission)
            }
            for pattern in webExtension.requestedPermissionMatchPatterns {
                context.setPermissionStatus(.grantedExplicitly, for: pattern)
            }

            // Grant permissions for any matches declared in content_scripts
            if let contentScripts = webExtension.manifest["content_scripts"] as? [[String: Any]] {
                for script in contentScripts {
                    if let matches = script["matches"] as? [String] {
                        for match in matches {
                            if let pattern = try? WKWebExtension.MatchPattern(string: match) {
                                context.setPermissionStatus(.grantedExplicitly, for: pattern)
                            }
                        }
                    }
                }
            }

            try self.webExtensionController.load(context)
            if webExtension.hasBackgroundContent {
                try? await context.loadBackgroundContent()
            }

            self.activeContexts[ext.id] = context
            Log.app.info("Loaded WebExtension: \(ext.name) (\(ext.version))")
        } catch {
            Log.app.error("Failed to load extension \(ext.name): \(error.localizedDescription)")
        }
    }

    public func installExtension(from sourceFolderURL: URL) async throws -> ManagedExtension {
        let manifestURL = sourceFolderURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "WebExtensionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Folder does not contain a manifest.json file."])
        }

        let data = try Data(contentsOf: manifestURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WebExtensionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to parse manifest.json."])
        }

        var name = (json["name"] as? String) ?? sourceFolderURL.lastPathComponent
        if name.hasPrefix("__MSG_") {
            // Try loading default locale display name
            let messagesURL = sourceFolderURL.appendingPathComponent("_locales/en/messages.json")
            if let msgData = try? Data(contentsOf: messagesURL),
               let msgJSON = try? JSONSerialization.jsonObject(with: msgData) as? [String: [String: Any]],
               let extName = msgJSON["extName"]?["message"] as? String {
                name = extName
            }
        }

        let version = (json["version"] as? String) ?? "1.0"
        let optionsUI = json["options_ui"] as? [String: Any]
        let optionsPath = (optionsUI?["page"] as? String) ?? (json["options_page"] as? String)

        var popupPath: String?
        if let action = (json["action"] as? [String: Any]) ?? (json["browser_action"] as? [String: Any]) {
            popupPath = action["default_popup"] as? String
        }

        let relativePath = UUID().uuidString
        let destURL = extensionsBaseURL.appendingPathComponent(relativePath, isDirectory: true)

        try FileManager.default.copyItem(at: sourceFolderURL, to: destURL)

        let managed = ManagedExtension(
            id: relativePath,
            name: name,
            version: version,
            isEnabled: true,
            relativePath: relativePath,
            optionsPath: optionsPath,
            popupPath: popupPath
        )

        self.installedExtensions.append(managed)
        self.savePersistedList()

        await self.loadSingleExtension(managed)
        return managed
    }

    public func toggleExtension(id: String) async {
        guard let idx = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        var ext = installedExtensions[idx]
        ext.isEnabled.toggle()
        installedExtensions[idx] = ext
        savePersistedList()

        if ext.isEnabled {
            await loadSingleExtension(ext)
        } else {
            if let context = activeContexts.removeValue(forKey: id) {
                try? self.webExtensionController.unload(context)
            }
        }
    }

    public func removeExtension(id: String) async {
        guard let idx = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        let ext = installedExtensions[idx]

        if let context = activeContexts.removeValue(forKey: id) {
            try? self.webExtensionController.unload(context)
        }

        let folderURL = extensionsBaseURL.appendingPathComponent(ext.relativePath)
        try? FileManager.default.removeItem(at: folderURL)

        installedExtensions.remove(at: idx)
        savePersistedList()
    }

    public func presentInstallPanel(completion: ((Result<ManagedExtension, Error>) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Install Extension"
        panel.message = "Select an unpacked Web Extension folder containing manifest.json"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            Task { @MainActor in
                do {
                    let ext = try await self.installExtension(from: url)
                    completion?(.success(ext))
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                    completion?(.failure(error))
                }
            }
        }
    }

    public func openExtensionsFolder() {
        NSWorkspace.shared.open(extensionsBaseURL)
    }

    public func openExtensionOptions(id: String) {
        guard let context = activeContexts[id],
              let optionsURL = context.optionsPageURL else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Extension Options"
        let webView = WKWebView(frame: window.contentView?.bounds ?? .zero)
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        webView.load(URLRequest(url: optionsURL))
        window.makeKeyAndOrderFront(nil)
    }
}

@available(macOS 15.4, *)
extension WebExtensionManager: WKWebExtensionControllerDelegate {
    public func webExtensionController(_ controller: WKWebExtensionController, shouldShowPromptFor permissions: Set<WKWebExtension.Permission>, in context: WKWebExtensionContext) async -> Bool {
        return false // Auto-grant permissions without modal prompts
    }

    public func webExtensionController(_ controller: WKWebExtensionController, shouldShowPromptFor matchPatterns: Set<WKWebExtension.MatchPattern>, in context: WKWebExtensionContext) async -> Bool {
        return false // Auto-grant match pattern permissions without modal prompts
    }

    public func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor context: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        if let win = self.currentWindow { return [win] }
        return []
    }

    public func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        return self.currentWindow
    }
}
