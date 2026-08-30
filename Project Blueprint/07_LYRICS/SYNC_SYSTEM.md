# Sync System

How lyrics stay in sync with playback (and with track metadata).

## Time-driven line synchronization

```
NowPlayingManager.currentState.currentTime   (updated every 0.25s offline, JS messages online)
   │
   ▼  (0.1s timer in CenteredMenuBarLyricsWindowController)
SyncedLyricsParser.activeLineAndWord(_ currentTime: TimeInterval, leadOffset: TimeInterval = 0.35)
   → walks [LRCLine] sorted by time
   → returns active LRCLine + active LRCWord
   ▼
lyricsLabel.text = active line (fade-swap)
```

- Lead offset **0.35 s** — the next line is highlighted slightly before its timestamp.
- Word-level highlighting available when LRC contains inline word timestamps.

## Active-line resolution details

- `activeLineAndWord` finds the latest line whose `time <= currentTime`; when the next line's time is within the lead window, it is chosen for early highlight.
- When lyrics are absent, the HUD shows `title • artist` from `PlaybackState`.

## Track-change re-sync

- On new track (`PlaybackState` title change), the lyrics HUD re-fetches via `LyricsManager.fetchLyrics(track)` and resets the current-line index.
- Playback-state changes (pause/resume/seek) reuse the same timer — the current time naturally drives the active line; seeking jumps the highlight accordingly.

## Download-side sync

- `fetchRawSyncedLRC` fetches synced lyrics during downloads so offline tracks carry `.lrc`.
- ⚠ Concurrent fetches have no request-ID guard — responses can apply out of order (see `15_ISSUES_AND_RISKS`).

## Timing constants (verified)

| Constant | Value |
| :--- | :--- |
| HUD timer | 0.1 s |
| Highlight lead | 0.35 s |
| Plain→LRC spacing | 4.0 s |
| Default word span | 4.2 s |
| Min line duration | 0.4 s |

## Related

- `13_WORKFLOWS/LYRICS_WORKFLOW.md`, `06_AUDIO/NOW_PLAYING.md`.