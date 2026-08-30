# Dependencies

All third-party dependencies (library + system).

## Library dependencies

**Zero external Swift packages.** `Package.swift` declares `dependencies: []`. Everything is system frameworks + two external binaries.

## System frameworks

| Framework | Import | Consumers |
| :--- | :--- | :--- |
| AppKit | most files | UI |
| WebKit | `YTMWebView`, `URLFilter`, `ObserverBridge` | web + JS bridge |
| AVFoundation | `NativeAudioPlayer`, `AppArtworkHelper` | playback, artwork |
| MediaPlayer | `NowPlayingManager`, `NativeAudioPlayer` | Now Playing center |
| CoreAudio / AudioToolbox | `AppVolumeManager`, `AudioRouteMonitor` | volume, device changes |
| IOKit | `BackgroundMediaController` | sleep assertion |
| SQLite3 | `LocalDatabaseManager` | DB |
| Foundation | everywhere | networking, state |
| UserNotifications | `TrackNotificationManager` | notifications |
| Carbon | `GlobalHotKeyManager` (imported) | **unused** (NSEvent monitors used) |

## Private framework

| Framework | Use | Risk |
| :--- | :--- | :--- |
| `Multitouch` | right-edge volume + corner taps (`EdgeVolumeEngine`) | no public API; ABI fragile |

## External binaries (runtime, not bundled)

| Binary | Purpose | Presence check |
| :--- | :--- | :--- |
| `yt-dlp` | YouTube audio download | checked at job start; startup warning path |
| `ffmpeg` | post-processing / muxing | same |

## External services (network deps)

See `09_NETWORK/EXTERNAL_SERVICES.md` — YTM, LRCLib, Lyrics.ovh, Discord IPC.

## Dependency graph (in-repo)

```
NowPlayingManager ──► NativeAudioPlayer, AppVolumeManager, LikedSongsManager,
                      HistoryManager, PlaylistManager, LocalLibraryManager,
                      DiscordRPCManager, TrackNotificationManager, LyricsManager
MainViewController ──► StatusItemManager, YTMWebViewContainer, player views,
                       EdgeVolumeEngine, GlobalHotKeyManager, ProgressStyleManager
LocalDatabaseManager ◄── LocalLibraryManager, PlaylistManager, HistoryManager, LikedSongsManager
```

## Related

- `03_ARCHITECTURE/DEPENDENCY_GRAPH.md`, `09_NETWORK/EXTERNAL_SERVICES.md`.