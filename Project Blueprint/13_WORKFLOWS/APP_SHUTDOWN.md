# App Shutdown

What happens when Mooziac quits.

## Termination path

```
User quits (context menu "Quit" / Cmd+Q / system)
  └─ NSApplicationDelegate.applicationWillTerminate
       └─ BackgroundMediaController.shared.stopPreventingSleep()
            - release IOPMAssertion
            - end ProcessInfo activity
```

## What is NOT flushed on quit

| Item | Status |
| :--- | :--- |
| Playback position | persisted continuously by ObserverBridge (≥5 s delta gate) → `YTM_lastTime` (online) / `Mooziac_LastPlayedLocalTrack*` (offline) |
| History | written per track (HistoryManager) |
| Liked songs / playlists / library | written per action to SQLite |
| Window frame | persisted on panel move |
| **In-flight downloads** | ❌ **not persisted** — download queue is in-memory; interrupted jobs lost on quit (stale `.downloading` sandboxes cleaned on next launch) |
| Discord presence | ❌ not cleared on quit (left stale until next start or Discord-side expiry) |

## `applicationShouldTerminateAfterLastWindowClosed`

- Returns `false` — the app keeps running without windows (it's a menu-bar app; window close ≠ quit).

## Session restore asymmetry (see risks)

- `flushSessionState(keepCookies:)` removes `YTM_lastUrl/VideoId/Time/Title/Artist` but **not** `YTM_lastArtwork` on `keepCookies:false` — stale artwork can persist across a logout/login.
- `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` are deleted at every **launch** (not shutdown) — like-state reset each run.

## Related

- `13_WORKFLOWS/APP_STARTUP.md`, `10_BACKGROUND_SYSTEMS/BACKGROUND_TASKS.md`.