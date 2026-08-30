# Dependency Graph

Mapping of how modules depend on each other. Derived from per-file import analysis in the raw discovery notes.

## Notation

```
A ──depends on──▶ B        A ──used by──▶ B
```

## Core dependency diagram

```
                       ┌─────────────────────────────┐
                       │       AppDelegate            │
                       └──┬──────┬──────┬──────┬──────┘
                          │      │      │      │
   BackgroundMediaController EdgeVolumeEngine AudioRouteMonitor NetworkMonitor
   DiscordRPCManager        StatusItemManager  (also used by NowPlayingManager)
                                      │
              ┌───────────────────────┼──────────────────────┐
              ▼                       ▼                      ▼
      MainViewController       ContextMenu           StatusItemPanel
              │
     ┌────────┼────────────┬──────────────┐
     ▼        ▼            ▼              ▼
 DynamicIslandPlayerView  YTMWebView   OfflineLibraryView  PlaylistLibraryView
     │                    (Web/)           │                    │
     │  ┌─────────────────┼───────────────┴────────────────────┘
     └──▼─────────────────▼
      NowPlayingManager (state hub)
        │        │          │
        ▼        ▼          ▼
   ObserverBridge PlayerControls Queue
   (JS bridge)    (dispatch)   (queue JS)
        │              │
        ▼              ▼
  YTMWebView JS  ┌───┴──────────────┐
                 ▼                  ▼
      NativeAudioPlayer     LocalLibraryManager
        (offline engine)    (library + likes)
```

## Full dependency list (high-level, by consumer)

**`NowPlayingManager` depends on:** `YTMWebView`/WebKit (attach, evaluateJS), `NativeAudioPlayer`, `LocalLibraryManager`, `HistoryManager`, `LikedSongsManager`, `PlaylistManager`, `NetworkMonitor`, `DisplayManager`, `AppArtworkHelper` (artwork), `LyricsManager` (indirect), `DiscordRPCManager` (presence). **Used by:** every view, `PlayerControls`, `ObserverBridge`, `Queue`, `AppVolumeManager`, `LyricsManager`, `NativeAudioPlayer`, `StatusItemManager`.

**`MainViewController` depends on:** `DynamicIslandPlayerView`, `YTMWebViewContainer`, `HeaderView`, `OfflineLibraryView`, `PlaylistLibraryView`, `DisplayManager`, `NowPlayingManager`, `LocalLibraryManager`, `PlaylistManager`, `LyricsManager` (indirect). **Used by:** `StatusItemManager`.

**`NativeAudioPlayer` depends on:** `LocalTrack`, `RepeatMode`, `PlaybackState`, `LocalLibraryManager`, `HistoryManager`, `NowPlayingManager`, `AppVolumeManager`. **Used by:** `NowPlayingManager`, `AppVolumeManager`, library views, player views, `LyricsManager`.

**`ObserverBridge` depends on:** WebKit (WKScriptMessageHandler), `NowPlayingManager`, `PlaybackState`, `AppArtworkHelper` (artwork URL→image). **Used by:** `YTMWebView` (attach).

**`LocalDatabaseManager` depends on:** `SQLite3`, `Foundation`. **Used by:** `LocalLibraryManager`, `PlaylistManager`, `HistoryManager`, `LikedSongsManager`, `DownloadManager`.

**`LocalLibraryManager` depends on:** `LocalDatabaseManager`, `AppArtworkHelper`, `AVFoundation`. **Used by:** `NativeAudioPlayer`, `PlaylistManager`, `DownloadManager`, library views, player views, `LikedSongsManager`.

**`PlaylistManager` depends on:** `LocalDatabaseManager`, `LocalLibraryManager`, `LocalTrack`, `NowPlayingManager`, `NativeAudioPlayer`. **Used by:** player views, `PlaylistLibraryView`, `MainViewController`.

**`DownloadManager` depends on:** `LocalDatabaseManager`, `LocalLibraryManager`, `AppArtworkHelper`, `NowPlayingManager` (last-track read). **Used by:** player views (download buttons), library views.

**`LyricsManager` depends on:** `SyncedLyricsParser`, `NowPlayingManager`, `LocalTrack`, URLSession. **Used by:** `CenteredMenuBarLyricsWindowController`, player views.

**`DiscordRPCManager` depends on:** `NowPlayingManager` (state), `PlaybackState`. **Used by:** `AppDelegate`.

**`StatusItemManager` depends on:** `MainViewController`, `ContextMenu`, `StatusItemPanel`, `DisplayManager`, `KeyboardCommandHandler`, `NowPlayingManager`. **Used by:** `AppDelegate`.

**`YTMWebViewContainer` depends on:** `URLFilter`, `NowPlayingManager`, `DisplayManager`, `NetworkMonitor`. **Used by:** `MainViewController`, `StatusItemManager`.

**`EdgeVolumeEngine` depends on:** `AppVolumeManager`, `DisplayManager`, `CenteredMenuBarLyricsWindowController` (overlays), `ClickSound`, Multitouch. **Used by:** `AppDelegate`.

## Circular dependencies

- `NowPlayingManager ⇄ NativeAudioPlayer` (mutual).
- `NowPlayingManager ⇄ LocalLibraryManager` (mutual, via likes/history).
- `NowPlayingManager ⇄ YTMWebView` (attach + evaluateJS + observer messages).
- `MainViewController ⇄ DynamicIslandPlayerView` (delegate + owns).
- These are acceptable within a single module but concentrate state mutation in `NowPlayingManager`.

## Highly coupled / central modules

1. **`NowPlayingManager`** — hub for all playback state; virtually every subsystem touches it.
2. **`LocalDatabaseManager`** — all persistence.
3. **`LocalLibraryManager`** — shared by native player + playlists + downloads + views.
4. **`MainViewController`** — couples player, web, and library views.
5. **`StatusItemManager`** — the app's shell; owns the window, menu, and key monitor.

## Isolated modules

- `ClickSound`, `Support/AppExtensions`, `URLFilter`, `LaunchOverlayView`, `SyncedLyricsParser` (only used by LyricsManager), `LaunchAnimationTimeline` (model, largely unused).

## Single points of failure

- `NowPlayingManager` (if it fails, no state fan-out).
- `LocalDatabaseManager` (if DB corrupts, recovery deletes DB and rebuilds — `recoverCorruptDatabase`).
- JS bridge + YTM DOM (any YouTube redesign silently breaks controls — all JS wrapped in try/catch).
- Private Multitouch ABI in `EdgeVolumeEngine`.