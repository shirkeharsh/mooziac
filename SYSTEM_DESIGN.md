# System Design & Architecture Report: mp3kal

**Generated autonomously by tiny-ai on Apple Silicon**

---

## 1. Project Overview & High-Level Architecture

`mp3kal` is an on-disk software project analyzed by the tiny-ai on-device engine.

### Summary Metrics
- **Root Directory**: `/Users/harshshirke/local/projects/mp3kal`
- **Total Source Files**: `7764`
- **Total Lines of Code**: `48140724`
- **Primary Languages**: **Markdown** (118 files), **Other** (7361 files), **Swift** (207 files), **Shell Script** (8 files), **HTML** (11 files), **YAML** (13 files), **JSON** (22 files), **C** (5 files), **C++** (1 files), **CSS** (4 files), **JavaScript** (6 files), **Python** (8 files)

---

## 2. Technology Stack & Key Dependencies

### Ecosystem
The codebase utilizes the following libraries, frameworks, and packages:
- `Swift Package Manager (SPM)`
- `Swift Package Manager (SPM)`
- `Swift Package Manager (SPM)`
- `Swift Package Manager (SPM)`

---

## 3. Architecture & Entry Points

### Key Application Entry Points
- [`.build/checkouts/whisper.spm/Sources/test-swift/main.swift`](file:///Users/harshshirke/local/projects/mp3kal/.build/checkouts/whisper.spm/Sources/test-swift/main.swift)

### Core Classes & Data Models
- `class PassthroughBrowserContainerView` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L4)
- `class MainViewController` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L13)
- `class NowPlayingManager` — defined in [`mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift#L5)
- `struct QueueItemInfo` — defined in [`mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift#L192)
- `struct AutomixItemInfo` — defined in [`mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift#L218)
- `struct UpNextSnapshot` — defined in [`mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift#L224)
- `class StatusItemManager` — defined in [`mooziac/Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift#L4)
- `class StatusItemPanel` — defined in [`mooziac/Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift#L3)
- `class AppDelegate` — defined in [`mooziac/Sources/Mooziac/App/AppDelegate.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/App/AppDelegate.swift#L4)
- `class BackgroundMediaController` — defined in [`mooziac/Sources/Mooziac/App/BackgroundMediaController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/App/BackgroundMediaController.swift#L6)
- `enum KeyboardCommandHandler` — defined in [`mooziac/Sources/Mooziac/Input/KeyboardCommandHandler.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Input/KeyboardCommandHandler.swift#L6)
- `class DOMHealthMonitor` — defined in [`mooziac/Sources/Mooziac/Web/DOMHealthMonitor.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Web/DOMHealthMonitor.swift#L3)
- `struct URLFilter` — defined in [`mooziac/Sources/Mooziac/Web/URLFilter.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Web/URLFilter.swift#L3)
- `class YTMWebViewContainer` — defined in [`mooziac/Sources/Mooziac/Web/YTMWebView.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Web/YTMWebView.swift#L5)
- `enum RPCOpcode` — defined in [`mooziac/Sources/Mooziac/Managers/DiscordRPCManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DiscordRPCManager.swift#L4)
- `class DiscordRPCManager` — defined in [`mooziac/Sources/Mooziac/Managers/DiscordRPCManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DiscordRPCManager.swift#L12)
- `enum DownloadStatus` — defined in [`mooziac/Sources/Mooziac/Managers/DownloadManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DownloadManager.swift#L6)
- `struct DownloadProgressInfo` — defined in [`mooziac/Sources/Mooziac/Managers/DownloadManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DownloadManager.swift#L13)
- `struct QueueTask` — defined in [`mooziac/Sources/Mooziac/Managers/DownloadManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DownloadManager.swift#L30)
- `struct PersistedDownloadJob` — defined in [`mooziac/Sources/Mooziac/Managers/DownloadQueuePersistence.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Managers/DownloadQueuePersistence.swift#L3)

### Key Functions & API Services
- `setupObservers()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L14)
- `displayID()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L30)
- `findScreen()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L38)
- `clampFrameToVisibleBounds()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L56)
- `hasNotch()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L78)
- `safeTopBoundary()` — defined in [`mooziac/Sources/Mooziac/Core/DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/DisplayManager.swift#L86)
- `setupUI()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L43)
- `setupObservers()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L115)
- `setBrowserVisible()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L121)
- `setOfflineLibraryVisible()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L154)
- `setPlaylistLibraryVisible()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L181)
- `dynamicIslandDidSearch()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L209)
- `playSearchQuery()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L213)
- `findBestLocalTrack()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L357)
- `dynamicIslandDidTapPlayPause()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L403)
- `dynamicIslandDidTapNext()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L407)
- `dynamicIslandDidTapPrevious()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L411)
- `dynamicIslandDidTapShuffle()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L415)
- `dynamicIslandDidTapRepeat()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L419)
- `dynamicIslandDidToggleExpanded()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L423)
- `dynamicIslandDidSeek()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L431)
- `dynamicIslandDidTapWebBrowser()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L435)
- `dynamicIslandDidTapOfflineLibrary()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L445)
- `dynamicIslandDidTapResetPosition()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L456)
- `dynamicIslandDidTapPlaylistLibrary()` — defined in [`mooziac/Sources/Mooziac/Core/MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/mooziac/Sources/Mooziac/Core/MainViewController.swift#L461)

---

## 4. Directory Structure Tree

```text
mp3kal/
├── AGENTS.md (37 lines)
├── AGY.md (214 lines)
├── CHANGELOG.md (89 lines)
├── LICENSE (21 lines)
├── Mooziac.entitlements (24 lines)
├── Package.swift (22 lines)
├── README.md (103 lines)
├── SYSTEM_DESIGN.md (136 lines)
├── Todaytodo.md (1714 lines)
├── build_app.sh (311 lines)
├── downloadreport.md (659 lines)
├── mooziac-3d-website-player-logo-only.html (1597 lines)
├── mooziac.sh (3 lines)
├── mp3kal_system_design.pdf (168 lines)
├── nextupdatesync.md (244 lines)
├── publish.md (147 lines)
├── release.sh (158 lines)
  ├── build.db (17658 lines)
  ├── debug.yaml (81 lines)
  ├── plugin-tools.yaml (66 lines)
  ├── release.yaml (66 lines)
  ├── workspace-state.json (29 lines)
      ├── LICENSE (21 lines)
      ├── Makefile (51 lines)
      ├── Makefile-tmpl (51 lines)
      ├── Package.swift (83 lines)
      ├── README.md (36 lines)
      ├── publish-trigger (0 lines)
        ├── for-tests-ggml-base.en.bin (6531 lines)
          ├── swift.yml (21 lines)
          ├── main.m (62 lines)
          ├── main.swift (35 lines)
          ├── ggml-alloc.c (985 lines)
          ├── ggml-alloc.h (76 lines)
          ├── ggml-backend-impl.h (141 lines)
          ├── ggml-backend.c (2101 lines)
          ├── ggml-backend.h (233 lines)
          ├── ggml-common.h (1853 lines)
          ├── ggml-impl.h (607 lines)
          ├── ggml-metal.h (66 lines)
```

---

## 5. Architectural Quality & Next Steps
- **Modularity**: File separation allows independent testing and scaling.
- **Recommendations**: Ensure test coverage is maintained for core entry points and verify configuration schemas.
