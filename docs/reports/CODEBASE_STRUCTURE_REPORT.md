# Mooziac — Codebase Structure & Organization Report

> **Status:** Planning only — no code was changed to produce this report.
> **Goal:** Turn the current flat `Sources/Mooziac/` directory into a professional, folder-organized repo like a well-maintained open-source GitHub project, without breaking the build.

---

## 1. Executive Summary

Mooziac is a Swift Package Manager (SPM) **single-target** executable macOS app (`Sources/Mooziac`, ~20,000 LOC across **44 Swift files + 3 subfolders**). The code is functionally rich and already shows a good instinct for grouping (extensions of `NowPlayingManager`, `StatusItemManager`, and `DynamicIslandPlayerView` already live in matching subfolders).

**The three biggest problems today:**

1. **Flat namespace** — 40+ files piled into one directory mixes views, managers, models, parsers, engines, and input handlers. Nothing is discoverable.
2. **Repo-root clutter** — 30+ dev artifacts (reports, screenshots, `.py` monitors, `.log`, `.txt`, `.json`, `.html`) sit at the repo root and are committed to git.
3. **Git hygiene** — `.build/` and `.DS_Store` are tracked in git. These should never be in version control.

**What we recommend (summary):**

| Area | Recommendation |
| :--- | :--- |
| Swift source | Group into feature folders: `App/`, `Core/`, `Managers/`, `Audio/`, `Models/`, `Views/`, `Controllers/`, `Web/`, `Input/`, `Support/` |
| Root | Keep only `Package.swift`, `README.md`, `LICENSE`, `build_app.sh`, `.gitignore`, `Sources/`, `Resources/`, and `docs/` |
| Dev artifacts | Move scripts/screenshots/logs to `dev/` (git-ignored) and reports to `docs/` |
| Git | Stop tracking `.build/` and `.DS_Store` |

This is a **zero-behavior-change refactor**. SPM automatically compiles all Swift files recursively under the target path, so moving files into subfolders does **not** require any change to `Package.swift`.

---

## 2. Current State Analysis

### 2.1 The Swift source (`Sources/Mooziac/`)

Current inventory (sorted by size):

```
2682  PlaylistLibraryView.swift            # Playlist browsing UI + logic
1494  DynamicIslandPlayerView/SettingsPanel.swift
1174  DynamicIsPlayerView/Core.swift       # main player view (class DynamicIslandPlayerView)
1067  LocalDatabaseManager.swift           # SQLite layer
1013  DownloadManager.swift                # downloads + progress
 941  OfflineLibraryView.swift             # local files UI
 770  PlaylistManager.swift                # playlist CRUD + persistence
 644  SwipeToDeleteContainerView.swift     # reusable swipe container
 635  NowPlayingManager/Queue.swift        # ext NowPlayingManager (queue)
 601  YTMWebView.swift                     # WKWebView wrapper + JS bridge
 567  NowPlayingManager/PlayerControls.swift
 529  MainViewController.swift             # main container VC
 520  EdgeVolumeEngine.swift               # trackpad edge volume engine
 507  LyricsManager.swift
 482  StatusItemManager.swift              # menu bar status item
 467  LocalLibraryManager.swift            # filesystem scanning
 456  NowPlayingManager/ObserverBridge.swift
 442  NativeAudioPlayer.swift              # AVPlayer offline playback
 412  DiscordRPCManager.swift              # Discord rich presence
 356  WaveformProgressView.swift           # seekable waveform
 310  LiquidGlassSegmentedSlider.swift     # custom control
 298  NowPlayingManager.swift              # core playback state + Web bridge
 282  CenteredMenuBarLyricsWindowController.swift
 277  AppArtworkHelper.swift               # artwork color extraction
 256  ReactiveIconButton.swift             # base animated button
 237  GlassSearchField.swift               # custom NSSearchField
 207  DynamicIslandPlayerView/ArtworkTheme.swift
 178  StatusItemManager/ContextMenu.swift
 176  HistoryManager.swift                 # recently played
 173  LaunchAnimationController.swift
 171  CircularProgressDownloadButton.swift
 155  SyncedLyricsParser.swift             # LRC parser (pure Swift)
 152  LaunchOverlayView.swift
 130  GestureMappingManager.swift          # gesture→action mapping
 126  AudioRouteMonitor.swift              # device/lock monitoring
 122  HeaderView.swift
 117  OfflineOverlayView.swift
 101  AppVolumeManager.swift
  92  DisplayManager.swift
  90  TrackNotificationManager.swift
  88  NetworkMonitor.swift
  85  NativeGestureTutorialWindowController.swift
  75  LocalTrack.swift                     # offline track model
  70  AppDelegate.swift
  69  NativeCapsuleToggleView.swift
  62  KeyboardCommandHandler.swift
  54  GlobalHotKeyManager.swift
  54  BackgroundMediaController.swift      # prevent sleep
  45  AudioVisualizerView.swift
  34  URLFilter.swift                      # URL sanitization
  29  StatusItemPanel.swift                # NSPanel subclass
  27  LaunchAnimationTimeline.swift
  14  ClickSound.swift
   7  main.swift                           # entry point
```

### 2.2 The pattern already in place (good — keep it)

Some files already use a **`ClassName.swift` + `ClassName/` folder for extensions** convention:

```
NowPlayingManager.swift            (class NowPlayingManager)
NowPlayingManager/
  ├─ ObserverBridge.swift          (extension NowPlayingManager)
  ├─ PlayerControls.swift          (extension NowPlayingManager)
  └─ Queue.swift                   (extension NowPlayingManager)

StatusItemManager.swift            (class StatusItemManager)
StatusItemManager/
  └─ ContextMenu.swift             (extension StatusItemManager)

DynamicIslandPlayerView/
  ├─ Core.swift                    (class DynamicIslandPlayerView)
  ├─ SettingsPanel.swift
  └─ ArtworkTheme.swift
```

**This is a great convention to formalize and extend to the rest of the codebase.**

### 2.3 Repo root clutter (dev artifacts, not shipped code)

| File | Category | Recommendation |
| :--- | :--- | :--- |
| `BLACKBOOK.txt`, `todolist.txt` | personal notes | `docs/notes/` (or delete) |
| `*.md` reports (Playbackreport, PLAYLIST_ARCHITECTURE_REPORT, QUEUE_BLUEPRINT, CODING_AGENT_FIX_REPORT, AUDIO_ONLY…_DIAGNOSTIC) | reports | `docs/reports/` |
| `report.txt`, `latestreport.txt`, `codebase_efficiency_technical_debt_audit.txt` | reports | `docs/reports/` |
| `PROJECT_CHANGES_LOG.md` | changelog | `CHANGELOG.md` (root, standard convention) |
| `tree.c`, `tree.py`, `tree.txt`, `inspect_app_resources.py`, `update_diagnostics.py`, `monitor_*.py`, `monitor_gpu_spikes.sh` | dev/monitoring scripts | `dev/` (git-ignored) |
| `*.png`, `*.jpg` (image, launch, menubar, macbook_panel, MOOZIAC) | screenshots | `dev/screenshots/` (git-ignored) |
| `click_events.log`, `diagnostics_data.json`, `trackmetadata.json`, `mooziac_realtime_diagnostics.html` | runtime dumps | `dev/` (git-ignored) |
| `trackpad.html`, `trackpad_visualizer.html` | shipped HTML assets | `Resources/` |
| `.DS_Store` | OS cruft | delete + gitignore |

---

## 3. Problems & Gaps (what a "professional repo" reviewer would flag)

1. **No folder hierarchy** for 40+ Swift files — impossible to navigate, no ownership boundaries.
2. **`.build/` is tracked in git** — 100s of stale binary diffs pollute every commit. Must be `git rm -r --cached .build`.
3. **`.DS_Store` committed** (root + `Sources/`) — should be removed and ignored.
4. **No `LICENSE` file** — README claims MIT but the file doesn't exist.
5. **README is out of date** — documents files (`DynamicIslandPlayerView.swift`, `SpotifyPlayerView.swift`) that no longer exist and the old `YTMMenuBar` folder name.
6. **Mixed naming styles** — some types `public`, some internal; some files plural folder matching already, some not.
7. **No tests** — zero test target in `Package.swift`. For a "professional repo", a `Tests/` target is expected.
8. **Two overlapping concepts in `NowPlayingManager.swift` (root)** — the file mixes the `class` with plain **models** (`PlaybackState`, `RepeatMode`, `PlaybackEngineMode`) that should live in `Models/`.
9. **Giant files** — `PlaylistLibraryView.swift` (2,682 LOC), `SettingsPanel.swift` (1,494 LOC), `LocalDatabaseManager.swift` (1,067 LOC), `DownloadManager.swift` (1,013 LOC). These need internal splitting eventually (Phase 3).
10. **No `AGENTS.md` / contributor docs / `CONTRIBUTING.md` / CI** — a professional repo should document how to build, lint, test.

---

## 4. Target Directory Structure

### 4.1 Repo root (proposed)

```
mp3kal/
├── Package.swift                     # SPM manifest (unchanged)
├── README.md                         # update file-map section to match reality
├── LICENSE                           # ADD: MIT license text
├── CHANGELOG.md                      # MOVE from PROJECT_CHANGES_LOG.md
├── CONTRIBUTING.md                   # optional: how to build/run/contribute
├── AGENTS.md                         # optional: instructions for AI agents
├── .gitignore                        # improve (see §7)
├── build_app.sh                      # keep
├── Sources/
├── Resources/                        # icons, artwork, HTML assets
├── Tests/                            # Phase 3: add test target
└── docs/
    ├── reports/                      # all existing *Report.md / report.txt files
    └── notes/                        # BLACKBOOK.txt, todolist.txt (or delete)
```

> `dev/` (git-ignored) holds all the personal scripts, screenshots, logs, and dumps — they have value but belong out of the published repo.

### 4.2 Swift source (`Sources/Mooziac/` — proposed)

```
Sources/Mooziac/
├── App/                              # application lifecycle & entry
│   ├── main.swift
│   ├── AppDelegate.swift
│   └── BackgroundMediaController.swift     # sleep prevention service
│
├── Core/                             # the app's central controllers/state
│   ├── MainViewController.swift
│   ├── StatusItemManager/
│   │   ├── StatusItemManager.swift
│   │   ├── ContextMenu.swift
│   │   └── StatusItemPanel.swift
│   ├── NowPlayingManager/
│   │   ├── NowPlayingManager.swift   # (moved from root) class + core bridge
│   │   ├── PlayerControls.swift
│   │   ├── Queue.swift
│   │   └── ObserverBridge.swift
│   └── DisplayManager.swift          # display/window coordination
│
├── Models/                           # pure data types — no UI
│   ├── LocalTrack.swift
│   ├── PlaybackState.swift           # extracted from NowPlayingManager.swift
│   ├── RepeatMode.swift              # extracted enum
│   ├── PlaybackEngineMode.swift      # extracted enum
│   ├── GestureMappingModels.swift    # GestureType, GestureAction (from GestureMappingManager)
│   ├── PlayerDesign.swift            # PlayerDesign, AppTheme (from AudioVisualizerView)
│   ├── ProgressStyle.swift           # from WaveformProgressView
│   └── LaunchAnimationTimeline.swift
│
├── Managers/                        # service singletons & business logic
│   ├── LocalDatabaseManager.swift
│   ├── LocalLibraryManager.swift
│   ├── DownloadManager.swift
│   ├── PlaylistManager.swift
│   ├── HistoryManager.swift
│   ├── LyricsManager.swift
│   ├── DiscordRPCManager.swift
│   ├── TrackNotificationManager.swift
│   ├── NetworkMonitor.swift
│   ├── AppArtworkHelper.swift
│   └── SyncedLyricsParser.swift
│
├── Audio/                           # audio engine & playback
│   ├── NativeAudioPlayer.swift
│   ├── EdgeVolumeEngine.swift
│   ├── AudioRouteMonitor.swift
│   ├── AppVolumeManager.swift
│   └── ClickSound.swift
│
├── Views/
│   ├── Player/                      # the Dynamic Island player
│   │   └── DynamicIslandPlayerView/
│   │       ├── Core.swift
│   │       ├── SettingsPanel.swift
│   │       └── ArtworkTheme.swift
│   │
│   ├── Libraries/                   # library/list UIs
│   │   ├── OfflineLibraryView.swift
│   │   ├── OfflineOverlayView.swift
│   │   ├── PlaylistLibraryView.swift
│   │   └── SwipeToDeleteContainerView.swift
│   │
│   ├── Components/                  # reusable custom controls
│   │   ├── GlassSearchField.swift
│   │   ├── HeaderView.swift
│   │   ├── ReactiveIconButton.swift
│   │   ├── CircularProgressDownloadButton.swift
│   │   ├── NativeCapsuleToggleView.swift
│   │   ├── LiquidGlassSegmentedSlider.swift
│   │   ├── WaveformProgressView.swift
│   │   └── AudioVisualizerView.swift
│   │
│   └── Windows/                     # window controllers & overlay HUDs
│       ├── CenteredMenuBarLyricsWindowController.swift
│       ├── NativeGestureTutorialWindowController.swift
│       ├── LaunchOverlayView.swift
│       └── LaunchAnimationController.swift
│
├── Web/                             # WebKit integration & URL handling
│   ├── YTMWebView.swift
│   └── URLFilter.swift
│
├── Input/                           # gestures, hotkeys, keyboard
│   ├── GestureMappingManager.swift
│   ├── GlobalHotKeyManager.swift
│   └── KeyboardCommandHandler.swift
│
└── Support/                         # cross-cutting helpers & extensions
    ├── AppExtensions.swift          # NSImage etc. (from DynamicIslandPlayerView/Core ext)
    └── NSView+Helpers.swift         # as needed
```

**Design rules this structure encodes:**
- `App/` — things that run at startup, nothing reusable.
- `Core/` — the skeleton everything else talks to (player, menu bar item, main VC).
- `Models/` — **no** AppKit/UI imports allowed. Pure data + Codable. Easiest to unit-test.
- `Managers/` — stateless-to-`shared` singletons providing services (DB, downloads, lyrics, RPC).
- `Audio/` — anything touching `AVFoundation`/`CoreAudio` that *isn't* a view.
- `Views/` — every `NSView`/`NSViewController`. Nested by feature, then reusable components.
- `Web/` — anything WebKit. If a view owns the webview, the view wins and Web/ only holds web plumbing.
- `Input/` — input hardware integration (trackpad gestures, global hotkeys).
- `Support/` — extensions/helpers with no home.

---

## 5. File → Folder Mapping (exact move list)

### Phase 1 moves (pure reorganization, no code edits)

| Current path | Target path |
| :--- | :--- |
| `main.swift` | `App/main.swift` |
| `AppDelegate.swift` | `App/AppDelegate.swift` |
| `BackgroundMediaController.swift` | `App/BackgroundMediaController.swift` |
| `MainViewController.swift` | `Core/MainViewController.swift` |
| `StatusItemManager.swift` | `Core/StatusItemManager/StatusItemManager.swift` |
| `StatusItemPanel.swift` | `Core/StatusItemManager/StatusItemPanel.swift` |
| `StatusItemManager/ContextMenu.swift` | `Core/StatusItemManager/ContextMenu.swift` |
| `NowPlayingManager.swift` | `Core/NowPlayingManager/NowPlayingManager.swift` |
| `NowPlayingManager/*.swift` | `Core/NowPlayingManager/*.swift` |
| `DisplayManager.swift` | `Core/DisplayManager.swift` |
| `LocalTrack.swift` | `Models/LocalTrack.swift` |
| `LaunchAnimationTimeline.swift` | `Models/LaunchAnimationTimeline.swift` |
| `LocalDatabaseManager.swift` | `Managers/LocalDatabaseManager.swift` |
| `LocalLibraryManager.swift` | `Managers/LocalLibraryManager.swift` |
| `DownloadManager.swift` | `Managers/DownloadManager.swift` |
| `PlaylistManager.swift` | `Managers/PlaylistManager.swift` |
| `HistoryManager.swift` | `Managers/HistoryManager.swift` |
| `LyricsManager.swift` | `Managers/LyricsManager.swift` |
| `DiscordRPCManager.swift` | `Managers/DiscordRPCManager.swift` |
| `TrackNotificationManager.swift` | `Managers/TrackNotificationManager.swift` |
| `NetworkMonitor.swift` | `Managers/NetworkMonitor.swift` |
| `AppArtworkHelper.swift` | `Managers/AppArtworkHelper.swift` |
| `SyncedLyricsParser.swift` | `Managers/SyncedLyricsParser.swift` |
| `NativeAudioPlayer.swift` | `Audio/NativeAudioPlayer.swift` |
| `EdgeVolumeEngine.swift` | `Audio/EdgeVolumeEngine.swift` |
| `AudioRouteMonitor.swift` | `Audio/AudioRouteMonitor.swift` |
| `AppVolumeManager.swift` | `Audio/AppVolumeManager.swift` |
| `ClickSound.swift` | `Audio/ClickSound.swift` |
| `DynamicIslandPlayerView/` | `Views/Player/DynamicIslandPlayerView/` |
| `OfflineLibraryView.swift` | `Views/Libraries/OfflineLibraryView.swift` |
| `OfflineOverlayView.swift` | `Views/Libraries/OfflineOverlayView.swift` |
| `PlaylistLibraryView.swift` | `Views/Libraries/PlaylistLibraryView.swift` |
| `SwipeToDeleteContainerView.swift` | `Views/Libraries/SwipeToDeleteContainerView.swift` |
| `GlassSearchField.swift` | `Views/Components/GlassSearchField.swift` |
| `HeaderView.swift` | `Views/Components/HeaderView.swift` |
| `ReactiveIconButton.swift` | `Views/Components/ReactiveIconButton.swift` |
| `CircularProgressDownloadButton.swift` | `Views/Components/CircularProgressDownloadButton.swift` |
| `NativeCapsuleToggleView.swift` | `Views/Components/NativeCapsuleToggleView.swift` |
| `LiquidGlassSegmentedSlider.swift` | `Views/Components/LiquidGlassSegmentedSlider.swift` |
| `WaveformProgressView.swift` | `Views/Components/WaveformProgressView.swift` |
| `AudioVisualizerView.swift` | `Views/Components/AudioVisualizerView.swift` |
| `CenteredMenuBarLyricsWindowController.swift` | `Views/Windows/CenteredMenuBarLyricsWindowController.swift` |
| `NativeGestureTutorialWindowController.swift` | `Views/Windows/NativeGestureTutorialWindowController.swift` |
| `LaunchOverlayView.swift` | `Views/Windows/LaunchOverlayView.swift` |
| `LaunchAnimationController.swift` | `Views/Windows/LaunchAnimationController.swift` |
| `YTMWebView.swift` | `Web/YTMWebView.swift` |
| `URLFilter.swift` | `Web/URLFilter.swift` |
| `GestureMappingManager.swift` | `Input/GestureMappingManager.swift` |
| `GlobalHotKeyManager.swift` | `Input/GlobalHotKeyManager.swift` |
| `KeyboardCommandHandler.swift` | `Input/KeyboardCommandHandler.swift` |

**Result of Phase 1:** No Swift code changed, no `Package.swift` change. Verify with `swift build`.

### Phase 2 (extract pure models — small code moves, still zero behavior change)

- Pull `PlaybackState`, `RepeatMode`, `PlaybackEngineMode` out of `NowPlayingManager.swift` into `Models/` (they're used across the app already; `public` visibility makes this safe).
- Pull `GestureType`/`GestureAction` out of `GestureMappingManager.swift` into `Models/`.
- Pull `PlayerDesign`/`AppTheme` out of `AudioVisualizerView.swift` into `Models/`.
- Pull `ProgressStyle` out of `WaveformProgressView.swift` into `Models/`.
- Move the `NSImage` extension from `DynamicIslandPlayerView/Core.swift` into `Support/AppExtensions.swift`.

### Phase 3 (optional, bigger)

- Split giants: `PlaylistLibraryView.swift` → view + table datasource + row cell; `LocalDatabaseManager.swift` → schema + queries + migrations; `DownloadManager.swift` → session + progress + task store.
- Add a `Tests/` target in `Package.swift`; write unit tests against `Models/`, `SyncedLyricsParser`, `URLFilter`, `HistoryManager`, and the database layer (pure logic — no UI).
- Optionally split into **multiple SPM modules** (`MooziacCore` library + `MooziacApp` executable). This is the "next level" professional move: it enforces the `Models` has no AppKit rule at the compiler level. Only do this after Phase 1 & 2.

---

## 6. Coding Conventions to Standardize

1. **Folder naming:** `PascalCase` for folders containing types (matches `ClassName/` extension convention).
2. **File naming:** one file per primary type; extensions in `TypeName/` folder.
3. **Access control:** be deliberate — `internal` by default, `public` only where actually shared (many files are already `public`; tighten as part of Phase 3 multi-module).
4. **Imports:** keep minimal; `Models/` files should import only `Foundation`.
5. **No dead code:** `MooziacWebView`, `BeatGlowEngine`, `RealAudioAnalyzer`, `SettingsWindowController`, `SpotlightSearchWindowController`, `FloatingSearchOverlayView`, `DancingCatView`, `DynamicIslandPlayerView.swift`, `MiniPlayerView.swift`, `SpotifyPlayerView.swift`, `SearchSuggestionManager.swift` were **deleted** from the working tree but still appear in `.build` module cache history. Phase 1 cleanup will drop them automatically with a clean build.
6. **Mutations go through `MainActor`/main queue:** several managers touch `NSApp`/UI from async contexts — consistent `@MainActor` annotations are a good follow-up.

---

## 7. Git Hygiene Plan

```bash
# 1. Stop tracking build artifacts (keep local files)
git rm -r --cached .build
echo ".build/" >> .gitignore          # already present, keep it

# 2. Stop tracking OS cruft
git rm -r --cached .DS_Store Sources/.DS_Store
echo ".DS_Store" >> .gitignore        # already present, keep it

# 3. Commit the reorganization as logical commits:
#    a) chore: remove .build and .DS_Store from tracking
#    b) chore: add LICENSE, CHANGELOG.md, update .gitignore (dev/, docs/helpers)
#    c) refactor: move sources into feature folders (single commit, no code edits)
#    d) docs: update README file-map section
```

**.gitignore additions:**

```
# build + OS cruft
.build/
.DS_Store

# local dev tooling (never published)
dev/

# secrets (already present)
client_secret*.json
*.secret.json
credentials.json
```

---

## 8. Documentation Strategy

- **`README.md`** — update the "Project Architecture & File Sitemap" section to the real tree. Keep it as the single public entry point.
- **`CHANGELOG.md`** — adopt Keep-a-Changelog format, seeded from `PROJECT_CHANGES_LOG.md`.
- **`LICENSE`** — add the actual MIT text (badge already claims it).
- **`AGENTS.md`** *(recommended)* — one short file telling future coding agents: build command (`swift build`), how folders are organized, the "Models have no AppKit" rule. This directly helps any AI tool (including this one) work in the repo correctly.
- **`docs/reports/`** — archive all past investigation/audit reports; they document *why* decisions were made and are worth keeping out of the root.

---

## 9. Recommended Execution Order

1. **§7 Git hygiene** — fix `.gitignore`, untrack `.build/`/`.DS_Store`. (5 min, big payoff.)
2. **§4.1 root cleanup** — add `LICENSE`, move reports → `docs/reports/`, scripts/screenshots → `dev/` (ignored), `trackpad*.html` → `Resources/`.
3. **§4.2 + §5 Phase 1** — execute the file-move table verbatim; run `swift build` to verify.
4. **§5 Phase 2** — extract `Models/`; run `swift build` again.
5. **Docs** — update README file-map, add `AGENTS.md`, seed `CHANGELOG.md`.
6. **Phase 3 (later)** — split giant files, add `Tests/` target, consider multi-module split.

Every step is independently verifiable with `swift build` and reversible — this is a low-risk, high-visibility improvement.

---

## 10. Risks & Notes

- **SPM globbing:** files under the target's `path` are compiled recursively, so subfolders are safe. Confirmed — no `Package.swift` change needed for Phase 1.
- **`public` visibility is your friend here:** because the code already uses `public` on most types, moving files between folders cannot break cross-file visibility within the module.
- **Do not rename types during the move.** Phase 1 must be pure `git mv`; type renames belong in separate later commits to keep history clean.
- **The `.build` dir being tracked means your working tree is already dirty.** Cleaning it is safe and will *not* break local builds (SPM regenerates it).
- The app is **apparently not in a finished published state** (various `.md` reports describe bugs and rework). Reorganization should be done on `main` before any future feature work to avoid reorganizing mid-feature.

---

## 11. Build & Connectivity Audit (verified — nothing is broken today)

These checks were actually **run**, not assumed:

| Check | Result |
| :--- | :--- |
| `swift build` (debug) | ✅ Build complete |
| `swift build -c release` | ✅ Build complete |
| Duplicate type definitions | ✅ None — every top-level type has exactly one definition |
| Orphan types (defined, never referenced) | ⚠️ Exactly **1**: `AppTheme` |
| Dangling refs to previously deleted files (`MooziacWebView`, `DancingCatView`, `SpotifyPlayerView`, etc.) | ✅ Zero in `Sources/` (only harmless comments mention `HaptiTrack`) |
| `TODO`/`FIXME`/`HACK` markers | ✅ Zero |

**Connectivity map:** 43 of 48 top-level types are referenced from **2+ files** — the app is genuinely wired together: `NowPlayingManager` (21 files), `StatusItemManager` (12), `NetworkMonitor` (12), `LocalTrack` (12), `NativeAudioPlayer` (11), `CenteredMenuBarLyricsWindowController` (11), `PlayerDesign` (10), `PlaylistManager` (8), `DynamicIslandPlayerView` (8). The remaining single-file types (`QueueTask`, `DownloadStatus`, `PlaylistPlayResult`, `ConnectionType`, etc.) are **internal models used within their own file** — not junk, keep them.

### 11.1 Verified junk — safe to remove (nothing references it)

| Item | Evidence |
| :--- | :--- |
| **`AppTheme` enum** in `AudioVisualizerView.swift` | Zero references in the entire `Sources/` tree |
| **`trackpad_visualizer.html`** (root) | Zero references in Swift or `build_app.sh` |
| **Root `MOOZIAC.png`** | MD5 `7f04ad62…` = byte-identical to `Resources/MOOZIAC.png`. The `Resources/` copy is already the one the build script ships |
| **3,502 tracked files under `.build/`** | Every `git status` shows hundreds of stale binary diffs. Delete from index only (`git rm -r --cached`) |
| **`.DS_Store`** (root + `Sources/`) | OS cruft, tracked today |
| Root dev scripts/screenshots/logs (`monitor_*.py`, `inspect_app_resources.py`, `update_diagnostics.py`, `image.png`, `launch.png`, `menubar.png`, `click_events.log`, `diagnostics_data.json`, `trackmetadata.json`, `mooziac_realtime_diagnostics.html`) | Nothing in `Sources/` or `build_app.sh` loads them |

### 11.2 Misleading file name

`AudioVisualizerView.swift` (45 lines) contains **no view** — only the `PlayerDesign` and `AppTheme` enums. When restructuring, it becomes `Models/PlayerDesign.swift` and the dead `AppTheme` enum is deleted.

### 11.3 Runtime resource pipeline (the one place reorganization can break things)

The app loads these assets at runtime via `Bundle.main`:

| Asset | Loaded by | Current home |
| :--- | :--- | :--- |
| `launch_transparent.png` | `LaunchOverlayView.swift` | `Resources/` ✅ |
| `MenuBarIcon.png` | `StatusItemManager.swift` | `Resources/` ✅ |
| `MOOZIAC_transparent.png` | `StatusItemManager.swift`, `AppArtworkHelper.swift` | `Resources/` ✅ |
| `MOOZIAC.png` | `LaunchOverlayView.swift` (fallback) | `Resources/` ✅ (root copy is a duplicate) |
| `trackpad.html` | `NativeGestureTutorialWindowController.swift` | **repo root** ⚠️ |
| `macbook_panel.jpg` | loaded **by `trackpad.html`** | **repo root** ⚠️ |

SPM declares **no** `resources:` in `Package.swift`; `build_app.sh` hand-assembles the bundle and copies from a mix of `Resources/` and the repo root. This is fragile. **The fix:** move `trackpad.html` + `macbook_panel.jpg` into `Resources/` *together* (they are a coupled pair — the HTML loads the JPG), and update the two `cp` lines in `build_app.sh` to copy them from `Resources/`. That is the **only** copy-path change required by the whole reorganization.

---

## 12. Final-Product Pipeline (execute so nothing breaks, junk is removed, everything connects)

The goal: an end state where **build → bundle → sign → launch** is a clean, single, verified pipeline and the repo looks like a shipped product.

### Phase 0 — Baseline (5 min)
```bash
swift build && swift build -c release      # both PASS today — proven above
git status                                  # record the dirty baseline
```

### Phase 1 — Git hygiene (10 min)
```bash
git rm -r --cached .build                   # stop tracking build artifacts
git rm --cached .DS_Store Sources/.DS_Store
# .gitignore additions:
#   .build/
#   .DS_Store
#   dev/
git commit -m "chore: stop tracking build artifacts and OS cruft"
```

### Phase 2 — Junk removal + resource pipeline (20 min)
1. `git mv trackpad.html Resources/trackpad.html`
2. `git mv macbook_panel.jpg Resources/macbook_panel.jpg`
3. `git rm --cached MOOZIAC.png` + `rm MOOZIAC.png` (byte-identical duplicate)
4. `rm trackpad_visualizer.html` (unused prototype)
5. Edit `build_app.sh`:
   - change `if [ -f "trackpad.html" ]` → `if [ -f "Resources/trackpad.html" ]` (copy `Resources/trackpad.html`)
   - change `if [ -f "macbook_panel.jpg" ]` → copy from `Resources/macbook_panel.jpg`
   - delete the `if [ -f "MOOZIAC.png" ]` root-copy block (already shipped from `Resources/`)
6. Delete the dead `AppTheme` enum; **rename** `AudioVisualizerView.swift` → `Models/PlayerDesign.swift` (foldered in Phase 3)
7. Verify: `swift build` ✅

### Phase 3 — Folder restructure (30 min)
Apply the **entire** move table from §5 via `git mv` (pure moves, no content edits — all types are `public` and SPM compiles subfolders recursively, so nothing breaks). Then:
```bash
swift build && swift build -c release      # MUST still pass
```

### Phase 4 — Repo polish (30 min)
- `LICENSE` (MIT — README already claims it)
- `CHANGELOG.md` seeded from `PROJECT_CHANGES_LOG.md`
- `docs/reports/` ← all `*Report.md`, `report.txt`, `latestreport.txt`, audits
- `docs/notes/` ← `BLACKBOOK.txt`, `todolist.txt`
- `dev/` (git-ignored) ← monitor scripts, screenshots, diagnostics, logs
- Update README "Architecture & File Sitemap" section to the real tree
- Add `AGENTS.md` (build command, folder conventions, "Models have no AppKit" rule)

### Phase 5 — End-to-end pipeline verification (5 min)
```bash
./build_app.sh                               # must build, bundle, sign, launch
# Then inspect the produced bundle:
ls "$HOME/Applications/Mooziac.app/Contents/Resources/"
#   → must contain: AppIcon.icns, MOOZIAC_transparent.png, launch_transparent.png,
#     MenuBarIcon.png, MenuBarIcon@2x.png, MOOZIAC.png, trackpad.html, macbook_panel.jpg
```
Launch the app; open the gesture tutorial window (must render `trackpad.html`) and the player (must show artwork fallback). This is the true "nothing breaks" gate.

### Phase 6 — Future hardening (not required for restructure)
- Split the three giant files (`PlaylistLibraryView.swift` 2,682 LOC, `SettingsPanel.swift` 2,116 LOC, `LocalDatabaseManager.swift` 1,067 LOC)
- Add `Tests/` target; unit-test the pure logic (`SyncedLyricsParser`, `URLFilter`, `HistoryManager`, DB layer, models)
- Add CI (GitHub Actions: `swift build -c release` on macOS 13/14/15)
- Optionally split into `MooziacCore` (library) + `MooziacApp` (executable) modules

### Why this cannot break
- SPM compiles all Swift files under the target path recursively — folders are free.
- Every cross-file reference is to a `public` (or internal-in-module) type — moving files within the module cannot change visibility.
- The **only** path-sensitive code is `build_app.sh` + `Bundle.main` lookups, and Phase 2 updates exactly those two `cp` lines.
- Each phase is independently verified with `swift build` before moving on.

---

*Report generated from a full read of the repo on Aug 18, 2026. No files were modified. Build (debug + release) verified passing.*
