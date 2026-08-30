# Technology Stack

## Language & toolchain

| Layer | Choice | Notes |
| :--- | :--- | :--- |
| Language | Swift 5.9 | `swift-tools-version: 5.9` |
| Minimum OS | macOS 13.0 (Ventura) | `platforms: [.macOS(.v13)]` |
| UI framework | AppKit (NSView / NSViewController / NSPanel / NSStatusItem) | No SwiftUI except the launch overlay (`LaunchOverlayView` is a SwiftUI `View` used inside an AppKit window via `NSHostingView`) |
| Package manager | Swift Package Manager | `Package.swift`, single executable target `Mooziac` |
| External dependencies | **None** | `dependencies: []` — everything is Apple frameworks + private-framework `dlopen` for Multitouch |

## System frameworks used (from `import` statements across the module)

- **AppKit** — all UI.
- **Foundation** — everything.
- **WebKit** — `WKWebView`, `WKUserScript`, `WKUserContentController`, content rule lists, cookies.
- **AVFoundation** — offline playback (`AVPlayer`, `AVPlayerItem`, `AVURLAsset`), artwork metadata.
- **MediaPlayer** — `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, `MPMediaItemArtwork`.
- **CoreAudio / AudioToolbox** — system volume manipulation (`AudioObjectSetPropertyData` on `vmvo`), audio route monitoring, system sounds (`AudioServicesPlaySystemSound`).
- **IOKit (`pwr_mgt`)** — `IOPMAssertionCreateWithName` sleep prevention.
- **Combine** — used in `LaunchOverlayModel` (ObservableObject).
- **Discord IPC** — hand-rolled UNIX-socket JSON framing (no SDK).
- **SQLite3** — via `import SQLite3` C API (bundled by OS).
- **Multitouch (private, dlopen'd)** — trackpad touch-stream (`MTDeviceCreateList`, `MTRegisterContactFrameCallback`, etc.).
- **UserNotifications** — `UNUserNotificationCenter` track-change banners.
- **Network framework** — `NWPathMonitor` reachability.
- **Carbon** — imported but `RegisterEventHotKey` is NOT used (global monitors used instead). *CONFIRMED FROM SOURCE.*

## External executables invoked

| Executable | Used by | Purpose |
| :--- | :--- | :--- |
| `yt-dlp` | `DownloadManager` | Fetch YouTube Music audio streams (`player_client=mweb,web_safari,tv_embedded,web`) |
| `ffmpeg` | `DownloadManager` | Remux/convert downloaded stream to final format |

## Remote HTTP services

| Service | Used by | Purpose |
| :--- | :--- | :--- |
| YouTube Music (`music.youtube.com`) | `YTMWebView` | Online playback, search autoplay, liked-songs sync |
| LRCLib (`lrclib.net`) | `LyricsManager` | Synced/plain lyrics (`/api/get`, `/api/search`) |
| Lyrics.ovh (`api.lyrics.ovh`) | `LyricsManager` | Plain-lyrics fallback |
| Discord IPC socket (local) | `DiscordRPCManager` | Rich Presence |

## Build & distribution

- `swift build` / `swift build -c release`.
- `build_app.sh` — assembles `Mooziac.app` manually, writes `Info.plist` (bundle id `com.local.Mooziac`, `LSUIElement`), copies assets from `Resources/`, ad-hoc codesigns (`codesign --force --deep --sign -`), launches.
- No Xcode project, no nibs/storyboards (all views are code-built).

## Developer tooling (non-shipped, in `dev/`)

Python + shell scripts for GPU/hardware monitoring, diagnostics (`monitor_gpu_*.py`, `update_diagnostics.py`, `inspect_app_resources.py`, `tree.py`, `tree.c`), and a realtime diagnostics HTML dashboard. These are development aids only (git-ignored).