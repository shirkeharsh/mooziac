# Asset Map

All runtime assets live in `Resources/` — this is the **sole source** for `build_app.sh` asset copying (per `AGENTS.md`/`AGY.md` and the script itself). 10 files, ~5.6 MB total.

| Asset | Size | Used by | Purpose |
| :--- | ---: | :--- | :--- |
| `AppIcon.icns` | 508 KB | `Info.plist` `CFBundleIconFile` | Application icon |
| `AppIcon.png` | 1.5 MB | (source for icns) | PNG version of app icon |
| `MOOZIAC.png` | 1.3 MB | `LaunchAnimationController` | Full branding logo (launch animation) |
| `MOOZIAC_transparent.png` | 787 KB | launch animation | Transparent branding logo |
| `launch_transparent.png` | 1.1 MB | `LaunchAnimationController` / `LaunchOverlayView` | Launch overlay artwork |
| `MenuBarIcon.png` | 2.1 KB | `StatusItemManager` | 1× menu bar icon |
| `MenuBarIcon@2x.png` | 6.9 KB | `StatusItemManager` | 2× menu bar icon (Retina) |
| `trackpad.html` | 11 KB | `NativeGestureTutorialWindowController` (WKWebView) | Trackpad gesture tutorial UI |
| `macbook_panel.jpg` | 566 KB | `trackpad.html` (loaded by the HTML) | MacBook trackpad panel image for tutorial |

## Coupling rules

- **`trackpad.html` + `macbook_panel.jpg` are a coupled pair** — the HTML loads the JPG. They must always be copied together and kept together (per `AGENTS.md`, `AGY.md`).
- All assets referenced by `build_app.sh` are copied into `Mooziac.app/Contents/Resources/` with the same filename.

## Assets referenced from source (cross-check)

| Asset name referenced in code | Found in Resources? |
| :--- | :--- |
| `launch_transparent` | ✅ |
| `MOOZIAC` | ✅ |
| `MOOZIAC_transparent` | ✅ |
| `trackpad.html` | ✅ |
| `macbook_panel.jpg` | ✅ |
| `MenuBarIcon` / `MenuBarIcon@2x` (via `statusItem.image`) | ✅ |
| `AppIcon` | ✅ |

## Assets NOT in Resources (verified absent)

- `trackpad_visualizer.html` — removed (dead code cleanup, per CHANGELOG).
- Any Liquid-Glass theme assets — rolled back.

## Runtime file locations (not bundle assets)

These are created at runtime and live outside the bundle — see `08_DATA/STORAGE.md` and `08_DATA/CACHE.md` for details:

- `~/Library/Application Support/Mooziac/library.sqlite3` (+ `-wal`, `-shm`)
- `~/Library/Application Support/Mooziac/Offline/`
- `~/Music/Mooziac/` (default music folder; configurable via `YTM_downloadsFolder`)
- `~/Library/Caches/Mooziac/Lyrics/`
- `~/Library/Caches/Mooziac/Thumbnails/`
- `<tmp>/ytm_art_<UUID>.jpg` (notification artwork temp)