# Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         MENU BAR (status item)                           │
│   ┌──────────┐   ┌─────────────────────────────────────────────────┐     │
│   │ icon     │   │              PANEL WINDOW                       │     │
│   └──────────┘   │  MainViewController ─┐                           │     │
│                  │  ├─ Player views    │ (controls)                │     │
│                  │  │  (DynamicIsland) │                           │     │
│                  │  └─ Tabs: Browser / Offline / Playlists /        │     │
│                  │     Liked / History / Downloads                  │     │
│                  └─────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────────┤
│  LYRICS HUD  ◄── CenteredMenuBarLyricsWindowController (0.1s timer)      │
├──────────────────────────────────────────────────────────────────────────┤
│ NowPlayingManager (canonical state + routing)                            │
│  ├─► ObserverBridge (JS messages) ─► PlaybackState                      │
│  ├─► PlayerControls (JS commands)                                       │
│  ├─► NativeAudioPlayer (offline AVPlayer)                               │
│  ├─► LikedSongsManager / HistoryManager / PlaylistManager               │
│  └─► DiscordRPCManager / TrackNotificationManager / LyricsManager       │
├──────────────────────────────────────────────────────────────────────────┤
│ SERVICES                                                                 │
│  ├─ LocalDatabaseManager (SQLite) ◄── library managers                  │
│  ├─ DownloadManager (yt-dlp/ffmpeg)                                     │
│  ├─ NetworkMonitor (NWPathMonitor)                                      │
│  ├─ AppVolumeManager / AudioRouteMonitor / BackgroundMediaController    │
│  ├─ EdgeVolumeEngine (Multitouch) / GlobalHotKeyManager (NSEvent)       │
│  └─ StatusItemManager (window mgmt)                                     │
├──────────────────────────────────────────────────────────────────────────┤
│ EXTERNAL                                                                 │
│  ├─ YouTube Music (WebKit webview) — primary playback engine            │
│  ├─ LRCLib / Lyrics.ovh (URLSession)                                    │
│  ├─ Discord (UNIX socket IPC)                                           │
│  └─ yt-dlp / ffmpeg (Process)                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## Two-engine model

```
ONLINE ──────────────── WebKit → YTM page → WebContent audio
OFFLINE ─────────────── AVPlayer (app process)
        engineMode = .online | .offline  (NowPlayingManager)
```

## Related

- `03_ARCHITECTURE/SYSTEM_ARCHITECTURE.md`