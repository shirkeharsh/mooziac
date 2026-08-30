# Download Workflow

The full offline download pipeline.

## Entry points

| Entry | Path |
| :--- | :--- |
| Player UI download button | `DynamicIslandPlayerView.downloadCurrentTrackTapped` → `DownloadManager.queueTrack` |
| Playlist auto-download | `PlaylistManager` download plan → batch enqueue |
| Context menu | queue selected video/playlist |
| History/suggested | batch enqueue helpers |

## Pipeline (verified)

```
enqueue(url, title, artist) / enqueueBatch(...)
  ├─ dedup (queue contains URL? → skip)
  ├─ broadcast .queued (Mooziac_DownloadQueueChanged) + progress
  └─ processNextQueueTask()          // serial, one at a time

processNextQueueTask()
  ├─ guard not currently active
  ├─ run yt-dlp pipeline (workQueue async)
  │    1. create sandbox ~/Music/Mooziac/.downloading/<UUID>/
  │    2. resolve yt-dlp path (PATH candidates: ~/.local/bin, ~/.pyenv/shims,
  │       /opt/homebrew/bin|sbin, /usr/local/bin, ~/.cargo/bin, /usr/bin,
  │       youtube-dl fallback) — else fail "brew install yt-dlp ffmpeg"
  │    3. resolve ffmpeg dir (command -v → dirname; candidate dirs) → --ffmpeg-location
  │    4. args: yt-dlp + --player-client=mweb,web_safari,tv_embedded,web
  │            [-o <template>] optional --ffmpeg-location <dir> <query>
  │    5. Process.run + blocking waitUntilExit (1200 s timeout → kill + fail)
  │    6. parse progress output → Mooziac_DownloadProgress
  │    7. validate output file (pick valid audio: mp3/m4a/flac/wav/aac/ogg/opus)
  │    8. if failed → friendly error map (ERROR:/[youtube] ERROR/ffmpeg missing)
  │    9. cancel → kill process, cleanup sandbox
  └─ processNextQueueTask() recursion until queue drains

finalize (success)
  ├─ move file into music folder (~/Music/Mooziac)
  ├─ LocalLibraryManager.scanLibrary → SQLite upsert (saveTracks)
  ├─ assignYTVideoID mapping
  ├─ fetch synced lyrics (.lrc attach) via LyricsManager.fetchRawSyncedLRC
  └─ broadcast status → UI refresh
```

## Concurrency & safety

| Concern | Mechanism |
| :--- | :--- |
| Serialization | single in-flight task; `processNextQueueTask` recursion |
| Dedup | in-queue URL check + batch one-shot index |
| Network loss | `NetworkMonitorReconnected` → requeue handling |
| Stale state | `cleanupStaleDownloads` on startup removes leftover `.downloading` dirs |
| Timeout | 1200 s watchdog kill |
| User cancel | `cancelTask` → kill + sandbox cleanup |

## Failure modes & messages

| Failure | Handling |
| :--- | :--- |
| yt-dlp missing | job failed + user-facing install hint |
| ffmpeg missing | job failed + hint |
| Network/video unavailable | friendly error map, job marked failed |
| Timeout (1200 s) | kill, failed |

## Persistence caveat

- Download **queue is in-memory only** — quitting the app loses pending jobs (see `13_WORKFLOWS/APP_SHUTDOWN.md`).

## Related

- `09_NETWORK/REQUEST_PIPELINES.md`, `13_WORKFLOWS/LYRICS_WORKFLOW.md`, raw note `03_DATA_MANAGERS.md`.