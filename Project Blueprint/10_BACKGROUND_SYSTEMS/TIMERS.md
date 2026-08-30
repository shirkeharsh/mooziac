# Timers

All repeating/delayed timers in Mooziac, with rates and purposes.

## Recurring timers

| Timer | Rate | Owner | Purpose | Runs while |
| :--- | :--- | :--- | :--- | :--- |
| Playback time observer | **0.25 s** | `NativeAudioPlayer` | broadcast currentTime → NowPlayingManager → UI | offline playback |
| Lyrics HUD timer | **0.1 s** | `CenteredMenuBarLyricsWindowController` | resolve active line + word, status toasts | HUD visible |
| Player progress redraw | per-frame-ish | `DynamicIslandPlayerView` | waveform/capsule progress animation | panel visible |
| Ambient theme timer | periodic | ambient theme controller | re-poll ambient theme | enabled |

## One-shot / delayed timers

| Timer | Delay | Owner | Purpose |
| :--- | :--- | :--- | :--- |
| `recoveryWatchdog` | **20 s** | `YTMWebView` | re-trigger session restore if page didn't become ready |
| Window animation | ~0.2–0.35 s | `StatusItemManager` / MainViewController | panel open/close animations |
| Toast fade | ~1–2 s | CenteredMenuBarLyricsWindowController | auto-dismiss volume/HUD toasts |

## Deferred dispatch patterns

- `DispatchQueue.main.asyncAfter` for animation sequencing (window show → content fade).
- `DispatchQueue.main.async` after URLSession completions to marshal UI updates.
- Download retry/requeue on `NetworkMonitorReconnected` (no fixed delay).

## Behavioral notes / risks

- The 0.25 s broadcast writes `YTM_lastTime` gated by ≥5 s delta (minimal writes) but still recomputes state each tick.
- 0.1 s HUD timer runs even when lyrics absent (shows title • artist) — constant CPU while open.
- No coalescing for multiple `notifyObservers` from rapid JS messages.
- Timer work is main-thread only; a busy 0.1 s HUD + 0.25 s broadcast + waveform redraw could contend (see `15_ISSUES_AND_RISKS`).

## Related

- `10_BACKGROUND_SYSTEMS/BACKGROUND_TASKS.md`, `07_LYRICS/SYNC_SYSTEM.md`.