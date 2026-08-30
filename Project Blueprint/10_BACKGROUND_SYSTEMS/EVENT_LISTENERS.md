# Event Listeners

All the system/OS event hooks wired in Mooziac.

## System events

| Listener | Mechanism | Handler(s) |
| :--- | :--- | :--- |
| Screen lock/unlock | `NSWorkspace.didLockNotification` / `didUnlockNotification` | NowPlayingManager (pause/resume), AudioRouteMonitor, EdgeVolumeEngine (haptics) |
| System sleep/wake | `willSleep` / `didWake` | NowPlayingManager pause/resume |
| Session resign/active | `NSApplication.didResignActive` / `didBecomeActive` | MainViewController panel behavior |
| App launch/terminate | NSApplication delegates | AppDelegate, MainViewController teardown |
| Screen/display change | `NSApplication.didChangeScreenParameters` / display registration | window re-anchor (`YTM_savedDisplayID`) |
| Dock drag | dragSessionDropped | `YTM_isDraggedFromDock` window mode |

## Hardware input events

| Listener | Mechanism | Handler |
| :--- | :--- | :--- |
| Global hotkeys | `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` | `GlobalHotKeyManager` → NowPlayingManager/panel |
| Local keys | `NSEvent.addLocalMonitorForEvents` | `KeyboardCommandHandler.handle` (Space/Enter/arrows/Esc/L) |
| Scroll-wheel volume | local monitor `.scrollWheel` | NowPlayingManager.adjustVolume |
| Trackpad right-edge | `Multitouch` private framework (via `EdgeVolumeEngine`) | VolumeController |
| Corner taps | `EdgeVolumeEngine` gesture recognizers | next/prev/play-pause |

## Runtime state listeners (observers)

| Listener | For | Response |
| :--- | :--- | :--- |
| Network path monitor | `NWPathMonitor` | engine mode switch, download gating |
| WebContent termination | `WKWebView` delegate | re-inject observers + restore playback |
| `URLCache` mutation | YTMWebViewContainer init | global cache reset on session flush |

## Timer-driven "listeners"

- `recoveryWatchdog` (20 s) — retries session restore if page didn't become ready.
- `CenteredMenuBarLyricsWindowController` (0.1 s) — lyrics line + status toasts.
- `NativeAudioPlayer` time observer (0.25 s) — broadcast playback state.
- `DynamicIslandPlayerView` progress redraw timer — waveform animation.

## Why this matters (single-thread model)

All listeners dispatch work onto the **main thread**. The only background listeners are NWPathMonitor and URLSession completions. Multiple listeners fire on the same event (e.g. lock → 3 handlers), each posting/reading shared `NowPlayingManager` state — see concurrency risks.

## Related

- `10_BACKGROUND_SYSTEMS/OBSERVERS.md`, `06_AUDIO/MEDIA_CONTROLS.md`, `03_ARCHITECTURE/EVENT_FLOW.md`.