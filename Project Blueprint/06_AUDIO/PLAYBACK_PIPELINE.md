# Playback Pipeline

End-to-end audio pipelines for both engines.

## Online pipeline (YouTube Music via WebKit)

```
User taps play (UI)
  → NowPlayingManager.togglePlayPause()  (PlayerControls.swift:22)
  → engineMode == .online (or network up)
  → NativeAudioPlayer.shared.pause()          // prevent dual audio
  → evaluateJS("toggle video/player click JS")
  → YouTube Music page plays in WebContent process
  → injected JS binds video events (play/pause/timeupdate/ended)
  → updateNowPlaying(true) builds 15-field dict
  → webkit.messageHandlers.nowPlayingHandler.postMessage(dict)
  → ObserverBridge.userContentController(didReceive:)     (ObserverBridge.swift:320)
  → PlaybackState rebuilt
  → NowPlayingManager.currentState set
  → updateSystemNowPlayingInfo()  → MPNowPlayingInfoCenter
  → notifyObservers() → UI pill, lyrics HUD, Discord presence
  → YTM_lastTitle/Artist/Artwork/VideoId/Url/Time persisted (time gated ≥5s)
```

### Startup restore (`YTMWebView`)
- On webview creation: reads `YTM_lastUrl` (must contain `watch?v=`), `YTM_lastTime`, `YTM_lastVideoId`.
- `restoreAndPlayJS` uses `cueVideoById(targetVideoId, targetTime)` (not `playVideo`) so startup never force-plays.
- `recoveryWatchdog` (20 s) + `webViewWebContentProcessDidTerminate` auto-recovery restores playback after WebContent crash.

## Offline pipeline (AVPlayer)

```
OfflineLibraryView / PlaylistLibraryView / PlaylistManager / LikedSongsManager / HistoryManager
  → select LocalTrack + queue
  → NativeAudioPlayer.play(track:in:)            (NativeAudioPlayer.swift)
      → engineMode = .offline
      → evaluateJS to pause web video (IIFE)
      → HistoryManager.trackDidStartOffline
      → AVPlayerItem(url: track.fileURL)
      → player.replaceCurrentItem(with:)
      → setupTimeObserver (0.25 s) → broadcastPlaybackState(currentTime:)
      → setupEndObserver (.AVPlayerItemDidPlayToEndTime)
  → repeatMode == .one  → seek(0)+play
  → PlaylistManager.hasActiveContext → playNextTrackInPlaylist()
  → else nextTrack() in queue / queue end behavior
```

### Seek / ff / rw (offline)
- `seek(to:)`, `fastForward(seconds:)`/`rewind(seconds:)` default step **10.0 s**.
- `previousTrack()` restarts if current time > **3.0 s**, else previous queue item.
- Timescale constant **600** for CMTime.

### Volume (offline)
- `setVolume(_:)` maps through `AppVolumeManager` (system or app-only mode) onto `AVPlayer.volume`.

## Engine switching

- `NowPlayingManager.switchToOnlineMode()` / offline paths set `engineMode` and post `"Mooziac_EngineModeChanged"` (posted but **no listeners** — inert; see risks).
- Offline network fallback: `NetworkMonitorStatusChanged` → if offline engine and network returns, prefers staying; searches route accordingly.

## End-of-track behavior

| Engine | repeat .off | repeat .one | repeat .all | playlist context |
| :--- | :--- | :--- | :--- | :--- |
| Online | JS `player.nextVideo()` / radio | JS seek-to-0+play (`window.ytmRepeatMode===1`) | via YTM UI state | — |
| Offline | advance or stop | `seek(0)+play` | advance wrapping (native) | `playNextTrackInPlaylist()` (has priority) |

## Related

- `13_WORKFLOWS/PLAYBACK_WORKFLOW.md`
- `14_DIAGRAMS/DATA_FLOW.md`
- Raw note `02_AUDIO_WEB_INPUT.md`