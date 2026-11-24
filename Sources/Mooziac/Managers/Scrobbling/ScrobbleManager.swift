import Foundation
import AppKit
import QuartzCore

/// Watches playback and scrobbles to Last.fm and/or ListenBrainz.
///
/// Rules:
/// - Metadata is cleaned first ("Starboy (Official Music Video) ft. X" -> "Starboy").
/// - Ads are never counted or scrobbled.
/// - Only time actually spent playing counts. A track scrobbles after half its length
///   or 4 minutes (whichever is first), and never if it is shorter than 30 s.
///   So skipping a song early never scrobbles it.
/// - "Now playing" is sent after 3 s of listening (avoids spam while skipping).
/// - Failed scrobbles (offline, rate limit, server error) are queued on disk and retried.
///
/// All state is touched on the main thread only.
final class ScrobbleManager {
    static let shared = ScrobbleManager()

    // MARK: Defaults keys

    private let pendingKey = "Mooziac_scrobble_pending_v1"
    private func enabledKey(_ p: ScrobbleProvider) -> String { "Mooziac_scrobble_enabled_\(p.rawValue)" }
    private func usernameKey(_ p: ScrobbleProvider) -> String { "Mooziac_scrobble_username_\(p.rawValue)" }

    private let defaults = UserDefaults.standard
    private let maxPending = 500
    private let maxScrobbleAge: Int = 14 * 24 * 3600   // Last.fm ignores older scrobbles

    // MARK: Credential cache (avoids hitting the Keychain every second)

    private var credentialCache: [ScrobbleProvider: String] = [:]
    private var credentialLoaded: Set<ScrobbleProvider> = []

    // MARK: Listening session

    private var timer: Timer?
    private var lastTickTime: CFTimeInterval = CACurrentMediaTime()
    private var tickCounter = 0

    private var sessionKey = ""
    private var sessionStart = Date()
    private var sessionListened: Double = 0
    private var sessionScrobbled = false
    private var sessionNowPlayingSent = false
    private var lastPosition: Double = 0

    // MARK: Retry queue

    private var pending: [PendingScrobble] = []
    private var isFlushing = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        pending = loadPending()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
        flushPending()
    }

    // MARK: - Settings & connection state

    func isEnabled(_ provider: ScrobbleProvider) -> Bool {
        defaults.bool(forKey: enabledKey(provider))
    }

    func setEnabled(_ enabled: Bool, for provider: ScrobbleProvider) {
        defaults.set(enabled, forKey: enabledKey(provider))
        if !enabled { resetSession() }
    }

    func isConnected(_ provider: ScrobbleProvider) -> Bool {
        credential(for: provider) != nil
    }

    func username(for provider: ScrobbleProvider) -> String? {
        defaults.string(forKey: usernameKey(provider))
    }

    private func credential(for provider: ScrobbleProvider) -> String? {
        if credentialLoaded.contains(provider) { return credentialCache[provider] }
        credentialLoaded.insert(provider)
        if let value = ScrobbleKeychain.read(account: provider.keychainAccount) {
            credentialCache[provider] = value
            return value
        }
        return nil
    }

    private func activeProviders() -> [ScrobbleProvider] {
        ScrobbleProvider.allCases.filter { isEnabled($0) && isConnected($0) }
    }

    // MARK: - Connect / disconnect

    /// ListenBrainz: validate the pasted user token, then store it in the Keychain.
    func connectListenBrainz(token: String) async throws -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = try await ListenBrainzService.validate(token: trimmed)
        await MainActor.run { self.storeConnection(.listenBrainz, credential: trimmed, username: user) }
        return user
    }

    /// Last.fm step 1: get a request token and the URL the user must approve in the browser.
    func beginLastFMAuth() async throws -> (token: String, url: URL) {
        guard ScrobbleConfig.isLastFMConfigured else { throw ScrobbleError.notConfigured }
        let token = try await LastFMService.getToken()
        guard let url = LastFMService.authURL(token: token) else {
            throw ScrobbleError.rejected("Could not build the Last.fm approval link.")
        }
        return (token, url)
    }

    /// Last.fm step 2: after the user approved, exchange the token for a permanent session key.
    func completeLastFMAuth(token: String) async throws -> String {
        let session = try await LastFMService.getSession(token: token)
        await MainActor.run { self.storeConnection(.lastFM, credential: session.key, username: session.name) }
        return session.name
    }

    private func storeConnection(_ provider: ScrobbleProvider, credential: String, username: String) {
        ScrobbleKeychain.save(credential, account: provider.keychainAccount)
        credentialCache[provider] = credential
        credentialLoaded.insert(provider)
        defaults.set(username, forKey: usernameKey(provider))
        defaults.set(true, forKey: enabledKey(provider))
        resetSession()
    }

    func disconnect(_ provider: ScrobbleProvider) {
        ScrobbleKeychain.delete(account: provider.keychainAccount)
        credentialCache[provider] = nil
        credentialLoaded.insert(provider)
        defaults.removeObject(forKey: usernameKey(provider))
        defaults.set(false, forKey: enabledKey(provider))
        pending.removeAll { $0.provider == provider }
        savePending()
        resetSession()
    }

    // MARK: - Listening tracker

    private func resetSession() {
        sessionKey = ""
        sessionListened = 0
        sessionScrobbled = false
        sessionNowPlayingSent = false
        lastPosition = 0
    }

    private func beginSession(key: String, position: Double) {
        sessionKey = key
        sessionStart = Date()
        sessionListened = 0
        sessionScrobbled = false
        sessionNowPlayingSent = false
        lastPosition = position
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTickTime, 0), 2.0)
        lastTickTime = now

        tickCounter += 1
        if tickCounter % 60 == 0, !pending.isEmpty { flushPending() }

        guard !activeProviders().isEmpty else {
            if !sessionKey.isEmpty { resetSession() }
            return
        }

        let state = NowPlayingManager.shared.currentState

        // Ads: never counted, never scrobbled. The session is kept so the real track resumes cleanly.
        if state.isAd { return }

        guard let meta = ScrobbleRules.cleanedMetadata(title: state.title, artist: state.artist) else { return }
        let key = NowPlayingManager.shared.trackKey(title: state.title, artist: state.artist, videoId: state.videoId)
        guard !key.isEmpty else { return }

        let position = state.getAccurateTime()

        if key != sessionKey {
            beginSession(key: key, position: position)
        } else if sessionScrobbled && lastPosition - position > 20 && position < 5 {
            // Same track jumped back to the start after being scrobbled: repeat / replay = new listen.
            beginSession(key: key, position: position)
        }
        lastPosition = position

        guard state.isPlaying else { return }
        sessionListened += dt

        let track = ScrobbleTrack(
            title: meta.title,
            artist: meta.artist,
            album: state.album.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Int(state.duration.rounded()),
            startedAt: Int(sessionStart.timeIntervalSince1970)
        )

        if !sessionNowPlayingSent && sessionListened >= 3 {
            sessionNowPlayingSent = true
            sendNowPlaying(track)
        }

        if !sessionScrobbled,
           let required = ScrobbleRules.requiredListenTime(duration: state.duration),
           sessionListened >= required {
            sessionScrobbled = true
            submitScrobble(track)
        }
    }

    // MARK: - Delivery

    private func sendNowPlaying(_ track: ScrobbleTrack) {
        for provider in activeProviders() {
            guard let cred = credential(for: provider) else { continue }
            Task.detached {
                do {
                    try await ScrobbleManager.deliver(track, to: provider, credential: cred, nowPlaying: true)
                } catch ScrobbleError.unauthorized {
                    DispatchQueue.main.async { ScrobbleManager.shared.handleAuthFailure(provider) }
                } catch {
                    // "Now playing" is best effort: never queued, never retried.
                }
            }
        }
    }

    private func submitScrobble(_ track: ScrobbleTrack) {
        for provider in activeProviders() {
            guard let cred = credential(for: provider) else { continue }
            Task.detached {
                do {
                    try await ScrobbleManager.deliver(track, to: provider, credential: cred, nowPlaying: false)
                } catch ScrobbleError.retryable {
                    DispatchQueue.main.async { ScrobbleManager.shared.enqueue(track, for: provider) }
                } catch ScrobbleError.unauthorized {
                    DispatchQueue.main.async { ScrobbleManager.shared.handleAuthFailure(provider) }
                } catch {
                    // Rejected permanently (bad metadata etc.): drop it.
                }
            }
        }
    }

    private static func deliver(_ track: ScrobbleTrack,
                                to provider: ScrobbleProvider,
                                credential: String,
                                nowPlaying: Bool) async throws {
        switch provider {
        case .lastFM:
            if nowPlaying {
                try await LastFMService.updateNowPlaying(sessionKey: credential, track: track)
            } else {
                try await LastFMService.scrobble(sessionKey: credential, track: track)
            }
        case .listenBrainz:
            if nowPlaying {
                try await ListenBrainzService.playingNow(token: credential, track: track)
            } else {
                try await ListenBrainzService.scrobble(token: credential, track: track)
            }
        }
    }

    private func handleAuthFailure(_ provider: ScrobbleProvider) {
        guard isConnected(provider) else { return }
        disconnect(provider)
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
            text: "\(provider.displayName) login expired. Reconnect from Quick Controls."
        )
    }

    // MARK: - Retry queue

    private func enqueue(_ track: ScrobbleTrack, for provider: ScrobbleProvider) {
        pending.append(PendingScrobble(provider: provider, track: track))
        if pending.count > maxPending { pending.removeFirst(pending.count - maxPending) }
        savePending()
    }

    private func flushPending() {
        guard !isFlushing else { return }

        let cutoff = Int(Date().timeIntervalSince1970) - maxScrobbleAge
        let before = pending.count
        pending.removeAll { $0.track.startedAt < cutoff || !isConnected($0.provider) }
        if pending.count != before { savePending() }

        guard let item = pending.first, let cred = credential(for: item.provider) else { return }
        isFlushing = true

        Task.detached {
            var finished = false      // true = remove from queue
            var authFailed = false
            do {
                try await ScrobbleManager.deliver(item.track, to: item.provider, credential: cred, nowPlaying: false)
                finished = true
            } catch ScrobbleError.retryable {
                finished = false
            } catch ScrobbleError.unauthorized {
                authFailed = true
            } catch {
                finished = true       // rejected permanently
            }

            DispatchQueue.main.async {
                let manager = ScrobbleManager.shared
                manager.isFlushing = false
                if authFailed { manager.handleAuthFailure(item.provider); return }
                if finished {
                    manager.pending.removeAll { $0.id == item.id }
                    manager.savePending()
                    manager.flushPending()   // keep draining the queue
                }
            }
        }
    }

    private func loadPending() -> [PendingScrobble] {
        guard let data = defaults.data(forKey: pendingKey),
              let items = try? JSONDecoder().decode([PendingScrobble].self, from: data) else { return [] }
        return items
    }

    private func savePending() {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: pendingKey)
        }
    }
}
