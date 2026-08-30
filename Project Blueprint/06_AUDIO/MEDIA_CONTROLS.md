# Media Controls

Every way a user can control playback, and how each is handled.

## 1. Player UI buttons (Dynamic Island)

| Button | Selector/handler | Route |
| :--- | :--- | :--- |
| Play/Pause | `playPauseTapped` | delegate → `NowPlayingManager.togglePlayPause()` |
| Next | `nextTapped` | delegate → `NowPlayingManager.nextTrack()` |
| Previous | `previousTapped` | delegate → `NowPlayingManager.previousTrack()` |
| Like | `likeTapped` | `NowPlayingManager.toggleLike()` |
| Repeat | `repeatTapped` | `NowPlayingManager.setRepeatMode` / `toggleRepeat` |
| Shuffle | (selector declared, not wired) | — |
| Seek | `InteractiveWaveformProgressView.onSeek` | `NowPlayingManager.seek(to:)` |
| Download | `downloadCurrentTrackTapped` | `DownloadManager.queueTrack`/`cancelTask` |
| Volume | scroll on status icon | `NowPlayingManager.adjustVolume(±4)` |

## 2. `PlayerControls` command surface (routed by engine mode)

| Command | Online (JS) | Offline (NativeAudioPlayer) |
| :--- | :--- | :--- |
| togglePlayPause (:22) | pause native + toggle `#movie_player` | playLastOrFirst/toggle |
| pause (:72) / play (:95) | JS video pause/play | native pause/play |
| nextTrack (:128) | priority: playlist context → next-button click → next queue item → `player.nextVideo()` | playlist context → native next |
| previousTrack (:218) | mirrored | mirrored |
| seek (:443) | JS `seekTo` | `seek(to:)` |
| fastForward/rewind (398/421) | JS | ±10 s |
| setRepeatMode (:308) | JS `window.ytmRepeatMode` + UI | native repeat |
| setShuffleState (:363) | JS `window.ytmShuffleActive` | native shuffle |
| toggleLike (:464) | LikedSongsManager + JS click or optimistic flip | native toggleLike + mirror |
| setEQPreset (:519) | WebAudio graph (per-page, ephemeral) | n/a |
| adjustVolume (:577) | JS `video.volume` clamp | native volume |

## 3. Menu bar & trackpad

| Input | Path |
| :--- | :--- |
| Scroll wheel on status icon | local monitor → `adjustVolume(±4%)` |
| Left-click status icon | toggle panel |
| Right-click status icon | context menu |
| Drag status panel | float mode |
| Trackpad right-edge swipe | `EdgeVolumeEngine` → `AppVolumeManager` → system volume (+ haptic + overlay) |
| Bottom-right 2 taps | next track |
| Bottom-right 3 taps | previous track |
| Bottom-left 2 taps | play/pause |

## 4. Keyboard (global + local)

`GlobalHotKeyManager` (global `NSEvent` monitors):
- `Ctrl+Option+Space` and/or `Cmd+Shift+Space` — toggle player panel.
- Left/Right arrows — previous/next.
- `L` (keycode 37, US layout) — like.

`KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)` (local, when panel focused, not in text field):
- Space — play/pause; Enter — play/pause (mirror); arrows; Escape — close/collapse.
- Shows overlay via `CenteredMenuBarLyricsWindowController`.

> ⚠ **Media keys (`MPRemoteCommandCenter`)**: No handlers are registered anywhere in the module. Physical keyboard media keys and the Touch Bar / Control Center playback widget are NOT wired (`UNKNOWN — requires runtime verification` — only `MPNowPlayingInfoCenter` is written).

## 5. Session restore (indirect control)

On launch, `YTMWebView` restores `YTM_lastUrl`/`YTM_lastTime` via `cueVideoById` (paused, not auto-played). No media command needed.

## Related

- `06_AUDIO/PLAYBACK_PIPELINE.md`, `10_BACKGROUND_SYSTEMS/SYSTEM_INTEGRATIONS.md`, raw notes 01/02.