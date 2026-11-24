import Foundation

// MARK: - Providers

enum ScrobbleProvider: String, CaseIterable, Codable {
    case lastFM = "lastfm"
    case listenBrainz = "listenbrainz"

    var displayName: String {
        switch self {
        case .lastFM: return "Last.fm"
        case .listenBrainz: return "ListenBrainz"
        }
    }

    /// Keychain account name under which this provider's secret is stored.
    var keychainAccount: String {
        switch self {
        case .lastFM: return "lastfm.sessionKey"
        case .listenBrainz: return "listenbrainz.userToken"
        }
    }
}

// MARK: - Errors

enum ScrobbleError: LocalizedError {
    /// Network failure, rate limit or server error: safe to try again later.
    case retryable(String)
    /// The service refused this request permanently (bad metadata etc.). Do not retry.
    case rejected(String)
    /// Token / session key is no longer valid. The user has to reconnect.
    case unauthorized
    /// Last.fm: the user has not approved the token in the browser yet.
    case notAuthorizedYet
    /// No Last.fm API key / secret configured in this build.
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .retryable(let m): return m.isEmpty ? "Network problem. Please try again." : m
        case .rejected(let m): return m.isEmpty ? "The service rejected the request." : m
        case .unauthorized: return "The saved login is no longer valid. Please connect again."
        case .notAuthorizedYet: return "Mooziac has not been approved on the Last.fm website yet."
        case .notConfigured: return "This build of Mooziac has no Last.fm API key."
        }
    }
}

// MARK: - Configuration

/// Last.fm requires every app to have its own API key + shared secret
/// (create one for free at https://www.last.fm/api/account/create).
///
/// Lookup order: Info.plist (`LastFMAPIKey` / `LastFMSharedSecret`),
/// environment (`MOOZIAC_LASTFM_API_KEY` / `MOOZIAC_LASTFM_SECRET`),
/// then UserDefaults (`Mooziac_lastfm_apiKey` / `Mooziac_lastfm_secret`).
/// Nothing is hard-coded so the secret never ends up in the public repo.
enum ScrobbleConfig {
    static var lastFMAPIKey: String {
        value(plist: "LastFMAPIKey", env: "MOOZIAC_LASTFM_API_KEY", defaults: "Mooziac_lastfm_apiKey")
    }

    static var lastFMSecret: String {
        value(plist: "LastFMSharedSecret", env: "MOOZIAC_LASTFM_SECRET", defaults: "Mooziac_lastfm_secret")
    }

    /// Whether this client build has direct developer keys baked in or configured locally.
    static var hasLocalKeys: Bool {
        !lastFMAPIKey.isEmpty && !lastFMSecret.isEmpty
    }

    /// Always true: if no local keys are present, the app seamlessly routes through
    /// Mooziac's Cloudflare Pages serverless proxy (https://mooziac.pages.dev/api/lastfm)
    /// keeping developer credentials secure.
    static var isLastFMConfigured: Bool {
        true
    }

    private static func value(plist: String, env: String, defaults: String) -> String {
        if let v = Bundle.main.object(forInfoDictionaryKey: plist) as? String, !v.isEmpty { return v }
        if let v = ProcessInfo.processInfo.environment[env], !v.isEmpty { return v }
        if let v = UserDefaults.standard.string(forKey: defaults), !v.isEmpty { return v }
        return ""
    }
}

// MARK: - Credential Store

/// Stores scrobble tokens (Last.fm session key & ListenBrainz user token) in UserDefaults.
/// This completely prevents macOS Keychain security prompts ("Mooziac wants to use your confidential information...")
/// from popping up on launch when using ad-hoc code signed distributions.
enum ScrobbleKeychain {
    private static let keyPrefix = "Mooziac_scrobble_credential_"

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        UserDefaults.standard.set(value, forKey: keyPrefix + account)
        return true
    }

    static func read(account: String) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + account)
    }

    static func delete(account: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + account)
    }
}

// MARK: - Track model

struct ScrobbleTrack: Codable, Equatable {
    var title: String
    var artist: String
    var album: String
    /// Track length in seconds (0 when unknown).
    var duration: Int
    /// Unix time (seconds) at which the track started playing.
    var startedAt: Int
}

struct PendingScrobble: Codable, Equatable {
    var id: UUID = UUID()
    var provider: ScrobbleProvider
    var track: ScrobbleTrack
}

// MARK: - Rules

enum ScrobbleRules {
    /// Standard Last.fm / ListenBrainz rule: tracks shorter than 30 s never scrobble;
    /// otherwise the listener must have played half the track or 4 minutes, whichever comes first.
    /// Returns nil when the track can not be scrobbled (too short / duration unknown).
    static func requiredListenTime(duration: Double) -> Double? {
        guard duration >= 30 else { return nil }
        return min(duration / 2.0, 240.0)
    }

    /// Turns raw YouTube-style metadata ("Starboy (Official Music Video) ft. Daft Punk")
    /// into clean scrobble metadata ("Starboy"). Returns nil if nothing usable is left.
    static func cleanedMetadata(title: String, artist: String) -> (title: String, artist: String)? {
        let rawTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanTitle = LyricsManager.cleanSongInfo(rawTitle)
        var cleanArtist = LyricsManager.cleanSongInfo(rawArtist)
        if cleanTitle.isEmpty { cleanTitle = rawTitle }
        if cleanArtist.isEmpty { cleanArtist = rawArtist }

        // YouTube auto-generated channels are called "Artist - Topic".
        cleanArtist = cleanArtist
            .replacingOccurrences(of: "(?i)\\s*-\\s*topic$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else { return nil }
        return (cleanTitle, cleanArtist)
    }
}
