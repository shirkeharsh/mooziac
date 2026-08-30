# Mooziac Reverse-Engineering Blueprint — Work Package B: Audio · Web · Input

**Scope:** 11 source files under `Sources/Mooziac/` (Audio/, Web/, Input/, Support/).
**Method:** line-by-line read of the source. Only what is directly verified in source is stated as fact;
anything inferred is marked `INFERRED FROM SOURCE`; anything requiring runtime verification is marked
`UNKNOWN — requires runtime verification`.
**Constraints honored:** READ-ONLY. No source files were modified. Only this documentation file was written.

---

# Table of Contents

1. `Audio/NativeAudioPlayer.swift`
2. `Audio/EdgeVolumeEngine.swift`
3. `Audio/AppVolumeManager.swift`
4. `Audio/AudioRouteMonitor.swift`
5. `Audio/ClickSound.swift`
6. `Web/YTMWebView.swift`
7. `Web/URLFilter.swift`
8. `Input/GestureMappingManager.swift`
9. `Input/GlobalHotKeyManager.swift`
10. `Input/KeyboardCommandHandler.swift`
11. `Support/AppExtensions.swift`
12. External types referenced (models & managers used as dependencies)
13. RISKS & OBSERVATIONS

---

# 1. `Audio/NativeAudioPlayer.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Audio/NativeAudioPlayer.swift`
- **Purpose:** Native offline playback engine using AVFoundation `AVPlayer`. Owns the offline track queue,
  shuffle/repeat state, AVPlayer lifecycle, periodic time observation, end-of-item handling, seek/rate,
  and broadcasts playback state to `NowPlayingManager` (which fans out to UI, system Now Playing, MP command center).
- **Subsystem:** Audio (offline playback).
- **Depends on:** `AVFoundation`, `MediaPlayer`, `AppKit`, `Foundation`; `LocalTrack` (Models), `RepeatMode`
  (Models), `PlaybackState` (Models), `LocalLibraryManager.shared`, `HistoryManager.shared`,
  `NowPlayingManager.shared`, `AppVolumeManager.shared`.
- **Depended on by:** `NowPlayingManager` (play/pause/next/prev/queue, PlayerControls.swift,
  ObserverBridge.swift), `AppVolumeManager` (`setVolume`), UI views (`OfflineLibraryView`,
  `PlaylistLibraryView`, `DynamicIslandPlayerView/Core.swift`, `DynamicIslandPlayerView/SettingsPanel.swift`),
  `LyricsManager`.
- **Important imports:** `AppKit`, `Foundation`, `AVFoundation`, `MediaPlayer`.
- **Classes defined:** `NativeAudioPlayer`.
- **Functions defined:** `play(track:in:)`, `playNext(track:)`, `appendToQueue(track:)`,
  `handleTrackDeleted(trackID:)`, `primeLastOrFirstTrack()`, `playLastOrFirstTrack()`, `playCurrentTrack()`,
  `play()`, `pause()`, `togglePlayPause()`, `nextTrack()`, `previousTrack()`, `seek(to:)`,
  `fastForward(seconds:)`, `rewind(seconds:)`, `setRepeatMode(_:)`, `setShuffleState(_:)`, `setVolume(_:)`,
  `getCurrentTime()`, `getDuration()`, `setupTimeObserver()`, `setupEndObserver()`, `cleanupObservers()`,
  `toggleLike()`, `updateLikedState(isLiked:)`, `broadcastPlaybackState(currentTime:)`, `setupAudioSession()`.
- **Constants:** Time observer interval `CMTime(seconds: 0.25, preferredTimescale: 600)`; seek timescale `600`;
  `previousTrack` restart threshold `3.0 s`; default `fastForward`/`rewind` step `10.0 s`.
- **Properties/state:** `player`, `timeObserverToken`, `itemEndObserverToken`, `currentQueue`,
  `shuffledQueue`, `currentIndex`, `currentTrack`, `isPlaying`, `repeatMode`, `isShuffleActive`.
- **Events posted:** none directly. State is pushed through `NowPlayingManager.notifyObservers` /
  `updateSystemNowPlayingInfo`. Listens to `.AVPlayerItemDidPlayToEndTime`.
- **Side effects:** writes `Mooziac_LastPlayedLocalTrackId` / `Mooziac_LastPlayedLocalTrackTitle` defaults;
  removes those keys in `handleTrackDeleted`; sets `NowPlayingManager.shared.engineMode = .offline`;
  evaluates JS in the YTM web view to pause WebKit playback; calls `HistoryManager.trackDidStartOffline`;
  sets `MPNowPlayingInfoCenter` artwork.
- **External APIs / system frameworks:** `AVPlayer`, `AVPlayerItem`, `CMTime`, `MPNowPlayingInfoCenter`,
  `MPMediaItemArtwork`, `MPMediaItemPropertyArtwork`, `CACurrentMediaTime()` (QuartzCore), `UserDefaults`.
- **Files it communicates with:** `NowPlayingManager` (+ `PlayerControls.swift`, `ObserverBridge.swift`),
  `AppVolumeManager`, `LocalLibraryManager`, `HistoryManager`, `LocalTrack`, `RepeatMode`, `PlaybackState`.

## CLASS ENTRY — `NativeAudioPlayer`

- **Purpose:** single shared offline audio engine; manages the AVPlayer instance, track queue, playback
  controls, and state broadcast for the app's offline (local-file) mode.
- **Type:** `public final class NativeAudioPlayer: NSObject`.
- **Responsibilities:** track selection/queueing; shuffle + repeat(off/one); play/pause/next/previous/seek/
  ff/rw; deletion handling; volume mapping to AVPlayer; periodic time broadcast; like toggling; system Now
  Playing artwork.
- **init:** private override init (line 22). Prevents external instantiation (singleton via
  `static let shared`, line 7). Calls `setupAudioSession()` (which is an empty stub — see RISKS).
- **Properties:**
  - `static let shared: NativeAudioPlayer` (line 7)
  - `private var player: AVPlayer?` (line 9)
  - `private var timeObserverToken: Any?` (line 10)
  - `private var itemEndObserverToken: Any?` (line 11) — **declared but never assigned/read → dead property.**
  - `public private(set) var currentQueue: [LocalTrack]` (line 13)
  - `public private(set) var shuffledQueue: [LocalTrack]` (line 14)
  - `public private(set) var currentIndex: Int = -1` (line 15)
  - `public private(set) var currentTrack: LocalTrack?` (line 16)
  - `public private(set) var isPlaying: Bool = false` (line 17)
  - `public var repeatMode: RepeatMode = .off` (line 19)
  - `public var isShuffleActive: Bool = false` (line 20)
- **Public API:** `play(track:in:)`, `playNext`, `appendToQueue`, `handleTrackDeleted`, `primeLastOrFirstTrack`,
  `playLastOrFirstTrack`, `play`, `pause`, `togglePlayPause`, `nextTrack`, `previousTrack`, `seek`,
  `fastForward`, `rewind`, `setRepeatMode`, `setShuffleState`, `setVolume`, `getCurrentTime`, `getDuration`,
  `toggleLike`, `updateLikedState`, `broadcastPlaybackState`.
- **Dependencies:** `LocalLibraryManager.shared` (allTracks, toggleLike), `HistoryManager.shared`
  (`trackDidStartOffline`), `NowPlayingManager.shared` (engineMode, currentState, notifyObservers,
  updateSystemNowPlayingInfo, evaluateJS), `AppVolumeManager.shared` (isAppVolumeOnly, mediaVolume).
- **Consumers:** `NowPlayingManager` (`PlayerControls.swift`, `ObserverBridge.swift`), `AppVolumeManager`,
  offline/playlist library views, Dynamic Island player views, `LyricsManager`.
- **Lifecycle:** created lazily at first `shared` access; never torn down (app-lifetime singleton).
  AVPlayer items are replaced in-place via `replaceCurrentItem(with:)`.
- **State:** queue, shuffled queue, current index, current track, isPlaying, repeatMode, shuffle flag,
  AVPlayer reference, active time-observer token.
- **Events:** listens to `NotificationCenter` `.AVPlayerItemDidPlayToEndTime` (per item, re-registered on each
  `playCurrentTrack`). Emits state updates through `NowPlayingManager` observer callback list.
- **Relationships:** tightly coupled to `NowPlayingManager` (mutual); engine mode is forced to `.offline`
  whenever it plays, and `broadcastPlaybackState` no-ops unless engine mode is `.offline`.
- **What would break if removed:** all offline playback; `NowPlayingManager`'s offline branch; offline queue
  UI in `OfflineLibraryView`/`PlaylistLibraryView`; app-volume-only playback path (`AppVolumeManager`).

## FUNCTION ENTRIES — `NativeAudioPlayer`

### `setupAudioSession()` — private — ~line 27
- **Purpose:** placeholder for audio session setup on route changes. Body is empty (`// Ensure player responds
  cleanly to audio route changes`).
- **Called by:** `init()`.
- **Reads/writes:** none. **Side effects:** none.
- **Errors:** none. **Events:** none. **Async:** none.
- **Assessment:** stub — no actual AVAudioSession work (`INFERRED FROM SOURCE`; macOS does not use AVAudioSession
  the way iOS does, so this is likely intentional but functionally empty).

### `play(track:in:)` — public — ~line 32
- **Purpose:** start playing a track within an optional queue.
- **Inputs:** `track: LocalTrack`, `queue: [LocalTrack] = []`.
- **Logic:** if `queue` non-empty → set `currentQueue`, and `shuffledQueue = queue.shuffled()` if shuffle active;
  else if `currentQueue.isEmpty` → `currentQueue = [track]`. Active list = `shuffledQueue` or `currentQueue`.
  Set `currentIndex` to index of `track` in active list, else `0`. Set `currentTrack`, call `playCurrentTrack()`.
- **Called by:** `NowPlayingManager` (via `play(track:in:)` at NowPlayingManager.swift:33).
- **Calls:** `playCurrentTrack()`.
- **Writes:** `currentQueue`, `shuffledQueue`, `currentIndex`, `currentTrack`, `isPlaying`.
- **Side effects:** begins offline playback; persists last-played defaults; pauses WebKit video via JS.
- **Edge case:** if `track` is not found in active list (e.g. shuffle with a track not in shuffled list),
  index is forced to `0` while `currentTrack` is still the requested track — mismatch potential (`INFERRED`).

### `playNext(track:)` — public — ~line 53
- **Purpose:** insert a track immediately after the currently playing one and start it (does not persist to library).
- **Logic:** if queue empty → `play(track:)`. Else remove any existing instance of the track by `id`, insert at
  `max(0, min(count, currentIndex+1))` in `currentQueue`; mirror into `shuffledQueue` if shuffle active.
- **Called by:** `OfflineLibraryView` (:433), `PlaylistLibraryView` (:1442),
  `DynamicIslandPlayerView/SettingsPanel.swift` (:1842).
- **Side effects:** mutates both queues.
- **Note:** inserts into *both* queues but does not recompute shuffled order otherwise.

### `appendToQueue(track:)` — public — ~line 71
- **Purpose:** append track to the end of the queue.
- **Logic:** if queue empty → `play(track:)`. Else remove duplicates by `id`, append; mirror into `shuffledQueue`.
- **Called by:** `DynamicIslandPlayerView/SettingsPanel.swift` (:1848).

### `handleTrackDeleted(trackID:)` — public — ~line 84
- **Purpose:** react to a local track being deleted from the library.
- **Logic:** remove from both queues. If it was `currentTrack`: remember `wasPlaying`, pause, clear item, nil
  current track, remove last-played defaults (only if the stored last-played id matches), then either advance to
  `activeList[currentIndex]` (clamping index to 0 if out of range) and replay if was playing, else broadcast an
  empty paused state; or if the active list is empty, broadcast "Not Playing" / "No Track Selected" state and
  update system Now Playing. If it was NOT current: re-sync `currentIndex` to the current track's index.
- **Reads/writes:** defaults keys `Mooziac_LastPlayedLocalTrackId`, `Mooziac_LastPlayedLocalTrackTitle`.
- **Side effects:** may auto-start next track; writes `NowPlayingManager.currentState` directly and calls
  `notifyObservers` + `updateSystemNowPlayingInfo`.

### `primeLastOrFirstTrack()` — public — ~line 136
- **Purpose:** pre-load queue metadata without starting playback (offline "auto offline" entry).
- **Logic:** `tracks = LocalLibraryManager.shared.allTracks`; guard non-empty. Set queue (+ shuffled).
  Find last-played id in active list (default index 0). Set currentIndex/currentTrack, `isPlaying = false`.
  Broadcast only if `NowPlayingManager.shared.engineMode == .offline`.
- **Called by:** `NowPlayingManager` (NowPlayingManager.swift:60).

### `playLastOrFirstTrack()` — public — ~line 158
- **Purpose:** resume last-played (or first) local track and start playback.
- **Logic:** same as `primeLastOrFirstTrack` but always calls `playCurrentTrack()`. Logs
  `[NativeAudioPlayer] No offline tracks available in library` if library empty.

### `playCurrentTrack()` — private — ~line 178
- **Purpose:** core item-load-and-play routine.
- **Flow:**
  1. guard `currentTrack`.
  2. Persist `Mooziac_LastPlayedLocalTrackId` and `Mooziac_LastPlayedLocalTrackTitle`.
  3. `cleanupObservers()` (remove old time + end observers).
  4. `AVPlayerItem(url: track.fileURL)`; create `AVPlayer` on first use else `replaceCurrentItem`.
  5. Volume: `player?.volume = AppVolumeManager.shared.mediaVolume` if `isAppVolumeOnly` else `1.0`.
  6. `setupTimeObserver()` + `setupEndObserver()`.
  7. Set `NowPlayingManager.shared.engineMode = .offline`; inject JS to pause `document.querySelector('video')`
     and `#movie_player`/`.html5-video-player` `pauseVideo()`.
  8. `player?.play()`, `isPlaying = true`.
  9. `HistoryManager.shared.trackDidStartOffline(track)`.
  10. `broadcastPlaybackState(currentTime: 0.0)`.
- **Called by:** `play`, `primeLastOrFirstTrack` (via playLastOrFirstTrack), `nextTrack`, `previousTrack`,
  `handleTrackDeleted`.
- **Side effects:** engine mode flip to offline; JS pause of web player; history logging; defaults writes.
- **Note:** the JS pause string is duplicated verbatim in `play()` (see RISKS — duplicated logic).

### `play()` — public — ~line 227
- **Purpose:** resume/resume-or-start playback.
- **Logic:** if no `currentTrack` → `playLastOrFirstTrack()`. Else set engine mode offline, inject the same
  video-pause JS, `player?.play()`, `isPlaying = true`, broadcast with `getCurrentTime()`.
- **Called by:** `togglePlayPause`, `NowPlayingManager` (PlayerControls.swift:104), end-of-item repeat-one.

### `pause()` — public — ~line 248
- **Logic:** `player?.pause()`, `isPlaying = false`; broadcast only when engine mode `.offline`.
- **Called by:** `togglePlayPause`, `NowPlayingManager` (PlayerControls.swift:39,44,74,108),
  `ObserverBridge.swift` (:349), `handleTrackDeleted`.

### `togglePlayPause()` — public — ~line 256
- **Logic:** if `isPlaying` → `pause()` else `play()`.
- **Called by:** `GlobalHotKeyManager` (space), `NowPlayingManager` (PlayerControls.swift:31), UI buttons.

### `nextTrack()` — public — ~line 264
- **Logic:** active list; if `currentIndex+1 < count` → advance + `playCurrentTrack()`; else if `repeatMode == .one`
  → `seek(to:0)` + `play()`; else wrap to index 0 + `playCurrentTrack()`.
- **Called by:** `GlobalHotKeyManager` (124), `NowPlayingManager` (PlayerControls.swift:143), end-of-item observer.

### `previousTrack()` — public — ~line 283
- **Logic:** if `getCurrentTime() > 3.0` → `seek(to:0)` (restart). Else if `currentIndex > 0` → step back +
  `playCurrentTrack()`; else `seek(to:0)`.
- **Called by:** `GlobalHotKeyManager` (123), `NowPlayingManager` (PlayerControls), gesture manager.

### `seek(to:)` — public — ~line 302
- **Logic:** `CMTime(seconds: max(0, seconds), preferredTimescale: 600)`; `player.seek(to:toleranceBefore: .zero,
  toleranceAfter: .zero)`; completion re-broadcasts with the requested seconds.
- **Async:** completion closure on whatever queue AVFoundation uses.
- **Called by:** `fastForward`, `rewind`, `nextTrack` (repeat-one), `previousTrack`.

### `fastForward(seconds:)` — public — ~line 310
- **Logic:** `seek(to: min(duration, curr + seconds))`, default step `10.0`.

### `rewind(seconds:)` — public — ~line 316
- **Logic:** `seek(to: max(0.0, curr - seconds))`, default step `10.0`.

### `setRepeatMode(_:)` — public — ~line 321
- **Logic:** sets `repeatMode`, broadcasts current time.
- **Note:** only `.off` and `.one` exist in `RepeatMode` (Models). `.all` is not supported.

### `setShuffleState(_:)` — public — ~line 326
- **Logic:** on enable → `shuffledQueue = currentQueue.shuffled()`, resync index; on disable → resync index to
  `currentQueue`. Broadcasts.

### `setVolume(_:)` — public — ~line 341
- **Logic:** `player?.volume = max(0, min(1, volume))`.
- **Called by:** `AppVolumeManager.applyMediaVolume` / `resetPlayerVolumeToMax`.

### `getCurrentTime()` — public — ~line 345
- **Logic:** `CMTimeGetSeconds(player.currentTime())`, NaN/∞ → `0.0`.

### `getDuration()` — public — ~line 351
- **Logic:** prefers `currentTrack.duration` (>0), else `player?.currentItem.duration`, NaN/∞ → `0.0`.

### `setupTimeObserver()` — private — ~line 359
- **Purpose:** periodic state broadcast every `0.25 s` while playing.
- **Logic:** `player.addPeriodicTimeObserver(forInterval: 0.25s @600, queue: .main)`; guard `self.isPlaying`;
  broadcast sanitized seconds.
- **Side effects:** retains the token in `timeObserverToken`.
- **Called by:** `playCurrentTrack()`.

### `setupEndObserver()` — private — ~line 371
- **Logic:** removes any prior `.AVPlayerItemDidPlayToEndTime` observer, adds one for the *current* item
  (object: item): repeat-one → `seek(0)` + `play()`; else `nextTrack()`.
- **Called by:** `playCurrentTrack()`.
- **Note:** the token returned by `addObserver(forName:...)` is discarded; cleanup relies on removing by name+object
  (see RISKS).

### `cleanupObservers()` — private — ~line 385
- **Logic:** `removeTimeObserver(token)` if present; `NotificationCenter.removeObserver(self, name:
  .AVPlayerItemDidPlayToEndTime, object: nil)`.

### `toggleLike()` — public — ~line 393
- **Logic:** `LocalLibraryManager.shared.toggleLike(for: track.id)`.
- **Called by:** `NowPlayingManager.toggleLike` (PlayerControls.swift:464) and global hotkey 'L'.

### `updateLikedState(isLiked:)` — public — ~line 398
- **Logic:** mutates a copy of `currentTrack` (struct) setting `isLiked`, reassigns, broadcasts.

### `broadcastPlaybackState(currentTime:)` — public — ~line 407
- **Purpose:** push a full `PlaybackState` snapshot to `NowPlayingManager`.
- **Logic:** guard engine mode `.offline`; guard currentTrack. Builds `PlaybackState` from track fields
  (title/artist/album/artworkUrl/pageUrl=fileURL.absoluteString/videoId/trackID/id), `hostTimestamp =
  CACurrentMediaTime()`, `playbackRate = isPlaying ? 1.0 : 0.0`, isLiked, isShuffleOn, isRepeatOn, repeatMode.
  Sets `currentState`, calls `notifyObservers`, `updateSystemNowPlayingInfo`, and if `track.artwork` exists
  attaches `MPMediaItemArtwork` into `MPNowPlayingInfoCenter`.
- **Errors:** none handled (artwork insertion is fire-and-forget).
- **Called by:** everywhere in this file; gated by engine mode.
- **Side effects:** system Now Playing info, Discord presence (via notifyObservers), UI observers.

---

# 2. `Audio/EdgeVolumeEngine.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Audio/EdgeVolumeEngine.swift`
- **Purpose:** system-volume control plus trackpad-edge gestures. Uses a private/dylib **MultitouchSupport**
  framework hookup (`dlopen`/`dlsym`) to read raw contact frames from the trackpad, interprets edge touches as
  volume drags and bottom-corner tap sequences (2/3 taps), and writes system volume through CoreAudio
  (`AudioObjectSetPropertyData` on the default output device). Also defines the `VolumeController` CoreAudio
  volume read/write engine.
- **Subsystem:** Audio (system volume) + Input (trackpad multitouch).
- **Depends on:** `AppKit`, `CoreAudio`, `AudioToolbox`, `GestureMappingManager.shared`,
  `AppVolumeManager.shared`, `UserDefaults`.
- **Depended on by:** `AppVolumeManager` (uses `VolumeController.shared.getVolume/setVolume`),
  `AppDelegate` (calls `EdgeVolumeEngine.shared.start()`), `ContextMenu.swift` (toggles enable flags),
  `SettingsPanel.swift` (toggles), `GestureMappingManager` (toggleMute uses `VolumeController`).
- **Important imports:** `AppKit`, `CoreAudio`, `AudioToolbox`.
- **Classes defined:** `VolumeController`, `EdgeVolumeEngine`, `ActiveEngineBox` (private), plus a file-scoped
  C function pointer `globalMultitouchCallbackRelay`.
- **Functions defined (file scope):** `globalMultitouchCallbackRelay` (closure typed as `MTContactFrameCallback`).
- **Constants / magic numbers:** layout stride 96, identifier offset 16, state offset 20, normalisedX 32,
  normalisedY 36; touch `state` range `(2...5)`; right-edge boundary `distanceFromRightMm <= 2.5 || x >= 0.982`;
  top-30% `y >= 0.70`; bottom corners `y <= 0.15`; bottom-left `(distanceFromLeftMm <= 2.5 || x <= 0.005) && y <= 0.15`;
  tap move tolerance `0.05`; tap window `<= 0.35 s`; tap commit debounce `0.30 s`; volume drag threshold `3.0 mm`;
  full-range `160.0 mm` for 0–100%; per-frame delta clamp `±0.25`; global volume clamp `0...1`;
  reconnect timer `10.0 s` (tolerance `5.0 s`); restart delay `0.3 s`; default trackpad size `157.8 × 97.8 mm`;
  `vmvo` selector = `0x766d766f`; default last-known volume `0.3`.
- **Properties/state:** many (see class entries). Persisted defaults keys:
  `YTM_lastKnownSystemVolume`, `YTM_v3_isEdgeEngineEnabled`, `YTM_v3_isRightEdgeVolumeEnabled`,
  `YTM_v3_isRightCornerTapsEnabled`, `YTM_v3_isLeftCornerTapsEnabled`.
- **Events:** listens on `DistributedNotificationCenter` to `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`,
  and on `NSWorkspace.shared.notificationCenter` to `willSleepNotification` / `didWakeNotification`.
- **Side effects:** loads a private framework; registers raw C callbacks; writes system volume & unmute;
  plays no sounds itself.
- **External APIs / system frameworks:** `dlopen`/`dlsym`/`unsafeBitCast`; `MultitouchSupport.framework`
  (`/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`); symbols
  `MTDeviceCreateList`, `MTRegisterContactFrameCallback` (fallback `MTRegisterContactObserver`),
  `MTDeviceStart`, `MTDeviceStop`, `MTDeviceGetSensorSurfaceDimensions`; CoreAudio
  `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioDevicePropertyVolumeScalar`, `kAudioDevicePropertyMute`,
  `AudioObjectGetPropertyData`, `AudioObjectSetPropertyData`; `AudioServicesPlaySystemSound` is NOT used here.
- **Files it communicates with:** `AppVolumeManager`, `GestureMappingManager`, `AppDelegate`, `ContextMenu.swift`.

## CLASS ENTRY — `VolumeController`

- **Type:** `final class` (internal), singleton `static let shared`.
- **Purpose:** read/write the **system** output volume via CoreAudio with multi-fallback strategies
  ("Apple Silicon Multi-Channel Aligned").
- **Properties:** computed `lastKnownVolume: Float` (get from `YTM_lastKnownSystemVolume`, clamp 0…1, default `0.3`;
  set writes back to defaults).
- **init:** calls `_ = getVolume()` to prime the cache.
- **API:** `getVolume() -> Float`, `setVolume(_ volume: Float)` (both internal).
- **Logic — `getVolume()` (line 45):** resolve `defaultOutputDevice()`; then try, in order:
  1. `vmvo` (`0x766d766f`) on output scope, main element;
  2. `kAudioDevicePropertyVolumeScalar` output scope, main element;
  3. scalar on channel element `1` then `2`;
  4. `vmvo` on global scope.
  Each success clamps 0…1 and caches; final fallback returns cached `lastKnownVolume`.
- **Logic — `setVolume()` (line 101):** resolve device; clamp; cache; then fire-and-forget:
  1. `vmvo` output-scope write;
  2. scalar write on elements `0, 1, 2`;
  3. unmute: read `kAudioDevicePropertyMute` (main, output scope); if muted and `newVolume > 0`, write mute `0`.
- **Errors:** all CoreAudio status codes discarded with `_ =` (silent failures).
- **Consumers:** `AppVolumeManager.getEffectiveVolume/setEffectiveVolume`,
  `GestureMappingManager.executeAction(.toggleMute)`.
- **What would break if removed:** system-volume gesture support, mute toggle, system-volume path of
  `AppVolumeManager`.

## CLASS ENTRY — `EdgeVolumeEngine`

- **Type:** `final class` (internal), singleton `static let shared`.
- **Purpose:** interpret raw Multitouch contact frames into volume-drag and corner-tap gestures; own the
  device lifecycle (start/stop/restart, lock/sleep observers, auto-reconnect).
- **Persisted flags (computed props, all bools, default `false`):**
  - `isEnabled` (key `YTM_v3_isEdgeEngineEnabled`) — setter also copies value into the three sub-flags and calls
    `stop()` or `start()`.
  - `isRightEdgeVolumeEnabled` (`YTM_v3_isRightEdgeVolumeEnabled`)
  - `isRightCornerTapsEnabled` (`YTM_v3_isRightCornerTapsEnabled`)
  - `isLeftCornerTapsEnabled` (`YTM_v3_isLeftCornerTapsEnabled`)
- **Private state:** `frameworkHandle`, `devices: [UnsafeMutableRawPointer]`, `retainedCFDevices: [AnyObject]`,
  `pendingRestartWorkItem: DispatchWorkItem?`, `trackpadWidthMm = 157.8`, `trackpadHeightMm = 97.8`;
  volume-gesture state: `isSwiping`, `isVolumeDragActive`, `activeTouchID: Int32 = -1`, `startY`, `startVolume = 0.5`,
  `autoReconnectTimer: Timer?`; right-tap state: `rightTapCount`, `rightTapTimer`, `isPotentialRightTap`;
  left-tap state: `leftTapCount`, `leftTapTimer`, `isPotentialLeftTap`; shared `tapStartTime`, `tapStartY`;
  function pointers: `createListFunc`, `registerCallbackFunc`, `deviceStartFunc`, `deviceStopFunc`,
  `getDimensionsFunc`.
- **`Layout` enum (private):** `stride = 96`, `identifier = 16`, `state = 20`, `normalisedX = 32`,
  `normalisedY = 36` — hardcoded offsets into the raw contact-frame struct.
- **init (line 227):** `loadFramework()` + `setupLockWakeObservers()`.
- **Public/internal API:** `restart()`, `start()`, `stop()`, `fileprivate handleTouches(rawPtr:count:)`.
- **Consumers:** `AppDelegate` (start), `ContextMenu`/`SettingsPanel` (flag toggles), `AppVolumeManager`.
- **Threading:** the multitouch callback arrives on a **private/background C thread** (driven by the private
  framework); `handleTouches` is called directly on that thread (no hop to main). Tap-commit timers hop to
  main via `DispatchQueue.main.async` + `Timer.scheduledTimer` (run loop = main). Volume writes call
  `AppVolumeManager.setEffectiveVolume` which may dispatch overlays to main.
- **What would break if removed:** all edge-volume and corner-tap gestures.

## FUNCTION ENTRIES — `EdgeVolumeEngine` / related

### `VolumeController.defaultOutputDevice()` — private — ~line 25
- **Purpose:** fetch `kAudioHardwarePropertyDefaultOutputDevice` from `kAudioObjectSystemObject`.
- **Output:** `AudioObjectID` (or `kAudioObjectUnknown` on failure).

### `VolumeController.getVolume()` — ~line 45
- **Input:** none. **Output:** `Float` 0…1.
- **Calls:** `defaultOutputDevice`, caches `lastKnownVolume`.
- **Errors:** silent (`== noErr` checks only; else falls through).

### `VolumeController.setVolume(_:)` — ~line 101
- **Input:** `volume: Float`. **Output:** `Void`.
- **Calls:** `defaultOutputDevice`, `AudioObjectSetPropertyData` (vmvo + scalar ch 0/1/2), mute read+write.
- **Side effects:** system volume change, unmute, cache write.

### `EdgeVolumeEngine.loadFramework()` — private — ~line 232
- **Purpose:** `dlopen` the private framework and resolve all five symbols via `dlsym` + `unsafeBitCast`.
- **Note:** `MTRegisterContactObserver` is only used as a fallback if `MTRegisterContactFrameCallback` is absent;
  the callback typedef matches the frame-callback signature, so using `MTRegisterContactObserver` (different
  signature) would be ABI-mismatched (`INFERRED FROM SOURCE` — unsafe assumption, see RISKS).
- **Errors:** if `dlopen` fails, engine silently stays non-functional (`frameworkHandle == nil`, funcs nil).

### `EdgeVolumeEngine.setupLockWakeObservers()` — private — ~line 254
- **Purpose:** stop on lock/sleep, restart on unlock/wake; plus a 10 s auto-reconnect timer.
- **Events registered:**
  - DNC: `com.apple.screenIsLocked` → `stop()`; `com.apple.screenIsUnlocked` → `restart()`.
  - NSWorkspace: `.willSleepNotification` → `stop()`; `.didWakeNotification` → `restart()`.
  - `Timer(timeInterval: 10.0, repeats: true)` with `tolerance = 5.0`, added to `.main` run loop in `.common`
    mode; if `isEnabled && devices.isEmpty` → `start()`.
- **Note:** observer tokens from `addObserver(forName:...)` are not retained; the closure-based observers are
  never explicitly removed (object lifetime = app lifetime).

### `EdgeVolumeEngine.restart()` — ~line 282
- **Purpose:** debounced restart (cancels pending work item, stops, starts after `0.3 s` on main).

### `EdgeVolumeEngine.start()` — ~line 292
- **Purpose:** enumerate Multitouch devices, register callback, start device stream.
- **Flow:** `stop()`; guard `isEnabled`; guard funcs non-nil; `createList()` → `takeRetainedValue()` as
  `[AnyObject]`; store `retainedCFDevices`; `activeEngineBox.set(self)`; for each device: build opaque pointer,
  call `getDimensionsFunc` (if returned `0` and `h > 0`, convert mm: `Double(w)/100.0`), `registerCallback(ptr,
  globalMultitouchCallbackRelay)`, `deviceStart(ptr, 0)`.
- **Side effects:** registers C callback; holds device references to keep them alive.

### `EdgeVolumeEngine.stop()` — ~line 323
- **Flow:** cancel pending restart; `deviceStopFunc` for each device; clear arrays; reset `isSwiping`,
  `isVolumeDragActive`.

### `EdgeVolumeEngine.handleRightTapCompleted()` — private — ~line 337
- **Purpose:** debounce right-corner tap counting.
- **Logic:** async to main; invalidate old timer; schedule `0.30 s` one-shot; on fire: read+reset `rightTapCount`;
  `count == 2` → `GestureMappingManager.shared.executeAction(for: .bottomRightDoubleTap)`;
  `count >= 3` → `.bottomRightTripleTap`.
- **Called by:** `handleTouches` (end-of-frame path).

### `EdgeVolumeEngine.handleLeftTapCompleted()` — private — ~line 355
- **Purpose:** same debounce for left corner.
- **Logic:** `count == 2` → `.bottomLeftDoubleTap`; `count >= 3` → `.bottomLeftTripleTap`.

### `EdgeVolumeEngine.handleTouches(rawPtr:count:)` — fileprivate — ~line 373
- **Purpose:** the raw contact-frame interpreter. **Runs on the framework's callback thread.**
- **Guards:** `isEnabled`; at least one of the three sub-flags; else returns.
- **End-of-touch path (`count <= 0` or nil ptr):** if nothing in flight → return. Otherwise compute
  `duration = now - tapStartTime`; if `<= 0.35` increment the appropriate tap count and call the corresponding
  `handle...TapCompleted()`; clear flags; end swipe state.
- **Frame iteration:** for `i in 0..<count`: `base = i*96`; read `state` (offset 20) as Int32; skip unless
  `(2...5).contains(state)`; read `touchID` (offset 16), `x`, `y` (offsets 32/36 as Float).
- **Region math (normalized x/y, 0…1):**
  - `distanceFromRightMm = (1.0 - x) * trackpadWidthMm`
  - `isRightEdge = distanceFromRightMm <= 2.5 || x >= 0.982`
  - `isTopRight30Edge = isRightEdge && y >= 0.70`
  - `isBottomRightCorner = isRightEdge && y <= 0.15`
  - `distanceFromLeftMm = x * trackpadWidthMm`
  - `isBottomLeftCorner = (distanceFromLeftMm <= 2.5 || x <= 0.005) && y <= 0.15`
- **Corner-tap state machine:** when in a corner and not swiping and enabled: set `isPotentialXTap = true`,
  record `tapStartTime`/`tapStartY`; if y moved `> 0.05` since start, cancel potential tap.
- **Volume-drag state machine:**
  - Not swiping: if `isTopRight30Edge && isRightEdgeVolumeEnabled` → `isSwiping = true`, `activeTouchID = touchID`,
    `startY = y`, `startVolume = AppVolumeManager.shared.getEffectiveVolume()`, `isVolumeDragActive = false`,
    break.
  - Swiping: if `touchID == activeTouchID`: compute `dy`, `travelMm = dy * trackpadHeightMm`. Arm drag only when
    `abs(travelMm) >= 3.0`; on arming re-anchor `startY` and re-read `startVolume`. Once active:
    `activeTravelMm = (y - startY) * trackpadHeightMm`; `change = clamp(-0.25...0.25, activeTravelMm / 160.0)`;
    `newVol = clamp(0...1, startVolume + change)`; `AppVolumeManager.shared.setEffectiveVolume(newVol)`.
- **End of frame:** if swiping but the active touch is gone → reset `isSwiping`/`isVolumeDragActive`.
- **Side effects:** system volume writes, gesture-action execution, UI overlays (via AppVolumeManager).
- **Errors:** none handled — raw pointer reads are unvalidated (`loadUnaligned`); no bounds check on `count`
  beyond `count > 0` (see RISKS).
- **Async:** synchronous on the callback thread; only the tap-debounce timers hop to main.

### `ActiveEngineBox` — private class — ~line 498
- **Purpose:** thread-safe weak holder for the engine so the C callback can reach the singleton without a retain
  cycle.
- **State:** `NSLock`, `weak var engine: EdgeVolumeEngine?`.
- **API:** `set(_:)`, `current`.

### `globalMultitouchCallbackRelay` — file-scoped — ~line 517
- **Type:** `MTContactFrameCallback` (`@convention(c)`).
- **Logic:** `activeEngineBox.current?.handleTouches(rawPtr: touches, count: count)`; returns `0`.
- **Called by:** private framework (per contact frame).

### C function-pointer typedefs — ~line 144-154
- `MTContactFrameCallback` = `(UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32`
- `MTDeviceCreateList` = `() -> Unmanaged<CFArray>?`
- `MTRegisterContactFrameCallback` = `(UnsafeMutableRawPointer, MTContactFrameCallback) -> Void`
- `MTDeviceStart` = `(UnsafeMutableRawPointer, Int32) -> Void`
- `MTDeviceStop` = `(UnsafeMutableRawPointer) -> Void`
- `MTDeviceGetSensorSurfaceDimensions` = `(UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32`

---

# 3. `Audio/AppVolumeManager.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Audio/AppVolumeManager.swift`
- **Purpose:** central volume abstraction. Decides between **app-only volume** (offline AVPlayer + web player JS)
  and **system volume** (CoreAudio via `VolumeController`), and shows volume overlays.
- **Subsystem:** Audio (volume control).
- **Depends on:** `AppKit`, `WebKit` (unused in file body? — see below), `AVFoundation` (via `NativeAudioPlayer`);
  `VolumeController.shared`, `NativeAudioPlayer.shared`, `NowPlayingManager.shared` (evaluateJS),
  `CenteredMenuBarLyricsWindowController.shared`, `UserDefaults`.
- **Depended on by:** `EdgeVolumeEngine` (`getEffectiveVolume`/`setEffectiveVolume`), `KeyboardCommandHandler`
  (arrows), `SettingsPanel.swift` (isAppVolumeOnly toggle), `NativeAudioPlayer` (isAppVolumeOnly, mediaVolume).
- **Important imports:** `AppKit`, `WebKit`, `AVFoundation`. (`WebKit` import is not strictly needed in this file
  — JS is injected through `NowPlayingManager.evaluateJS`, not WKWebView directly. `INFERRED — possibly unused import`.)
- **Classes defined:** `AppVolumeManager`.
- **Functions defined:** `getEffectiveVolume()`, `setEffectiveVolume(_:)`, `applyMediaVolume(_:)`,
  `resetPlayerVolumeToMax()`.
- **Defaults keys:** `Mooziac_IsAppVolumeOnly` (bool, default `false`), `Mooziac_MediaVolume` (Float, default `1.0`).
- **Events:** none registered.
- **Side effects:** overlay windows; JS injection; AVPlayer volume writes; system volume writes.
- **Files it communicates with:** `NativeAudioPlayer`, `VolumeController` (EdgeVolumeEngine.swift),
  `NowPlayingManager`, `CenteredMenuBarLyricsWindowController`.

## CLASS ENTRY — `AppVolumeManager`

- **Type:** `public final class`, singleton `static let shared`.
- **Purpose:** single switch for app-only vs system volume.
- **Properties:**
  - `isAppVolumeOnly: Bool` (computed; defaults-backed). Setter: on true → `applyMediaVolume(mediaVolume)` +
    overlay "Separate App Sound: ON"; on false → `resetPlayerVolumeToMax()` + overlay "System Sound: ON".
  - `mediaVolume: Float` (computed; defaults-backed, clamped 0…1, default `1.0`). Setter → `applyMediaVolume(clamped)`.
- **init:** private, empty.
- **API:**
  - `getEffectiveVolume() -> Float`: `mediaVolume` if app-only else `VolumeController.shared.getVolume()`.
  - `setEffectiveVolume(_ vol: Float)`: clamp; if app-only → set `mediaVolume` + main-async overlay
    `showVolumeOverlay(volumePercent:, isAppOnly: true)`; else → `VolumeController.shared.setVolume(clamped)` +
    main-async overlay `isAppOnly: false`.
  - `applyMediaVolume(_ vol: Float)`: `NativeAudioPlayer.shared.setVolume(vol)`; inject JS that sets
    `document.querySelector('video').volume` to `vol` and calls `#movie_player`/`.html5-video-player`
    `setVolume(Int(vol*100))` if available (in a try/catch).
  - `resetPlayerVolumeToMax()`: `NativeAudioPlayer.shared.setVolume(1.0)`; JS sets video volume `1.0` and
    player `setVolume(100)`.
- **Dependencies:** `NativeAudioPlayer`, `VolumeController`, `NowPlayingManager`, overlay window controller.
- **Consumers:** `EdgeVolumeEngine` (drag), `KeyboardCommandHandler` (Up/Down arrows), settings UI.
- **Side effects:** JS evaluation on web player; AVPlayer volume; system CoreAudio volume; overlay window.
- **What would break if removed:** the volume abstraction used by gestures/arrows/settings; app-only volume.
- **Note:** `setEffectiveVolume` overlay dispatch is duplicated with the `isAppVolumeOnly` branches (identical
  `DispatchQueue.main.async` blocks) — minor duplication (see RISKS).

---

# 4. `Audio/AudioRouteMonitor.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Audio/AudioRouteMonitor.swift`
- **Purpose:** detect default-output-device changes and auto-pause playback (unless sleeping). Uses a CoreAudio
  property listener on the system object plus lock/sleep distributed notifications.
- **Subsystem:** Audio (route handling).
- **Depends on:** `AppKit`, `CoreAudio`; `NowPlayingManager.shared` (currentState.isPlaying, pause),
  `CenteredMenuBarLyricsWindowController.shared`, `UserDefaults`.
- **Depended on by:** `AppDelegate` (`startMonitoring()`), `ContextMenu.swift` (isAutoPauseOnDisconnectEnabled toggle).
- **Important imports:** `AppKit`, `CoreAudio`.
- **Classes defined:** `AudioRouteMonitor` (+ file-scoped C callback `audioOutputDeviceChangedCallback`).
- **Functions defined:** `startMonitoring()`, `stopMonitoring()`, `handleScreenLocked()`, `handleScreenUnlocked()`,
  `handleDeviceChanged()`, `getCurrentOutputDeviceID()`.
- **Defaults key:** `YTM_isAutoPauseOnDisconnectEnabled` (bool, default `true`).
- **Constants:** `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioObjectPropertyScopeGlobal`,
  `kAudioObjectPropertyElementMain`.
- **Properties/state:** `lastOutputDeviceID`, `isMonitoring`, `isSleeping`.
- **Events:** DNC `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`; NSWorkspace `.willSleepNotification` /
  `.didWakeNotification`; CoreAudio property-change callback.
- **Side effects:** pauses `NowPlayingManager` playback; shows overlay "Audio Device Changed (Paused)".
- **External APIs:** `AudioObjectAddPropertyListener` / `AudioObjectRemovePropertyListener` /
  `AudioObjectGetPropertyData`; `DistributedNotificationCenter`, `NSWorkspace`.
- **Files it communicates with:** `NowPlayingManager`, `CenteredMenuBarLyricsWindowController`, `AppDelegate`.

## CLASS ENTRY — `AudioRouteMonitor`

- **Type:** `final class` (internal), singleton `static let shared`.
- **Purpose:** pause playback when the default audio output changes, but not during sleep/lock.
- **Properties:** `isAutoPauseOnDisconnectEnabled` (defaults-backed), `lastOutputDeviceID`, `isMonitoring`,
  `isSleeping`.
- **init:** default; `deinit` calls `stopMonitoring()`.
- **API:** `startMonitoring()`, `stopMonitoring()`, private `handleScreenLocked/Unlocked`, fileprivate
  `handleDeviceChanged()`, private `getCurrentOutputDeviceID()`.
- **Lifecycle:** `startMonitoring` registers a CoreAudio listener keyed by an unretained self pointer
  (`Unmanaged.passUnretained(self).toOpaque()`). `stopMonitoring` removes it. (Note: if start is never stopped
  before dealloc, the listener would point at freed memory — mitigated by `deinit`; app-lifetime singleton so
  low practical risk.)
- **Consumers:** `AppDelegate` start; `ContextMenu` toggle.
- **What would break if removed:** auto-pause on device switch.

## FUNCTION ENTRIES — `AudioRouteMonitor`

### `startMonitoring()` — ~line 20
- **Purpose:** register the CoreAudio listener + observers.
- **Flow:** guard `!isMonitoring`; set flag; seed `lastOutputDeviceID`; `AudioObjectAddPropertyListener(system,
  kAudioHardwarePropertyDefaultOutputDevice, audioOutputDeviceChangedCallback, selfPtr)`; add DNC observers for
  `com.apple.screenIsLocked`→`handleScreenLocked`, `com.apple.screenIsUnlocked`→`handleScreenUnlocked`;
  NSWorkspace willSleep→`handleScreenLocked`, didWake→`handleScreenUnlocked`.
- **Note:** selector-based observers (retained by the system on `self`).

### `stopMonitoring()` — ~line 49
- **Flow:** guard `isMonitoring`; clear flag; `AudioObjectRemovePropertyListener(...)`; remove all DNC + NSWorkspace
  observers.
- **Called by:** `deinit`.

### `handleScreenLocked()` — @objc private — ~line 70
- **Purpose:** `isSleeping = true`.
- **Also invoked by:** willSleep.

### `handleScreenUnlocked()` — @objc private — ~line 74
- **Purpose:** `isSleeping = false`.
- **Also invoked by:** didWake.

### `handleDeviceChanged()` — fileprivate — ~line 78
- **Purpose:** react to output-device change.
- **Flow:** guard `!isSleeping`; fetch new id; if old id != unknown and differs → if enabled, main-async: if
  `NowPlayingManager.shared.currentState.isPlaying` → `NowPlayingManager.shared.pause()` +
  `showCustomTextOverlay("Audio Device Changed (Paused)")`. Update `lastOutputDeviceID = newDeviceID`.
- **Called by:** C callback (dispatched to main).
- **Note:** `NowPlayingManager.pause()` is engine-agnostic (works for online/offline) `INFERRED FROM SOURCE`.

### `getCurrentOutputDeviceID()` — private — ~line 94
- **Purpose:** query `kAudioHardwarePropertyDefaultOutputDevice`.
- **Output:** `AudioObjectID` (may be `kAudioObjectUnknown` on failure).

### `audioOutputDeviceChangedCallback` — file-scoped C function — ~line 114
- **Purpose:** C trampoline; `Unmanaged<AudioRouteMonitor>.fromOpaque(clientData).takeUnretainedValue()`;
  `DispatchQueue.main.async { monitor.handleDeviceChanged() }`; returns `noErr`.
- **Called by:** CoreAudio (on a system audio thread — hence the main-queue hop).

---

# 5. `Audio/ClickSound.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Audio/ClickSound.swift`
- **Purpose:** play a system click sound ("HaptiTrack's launch flourish click").
- **Subsystem:** Audio (feedback).
- **Depends on:** `AppKit`, `AudioToolbox`.
- **Depended on by:** `LaunchAnimationController` (creates `ClickSound()`).
- **Important imports:** `AppKit`, `AudioToolbox`.
- **Classes defined:** `ClickSound`.
- **Functions defined:** `play()`, `stop()`.
- **Constants:** system sound ID `1104`.
- **External APIs:** `AudioServicesPlaySystemSound`.
- **Files it communicates with:** `LaunchAnimationController`.

## CLASS ENTRY — `ClickSound`

- **Type:** `public final class`.
- **Purpose:** tiny wrapper around `AudioServicesPlaySystemSound(1104)`.
- **init:** public, empty.
- **API:** `play()` (plays system sound 1104); `stop()` (empty stub).
- **Side effects:** plays a system sound.
- **What would break if removed:** the launch flourish click in `LaunchAnimationController`.

---

# 6. `Web/YTMWebView.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Web/YTMWebView.swift`
- **Purpose:** container `NSView` hosting the single `WKWebView` that loads music.youtube.com. Owns webview
  configuration (user agent, content rule list, CSS user script), navigation delegate behavior, offline overlay,
  session restore, autoplay-on-search JS, player-page parking, Google login loading, and WebContent-process crash
  recovery.
- **Subsystem:** Web (WebKit integration).
- **Depends on:** `Foundation`, `WebKit`, `AppKit`; `NowPlayingManager.shared` (attach, evaluateJS,
  handleWebContentTermination, markTerminationRecoveryComplete, currentState, flushSessionState),
  `OfflineOverlayView`, `NetworkMonitor.shared` (isReachable, statusChangedNotification, reconnectedNotification),
  `LikedSongsManager.shared`, `UserDefaults`.
- **Depended on by:** `MainViewController` (instantiates `YTMWebViewContainer()`), `NowPlayingManager`
  (evaluateJS/evaluateJSWithResult route through `mainViewController.webViewContainer.webView`), `ContextMenu`
  (login / cookie clearing), `DynamicIslandPlayerView` (parking/restore).
- **Important imports:** `Foundation`, `WebKit`, `AppKit`.
- **Classes defined:** `YTMWebViewContainer`.
- **Constants:** `static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15
  (KHTML, like Gecko) Version/17.0 Safari/605.1.15"` (line 584).
- **Properties/state:** `webView`, `progressView`, `offlineOverlay`, `hasRestoredInitialPosition`,
  `shouldRestoreSavedTime`, `videoToRestoreOnLaunch`, crash-recovery state (`isRecoveringFromTermination`,
  `recoveryVideoId`, `recoveryTime`, `recoveryResumePlayback`, `recoveryWatchdog`).
- **Events registered:** NotificationCenter `YTM_reloadWebView` → `webView.reload()`; `NetworkMonitor
  statusChangedNotification` → offline overlay; `NetworkMonitor.reconnectedNotification` → reload + hide overlay.
- **JS bridge handler name:** `nowPlayingHandler` — registered by `NowPlayingManager`'s `ObserverBridge.setupInWebView`
  via `NowPlayingManager.shared.attach(to: webView)` (called at line 170). Not registered in this file directly.
- **User scripts added:** one `WKUserScript` (CSS injection) at `.atDocumentEnd`, `forMainFrameOnly: true`.
  `WKUserContentController` also gets `WKContentRuleList` "YTMBlockRules" (see URLFilter section).
- **Configuration details (init, lines 20-98):**
  - `URLCache.shared.memoryCapacity = 512 * 1024`; `diskCapacity = 2 * 1024 * 1024` (global side effect).
  - `WKWebsiteDataStore.default()`.
  - `allowsAirPlayForMediaPlayback = false`.
  - `mediaTypesRequiringUserActionForPlayback = []` (autoplay allowed).
  - `suppressesIncrementalRendering = true`.
  - `WKWebpagePreferences.allowsContentJavaScript = true`.
  - `config.preferences.setValue(false, forKey: "developerExtrasEnabled")`.
  - CSS string (hide video + cinematic background layers + disable backdrop blur) JSON-encoded into a
    `WKUserScript` that creates a `<style>` element.
  - Content rule list JSON (blocklist) compiled async under id "YTMBlockRules".
- **Side effects:** global `URLCache` mutation; cookie persistence via default store; prints; overlay show/hide;
  JS evaluation.
- **External APIs / system frameworks:** `WKWebView`, `WKWebViewConfiguration`, `WKUserScript`,
  `WKUserContentController`, `WKContentRuleListStore`, `NSProgressIndicator`, `NSLayoutConstraint`,
  `NotificationCenter`, `NetworkMonitor`.
- **Files it communicates with:** `NowPlayingManager` (ObserverBridge), `NetworkMonitor`, `OfflineOverlayView`,
  `LikedSongsManager`, `MainViewController`, `UserDefaults` (`YTM_lastVideoId`, `YTM_lastUrl`, `YTM_lastTime`).

## CLASS ENTRY — `YTMWebViewContainer`

- **Type:** `class YTMWebViewContainer: NSView, WKNavigationDelegate, WKUIDelegate` (internal).
- **Purpose:** single WebKit surface for YouTube Music; handles restore, autoplay, recovery, parking.
- **Properties:**
  - `let webView: WKWebView` (public/internal)
  - `private let progressView = NSProgressIndicator()`
  - `private let offlineOverlay = OfflineOverlayView()`
  - `private var hasRestoredInitialPosition = false`
  - `private var shouldRestoreSavedTime = false`
  - crash recovery: `isRecoveringFromTermination`, `recoveryVideoId`, `recoveryTime`, `recoveryResumePlayback`,
    `recoveryWatchdog: DispatchWorkItem?`
  - `private var videoToRestoreOnLaunch = ""`
  - `public static let userAgent: String`
- **init(frame):** performs global cache config, builds config + CSS script, sets user agent, `super.init`,
  compiles content rule list (async), `setupViews()`, `setupWebView()`, registers the 3 NotificationCenter
  observers. Note: the content-rule-list completion captures `self` weakly and mutates
  `self?.webView.configuration.userContentController` — race window where webView may already be loading
  (`INFERRED`).
- **init?(coder):** `fatalError`.
- **API (public):** `selectSongTab()`, `parkOnPlayerPage()`, `loadGoogleLogin()`, `static userAgent`.
- **API (internal):** `setupViews`, `setupWebView`, navigation delegate methods, `buildRestorePlaybackJS`,
  `webViewWebContentProcessDidTerminate`, `startRecoveryWatchdog`, `handleNavigationFailure`,
  `showOfflineOverlay`, `hideOfflineOverlay`.
- **Dependencies:** `NowPlayingManager`, `OfflineOverlayView`, `NetworkMonitor`, `LikedSongsManager`, UserDefaults.
- **Consumers:** `MainViewController` (hosts it), `NowPlayingManager` (JS bridge + evaluateJS target),
  `ContextMenu` (login via `loadGoogleLogin`, cookie clear), player UI (parking).
- **Lifecycle:** created once by `MainViewController` (line 15); lives for app lifetime; WebContent process can be
  terminated and restored in-place.
- **What would break if removed:** all online playback, YT UI, session restore, crash recovery, the JS bridge.

## FUNCTION ENTRIES — `YTMWebViewContainer`

### `init(frame:)` — ~line 20
- **Flow:** see class entry. Registers observers: `YTM_reloadWebView` (reload), network status (overlay), network
  reconnect (reload).
- **Side effects:** mutates global `URLCache`, compiles rule list asynchronously.

### `setupViews()` — private — ~line 128
- **Purpose:** Auto Layout pinning of webView (full), offlineOverlay (full), progressView (top bar, height 3).
- **Details:** progress bar style `.bar`, `isIndeterminate = false`, hidden initially; overlay hidden initially;
  `offlineOverlay.onRetry = { webView.reload() }`.

### `setupWebView()` — private — ~line 165
- **Purpose:** attach delegates + JS bridge, compute restore URL, load it.
- **Flow:** `webView.navigationDelegate = self`, `uiDelegate = self`,
  `webView.underPageBackgroundColor = .clear`; `NowPlayingManager.shared.attach(to: webView)`.
  Restore decision:
  - Read `YTM_lastVideoId`; read `YTM_lastUrl`. If last URL is a `music.youtube.com` watch URL → use it (and derive
    videoId if empty via `components(separatedBy: "v=")`).
  - Else if videoId non-empty → `https://music.youtube.com/watch?v=\(id)&list=RDAMVM\(id)`.
  - Else → `https://music.youtube.com/` and reset `YTM_lastTime = 0.0`.
  - If restoring → `shouldRestoreSavedTime = true`.
- **Side effects:** loads web content; prints restore message.

### `selectSongTab()` — public — ~line 203
- **Purpose:** force YouTube Music into "song/audio" (OMV) mode.
- **JS:** repeatedly (200 ms interval, max ~6 attempts) finds `ytmusic-av-toggle`; if
  `playback-mode == 'OMV_PREFERRED'` clicks `button.song-button`.
- **Called by:** `didFinish` (immediately + after 0.5 s + after 1.5 s).

### `webView(_:didStartProvisionalNavigation:)` — ~line 198
- **Purpose:** show progress bar at `0.2`.

### `webView(_:didFinish:)` — ~line 235
- **Purpose:** navigation-completion handler.
- **Flow:** progress `1.0`; `LikedSongsManager.shared.refreshSignInStatus()`; hide progress after `0.3 s`;
  `hideOfflineOverlay()`; `selectSongTab()` three times (now, +0.5 s, +1.5 s).
- **Search autoplay:** if URL contains `search?q=`: injects `autoPlayJS` — a 250 ms `setInterval` (max 30 attempts)
  that:
  1. calls `ensurePlaying()` (uses `#movie_player`/`.html5-video-player` `playVideo`, `video.play()`, or clicks
     `#play-pause-button` with aria-label "Play");
  2. `findAndPlayTopTrack()` clicks (via synthesized `mousedown/mouseup/click` + `element.click()`) the first
     top-card/`ytmusic-responsive-list-item-renderer` play button or title link, then any play button, once.
- **Restore-on-launch:** first finished navigation → if `shouldRestoreSavedTime`, reset flag and evaluate
  `buildRestorePlaybackJS(videoId: YTM_lastVideoId, targetTime: YTM_lastTime, resume: false)`.
- **Crash recovery completion:** if `isRecoveringFromTermination` → clear recovery state, cancel watchdog,
  `NowPlayingManager.shared.markTerminationRecoveryComplete()`, evaluate `buildRestorePlaybackJS(...)` with
  `recoveryVideoId/recoveryTime/recoveryResumePlayback`.
- **Note:** `buildRestorePlaybackJS` runs a 250 ms `setInterval` (max 20 attempts) that cues/seek via
  `player.cueVideoById(id, time)` if current video differs, `player.seekTo(time, true)` if `targetTime > 2.0`,
  applies `playVideo()/pauseVideo()` per `resume`, calls `enforceSong()` (clicks song-button when OMV mode), or
  falls back to raw `video.currentTime` + `play()/pause()`.

### `buildRestorePlaybackJS(videoId:targetTime:resume:)` — private — ~line 384
- **Input:** `videoId: String`, `targetTime: Double`, `resume: Bool`.
- **Output:** JS source string (as documented above).

### `webViewWebContentProcessDidTerminate(_:)` — ~line 456
- **Purpose:** crash recovery entry point (called by WebKit on WebContent death, e.g. kill -9 / OOM).
- **Flow:** guard not already recovering; set flag. Snapshot `YTM_lastVideoId`/`YTM_lastTime`/current isPlaying.
  `NowPlayingManager.shared.handleWebContentTermination()` (re-wires JS bridge, suppresses stale callbacks).
  Choose target URL: `YTM_lastUrl` if it is a music watch URL, else current `webView.url`, else
  `https://music.youtube.com/`. `hideOfflineOverlay()`; `load` or `reload`. `startRecoveryWatchdog()`.
- **Side effects:** reloads web content; logs.

### `startRecoveryWatchdog()` — private — ~line 500
- **Purpose:** after 20 s, if recovery never completed, clear recovery state and call
  `NowPlayingManager.shared.markTerminationRecoveryComplete()`.
- **Async:** `DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: watchdog)`.

### `webView(_:didFail:withError:)` / `webView(_:didFailProvisionalNavigation:withError:)` — ~lines 513/518
- **Flow:** hide progress; `handleNavigationFailure(error)`.

### `handleNavigationFailure(_:)` — private — ~line 523
- **Logic:** ignore `NSURLErrorCancelled`; if unreachable or the error code is one of
  `NSURLErrorNotConnectedToInternet / CannotFindHost / CannotConnectToHost / TimedOut / NetworkConnectionLost /
  DNSLookupFailed / DataNotAllowed` → `showOfflineOverlay()`.

### `showOfflineOverlay()` / `hideOfflineOverlay()` — private — ~lines 547/552
- **Logic:** toggle `offlineOverlay.isHidden`; `show` refreshes `updateNetworkState(isReachable:)` first.

### `parkOnPlayerPage()` — public — ~line 559
- **Purpose:** keep the webview on a lean watch page while in player mode.
- **Logic:** if current URL already contains `watch?v=` → return. Build URL from `YTM_lastUrl` or
  `YTM_lastVideoId`; if it differs from current URL → `load`.
- **Called by:** player UI (`INFERRED FROM SOURCE` — no caller found in grep of the 11 files; called externally
  in player views).

### `loadGoogleLogin()` — public — ~line 574
- **Purpose:** open Google sign-in in the same webview.
- **Flow:** `NowPlayingManager.shared.flushSessionState(keepCookies: true)`; load
  `https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F`
  with UA header. Note: `passive=true` requests no account chooser interaction (`INFERRED`).

### WKUIDelegate / navigation policy — ~lines 587-601
- `createWebViewWith:` — if `targetFrame == nil`, load request in the same webview; return nil (single-window auth).
- `decidePolicyFor navigationAction:` — same behavior; if no target frame, load + `.cancel`, else `.allow`.

---

# 7. `Web/URLFilter.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Web/URLFilter.swift`
- **Purpose:** lightweight heuristic to detect whether a text string contains a clickable link (used to decide
  whether to paste/lookup a URL vs. a song query).
- **Subsystem:** Web (text classification).
- **Depends on:** `Foundation`.
- **Depended on by:** `DynamicIslandPlayerView/Core.swift` (lines 556, 923), `GlassSearchField.swift` (line 193).
- **Important imports:** `Foundation` only.
- **Classes defined:** `struct URLFilter` (static helper).
- **Functions defined:** `static func containsLink(_ text: String) -> Bool`.
- **Constants:** matched domain fragments: `youtube.com/`, `youtu.be/`, `music.youtube.com/`, `spotify.com/`,
  `apple.com/`; TLD suffixes `.com .org .net .io .be .co`; prefixes `http://`, `https://`, `www.`, `ftp://`.
- **External APIs:** `NSDataDetector` (link type).
- **Files it communicates with:** player views, search field.

## FUNCTION ENTRY — `URLFilter.containsLink(_:)` — ~line 4

- **Input:** `text: String`. **Output:** `Bool`.
- **Flow:**
  1. Trim whitespace/newlines; empty → false.
  2. Lowercase; if prefixed `http://`, `https://`, `www.`, `ftp://` → true.
  3. If contains any of `youtube.com/`, `youtu.be/`, `music.youtube.com/`, `spotify.com/`, `apple.com/` → true.
  4. `NSDataDetector` link matches; true if a `.link` match exists whose `url.scheme != nil` **or** the string
     contains `.com/.org/.net/.io/.be/.co`.
- **Side effects:** none.
- **Note:** this file does **NOT** contain the content-blocking rule list. The ad/analytics `WKContentRuleList`
  lives in `YTMWebView.swift` (see below).

### The content rule JSON (in `YTMWebView.swift`, lines 77-92) — id `"YTMBlockRules"`

Array of `{ "trigger": { "url-filter": <regex> }, "action": { "type": "block" } }` objects. Exact filters
(all `.*...` regexes, `\\.` escaped):

| url-filter regex | Blocks |
| :--- | :--- |
| `.*google-analytics\\.com.*` | Google Analytics |
| `.*doubleclick\\.net.*` | DoubleClick (any path) |
| `.*doubleclick\\.net\\/pagead.*` | DoubleClick pagead (subsumed by above; redundant) |
| `.*googletagmanager\\.com.*` | Tag Manager |
| `.*googleadservices\\.com.*` | Ad Services |
| `.*googlesyndication\\.com.*` | Syndication |
| `.*googletagservices\\.com.*` | Tag Services |
| `.*mobileads\\.google\\.com.*` | Mobile Ads |
| `.*pagead\\.googlesyndication\\.com.*` | Pagead syndication (subsumed) |
| `.*adsafeprotected\\.com.*` | AdSafeProtected |
| `.*scorecardresearch\\.com.*` | ScorecardResearch |
| `.*quantserve\\.com.*` | QuantServe |

Notes: this is a URL **blocklist** (no cosmetic hiding, no allowlist exceptions). Two entries are redundant with
earlier, broader rules. Compiled asynchronously; on success
`webView.configuration.userContentController.add(ruleList)`.

---

# 8. `Input/GestureMappingManager.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Input/GestureMappingManager.swift`
- **Purpose:** persist and execute user-customizable trackpad gesture mappings (which `GestureAction` fires for
  each `GestureType`).
- **Subsystem:** Input (gesture mappings).
- **Depends on:** `AppKit`; `GestureType`/`GestureAction` (Models), `NowPlayingManager.shared`,
  `CenteredMenuBarLyricsWindowController.shared`, `VolumeController.shared`, `StatusItemManager.shared`, `UserDefaults`.
- **Depended on by:** `EdgeVolumeEngine` (corner taps → executeAction), `ContextMenu.swift`
  (get/set/reset mappings).
- **Important imports:** `AppKit`.
- **Classes defined:** `GestureMappingManager`.
- **Functions defined:** `getAction(for:)`, `setAction(_:for:)`, `resetToDefaults()`,
  `executeAction(for:)`, `executeAction(_:)`.
- **Defaults key pattern:** `YTM_gestureMapping_\(gesture.rawValue)`; mute-restore key `YTM_preMuteVolume`.
- **Files it communicates with:** `EdgeVolumeEngine`, `ContextMenu`, `NowPlayingManager`, overlay window,
  `StatusItemManager`.

## CLASS ENTRY — `GestureMappingManager`

- **Type:** `public final class`, singleton `static let shared`.
- **Purpose:** map trackpad corner-tap triggers to user-assigned actions; execute them.
- **Properties:** none stored; purely defaults-backed.
- **API:**
  - `getAction(for gesture: GestureType) -> GestureAction` — reads `YTM_gestureMapping_<raw>`; falls back to
    `gesture.defaultAction`.
  - `setAction(_ action: GestureAction, for gesture: GestureType)` — writes `action.rawValue` to the key.
  - `resetToDefaults()` — removes all four keys.
  - `executeAction(for gesture: GestureType)` — resolves then dispatches.
  - `executeAction(_ action: GestureAction)` — dispatch switch (below).
- **Dispatch switch (`executeAction(_:)`, line 41):**
  - `.nextTrack` → `NowPlayingManager.nextTrack()` + overlay "Next Track"
  - `.previousTrack` → `NowPlayingManager.previousTrack()` + overlay "Previous Track"
  - `.togglePlayPause` → `NowPlayingManager.togglePlayPause()` + overlay "Paused"/"Playing" based on
    `currentState.isPlaying` **after** the toggle (note: label logic is inverted-looking — if `isPlaying` is true
    after toggling it shows "Paused"; see RISKS).
  - `.toggleLyrics` → `CenteredMenuBarLyricsWindowController.shared.toggleOverlay()` + overlay "Lyrics Enabled"/
    "Lyrics Disabled" based on `isEnabled`.
  - `.volumeUp` → `NowPlayingManager.adjustVolume(deltaPercent: 5.0)`
  - `.volumeDown` → `NowPlayingManager.adjustVolume(deltaPercent: -5.0)`
  - `.toggleMute` → if `VolumeController.shared.getVolume() > 0.01`: save `Double(current)` to `YTM_preMuteVolume`,
    `setVolume(0.0)`, overlay "Muted"; else restore `YTM_preMuteVolume` (fallback `0.3` if `<= 0.05`), overlay
    "Volume: N%".
  - `.togglePlayer` → if `StatusItemManager.shared?.statusItem.button` exists → `togglePanel(button)`.
- **Consumers:** `EdgeVolumeEngine` corner taps; context-menu UI.
- **What would break if removed:** gesture→action dispatch, custom mappings UI.

---

# 9. `Input/GlobalHotKeyManager.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Input/GlobalHotKeyManager.swift`
- **Purpose:** register global (app-wide, even when app not focused) media hotkeys.
- **Subsystem:** Input (global hotkeys).
- **Depends on:** `AppKit`, `Carbon`; `NowPlayingManager.shared`.
- **Depended on by:** `AppDelegate` (`INFERRED FROM SOURCE` — not verified in the 11-file set; grep shows no
  caller inside the documented files; `INFERRED` it is started at app launch).
- **Important imports:** `AppKit`, `Carbon`.
- **Classes defined:** `GlobalHotKeyManager`.
- **Functions defined:** `startMonitoring()`, `stopMonitoring()`.
- **Constants / key codes:** modifiers `[.control, .option]` **or** `[.command, .shift]`;
  key codes `49` (spacebar → play/pause), `124` (right → next), `123` (left → previous), `37` ('L' → like).
- **Events:** none (uses `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`).
- **Files it communicates with:** `NowPlayingManager`.

## CLASS ENTRY — `GlobalHotKeyManager`

- **Type:** `public final class`, singleton `static let shared`.
- **Purpose:** global keyboard shortcuts (works when app is not frontmost).
- **Properties:** `private var eventMonitor: Any?`.
- **API:** `startMonitoring()` (idempotent — guard nil), `stopMonitoring()`.
- **Implementation notes:** uses an **NSEvent global monitor** (NOT Carbon `RegisterEventHotKey`, despite the
  `Carbon` import which is otherwise unused in the file). `startMonitoring` logs
  "[GlobalHotKeyManager] Global keyboard shortcuts registered (Control+Option+Space / Cmd+Shift+Space)."
- **Behavior details:** `modifierFlags.intersection(.deviceIndependentFlagsMask)`; if `isControlOption ||
  isCmdShift`, switch on `event.keyCode`. All action calls wrapped in `DispatchQueue.main.async`.
- **Limitations:** global monitors require the app to have Accessibility/Accessibility+Input-Monitoring
  permissions and do not receive events when app is inactive in some macOS versions (`INFERRED FROM SOURCE`;
  `UNKNOWN — requires runtime verification`). Global monitor does NOT prevent the original key event from also
  being delivered to the focused app (no `.localMonitor`/`.systemDefined` suppression).
- **What would break if removed:** global hotkeys; app-local keyboard commands remain via
  `KeyboardCommandHandler` + local monitors.

---

# 10. `Input/KeyboardCommandHandler.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Input/KeyboardCommandHandler.swift`
- **Purpose:** single source of truth for arrow/space media commands (key codes 123/124/126/125/49) used by both
  `StatusItemManager`'s live key monitor and `DynamicIslandPlayerView.keyDown`.
- **Subsystem:** Input (keyboard commands).
- **Depends on:** `Foundation`; `NowPlayingManager.shared`, `AppVolumeManager.shared`.
- **Depended on by:** `StatusItemManager.swift` (line 406), `DynamicIslandPlayerView/Core.swift` (line 1156).
- **Important imports:** `Foundation` only.
- **Classes defined:** `enum KeyboardCommandHandler` (no cases — namespace enum).
- **Functions defined:** `static handle(keyCode:isRepeat:showOverlay:) -> Bool`, `private static formatTime(_:)`.
- **Constants / key codes:** `123` left, `124` right, `126` up, `125` down, `49` spacebar; seek steps
  `isRepeat ? 8.0 : 4.0`; volume step `0.05`.
- **Files it communicates with:** `NowPlayingManager`, `AppVolumeManager`, caller-supplied overlay closure.

## FUNCTION ENTRIES — `KeyboardCommandHandler`

### `handle(keyCode:isRepeat:showOverlay:)` — static — ~line 7
- **Inputs:** `keyCode: UInt16`, `isRepeat: Bool`, `showOverlay: (String) -> Void`.
- **Output:** `Bool` (true = handled).
- **Cases:**
  - `123` (Left): `rewind(seconds: step)`; `newTime = max(0, curr - step)`; overlay `"Rewind Ns: m:ss"`.
  - `124` (Right): `fastForward(seconds: step)`; `newTime = min(duration, curr + step)`; overlay `"Forward Ns: m:ss"`.
  - `126` (Up): volume `curr + 0.05` clamped; `setEffectiveVolume`; overlay `"App Sound: N%"` or `"Volume: N%"`.
  - `125` (Down): same with `- 0.05`.
  - `49` (Space): `togglePlayPause()`; overlay `"Play"`/`"Pause"` computed as `!currentState.isPlaying` **after**
    the toggle (correct here — matches new state; contrast with GestureMappingManager, see RISKS).
  - default: return false.
- **Calls:** `NowPlayingManager.rewind/fastForward/togglePlayPause`, `AppVolumeManager.getEffectiveVolume/
  setEffectiveVolume`, `PlaybackState.getAccurateTime()` (for accurate current time).
- **Side effects:** playback/volume changes + UI overlay.

### `formatTime(_:)` — private static — ~line 56
- **Logic:** NaN/∞ → `"0:00"`; else `"%d:%02d"` minutes/seconds.

---

# 11. `Support/AppExtensions.swift`

## FILE ENTRY

- **File:** `Sources/Mooziac/Support/AppExtensions.swift`
- **Purpose:** (as named) shared AppKit extensions. **In its current state it contains exactly ONE extension.**
- **Subsystem:** Support.
- **Depends on:** `AppKit`.
- **Important imports:** `AppKit`.
- **Classes defined:** none (extension on `NSImage`).
- **Functions defined:** `NSImage.floppyDiskIcon(size:)`.
- **Files it communicates with:** callers of `floppyDiskIcon` (not found in grep of the 11 documented files —
  `INFERRED` the icon is used by save/save-UI elsewhere in the app).

> **IMPORTANT DISCREPANCY vs. task brief:** the task description listed expected extensions (NSColor hex/luminance,
> NSImage resize/tint/rounded, NSView shake/cornerRadius, String fuzzy search, Double time formatting). **None of
> those exist in this file.** The file only contains `NSImage.floppyDiskIcon`. Either those extensions live in other
> files, were removed, or were never merged here. The grep for `extension NSColor|extension NSView|extension String|
> extension Double` across `Sources/Mooziac` returned only this `extension NSImage` — so those utilities do **not**
> exist anywhere in the module. Only `floppyDiskIcon` is documented below.

## EXTENSION ENTRY — `NSImage.floppyDiskIcon(size:)` — ~line 4

- **Signature:** `static func floppyDiskIcon(size: CGFloat = 15.0) -> NSImage`.
- **Purpose:** draw a vector "floppy disk" template icon.
- **Drawing:** `NSImage(size:flipped:false) { rect in ... }`; `isTemplate = true`. Geometry:
  - outer body: rounded rect inset 1.0, radius 1.8, stroke lineWidth 1.3
  - metal shutter: width `0.56*W`, height `0.38*H`, centered horizontally, top-aligned, radius 1.0, lineWidth 1.1
  - shutter slot: `0.28*shutterW` × `0.50*shutterH`, offset `+2.0` from shutter bottom, filled black, radius 0.5
  - label: `0.68*W` × `0.38*H`, bottom-aligned +1.0, radius 0.8, stroke lineWidth 1.0
- **Side effects:** none (pure drawing).
- **Errors:** none.
- **Note:** all colors are fixed black (template rendering adapts via `isTemplate`).

---

# 12. External types referenced by the documented files (verified, for context)

- **`LocalTrack`** (Models/LocalTrack.swift): `Identifiable & Equatable`; `id`, `title`, `artist`, `album`,
  `duration: Double`, `fileURL: URL`, `artwork: NSImage?` (computed via `AppArtworkHelper`), `artworkURL`,
  `lrcURL`, `dateAdded`, `ytVideoId`, `isLiked` (computed → `LocalLibraryManager`), `cleanTitle`/`cleanArtist`.
  Equality = `id` OR `fileURL` match.
- **`RepeatMode`** (Models/RepeatMode.swift): `Int`-raw, cases `.off = 0`, `.one = 1` (no "all").
- **`PlaybackState`** (Models/PlaybackState.swift): fields incl. `hostTimestamp` (CACurrentMediaTime),
  `playbackRate`, `engineMode: PlaybackEngineMode`; `getAccurateTime()` extrapolates
  `currentTime + (now - hostTimestamp) * playbackRate` while playing.
- **`PlaybackEngineMode`** (Models/PlaybackEngineMode.swift): `.online`, `.offline`.
- **`GestureType`** (Models/GestureMappingModels.swift): `bottomRightDoubleTap`, `bottomRightTripleTap`,
  `bottomLeftDoubleTap`, `bottomLeftTripleTap`; defaults: Next / Previous / TogglePlayPause / ToggleLyrics.
- **`GestureAction`** (Models/GestureMappingModels.swift): `nextTrack`, `previousTrack`, `togglePlayPause`,
  `toggleLyrics`, `volumeUp`, `volumeDown`, `toggleMute`, `togglePlayer`.
- **`NowPlayingManager`** (Core/NowPlayingManager/NowPlayingManager.swift): `static shared`; `currentState`,
  `engineMode`; `attach(to:)` → `setupInWebView(userContentController)` (registers **`nowPlayingHandler`**
  script message handler, injects the `ytmObserverInjected` JS poller); `handleWebContentTermination()`
  (suppresses + re-wires bridge, `isRestoringAfterTermination`); `markTerminationRecoveryComplete()`;
  `evaluateJS(_:)` / `evaluateJSWithResult(_:completion:)` (main-queue, guarded by `isSystemSleeping`);
  `flushSessionState(keepCookies:)`; `notifyObservers` (also drives DiscordRPCManager); `updateSystemNowPlayingInfo`;
  posts `Mooziac_EngineModeChanged` notification. Also references defaults `YTM_likedTrackKeysSet`,
  `YTM_lastUrl`, `YTM_lastVideoId`, `YTM_lastTime`, `YTM_lastTitle`, `YTM_lastArtist`.
- **`NetworkMonitor`** (Managers/NetworkMonitor.swift): notification names `"NetworkMonitorStatusChanged"` and
  `"NetworkMonitorReconnected"` (userInfo key `isReachable`), `isReachable`.
- **`OfflineOverlayView`** (Views/Libraries/OfflineOverlayView.swift): `NSView` with `onRetry` closure and
  `updateNetworkState(isReachable:)`.
- **`CenteredMenuBarLyricsWindowController`**: `showVolumeOverlay(volumePercent:isAppOnly:)`,
  `showCustomTextOverlay(text:duration:)`, `toggleOverlay()`, `isEnabled`.
- **`StatusItemManager`**: `statusItem.button`, `togglePanel(_:)`, `mainViewController`.
- **`HistoryManager.trackDidStartOffline(_:)`**, **`LocalLibraryManager`** (`allTracks`, `toggleLike(for:)`,
  `isLiked(trackID:)`), **`LikedSongsManager.refreshSignInStatus()`**.

---

# 13. RISKS & OBSERVATIONS

1. **Dead property `itemEndObserverToken`** — `NativeAudioPlayer.swift:11` is declared, never assigned/read.
   The end-of-item observer is cleaned by name+object instead of token.
2. **Duplicated JS pause snippet** — the exact same IIFE that pauses `video` / `#movie_player` is pasted in
   `playCurrentTrack()` (lines 205-214) and `play()` (lines 233-242). Any fix must be applied twice.
3. **`previousTrack()` restart threshold hardcoded `3.0 s`** (NativeAudioPlayer:285) — no constant; different
   players use 3-5 s; behavior differs between online/offline engines (`INFERRED`).
4. **`playNext`/`appendToQueue` shuffle semantics** — inserting a track into `shuffledQueue` at
   `currentIndex+1` after it was already shuffled produces non-random placement; acceptable but worth noting.
5. **Unretained C callback self pointer in `AudioRouteMonitor`** — `startMonitoring` passes
   `passUnretained(self)` to CoreAudio. Safe only because the singleton outlives the listener; if
   `stopMonitoring` were skipped and the object deallocated, a stale-pointer crash would occur.
6. **`AudioRouteMonitor` observer mismatch** — DNC `com.apple.screenIsLocked`/`screenIsUnlocked` names are hardcoded
   strings; selector-based observers are never removed on app quit (harmless for a singleton, but `stopMonitoring`
   removes them correctly).
7. **Edge-volume callback thread safety** — `handleTouches` runs on the Multitouch framework thread while the tap
   debounce and volume overlay paths hop to main. `isEnabled`/flags are read cross-thread without synchronization
   (no lock/atomic) → data races possible on toggles (`INFERRED FROM SOURCE`; `UNKNOWN — requires runtime
   verification`).
8. **Unvalidated raw memory reads** — `handleTouches` uses `loadUnaligned` at fixed stride/offsets (96-byte layout).
   If the framework's `MTContactFrame` layout differs on a macOS version, this reads garbage and could cause
   phantom gestures or crashes. The private-framework layout is a fragile assumption.
9. **`MTRegisterContactObserver` fallback mismatch** — `registerCallbackFunc` may be resolved to
   `MTRegisterContactObserver` (different C signature) but is bit-cast to the frame-callback signature; invoking it
   with the wrong signature is ABI-unsafe. Also `MTContactFrameCallback` passes 5 args; observer passes different
   args.
10. **Volume drag `±0.25` per-frame clamp + 160 mm full range** — combined with 3 mm arming threshold; behavior on
    small trackpads (13-inch: ~150 mm) differs from the hardcoded 157.8 mm default; real dimensions only come from
    `MTDeviceGetSensorSurfaceDimensions` when it returns 0.
11. **`VolumeController.setVolume` writes element 0, 1, 2 unconditionally** — the `vmvo` write is ignored (`_ =`);
    per-channel scalar writes on devices without channel volume support are silently ignored; mute toggle is only
    "unmute when raising" — lowering to 0 with volume already 0 keeps the mute state untouched.
12. **`AppVolumeManager` unused `WebKit` import** — not needed since JS goes through `NowPlayingManager.evaluateJS`.
13. **`AppVolumeManager.setEffectiveVolume` overlay duplication** — identical `DispatchQueue.main.async` overlay
    blocks in both branches.
14. **`broadcastPlaybackState` gating on `engineMode == .offline`** — during online playback, offline-side state is
    never broadcast; if engine mode ever drifts, UI state can go stale (`INFERRED`).
15. **`play()` double pause semantics** — offline play() pauses web video; online play path is handled by
    NowPlayingManager (not this file); the two engine modes coordinate via `engineMode` but there is no centralized
    mutex — `INFERRED` risk of both engines running concurrently if JS pause fails silently (JS errors are caught
    and swallowed).
16. **Crash-recovery URL fallback order** — recovery prefers `YTM_lastUrl` only if it already contains
    `watch?v=`; if the user was on a non-watch page, it falls back to the current (dead) webview URL, then root —
    so a killed process on a search page reloads search rather than the playing track (`INFERRED`).
17. **`recoveryWatchdog` 20 s fixed window** — slow networks may still be loading past 20 s; watchdog clears
    recovery state and the later `didFinish` will skip the recovery branch, losing the restore.
18. **Global hotkeys use `NSEvent.addGlobalMonitorForEvents`** — requires Accessibility / Input Monitoring
    permission; `Carbon` is imported but `RegisterEventHotKey` is never used. Modifier sets are `Ctrl+Option`
    **or** `Cmd+Shift`; keycode `37` = 'L' (US layout only).
19. **`GestureMappingManager.togglePlayPause` overlay logic** — shows "Paused" when `currentState.isPlaying`
    is true after the toggle and "Playing" when false — i.e., the labels describe the state that *was* active.
    `KeyboardCommandHandler`'s space overlay computes `!isPlaying` and is correct. One of the two is inverted
    relative to the other (`INFERRED` bug/oddity — requires runtime verification).
20. **`YTMWebView` content rule list race** — the blocklist is compiled async in `init`; the webview starts loading
    before the rule list is attached, so the first page load may not have ad blocking applied.
21. **Content rule list has redundant entries** — `doubleclick.net/pagead` is subsumed by `doubleclick.net`,
    `pagead.googlesyndication.com` by `googlesyndication.com`.
22. **`offlineOverlay.onRetry` / `onRetry` closure** retains webView weakly — fine; but `showOfflineOverlay` is not
    called on initial failure if `NetworkMonitor.isReachable` is true yet the load failed for another reason —
    failure paths other than the enumerated NSURLError codes silently do nothing (no overlay, no retry).
23. **`parkOnPlayerPage` no caller found** in the 11 documented files — called from player views outside this
    set (`INFERRED`).
24. **`selectSongTab`/restore JS depend on YouTube DOM** — `ytmusic-av-toggle`, `song-button`,
    `ytmusic-card-shelf-renderer`, `ytmusic-responsive-list-item-renderer` are all third-party DOM; any YouTube
    redesign breaks autoplay/restore silently (JS try/catch swallows errors).
25. **`URLCache` global mutation in `YTMWebViewContainer.init`** — affects the whole app process; every
    `YTMWebViewContainer` init re-sets it (only one instance exists in practice).
26. **`AudioRouteMonitor` treats lock and sleep identically** (`handleScreenLocked` for both) — a lock without sleep
    sets `isSleeping=true` and suppresses pause-on-device-change; a device swap while the screen is merely locked
    will not pause (by design? `INFERRED`).
27. **`ClickSound.stop()` is a no-op stub.**
28. **`NativeAudioPlayer.setupAudioSession()` is an empty stub.**
29. **`GlobalHotKeyManager` and `AudioRouteMonitor` start/stop lifecycle** — `AppDelegate` calls
    `EdgeVolumeEngine.shared.start()` and `AudioRouteMonitor.shared.startMonitoring()`; no matching stop calls were
    found in the 11-file set (`INFERRED` they run for the whole app lifetime).
30. **`startVolume`/`startY` re-anchoring on arming** deliberately avoids a jump, but `startVolume` uses
    `getEffectiveVolume()` which for app-volume mode reads the *stored* `mediaVolume` — dragging volume in
    app-only mode changes persisted `Mooziac_MediaVolume` (and thus native + web volume) rather than system volume.
    This is the intended "app-only" behavior.

---

# Summary (counts)

- **Files documented:** 11 (NativeAudioPlayer, EdgeVolumeEngine, AppVolumeManager, AudioRouteMonitor, ClickSound,
  YTMWebView, URLFilter, GestureMappingManager, GlobalHotKeyManager, KeyboardCommandHandler, AppExtensions).
- **Classes/types defined:** 13 (NativeAudioPlayer, VolumeController, EdgeVolumeEngine, ActiveEngineBox,
  AppVolumeManager, AudioRouteMonitor, ClickSound, YTMWebViewContainer, URLFilter, GestureMappingManager,
  GlobalHotKeyManager, KeyboardCommandHandler, NSImage.floppyDiskIcon extension).
- **Functions/methods/callbacks/observers documented:** ~85 (including private helpers, @objc selectors,
  NotificationCenter observer closures, the C callback `audioOutputDeviceChangedCallback`, the multitouch relay
  `globalMultitouchCallbackRelay`, and JS injection builders).
- **Notification names referenced:** `AVPlayerItemDidPlayToEndTime`, `YTM_reloadWebView`, `NetworkMonitorStatusChanged`,
  `NetworkMonitorReconnected`, `Mooziac_EngineModeChanged`, `com.apple.screenIsLocked`, `com.apple.screenIsUnlocked`,
  `NSWorkspace.willSleepNotification`, `NSWorkspace.didWakeNotification`.
- **UserDefaults keys used:** `Mooziac_LastPlayedLocalTrackId`, `Mooziac_LastPlayedLocalTrackTitle`,
  `Mooziac_IsAppVolumeOnly`, `Mooziac_MediaVolume`, `YTM_lastKnownSystemVolume`, `YTM_v3_isEdgeEngineEnabled`,
  `YTM_v3_isRightEdgeVolumeEnabled`, `YTM_v3_isRightCornerTapsEnabled`, `YTM_v3_isLeftCornerTapsEnabled`,
  `YTM_isAutoPauseOnDisconnectEnabled`, `YTM_gestureMapping_*`, `YTM_preMuteVolume`, `YTM_lastVideoId`,
  `YTM_lastUrl`, `YTM_lastTime` (plus read-only: `YTM_lastTitle`, `YTM_lastArtist`, `YTM_likedTrackKeysSet`).
- **JS bridge handler names:** `nowPlayingHandler` (registered via `NowPlayingManager.attach(to:)`).
- **Risks found:** 30 numbered observations in §13 (5 dead-code/unused items: `itemEndObserverToken`, empty
  `setupAudioSession`, empty `ClickSound.stop`, unused `Carbon` import, unused `WebKit` import in AppVolumeManager).