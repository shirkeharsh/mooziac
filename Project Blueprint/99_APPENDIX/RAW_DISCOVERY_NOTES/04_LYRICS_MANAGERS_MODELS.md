# Mooziac — WorkD Blueprint: Lyrics, Parsers, History, Likes, RPC, Notifications, Network, Artwork & Models

> Reverse-engineering archive (READ-ONLY). Every statement below was verified in source unless marked **INFERRED FROM SOURCE** or **UNKNOWN — requires runtime verification**.
> Line numbers refer to the files as read at analysis time. Consumers were verified by repository-wide grep unless marked INFERRED.
> No secret values are printed. Where secrets exist, their location and shape are described only.

## Conventions

- `public final class X: singleton` = `static let shared` + `private init()`.
- "Approximate line" = exact declaration line in the read source.
- Notification names, URLs, defaults keys, socket paths, JSON keys, file paths, and magic numbers are quoted verbatim.

---

# FILE ENTRY 1 — `Sources/Mooziac/Managers/LyricsManager.swift` (508 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/LyricsManager.swift`
- **Purpose**: Central lyrics service. Fetches synced (`.lrc`) or plain lyrics from LRCLib and Lyrics.ovh through a 5-tier fallback pipeline: local `.lrc` sidecars → local disk cache → LRCLib exact `GET` → LRCLib search (title+artist) → LRCLib search (title only) → Lyrics.ovh. Cleans YouTube title fluff, normalizes for matching, scores results with a Jaccard heuristic, caches to disk, and feeds line highlighting via `SyncedLyricsParser.activeLineAndWord`.
- **Subsystem**: Managers (lyrics / network / caching).
- **Dependencies (cross-file types)**: `LRCLine` + `SyncedLyricsParser` (`SyncedLyricsParser.swift`), `NetworkMonitor.shared.isReachable` (`NetworkMonitor.swift`), `NativeAudioPlayer.shared.currentTrack` (`Audio/NativeAudioPlayer.swift`), `LocalLibraryManager.shared.musicFolderURL` (`Managers/LocalLibraryManager.swift`).
- **Imports**: `import AppKit` (1), `import Foundation` (2).
- **Classes/structs/enums defined**: only `public final class LyricsManager`.
- **API mechanism (mechanism only, no secrets)**: two public lyric providers:
  - LRCLib — exact lookup `https://lrclib.net/api/get?artist_name=<q>&track_name=<q>` (line 289); search `https://lrclib.net/api/search?q=<query>` (lines 335, 379). JSON keys consumed: `syncedLyrics`, `plainLyrics`, `trackName`, `artistName`, `duration`.
  - Lyrics.ovh — `https://api.lyrics.ovh/v1/<artist>/<title>` (line 421). JSON key consumed: `lyrics`.
  - No auth headers or tokens observed anywhere in this file.
- **Storage paths**:
  - Lyrics cache dir: `~/Library/Caches/Mooziac/Lyrics/` (lines 249, 448).
  - Local library dir: `LocalLibraryManager.shared.musicFolderURL` (line 232) — scanned for `*.lrc` sidecars.
- **Events**: `onLyricsUpdated` closure (line 14), fired on main thread after every successful resolution.
- **Side effects**: writes `.lrc` cache files (`saveToLocalLyricsCache`, line 446); cancels in-flight `URLSessionDataTask` (line 216); `print` logging (lines 262, 275).
- **External APIs**: LRCLib (`lrclib.net`), Lyrics.ovh (`api.lyrics.ovh`).
- **Files it communicates with**:
  - Reads: `SyncedLyricsParser.swift` (`parse`), `NetworkMonitor.swift` (`isReachable`), `NativeAudioPlayer.swift` (`currentTrack`), `LocalLibraryManager.swift` (`musicFolderURL`).
  - Consumers (grep-verified): `Views/Windows/CenteredMenuBarLyricsWindowController.swift:136` (`fetchLyrics`; `activeLineAndWord` at :169), `Managers/DownloadManager.swift:537` (`fetchRawSyncedLRC`).

## Class: `LyricsManager` (line 4) — `public final class`, singleton

### Purpose
Manages the lyric fetch/parse/cache/highlight pipeline with request-ID-based stale-response protection.

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `LyricsManager` | `public static let` | 5 | singleton |
| `urlSession` | `URLSession` | `private let` | 7 | `URLSession.shared` |
| `currentTask` | `URLSessionDataTask?` | `private var` | 8 | in-flight request |
| `currentRequestID` | `UUID` | `private var` | 9 | stale-response guard |
| `currentTrackKey` | `String` | `public private(set) var` | 11 | cache identity of current track |
| `currentLRCLines` | `[LRCLine]` | `public private(set) var` | 12 | parsed lines for current track |
| `onLyricsUpdated` | `(([LRCLine]) -> Void)?` | `public var` | 14 | main-thread callback after resolution |

### Init
`private init() {}` (line 16) — singleton.

### Static functions

- **`cleanSongInfo(_ text: String) -> String`** (line 19)
  - Purpose: strip YouTube fluff from titles/artists while preserving native scripts (Devanagari, CJK, Spanish accents).
  - Input: raw string. Output: cleaned string.
  - Called by: `strongTrackKey`, `fetchLyrics`, `fetchRawSyncedLRC`, and `LocalTrack.cleanTitle`/`cleanArtist` (`Models/LocalTrack.swift:64-70`).
  - Mechanics (exact regexes):
    1. `"(?i)[(\[{].*?(official|video|audio|remastered|remaster|explicit|version|lyric|hd|4k|full song|video song).*?[)\]}]"` → `""` (line 22).
    2. `"(?i)\s+ft\.?.*$"` → `""` (line 23).
    3. `"(?i)\s+feat\.?.*$"` → `""` (line 24).
    4. `trimmingCharacters(in: .whitespacesAndNewlines)` (line 25).
  - Side effects: none (pure). Errors: none. Async: none.

- **`convertPlainToLRCLines(_ plainText: String) -> [LRCLine]`** (line 29)
  - Purpose: convert plain (non-timed) lyrics into evenly spaced LRC lines for scrollable viewing.
  - Input: plain text. Output: `[LRCLine]`.
  - Mechanics: split on newlines; each non-empty trimmed line gets `timestamp` starting at `0.0` and incrementing by `+4.0` seconds; `nextTimestamp = timestamp + 4.0` (lines 30–41). Whitespace-only lines skipped.
  - Called by: `fetchLyrics` (lines 310, 362, 402, 436).
  - Side effects: none. Errors: none. Async: none.

### Private instance functions

#### Matching & normalization
- **`normalizeForMatch(_ text: String) -> [String]`** (line 48)
  - Purpose: tokenize for matching — lowercase, drop ASCII punctuation, keep non-ASCII (native scripts), collapse whitespace, drop tokens `< 3` chars.
  - Mechanics: per-char loop keeps ASCII letters/numbers/whitespace, always appends non-ASCII (lines 51–59); `"\s+"` → single space (line 61); split + filter `count >= 3` (line 63).
  - Called by: `isMeaningfulArtist`, `matchScore`, `confidentLRCNameMatch`.
- **`jaccard(_ a: Set<String>, _ b: Set<String>) -> Double`** (line 66)
  - Purpose: Jaccard similarity; returns `0.0` if either set empty or union empty. Mechanics: `inter / union`.
- **`isMeaningfulArtist(_ artist: String) -> Bool`** (line 73)
  - Purpose: reject placeholder artists. Placeholder set (line 77): `["local audio", "unknown artist", "unknown", "various artists", "artist", "track artist"]`. Returns `false` if tokenized empty or joined tokens in placeholders.
- **`matchScore(_ item: [String: Any], targetTitle: String, targetArtist: String, targetDuration: Double) -> Double?`** (line 83)
  - Purpose: combined similarity score (higher = better) or `nil` if hard gates fail.
  - Mechanics:
    1. Duration gate (lines 85–95): only if `targetDuration > 5.0`; reads `item["duration"]` as `Double` or `NSNumber`; if item duration `> 0` and `abs(itemDur - targetDuration) > 12.0` → `nil`.
    2. Requires `item["trackName"] as? String` (line 97).
    3. Title gate (lines 98–103): non-empty token sets; `titleSim = jaccard(...)`; requires `titleSim >= 0.6`.
    4. Artist logic (lines 105–120): both meaningful → `artistSim = jaccard(...)`, accept if `>= 0.4` OR one set is a subset of the other; only one meaningful → require `titleSim >= 0.8`, `artistSim = titleSim`.
    5. Final score: `(0.65 * titleSim) + (0.35 * artistSim)` (line 122).
- **`isResultMatch(_ item:..., ...) -> Bool`** (line 125): returns `matchScore(...) != nil`.
- **`bestPassingResult(in results: [[String: Any]], preferSynced: Bool, targetTitle:, targetArtist:, targetDuration:) -> [String: Any]?`** (line 130)
  - Purpose: best-scoring validated result; when `preferSynced` requires non-empty `syncedLyrics`, else non-empty `plainLyrics`; keeps max `matchScore`.

#### Cache identity
- **`strongTrackKey(trackID:title:artist:duration:) -> String`** (line 152)
  - Purpose: collision-resistant identity. With trackID → `"VID:" + trackID` (line 154). Else → `"TRACK:<cleanTitleLower>|<cleanArtistLower>|<Int(duration)>"` (line 159). Uses `cleanSongInfo` + lowercase.
- **`strongCacheFilename(trackID:cleanTitle:cleanArtist:duration:) -> String`** (line 162)
  - Purpose: cache filename. Sanitizer replaces `/` and `:` with `-` (lines 163–165). With trackID → `"vid_<sanitized>.lrc"` (line 167). Else → `"<t>_<a>_<Int(duration)>.lrc"` with `untitled`/`unknown` fallbacks (lines 169–172).
- **`confidentLRCNameMatch(fname:cleanTitle:cleanArtist:) -> Bool`** (line 178)
  - Purpose: accept a local `.lrc` only when the filename confidently matches the track; rejects arbitrary substring matches.
  - Mechanics: requires non-empty title tokens; splits at `" - "` into `artistPart`/`titlePart` (lines 182–188); requires `titleSim >= 0.8` (line 193); if artist part present and artist tokens exist, requires `artistSim >= 0.5` (lines 195–201).

#### Fetch pipeline
- **`fetchLyrics(artist:title:duration:trackID:completion:)`** (line 206)
  - Inputs: `artist`, `title`; `duration: Double = 0.0`; `trackID: String = ""`; `completion: (String?, [LRCLine]) -> Void` (first param = clean plain text for display; second = parsed lines).
  - Execution flow (exact order):
    1. `cleanTitle`/`cleanArtist` via `cleanSongInfo`; `trackKey` via `strongTrackKey` (lines 207–209).
    2. **Short-circuit**: if `trackKey == currentTrackKey && !currentLRCLines.isEmpty` → `completion(nil, currentLRCLines)` immediately (lines 211–214). **NOTE: cache hit returns `nil` display text.**
    3. Cancel `currentTask`; new `requestID`; set `currentTrackKey`; reset `currentLRCLines = []` (lines 216–220).
    4. **Tier 0 — local `.lrc` sidecars** (lines 222–246):
       - If `NativeAudioPlayer.shared.currentTrack` non-nil: sidecar `fileURL.deletingPathExtension().appendingPathExtension("lrc")`; plus `offlineTrack.lrcURL` if set (lines 224–230).
       - Music folder direct paths: `<musicFolder>/<cleanArtist> - <cleanTitle>.lrc` and `<musicFolder>/<cleanTitle>.lrc` (lines 233–234).
       - Scan `<musicFolder>` for any `*.lrc` passing `confidentLRCNameMatch` (lines 239–246).
    5. **Tier 0.5 — disk cache** (lines 248–254): `~/Library/Caches/Mooziac/Lyrics/<strongCacheFilename>.lrc`; creates dir.
       - For each candidate: if exists, UTF-8 read, non-empty, parses via `SyncedLyricsParser.parse`; on non-empty lines → set `currentLRCLines`, strip timestamps with regex `"\[\d+:\d+[\.:]?\d*\]"` (line 264), main-async → `onLyricsUpdated?(parsedLines)` + `completion(cleanText, parsedLines)`, return (lines 256–272).
    6. **Offline gate** (lines 274–278): `guard NetworkMonitor.shared.isReachable` else `completion("Offline: Internet connection required for lyrics", [])`.
    7. **Empty-title gate** (lines 280–283): `guard !cleanTitle.isEmpty` else `completion(nil, [])`.
    8. **Tier 1 — LRCLib exact** (lines 285–329): `https://lrclib.net/api/get?artist_name=<enc>&track_name=<enc>`; stale guard `requestID == self.currentRequestID` (line 294); if `isResultMatch`: prefer `syncedLyrics` (parse, cache, strip timestamps `"\[\d+:\d+\.\d+\]"`, callback) else `plainLyrics` (convert, cache raw, callback) (lines 296–318); else **Tier 2** `searchLRCLibFallback` (line 323).
    9. URL construction failure → directly `searchLRCLibFallback` (line 328).
  - Called by: `CenteredMenuBarLyricsWindowController.swift:136`.
  - Async: yes (URLSession). Threading: network-path completions on main; cache-hit short-circuit on caller thread.
  - Side effects: cache writes, task cancellation, `print`s. Errors: non-fatal via completion.

- **`searchLRCLibFallback(requestID:artist:title:duration:completion:)`** (line 332)
  - Purpose: **Tier 2** — LRCLib search with query `"\(title) \(artist)"`, URL `https://lrclib.net/api/search?q=<enc>`.
  - Mechanics: stale guard; on `[[String: Any]]` results: pass 1 `bestPassingResult(preferSynced: true)` → parse + strip + cache + callback; pass 2 `preferSynced: false` → convert + callback (lines 346–369). Fail or bad URL → **Tier 3** `searchLRCLibTitleOnly`. NOTE: no `saveToLocalLyricsCache` call in the synced branch here (line 350–355 only caches via... none) — verified: **no cache write in search tiers**.
- **`searchLRCLibTitleOnly(requestID:title:artist:duration:completion:)`** (line 377)
  - Purpose: **Tier 3** — LRCLib search title-only `https://lrclib.net/api/search?q=<encTitle>`.
  - Mechanics: same two-pass logic (lines 390–409); fail → **Tier 4** `fetchLyricsOVHFallback`.
- **`fetchLyricsOVHFallback(requestID:artist:title:completion:)`** (line 417)
  - Purpose: **Tier 4** — Lyrics.ovh final fallback. Empty artist coerced to `"Artist"` (line 418); encoding `.urlPathAllowed`; URL `https://api.lyrics.ovh/v1/<artist>/<title>`.
  - Mechanics: reads `json["lyrics"]`; `convertPlainToLRCLines`; main-async callback. Any failure → `completion(nil, [])` on main (lines 422, 432).
- **`saveToLocalLyricsCache(filename:lrcText:)`** (line 446)
  - Purpose: write fetched lyrics to `~/Library/Caches/Mooziac/Lyrics/<filename>`; `atomically: true`, UTF-8.
  - Called by: `fetchLyrics` synced (line 302) and plain (line 312) Tier-1 branches only.
- **`fetchRawSyncedLRC(artist:title:duration:completion:)`** (line 456)
  - Purpose: fetch raw LRC/plain text without parsing or caching — used by `DownloadManager.swift:537` (save lyrics with downloaded audio).
  - Mechanics: LRCLib exact `GET`; on match returns `syncedLyrics` else `plainLyrics` (lines 469–481); fallback search `"\(cleanTitle) \(cleanArtist)"` with two-pass best-scoring (lines 483–502); `completion(nil)` on all failures. **No request-ID guard; callbacks run on the URLSession queue (INFERRED — no main dispatch observed).**

### Callback/closure inventory
- `onLyricsUpdated` fired on main at lines 266, 305, 314, 353, 365, 396, 405, 440.
- `completion` invoked on main at lines 267, 276, 281, 306, 315, 354, 366, 397, 406, 422, 432, 441 — except cache-hit short-circuit (line 212, caller thread) and `fetchRawSyncedLRC` (URLSession thread).

### Risks (LyricsManager)
- Cache-hit path returns `(nil, lines)` — callers using the first parameter for display text get `nil` after first play.
- `fetchRawSyncedLRC` has no stale-response guard; concurrent downloads could apply out-of-order.
- Nested closure at line 487 references `self` strongly inside an already-`[weak self]` outer closure — potential temporary retain (INFERRED).
- LRCLib search tiers (2/3) and Lyrics.ovh tier (4) never write the disk cache — repeated search-fallback fetches re-hit the network.
- No rate limiting / retry / backoff; up to 4 sequential network tiers can fire per request.
- Duration gate skipped when `targetDuration <= 5.0` (design choice).
- Inconsistent completion threading contract (caller thread vs main vs URLSession).

---

# FILE ENTRY 2 — `Sources/Mooziac/Managers/SyncedLyricsParser.swift` (155 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/SyncedLyricsParser.swift`
- **Purpose**: LRC format parsing + word-level timing. Defines `LRCWord`/`LRCLine` and a static parser producing sorted, word-timed lines; `activeLineAndWord` drives per-word highlighting from playback time.
- **Subsystem**: Managers (lyrics parsing; data types used by views).
- **Dependencies**: none beyond Foundation.
- **Imports**: `import Foundation` (line 1).
- **Classes/structs/enums defined**: `LRCWord` (struct), `LRCLine` (struct), `SyncedLyricsParser` (final class, static-only).
- **External APIs**: none.
- **Files it communicates with**: consumed by `LyricsManager.swift` (`parse`), `Views/Windows/CenteredMenuBarLyricsWindowController.swift:169` (`activeLineAndWord`), `DownloadManager` indirectly.

## Struct: `LRCWord` (line 3) — `public struct`
| Field | Type | Access | Line | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `text` | `String` | `public let` | 4 | the word |
| `startTime` | `Double` | `public let` | 5 | seconds |
| `endTime` | `Double` | `public let` | 6 | seconds |
| `weight` | `Double` | `public let` | 7 | acoustic weight used for word-duration distribution |

Memberwise init (implicit, internal). No Codable/Equatable/Hashable conformance.

## Struct: `LRCLine` (line 10) — `public struct`
| Field | Type | Access | Line | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `timestamp` | `Double` | `public let` | 11 | line start in seconds |
| `text` | `String` | `public let` | 12 | lyric text |
| `words` | `[LRCWord]` | `public let` | 13 | word-level timing |

### Init `init(timestamp: Double, text: String, nextTimestamp: Double?)` (line 15)
- Purpose: compute per-word timing from line duration.
- Mechanics:
  1. Split `text` on whitespace, drop empties (line 19).
  2. `lineEnd = nextTimestamp ?? (timestamp + 4.2)`; `lineDuration = max(0.4, lineEnd - timestamp)` (lines 23–24).
  3. **Vowel-weighted acoustic weighting** (lines 26–35): per char, `+2` if lowercase string is in `"aeiouáéíóúअआईईउऊएऐओऔ"` (ASCII + accented + Devanagari vowels), else `+1`; word weight = `Double(max(1, vowelCount))`.
  4. Distribute `lineDuration` proportional to weight: `share = (weights[i] / totalWeight) * lineDuration`; `currentStart` accumulates (lines 38–44).
- Codable: none.
- Consumers: `LyricsManager.currentLRCLines`; `CenteredMenuBarLyricsWindowController` (renders lines + words).

## Class: `SyncedLyricsParser` (line 51) — `public final class`, no stored properties, all static

### `static func parse(lrcText: String) -> [LRCLine]` (line 52)
- Purpose: parse LRC text into sorted, word-timed lines.
- **Exact regex** (line 56): `"\[(\d+):(\d+)(?:[\.:](\d+))?\](.*)"` — matches `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss:xx]`. Groups: 1 = minutes, 2 = seconds, 3 = optional fractional digits (`:` or `.`), 4 = lyric text.
- Mechanics:
  1. Split on newlines; regex per line (lines 54–61).
  2. Require ≥ 3 ranges; minute/second ranges must exist (lines 64–67).
  3. Fractional scaling (lines 72–84): 1 digit → `/10`; 3 digits → `/1000`; else (2 digits) → `/100`.
  4. Lyric text = group 4, trimmed; only non-empty text entries kept (lines 86–95).
  5. Total seconds = `mins * 60 + secs + msFraction` (line 92).
  6. **Sort ascending by timestamp** (line 100).
  7. Build `LRCLine`s; `nextTimestamp` = next entry's timestamp or `nil` (lines 102–107).
- Output: `[LRCLine]`. Errors: none thrown; malformed lines silently skipped.
- Called by: `LyricsManager` (many sites), `DownloadManager` indirectly.

### `static func activeLineAndWord(at currentTime: Double, in lines: [LRCLine], leadOffset: Double = 0.35) -> (line: LRCLine, lineIndex: Int, activeWordIndex: Int, activeWordProgress: Double)?` (line 112)
- Purpose: given playback time, return active line/index/word/progress for highlight rendering. `leadOffset = 0.35` s look-ahead.
- Mechanics:
  1. `effectiveTime = currentTime + leadOffset` (line 115).
  2. Linear scan finds last line with `effectiveTime >= line.timestamp`, early-break (lines 117–124); `nil` if none.
  3. Empty words → `(line, foundIndex, 0, 0.0)` (line 130).
  4. Word scan: inside `[start, end]` → active word, `wordProgress = clamp((t - start)/max(0.05, end - start))` (lines 136–141); before word start → previous word (or 0), progress 0 (lines 142–150). Past end → last word, progress 1.0 (lines 133–134).
- Output: optional tuple.
- Called by: `CenteredMenuBarLyricsWindowController.swift:169` with `leadOffset: 0.35`.

### Risks (SyncedLyricsParser)
- `LRCLine.init` floors line duration at 0.4 s — a next line closer than 0.4 s inflates the current line's word spans.
- Vowel set is heuristic and incomplete for Devanagari (matras/conjuncts missing) — visual-only effect (INFERRED).
- Multi-tag lines (`[00:01.00][00:05.00]x`) produce duplicate entries with identical text.
- `LRCLine`/`LRCWord` lack Codable/Equatable — no persistence/testing helpers observed.
- `activeLineAndWord` linear scans; O(n) per call at display refresh rate (n = line count; small, acceptable).

---

# FILE ENTRY 3 — `Sources/Mooziac/Managers/HistoryManager.swift` (176 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/HistoryManager.swift`
- **Purpose**: Logs online/offline track playback into listening history (dedup), queries, deletes/clears, and routes a history item back to the correct playback engine (local file vs online video vs web search).
- **Subsystem**: Managers (history / persistence bridge).
- **Dependencies**: `HistoryRecord` + `LocalDatabaseManager` (`Managers/LocalDatabaseManager.swift`), `LocalTrack` (`Models/LocalTrack.swift`), `NowPlayingManager` (`Core/NowPlayingManager/NowPlayingManager.swift`), `PlaylistManager` (`Managers/PlaylistManager.swift`), `LocalLibraryManager` (`Managers/LocalLibraryManager.swift`), `StatusItemManager.shared?.mainViewController.webViewContainer.webView` (`Core/StatusItemManager/`).
- **Imports**: `import AppKit` (1), `import Foundation` (2).
- **Classes/structs/enums defined**: `HistoryManager`.
- **Storage format** (delegated to SQLite via `LocalDatabaseManager`):
  - Table `listening_history`, columns `id, title, artist, album, artwork_url, yt_video_id, file_path, played_at, duration, source_type` (see `LocalDatabaseManager.swift:1105`).
  - **Dedup** (`recordHistoryItem`, `LocalDatabaseManager.swift:1066–1135`): deletes prior rows matching by (a) `yt_video_id`, (b) `file_path`, (c) `LOWER(TRIM(title))`+`LOWER(TRIM(artist))`, then inserts fresh — one row per song, last-played wins.
  - **Cap**: prune keeps max **1,000** rows: `DELETE FROM listening_history WHERE id NOT IN (SELECT id FROM listening_history ORDER BY played_at DESC LIMIT 1000);` (line 1134).
  - Timestamps: `played_at` = `Date().timeIntervalSince1970` (epoch seconds).
- **Events**: `historyUpdatedNotification` = `Notification.Name("Mooziac_historyUpdated")` (line 7).
- **Defaults keys read** (seed path): `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastVideoId`, `YTM_lastArtwork`, `YTM_lastDuration` (lines 91–95).
- **Files it communicates with**:
  - Writers: `Core/NowPlayingManager/ObserverBridge.swift:442` (`trackDidStartOnline`), `Audio/NativeAudioPlayer.swift:220` (`trackDidStartOffline`).
  - Observers: `Views/Player/DynamicIslandPlayerView/Core.swift:234`; `Views/Libraries/PlaylistLibraryView.swift:364`; `Core/StatusItemManager/ContextMenu.swift:225`.
  - Readers: `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift:965,1419,2170`; `Views/Libraries/PlaylistLibraryView.swift` (multiple).

## Class: `HistoryManager` (line 4) — `public final class`, singleton

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `HistoryManager` | `public static let` | 5 | singleton |
| `historyUpdatedNotification` | `Notification.Name` | `public static let` | 7 | `"Mooziac_historyUpdated"` |
| `pendingTrackKey` | `String` | `private var` | 9 | dedup guard for current pending track |
| `pendingStartTime` | `CFAbsoluteTime` | `private var` | 10 | **DEAD — never read/written beyond declaration** |
| `pendingRecord` | `HistoryRecord?` | `private var` | 11 | **DEAD — never read/written beyond declaration** |
| `hasCommittedCurrentPending` | `Bool` | `private var` | 12 | **DEAD — never read/written beyond declaration** |
| `commitTimer` | `Timer?` | `private var` | 13 | **DEAD — never read/written beyond declaration** |

### Init
`private init() {}` (line 15).

### Functions
- **`trackDidStartOnline(title:artist:album:artworkUrl:videoId:duration:)`** (line 20)
  - Purpose: log online track start (dedup).
  - Mechanics: trims title; guard empty or `"Not Playing"` (line 29). Dedup key `"\(titleLower)__\(artistLower)__\(videoId)"` (line 31); equal to `pendingTrackKey` → return (line 34). Builds `HistoryRecord` (`sourceType: "online"`, `ytVideoId: videoId.isEmpty ? nil : videoId`, `filePath: nil`, `playedAt: Date().timeIntervalSince1970`). `LocalDatabaseManager.shared.recordHistoryItem(record)` (line 51); main-thread post `historyUpdatedNotification` (lines 52–54).
  - Called by: `ObserverBridge.swift:442`.
  - Async: notification on main; DB write async inside LocalDatabaseManager.
- **`trackDidStartOffline(_ track: LocalTrack)`** (line 58)
  - Purpose: log local track start (dedup).
  - Mechanics: dedup key `"local__\(track.id)__\(track.fileURL.path)"` (line 59). Record: `artworkUrl: track.fileURL.path`, `ytVideoId: track.ytVideoId`, `filePath: track.fileURL.path`, `sourceType: "local"` (lines 66–76). DB write + main-thread post (lines 78–81).
  - Called by: `NativeAudioPlayer.swift:220`.
- **`fetchHistory(limit: Int = 200, offset: Int = 0) -> [HistoryRecord]`** (line 86)
  - Purpose: query history; if empty, seed from currently playing track or persisted defaults.
  - Mechanics: `LocalDatabaseManager.shared.fetchHistory(limit:offset:)`. If empty: builds record from `NowPlayingManager.shared.currentState` falling back to UserDefaults keys `YTM_lastTitle`/`YTM_lastArtist`/`YTM_lastVideoId`/`YTM_lastArtwork`/`YTM_lastDuration` (lines 90–95); if valid title, inserts seed record and returns `[initialRecord]` (lines 97–111).
  - Called by: `SettingsPanel.swift:965`, `PlaylistLibraryView.swift:380,656`.
- **`deleteHistoryItem(id: String) -> Bool`** (line 117, `@discardableResult`)
  - Purpose: delete one history row; posts `historyUpdatedNotification` on main if successful.
  - Called by: `SettingsPanel.swift:1419`, `PlaylistLibraryView.swift:998,1581,1914,1977`.
- **`clearHistory() -> Bool`** (line 128, `@discardableResult`)
  - Purpose: wipe history; posts `historyUpdatedNotification` on main if successful.
  - Called by: `PlaylistLibraryView.swift:896`, `StatusItemManager/ContextMenu.swift:225`.
- **`fetchHistoryCount() -> Int`** (line 138)
  - Purpose: distinct-count of history entries; delegates to `LocalDatabaseManager.fetchHistoryCount()`.
- **`playHistoryItem(_ item: HistoryRecord)`** (line 144)
  - Purpose: route a history item back to playback.
  - Mechanics (exact branching):
    1. `sourceType == "local"` and `filePath` exists → build `LocalTrack` (reuse from `LocalLibraryManager.shared.allTracks` by path, else construct fresh with `id: item.id`, `isLiked: LocalDatabaseManager.shared.isLiked(filePath:)`); `NowPlayingManager.shared.playOfflineTrack(localTrack, in: [localTrack])` (lines 145–160).
    2. Else if `ytVideoId` non-empty → `NowPlayingManager.shared.switchToOnlineMode()` + `PlaylistManager.shared.playOnlineVideo(videoId:)` (lines 161–163).
    3. Else → switch to online mode; build URL `"https://music.youtube.com/search?q=<enc>"` from `"\(item.title) \(item.artist)"` and load it in `StatusItemManager.shared?.mainViewController.webViewContainer.webView.load(...)` on main (lines 164–173).
  - Called by: `SettingsPanel.swift:2170`, `PlaylistLibraryView.swift:941,966,1499,1911`.

### Risks (HistoryManager)
- `pendingStartTime`, `pendingRecord`, `hasCommittedCurrentPending`, `commitTimer` are dead fields (vestigial "commit after threshold" design never implemented).
- Dedup happens twice: in-memory `pendingTrackKey` AND SQL-side delete+insert. The in-memory key ignores duration changes and relies on `videoId` (empty videoId → same title+artist collapse even for different videos).
- `fetchHistory` seeds the DB with the currently playing track on every empty-history read — can re-insert repeatedly if DB write is slow (DB write is async; race between read and write can cause duplicate seeding — INFERRED).
- Offline/local playback sets `artworkUrl` to a local file path (not a URL) — consumers must handle non-URL artwork strings.
- The web-search fallback depends on the status-item webView being alive (`StatusItemManager.shared?.mainViewController` is optional chained — silent no-op if nil).
- History is appended only on track *start* — very short listens are still recorded.

---

# FILE ENTRY 4 — `Sources/Mooziac/Managers/LikedSongsManager.swift` (215 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/LikedSongsManager.swift`
- **Purpose**: Tracks liked-song state (local mirror), detects YouTube sign-in via WebKit cookies and DOM, records online/offline like toggles into SQLite, and one-time-syncs unsynced liked songs to the user's YouTube account by driving the in-page like button.
- **Subsystem**: Managers (likes / account bridge).
- **Dependencies**: `LocalDatabaseManager` (`Managers/LocalDatabaseManager.swift`), `LikedSongRecord` (`Models/LikedSongRecord.swift`), `NowPlayingManager` (`Core/NowPlayingManager/NowPlayingManager.swift` — `evaluateJS`, `evaluateJSWithResult`, `switchToOnlineMode`), `PlaylistManager` (`playOnlineVideo`), `LocalLibraryManager` (`allTracks`), `NetworkMonitor` (`isReachable`), `WKWebsiteDataStore` (WebKit).
- **Imports**: `import AppKit` (1), `import WebKit` (2).
- **Classes/structs/enums defined**: `LikedSongsManager`.
- **Events / notification names**:
  - `likedSongsUpdatedNotification` = `NSNotification.Name("Mooziac_LikedSongsUpdated")` (line 7).
  - `signInStatusChangedNotification` = `NSNotification.Name("Mooziac_SignInStatusChanged")` (line 8).
- **Storage**: SQLite table `liked_songs`, columns `video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type` (INSERT/UPSERT at `LocalDatabaseManager.swift:636–664`; `video_id` is the unique conflict key). `synced` is the local→account sync flag; `source_type` is `"ytm"` (default) or `"local"`.
- **API mechanism (DOM, no secrets)**: sign-in is detected from cookies `SAPISID`, `__Secure-3PAPISID`, `__Secure-1PAPISID` whose `domain` contains `youtube.com` or `google.com` (lines 30–32). Sync drives the real YTMusic player-bar like button via injected JS. Cookie *values* are never read/printed.
- **Files it communicates with**:
  - Writers/readers of DB: `LocalDatabaseManager` (`isLikedSong`, `fetchLikedSongs`, `addLikedSong`, `removeLikedSong`, `fetchUnsyncedLikedSongs`, `setLikedSongSynced`, `isLiked(filePath:)`).
  - Callers: `Core/NowPlayingManager/ObserverBridge.swift:383-384` (read), `Core/NowPlayingManager/PlayerControls.swift:468,475,486` (toggle/sync), `Web/YTMWebView.swift:237` (`refreshSignInStatus`).
  - Observers: `Views/Player/DynamicIslandPlayerView/Core.swift:241`; `Views/Libraries/PlaylistLibraryView.swift:366`.
  - Direct notification posters on the same name: `PlaylistLibraryView.swift:987,1728,1868,1954`; `SettingsPanel.swift:1452`.

## Class: `LikedSongsManager` (line 4) — `public class` (not final), singleton

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `LikedSongsManager` | `public static let` | 5 | singleton |
| `likedSongsUpdatedNotification` | `NSNotification.Name` | `public static let` | 7 | `"Mooziac_LikedSongsUpdated"` |
| `signInStatusChangedNotification` | `NSNotification.Name` | `public static let` | 8 | `"Mooziac_SignInStatusChanged"` |
| `isSignedIn` | `Bool` | `public private(set) var` | 10 | defaults `false` |
| `isSyncing` | `Bool` | `private var` | 11 | guards one sync at a time |

### Init
`private init() {}` (line 13).

### Functions
- **`isLiked(videoId: String) -> Bool`** (line 17): delegates to `LocalDatabaseManager.shared.isLikedSong(videoId:)`. Called by `ObserverBridge.swift:384`.
- **`fetchLikedSongs() -> [LikedSongRecord]`** (line 21): delegates to `LocalDatabaseManager.shared.fetchLikedSongs()`. Called by `SettingsPanel.swift:915`, `PlaylistLibraryView.swift:371,600`.
- **`refreshSignInStatus()`** (line 27)
  - Purpose: detect sign-in from WKWebView cookie store.
  - Mechanics: `WKWebsiteDataStore.default().httpCookieStore.getAllCookies`; filter `name ∈ {SAPISID, __Secure-3PAPISID, __Secure-1PAPISID}` AND `domain` contains `youtube.com` or `google.com`; `updateSignedIn(!authCookies.isEmpty)` (lines 28–36). Called by `YTMWebView.swift:237`.
  - Threading: cookie callback is non-main (INFERRED) — `updateSignedIn` hops to main.
- **`probeSignInFromDOM()`** (line 39)
  - Purpose: DOM-based sign-in probe via injected JS.
  - JS (lines 40–50): queries `ytmusic-pivot-bar-renderer yt-avatar`, `ytmusic-account-chip-renderer`, `#avatar-btn`, `ytmusic-pivot-bar-renderer [class*="avatar"]`; returns `!!el`.
  - Mechanics: `NowPlayingManager.shared.evaluateJSWithResult(js)`; `updateSignedIn(result as? Bool ?? false)`.
- **`updateSignedIn(_ value: Bool)`** (line 57)
  - Purpose: set `isSignedIn` on main; posts `signInStatusChangedNotification` only on change; `print("[LikedSongsManager] isSignedIn = \(value)")`.
- **`recordOnlineLikeToggle(desiredLiked:videoId:title:artist:album:artworkUrl:duration:)`** (line 70)
  - Purpose: persist an online like/unlike.
  - Mechanics: liked → `LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(..., synced: isSignedIn))`; unliked → `removeLikedSong(videoId:)`; then post `likedSongsUpdatedNotification` (line 90).
  - Called by: `PlayerControls.swift:475`.
  - Side effects: DB write + notification. Threading: synchronous on caller.
- **`mirrorOfflineLike(trackID: String)`** (line 93)
  - Purpose: mirror a local-library like into the liked-songs table.
  - Mechanics: `liked = LocalDatabaseManager.shared.isLiked(filePath: trackID)` (line 94). If liked → find track in `LocalLibraryManager.shared.allTracks` by `id == trackID || fileURL.path == trackID`; `key = track.ytVideoId ?? track.fileURL.path`; `addLikedSong(LikedSongRecord(videoId: key, ..., synced: true, sourceType: "local"))` (lines 96–109). If unliked → remove by `key` if track found, else remove by `trackID` (lines 110–118). Post `likedSongsUpdatedNotification` (line 120).
  - Called by: `PlayerControls.swift:468`.
  - Note: local like → `synced: true` hard-coded (treated as already synced — no account sync attempted).
- **`syncUnsyncedToAccount()`** (line 125)
  - Purpose: one-time local→account sync.
  - Mechanics: if not signed in → post notification, return (lines 126–129); guard `!isSyncing`; `unsynced = fetchUnsyncedLikedSongs()`; `isSyncing = true`; `syncNext(unsynced)` (lines 130–134).
  - Called by: `PlayerControls.swift:486` (guarded by `isSignedIn`).
- **`syncNext(_ remaining: [LikedSongRecord])`** (line 137) — recursive
  - Purpose: sequentially like each unsynced song in the web player.
  - Mechanics: guard `isSyncing`, non-empty, `NetworkMonitor.shared.isReachable` else reset `isSyncing = false` + post (lines 138–142). Take first record; `switchToOnlineMode()`; `PlaylistManager.shared.playOnlineVideo(videoId:)` (lines 146–147). After **2.5 s** main-async → `clickLikeButton()`; after another **1.0 s** → `readLikeState { liked in ... }`; if liked → `setLikedSongSynced(videoId:)`; recurse `syncNext(items)` (lines 149–160).
  - Timing constants: 2.5 s load wait, 1.0 s post-click wait.
  - Errors/races: if the track doesn't load or like button missing, `readLikeState` returns false and item is skipped silently (never marked synced; retried on next sync).
- **`clickLikeButton()`** (line 163)
  - Purpose: click the YTMusic like button via JS.
  - JS (lines 164–187): locate `ytmusic-player-bar`/`#player-bar`; then `ytmusic-like-button-renderer`/`#like-button-renderer`; button via `#button-shape-like button, .like-button`; fallback: iterate `button`s whose `aria-label`/`title` contains `like` or `thumbs up` but not `dislike`; `click()`; returns `true`/`false`.
  - Mechanics: `NowPlayingManager.shared.evaluateJS(js)` (fire-and-forget).
- **`readLikeState(completion: @escaping (Bool) -> Void)`** (line 191)
  - Purpose: read current like state from DOM.
  - JS (lines 192–210): read `like-status` attribute (`LIKE` → true; `DISLIKE`/`INDIFFERENT` → false); else inspect `#button-shape-like button`, `button[aria-label*="Remove from your Liked Songs"]`, `button[aria-label*="Undo like"]`; `aria-pressed == "true"` or label contains `undo like`/`remove from your liked` → true.
  - Mechanics: `NowPlayingManager.shared.evaluateJSWithResult(js)`; `completion((result as? Bool) ?? false)`.

### Risks (LikedSongsManager)
- Cookie-based sign-in detection is heuristic; cookies vary by account/region (INFERRED false-negatives).
- Sync is DOM-fragile: relies on exact YTMusic markup selectors; YouTube UI changes silently break `clickLikeButton`/`readLikeState` (no user-visible failure; items just never sync).
- Hard-coded `synced: true` for local like mirrors means local likes are never pushed to the account.
- `syncNext` recursion has no max retries; a permanently failing item loops once (each unsynced item attempted once per invocation), but `syncUnsyncedToAccount` can be re-invoked repeatedly → repeated 3.5 s × n traffic.
- No cancellation: toggling the toggle/desiredLiked mid-sync does not stop the recursive chain.
- `isSignedIn` only updates on `refreshSignInStatus`/`probeSignInFromDOM` calls — may be stale between calls (INFERRED).

---

# FILE ENTRY 5 — `Sources/Mooziac/Managers/DiscordRPCManager.swift` (412 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/DiscordRPCManager.swift`
- **Purpose**: Full Discord Rich Presence (RPC) client over the Discord IPC unix socket: finds the socket, performs the opcode-framed handshake, maintains a heartbeat/refresh loop, publishes SET_ACTIVITY frames with playback state, and clears presence when paused/no track.
- **Subsystem**: Managers (external integration / IPC).
- **Dependencies**: `PlaybackState` (`Models/PlaybackState.swift` — incl. `getAccurateTime()`), `NowPlayingManager.shared.currentState`.
- **Imports**: `import Foundation` (1), `import AppKit` (2).
- **Classes/structs/enums defined**: `RPCOpcode` (enum), `DiscordRPCManager` (final class, singleton).
- **IPC mechanism**:
  - **Socket**: unix domain, `SOCK_STREAM`, path searched in order `/tmp`, `NSTemporaryDirectory()`, `ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"`; tries `discord-ipc-0` … `discord-ipc-9` in each dir, then scans `tmpDir` for entries prefixed `discord-ipc-` (lines 103–128).
  - **Frame format**: 8-byte header (opcode UInt32 LE + payload length UInt32 LE) + JSON payload (lines 181–186, 275–280).
  - **Opcodes**: `handshake = 0`, `frame = 1`, `close = 2`, `ping = 3`, `pong = 4` (lines 4–10).
  - **Handshake**: connect → send opcode 0 with `{"v":1,"client_id":"<clientId>"}` → synchronously read 8-byte header + body → require body contains `"READY"` (lines 174–219).
  - **PING/PONG**: incoming opcode 3 is answered with opcode 4 echoing the same payload (lines 262–265).
  - **Timing**: reconnect timer every 4.0 s (line 60); periodic refresh heartbeat every 12 s (every 3rd tick, lines 68–75); socket timeouts 2 s send/recv (lines 141–143).
- **Secrets**: a Discord application Client ID constant `clientId = "1537169013174435870"` (line 22). This is an application ID, not a token; per instructions the numeric value is a public identifier (registered client ID) — recorded as a constant, no secret printed elsewhere.
- **Defaults key**: `YTM_discordRPC_enabled` (Bool, default `true`) (lines 28–30).
- **Files it communicates with**: `Core/NowPlayingManager/NowPlayingManager.swift:125` (`updatePresence`); `App/AppDelegate.swift:35-36` (`startReconnectLoop`, `tryConnect`); `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift:59-61` (enable toggle).

## Enum: `RPCOpcode` (line 4) — `enum`, raw `UInt32`
| Case | Raw | Line | Meaning |
| :--- | :--- | :--- | :--- |
| `handshake` | `0` | 5 | initial connect frame |
| `frame` | `1` | 6 | command/data frame |
| `close` | `2` | 7 | close |
| `ping` | `3` | 8 | Discord→client keepalive |
| `pong` | `4` | 9 | client→Discord keepalive reply |

## Class: `DiscordRPCManager` (line 12) — `final class`, singleton

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `DiscordRPCManager` | `static let` | 13 | singleton |
| `socketFd` | `Int32` | `private var` | 15 | `-1` when closed |
| `_isConnected` | `Bool` | `private var` | 16 | queue-protected |
| `isConnected` | `Bool` | `public var` | 17 | `queue.sync { _isConnected }` |
| `clientId` | `String` | `private let` | 22 | `"1537169013174435870"` |
| `reconnectTimer` | `Timer?` | `private var` | 23 | 4 s period |
| `periodicRefreshCounter` | `Int` | `private var` | 24 | 0…2 then refresh |
| `queue` | `DispatchQueue` | `private let` | 25 | `"com.mooziac.discordrpc"`, qos `.utility` |
| `isEnabled` | `Bool` | `public var` | 27 | UserDefaults-backed `YTM_discordRPC_enabled`, default `true`; setter dispatches to `queue` (connect+update or clear+close) |

### Init / deinit
- `private init()` (line 44): calls `signal(SIGPIPE, SIG_IGN)` (global ignore of SIGPIPE), then `startReconnectLoop()` (line 47).
- `deinit` (line 50): `stopReconnectLoop()`; `queue.sync { closeSocketInternal() }`. **NOTE: `shared` is never deallocated in practice; deinit is effectively dead (INFERRED).**

### Functions
- **`startReconnectLoop()`** (line 57)
  - Purpose: start the 4 s periodic reconnect/heartbeat timer on the main run loop.
  - Mechanics: main-async invalidate existing; `Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true)`: on `queue`, if `!isEnabled` skip; if not connected → `tryConnectInternal()`; else every 3rd tick `drainSocket()` then `updatePresenceInternal(NowPlayingManager.shared.currentState)` (lines 60–78).
- **`stopReconnectLoop()`** (line 82): main-async invalidate + nil.
- **`tryConnect()`** (line 89): queue-async → `tryConnectInternal()`. Called by `AppDelegate.swift:36`.
- **`tryConnectInternal()`** (line 95): guard `isEnabled && !_isConnected`; find socket; `connectToSocket(path:)` then `updatePresenceInternal(currentState)`.
- **`findDiscordIPCSocket() -> String?`** (line 103): search order `/tmp`, `NSTemporaryDirectory()`, env `TMPDIR`; for each, probe `discord-ipc-0..9` via `FileManager.fileExists`; finally scan `tmpDir` subdirs with prefix `discord-ipc-`. Returns first hit or `nil`.
- **`connectToSocket(path: String) -> Bool`** (line 130)
  - Mechanics (exact): `closeSocketInternal()`; `socket(AF_UNIX, SOCK_STREAM, 0)`; `setsockopt(SO_NOSIGPIPE)`; `SO_RCVTIMEO`/`SO_SNDTIMEO` = `timeval(2,0)`; build `sockaddr_un` (`sun_len = sizeof`, `sun_family = AF_UNIX`, `sun_path` copied bytewise; reject path too long); `connect`; send handshake frame opcode 0, JSON `{"v":1,"client_id":"<clientId>"}`; `recv` 8-byte header; `respLen` from header bytes 4..8 (`< 65536` guard); `recv` body; require body contains `"READY"`; on success set `socketFd`, `_isConnected = true`, reset `periodicRefreshCounter`. Any failure closes fd and returns `false`.
- **`closeSocketInternal()`** (line 227): `close(socketFd)` if ≥ 0, reset to `-1`, `_isConnected = false`.
- **`drainSocket()`** (line 235)
  - Purpose: non-blocking drain of pending frames; replies PONG to PING.
  - Mechanics: loop `recv(fd, 8 bytes, MSG_DONTWAIT)`; `bytesRead <= 0` → if 0 or error not in {`EWOULDBLOCK`, `EAGAIN`} → `closeSocketInternal()`, break; else parse 4-byte opcode + 4-byte length; if length in `(0, 65536)` read body; if opcode == `.ping.rawValue` → `sendFrame(opcode: .pong, payload: body)`.
- **`sendFrame(opcode: RPCOpcode, payload: String) -> Bool`** (line 271)
  - Mechanics: build 8-byte header + UTF-8 payload; `send`; short write → `closeSocketInternal()` + `false`; else `drainSocket()`; return `true`.
- **`updatePresence(state: PlaybackState)`** (line 296): queue-async → `updatePresenceInternal(state:)`. Called by `NowPlayingManager.swift:125`.
- **`updatePresenceInternal(state: PlaybackState)`** (line 302)
  - Purpose: publish SET_ACTIVITY frame reflecting playback.
  - Mechanics:
    1. Guard `isEnabled`; if not connected, find socket + `connectToSocket`, else return (lines 303–307).
    2. If `!state.isPlaying || title empty || title == "Not Playing"` → `clearPresenceInternal()` and return (lines 309–313).
    3. `pid = ProcessInfo.processInfo.processIdentifier`; `nowMs = Int64(Date().timeIntervalSince1970 * 1000)` (lines 315–316).
    4. Truncations: `titleStr = String(state.title.prefix(128))`; `artistStr = state.artist.isEmpty ? "Mooziac" : String("by \(state.artist) • Mooziac".prefix(128))` (lines 318–319).
    5. Assets dict: `small_image = "mooziac"`, `large_text = titleStr`, `small_text = "Mooziac — Native YouTube Music for Mac"`; `large_image` = `state.artworkUrl` if `http://`/`https://` prefix else `"mooziac"` (lines 321–331).
    6. Activity: `type = 2` (Listening to), `details = titleStr`, `state = artistStr`, `assets` (lines 333–338).
    7. **Timestamps**: via `state.getAccurateTime()`; if `duration > 0` and both non-NaN/non-infinite → `validAccurate = max(0, accurateTime)`, `validDuration = max(0, duration)`, `remaining = max(0, validDuration - validAccurate)`, `start = nowMs - Int64(validAccurate*1000)`, `end = nowMs + Int64(remaining*1000)`; only set if `startTimeMs > 0 && endTimeMs >= startTimeMs` (lines 340–355).
    8. **Button**: `targetUrl = state.pageUrl`, overridden by `"https://music.youtube.com/watch?v=\(state.videoId)"` if videoId present; only if starts `https://`/`http://` and contains `music.youtube.com`; truncated to 512; button `{"label": "Listen on YouTube Music", "url": validUrl}` (lines 357–369).
    9. Payload: `cmd = "SET_ACTIVITY"`, `args.pid`, `args.activity`, `nonce = UUID().uuidString` (lines 371–378); JSON-serialize; `sendFrame(opcode: .frame, ...)`; failure → `closeSocketInternal()` (lines 380–385).
- **`clearPresence()`** (line 388): queue-async → `clearPresenceInternal()`.
- **`clearPresenceInternal()`** (line 394)
  - Purpose: clear presence from Discord profile.
  - Mechanics: guard connected; payload `cmd = "SET_ACTIVITY"`, `args.pid`, `activity = NSNull()`, `nonce`; `sendFrame(opcode: .frame, ...)`; failure → close.

### Risks (DiscordRPCManager)
- Synchronous blocking `recv` during handshake (2 s timeout) inside the utility queue — brief queue stalls are fine but non-blocking pattern not used at connect time.
- `signal(SIGPIPE, SIG_IGN)` is process-global (affects all sockets in app).
- Every 3rd timer tick re-sends full presence even if nothing changed — ~1 SET_ACTIVITY/12 s.
- If Discord socket path search finds a stale/unusable socket, `connectToSocket` fails silently and retries every 4 s forever.
- No handling of opcode `close` (2) from Discord; a closed-by-server connection is only detected on next send failure or drain.
- `updatePresence`/`clearPresence` are public fire-and-forget (queue-async) — caller cannot observe failure.
- Presence reflects `currentState` which may be stale if JS bridge hasn't updated yet (INFERRED lag).
- `isConnected` computed via `queue.sync` from main while the queue may be blocked in `recv` (2 s) — potential main-thread stall if ever read from main during handshake (INFERRED).

---

# FILE ENTRY 6 — `Sources/Mooziac/Managers/TrackNotificationManager.swift` (90 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/TrackNotificationManager.swift`
- **Purpose**: Posts a macOS user notification on each track change with the album-art image attached; shows notifications even when the app is foreground.
- **Subsystem**: Managers (user notifications).
- **Dependencies**: `UserNotifications` framework only.
- **Imports**: `import AppKit` (1), `import UserNotifications` (2).
- **Classes/structs/enums defined**: `TrackNotificationManager` (`NSObject`, `UNUserNotificationCenterDelegate`).
- **External APIs**: `UNUserNotificationCenter`, `URLSession.shared` (artwork download).
- **Storage paths**: temp dir `FileManager.default.temporaryDirectory`; temp artwork files named `ytm_art_<UUID>.jpg`; all `ytm_art_*` files cleaned before writing a new one (lines 66–75).
- **Files it communicates with**: called by `Core/NowPlayingManager/ObserverBridge.swift:433` (`notifyTrackChange`).

## Class: `TrackNotificationManager` (line 4) — `public class`, NSObject, UNUserNotificationCenterDelegate, singleton

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `TrackNotificationManager` | `public static let` | 5 | singleton |
| `lastNotifiedTrack` | `String` | `private var` | 7 | dedup key `"<title>|<artist>"` |

### Init
`override init()` (line 9): `super.init()` + `setupNotifications()`.

### Functions
- **`setupNotifications()`** (line 14)
  - Purpose: set delegate + request authorization.
  - Mechanics: `UNUserNotificationCenter.current().delegate = self`; `requestAuthorization(options: [.alert, .sound])` with `print` logging on granted/error (lines 17–23).
- **`notifyTrackChange(title:artist:artworkUrl:)`** (line 26)
  - Purpose: post a track-change notification.
  - Mechanics: guard non-empty title and `!= "Not Playing"` (line 27); dedup key `"\(title)|\(artist)"` vs `lastNotifiedTrack` (lines 29–31); build `UNMutableNotificationContent` with `title`, `subtitle = artist`, `body = "Playing on YouTube Music"` (lines 33–36); if `URL(string: artworkUrl)` valid → `downloadImage` then attach `UNNotificationAttachment(identifier: "albumArt", url:, options: nil)` and post; else post without attachment (lines 38–48).
  - Called by: `ObserverBridge.swift:433`.
- **`postNotification(content: UNMutableNotificationContent)`** (line 51)
  - Purpose: add a `UNNotificationRequest` (identifier `UUID().uuidString`, `trigger: nil` → immediate).
  - Errors: `print("[TrackNotificationManager] Failed to post notification: \(error.localizedDescription)")` (line 55).
- **`downloadImage(from url: URL, completion: @escaping (URL?) -> Void)`** (line 60)
  - Purpose: download artwork to temp file for attachment.
  - Mechanics: `URLSession.shared.dataTask`; on data → clean prior temp `ytm_art_*` files (lines 69–73); write to `tempDir/ytm_art_<UUID>.jpg` (line 75); completion with URL or `nil`. Not dispatched to main — completion on URLSession queue (INFERRED).
- **`userNotificationCenter(_:willPresent:withCompletionHandler:)`** (line 87) — delegate
  - Purpose: show banner/list/sound while app is active: `completionHandler([.banner, .list, .sound])`.

### Risks (TrackNotificationManager)
- `downloadImage` completion runs on the URLSession queue; `postNotification` then runs off-main — `UNUserNotificationCenter.add` is safe off-main, but ordering vs. subsequent notifications is not guaranteed (INFERRED).
- Aggressive temp cleanup deletes ALL `ytm_art_*` files app-wide before each write — concurrent downloads could delete a file another in-flight request just wrote (race; both write distinct UUID names, so delete-before-write is benign unless same instant — INFERRED low risk).
- Artwork URL may be a huge or slow CDN image; notification may post without artwork if download fails.
- No `UNUserNotificationCenter.current().removePendingNotificationRequests` — dedup only via `lastNotifiedTrack`.
- Permission requested on every init (singleton init at first access).

---

# FILE ENTRY 7 — `Sources/Mooziac/Managers/NetworkMonitor.swift` (88 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/NetworkMonitor.swift`
- **Purpose**: Wraps `NWPathMonitor` to expose reachability + interface type and broadcast changes app-wide.
- **Subsystem**: Managers (network state).
- **Dependencies**: `Network` framework (`NWPathMonitor`, `NWPath`).
- **Imports**: `import Foundation` (1), `import Network` (2), `import AppKit` (3).
- **Classes/structs/enums defined**: `NetworkMonitor`, nested `ConnectionType` enum.
- **Notification names**:
  - `statusChangedNotification` = `Notification.Name("NetworkMonitorStatusChanged")` (line 8).
  - `reconnectedNotification` = `Notification.Name("NetworkMonitorReconnected")` (line 9).
- **Files it communicates with**:
  - Start/stop: `App/AppDelegate.swift:32` (`startMonitoring`).
  - Observers: `Core/NowPlayingManager/NowPlayingManager.swift:54`; `Web/YTMWebView.swift:107,116`; `Views/Player/DynamicIslandPlayerView/Core.swift:178,187`; `Views/Components/HeaderView.swift:28`.
  - Readers of `isReachable`: `LyricsManager.swift:274`, `LikedSongsManager.swift:138`, `MainViewController.swift:211,218`, `PlaylistManager.swift:571,610`, `PlayerControls.swift` (multiple), `PlaylistLibraryView`, `OfflineOverlayView.swift:95`, `Core.swift:928`.

## Class: `NetworkMonitor` (line 5) — `public final class`, singleton

### Enum: `NetworkMonitor.ConnectionType` (line 11) — `public enum: String`
| Case | Raw | Line |
| :--- | :--- | :--- |
| `wifi` | `"Wi-Fi"` | 12 |
| `cellular` | `"Cellular"` | 13 |
| `ethernet` | `"Ethernet"` | 14 |
| `other` | `"Network"` | 15 |
| `none` | `"Offline"` | 16 |

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `NetworkMonitor` | `public static let` | 6 | singleton |
| `statusChangedNotification` | `Notification.Name` | `public static let` | 8 | `"NetworkMonitorStatusChanged"` |
| `reconnectedNotification` | `Notification.Name` | `public static let` | 9 | `"NetworkMonitorReconnected"` |
| `monitor` | `NWPathMonitor` | `private let` | 19 | |
| `queue` | `DispatchQueue` | `private let` | 20 | `"com.mooziac.networkmonitor"`, qos `.utility` |
| `isReachable` | `Bool` | `private(set) public var` | 22 | default `true`; `didSet` posts on change |
| `connectionType` | `ConnectionType` | `private(set) public var` | 45 | default `.wifi` |
| `isMonitoring` | `Bool` | `private var` | 46 | guard flag |

### isReachable `didSet` (lines 23–43)
- On change (old != new): main-async post `statusChangedNotification` with `userInfo: ["isReachable": self.isReachable, "connectionType": self.connectionType]` (lines 26–33); additionally post `reconnectedNotification` when reachable (lines 34–39).
- Note: `userInfo["connectionType"]` is the *new* value (property already updated by caller).

### Init
`private init() { monitor = NWPathMonitor() }` (lines 48–50). Does NOT auto-start.

### Functions
- **`startMonitoring()`** (line 52)
  - Purpose: begin path observation (idempotent via `isMonitoring`).
  - Mechanics: `pathUpdateHandler` reads `path.status == .satisfied`; `getInterfaceType(from: path)`; sets `connectionType = status ? type : .none` then `isReachable = status`; `print("[NetworkMonitor] Status changed: \(status ? "ONLINE (\(type.rawValue))" : "OFFLINE")")` (lines 56–66); `monitor.start(queue: queue)` (line 68).
  - Lifecycle: called once from `AppDelegate.swift:32`.
- **`stopMonitoring()`** (line 71): `monitor.cancel()`; `isMonitoring = false`. (No caller observed in repo — potential dead API, INFERRED.)
- **`getInterfaceType(from path: NWPath) -> ConnectionType`** (line 77): priority `usesInterfaceType(.wifi)` → `.wifi`; `.cellular` → `.cellular`; `.wiredEthernet` → `.ethernet`; else `.other`. Note: a Mac with both Wi-Fi and Ethernet reports Wi-Fi first.

### Risks (NetworkMonitor)
- `stopMonitoring` has no caller — the monitor runs for the app's lifetime (probably intended).
- `isReachable` default `true` before first path update — brief startup window where offline is treated as online (INFERRED).
- `didSet` posts even if connectionType changed but reachability didn't (only reachability change triggers).
- Path status is a snapshot; no retry/backoff here (reconnect handled by consumers on `reconnectedNotification`).

---

# FILE ENTRY 8 — `Sources/Mooziac/Managers/AppArtworkHelper.swift` (277 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/AppArtworkHelper.swift`
- **Purpose**: Artwork/thumbnail service: default artwork, deterministic cache-key generation (SHA-256), memory (NSCache) + disk caching, synchronous and asynchronous thumbnail resolution, embedded-metadata vs sidecar extraction, downsizing via ImageIO.
- **Subsystem**: Managers (image processing / caching).
- **Dependencies**: `LocalTrack` (`Models/LocalTrack.swift`), `ImageIO`, `AVFoundation` (`AVURLAsset` metadata), `CryptoKit` (`SHA256`).
- **Imports**: `import AppKit` (1), `import Foundation` (2), `import ImageIO` (3), `import AVFoundation` (4), `import CryptoKit` (5).
- **Classes/structs/enums defined**: `AppArtworkHelper`.
- **Storage paths**:
  - Disk cache: `~/Library/Caches/Mooziac/Thumbnails/` (`thumbnailCacheFolderURL`, line 79–86; falls back to `NSTemporaryDirectory()` if caches dir missing).
  - Disk files: `<key>.jpg` where key is the SHA-256 hex digest.
- **Magic numbers**: memory cache `countLimit = 500`, `totalCostLimit = 50 * 1024 * 1024` (50 MB, lines 15–16); downsampling max pixel = `targetSize * 2` (2× Retina, lines 65, 213); JPEG compression factor `0.85` (line 271); min pixels `16` (line 213); cost floor `1024` bytes and `pixels * 4` bytes per pixel (lines 104–113).
- **Files it communicates with**:
  - Reads: `Models/LocalTrack.swift` (via `LocalTrack.artwork` getter → `getThumbnail`).
  - Callers: `Views/Libraries/OfflineLibraryView.swift:730,734`; `Views/Libraries/PlaylistLibraryView.swift:2698,2702,2922,2926,3144,3148,3375,3379`; `Managers/LocalLibraryManager.swift:470,481` (`removeCachedThumbnails`).

## Class: `AppArtworkHelper` (line 7) — `public final class`, singleton

### Properties
| Property | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `shared` | `AppArtworkHelper` | `public static let` | 8 | singleton |
| `cachedCompressedArtwork` | `NSImage?` | `private var` | 10 | cached default artwork |
| `memoryCache` | `NSCache<NSString, NSImage>` | `private let` | 11 | keyed by SHA-256 cache key |
| `ioQueue` | `DispatchQueue` | `private let` | 12 | `"com.mooziac.artwork.io"`, qos `.userInitiated`, `.concurrent` |

### Init
`private init()` (line 14): sets `countLimit = 500`, `totalCostLimit = 50 MB`.

### Properties/functions
- **`defaultArtwork`** (line 19, `public static var`): returns `shared.getCompressedDefaultArtwork()`.
- **`getCompressedDefaultArtwork(targetSize: CGFloat = 128) -> NSImage`** (line 23)
  - Purpose: compressed default Mooziac logo.
  - Mechanics: returns `cachedCompressedArtwork` if set; loads from Bundle resources `"MOOZIAC"`/`"MOOZIAC_transparent"` `.png`; else from filesystem paths: `"MOOZIAC.png"`, `"Resources/MOOZIAC.png"`, `"Resources/MOOZIAC_transparent.png"`, `"/Users/harshshirke/local/projects/mp3kal/MOOZIAC.png"`, `"/Users/harshshirke/local/projects/mp3kal/Resources/MOOZIAC.png"` (lines 38–44 — **note: two hard-coded absolute developer-machine paths**); fallback `NSImage(systemSymbolName: "music.note", accessibilityDescription: "Mooziac")`; downsamples via ImageIO thumbnail at `targetSize * 2`; caches result.
- **`thumbnailCacheFolderURL: URL`** (line 79): `~/Library/Caches/Mooziac/Thumbnails`, creates dir if missing.
- **`cacheKey(for fileURL: URL, dateAdded: Date, targetSize: CGFloat = 128) -> String`** (line 89)
  - Purpose: deterministic cache key.
  - Mechanics: `effectiveTimestamp = dateAdded.timeIntervalSince1970`; if jpg/png sidecar exists, bump to max(contentModificationDate, dateAdded) (lines 91–97); `rawKey = "\(fileURL.path)_\(effectiveTimestamp)_\(Int(targetSize))"`; `SHA256.hash(data: Data(rawKey.utf8))` → lowercase hex (lines 98–100).
- **`approximateMemoryCost(for image: NSImage) -> Int`** (line 104): `max(1024, pixelsWide * pixelsHigh * 4)`; `pixelsWide/High` from first representation, falling back to `size * 2`.
- **`getCachedThumbnail(for track: LocalTrack, targetSize: CGFloat = 128) -> NSImage?`** (line 116): memory-cache-only lookup. Called by `OfflineLibraryView.swift:730`, `PlaylistLibraryView.swift:2698,2922,3144,3375`.
- **`removeCachedThumbnails(for track: LocalTrack)`** (line 122): for sizes `[64, 128, 256]` removes memory-cache entry and deletes `<key>.jpg` on disk. Called by `LocalLibraryManager.swift:470,481`.
- **`getThumbnail(for track: LocalTrack, targetSize: CGFloat = 128) -> NSImage?`** (line 135) — **synchronous**
  - Purpose: sync thumbnail resolver.
  - Mechanics (exact order): 1) memory cache hit → return; 2) disk `<key>.jpg` exists → load, store in memory cache with cost, return; 3) `extractAndDownsample(from: track.fileURL, targetSize:)` → `saveThumbnailToDisk` + memory-store + return; 4) fallback `getCompressedDefaultArtwork(targetSize:)`.
  - Called by: `LocalTrack.artwork` getter (line 16 of `LocalTrack.swift`).
- **`loadThumbnail(for track: LocalTrack, targetSize: CGFloat = 128, completion: @escaping (NSImage?) -> Void)`** (line 162) — **asynchronous**
  - Purpose: async resolver with main-thread completion.
  - Mechanics: memory hit → `completion(memoryHit)` immediately (caller thread); else `ioQueue.async` (concurrent queue) → disk check → `saveThumbnailToDisk` + memory-store → `DispatchQueue.main.async { completion(...) }`; fallback default artwork likewise on main (lines 172–198).
- **`downsample(data: Data, targetSize: CGFloat = 128) -> NSImage?`** (line 202): `CGImageSourceCreateWithData` + `createThumbnail`.
- **`downsample(fileURL: URL, targetSize: CGFloat = 128) -> NSImage?`** (line 207): `CGImageSourceCreateWithURL` + `createThumbnail`.
- **`createThumbnail(from source: CGImageSource, targetSize: CGFloat) -> NSImage?`** (line 212)
  - Mechanics: `maxPixel = max(16, targetSize * 2)`; options `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceCreateThumbnailWithTransform`, `kCGImageSourceShouldCacheImmediately`, `kCGImageSourceThumbnailMaxPixelSize`; `CGImageSourceCreateThumbnailAtIndex(source, 0, ...)`; `NSImage(cgImage:, size: NSSize(targetSize, targetSize))`.
- **`extractAndDownsample(from fileURL: URL, targetSize: CGFloat) -> NSImage?`** (line 227)
  - Purpose: artwork extraction pipeline.
  - Mechanics:
    - **Tier 1 — embedded metadata** (`AVURLAsset(url: fileURL)`): iterate `asset.metadata` for `commonKey == .commonKeyArtwork` OR (`keySpace == .iTunes` and key `"covr"`) OR (`keySpace == .id3` and key `"APIC"`) OR (`keySpace == .quickTimeMetadata` and key contains `"artwork"`); use `item.dataValue ?? item.value as? Data`; downsample (lines 229–241). Then iterate `asset.commonMetadata` for `.commonKeyArtwork` (lines 242–248).
    - **Tier 2 — sidecar images**: `jpg`, `png`, `jpeg`, `webp` sibling files (lines 251–262); first existing + successful downsample wins.
    - Returns `nil` if nothing found.
- **`saveThumbnailToDisk(image: NSImage, key: String)`** (line 268)
  - Mechanics: `tiffRepresentation` → `NSBitmapImageRep` → JPEG with `[.compressionFactor: 0.85]` → `try? jpegData.write(to: <cacheFolder>/<key>.jpg, options: .atomic)`.
  - NOTE: method comment says "Disk Persistence"; **no dominant color extraction algorithm exists in this file** — the "dominant color extraction" in the task brief was NOT found; artwork colors are instead derived elsewhere (e.g., `Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift` — outside scope). Verified absence: grep for "color"/"Color" in this file returns nothing.

### Risks (AppArtworkHelper)
- Two absolute paths to a developer's machine (`/Users/harshshirke/local/projects/mp3kal/...`) are hard-coded (lines 42–43) — will fail for any other user, leaking the developer home path into the binary.
- Concurrent `ioQueue` (`attributes: .concurrent`) means two threads can generate + write the same `<key>.jpg` simultaneously; both writes are atomic but redundant work occurs.
- `loadThumbnail`'s memory-hit path calls `completion` on the caller thread, while disk/generate paths call on main — inconsistent threading contract.
- No dominant-color extraction in this file (task brief expected it; it's implemented elsewhere or absent — see risk note above).
- `cachedCompressedArtwork` is unbounded single image; fine.
- `LocalTrack.artwork` getter calls the synchronous `getThumbnail` — doing so on the main thread can block on disk I/O/decoding for uncached tracks (INFERRED hot-path risk; views use `loadThumbnail` async, but `artwork` is synchronous).
- SHA-256 key means cache files never expire by age — only by manual `removeCachedThumbnails`; stale thumbnails accumulate if tracks change without sidecar mtime changes.

---

# FILE ENTRY 9 — `Sources/Mooziac/Models/LocalTrack.swift` (75 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/LocalTrack.swift`
- **Purpose**: Data model for a local audio file: identity, metadata, artwork, lyrics sidecar, like state, video-ID linkage.
- **Subsystem**: Models.
- **Dependencies**: `AppArtworkHelper` (artwork getter), `LyricsManager` (`cleanSongInfo`), `LocalLibraryManager` (`isLiked`, `toggleLike`).
- **Imports**: `import AppKit` (1), `import Foundation` (2), `import AVFoundation` (3) — **AVFoundation imported but unused in this file (dead import, INFERRED)**.
- **Classes/structs/enums defined**: `LocalTrack` (struct).
- **Codable**: none.
- **Files it communicates with**:
  - Consumers: `Audio/NativeAudioPlayer.swift` (`currentTrack`), `Managers/HistoryManager.swift`, `Managers/LikedSongsManager.swift`, `Managers/LocalLibraryManager.swift`, `Managers/PlaylistManager.swift`, `Views/Libraries/OfflineLibraryView.swift`, `Views/Libraries/PlaylistLibraryView.swift`, `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift`, `AppArtworkHelper`.

## Struct: `LocalTrack` (line 5) — `public struct: Identifiable, Equatable`

### Fields
| Field | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `String` | `public let` | 6 | identity |
| `title` | `String` | `public var` | 7 | |
| `artist` | `String` | `public var` | 8 | |
| `album` | `String` | `public var` | 9 | |
| `duration` | `Double` | `public var` | 10 | seconds |
| `fileURL` | `URL` | `public let` | 11 | |
| `_artwork` | `NSImage?` | `private var` | 12 | backing storage |
| `artwork` | `NSImage?` | `public var` | 13–21 | getter: `_artwork ?? AppArtworkHelper.shared.getThumbnail(for: self)`; setter: `_artwork = newValue` |
| `artworkURL` | `URL?` | `public var` | 22 | |
| `lrcURL` | `URL?` | `public var` | 23 | assigned lyrics sidecar |
| `dateAdded` | `Date` | `public var` | 24 | |
| `ytVideoId` | `String?` | `public var` | 25 | linkage to YT video |
| `isLiked` | `Bool` | `public var` | 26–35 | getter: `LocalLibraryManager.shared.isLiked(trackID: id)`; setter: toggles via `LocalLibraryManager.shared.toggleLike(for: id)` when changed |

### Init (line 37)
`public init(id: String = UUID().uuidString, title: String, artist: String, album: String = "", duration: Double = 0.0, fileURL: URL, artwork: NSImage? = nil, artworkURL: URL? = nil, lrcURL: URL? = nil, isLiked: Bool = false, dateAdded: Date = Date(), ytVideoId: String? = nil)`
- Defaults: empty title → `fileURL.deletingPathExtension().lastPathComponent` (line 52); empty artist → `"Local Audio"` (line 53). `isLiked` param is **ignored** (not stored — like state is always read from LocalLibraryManager; the parameter is dead, INFERRED).

### Computed properties
- **`cleanTitle`** (line 64): `LyricsManager.cleanSongInfo(title)`.
- **`cleanArtist`** (line 68): `LyricsManager.cleanSongInfo(artist)`.

### Equatable (line 72)
`== (lhs, rhs)`: `lhs.id == rhs.id || lhs.fileURL == rhs.fileURL` — **matches on either id OR path** (note: two different ids with same fileURL are equal).

### Risks (LocalTrack)
- `isLiked` initializer parameter is discarded — constructing with `isLiked: true` silently does nothing.
- `artwork` getter runs synchronous disk/decode work; main-thread hot path risk (see AppArtworkHelper).
- Equality via id-or-path can collapse distinct library entries that share a file path.
- Not Codable — persistence handled by `LocalDatabaseManager`'s own SQLite row mapping (duplicated field list).
- `AVFoundation` import unused.

---

# FILE ENTRY 10 — `Sources/Mooziac/Models/PlaybackState.swift` (29 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlaybackState.swift`
- **Purpose**: The app-wide current playback snapshot consumed by observers, UI, and Discord RPC.
- **Subsystem**: Models.
- **Dependencies**: `RepeatMode` (`Models/RepeatMode.swift`), `PlaybackEngineMode` (`Models/PlaybackEngineMode.swift`), `QuartzCore` (`CACurrentMediaTime`).
- **Imports**: `import Foundation` (1), `import QuartzCore` (2).
- **Classes/structs/enums defined**: `PlaybackState` (struct) — **internal, NOT `public`** (matches AGENTS.md that Models stay AppKit-free, but visibility is internal).
- **Codable**: none.
- **Files it communicates with**: `Core/NowPlayingManager/*` (state producer/consumer), `Managers/DiscordRPCManager.swift` (`updatePresence(state:)`, `getAccurateTime()`), views (player UI).

## Struct: `PlaybackState` (line 4) — `struct` (internal)

### Fields
| Field | Type | Line | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `title` | `String` | 5 | `""` | |
| `artist` | `String` | 6 | `""` | |
| `album` | `String` | 7 | `""` | |
| `artworkUrl` | `String` | 8 | `""` | |
| `isPlaying` | `Bool` | 9 | `false` | |
| `currentTime` | `Double` | 10 | `0.0` | seconds |
| `duration` | `Double` | 11 | `0.0` | seconds |
| `pageUrl` | `String` | 12 | `""` | |
| `videoId` | `String` | 13 | `""` | |
| `trackID` | `String` | 14 | `""` | |
| `hostTimestamp` | `Double` | 15 | `0.0` | `CACurrentMediaTime()` when reported |
| `playbackRate` | `Double` | 16 | `1.0` | |
| `isLiked` | `Bool` | 17 | `false` | |
| `isShuffleOn` | `Bool` | 18 | `false` | |
| `isRepeatOn` | `Bool` | 19 | `false` | |
| `repeatMode` | `RepeatMode` | 20 | `.off` | |
| `engineMode` | `PlaybackEngineMode` | 21 | `.online` | |

### Method
- **`getAccurateTime() -> Double`** (line 24)
  - Purpose: sub-millisecond exact audio time extrapolator.
  - Mechanics: if `isPlaying && hostTimestamp > 0` → `max(0, currentTime + (CACurrentMediaTime() - hostTimestamp) * playbackRate)`; else returns `currentTime`.
  - Called by: `DiscordRPCManager.updatePresenceInternal` (line 340).
  - Inputs: none (state). Output: `Double` seconds. Errors: none. Async: none.

### Risks (PlaybackState)
- Internal visibility — views and managers inside the module only; no cross-module persistence.
- `hostTimestamp` uses `CACurrentMediaTime()` (monotonic) but is compared/persisted with wall-clock elsewhere (INFERRED mixing hazard in RPC timestamp math — RPC uses wall-clock `nowMs` and subtracts accurate time, which is fine).
- When paused, `getAccurateTime` freezes at last `currentTime` (correct); but `playbackRate` from JS may be 0 or stale for paused (INFERRED).
- Not Codable — snapshot not persisted; re-derivation relies on UserDefaults keys (`YTM_last*`) instead.

---

# FILE ENTRY 11 — `Sources/Mooziac/Models/PlaybackEngineMode.swift` (6 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlaybackEngineMode.swift`
- **Purpose**: Which playback engine is active: web (online) or native local file player (offline).
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `PlaybackEngineMode`.
- **Codable**: `String` raw + `Codable`.

## Enum: `PlaybackEngineMode` (line 3) — `public enum: String, Codable`
| Case | Raw | Line |
| :--- | :--- | :--- |
| `online` | `"online"` | 4 |
| `offline` | `"offline"` | 5 |

- Consumers: `PlaybackState.engineMode`, `NowPlayingManager`, `PlayerControls.swift` (engine-mode branching), `ObserverBridge.swift:383`.

### Risks
- No display name / helper — callers switch on raw cases directly.
- Codable raw strings are the persistence contract if ever stored (not currently persisted).

---

# FILE ENTRY 12 — `Sources/Mooziac/Models/RepeatMode.swift` (13 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/RepeatMode.swift`
- **Purpose**: Repeat mode with display strings. **Only Off and One exist — there is NO "Repeat All" case.**
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `RepeatMode`.
- **Codable**: `Int` raw + `Codable`.

## Enum: `RepeatMode` (line 3) — `public enum: Int, Codable`
| Case | Raw | Line |
| :--- | :--- | :--- |
| `off` | `0` | 4 |
| `one` | `1` | 5 |

### Computed property
- **`displayName: String`** (line 7): `off` → `"Repeat: Off"`; `one` → `"Repeat: Song"`.

### Risks
- No repeat-all mode; YTMusic's repeat-all state must map to `.off` or be handled elsewhere (INFERRED — see `PlaybackState.isRepeatOn` which is a separate Bool).
- Raw Int is a persistence contract; changing raw values breaks stored state.

---

# FILE ENTRY 13 — `Sources/Mooziac/Models/PlayerDesign.swift` (24 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlayerDesign.swift`
- **Purpose**: Player visual design theme (enum) persisted in UserDefaults; posts a notification on change.
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `PlayerDesign`.
- **Codable**: `String` raw, `CaseIterable`, but **not Codable**.
- **Defaults key**: `YTM_playerDesign` (lines 15, 20).
- **Notification name**: `NSNotification.Name("YTM_playerDesignChanged")` (line 21).
- **Files it communicates with**: UI reads `PlayerDesign.current`; observers of `YTM_playerDesignChanged`.

## Enum: `PlayerDesign` (line 3) — `public enum: String, CaseIterable`
| Case | Raw | Line | Display intent |
| :--- | :--- | :--- | :--- |
| `adaptive` | `"Adaptive (Ambient Dark)"` | 4 | default |
| `darkMode` | `"OLED Dark Mode"` | 5 | |
| `glassMode` | `"Pure Crystal Glass Mode"` | 6 | |
| `native` | `"Native (Glass & Ambient)"` | 7 | legacy name |

### Computed properties
- **`isGlass: Bool`** (line 9): `self == .glassMode`.
- **`current: PlayerDesign`** (line 13, static var)
  - Getter: `UserDefaults.string(forKey: "YTM_playerDesign") ?? PlayerDesign.adaptive.rawValue`; if value == `.native.rawValue` OR the legacy string `"Adaptive (Glass & Ambient)"` → return `.adaptive` (migration, line 16); else `PlayerDesign(rawValue: saved) ?? .adaptive`.
  - Setter: writes `rawValue` to `YTM_playerDesign`; posts `NSNotification.Name("YTM_playerDesignChanged")` (lines 19–22).

### Risks
- Migration maps `.native` → `.adaptive`, silently discarding the "native" design option.
- Legacy string `"Adaptive (Glass & Ambient)"` is a magic migration value.
- Not Codable; only raw-value persisted.

---

# FILE ENTRY 14 — `Sources/Mooziac/Models/ProgressStyle.swift` (32 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/ProgressStyle.swift`
- **Purpose**: Progress-bar visual style (enum) persisted in UserDefaults; posts a notification on change.
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `ProgressStyle`.
- **Codable**: `String` raw + `CaseIterable` + `Codable`.
- **Defaults keys**: `YTM_progressStyle` (lines 20, 27), `YTM_v3_useWaveformProgress` (line 28, legacy flag mirrored to `style == .waveform`).
- **Notification name**: `NSNotification.Name("ProgressStyleDidChange")` (line 29).
- **Files it communicates with**: player UI (waveform/glow/dots/line renderers), observers of `ProgressStyleDidChange`.

## Enum: `ProgressStyle` (line 3) — `public enum: String, CaseIterable, Codable`
| Case | Raw | Line | Display intent |
| :--- | :--- | :--- | :--- |
| `waveform` | `"waveform"` | 4 | Dynamic Equalizer Waveform (32 bars — comment) |
| `neonGlow` | `"neonGlow"` | 5 | Neon Liquid Capsule with glowing head |
| `cyberDots` | `"cyberDots"` | 6 | Pulsing LED Dot Matrix |
| `minimalLine` | `"minimalLine"` | 7 | Sleek Precision Line |

### Computed properties
- **`displayName: String`** (line 9): `"Dynamic Equalizer Waveform"`, `"Neon Liquid Capsule"`, `"Pulsing Cyber Dots"`, `"Minimal Precision Line"`.
- **`current: ProgressStyle`** (line 18, static var)
  - Getter: `UserDefaults.string(forKey: "YTM_progressStyle")` → `ProgressStyle(rawValue:)` else default `.waveform`.
  - Setter: writes `YTM_progressStyle`; writes `YTM_v3_useWaveformProgress = (newValue == .waveform)`; posts `NSNotification.Name("ProgressStyleDidChange")`.

### Risks
- Two sources of truth (`YTM_progressStyle` and legacy `YTM_v3_useWaveformProgress`) must be kept in sync; other writers of the legacy key could desync.
- Default `.waveform` when key unset.

---

# FILE ENTRY 15 — `Sources/Mooziac/Models/GestureMappingModels.swift` (52 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/GestureMappingModels.swift`
- **Purpose**: Trackpad gesture trigger definitions and the actions they can be mapped to.
- **Subsystem**: Models (used by `Input/` trackpad handling).
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `GestureType`, `GestureAction`.
- **Codable**: both `String` raw, `CaseIterable`, `Codable`.

## Enum: `GestureType` (line 4) — `public enum: String, CaseIterable, Codable`
| Case | Raw | Line | displayName |
| :--- | :--- | :--- | :--- |
| `bottomRightDoubleTap` | `"bottomRightDoubleTap"` | 5 | `"Bottom-Right 2 Taps"` |
| `bottomRightTripleTap` | `"bottomRightTripleTap"` | 6 | `"Bottom-Right 3 Taps"` |
| `bottomLeftDoubleTap` | `"bottomLeftDoubleTap"` | 7 | `"Bottom-Left 2 Taps"` |
| `bottomLeftTripleTap` | `"bottomLeftTripleTap"` | 8 | `"Bottom-Left 3 Taps"` |

### Computed property
- **`defaultAction: GestureAction`** (line 19): BR 2-tap → `.nextTrack`; BR 3-tap → `.previousTrack`; BL 2-tap → `.togglePlayPause`; BL 3-tap → `.toggleLyrics`.

## Enum: `GestureAction` (line 30) — `public enum: String, CaseIterable, Codable`
| Case | Raw | Line | displayName |
| :--- | :--- | :--- | :--- |
| `nextTrack` | `"nextTrack"` | 31 | `"Next Track"` |
| `previousTrack` | `"previousTrack"` | 32 | `"Previous Track"` |
| `togglePlayPause` | `"togglePlayPause"` | 33 | `"Play / Pause"` |
| `toggleLyrics` | `"toggleLyrics"` | 34 | `"Toggle Centered Lyrics"` |
| `volumeUp` | `"volumeUp"` | 35 | `"Volume Up"` |
| `volumeDown` | `"volumeDown"` | 36 | `"Volume Down"` |
| `toggleMute` | `"toggleMute"` | 37 | `"Toggle Mute"` |
| `togglePlayer` | `"togglePlayer"` | 38 | `"Toggle Player Panel"` |

### Risks
- `GestureType`/`GestureAction` raw strings are the persistence contract if mappings stored (not confirmed in source read).
- Only 4 trigger types, 8 actions; new gestures require enum expansion.

---

# FILE ENTRY 16 — `Sources/Mooziac/Models/LikedSongRecord.swift` (33 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/LikedSongRecord.swift`
- **Purpose**: Data model for one liked song (account and signed-out mirror) as stored in SQLite.
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `LikedSongRecord` (struct).
- **Codable**: none — mapping to/from SQLite done manually in `LocalDatabaseManager`.
- **Files it communicates with**: `Managers/LikedSongsManager.swift` (constructs records), `Managers/LocalDatabaseManager.swift` (persists; `addLikedSong`, `removeLikedSong`, `fetchLikedSongs`, `fetchUnsyncedLikedSongs`, `setLikedSongSynced`), `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift:1444` (remove), `Views/Libraries/PlaylistLibraryView.swift`.

## Struct: `LikedSongRecord` (line 3) — `public struct`

### Fields
| Field | Type | Access | Line | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `videoId` | `String` | `public var` | 4 | unique DB key |
| `title` | `String` | `public var` | 5 | |
| `artist` | `String` | `public var` | 6 | |
| `album` | `String` | `public var` | 7 | |
| `artworkUrl` | `String` | `public var` | 8 | |
| `duration` | `Double` | `public var` | 9 | |
| `dateLiked` | `Double` | `public var` | 10 | epoch seconds |
| `synced` | `Bool` | `public var` | 11 | local→account sync flag |
| `sourceType` | `String` | `public var` | 12 | `"ytm"` (default) or `"local"` |

### Init (line 14)
`public init(videoId:, title:, artist: String = "", album: String = "", artworkUrl: String = "", duration: Double = 0, dateLiked: Double = Date().timeIntervalSince1970, synced: Bool = false, sourceType: String = "ytm")`.

### Risks
- No `Equatable`/`Hashable`/`Codable`.
- `videoId` doubles as DB primary key; for local tracks it's `ytVideoId ?? filePath` — could be a very long path string.
- DB upsert (`LocalDatabaseManager.swift:641-647`) updates `title/artist/album/artwork_url/duration/synced` but **not** `date_liked` or `source_type` on conflict — re-liking an old song keeps the original date.

---

# FILE ENTRY 17 — `Sources/Mooziac/Models/LaunchAnimationTimeline.swift` (27 lines)

## Overview
- **File path**: `/Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/LaunchAnimationTimeline.swift`
- **Purpose**: Timeline configuration for the HaptiTrack-style intro animation.
- **Subsystem**: Models.
- **Imports**: `import Foundation` (1).
- **Classes/structs/enums defined**: `LaunchAnimationTimeline` (struct, internal, `Equatable`).
- **Codable**: none.
- **Files it communicates with**: launcher/intro animation code (consumer not present in the read set; INFERRED to be in `App/` or `Views/Windows/`).

## Struct: `LaunchAnimationTimeline` (line 4) — `struct: Equatable`

### Fields (all `var`, internal)
| Field | Type | Line | Default |
| :--- | :--- | :--- | :--- |
| `fadeIn` | `TimeInterval` | 5 | `0.45` |
| `pulseCount` | `Int` | 6 | `2` |
| `firstPulse` | `TimeInterval` | 7 | `0.35` |
| `pulseInterval` | `TimeInterval` | 8 | `0.55` |
| `pulseRise` | `TimeInterval` | 9 | `0.25` |
| `pulseFall` | `TimeInterval` | 10 | `0.35` |
| `hold` | `TimeInterval` | 11 | `0.22` |
| `fadeOut` | `TimeInterval` | 12 | `0.55` |

### Computed/method
- **`pulseTime(_ index: Int) -> TimeInterval`** (line 14): `firstPulse + Double(index) * pulseInterval`.
- **`pulseTimes: [TimeInterval]`** (line 18): `(0..<max(pulseCount, 0)).map(pulseTime)`.
- **`fadeOutStart: TimeInterval`** (line 22): `(pulseTimes.last ?? fadeIn) + pulseRise + pulseFall + hold`.
- **`total: TimeInterval`** (line 26): `fadeOutStart + fadeOut`.

### Risks
- Internal visibility; magic timing numbers tuned empirically.
- `pulseTimes` guards `pulseCount < 0` via `max(0, ...)` (defensive).

---

# CROSS-CUTTING: Notification names, defaults keys, URLs, storage paths, magic numbers

## Notification names (all exact)
| Name | Defined at |
| :--- | :--- |
| `"Mooziac_historyUpdated"` | `HistoryManager.swift:7` |
| `"Mooziac_LikedSongsUpdated"` | `LikedSongsManager.swift:7` |
| `"Mooziac_SignInStatusChanged"` | `LikedSongsManager.swift:8` |
| `"NetworkMonitorStatusChanged"` | `NetworkMonitor.swift:8` |
| `"NetworkMonitorReconnected"` | `NetworkMonitor.swift:9` |
| `"YTM_playerDesignChanged"` | `PlayerDesign.swift:21` |
| `"ProgressStyleDidChange"` | `ProgressStyle.swift:29` |

## UserDefaults keys
| Key | Used by | Meaning |
| :--- | :--- | :--- |
| `YTM_discordRPC_enabled` | `DiscordRPCManager` | Bool, default `true` |
| `YTM_lastTitle` / `YTM_lastArtist` / `YTM_lastVideoId` / `YTM_lastArtwork` / `YTM_lastDuration` | `HistoryManager` seed | last-known track snapshot |
| `YTM_playerDesign` | `PlayerDesign` | design raw value |
| `YTM_progressStyle` | `ProgressStyle` | progress style raw value |
| `YTM_v3_useWaveformProgress` | `ProgressStyle` | legacy waveform flag |

## Remote URLs/APIs
| URL | Used by |
| :--- | :--- |
| `https://lrclib.net/api/get?artist_name=<q>&track_name=<q>` | `LyricsManager` (exact lookup) |
| `https://lrclib.net/api/search?q=<q>` | `LyricsManager` (2 search tiers + `fetchRawSyncedLRC`) |
| `https://api.lyrics.ovh/v1/<artist>/<title>` | `LyricsManager` (final fallback) |
| `https://music.youtube.com/search?q=<q>` | `HistoryManager` (playback fallback) |
| `https://music.youtube.com/watch?v=<videoId>` | `DiscordRPCManager` (RPC button) |

## Storage paths
| Path | Used by |
| :--- | :--- |
| `~/Library/Caches/Mooziac/Lyrics/` | Lyrics cache (`LyricsManager`) |
| `~/Library/Caches/Mooziac/Thumbnails/` | Artwork thumbnails (`AppArtworkHelper`) |
| `<tmp>/ytm_art_<UUID>.jpg` | Notification artwork temp (`TrackNotificationManager`) |
| `~/Library/Application Support/Mooziac/library.sqlite3` | SQLite (`LocalDatabaseManager`, referenced) |
| `~/Music/Mooziac` (musicFolderURL) | local library `.lrc` sidecar scan (`LyricsManager`) |
| `/tmp/discord-ipc-0…9`, `$TMPDIR/discord-ipc-*` | Discord IPC socket (`DiscordRPCManager`) |

## Key magic numbers/constants
- History cap: **1000** rows (`LocalDatabaseManager.swift:1134`).
- History fetch default limit: **200** (`HistoryManager.fetchHistory`).
- LRCLib duration tolerance: **12.0 s**; title similarity gate **0.6**; artist gate **0.4** / subset; asymmetric-artist title gate **0.8**; local-filename title gate **0.8**, artist gate **0.5**; score weights **0.65 / 0.35** (`LyricsManager`).
- Plain→LRC spacing: **4.0 s**; default word span **4.2 s**; min line duration **0.4 s**; highlight lead **0.35 s** (`SyncedLyricsParser`).
- Discord RPC: reconnect **4 s**; refresh every **3rd tick** (12 s); socket timeouts **2 s**; payload size cap **65536**; title truncation **128**; URL truncation **512** (`DiscordRPCManager`).
- Liked-songs sync pacing: **2.5 s** load wait, **1.0 s** post-click wait (`LikedSongsManager`).
- Artwork: memory cache **500** items / **50 MB**; thumbnail pixel = `targetSize * 2`; JPEG factor **0.85**; removal sizes **[64,128,256]** (`AppArtworkHelper`).

---

# RISKS & OBSERVATIONS (cross-file)

## Race conditions
- **R1. Lyrics cache-hit threading**: `fetchLyrics` short-circuit returns synchronously on caller thread while all other paths return async on main — inconsistent contract (LyricsManager:211-214).
- **R2. Lyrics stale responses**: `fetchRawSyncedLRC` has no request-ID guard; concurrent calls (multiple downloads) can apply out of order (LyricsManager:456+).
- **R3. History seeding race**: `fetchHistory` seeds DB with current track when empty; DB write is async, so repeated empty reads can seed duplicates before the first write lands (HistoryManager:86-113 + LocalDatabaseManager async writes).
- **R4. Artwork concurrent generation**: `ioQueue` is `.concurrent` — two threads may generate/write the same thumbnail key simultaneously (AppArtworkHelper:172, 268).
- **R5. Liked-sync vs toggle race**: `syncNext` recursion and user toggles are not mutually excluded; a toggle during sync can flip the DB row the sync just read (LikedSongsManager).
- **R6. Discord RPC queue stall**: handshake does a blocking `recv` (2 s) on the utility queue; `isConnected` uses `queue.sync` — if ever read from main during handshake, main can stall (DiscordRPCManager:130-225, 17-19).

## Dead code
- **D1.** `HistoryManager.pendingStartTime`, `pendingRecord`, `hasCommittedCurrentPending`, `commitTimer` — declared, never used (HistoryManager:10-13).
- **D2.** `LocalTrack.init(isLiked:)` parameter ignored (LocalTrack:37-62).
- **D3.** `NetworkMonitor.stopMonitoring()` — no caller found.
- **D4.** `DiscordRPCManager.deinit` — singleton never deallocated (effectively dead).
- **D5.** `LocalTrack` imports `AVFoundation` but never uses it.
- **D6.** `AppArtworkHelper` — task brief expected dominant-color extraction; **none exists in this file** (no color code anywhere).

## Missing error handling
- **E1.** All `URLSession` lyric fetches ignore HTTP status codes (non-200 with HTML body parses to nil → silent fallback).
- **E2.** SQLite writes in `recordHistoryItem`/`addLikedSong` check `sqlite3_prepare_v2 == SQLITE_OK` but ignore `sqlite3_step` results.
- **E3.** `saveToLocalLyricsCache` swallows write errors (`try?`).
- **E4.** Discord IPC: no handling of Discord not installed (retries forever every 4 s), no opcode `close` handling.
- **E5.** Like-sync failures are silent (item skipped, never marked synced).
- **E6.** `downsample`/`createThumbnail` return nil on failure → fallback artwork used silently.

## Leaks / retain cycles
- **L1.** Nested closure in `fetchRawSyncedLRC` (LyricsManager:487) references `self` strongly inside `[weak self]` outer closure (INFERRED temporary retention while request in flight).
- **L2.** `HistoryManager.commitTimer`/`pendingRecord` field set hints at an abandoned timer design (dead fields suggest prior leak, now inert).

## Fragile state / integration fragility
- **F1.** Liked-songs sync + sign-in detection depend on YouTube DOM/cookie internals (`ytmusic-like-button-renderer`, `#button-shape-like button`, `SAPISID`, `__Secure-3PAPISID`, `__Secure-1PAPISID`, `like-status` attribute) — breaks silently on YouTube layout changes.
- **F2.** Discord presence artwork uses the raw remote artwork URL as `large_image` — Discord asset keys normally must be pre-uploaded asset keys; remote URLs are generally NOT supported as `large_image` by Discord RPC (INFERRED: may show blank/mooziac). This likely does not work as intended.
- **F3.** Hard-coded absolute developer paths in `AppArtworkHelper` (lines 42–43).
- **F4.** History/local records store a local *file path* in `artworkUrl` (HistoryManager:70) — code treating it as a URL will fail.
- **F5.** `RepeatMode` has no repeat-all; YouTube repeat-all must be mapped elsewhere.
- **F6.** `.native` PlayerDesign maps to `.adaptive` — the "native" theme is unreachable via the enum.

## Privacy / security concerns
- **P1.** Cookie *names* for Google auth are enumerated (`SAPISID`, `__Secure-3PAPISID`, `__Secure-1PAPISID`) to infer sign-in — values are never read/transmitted, but this is a fingerprinting-style heuristic (moderate).
- **P2.** Discord RPC transmits title/artist/artwork-url/page URL of the currently playing song to Discord's IPC socket (local) — standard RPC behavior, but it is third-party data exposure of listening habits (user-facing, expected by the feature).
- **P3.** Lyrics cache and artwork cache persist track metadata + fetched lyrics on disk with no encryption.
- **P4.** `print` logs include track titles/artists and sign-in booleans (no secrets, but verbose debug logging in release builds is likely).
- **P5.** No sandbox entitlement analysis performed (out of scope; `read` only).

---

# SUMMARY COUNTS

- **Files documented**: 17
- **Classes/structs/enums defined** (top-level): 
  - Classes: `LyricsManager`, `SyncedLyricsParser`, `HistoryManager`, `LikedSongsManager`, `DiscordRPCManager`, `TrackNotificationManager`, `NetworkMonitor`, `AppArtworkHelper` (8)
  - Structs: `LRCWord`, `LRCLine`, `LocalTrack`, `PlaybackState`, `LikedSongRecord`, `LaunchAnimationTimeline` (6)
  - Enums: `RPCOpcode`, `NetworkMonitor.ConnectionType`, `PlaybackEngineMode`, `RepeatMode`, `PlayerDesign`, `ProgressStyle`, `GestureType`, `GestureAction` (8)
  - **Total: 22 types**
- **Functions/methods/callbacks documented**: approximately **60** (LyricsManager 12 + 2 static; SyncedLyricsParser 2 static + LRCLine init; HistoryManager 7; LikedSongsManager 10; DiscordRPCManager 12 + 1 enum; TrackNotificationManager 5 + 1 delegate; NetworkMonitor 4 + didSet; AppArtworkHelper 14; LocalTrack 1 init + 3 computed + ==; PlaybackState 1; PlayerDesign 1; ProgressStyle 1; GestureType 1; RepeatMode 1; LaunchAnimationTimeline 3) — exact ≈ 70 with computed properties and initializers.
- **Notification names**: 7 (`Mooziac_historyUpdated`, `Mooziac_LikedSongsUpdated`, `Mooziac_SignInStatusChanged`, `NetworkMonitorStatusChanged`, `NetworkMonitorReconnected`, `YTM_playerDesignChanged`, `ProgressStyleDidChange`)
- **URLs/APIs**: 5 URL patterns (LRCLib get, LRCLib search, Lyrics.ovh, YTMusic search, YTMusic watch) + 3 frameworks/APIs (Discord RPC unix socket, `NWPathMonitor`, `UNUserNotificationCenter`)
- **Storage paths**: 7 (Lyrics cache, Thumbnails cache, notification temp art, SQLite `library.sqlite3`, music folder `.lrc` scan, Discord IPC sockets, `NSTemporaryDirectory`)
- **Risks found**: 6 race conditions (R1–R6), 6 dead-code items (D1–D6), 6 error-handling gaps (E1–E6), 2 leak/retain items (L1–L2), 6 fragility items (F1–F6), 5 privacy/security items (P1–P5).