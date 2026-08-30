# Lyrics Pipeline

Step-by-step flow from track to displayed line, traced from `LyricsManager` source.

## Fetch pipeline

```
Trigger: track selected / lyrics requested (player UI, downloads, HUD)
  │
  ▼
LyricsManager.fetchLyrics(track)
  ├─ has cached lyrics on disk? ──yes──▶ return cached (SYNCHRONOUS, caller thread)
  │
  ├─ offline / no match path?
  │     - local .lrc sidecar (track.lrcURL) → parse → return
  │
  ▼
Online fetch (URLSession, async, main-queue completion):
  1. LRCLib /api/get?artist_name=&track_name=        (exact)
  2. LRCLib /api/search?q=  → tier 1 scores
  3. LRCLib /api/search?q=  → tier 2 scores
  4. Lyrics.ovh /v1/<artist>/<title>                  (plain text fallback)
  │
  ▼
Matching gates applied (title ≥0.6, artist ≥0.4/subset, duration ≤12s tolerance)
  │
  ▼
Selected result:
  ├─ synced (.lrc)   → SyncedLyricsParser.parseLRC()
  └─ plain           → SyncedLyricsParser.synthesizeLRC(plain)  (4.0s spacing)
  │
  ▼
saveToLocalLyricsCache()   (~/Library/Caches/Mooziac/Lyrics/)
  │
  ▼
completion([LRCLine]) → HUD / UI
```

## Display pipeline

```
NowPlayingManager.currentState.currentTime
  │ (0.1s timer in CenteredMenuBarLyricsWindowController)
  ▼
SyncedLyricsParser.activeLineAndWord(currentTime, leadOffset: 0.35)
  → active LRCLine + active word
  ▼
lyricsLabel.text = line.text (fade-swap animation, width recompute)
  ▼
window repositioned to menu-bar center if needed
```

## Raw synced LRC path (`fetchRawSyncedLRC`)

Used by download flow to attach `.lrc` to offline tracks:
```
fetchRawSyncedLRC(artist, title, duration)
  → LRCLib /api/get exact → /api/search → score + pick
  → returns raw LRC string
```
⚠ No request-ID/stale-response guard — concurrent calls may apply out of order.

## Failure behavior

| Failure | Result |
| :--- | :--- |
| No lyrics found | `[]` → HUD shows "title • artist" |
| Network error | silent nil → fallback tier |
| Cache write failure | swallowed (`try?`) |
| Non-200 HTTP | treated as empty → next tier |

## Related

- `07_LYRICS/PROVIDERS.md`, `SYNC_SYSTEM.md`, `13_WORKFLOWS/LYRICS_WORKFLOW.md`.