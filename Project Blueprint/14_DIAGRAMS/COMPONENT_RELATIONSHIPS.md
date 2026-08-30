# Component Relationships

## Core dependency map

```
                    ┌─────────────────────────────┐
                    │      NowPlayingManager      │
                    └───────┬─────┬─────┬─────────┘
                            │     │     │
          ┌─────────────────┘     │     └───────────────────┐
          ▼                       ▼                         ▼
 NativeAudioPlayer       PlayerControls/Queue        LikedSongsManager
 (AVPlayer, offline)     (JS routing)                HistoryManager
                          YTMWebView                 PlaylistManager
                                                    LocalLibraryManager
                                                    DiscordRPCManager
                                                    TrackNotificationManager
                                                    LyricsManager
```

## MainViewController cluster

```
                    ┌─────────────────────────────┐
                    │      MainViewController     │
                    └───┬────┬────┬────┬────┬─────┘
                        │    │    │    │    │
      ┌─────────────────┘    │    │    │    └───────────────┐
      ▼                      ▼    ▼    ▼                    ▼
 StatusItemManager    Player views  YTMWebView      EdgeVolumeEngine
 (window)             (DynamicIsland)  (WebKit)     GlobalHotKeyManager
                                         ProgressStyleManager
```

## Service singletons

```
AppDelegate ──► BackgroundMediaController
             ──► EdgeVolumeEngine
             ──► AudioRouteMonitor
             ──► NetworkMonitor
             ──► DiscordRPCManager
             ──► StatusItemManager
```

## Database layer

```
LocalDatabaseManager (SQLite, raw C API)
   ▲                    ▲                    ▲              ▲
 LocalLibraryManager  PlaylistManager   HistoryManager  LikedSongsManager
 (tracks)             (playlists/items)  (history)       (liked_songs)
   │
   └─► views (Offline, Playlist, History, Liked)
```

## Web ↔ native bridge

```
YTM page
   │ JS mutations / player events
   ▼
injected ObserverBridge script ──message──► ObserverBridge (Swift) ──► NowPlayingManager
   ▲
   │ evaluateJavaScript(command)
   └── PlayerControls / Queue / YTMWebView (Swift)
```

## Note

Singletons communicate via `NotificationCenter` (18 names) and closure observers (NowPlayingManager). No protocol-based DI; `Shared` singletons throughout. See `03_ARCHITECTURE/DEPENDENCY_GRAPH.md` for the full table.