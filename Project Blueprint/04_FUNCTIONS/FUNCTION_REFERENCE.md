# Function Reference

This document is the **navigation layer** for the exhaustive function documentation. Every function/method/callback in Mooziac is documented in the raw discovery notes; this page explains where to find each category and provides the index.

## Where each function category lives

| Category | File | What's documented per function |
| :--- | :--- | :--- |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/01_CORE_LAYER.md`** | App + Core (12 files) | Every `init`, `deinit`, computed property, method, injected JS function, selector, observer closure — with inputs, outputs, callers, calls, reads/writes, side effects, errors, async behavior, execution flow |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/02_AUDIO_WEB_INPUT.md`** | Audio + Web + Input + Support (11 files) | Same depth incl. C callbacks (Multitouch), KVO/observers, timers |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/03_DATA_MANAGERS.md`** | LocalDatabaseManager, LocalLibraryManager, PlaylistManager, DownloadManager | ~131 functions incl. every SQL statement and completion handler |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/04_LYRICS_MANAGERS_MODELS.md`** | Lyrics/History/Likes/Discord/Notifications/Network/Artwork + Models | ~70 functions, init & computed properties included |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/05_PLAYER_WINDOWS_UI.md`** | DynamicIslandPlayerView/* + Views/Windows/* | ~200 functions/selectors incl. animations & gesture handlers |
| **`99_APPENDIX/RAW_DISCOVERY_NOTES/06_LIBRARIES_COMPONENTS_UI.md`** | Views/Libraries/* + Views/Components/* | ~150 functions/selectors incl. table delegate/dataSource & context menus |

## How to use

1. Find the function name in `FUNCTION_INDEX.md` (673 declarations, grouped by file with line numbers).
2. Open the matching raw discovery note for that file.
3. Read the `## FUNCTION ENTRY` section with the matching name.

## Example function entry format (used throughout the raw notes)

```
### dynamicIslandDidSearch(query: String)   (lines 206–348)
- Purpose: ...
- Inputs: query: String — trimmed search text
- Output: Void
- Called by: DynamicIslandPlayerView (delegate), MainViewController.setupUI
- Calls: findBestLocalTrack, switchToOnlineMode, setBrowserVisible, ...
- Reads: engineMode, NetworkMonitor.isReachable, LocalLibraryManager.allTracks
- Writes: currentState, YTM_last* keys
- Side effects: loads webview URL, injects autoPlayJS, shows overlay
- Errors: ...
- Async behavior: DispatchQueue.main.asyncAfter at 0.4/0.8/1.3/1.8/2.5s
- Events: posts/observes ...
- Execution flow: 1) ... 2) ... 3) ...
```

## Injected JavaScript functions (documented in 01_CORE_LAYER / 02)

The observer script defines browser-side functions that are *not* Swift funcs but are part of the bridge contract: `updateNowPlaying`, `findAndPlayTopTrack`, `simulateClick`, `bindVideoEvents`, `fetchQueueData`, `setEQPreset`, `videoEnded` handler, etc. — see `01_CORE_LAYER.md` "JS globals set by the app" and `02_AUDIO_WEB_INPUT.md` YTMWebView section.

## Line-number caveat

Line numbers in all documents are **approximate and file-relative** (taken from the last-read state of the files). They should be used as search anchors, not contracts.