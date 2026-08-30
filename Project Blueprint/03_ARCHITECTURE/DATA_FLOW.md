# Data Flow

Traced flows of how information moves through Mooziac, derived directly from the source. Each flow is a **CONFIRMED FROM SOURCE** path unless marked otherwise.

## The canonical playback state flow

```
User action (UI)
   → delegate / manager call
   → NowPlayingManager (engine mode routing)
   → PlayerControls dispatch
   → engine (JS on YTM webview  OR  NativeAudioPlayer)
   → JS observer posts nowPlayingHandler message (online)
        OR  NativeAudioPlayer broadcastPlaybackState (offline)
   → ObserverBridge parses → PlaybackState
   → NowPlayingManager.currentState set
   → updateSystemNowPlayingInfo (MPNowPlayingInfoCenter)
   → notifyObservers → UI (player pill, lyrics HUD), Discord RPC
   → YTM_last* UserDefaults persisted (online, delta-gated)
```

## Flow 1 — Status item click → panel

1. `NSStatusItem.button` action → `statusItemClicked(_:)` (StatusItemManager.swift:293).
2. Right-click → `showContextMenu`; double-click → `showPanel`; else → `togglePanel` (:312).
3. `showPanel` (:320) → `positionPanel` → `positionCustomWindow` (:227) → places panel under the status button (or saved dragged spot) → `makeKeyAndOrderFront` → `NSApp.activate(ignoringOtherApps:)` → fade-in → `startEventMonitors()` (:375).
4. Outside click → local monitor `closePanel()` (:387) → fade-out → `orderOut` → `stopEventMonitors()`.

## Flow 2 — Play/pause

1. `MainViewController.dynamicIslandDidTapPlayPause()` (:396) → `NowPlayingManager.togglePlayPause()` (PlayerControls.swift:22).
2. Offline/offline-network → `NativeAudioPlayer.shared` `playLastOrFirstTrack()` / `togglePlayPause()`.
3. Else → `NativeAudioPlayer.shared.pause()` + `evaluateJS` toggle JS → webview `#movie_player` play/pause.
4. JS `play`/`pause` event → `updateNowPlaying(true)` → `postMessage("nowPlayingHandler", …)`.
5. `userContentController(didReceive:)` (ObserverBridge.swift:320) → rebuild `PlaybackState` → set `currentState` → persist `YTM_last*` → `updateSystemNowPlayingInfo` → `notifyObservers`.
6. Observers: `DynamicIslandPlayerView.updateState(state)` (via MainViewController), `CenteredMenuBarLyricsWindowController`; `notifyObservers` also updates Discord presence on key change.

## Flow 3 — Search

1. Query trimmed; if offline engine or network down → `findBestLocalTrack` (fuzzy scoring) → `playOfflineTrack` → native playback.
2. Else → `switchToOnlineMode` → load `https://music.youtube.com/search?q=<encoded>`.
3. `autoPlayJS` injected at 0.4/0.8/1.3/1.8/2.5 s; polls `findAndPlayTopTrack` every 250 ms (≤30 attempts); clicks top result → track plays → JS posts state → UI updates.

## Flow 4 — Next/Previous

1. `dynamicIslandDidTapNext()` → `NowPlayingManager.nextTrack()` (PlayerControls.swift:128).
2. If `PlaylistManager.hasActiveContext` → `playNextTrackInPlaylist()`.
3. If offline/no network → native next.
4. Else JS: priority next-button click → next queue item click → `player.nextVideo()`. (Previous mirrors.)

## Flow 5 — Track end

- Online JS `ended`: if `window.ytmRepeatMode === 1` → seek 0 + play (JS-side). Else post `{event:"videoEnded", videoId}`.
- Native: `repeatMode == .one` → `seek(0)+play`; else if `PlaylistManager.hasActiveContext` → `playNextTrackInPlaylist()`.

## Flow 6 — Scroll wheel on status icon = volume

Local scrollWheel monitor: `|deltaY| > 0.1` → `NowPlayingManager.adjustVolume(deltaPercent: ±4)` (PlayerControls.swift:577) → JS `video.volume` clamp; event consumed.

## Flow 7 — Panel drag → floating player + persistence

1. `NSWindow.didMoveNotification` → `panelDidMove` (:159).
2. Guards (player mode, ≤360×120, mouse pressed).
3. `isDragged` if > 25 pt from docked anchor → flip `isDraggedFromDock`, show reset button, `panel.level = .floating`.
4. 0.12 s debounce → clamp frame → persist `YTM_isDraggedFromDock`, `YTM_playerFrameX/Y`, `YTM_playerTopY`, `YTM_savedDisplayID`.
5. Reset via `dockBackToMenuBar` (:304) or `onResetPosition` (:114).

## Flow 8 — Display change → reposition

`didChangeScreenParametersNotification` → `DisplayManager.handleDisplayParametersChange` → `onDisplayConfigurationChanged` → StatusItemManager repositions dragged/docked panel + lyrics overlay.

## Flow 9 — Like toggle

Offline: native `toggleLike` + `mirrorOfflineLike`. Online: record in `LikedSongsManager`; signed-in → JS click YTM like button (+250 ms `updateNowPlaying(true)`); else optimistic `currentState.isLiked` flip + direct observer fan-out (bypasses `notifyObservers`, so Discord presence is not updated on the optimistic path — see risks).

## Flow 10 — Keyboard command

keyDown while panel visible, not in text field/WebKit → `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)`; overlay via `CenteredMenuBarLyricsWindowController`.

## Offline playback flow (NativeAudioPlayer)

```
OfflineLibraryView / PlaylistLibraryView / PlaylistManager
  → LocalTrack + queue
  → NativeAudioPlayer.play(track:in:) 
  → AVPlayerItem(url:)
  → replaceCurrentItem
  → periodic time observer (0.25 s) → broadcastPlaybackState
  → NowPlayingManager.notifyObservers → UI/system/Discord
  → end-of-item (AVPlayerItemDidPlayToEndTime) → repeat-one / next / playlist advance
```

## Download flow (data path)

```
DownloadManager.queueTrack(s)
  → dedup against DB/library
  → QueueTask on serial workQueue
  → spawn yt-dlp (player_client=mweb,web_safari,tv_embedded,web)
  → stdout pipe → progress parser → Mooziac_DownloadProgress
  → ffmpeg remux → move into downloads folder
  → assignYTVideoID / register in DB → Mooziac_LibraryUpdated
```

## Lyrics flow (data path)

```
LyricsManager.fetchLyrics(track)
  → LRCLib /api/get → /api/search (2 tiers) → Lyrics.ovh fallback
  → similarity gates (title ≥0.6, artist ≥0.4/subset, etc.)
  → SyncedLyricsParser (LRC or plain→LRC synthesis)
  → cache to ~/Library/Caches/Mooziac/Lyrics/
  → time-driven line resolution (currentTime → active line)
  → CenteredMenuBarLyricsWindowController displays
```

## Related

- Event traces: `03_ARCHITECTURE/EVENT_FLOW.md`, `10_BACKGROUND_SYSTEMS/`.
- Diagrams: `14_DIAGRAMS/DATA_FLOW.md`.
- Workflows: `13_WORKFLOWS/`.