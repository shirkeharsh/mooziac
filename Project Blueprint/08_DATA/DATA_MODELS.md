# Data Models

All core data structures. Verified from source.

## PlaybackState (`Models/PlaybackState.swift`)

```swift
struct PlaybackState {
    var title: String
    var artist: String
    var album: String
    var artworkUrl: String
    var artwork: NSImage?          // loaded lazily
    var duration: Double
    var currentTime: Double
    var isPlaying: Bool
    var playbackRate: Double
    var isLiked: Bool
    var pageUrl: String
    var videoId: String
    var trackID: String
    var volume: Double
    var repeatMode: RepeatMode
    var isShuffle: Bool
}
```

## LocalTrack (`Models/LocalTrack.swift`)

```swift
public struct LocalTrack: Identifiable, Equatable {
    let id: String                  // derived from file path
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var fileURL: URL
    var artwork: NSImage?           // embedded/derived
    var lrcURL: URL?
    var isLiked: Bool               // setter guards redundant LDM writes
    var dateAdded: Date
    var ytVideoId: String?
}
```
⚠ `init(isLiked:)` parameter ignored (risk D2).

## Enums

| Enum | Values | Notes |
| :--- | :--- | :--- |
| `RepeatMode` (Int, Codable) | `.off = 0`, `.all = 1`, `.one = 2` | no repeat-all handling in native end logic beyond advance |
| `PlaybackEngineMode` (String, Codable) | `.online`, `.offline` | engine routing |
| `PlayerDesign` (String, CaseIterable) | `.adaptive`, `.darkMode`, `.glassMode`, `.native` | `.native` maps to `.adaptive` (unreachable) |
| `ProgressStyle` (String, CaseIterable, Codable) | waveform / capsule / minimal | posts `ProgressStyleDidChange` |
| `GestureType`, `GestureAction` | tap patterns & mapped actions | gesture mapping |
| `LikedSongRecord` | id, title, artist, album, artworkUrl, duration, dateLiked, synced, sourceType | liked rows |

## Record structs (`Managers/LocalDatabaseManager.swift`)

| Struct | Fields |
| :--- | :--- |
| `CachedTrackRecord` | id, filePath, title, artist, album, duration, dateAdded, dateModified, fileSize, isLiked, lrcPath, ytVideoId |
| `PlaylistRecord` | id, name, createdAt, updatedAt |
| `PlaylistItemRecord` | id, playlistId, sortOrder, refType, refId, ytVideoId, title, artist, artworkUrl, duration, isLiked, dateAdded |
| `HistoryRecord` | id, title, artist, album, artworkUrl, ytVideoId, filePath, playedAt, duration, sourceType |

## Supporting structs (Managers)

| Struct | Defined in | Purpose |
| :--- | :--- | :--- |
| `PlaylistLibraryIndex` | PlaylistManager | playlist listing |
| `DownloadStatus` / `DownloadProgressInfo` | DownloadManager | download state + progress |
| `QueueItemInfo` / `AutomixItemInfo` / `UpNextSnapshot` | Queue.swift | online queue DTOs |
| `LRCWord` / `LRCLine` | SyncedLyricsParser | parsed lyrics |
| `LaunchAnimationTimeline` | Models | launch anim (largely unused) |
| `ActivePlaylistPlaybackContext` / `PlaylistPlayResult` / `PlaylistDownloadPlan` | PlaylistManager | playback contexts |

## Model consumers

| Model | Consumers |
| :--- | :--- |
| `PlaybackState` | Every view, DiscordRPC, LyricsManager, HistoryManager, TrackNotificationManager |
| `LocalTrack` | NativeAudioPlayer, LocalLibraryManager, PlaylistManager, DownloadManager, library views |
| Record structs | LocalDatabaseManager ↔ managers ↔ library views |

## Codable / persistence

- `PlaybackEngineMode`, `RepeatMode`, `ProgressStyle` are Codable (UserDefaults).
- `LocalTrack` is not persisted directly; persisted as `CachedTrackRecord` in SQLite.
- Session snapshot persisted as `YTM_last*` UserDefaults keys (not a model).