import Foundation
import WebKit
import CryptoKit

/// Thin client for YouTube Music's internal InnerTube API.
///
/// The app authenticates through the embedded WKWebView, so the user's session
/// cookies (SAPISID etc.) already live in `WKWebsiteDataStore.default()`. We read
/// those cookies and replay them on the same API the YTM web player uses. No API
/// key, no registration, no cost — the public web-client key is hardcoded below.
///
/// Everything here runs off the main thread. Completion callbacks are delivered on
/// the calling queue unless otherwise noted.
public final class YTMClient {

    public static let shared = YTMClient()

    // Public web-client API key used by the YouTube Music web player. It is a
    // well-known public constant (also published by yt-dlp / ytmusicapi).
    private static let innerTubeAPIKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private static let baseURL = "https://music.youtube.com/youtubei/v1"

    private static let clientContext: [String: Any] = [
        "client": [
            "clientName": "WEB_REMIX",
            "clientVersion": "1.20240902.01.00",
            "hl": "en",
            "gl": "US"
        ]
    ]

    public struct PlaylistSummary {
        public let playlistId: String
        public let browseId: String
        public let title: String
    }

    public struct PlaylistDetail {
        public let playlistId: String
        public let title: String
        public let tracks: [Track]
    }

    public struct Track {
        public let videoId: String
        public let title: String
        public let artist: String
        public let album: String
        public let artworkUrl: String
        public let duration: String
    }

    public enum YTMError: Error {
        case notSignedIn
        case network(String)
        case badResponse
        case api(String)
    }

    private init() {}

    // MARK: - Auth (cookies + SAPISIDHASH)

    private struct AuthCredentials {
        let authorization: String
        let cookie: String
    }

    /// Reads the session cookies from the shared WKWebView data store and returns
    /// the `Authorization` header value and `Cookie` string for InnerTube requests.
    private func authCredentials(completion: @escaping (Result<AuthCredentials, Error>) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let sapisid = cookies.first(where: { $0.name == "SAPISID" && $0.domain.contains("youtube.com") && !$0.value.isEmpty })?.value
            let apiSID = cookies.first(where: {
                $0.name == "__Secure-1PAPISID" && $0.domain.contains("youtube.com") && !$0.value.isEmpty
            })?.value

            let authValue = sapisid ?? apiSID
            guard let authValue = authValue, !authValue.isEmpty else {
                completion(.failure(YTMError.notSignedIn))
                return
            }

            let origin = "https://music.youtube.com"
            let timestamp = Int(Date().timeIntervalSince1970)
            let msg = "\(timestamp) \(authValue) \(origin)"
            let hash = Self.sha1Hex(msg)
            let header = "SAPISIDHASH \(timestamp)_\(hash)"

            let cookieString = cookies
                .filter { $0.domain.contains("youtube.com") || $0.domain.contains("google.com") }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")

            completion(.success(AuthCredentials(authorization: header, cookie: cookieString)))
        }
    }

    private static func sha1Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Core request

    @discardableResult
    private func post(
        endpoint: String,
        payload: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) -> URLSessionDataTask? {
        guard let url = URL(string: "\(Self.baseURL)/\(endpoint)?alt=json&key=\(Self.innerTubeAPIKey)") else {
            completion(.failure(YTMError.badResponse))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(YTMWebViewContainer.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("0", forHTTPHeaderField: "X-Goog-AuthUser")

        var body = payload
        body["context"] = Self.clientContext

        authCredentials { result in
            if case .success(let creds) = result {
                request.setValue(creds.authorization, forHTTPHeaderField: "Authorization")
                if !creds.cookie.isEmpty {
                    request.setValue(creds.cookie, forHTTPHeaderField: "Cookie")
                }
            }
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(YTMError.network(error.localizedDescription)))
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let data = data else {
                    completion(.failure(YTMError.badResponse))
                    return
                }
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(YTMError.badResponse))
                        return
                    }
                    completion(.success(json))
                } catch {
                    Log.sync.error("YTM JSON parse error: \(error.localizedDescription)")
                    completion(.failure(YTMError.badResponse))
                }
            }
            task.resume()
        }
        return nil
    }

    // MARK: - Browse (lists + contents + continuations)

    public func browse(browseId: String, continuation: String? = nil,
                       completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var payload: [String: Any]
        if let continuation = continuation {
            payload = ["continuation": continuation]
        } else {
            payload = ["browseId": browseId]
        }
        post(endpoint: "browse", payload: payload, completion: completion)
    }

    /// Fetches every playlist on the signed-in account (merge loop included).
    public func fetchAccountPlaylists(completion: @escaping (Result<[PlaylistSummary], Error>) -> Void) {
        fetchAllBrowsePages(browseId: "FEmusic_liked_playlists") { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let pages):
                var seen = Set<String>()
                var playlists: [PlaylistSummary] = []
                for page in pages {
                    for p in Self.parsePlaylistSummaries(from: page) where !seen.contains(p.playlistId) {
                        seen.insert(p.playlistId)
                        playlists.append(p)
                    }
                }
                completion(.success(playlists))
            }
        }
    }

    /// Fetches all tracks in a playlist or the liked-songs list.
    public func fetchTracks(browseId: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        fetchAllBrowsePages(browseId: browseId) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let pages):
                var seen = Set<String>()
                var tracks: [Track] = []
                for page in pages {
                    for t in Self.parseTracks(from: page) where !seen.contains(t.videoId) {
                        seen.insert(t.videoId)
                        tracks.append(t)
                    }
                }
                completion(.success(tracks))
            }
        }
    }

    /// Fetches all details (title and tracks) for any public, unlisted, or account playlist.
    public func fetchPlaylistDetails(playlistId: String, pageLimit: Int = 15,
                                     completion: @escaping (Result<PlaylistDetail, Error>) -> Void) {
        let cleanId = playlistId.replacingOccurrences(of: "VL", with: "")
        let browseId = "VL\(cleanId)"
        fetchAllBrowsePages(browseId: browseId, pageLimit: pageLimit) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let pages):
                guard let firstPage = pages.first else {
                    completion(.failure(YTMError.badResponse))
                    return
                }
                let title = Self.parsePlaylistTitle(from: firstPage)
                var seen = Set<String>()
                var tracks: [Track] = []
                for page in pages {
                    for t in Self.parseTracks(from: page) where !seen.contains(t.videoId) {
                        seen.insert(t.videoId)
                        tracks.append(t)
                    }
                }
                completion(.success(PlaylistDetail(playlistId: cleanId, title: title, tracks: tracks)))
            }
        }
    }

    /// Fetches single track details (title, artist, artwork, duration) from public oEmbed with player fallback.
    public func fetchTrackDetails(videoId: String, completion: @escaping (Result<Track, Error>) -> Void) {
        guard let oembedURL = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json") else {
            completion(.failure(YTMError.badResponse))
            return
        }

        let task = URLSession.shared.dataTask(with: oembedURL) { [weak self] data, response, error in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let rawTitle = json["title"] as? String ?? "YouTube Track"
                var author = json["author_name"] as? String ?? ""
                var title = rawTitle

                if rawTitle.contains(" - ") {
                    let parts = rawTitle.components(separatedBy: " - ")
                    if parts.count >= 2 {
                        let potentialArtist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let potentialTitle = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !potentialArtist.isEmpty && !potentialTitle.isEmpty {
                            author = potentialArtist
                            title = potentialTitle
                        }
                    }
                }

                        let cleanedTitle = title
                            .replacingOccurrences(of: "(Official Video)", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "(Official Music Video)", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "[Official Music Video]", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "(Official Audio)", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "[Official Audio]", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "(Audio)", with: "", options: .caseInsensitive)
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        let artworkUrl = (json["thumbnail_url"] as? String) ?? "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"

                        completion(.success(Track(
                            videoId: videoId,
                            title: cleanedTitle.isEmpty ? rawTitle : cleanedTitle,
                            artist: author,
                            album: "",
                            artworkUrl: artworkUrl,
                            duration: ""
                        )))
                        return
                    }
                } catch {
                    Log.sync.debug("oEmbed JSON parsing failed, falling back to player endpoint: \(error.localizedDescription)")
                }
            }

            // Fallback to InnerTube player endpoint
            let payload: [String: Any] = ["videoId": videoId]
            self?.post(endpoint: "player", payload: payload) { result in
                switch result {
                case .failure(let err):
                    completion(.failure(err))
                case .success(let json):
                    if let details = json["videoDetails"] as? [String: Any] {
                        let title = details["title"] as? String ?? "YouTube Track"
                        let artist = details["author"] as? String ?? ""
                        let artworkUrl = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
                        completion(.success(Track(
                            videoId: videoId,
                            title: title,
                            artist: artist,
                            album: "",
                            artworkUrl: artworkUrl,
                            duration: ""
                        )))
                    } else {
                        completion(.failure(YTMError.badResponse))
                    }
                }
            }
        }
        task.resume()
    }

    // MARK: - Search

    /// Searches YouTube Music via the InnerTube API for the best matching song/video.
    /// Returns the top track with its videoId, title, artist, and artwork.
    public func searchTopTrack(query: String, completion: @escaping (Result<Track, Error>) -> Void) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            completion(.failure(YTMError.badResponse))
            return
        }

        let payload: [String: Any] = ["query": cleanQuery]
        post(endpoint: "search", payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let json):
                if let track = Self.parseTopTrack(from: json) {
                    completion(.success(track))
                } else {
                    // Fallback to searching with filtered "Songs" parameter
                    let songPayload: [String: Any] = [
                        "query": cleanQuery,
                        "params": "EgWKAQIIAWoSEAUQDhAJEAMQEBAKEAQQFRAR"
                    ]
                    self.post(endpoint: "search", payload: songPayload) { secondResult in
                        switch secondResult {
                        case .failure(let secondErr):
                            completion(.failure(secondErr))
                        case .success(let secondJson):
                            if let songTrack = Self.parseTopTrack(from: secondJson) {
                                completion(.success(songTrack))
                            } else {
                                completion(.failure(YTMError.badResponse))
                            }
                        }
                    }
                }
            }
        }
    }

    /// Loops through `continuation` tokens until the response stops returning one
    /// (capped at a sane page count so a huge library can't spin forever).
    private func fetchAllBrowsePages(browseId: String, pageLimit: Int = 10,
                                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        var pages: [[String: Any]] = []

        func next(_ continuation: String?) {
            let payload: [String: Any]
            if let continuation = continuation {
                payload = ["continuation": continuation]
            } else {
                payload = ["browseId": browseId]
            }
            post(endpoint: "browse", payload: payload) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let json):
                    if pages.isEmpty {
                        Self.dumpDebugPage(json, browseId: browseId)
                    }
                    pages.append(json)
                    let token = Self.continuationToken(in: json)
                    if let token = token, !token.isEmpty, pages.count < pageLimit {
                        next(token)
                    } else {
                        completion(.success(pages))
                    }
                }
            }
        }
        next(nil)
    }

    // MARK: - Playlist mutation

    public func createPlaylist(title: String, videoIds: [String],
                               completion: @escaping (Result<String, Error>) -> Void) {
        let payload: [String: Any] = [
            "title": title,
            "videoIds": videoIds
        ]
        post(endpoint: "playlist/create", payload: payload) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let json):
                if let pid = json["playlistId"] as? String, !pid.isEmpty {
                    completion(.success(pid))
                } else if let pid = Self.findFirstString(in: json, key: "playlistId", prefix: "PL") {
                    completion(.success(pid))
                } else {
                    completion(.failure(YTMError.api("Playlist created but no id returned")))
                }
            }
        }
    }

    public func addToPlaylist(playlistId: String, videoIds: [String],
                              completion: @escaping (Result<Void, Error>) -> Void) {
        guard !videoIds.isEmpty else {
            completion(.success(()))
            return
        }
        let payload: [String: Any] = [
            "playlistId": playlistId,
            "videoIds": videoIds
        ]
        post(endpoint: "playlist/add", payload: payload) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(()))
            }
        }
    }

    public func like(videoId: String, liked: Bool,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        let endpoint = liked ? "like/like" : "like/removeLike"
        let payload: [String: Any] = ["target": ["videoId": videoId]]
        post(endpoint: endpoint, payload: payload) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(()))
            }
        }
    }

    // MARK: - Tolerant JSON extraction

    /// Temporary debug aid: writes the first browse response for a given browseId
    /// to a file in /tmp so response shape can be inspected while testing. Remove
    /// once the sync is confirmed working.
    private static func dumpDebugPage(_ json: [String: Any], browseId: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            guard let string = String(data: data, encoding: .utf8) else { return }
            let safe = browseId.replacingOccurrences(of: "/", with: "_")
            let url = URL(fileURLWithPath: "/tmp/ytm_\(safe).json")
            try string.write(to: url, atomically: true, encoding: .utf8)
            Log.web.debug("Dumped \(browseId) response to \(url.path)")
        } catch {
            Log.web.debug("Failed to dump debug page for \(browseId): \(error.localizedDescription)")
        }
    }

    /// DFS that collects every dictionary in a JSON tree.
    private static func collectDicts(_ value: Any?, into result: inout [[String: Any]]) {
        guard let value = value else { return }
        if let dict = value as? [String: Any] {
            result.append(dict)
            for (_, v) in dict {
                collectDicts(v, into: &result)
            }
        } else if let arr = value as? [Any] {
            for v in arr {
                collectDicts(v, into: &result)
            }
        }
    }

    /// DFS for the first string value for a key (optionally prefix-filtered).
    private static func findFirstString(in dict: [String: Any], key: String, prefix: String? = nil) -> String? {
        if let v = dict[key] as? String, prefix == nil || v.hasPrefix(prefix ?? "") {
            return v
        }
        for (k, v) in dict {
            if k == key, let s = v as? String, prefix == nil || s.hasPrefix(prefix ?? "") {
                return s
            }
            if let sub = v as? [String: Any], let found = findFirstString(in: sub, key: key, prefix: prefix) {
                return found
            }
            if let arr = v as? [Any] {
                for item in arr {
                    if let sub = item as? [String: Any], let found = findFirstString(in: sub, key: key, prefix: prefix) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    /// Pulls plain text out of a YTM "text" dict (handles `runs` and `simpleText`).
    private static func textFrom(_ value: Any?) -> String {
        guard let value = value else { return "" }
        if let dict = value as? [String: Any] {
            if let runs = dict["runs"] as? [[String: Any]] {
                return runs.compactMap { $0["text"] as? String }.joined()
            }
            if let simpleText = dict["simpleText"] as? String {
                return simpleText
            }
        }
        if let s = value as? String { return s }
        return ""
    }

    /// Title of a list item. Lives either in a direct `title` key
    /// (`gridPlaylistRenderer`) or in `flexColumns[0]` (list view).
    private static func listItemTitle(_ dict: [String: Any]) -> String {
        let t = textFrom(dict["title"])
        if !t.isEmpty { return t }
        if let flex = dict["flexColumns"] as? [[String: Any]], !flex.isEmpty,
           let col = flex[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] {
            return textFrom(col["text"])
        }
        return ""
    }

    /// Extracts the playlist's own title from the top-level browse page response.
    public static func parsePlaylistTitle(from page: [String: Any]) -> String {
        if let header = page["header"] as? [String: Any] {
            if let respHeader = header["musicResponsiveHeaderRenderer"] as? [String: Any],
               let title = respHeader["title"] as? [String: Any] {
                let t = textFrom(title)
                if !t.isEmpty { return t }
            }
            if let editHeader = header["musicEditablePlaylistDetailHeaderRenderer"] as? [String: Any],
               let innerHeader = editHeader["header"] as? [String: Any],
               let respHeader = innerHeader["musicResponsiveHeaderRenderer"] as? [String: Any],
               let title = respHeader["title"] as? [String: Any] {
                let t = textFrom(title)
                if !t.isEmpty { return t }
            }
            if let detailHeader = header["musicDetailHeaderRenderer"] as? [String: Any],
               let title = detailHeader["title"] as? [String: Any] {
                let t = textFrom(title)
                if !t.isEmpty { return t }
            }
        }
        if let microformat = page["microformat"] as? [String: Any],
           let microData = microformat["microformatDataRenderer"] as? [String: Any],
           let title = microData["title"] as? String, !title.isEmpty {
            return title
        }
        if let title = findFirstString(in: page, key: "title", prefix: nil), !title.isEmpty {
            return title
        }
        return "Imported Playlist"
    }

    private static func parsePlaylistSummaries(from page: [String: Any]) -> [PlaylistSummary] {
        var dicts: [[String: Any]] = []
        collectDicts(page, into: &dicts)

        var results: [PlaylistSummary] = []
        var seen = Set<String>()
        for dict in dicts {
            // Playlist identity: list view exposes it as a "VL..." browseId inside
            // navigationEndpoint; grid view has a direct "PL..." playlistId.
            var playlistId: String?
            var browseId: String?
            if let nav = dict["navigationEndpoint"] as? [String: Any],
               let browse = nav["browseEndpoint"] as? [String: Any],
               let b = browse["browseId"] as? String, b.hasPrefix("VL") {
                browseId = b
                playlistId = String(b.dropFirst(2))
            } else if let p = dict["playlistId"] as? String, p.hasPrefix("PL") {
                playlistId = p
                browseId = "VL\(p)"
            }
            guard let playlistId = playlistId, !playlistId.isEmpty, !seen.contains(playlistId) else { continue }
            let title = listItemTitle(dict)
            guard !title.isEmpty else { continue }
            seen.insert(playlistId)
            results.append(PlaylistSummary(playlistId: playlistId,
                                           browseId: browseId ?? "VL\(playlistId)",
                                           title: title))
        }
        return results
    }

    private static func parseTracks(from page: [String: Any]) -> [Track] {
        var dicts: [[String: Any]] = []
        collectDicts(page, into: &dicts)

        var results: [Track] = []
        var seen = Set<String>()

        for dict in dicts {
            // The owning renderer carries its own videoId in playlistItemData or a
            // watchEndpoint navigation. Prefer those, then fall back to a generic
            // DFS search, and validate the 11-char video id shape.
            let videoId: String? = {
                if let data = dict["playlistItemData"] as? [String: Any],
                   let v = data["videoId"] as? String, !v.isEmpty {
                    return v
                }
                if let nav = dict["navigationEndpoint"] as? [String: Any],
                   let watch = nav["watchEndpoint"] as? [String: Any],
                   let v = watch["videoId"] as? String, !v.isEmpty {
                    return v
                }
                if let v = dict["videoId"] as? String, v.count == 11 {
                    return v
                }
                if let found = findFirstString(in: dict, key: "videoId", prefix: ""),
                   found.count == 11 {
                    return found
                }
                return nil
            }()

            guard let videoId = videoId, !videoId.isEmpty, !seen.contains(videoId) else { continue }
            let title = listItemTitle(dict)
            guard !title.isEmpty else { continue }

            // Artist/album/duration live in flexColumns. Column 0 is the title,
            // column 1 is "Artist" or "Artist • Album", column 2 is the duration.
            var artist = ""
            var album = ""
            var duration = ""
            if let flexColumns = dict["flexColumns"] as? [[String: Any]] {
                if flexColumns.count >= 2,
                   let col = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] {
                    let t = textFrom(col["text"])
                    if !t.isEmpty {
                        let parts = t.components(separatedBy: " • ")
                        artist = parts[0]
                        if parts.count > 1 { album = parts.dropFirst().joined(separator: " • ") }
                    }
                } else if let col = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] {
                    let runs = (col["text"] as? [String: Any])?["runs"] as? [[String: Any]]
                    if let runs = runs, runs.count > 1 {
                        artist = runs.dropFirst().compactMap { $0["text"] as? String }.joined()
                    }
                }
            }
            if let lengthText = dict["lengthText"] {
                duration = textFrom(lengthText)
            }
            if let runs = (dict["lengthText"] as? [String: Any])?["runs"] as? [[String: Any]] {
                duration = runs.compactMap { $0["text"] as? String }.joined()
            }
            if duration.isEmpty, let flexColumns = dict["flexColumns"] as? [[String: Any]], flexColumns.count >= 3,
               let col = flexColumns[2]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] {
                duration = textFrom(col["text"])
            }

            var artworkUrl = ""
            if let thumbnail = dict["thumbnail"] as? [String: Any],
               let thumbs = thumbnail["thumbnails"] as? [[String: Any]],
               let last = thumbs.last, let url = last["url"] as? String {
                artworkUrl = url
            }

            seen.insert(videoId)
            results.append(Track(videoId: videoId, title: title, artist: artist,
                                 album: album, artworkUrl: artworkUrl, duration: duration))
        }
        return results
    }

    /// Finds a `continuationCommand.token` anywhere in the response.
    private static func continuationToken(in page: [String: Any]) -> String? {
        var dicts: [[String: Any]] = []
        collectDicts(page, into: &dicts)
        for dict in dicts {
            if dict["commandName"] as? String == "continuation" ||
                dict["token"] as? String != nil {
                if let cmd = dict["continuationCommand"] as? [String: Any],
                   let token = cmd["token"] as? String {
                    return token
                }
                if let token = dict["token"] as? String, !token.isEmpty {
                    return token
                }
            }
        }
        return nil
    }

    /// Parses the top matching song or video from an InnerTube search response.
    public static func parseTopTrack(from page: [String: Any]) -> Track? {
        guard let contents = page["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return nil
        }

        // 1. Check Top Card shelf (musicCardShelfRenderer)
        for s in sections {
            if let card = s["musicCardShelfRenderer"] as? [String: Any] {
                let title = textFrom(card["title"])
                let subtitle = textFrom(card["subtitle"])
                let isPodcast = subtitle.contains("Episode") || subtitle.contains("Podcast")

                if !isPodcast {
                    // Check direct onTap watchEndpoint
                    if let onTap = card["onTap"] as? [String: Any],
                       let watch = onTap["watchEndpoint"] as? [String: Any],
                       let vid = watch["videoId"] as? String, !vid.isEmpty {
                        return Track(videoId: vid, title: title, artist: subtitle, album: "", artworkUrl: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg", duration: "")
                    }

                    // Check card buttons for direct videoId (excluding radio/mix playlist)
                    if let buttons = card["buttons"] as? [[String: Any]] {
                        for b in buttons {
                            if let rend = b["buttonRenderer"] as? [String: Any] {
                                let nav = (rend["navigationEndpoint"] as? [String: Any]) ?? (rend["command"] as? [String: Any])
                                if let watch = nav?["watchEndpoint"] as? [String: Any],
                                   let vid = watch["videoId"] as? String, !vid.isEmpty {
                                    let plist = watch["playlistId"] as? String ?? ""
                                    if !plist.hasPrefix("RD") {
                                        return Track(videoId: vid, title: title, artist: subtitle, album: "", artworkUrl: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg", duration: "")
                                    }
                                }
                            }
                        }
                    }
                }

                // Check card contents (e.g. top songs list inside artist card)
                if let cardContents = card["contents"] as? [[String: Any]] {
                    for item in cardContents {
                        if let r = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let vid = extractVideoId(from: r) {
                            let itemTitle = listItemTitle(r)
                            return Track(videoId: vid, title: itemTitle.isEmpty ? title : itemTitle, artist: subtitle, album: "", artworkUrl: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg", duration: "")
                        }
                    }
                }
            }
        }

        // 2. Check general shelves (musicShelfRenderer or itemSectionRenderer)
        for s in sections {
            var candidateRenderers: [[String: Any]] = []
            if let shelf = s["musicShelfRenderer"] as? [String: Any] {
                if let items = shelf["contents"] as? [[String: Any]] {
                    for item in items {
                        if let r = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                            candidateRenderers.append(r)
                        }
                    }
                }
            } else if let isr = s["itemSectionRenderer"] as? [String: Any] {
                if let items = isr["contents"] as? [[String: Any]] {
                    for item in items {
                        if let r = item["musicResponsiveListItemRenderer"] as? [String: Any] {
                            candidateRenderers.append(r)
                        } else if let subShelf = item["musicShelfRenderer"] as? [String: Any],
                                  let subItems = subShelf["contents"] as? [[String: Any]] {
                            for subItem in subItems {
                                if let r = subItem["musicResponsiveListItemRenderer"] as? [String: Any] {
                                    candidateRenderers.append(r)
                                }
                            }
                        }
                    }
                }
            }

            for r in candidateRenderers {
                if let vid = extractVideoId(from: r) {
                    let title = listItemTitle(r)
                    var artist = ""
                    if let flexColumns = r["flexColumns"] as? [[String: Any]], flexColumns.count >= 2,
                       let col = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] {
                        let t = textFrom(col["text"])
                        if !t.isEmpty {
                            artist = t.components(separatedBy: " • ").first ?? ""
                        }
                    }
                    guard !title.isEmpty else { continue }
                    return Track(videoId: vid, title: title, artist: artist, album: "", artworkUrl: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg", duration: "")
                }
            }
        }

        return nil
    }

    private static func extractVideoId(from dict: [String: Any]) -> String? {
        if let data = dict["playlistItemData"] as? [String: Any],
           let vid = data["videoId"] as? String, !vid.isEmpty {
            return vid
        }
        if let overlay = dict["overlay"] as? [String: Any],
           let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = thumbOverlay["content"] as? [String: Any],
           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
           let nav = playBtn["playNavigationEndpoint"] as? [String: Any],
           let watch = nav["watchEndpoint"] as? [String: Any],
           let vid = watch["videoId"] as? String, !vid.isEmpty {
            return vid
        }
        if let nav = dict["navigationEndpoint"] as? [String: Any],
           let watch = nav["watchEndpoint"] as? [String: Any],
           let vid = watch["videoId"] as? String, !vid.isEmpty {
            return vid
        }
        if let vid = dict["videoId"] as? String, vid.count == 11 {
            return vid
        }
        return nil
    }
}