# Method Reference

A pointer index to every documented method. "Method" = a `func` inside a class/struct/enum (as opposed to standalone functions). Since all 673 `func` declarations are methods of one of the 95 types (or extension methods of `NowPlayingManager`, `DynamicIslandPlayerView`, etc.), the authoritative list is `FUNCTION_INDEX.md`.

## Largest method surfaces (by type)

| Type | Approx. method count | Where documented |
| :--- | ---: | :--- |
| `DynamicIslandPlayerView` (extension, Core.swift + SettingsPanel.swift) | ~130 | 05_PLAYER_WINDOWS_UI |
| `PlaylistLibraryView` (+ cell classes) | ~70 | 06_LIBRARIES_COMPONENTS_UI |
| `LocalDatabaseManager` | ~40 | 03_DATA_MANAGERS |
| `PlaylistManager` | ~44 | 03_DATA_MANAGERS |
| `DownloadManager` | ~29 | 03_DATA_MANAGERS |
| `NativeAudioPlayer` | ~26 | 02_AUDIO_WEB_INPUT |
| `NowPlayingManager` (+ extensions: ObserverBridge/PlayerControls/Queue) | ~45 | 01_CORE_LAYER |
| `StatusItemManager` | ~20 | 01_CORE_LAYER |
| `MainViewController` | ~25 | 01_CORE_LAYER |
| `EdgeVolumeEngine` (+ VolumeController + ActiveEngineBox) | ~15 | 02_AUDIO_WEB_INPUT |
| `LyricsManager` | ~15 | 04_LYRICS_MANAGERS_MODELS |

## Method groups by role

- **Lifecycle**: `init`, `deinit`, `loadView`, `viewDidLoad`, `setupUI`, `setupObservers`, `applicationDidFinishLaunching`, `applicationWillTerminate`.
- **Playback**: `play`, `pause`, `togglePlayPause`, `nextTrack`, `previousTrack`, `seek`, `fastForward`, `rewind`, `setRepeatMode`, `setShuffleState`, `setVolume`, `adjustVolume`, `toggleLike`.
- **State**: `updateState`, `updateSystemNowPlayingInfo`, `notifyObservers`, `broadcastPlaybackState`.
- **JS bridge**: `evaluateJS`, `evaluateJSWithResult`, `setupInWebView`, `userContentController(didReceive:)`, `updateNowPlaying`, `fetchQueue`.
- **Persistence**: all `LocalDatabaseManager` public APIs (upsert/delete/fetch for tracks/playlists/history/likes), `PlaylistManager` CRUD, `HistoryManager` record/track, `LikedSongsManager` toggle/sync.
- **Downloads**: `queueTrack`, `queueTracks`, `cancelTask`, `cancelAllDownloads`, `deleteDownloadedTrack`, `startNextTask`, `finishTask`, `handleStreamingProgress`.
- **Lyrics**: `fetchLyrics`, `fetchSyncedLyrics`, `resolveCurrentLine`, `saveToLocalLyricsCache`, `SyncedLyricsParser.parse`.
- **UI selectors**: ~80 `@objc` action selectors across player/settings/library views (see `CALLBACK_REFERENCE.md`).
- **Gesture/input**: `start`, `stop`, `handleTouches`, `handle`, `startMonitoring`, `stopMonitoring`.

## Cross-file navigation

| I need… | Open |
| :--- | :--- |
| Every func, sorted by file | `FUNCTION_INDEX.md` |
| Every class/struct/enum | `CLASS_REFERENCE.md` |
| Deep method detail (I/O, flow) | raw notes (see `FUNCTION_REFERENCE.md`) |
| Selectors/observers/closures | `CALLBACK_REFERENCE.md` |