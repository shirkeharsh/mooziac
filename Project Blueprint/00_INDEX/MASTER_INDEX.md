# Mooziac — Master Index

> The entry point to the entire Project Blueprint. This document tells you what Mooziac is, how the application is structured, where each subsystem lives, where to find each type of documentation, and how to navigate the archive.

---

## 1. What Mooziac Is

**Mooziac** is an ultra-lightweight, native macOS **menu bar music player** for YouTube Music, written in Swift 5.9 + AppKit. It provides:

- A **Dynamic Island–style floating player** (glassmorphic "pill" UI) with waveform seeking, reactive buttons, and album-art-reactive theming.
- **Online playback** via an embedded `WKWebView` running YouTube Music with ad/telemetry filtering and bidirectional JavaScript observation.
- **Offline playback** via a native `AVPlayer` engine for local audio files (`~/Music/Mooziac`, `~/Library/Application Support/Mooziac/Offline`).
- **Trackpad gestures** (right-edge volume swipe, corner tap shortcuts) using the private Multitouch framework.
- **Real-time synced lyrics** in a menu-bar-centered HUD.
- **Auto-pause on screen lock / sleep / headphone disconnect**, session restoration, Discord Rich Presence, native notifications, liked-songs sync, downloads (via `yt-dlp` + `ffmpeg`), playlists, and a full offline library.
- **Privacy-first posture**: no listening-history telemetry, no analytics, credentials remain in system web storage.

**Target:** macOS 13.0+ (Ventura/Sonoma/Sequoia). **License:** MIT. **Version:** 1.0.0.

---

## 2. Where Each Subsystem Lives

| Subsystem | Directory | Blueprint docs |
| :--- | :--- | :--- |
| App lifecycle & entry | `Sources/Mooziac/App/` | `03_ARCHITECTURE/APPLICATION_LAYERS.md`, `13_WORKFLOWS/APP_STARTUP.md`, `APP_SHUTDOWN.md` |
| Central controllers & state | `Sources/Mooziac/Core/` | `03_ARCHITECTURE/*`, `08_DATA/STATE_MANAGEMENT.md` |
| Service singletons | `Sources/Mooziac/Managers/` | `08_DATA/*`, `09_NETWORK/*`, `07_LYRICS/*` |
| Data models / enums | `Sources/Mooziac/Models/` | `08_DATA/DATA_MODELS.md` |
| Audio engines | `Sources/Mooziac/Audio/` | `06_AUDIO/*` |
| User interface | `Sources/Mooziac/Views/` | `05_UI/*` |
| WebKit integration | `Sources/Mooziac/Web/` | `09_NETWORK/*`, `06_AUDIO/MEDIA_CONTROLS.md` |
| Trackpad / hotkeys | `Sources/Mooziac/Input/` | `10_BACKGROUND_SYSTEMS/*` |
| Shared extensions | `Sources/Mooziac/Support/` | `02_CODEBASE/FILE_CATALOG.md` |

---

## 3. Blueprint Map — Where to Find Each Kind of Documentation

### Feature → Module → File → Class → Function
1. **Start with a feature** → `13_WORKFLOWS/` (playback, search, download, lyrics, settings, startup, shutdown).
2. **Find the owning module** → `03_ARCHITECTURE/MODULE_ARCHITECTURE.md`.
3. **Locate the file** → `02_CODEBASE/SOURCE_FILE_MAP.md` or `FILE_CATALOG.md`.
4. **Read the class** → `04_FUNCTIONS/CLASS_REFERENCE.md`.
5. **Read the function/method** → `04_FUNCTIONS/FUNCTION_REFERENCE.md` (and `METHOD_REFERENCE.md`, `CALLBACK_REFERENCE.md`).
6. **Exhaustive per-file detail** → `99_APPENDIX/RAW_DISCOVERY_NOTES/` (6 work-package docs).

### Caller / Dependency / Data flow
- **Dependency graph** → `03_ARCHITECTURE/DEPENDENCY_GRAPH.md`.
- **Data flow** → `03_ARCHITECTURE/DATA_FLOW.md`, `14_DIAGRAMS/DATA_FLOW.md`.
- **Event flow** → `03_ARCHITECTURE/EVENT_FLOW.md`, `10_BACKGROUND_SYSTEMS/OBSERVERS.md`, `EVENT_LISTENERS.md`.

### Directory-by-directory
| Blueprint folder | Contents |
| :--- | :--- |
| `00_INDEX` | Master index, documentation status, coverage checklist |
| `01_PROJECT_OVERVIEW` | Overview, purpose/goals, roadmap, tech stack, project history |
| `02_CODEBASE` | Complete file tree, file catalog, source file map, asset map |
| `03_ARCHITECTURE` | System architecture, layers, modules, data flow, event flow, dependency graph |
| `04_FUNCTIONS` | Function/class/method/callback reference & index |
| `05_UI` | UI architecture, windows, views, components, menus, settings, UI state flow |
| `06_AUDIO` | Audio architecture, playback pipeline, now playing, queue, media controls |
| `07_LYRICS` | Lyrics architecture, pipeline, providers, cache, sync |
| `08_DATA` | Data models, storage, cache, database, state management |
| `09_NETWORK` | API catalog, network flow, external services, request pipelines, error handling |
| `10_BACKGROUND_SYSTEMS` | Background tasks, observers, event listeners, timers, system integrations |
| `11_CONFIGURATION` | Config files, environment, build configuration, dependencies |
| `12_SECURITY` | Security architecture, key storage, permissions, privacy |
| `13_WORKFLOWS` | End-to-end workflows |
| `14_DIAGRAMS` | ASCII diagrams for architecture/data/event/component relationships |
| `15_ISSUES_AND_RISKS` | Known issues, technical debt, potential bugs, risk areas |
| `99_APPENDIX` | Glossary, terminology, raw discovery notes (full per-file/per-function detail) |

---

## 4. Critical Architecture Facts (in one paragraph each)

- **Two playback engines** coordinate through `NowPlayingManager.shared.engineMode` (`.online` WebKit / `.offline` AVPlayer). State snapshots (`PlaybackState`) fan out to UI, system Now Playing, Discord RPC, lyrics HUD, and notifications via an observer list.
- **A single status item** (`StatusItemManager`) owns the menu-bar icon, the `StatusItemPanel`, and the context menu; it can be "docked" in the menu bar or dragged out into a floating window.
- **The JS bridge** (`ObserverBridge`) injects a `window.ytmObserver` script into YTM; every `nowPlayingHandler` message carries the current track snapshot. **All YouTube DOM selectors are third-party and brittle.**
- **SQLite is the source of truth** for local library/playlists/history/likes (`LocalDatabaseManager`, schema v4, 5 tables).
- **Downloads** shell out to `yt-dlp` + `ffmpeg` processes with `player_client=mweb,web_safari,tv_embedded,web`; sandboxed job directories; progress streamed via stdout parser.
- **Lyrics** come from LRCLib (`lrclib.net`) with Lyrics.ovh fallback; parsed `.lrc` (`[mm:ss.xx]`) cached on disk; time-driven line highlighting.
- **Startup sequence**: `main.swift` → `AppDelegate.applicationDidFinishLaunching` → accessory activation → legacy-key purge → sleep prevention → EdgeVolumeEngine → AudioRouteMonitor → NetworkMonitor → Discord RPC → StatusItemManager → launch animation.

---

## 5. Critical Execution Paths

| Path | Entry | Follow |
| :--- | :--- | :--- |
| App startup | `main.swift` → `AppDelegate` | `13_WORKFLOWS/APP_STARTUP.md` |
| Online playback | Button tap → `PlayerControls` → `ObserverBridge` JS → YTM | `13_WORKFLOWS/PLAYBACK_WORKFLOW.md` |
| Offline playback | `NativeAudioPlayer.play(track:in:)` | `06_AUDIO/PLAYBACK_PIPELINE.md` |
| Search | `MainViewController.dynamicIslandDidSearch` | `13_WORKFLOWS/SEARCH_WORKFLOW.md` |
| Download | `DownloadManager.queueTrack/queueTracks` | `13_WORKFLOWS/DOWNLOAD_WORKFLOW.md` |
| Lyrics | `LyricsManager.fetchLyrics` → LRCLib → cache → HUD | `13_WORKFLOWS/LYRICS_WORKFLOW.md` |
| Media keys | `MPRemoteCommandCenter` → `ObserverBridge` | `06_AUDIO/MEDIA_CONTROLS.md` |
| Gestures | Multitouch → `EdgeVolumeEngine` / `GestureMappingManager` | `10_BACKGROUND_SYSTEMS/SYSTEM_INTEGRATIONS.md` |

---

## 6. Scale of the Codebase (verified)

- **60 Swift source files**, ~23,600 lines of Swift.
- **95 top-level types** (classes/structs/enums/protocols), **673 function/method declarations**.
- **38 distinct `UserDefaults` keys** prefixed `YTM_`/`Mooziac_`.
- **18 notification names** (default center + distributed).
- **5 SQLite tables**, 41 SQL statements.
- **8 remote HTTP services / endpoints**, 1 local IPC (Discord), 2 external processes (`yt-dlp`, `ffmpeg`).

---

## 7. How to Navigate

1. **New developer onboarding**: read `01_PROJECT_OVERVIEW/PROJECT_OVERVIEW.md` → `03_ARCHITECTURE/SYSTEM_ARCHITECTURE.md` → `13_WORKFLOWS/APP_STARTUP.md` → `06_AUDIO/PLAYBACK_PIPELINE.md`.
2. **Debug a bug in a specific screen**: `05_UI/UI_STATE_FLOW.md` → the view's class in `04_FUNCTIONS/CLASS_REFERENCE.md` → raw note in `99_APPENDIX/RAW_DISCOVERY_NOTES/05_PLAYER_WINDOWS_UI.md` (or `06_LIBRARIES_COMPONENTS_UI.md`).
3. **Modify a manager**: `08_DATA/` + `09_NETWORK/` + raw note `99_APPENDIX/RAW_DISCOVERY_NOTES/03_DATA_MANAGERS.md`.
4. **Find a function**: `04_FUNCTIONS/FUNCTION_INDEX.md`.
5. **Check what could break**: `15_ISSUES_AND_RISKS/`.

---

## 8. Legend for Confidence Markers

Throughout the blueprint the following markers are used (per the archivist rules):

- **CONFIRMED FROM SOURCE** — directly verified in the implementation.
- **INFERRED FROM SOURCE** — implied by the code but not confirmed at runtime.
- **UNKNOWN — requires runtime verification** — cannot be determined statically.