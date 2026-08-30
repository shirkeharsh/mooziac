# Now Playing

How "now playing" state is defined, propagated, and presented to the system.

## Canonical state

`PlaybackState` (Models/PlaybackState.swift, 28 lines):
- `title`, `artist`, `album`, `artworkUrl` (+ optional `artwork: NSImage`)
- `duration`, `currentTime`, `isPlaying`, `playbackRate`
- `isLiked`, `pageUrl`, `videoId`, `trackID`
- `volume`, `repeatMode`, `isShuffle`

Owned by `NowPlayingManager.currentState`. Rebuilt on every `nowPlayingHandler` message (online) or `broadcastPlaybackState` (offline).

## Producers

| Producer | When | Path |
| :--- | :--- | :--- |
| `ObserverBridge` (online) | JS play/pause/seek/track-change/like messages | message → state dict → `currentState` |
| `NativeAudioPlayer.broadcastPlaybackState` (offline) | every 0.25 s time tick + play/pause/next/prev/seek/like | direct → `currentState` |
| Optimistic like flip (online, unsigned) | `PlayerControls.toggleLike` | direct mutation + manual fan-out (bypasses `notifyObservers`) |

## Consumers

| Consumer | Uses | Mechanism |
| :--- | :--- | :--- |
| `DynamicIslandPlayerView.updateState(state)` | labels, icons, waveform, artwork, repeat/like | observer (via MainViewController) |
| `CenteredMenuBarLyricsWindowController` | lyrics line + status | observer + 0.1 s timer |
| `DiscordRPCManager` | presence title/artist/artwork/page-url | `notifyObservers` on key change |
| `HistoryManager` | history seeding | `trackDidStartOffline` / last-track defaults |
| `LyricsManager` | current line resolution | reads `currentTime` |
| `TrackNotificationManager` | banners | track change |

## System Now Playing (`MPNowPlayingInfoCenter`)

`updateSystemNowPlayingInfo()` writes:
- title, artist, album, elapsed (`MPNowPlayingInfoPropertyElapsedPlaybackTime`), duration, rate.

**Not written:** `MPMediaItemPropertyArtwork` (offline player sets its own `MPMediaItemArtwork` in NativeAudioPlayer).
**Not registered:** any `MPRemoteCommandCenter` handlers in the codebase — media-key handling appears to be **absent** (`UNKNOWN — requires runtime verification`; see risks).

## Session persistence

| Key | Written (online) | Restored by |
| :--- | :--- | :--- |
| `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork` | ObserverBridge:411–413 | player pill restore, history seed |
| `YTM_lastVideoId` | ObserverBridge:420 | YTMWebView restore, playlist playback |
| `YTM_lastUrl` | ObserverBridge:421/424 | YTMWebView restore |
| `YTM_lastTime` | ObserverBridge:430/437 (delta ≥5 s gate) | YTMWebView `cueVideoById` |
| `YTM_lastDuration` | — | history |

`flushSessionState(keepCookies:)` removes the last-* keys (except `YTM_lastArtwork` — asymmetric) and resets `window.ytmObserverInjected`.

## Like status

- Online: `isLiked` from JS (DOM attribute) or optimistic flip; `YTM_lastIsLiked` written (deleted every launch by `NowPlayingManager.init`).
- Offline: `LocalTrack.isLiked` ↔ `LocalDatabaseManager` liked_songs + `LocalLibraryManager.toggleLike`.

## Related

- `06_AUDIO/MEDIA_CONTROLS.md`, `08_DATA/STATE_MANAGEMENT.md`, raw note `01_CORE_LAYER.md`.