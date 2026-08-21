import AppKit
import Foundation

public final class LyricsManager {
    public static let shared = LyricsManager()
    
    private let urlSession = URLSession.shared
    private var currentTask: URLSessionDataTask?
    private var currentRequestID = UUID()
    
    public private(set) var currentTrackKey: String = ""
    public private(set) var currentLRCLines: [LRCLine] = []
    
    public var onLyricsUpdated: (([LRCLine]) -> Void)?
    
    private init() {}
    
    // Clean Title/Artist while preserving Native Scripts (Devanagari, CJK, Spanish accents, etc.)
    public static func cleanSongInfo(_ text: String) -> String {
        var clean = text
        // Strip common YouTube fluff like (Official Video), (Audio), (Remastered), [Explicit], (Lyrical Video)
        clean = clean.replacingOccurrences(of: "(?i)[(\\[{].*?(official|video|audio|remastered|remaster|explicit|version|lyric|hd|4k|full song|video song).*?[)\\]}]", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?i)\\s+ft\\.?.*$", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?i)\\s+feat\\.?.*$", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Convert plain text lyrics into LRC lines spaced out evenly for scrollable viewing
    public static func convertPlainToLRCLines(_ plainText: String) -> [LRCLine] {
        let rawLines = plainText.components(separatedBy: .newlines)
        var lines: [LRCLine] = []
        var timestamp: Double = 0.0
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let nextTime = timestamp + 4.0
                lines.append(LRCLine(timestamp: timestamp, text: trimmed, nextTimestamp: nextTime))
                timestamp = nextTime
            }
        }
        return lines
    }
    
    // MARK: - Matching & Normalization
    
    // Tokenize a string for matching: lowercase, drop ASCII punctuation, keep native scripts,
    // keep tokens of length >= 3.
    private func normalizeForMatch(_ text: String) -> [String] {
        let lower = text.lowercased()
        var cleaned = ""
        for ch in lower {
            if ch.isASCII {
                if ch.isLetter || ch.isNumber || ch.isWhitespace {
                    cleaned.append(ch)
                }
            } else {
                cleaned.append(ch)
            }
        }
        let normalized = cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 3 }
    }
    
    private func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0.0 }
        let inter = a.intersection(b).count
        let union = a.union(b).count
        return union == 0 ? 0.0 : Double(inter) / Double(union)
    }
    
    private func isMeaningfulArtist(_ artist: String) -> Bool {
        let tokens = normalizeForMatch(artist)
        guard !tokens.isEmpty else { return false }
        let joined = tokens.joined(separator: " ")
        let placeholders: Set<String> = ["local audio", "unknown artist", "unknown", "various artists", "artist", "track artist"]
        return !placeholders.contains(joined)
    }
    
    // Returns a combined similarity score (higher = better) or nil when the result fails
    // the hard gates (duration, meaningful title similarity, artist agreement).
    private func matchScore(_ item: [String: Any], targetTitle: String, targetArtist: String, targetDuration: Double) -> Double? {
        // Hard duration gate when both are known
        if targetDuration > 5.0 {
            var itemDur: Double? = nil
            if let d = item["duration"] as? Double {
                itemDur = d
            } else if let num = item["duration"] as? NSNumber {
                itemDur = num.doubleValue
            }
            if let itemDur = itemDur, itemDur > 0, abs(itemDur - targetDuration) > 12.0 {
                return nil
            }
        }
        
        guard let itemTrack = item["trackName"] as? String else { return nil }
        let targetTokens = Set(normalizeForMatch(targetTitle))
        let itemTokens = Set(normalizeForMatch(itemTrack))
        guard !targetTokens.isEmpty, !itemTokens.isEmpty else { return nil }
        
        let titleSim = jaccard(targetTokens, itemTokens)
        guard titleSim >= 0.6 else { return nil }
        
        let itemArtist = (item["artistName"] as? String) ?? ""
        let targetMeaningful = isMeaningfulArtist(targetArtist)
        let itemMeaningful = isMeaningfulArtist(itemArtist)
        
        var artistSim: Double = 1.0
        if targetMeaningful && itemMeaningful {
            let targetArtistTokens = Set(normalizeForMatch(targetArtist))
            let itemArtistTokens = Set(normalizeForMatch(itemArtist))
            artistSim = jaccard(targetArtistTokens, itemArtistTokens)
            let contained = targetArtistTokens.isSubset(of: itemArtistTokens) || itemArtistTokens.isSubset(of: targetArtistTokens)
            guard artistSim >= 0.4 || contained else { return nil }
        } else if targetMeaningful != itemMeaningful {
            // Artist information incomplete on one side — require a strong title match
            guard titleSim >= 0.8 else { return nil }
            artistSim = titleSim
        }
        
        return (0.65 * titleSim) + (0.35 * artistSim)
    }
    
    private func isResultMatch(_ item: [String: Any], targetTitle: String, targetArtist: String, targetDuration: Double) -> Bool {
        return matchScore(item, targetTitle: targetTitle, targetArtist: targetArtist, targetDuration: targetDuration) != nil
    }
    
    // Pick the best-scoring result that passes validation, preferring synced or plain lyrics.
    private func bestPassingResult(in results: [[String: Any]], preferSynced: Bool, targetTitle: String, targetArtist: String, targetDuration: Double) -> [String: Any]? {
        var best: [String: Any]? = nil
        var bestScore = -1.0
        for item in results {
            if preferSynced {
                guard let s = item["syncedLyrics"] as? String, !s.isEmpty else { continue }
            } else {
                guard let p = item["plainLyrics"] as? String, !p.isEmpty else { continue }
            }
            guard let score = matchScore(item, targetTitle: targetTitle, targetArtist: targetArtist, targetDuration: targetDuration) else { continue }
            if score > bestScore {
                bestScore = score
                best = item
            }
        }
        return best
    }
    
    // MARK: - Cache Identity
    
    // Collision-resistant identity: track/video ID when available, otherwise
    // normalized title + normalized artist + duration.
    private func strongTrackKey(trackID: String, title: String, artist: String, duration: Double) -> String {
        if !trackID.isEmpty {
            return "VID:" + trackID
        }
        let t = LyricsManager.cleanSongInfo(title).lowercased()
        let a = LyricsManager.cleanSongInfo(artist).lowercased()
        let d = duration > 0 ? String(Int(duration)) : "0"
        return "TRACK:\(t)|\(a)|\(d)"
    }
    
    private func strongCacheFilename(trackID: String, cleanTitle: String, cleanArtist: String, duration: Double) -> String {
        let sanitize: (String) -> String = { s in
            s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        }
        if !trackID.isEmpty {
            return "vid_" + sanitize(trackID) + ".lrc"
        }
        let t = cleanTitle.isEmpty ? "untitled" : cleanTitle
        let a = cleanArtist.isEmpty ? "unknown" : cleanArtist
        let d = duration > 0 ? String(Int(duration)) : "0"
        return sanitize("\(t)_\(a)_\(d)") + ".lrc"
    }
    
    // A local .lrc file only matches when its filename confidently corresponds to the track:
    // exact/near-exact title tokens, and when an "Artist - Title" prefix is present the artist
    // tokens must agree. Arbitrary substring matches are rejected.
    private func confidentLRCNameMatch(fname: String, cleanTitle: String, cleanArtist: String) -> Bool {
        let titleTokens = Set(normalizeForMatch(cleanTitle))
        guard !titleTokens.isEmpty else { return false }
        
        var titlePart = fname
        var artistPart = ""
        let separator = " - "
        if let range = fname.range(of: separator) {
            artistPart = String(fname[..<range.lowerBound])
            titlePart = String(fname[range.upperBound...])
        }
        
        let nameTokens = Set(normalizeForMatch(titlePart))
        guard !nameTokens.isEmpty else { return false }
        let titleSim = jaccard(titleTokens, nameTokens)
        guard titleSim >= 0.8 else { return false }
        
        if !artistPart.isEmpty {
            let artistTokens = Set(normalizeForMatch(cleanArtist))
            if !artistTokens.isEmpty {
                let artistNameTokens = Set(normalizeForMatch(artistPart))
                let artistSim = jaccard(artistTokens, artistNameTokens)
                guard artistSim >= 0.5 else { return false }
            }
        }
        return true
    }
    
    public func fetchLyrics(artist: String, title: String, duration: Double = 0.0, trackID: String = "", completion: @escaping (String?, [LRCLine]) -> Void) {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)
        let trackKey = strongTrackKey(trackID: trackID, title: cleanTitle, artist: cleanArtist, duration: duration)
        
        if trackKey == currentTrackKey && !currentLRCLines.isEmpty {
            completion(nil, currentLRCLines)
            return
        }
        
        currentTask?.cancel()
        let requestID = UUID()
        currentRequestID = requestID
        currentTrackKey = trackKey
        currentLRCLines = []

        // Tier 0: Check Local .lrc files (Direct sidecars, Library tracks, and Music folder)
        var localLrcCandidates: [URL] = []
        if let offlineTrack = NativeAudioPlayer.shared.currentTrack {
            let sidecar = offlineTrack.fileURL.deletingPathExtension().appendingPathExtension("lrc")
            localLrcCandidates.append(sidecar)
            if let assigned = offlineTrack.lrcURL {
                localLrcCandidates.append(assigned)
            }
        }

        let musicFolder = LocalLibraryManager.shared.musicFolderURL
        let directFromMusic = musicFolder.appendingPathComponent("\(cleanArtist) - \(cleanTitle).lrc")
        let titleOnlyFromMusic = musicFolder.appendingPathComponent("\(cleanTitle).lrc")
        localLrcCandidates.append(directFromMusic)
        localLrcCandidates.append(titleOnlyFromMusic)

        // Confident match any .lrc file in ~/Music/Mooziac (no arbitrary substring matches)
        if let items = try? FileManager.default.contentsOfDirectory(at: musicFolder, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension.lowercased() == "lrc" {
                let fname = item.deletingPathExtension().lastPathComponent.lowercased()
                if confidentLRCNameMatch(fname: fname, cleanTitle: cleanTitle.lowercased(), cleanArtist: cleanArtist.lowercased()) {
                    localLrcCandidates.append(item)
                }
            }
        }

        // Tier 0.5: Check Local Cache directory (~/Library/Caches/Mooziac/Lyrics/)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Mooziac/Lyrics", isDirectory: true)
        let cacheFilename = strongCacheFilename(trackID: trackID, cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration)
        if let cacheDir = cacheDir {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            localLrcCandidates.append(cacheDir.appendingPathComponent(cacheFilename))
        }

        for candidate in localLrcCandidates {
            if FileManager.default.fileExists(atPath: candidate.path),
               let lrcContent = try? String(contentsOf: candidate, encoding: .utf8),
               !lrcContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parsedLines = SyncedLyricsParser.parse(lrcText: lrcContent)
                if !parsedLines.isEmpty {
                    print("[LyricsManager] Found local offline LRC file: \(candidate.lastPathComponent) with \(parsedLines.count) lines")
                    self.currentLRCLines = parsedLines
                    let cleanText = lrcContent.replacingOccurrences(of: "\\[\\d+:\\d+[\\.:]?\\d*\\]", with: "", options: .regularExpression)
                    DispatchQueue.main.async {
                        self.onLyricsUpdated?(parsedLines)
                        completion(cleanText.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                    }
                    return
                }
            }
        }
        
        guard NetworkMonitor.shared.isReachable else {
            print("[LyricsManager] Offline: skipping network lyrics fetch")
            completion("Offline: Internet connection required for lyrics", [])
            return
        }
        
        guard !cleanTitle.isEmpty else {
            completion(nil, [])
            return
        }
        
        // Tier 1: Direct Exact Lookup on LRCLib
        let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let getUrlStr = "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)"
        if let url = URL(string: getUrlStr) {
            let task = urlSession.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { return }
                // Stale/cancelled request: never apply and never start a fallback for an old track.
                guard requestID == self.currentRequestID else { return }
                
                if let data = data, error == nil,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if self.isResultMatch(json, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration) {
                        if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                            let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                            self.currentLRCLines = parsedLines
                            self.saveToLocalLyricsCache(filename: cacheFilename, lrcText: syncedLyrics)
                            let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+\\.\\d+\\]", with: "", options: .regularExpression)
                            DispatchQueue.main.async {
                                self.onLyricsUpdated?(parsedLines)
                                completion(cleanText.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                            }
                            return
                        } else if let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.isEmpty {
                            let parsedLines = LyricsManager.convertPlainToLRCLines(plainLyrics)
                            self.currentLRCLines = parsedLines
                            self.saveToLocalLyricsCache(filename: cacheFilename, lrcText: plainLyrics)
                            DispatchQueue.main.async {
                                self.onLyricsUpdated?(parsedLines)
                                completion(plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                            }
                            return
                        }
                    }
                }
                
                // Tier 2: Search LRCLib with title + artist
                self.searchLRCLibFallback(requestID: requestID, artist: cleanArtist, title: cleanTitle, duration: duration, completion: completion)
            }
            currentTask = task
            task.resume()
        } else {
            searchLRCLibFallback(requestID: requestID, artist: cleanArtist, title: cleanTitle, duration: duration, completion: completion)
        }
    }
    
    private func searchLRCLibFallback(requestID: UUID, artist: String, title: String, duration: Double, completion: @escaping (String?, [LRCLine]) -> Void) {
        let query = "\(title) \(artist)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            searchLRCLibTitleOnly(requestID: requestID, title: title, artist: artist, duration: duration, completion: completion)
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard requestID == self.currentRequestID else { return }
            if let data = data, error == nil,
               let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                // First pass: best verified synced lyrics
                if let item = self.bestPassingResult(in: results, preferSynced: true, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                    self.currentLRCLines = parsedLines
                    let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+\\.\\d+\\]", with: "", options: .regularExpression)
                    DispatchQueue.main.async {
                        self.onLyricsUpdated?(parsedLines)
                        completion(cleanText.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                    }
                    return
                }
                
                // Second pass: best verified plain lyrics
                if let item = self.bestPassingResult(in: results, preferSynced: false, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let plainLyrics = item["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    let parsedLines = LyricsManager.convertPlainToLRCLines(plainLyrics)
                    self.currentLRCLines = parsedLines
                    DispatchQueue.main.async {
                        self.onLyricsUpdated?(parsedLines)
                        completion(plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                    }
                    return
                }
            }
            
            // Tier 3: Search with title ONLY
            self.searchLRCLibTitleOnly(requestID: requestID, title: title, artist: artist, duration: duration, completion: completion)
        }.resume()
    }
    
    private func searchLRCLibTitleOnly(requestID: UUID, title: String, artist: String, duration: Double, completion: @escaping (String?, [LRCLine]) -> Void) {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedTitle)") else {
            fetchLyricsOVHFallback(requestID: requestID, artist: artist, title: title, completion: completion)
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard requestID == self.currentRequestID else { return }
            if let data = data, error == nil,
               let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                if let item = self.bestPassingResult(in: results, preferSynced: true, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                    self.currentLRCLines = parsedLines
                    let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+\\.\\d+\\]", with: "", options: .regularExpression)
                    DispatchQueue.main.async {
                        self.onLyricsUpdated?(parsedLines)
                        completion(cleanText.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                    }
                    return
                } else if let item = self.bestPassingResult(in: results, preferSynced: false, targetTitle: title, targetArtist: artist, targetDuration: duration),
                          let plainLyrics = item["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    let parsedLines = LyricsManager.convertPlainToLRCLines(plainLyrics)
                    self.currentLRCLines = parsedLines
                    DispatchQueue.main.async {
                        self.onLyricsUpdated?(parsedLines)
                        completion(plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
                    }
                    return
                }
            }
            
            // Tier 4: Lyrics.ovh final fallback
            self.fetchLyricsOVHFallback(requestID: requestID, artist: artist, title: title, completion: completion)
        }.resume()
    }
    
    private func fetchLyricsOVHFallback(requestID: UUID, artist: String, title: String, completion: @escaping (String?, [LRCLine]) -> Void) {
        let cleanArtist = artist.isEmpty ? "Artist" : artist
        guard let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.lyrics.ovh/v1/\(encodedArtist)/\(encodedTitle)") else {
            DispatchQueue.main.async { completion(nil, []) }
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard requestID == self.currentRequestID else { return }
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lyrics = json["lyrics"] as? String, !lyrics.isEmpty else {
                DispatchQueue.main.async { completion(nil, []) }
                return
            }
            
            let parsedLines = LyricsManager.convertPlainToLRCLines(lyrics)
            self.currentLRCLines = parsedLines
            
            DispatchQueue.main.async {
                self.onLyricsUpdated?(parsedLines)
                completion(lyrics.trimmingCharacters(in: .whitespacesAndNewlines), parsedLines)
            }
        }.resume()
    }

    private func saveToLocalLyricsCache(filename: String, lrcText: String) {
        guard !lrcText.isEmpty else { return }
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Mooziac/Lyrics", isDirectory: true)
        if let cacheDir = cacheDir {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let cachedLrcURL = cacheDir.appendingPathComponent(filename)
            try? lrcText.write(to: cachedLrcURL, atomically: true, encoding: .utf8)
        }
    }

    public func fetchRawSyncedLRC(artist: String, title: String, duration: Double = 0.0, expectedTrackID: String = "", completion: @escaping (String?) -> Void) {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)
        
        let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let getUrlStr = "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)"
        guard let url = URL(string: getUrlStr) else {
            completion(nil)
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            if !expectedTrackID.isEmpty,
               LocalDatabaseManager.shared.fetchAllRecords().values
                   .contains(where: { $0.ytVideoId == expectedTrackID }) == false {
                completion(nil)
                return
            }
            if let data = data, error == nil,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               self.isResultMatch(json, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration) {
                if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                    completion(synced)
                    return
                } else if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                    completion(plain)
                    return
                }
            }
            
            // Fallback search — validated, best-scoring result only
            let query = "\(cleanTitle) \(cleanArtist)"
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let searchUrl = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") {
                self.urlSession.dataTask(with: searchUrl) { sData, _, sErr in
                    if !expectedTrackID.isEmpty,
                       LocalDatabaseManager.shared.fetchAllRecords().values
                           .contains(where: { $0.ytVideoId == expectedTrackID }) == false {
                        completion(nil)
                        return
                    }
                    if let sData = sData, sErr == nil,
                       let results = try? JSONSerialization.jsonObject(with: sData) as? [[String: Any]] {
                        if let item = self.bestPassingResult(in: results, preferSynced: true, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration),
                           let synced = item["syncedLyrics"] as? String, !synced.isEmpty {
                            completion(synced)
                            return
                        }
                        if let item = self.bestPassingResult(in: results, preferSynced: false, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration),
                           let plain = item["plainLyrics"] as? String, !plain.isEmpty {
                            completion(plain)
                            return
                        }
                    }
                    completion(nil)
                }.resume()
            } else {
                completion(nil)
            }
        }.resume()
    }
}