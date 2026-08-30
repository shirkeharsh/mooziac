# App Startup

Boot sequence from process launch to usable app.

## Entry

1. `main.swift` — `NSApplication.shared`, sets activation policy, runs.
2. `AppDelegate.applicationDidFinishLaunching` drives all startup.

## Startup sequence (verified)

```
main.swift
  └─ NSApplication run
       └─ applicationDidFinishLaunching
            1. NSApp.setActivationPolicy(.accessory)     // menu-bar app
            2. setupMainMenu()                           // Edit menu install
            3. UserDefaults.removeObject ×10             // legacy-key cleanup
            4. BackgroundMediaController.shared.startPreventingSleep()
            5. EdgeVolumeEngine.shared.start()
            6. AudioRouteMonitor.shared.startMonitoring()
            7. NetworkMonitor.shared.startMonitoring()
            8. DiscordRPCManager.shared.startReconnectLoop() + tryConnect()
            9. StatusItemManager()                       // creates panel + MainViewController
                 └─ MainViewController.viewDidLoad
                     ├─ setupUI()
                     ├─ setupObservers()
                     ├─ setBrowserVisible(false) / offline / playlists hidden
                     ├─ GlobalHotKeyManager.shared.startMonitoring()
                     └─ (StatusItemManager.setupPanel wires onChangeSize)
            10. LaunchAnimationController.shared.play()
```

## What StatusItemManager does at init

- Creates `NSStatusItem` + custom status view.
- Creates the panel window + `MainViewController`.
- `setupPanel()`: wires `onChangeSize`, positions docked under status item or saved dragged frame (`YTM_playerFrameX/Y`), registers panel-did-move to persist position, outside-click close, scroll-wheel volume, keyboard command forwarding, context menu.
- Observes display parameter changes; re-anchors to saved display.

## Delayed/async startup work

| Work | When | Where |
| :--- | :--- | :--- |
| WebView load + session restore (`cueVideoById`, paused) | after panel ready | YTMWebView |
| Offline library scan + DB open (corruption recovery) | async background | LocalLibraryManager / LocalDatabaseManager |
| `recoveryWatchdog` (20 s) session restore retry | timer | YTMWebView |
| Default settings seeding (`YTM_hasInitializedDefaultSettingsV2`) | early | AppDelegate |

## Ordering hazards (risks)

- `MainViewController.viewDidLoad` calls `setBrowserVisible(false)` etc. **before** StatusItemManager wires `onChangeSize` → resize no-ops at that point (benign, INFERRED).
- `NowPlayingManager.init` deletes `YTM_likedTrackKeysSet`/`YTM_lastIsLiked` at launch (state reset).
- Sleep-prevention assertion created on singleton touch (init already calls `startPreventingSleep`).
- Legacy UserDefaults keys removed ×10 each launch — if any of those are settings the user changed, they reset.

## Related

- `13_WORKFLOWS/APP_SHUTDOWN.md`, `10_BACKGROUND_SYSTEMS/BACKGROUND_TASKS.md`, raw notes `01_CORE_LAYER.md`.