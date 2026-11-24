import AppKit

/// Small native dialogs for connecting scrobbling accounts. Everything here runs on the main thread.
enum ScrobbleConnectUI {

    static func connect(_ provider: ScrobbleProvider) {
        NSApp.activate(ignoringOtherApps: true)
        switch provider {
        case .listenBrainz: promptListenBrainzToken(prefill: "")
        case .lastFM: startLastFM()
        }
    }

    // MARK: - ListenBrainz (user token)

    private static func promptListenBrainzToken(prefill: String) {
        let alert = NSAlert()
        alert.messageText = "Connect ListenBrainz"
        alert.informativeText = "1. Click “Get User Token” to open your ListenBrainz profile.\n2. Copy your user token.\n3. Paste it below and click Connect."

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "Paste your user token"
        field.stringValue = prefill
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Get User Token")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let token = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { promptListenBrainzToken(prefill: ""); return }
            Task {
                do {
                    let user = try await ScrobbleManager.shared.connectListenBrainz(token: token)
                    await MainActor.run { toast("✓ ListenBrainz connected (@\(user))") }
                } catch {
                    await MainActor.run {
                        showError(title: "Couldn't connect ListenBrainz", message: error.localizedDescription)
                        promptListenBrainzToken(prefill: token)
                    }
                }
            }
        case .alertSecondButtonReturn:
            if let url = URL(string: "https://listenbrainz.org/profile/") { NSWorkspace.shared.open(url) }
            promptListenBrainzToken(prefill: field.stringValue)
        default:
            break
        }
    }

    // MARK: - Last.fm (web authorization)

    private static func startLastFM() {
        guard ScrobbleConfig.isLastFMConfigured else {
            showError(
                title: "Last.fm API key needed",
                message: "This build of Mooziac has no Last.fm API key. Create a free one at last.fm/api/account/create, then add LastFMAPIKey and LastFMSharedSecret to the app's Info.plist (or set MOOZIAC_LASTFM_API_KEY and MOOZIAC_LASTFM_SECRET)."
            )
            return
        }
        Task {
            do {
                let auth = try await ScrobbleManager.shared.beginLastFMAuth()
                await MainActor.run {
                    NSWorkspace.shared.open(auth.url)
                    promptLastFMComplete(token: auth.token)
                }
            } catch {
                await MainActor.run {
                    showError(title: "Couldn't start Last.fm sign-in", message: error.localizedDescription)
                }
            }
        }
    }

    private static func promptLastFMComplete(token: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Finish connecting Last.fm"
        alert.informativeText = "Click “Yes, Allow Access” on the Last.fm page that just opened in your browser, then come back here and click Complete."
        alert.addButton(withTitle: "Complete")
        alert.addButton(withTitle: "Reopen Page")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                do {
                    let user = try await ScrobbleManager.shared.completeLastFMAuth(token: token)
                    await MainActor.run { toast("✓ Last.fm connected (@\(user))") }
                } catch ScrobbleError.notAuthorizedYet {
                    await MainActor.run {
                        showError(
                            title: "Not approved yet",
                            message: "Last.fm hasn't received your approval. Click “Yes, Allow Access” on the website first."
                        )
                        promptLastFMComplete(token: token)
                    }
                } catch {
                    await MainActor.run {
                        showError(title: "Couldn't connect Last.fm", message: error.localizedDescription)
                    }
                }
            }
        case .alertSecondButtonReturn:
            if let url = LastFMService.authURL(token: token) { NSWorkspace.shared.open(url) }
            promptLastFMComplete(token: token)
        default:
            break
        }
    }

    // MARK: - Helpers

    private static func showError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func toast(_ text: String) {
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: text)
    }
}
