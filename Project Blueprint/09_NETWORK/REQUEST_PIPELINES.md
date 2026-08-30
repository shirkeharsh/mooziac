# Request Pipelines

The concrete request pipelines for each network capability.

## 1. Lyrics pipeline (4 tiers)

```
fetchLyrics(track)
  ├─ [cache-hit] ~/Library/Caches/Mooziac/Lyrics/ → return (sync, caller thread)
  ├─ Tier 1  LRCLib /api/get (exact)        [stale-guarded by currentRequestID]
  │     ├─ syncedLyrics → parse → cache → callback(main)
  │     └─ plainLyrics  → synthesize → cache raw → callback(main)
  ├─ Tier 2  LRCLib /api/search?q="title artist"   [requestID stale guard]
  ├─ Tier 3  LRCLib /api/search?q=title-only
  └─ Tier 4  Lyrics.ovh /v1/<artist>/<title> (empty artist → "Artist")
        └─ all fail → callback([]) (main)
```

**Validation gates** (tiers 2–4): title ≥ 0.6, artist ≥ 0.4 or subset, duration ≤ 12 s tolerance; score weights 0.65/0.35. Title-only gates 0.8/0.5 for filename-driven tracks.

**Threading contract:** network completions → main; cache-hit → caller thread; `fetchRawSyncedLRC` → URLSession thread. (Inconsistent — see risks.)

## 2. Artwork pipeline (notification + rows)

```
AppArtworkHelper.loadArtwork(url, targetSize)
  ├─ memory cache hit → return image
  ├─ disk thumbnail hit (~/Library/Caches/Mooziac/Thumbnails/) → return
  ├─ download → generate → save (mem 500/50MB + disk JPEG 0.85, sizes 64/128/256)
  └─ failure → nil (fallback artwork)

TrackNotificationManager.downloadImage(url)
  └─ URLSession.shared.dataTask → write <tmp>/ytm_art_<UUID>.jpg → post notification
     (completion on URLSession queue — not main)
```

## 3. Download pipeline

```
DownloadManager.enqueue(videoId/url)
  → validate (yt-dlp/ffmpeg available, network up)
  → create job in .downloading/<jobId>/
  → spawn yt-dlp (player_client list)
  → spawn ffmpeg → final format
  → move into music folder → rescan → SQLite upsert (LocalLibraryManager.saveTracks)
  → post Mooziac_DownloadProgress / Mooziac_DownloadQueueChanged
  → failure → cleanup partial files, mark failed
```

## 4. Playback-fallback pipeline (history)

```
Play item that is offline-only (HistoryManager / PlaylistManager)
  ├─ online? → load https://music.youtube.com/search?q="<title> <artist>" in webview
  └─ offline? → switch to online mode + same search URL
```

## 5. Discord presence pipeline

```
Presence state changed → validate enabled + socket exists
  → HANDSHAKE(0) → OP 1 → SET_ACTIVITY(2)
  → payload: title/artist/timestamps/assets/button
  → failure → silent no-op
```

## Related

- `09_NETWORK/ERROR_HANDLING.md`, `13_WORKFLOWS/DOWNLOAD_WORKFLOW.md`.