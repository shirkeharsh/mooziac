# Queue System

Two queue worlds exist: the **online queue** (YouTube Music's Up-Next, manipulated via JS) and the **offline queue** (`NativeAudioPlayer.currentQueue`). They are coordinated through `PlaylistManager`'s playback contexts.

## Online queue (`Queue.swift` extension on NowPlayingManager)

| Function | Line | Purpose |
| :--- | ---: | :--- |
| `fetchQueue(completion:)` | 6 | Reads active in-document `#queue`/`ytmusic-player-queue` containers; dedups dual `ytmusic-player-queue-item` nodes (visible + shadow template); filters detached DOM nodes (`document.body.contains`); returns `[QueueItemInfo]` |
| `fetchUpNextSnapshot(completion:)` | 197 | Snapshot of upcoming items (title/artist/artwork) for the player UI |
| `playAutomixItem(at:)` | 437 | Plays an automix/radio item via JS |
| `playQueueItem(at:)` | 474 | Plays a specific queue index via JS |
| `removeQueueItem(at:)` | 520 | Removes a queue item via JS |
| `playNextQueueItem(from:)` | 553 | Next up from current selection (uses `fromIndex` mostly for bounds; see risk) |
| `triggerAutoplayRadio()` | 565 | Clicks `ytmusic-player-bar .radio-button` if queue is empty so YTM auto-populates Up-Next |
| `moveQueueItem(from:to:)` | 589 | Drag-reorder: DOM `insertBefore` + Polymer `ytmusic-player-queue` data-model splice → persisted server-side by YTM |

DTOs: `QueueItemInfo`, `AutomixItemInfo`, `UpNextSnapshot` (see raw note 01).

### Queue dedup logic (from CHANGELOG + source)
- Prefers YouTube's Polymer data-model array (`q.queue.items`) when present.
- Adds DOM visibility filtering (`offsetParent !== null`) + `seenKeys` key dedup.
- Excludes the currently playing track from the upcoming list.

## Offline queue (`NativeAudioPlayer`)

- `currentQueue: [LocalTrack]`, `shuffledQueue: [LocalTrack]`, `currentIndex: Int`, `currentTrack: LocalTrack?`.
- `play(track:in:)` (line 32) — set queue + start.
- `playNext(track:)` (53) — insert at `currentIndex+1`.
- `appendToQueue(track:)` (71).
- `primeLastOrFirstTrack()` (136) / `playLastOrFirstTrack()` (158) — pick last-played or first.
- `nextTrack()` (264) / `previousTrack()` (283) — advance/back (prev restarts if >3 s).
- `setShuffleState(_:)` (326) — shuffles into `shuffledQueue`.
- `setRepeatMode(_:)` (321).

## Playlist playback contexts (`PlaylistManager`)

- `activeContext: ActivePlaylistPlaybackContext` — when playing a playlist, next/prev are routed to `playNextTrackInPlaylist`/`playPreviousTrackInPlaylist` regardless of engine (takes priority in `PlayerControls.nextTrack`).
- Playlists can contain both local tracks and online (video-ID) items; playback falls back appropriately (see `PlaylistPlayResult`).
- `playNextQueueItem(from:)` semantics risk documented in `15_ISSUES_AND_RISKS`.

## Data flow

```
Player UI / library view
  → fetchQueue / fetchUpNextSnapshot (JS evaluation, completion on main)
  → QueueItemInfo[] rendered in drawer Up-Next
  → moveQueueItem (drag) → DOM + data model persist
  → playQueueItem / playAutomixItem → JS click → nowPlayingHandler → state update

Offline:
  → OfflineLibraryView / PlaylistLibraryView select track in queue
  → NativeAudioPlayer.play(track:in:) → currentQueue/currentIndex
  → next/prev/ff/rw/seek via PlayerControls
```

## Related

- `06_AUDIO/PLAYBACK_PIPELINE.md`, raw note `01_CORE_LAYER.md` (Queue section).