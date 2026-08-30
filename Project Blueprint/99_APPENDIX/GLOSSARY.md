# Glossary

Terms used across the blueprint and codebase.

| Term | Definition |
| :--- | :--- |
| **YTM** | YouTube Music (the web app embedded in Mooziac) |
| **Panel** | The main popover/pop-up window attached to the menu-bar status item containing the player |
| **Status item** | `NSStatusItem` in the menu bar (the app's icon) |
| **Now playing / pill** | The Dynamic Island player UI showing current track state |
| **Engine mode** | `.online` (WebKit YTM) vs `.offline` (AVPlayer) — `PlaybackEngineMode` |
| **ObserverBridge** | Swift class receiving `nowPlayingHandler` JS messages |
| **PlayerControls** | Swift class issuing JS playback commands to the YTM page |
| **LRC** | Lyric format with `[mm:ss.xx]` timestamps |
| **HUD** | Centered menu-bar lyrics window (also shows volume toasts) |
| **WAL** | SQLite Write-Ahead Logging journal mode |
| **LDM / LLM / PM / DM** | LocalDatabaseManager / LocalLibraryManager / PlaylistManager / DownloadManager |
| **Playlist context** | `ActivePlaylistPlaybackContext` — playback routed through a playlist |
| **Up-Next** | YTM's queue of upcoming tracks |
| **Automix / radio** | YTM's auto-generated radio queue |
| **LSUIElement** | Info.plist flag making a menu-bar app (no Dock icon) |
| **Ad-hoc signing** | `codesign --force --deep --sign -` — no developer identity |
| **Multitouch framework** | private macOS framework used for trackpad edge gestures |
| **Edge engine** | right-edge volume swipe + corner taps via Multitouch |
| **WebKit data store** | persistent `WKWebsiteDataStore` holding YTM cookies/session |
| **SAPISID** | Google session cookie name used to infer sign-in state |
| **Discord IPC** | local UNIX-socket protocol for Rich Presence |
| **yt-dlp / ffmpeg** | external binaries used by DownloadManager |
| **`YTM_*` / `Mooziac_*` keys** | UserDefaults keys (38 total) |
| **`Mooziac_*` notifications** | NotificationCenter names (18 total) |