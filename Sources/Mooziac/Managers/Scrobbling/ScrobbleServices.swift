import Foundation
import CryptoKit

private let scrobbleUserAgent: String = {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.6"
    return "Mooziac/\(v) (https://github.com/shirkeharsh/mooziac)"
}()

// MARK: - Last.fm

enum LastFMService {
    static let directEndpoint = "https://ws.audioscrobbler.com/2.0/"
    static let proxyEndpoint = "https://mooziac.pages.dev/api/lastfm"

    /// api_sig = md5( sorted "name+value" pairs, "format" and "callback" excluded, + secret )
    static func signature(for params: [String: String], secret: String) -> String {
        let base = params
            .filter { $0.key != "format" && $0.key != "callback" }
            .sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let digest = Insecure.MD5.hash(data: Data((base + secret).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func authURL(token: String) -> URL? {
        if ScrobbleConfig.hasLocalKeys {
            var c = URLComponents(string: "https://www.last.fm/api/auth/")
            c?.queryItems = [
                URLQueryItem(name: "api_key", value: ScrobbleConfig.lastFMAPIKey),
                URLQueryItem(name: "token", value: token)
            ]
            return c?.url
        } else {
            // Uses Cloudflare Pages serverless proxy which securely redirects to Last.fm with server-side key
            return URL(string: "\(proxyEndpoint)?action=auth&token=\(token)")
        }
    }

    static func getToken() async throws -> String {
        let json = try await call(["method": "auth.getToken"], post: false)
        guard let token = json["token"] as? String, !token.isEmpty else {
            throw ScrobbleError.rejected("Last.fm did not return a token.")
        }
        return token
    }

    static func getSession(token: String) async throws -> (name: String, key: String) {
        let json = try await call(["method": "auth.getSession", "token": token], post: false)
        guard let session = json["session"] as? [String: Any],
              let name = session["name"] as? String,
              let key = session["key"] as? String else {
            throw ScrobbleError.rejected("Last.fm did not return a session.")
        }
        return (name, key)
    }

    static func updateNowPlaying(sessionKey: String, track: ScrobbleTrack) async throws {
        var p: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "sk": sessionKey
        ]
        if !track.album.isEmpty { p["album"] = track.album }
        if track.duration > 0 { p["duration"] = String(track.duration) }
        _ = try await call(p, post: true)
    }

    static func scrobble(sessionKey: String, track: ScrobbleTrack) async throws {
        var p: [String: String] = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "timestamp": String(track.startedAt),
            "sk": sessionKey
        ]
        if !track.album.isEmpty { p["album"] = track.album }
        if track.duration > 0 { p["duration"] = String(track.duration) }
        _ = try await call(p, post: true)
    }

    // MARK: Plumbing

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private static func call(_ params: [String: String], post: Bool) async throws -> [String: Any] {
        var p = params
        let targetEndpoint: String

        if ScrobbleConfig.hasLocalKeys {
            p["api_key"] = ScrobbleConfig.lastFMAPIKey
            p["api_sig"] = signature(for: p, secret: ScrobbleConfig.lastFMSecret)
            p["format"] = "json"
            targetEndpoint = directEndpoint
        } else {
            // Cloudflare Pages proxy will add api_key, api_sig, and format=json server-side
            p["format"] = "json"
            targetEndpoint = proxyEndpoint
        }

        let body = formEncode(p)

        var request: URLRequest
        if post {
            guard let url = URL(string: targetEndpoint) else { throw ScrobbleError.rejected("Bad URL") }
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = Data(body.utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        } else {
            let delimiter = targetEndpoint.contains("?") ? "&" : "?"
            guard let url = URL(string: targetEndpoint + delimiter + body) else { throw ScrobbleError.rejected("Bad URL") }
            request = URLRequest(url: url)
        }
        request.timeoutInterval = 15
        request.setValue(scrobbleUserAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ScrobbleError.retryable(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        if let code = json?["error"] as? Int {
            let message = json?["message"] as? String ?? ""
            switch code {
            case 9: throw ScrobbleError.unauthorized              // invalid session key
            case 14: throw ScrobbleError.notAuthorizedYet         // token not authorised yet
            case 11, 16, 29: throw ScrobbleError.retryable(message) // service offline / temp error / rate limit
            default: throw ScrobbleError.rejected(message)
            }
        }
        if status >= 500 || status == 429 { throw ScrobbleError.retryable("Last.fm is unavailable (HTTP \(status)).") }
        guard let json = json else { throw ScrobbleError.retryable("Unexpected response from Last.fm.") }
        return json
    }
}

// MARK: - ListenBrainz

enum ListenBrainzService {
    private static let base = "https://api.listenbrainz.org/1"

    /// Returns the username that owns `token`, or throws `.unauthorized`.
    static func validate(token: String) async throws -> String {
        guard let url = URL(string: base + "/validate-token") else { throw ScrobbleError.rejected("Bad URL") }
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        let (json, status) = try await perform(request)
        if status == 401 { throw ScrobbleError.unauthorized }
        guard (json["valid"] as? Bool) == true, let user = json["user_name"] as? String else {
            throw ScrobbleError.unauthorized
        }
        return user
    }

    static func playingNow(token: String, track: ScrobbleTrack) async throws {
        try await submit(token: token, track: track, type: "playing_now")
    }

    static func scrobble(token: String, track: ScrobbleTrack) async throws {
        try await submit(token: token, track: track, type: "single")
    }

    private static func submit(token: String, track: ScrobbleTrack, type: String) async throws {
        guard let url = URL(string: base + "/submit-listens") else { throw ScrobbleError.rejected("Bad URL") }

        var info: [String: Any] = [
            "media_player": "Mooziac",
            "submission_client": "Mooziac"
        ]
        if track.duration > 0 { info["duration_ms"] = track.duration * 1000 }

        var metadata: [String: Any] = [
            "artist_name": track.artist,
            "track_name": track.title,
            "additional_info": info
        ]
        if !track.album.isEmpty { metadata["release_name"] = track.album }

        var listen: [String: Any] = ["track_metadata": metadata]
        if type == "single" { listen["listened_at"] = track.startedAt }

        let body: [String: Any] = ["listen_type": type, "payload": [listen]]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        let (json, status) = try await perform(request)
        switch status {
        case 200...299: return
        case 401: throw ScrobbleError.unauthorized
        case 429, 500...599: throw ScrobbleError.retryable("ListenBrainz is busy (HTTP \(status)).")
        default: throw ScrobbleError.rejected(json["error"] as? String ?? "HTTP \(status)")
        }
    }

    private static func perform(_ request: URLRequest) async throws -> ([String: Any], Int) {
        var req = request
        req.timeoutInterval = 15
        req.setValue(scrobbleUserAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if status >= 500 || status == 429 {
                throw ScrobbleError.retryable("ListenBrainz is busy (HTTP \(status)).")
            }
            return (json, status)
        } catch let error as ScrobbleError {
            throw error
        } catch {
            throw ScrobbleError.retryable(error.localizedDescription)
        }
    }
}
