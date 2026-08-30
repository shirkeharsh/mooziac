# Lyrics Workflow

Full lifecycle of lyrics in the app.

## Trigger

Track change (online or offline) → `LyricsManager` is invoked by the lyrics HUD / player UI with the current track (title, artist, duration).

## Resolution pipeline

```
track selected / playback state changed
  ├─ cache hit (~/Library/Caches/Mooziac/Lyrics/)?  → return (sync, caller thread)
  ├─ local .lrc sidecar (track.lrcURL)?             → parse → return
  └─ online fetch (URLSession, async, main callback)
        Tier 1: LRCLib exact  /api/get?artist_name&track_name
        Tier 2: LRCLib search "title artist"   (scored gates)
        Tier 3: LRCLib search title-only
        Tier 4: Lyrics.ovh /v1/<artist>/<title>
        → synced → parseLRC; plain → synthesizeLRC (4.0 s spacing)
        → saveToLocalLyricsCache
        → completion([LRCLine]) on main
```

## Display

```
[LRCLine] loaded into CenteredMenuBarLyricsWindowController
  → 0.1 s timer reads NowPlayingManager.currentState.currentTime
  → SyncedLyricsParser.activeLineAndWord(currentTime, leadOffset: 0.35)
  → lyricsLabel text swap (fade) → window re-anchored to menu-bar center
  → no lyrics → "title • artist" display
```

## Download attach path

```
DownloadManager finalize → LyricsManager.fetchRawSyncedLRC(artist, title, duration)
  → LRCLib exact → search → best score
  → raw LRC string → written as .lrc sidecar next to downloaded file
  (no request-ID stale guard — see risks)
```

## Settings integration

- `YTM_isCenteredLyricsEnabled` (and `YTM_v3_` variant) toggles the HUD.
- Toggling rebuilds/repositions the window; toast confirms.

## Failure & fallback

| Situation | Result |
| :--- | :--- |
| No match across all tiers | `[]` → HUD "title • artist" |
| Provider down | silent tier fallthrough |
| Cache write error | swallowed (`try?`) |
| Network offline | sidecar/local cache only |

## Related

- `07_LYRICS/LYRICS_PIPELINE.md`, `SYNC_SYSTEM.md`, `13_WORKFLOWS/DOWNLOAD_WORKFLOW.md`.