import AppKit
import Foundation

public final class LyricsManager {
    public static let shared = LyricsManager()
    
    private let urlSession = URLSession.shared
    private var currentTask: URLSessionDataTask?
    private var currentRequestID = UUID()
    
    public private(set) var currentTrackKey: String = ""
    public private(set) var currentLRCLines: [LRCLine] = []
    
    private var memoryCache: [String: (plainText: String?, lines: [LRCLine])] = [:]
    private let cacheLock = NSLock()
    
    public var onLyricsUpdated: (([LRCLine]) -> Void)?
    
    private init() {}
    
    public func clearSession() {
        currentTrackKey = ""
        currentLRCLines = []
    }

    private func storeInMemoryCache(key: String, plainText: String?, lines: [LRCLine]) {
        guard !lines.isEmpty else { return }
        cacheLock.lock()
        memoryCache[key] = (plainText, lines)
        cacheLock.unlock()
    }

    public func prefetchLyrics(artist: String, title: String, duration: Double = 0.0, trackID: String = "", videoId: String? = nil) {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)
        guard !cleanTitle.isEmpty else { return }
        let trackKey = strongTrackKey(trackID: trackID, title: cleanTitle, artist: cleanArtist, duration: duration)

        cacheLock.lock()
        let hasCache = memoryCache[trackKey] != nil
        cacheLock.unlock()
        if hasCache { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fetchLyrics(artist: artist, title: title, duration: duration, trackID: trackID, videoId: videoId) { _, _ in }
        }
    }
    
    // Clean Title/Artist while preserving Native Scripts (Devanagari, CJK, Spanish accents, etc.)
    public static func cleanSongInfo(_ text: String) -> String {
        var clean = text
        // Strip common YouTube fluff like (Official Video), (Audio), (Remastered), [Explicit], (Lyrical Video)
        clean = clean.replacingOccurrences(of: "(?i)[(\\[{].*?(official|video|audio|remastered|remaster|explicit|version|lyric|hd|4k|full song|video song).*?[)\\]}]", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?i)\\s+ft\\.?.*$", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?i)\\s+feat\\.?.*$", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Serialize LRCLine array back to standard LRC file content format
    public static func serializeLinesToLRC(lines: [LRCLine], title: String = "", artist: String = "") -> String {
        var out = ""
        if !title.isEmpty { out += "[ti:\(title)]\n" }
        if !artist.isEmpty { out += "[ar:\(artist)]\n" }
        for line in lines {
            let totalHundredths = Int(round(line.timestamp * 100))
            let min = totalHundredths / 6000
            let sec = (totalHundredths % 6000) / 100
            let hund = totalHundredths % 100
            let timeTag = String(format: "[%02d:%02d.%02d]", min, sec, hund)
            out += "\(timeTag)\(line.text)\n"
        }
        return out
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
        let t = LyricsManager.cleanSongInfo(title).lowercased()
        let a = LyricsManager.cleanSongInfo(artist).lowercased()
        let d = duration > 0 ? String(Int(duration)) : "0"
        if !trackID.isEmpty {
            return "VID:\(trackID)|\(t)"
        }
        return "TRACK:\(t)|\(a)|\(d)"
    }
    
    private func strongCacheFilename(trackID: String, cleanTitle: String, cleanArtist: String, duration: Double) -> String {
        let sanitize: (String) -> String = { s in
            s.replacingOccurrences(of: "/", with: "-")
             .replacingOccurrences(of: ":", with: "-")
             .replacingOccurrences(of: " ", with: "_")
        }
        let t = sanitize(cleanTitle.isEmpty ? "untitled" : cleanTitle)
        if !trackID.isEmpty {
            return "vid_\(sanitize(trackID))_\(t).lrc"
        }
        let a = sanitize(cleanArtist.isEmpty ? "unknown" : cleanArtist)
        let d = duration > 0 ? String(Int(duration)) : "0"
        return "\(t)_\(a)_\(d).lrc"
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
    
    private func deliverLyrics(trackKey: String, plainText: String?, lines: [LRCLine], completion: @escaping (String?, [LRCLine]) -> Void) {
        storeInMemoryCache(key: trackKey, plainText: plainText, lines: lines)
        if Thread.isMainThread {
            self.onLyricsUpdated?(lines)
            completion(plainText, lines)
        } else {
            DispatchQueue.main.async {
                self.onLyricsUpdated?(lines)
                completion(plainText, lines)
            }
        }
    }

    public func getCachedLRCLines(trackKey: String) -> [LRCLine]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return memoryCache[trackKey]?.lines
    }

    public func getCachedLRCLines(trackID: String, title: String, artist: String, duration: Double = 0.0) -> [LRCLine]? {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)
        let trackKey = strongTrackKey(trackID: trackID, title: cleanTitle, artist: cleanArtist, duration: duration)
        return getCachedLRCLines(trackKey: trackKey)
    }

    public func fetchLyrics(artist: String, title: String, duration: Double = 0.0, trackID: String = "", videoId: String? = nil, completion: @escaping (String?, [LRCLine]) -> Void) {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)
        let trackKey = strongTrackKey(trackID: trackID, title: cleanTitle, artist: cleanArtist, duration: duration)
        
        cacheLock.lock()
        if let cached = memoryCache[trackKey], !cached.lines.isEmpty {
            cacheLock.unlock()
            self.currentTrackKey = trackKey
            self.currentLRCLines = cached.lines
            if Thread.isMainThread {
                self.onLyricsUpdated?(cached.lines)
                completion(cached.plainText, cached.lines)
            } else {
                DispatchQueue.main.async {
                    self.onLyricsUpdated?(cached.lines)
                    completion(cached.plainText, cached.lines)
                }
            }
            return
        }
        cacheLock.unlock()

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
        // ONLY check offline player sidecar if in offline mode AND the track matches
        if NowPlayingManager.shared.engineMode == .offline,
           let offlineTrack = NativeAudioPlayer.shared.currentTrack {
            let cleanOfflineTitle = LyricsManager.cleanSongInfo(offlineTrack.title).lowercased()
            let matchesTrack = !trackID.isEmpty
                ? (trackID == offlineTrack.id || trackID == offlineTrack.ytVideoId)
                : (cleanOfflineTitle == cleanTitle.lowercased() || offlineTrack.title.lowercased() == title.lowercased())

            if matchesTrack {
                let sidecar = offlineTrack.fileURL.deletingPathExtension().appendingPathExtension("lrc")
                localLrcCandidates.append(sidecar)
                if let assigned = offlineTrack.lrcURL {
                    localLrcCandidates.append(assigned)
                }
            }
        }

        let musicFolder = LocalLibraryManager.shared.musicFolderURL
        let directFromMusic = musicFolder.appendingPathComponent("\(cleanArtist) - \(cleanTitle).lrc")
        let titleOnlyFromMusic = musicFolder.appendingPathComponent("\(cleanTitle).lrc")
        localLrcCandidates.append(directFromMusic)
        localLrcCandidates.append(titleOnlyFromMusic)

        // Confident match any .lrc file in ~/Music/Mooziac (no arbitrary substring matches)
        do {
            let items = try FileManager.default.contentsOfDirectory(at: musicFolder, includingPropertiesForKeys: nil)
            for item in items where item.pathExtension.lowercased() == "lrc" {
                let fname = item.deletingPathExtension().lastPathComponent.lowercased()
                if confidentLRCNameMatch(fname: fname, cleanTitle: cleanTitle.lowercased(), cleanArtist: cleanArtist.lowercased()) {
                    localLrcCandidates.append(item)
                }
            }
        } catch {
            Log.playback.debug("Unable to inspect music folder for local lyrics: \(error.localizedDescription)")
        }

        // Tier 0.5: Check Local Cache directory (~/Library/Caches/Mooziac/Lyrics/)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Mooziac/Lyrics", isDirectory: true)
        let cacheFilename = strongCacheFilename(trackID: trackID, cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration)
        if let cacheDir = cacheDir {
            do {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            } catch {
                Log.playback.warning("Unable to create lyrics cache directory: \(error.localizedDescription)")
            }
            localLrcCandidates.append(cacheDir.appendingPathComponent(cacheFilename))
            if !trackID.isEmpty {
                let sanitize: (String) -> String = { s in
                    s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
                }
                localLrcCandidates.append(cacheDir.appendingPathComponent("vid_\(sanitize(trackID)).lrc"))
            }
        }

        for candidate in localLrcCandidates {
            // Intentionally try? because candidate file might be invalid or non-UTF8 encoded
            if FileManager.default.fileExists(atPath: candidate.path),
               let lrcContent = try? String(contentsOf: candidate, encoding: .utf8),
               !lrcContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                // Cache validation: If the cached LRC has a [ti:...] tag, verify it matches cleanTitle
                if let tiRange = lrcContent.range(of: "(?i)\\[ti:([^\\]]+)\\]", options: .regularExpression) {
                    let tag = String(lrcContent[tiRange])
                    let cachedTi = tag.replacingOccurrences(of: "(?i)\\[ti:\\s*", with: "", options: .regularExpression)
                                      .replacingOccurrences(of: "\\]", with: "")
                                      .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cachedTi.isEmpty && !cleanTitle.isEmpty {
                        let titleTokens = Set(self.normalizeForMatch(cleanTitle))
                        let cachedTokens = Set(self.normalizeForMatch(cachedTi))
                        if !titleTokens.isEmpty && !cachedTokens.isEmpty {
                            let sim = self.jaccard(titleTokens, cachedTokens)
                            if sim < 0.4 {
                                Log.playback.debug("Evicting stale/mismatched LRC cache: \(candidate.lastPathComponent)")
                                do {
                                    try FileManager.default.removeItem(at: candidate)
                                } catch {
                                    Log.playback.warning("Unable to remove stale LRC cache: \(error.localizedDescription)")
                                }
                                continue
                            }
                        }
                    }
                }

                let parsedLines = SyncedLyricsParser.parse(lrcText: lrcContent)
                if !parsedLines.isEmpty {
                    Log.playback.debug("Found local offline LRC file: \(candidate.lastPathComponent) with \(parsedLines.count) lines")
                    self.currentLRCLines = parsedLines
                    let cleanText = lrcContent.replacingOccurrences(of: "\\[\\d+:\\d+[\\.:]?\\d*\\]", with: "", options: .regularExpression)
                    self.deliverLyrics(trackKey: trackKey, plainText: cleanText.trimmingCharacters(in: .whitespacesAndNewlines), lines: parsedLines, completion: completion)
                    return
                } else if candidate.path.contains("Mooziac/Lyrics") {
                    // Evict corrupted/plain-text pseudo-LRC from local cache
                    Log.playback.debug("Evicting pseudo-LRC without timestamps from cache: \(candidate.lastPathComponent)")
                    try? FileManager.default.removeItem(at: candidate)
                }
            }
        }
        
        guard NetworkMonitor.shared.isReachable else {
            Log.playback.debug("Offline: skipping network lyrics fetch")
            completion("Offline: Internet connection required for lyrics", [])
            return
        }
        
        guard !cleanTitle.isEmpty else {
            completion(nil, [])
            return
        }

        // Tier 0.8: Official YouTube Music Synced Lyrics via InnerTube
        let effectiveVideoId: String? = {
            if let vid = videoId, vid.count == 11 { return vid }
            if let extracted = DownloadManager.extractVideoID(from: trackID), extracted.count == 11 { return extracted }
            return nil
        }()

        if let vid = effectiveVideoId {
            YTMClient.shared.fetchOfficialLyrics(videoId: vid) { [weak self] result in
                guard let self = self else { return }
                guard requestID == self.currentRequestID else { return }

                switch result {
                case .success(let lines) where !lines.isEmpty:
                    Log.playback.info("Retrieved \(lines.count) official synced lyrics from YouTube Music for track '\(cleanTitle)'")
                    self.currentLRCLines = lines
                    let serializedLRC = LyricsManager.serializeLinesToLRC(lines: lines, title: cleanTitle, artist: cleanArtist)
                    self.saveToLocalLyricsCache(filename: cacheFilename, title: cleanTitle, artist: cleanArtist, lrcText: serializedLRC)
                    let plainText = lines.map { $0.text }.joined(separator: "\n")
                    self.deliverLyrics(trackKey: trackKey, plainText: plainText, lines: lines, completion: completion)
                case .success, .failure:
                    // Fall through to Tier 1: LRCLib
                    self.fetchFromLRCLib(requestID: requestID, trackKey: trackKey, cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration, cacheFilename: cacheFilename, completion: completion)
                }
            }
            return
        }

        self.fetchFromLRCLib(requestID: requestID, trackKey: trackKey, cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration, cacheFilename: cacheFilename, completion: completion)
    }

    private func fetchFromLRCLib(requestID: UUID, trackKey: String, cleanTitle: String, cleanArtist: String, duration: Double, cacheFilename: String, completion: @escaping (String?, [LRCLine]) -> Void) {
        // Tier 1: Direct Exact Lookup on LRCLib
        let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let getUrlStr = "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)"
        if let url = URL(string: getUrlStr) {
            let task = urlSession.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { return }
                guard requestID == self.currentRequestID else { return }
                
                var fallbackPlain: String? = nil
                
                if let data = data, error == nil,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if self.isResultMatch(json, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration) {
                        if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                            let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                            if !parsedLines.isEmpty {
                                self.currentLRCLines = parsedLines
                                self.saveToLocalLyricsCache(filename: cacheFilename, title: cleanTitle, artist: cleanArtist, lrcText: syncedLyrics)
                                let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+[\\.:]?\\d*\\]", with: "", options: .regularExpression)
                                self.deliverLyrics(trackKey: trackKey, plainText: cleanText.trimmingCharacters(in: .whitespacesAndNewlines), lines: parsedLines, completion: completion)
                                return
                            }
                        }
                        if let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.isEmpty {
                            // Hold plainLyrics as a fallback, but do NOT abort — search for true synced lyrics!
                            fallbackPlain = plainLyrics
                        }
                    }
                }
                
                // Tier 2: Search LRCLib with title + artist (prefer synced)
                self.searchLRCLibFallback(requestID: requestID, trackKey: trackKey, artist: cleanArtist, title: cleanTitle, duration: duration, cacheFilename: cacheFilename, fallbackPlain: fallbackPlain, completion: completion)
            }
            currentTask = task
            task.resume()
        } else {
            searchLRCLibFallback(requestID: requestID, trackKey: trackKey, artist: cleanArtist, title: cleanTitle, duration: duration, cacheFilename: cacheFilename, fallbackPlain: nil, completion: completion)
        }
    }
    
    private func searchLRCLibFallback(requestID: UUID, trackKey: String, artist: String, title: String, duration: Double, cacheFilename: String, fallbackPlain: String?, completion: @escaping (String?, [LRCLine]) -> Void) {
        let query = "\(title) \(artist)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            searchLRCLibTitleOnly(requestID: requestID, trackKey: trackKey, title: title, artist: artist, duration: duration, cacheFilename: cacheFilename, fallbackPlain: fallbackPlain, completion: completion)
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard requestID == self.currentRequestID else { return }
            var candidatePlain = fallbackPlain
            if let data = data, error == nil,
               let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                // First pass: best verified synced lyrics
                if let item = self.bestPassingResult(in: results, preferSynced: true, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                    if !parsedLines.isEmpty {
                        self.currentLRCLines = parsedLines
                        self.saveToLocalLyricsCache(filename: cacheFilename, title: title, artist: artist, lrcText: syncedLyrics)
                        let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+[\\.:]?\\d*\\]", with: "", options: .regularExpression)
                        self.deliverLyrics(trackKey: trackKey, plainText: cleanText.trimmingCharacters(in: .whitespacesAndNewlines), lines: parsedLines, completion: completion)
                        return
                    }
                }
                
                // Second pass: best verified plain lyrics if no plain was held
                if candidatePlain == nil,
                   let item = self.bestPassingResult(in: results, preferSynced: false, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let plainLyrics = item["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    candidatePlain = plainLyrics
                }
            }
            
            // Tier 3: Search with title ONLY
            self.searchLRCLibTitleOnly(requestID: requestID, trackKey: trackKey, title: title, artist: artist, duration: duration, cacheFilename: cacheFilename, fallbackPlain: candidatePlain, completion: completion)
        }.resume()
    }
    
    private func searchLRCLibTitleOnly(requestID: UUID, trackKey: String, title: String, artist: String, duration: Double, cacheFilename: String, fallbackPlain: String?, completion: @escaping (String?, [LRCLine]) -> Void) {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedTitle)") else {
            finalizePlainOrOVHFallback(requestID: requestID, trackKey: trackKey, artist: artist, title: title, fallbackPlain: fallbackPlain, completion: completion)
            return
        }
        
        urlSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard requestID == self.currentRequestID else { return }
            var candidatePlain = fallbackPlain
            if let data = data, error == nil,
               let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                if let item = self.bestPassingResult(in: results, preferSynced: true, targetTitle: title, targetArtist: artist, targetDuration: duration),
                   let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsedLines = SyncedLyricsParser.parse(lrcText: syncedLyrics)
                    if !parsedLines.isEmpty {
                        self.currentLRCLines = parsedLines
                        self.saveToLocalLyricsCache(filename: cacheFilename, title: title, artist: artist, lrcText: syncedLyrics)
                        let cleanText = syncedLyrics.replacingOccurrences(of: "\\[\\d+:\\d+[\\.:]?\\d*\\]", with: "", options: .regularExpression)
                        self.deliverLyrics(trackKey: trackKey, plainText: cleanText.trimmingCharacters(in: .whitespacesAndNewlines), lines: parsedLines, completion: completion)
                        return
                    }
                } else if candidatePlain == nil,
                          let item = self.bestPassingResult(in: results, preferSynced: false, targetTitle: title, targetArtist: artist, targetDuration: duration),
                          let plainLyrics = item["plainLyrics"] as? String, !plainLyrics.isEmpty {
                    candidatePlain = plainLyrics
                }
            }
            
            // Tier 4: Use candidate plain lyrics or fallback to Lyrics.ovh
            self.finalizePlainOrOVHFallback(requestID: requestID, trackKey: trackKey, artist: artist, title: title, fallbackPlain: candidatePlain, completion: completion)
        }.resume()
    }

    private func finalizePlainOrOVHFallback(requestID: UUID, trackKey: String, artist: String, title: String, fallbackPlain: String?, completion: @escaping (String?, [LRCLine]) -> Void) {
        if let plain = fallbackPlain, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.currentLRCLines = []
            // Plain lyrics are delivered for viewing in the panel, but with EMPTY synced lines so menu bar gracefully displays Title • Artist without fake jumps
            self.deliverLyrics(trackKey: trackKey, plainText: plain.trimmingCharacters(in: .whitespacesAndNewlines), lines: [], completion: completion)
            return
        }
        self.fetchLyricsOVHFallback(requestID: requestID, trackKey: trackKey, artist: artist, title: title, completion: completion)
    }
    
    private func fetchLyricsOVHFallback(requestID: UUID, trackKey: String, artist: String, title: String, completion: @escaping (String?, [LRCLine]) -> Void) {
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
            
            self.currentLRCLines = []
            self.deliverLyrics(trackKey: trackKey, plainText: lyrics.trimmingCharacters(in: .whitespacesAndNewlines), lines: [], completion: completion)
        }.resume()
    }

    private func saveToLocalLyricsCache(filename: String, title: String, artist: String, lrcText: String) {
        guard !lrcText.isEmpty else { return }
        // CRUCIAL: Only save to local .lrc cache if the text contains real timestamp cues!
        let hasTimestamp = lrcText.range(of: "\\[\\d+:\\d+", options: .regularExpression) != nil
        guard hasTimestamp else {
            Log.playback.debug("Skipping LRC cache save: text contains no timestamps for \(title)")
            return
        }
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Mooziac/Lyrics", isDirectory: true)
        if let cacheDir = cacheDir {
            do {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                let cachedLrcURL = cacheDir.appendingPathComponent(filename)
                var textToSave = lrcText
                if !textToSave.contains("[ti:") && !title.isEmpty {
                    textToSave = "[ti:\(title)]\n[ar:\(artist)]\n" + textToSave
                }
                try textToSave.write(to: cachedLrcURL, atomically: true, encoding: .utf8)
            } catch {
                Log.playback.warning("Failed to save lyrics to cache file: \(error.localizedDescription)")
            }
        }
    }

    public func fetchRawSyncedLRC(artist: String, title: String, duration: Double = 0.0, expectedTrackID: String = "", videoId: String? = nil, completion: @escaping (String?) -> Void) {
        let cleanTitle = LyricsManager.cleanSongInfo(title)
        let cleanArtist = LyricsManager.cleanSongInfo(artist)

        let effectiveVideoId: String? = {
            if let vid = videoId, vid.count == 11 { return vid }
            if let extracted = DownloadManager.extractVideoID(from: expectedTrackID), extracted.count == 11 { return extracted }
            return nil
        }()

        if let vid = effectiveVideoId {
            YTMClient.shared.fetchOfficialLyrics(videoId: vid) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let lines) where !lines.isEmpty:
                    let lrcText = LyricsManager.serializeLinesToLRC(lines: lines, title: cleanTitle, artist: cleanArtist)
                    completion(lrcText)
                    return
                case .success, .failure:
                    break
                }
                self.fetchRawSyncedLRCFromLRCLib(cleanArtist: cleanArtist, cleanTitle: cleanTitle, duration: duration, expectedTrackID: expectedTrackID, completion: completion)
            }
            return
        }

        fetchRawSyncedLRCFromLRCLib(cleanArtist: cleanArtist, cleanTitle: cleanTitle, duration: duration, expectedTrackID: expectedTrackID, completion: completion)
    }

    private func fetchRawSyncedLRCFromLRCLib(cleanArtist: String, cleanTitle: String, duration: Double, expectedTrackID: String, completion: @escaping (String?) -> Void) {
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