# Lyrics Architecture

Lyrics in Mooziac flow from remote providers → a matcher → a parser → a disk cache → a time-driven HUD.

## Components

| Component | File | Role |
| :--- | :--- | :--- |
| `LyricsManager` | `Managers/LyricsManager.swift` (507) | Fetch, match, cache, resolve current line |
| `SyncedLyricsParser` | `Managers/SyncedLyricsParser.swift` (155) | Parse `[mm:ss.xx]` LRC; synthesize LRC from plain text |
| `CenteredMenuBarLyricsWindowController` | `Views/Windows/...` (282) | HUD presentation, 0.1 s update timer |
| Models | `LRCWord`, `LRCLine` | Parsed line/word structures |

## Data model

- **`LRCLine`**: `time: TimeInterval`, `text: String`, `words: [LRCWord]`, `duration`.
- **`LRCWord`**: `time`, `text`, `endTime`.
- Lyrics are `[LRCLine]` sorted by time; the parser resolves the active line by `currentTime`.

## Fetch tiers (in order)

1. **LRCLib exact**: `GET https://lrclib.net/api/get?artist_name=<q>&track_name=<q>`.
2. **LRCLib search tier 1 / tier 2**: `GET https://lrclib.net/api/search?q=<q>` with two scoring tiers.
3. **Lyrics.ovh fallback**: `GET https://api.lyrics.ovh/v1/<artist>/<title>` (plain text → synthesized LRC).

## Matching gates (constants)

- LRCLib duration tolerance: **12.0 s**.
- Title similarity gate **≥0.6**; artist gate **≥0.4** or subset match; asymmetric-artist title gate **≥0.8**; local-filename title gate **≥0.8**, artist gate **≥0.5**; score weights **0.65/0.35**.

## Synthesis constants (plain → LRC)

- Plain→LRC spacing **4.0 s**; default word span **4.2 s**; min line duration **0.4 s**; highlight lead **0.35 s**.

## Cache

- Path: `~/Library/Caches/Mooziac/Lyrics/`.
- Keyed per track; written via `saveToLocalLyricsCache` (`try?` — errors swallowed).
- Also scans local `.lrc` sidecar files next to audio in `~/Music/Mooziac` (LocalTrack.lrcURL).

## Presentation

- `CenteredMenuBarLyricsWindowController` timer (0.1 s) calls `SyncedLyricsParser.activeLineAndWord(leadOffset: 0.35)` using `NowPlayingManager.currentState.currentTime`.
- Displays title • artist when no lyrics; fades between lines.
- Status toasts (`Volume: 65%`, etc.) share the same window.

## Risks (see `15_ISSUES_AND_RISKS`)

- Cache-hit path returns synchronously on the caller thread vs async elsewhere (inconsistent contract).
- `fetchRawSyncedLRC` has no request-ID guard → out-of-order application for concurrent downloads.
- HTTP status codes ignored; HTML bodies parse to nil → silent fallback.
- Retain-cycle risk in nested closure (LyricsManager:487).
- Lyrics cache persisted unencrypted.

## Related

- `07_LYRICS/LYRICS_PIPELINE.md`, `PROVIDERS.md`, `CACHE_SYSTEM.md`, `SYNC_SYSTEM.md`, raw note `04_LYRICS_MANAGERS_MODELS.md`.