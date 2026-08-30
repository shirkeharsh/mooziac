# System Integrations

How Mooziac plugs into macOS and external systems.

## macOS frameworks used

| Framework | Used for |
| :--- | :--- |
| AppKit | entire UI, NSStatusItem, windows, menus, animations |
| WebKit | YTMWebView, content-blocking, JS bridge |
| AVFoundation | offline playback (AVPlayer), media metadata |
| MediaPlayer | `MPNowPlayingInfoCenter` (system Now Playing) |
| CoreAudio | system volume control ("vmvo"), output device monitoring |
| IOKit / IOPM | sleep-prevention assertion (`kIOPMAssertionTypePreventUserIdleSystemSleep`) |
| SQLite3 (C) | local database |
| Foundation (URLSession, NWPathMonitor, UserDefaults, FileManager) | networking, state, storage |
| UserNotifications | track-change notifications |
| Carbon (imported) | unused — hotkeys use `NSEvent` monitors instead |

## Private / fragile APIs

| Integration | Risk |
| :--- | :--- |
| `Multitouch` framework (private) | right-edge volume + corner taps — ABI fragility, no official API |
| `AudioObjectGetPropertyData` / device changes | CoreAudio output monitoring (official but low-level) |
| JavaScript DOM scraping of YTM (`#queue`, `ytmusic-player-queue`, Polymer data model) | breaks on YTM DOM changes (CHANGELOG shows repeated fixes) |

## Status bar / menu bar

- `NSStatusItem` with custom view; menu-bar-attached panel window.
- Panel behaviors: attached (below status item), floating (draggable), dock (docked to edge).
- Window frame persisted (`YTM_playerFrameX/Y`, `YTM_playerTopY`, `YTM_savedDisplayID`).

## Media control surface

| Surface | Status |
| :--- | :--- |
| `MPNowPlayingInfoCenter` (title/artist/album/time) | ✅ written |
| `MPNowPlayingInfoPropertyElapsedPlaybackTime` | ✅ written |
| `MPMediaItemArtwork` | ✅ offline (NativeAudioPlayer) |
| `MPRemoteCommandCenter` handlers (media keys / widget / Touch Bar) | ❌ **absent** (risk, `UNKNOWN — requires runtime verification`) |
| Global/local key monitors | ✅ (`NSEvent` monitors) |

## Sleep & screen state

- `BackgroundMediaController`: IOPMAssertion + `ProcessInfo` activity keep system awake for playback.
- Lock/sleep → pause; unlock/wake → optional resume (preference-gated).
- `isSystemSleeping` flag coordination between listeners.

## External IPC

- **Discord**: UNIX socket `/tmp/discord-ipc-0…9`, HANDSHAKE + SET_ACTIVITY.
- **yt-dlp / ffmpeg**: `Process` subprocesses for downloads.

## Filesystem integration

- Watches/scans `~/Music/Mooziac` (configurable `YTM_downloadsFolder`), `Offline/` for local tracks.
- SQLite in `~/Library/Application Support/Mooziac/`.
- Caches in `~/Library/Caches/Mooziac/`.

## Startup / launch integration

- Not a login item by default; launched by user.
- `YTM_isDraggedFromDock` window mode on dock icon drag-to-status-bar.

## Related

- `12_SECURITY/PERMISSIONS.md`, `10_BACKGROUND_SYSTEMS/EVENT_LISTENERS.md`, `99_APPENDIX/RAW_DISCOVERY_NOTES/02_AUDIO_WEB_INPUT.md`.