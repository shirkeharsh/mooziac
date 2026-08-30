# API Catalog

All remote endpoints and external services Mooziac talks to. Mechanisms only — no secrets, cookies, or credentials documented here.

## Remote HTTP endpoints

| Endpoint | Consumer | Purpose | Method |
| :--- | :--- | :--- | :--- |
| `https://lrclib.net/api/get?artist_name=<q>&track_name=<q>` | `LyricsManager` | exact synced-lyrics lookup | GET |
| `https://lrclib.net/api/search?q=<q>` | `LyricsManager` | lyrics search (2 tiers + raw fetch) | GET |
| `https://api.lyrics.ovh/v1/<artist>/<title>` | `LyricsManager` | plain-text lyrics fallback | GET |
| `https://music.youtube.com/search?q=<q>` | `HistoryManager` | playback fallback for offline-only history items | GET (webview) |
| `https://music.youtube.com/watch?v=<videoId>` | `DiscordRPCManager` (button target), `YTMWebView` (playback) | watch page | — |
| `https://music.youtube.com/watch?v=<vid>&list=RDAMVM<vid>` | `PlaylistManager` (autoplay radio fallback) | radio playback | — |
| Discord local IPC | `DiscordRPCManager` | Rich Presence over UNIX socket | IPC |
| yt-dlp + ffmpeg subprocesses | `DownloadManager` | audio download + mux | subprocess |

## Response shapes (keys consumed)

| Service | Keys consumed |
| :--- | :--- |
| LRCLib | `syncedLyrics`, `plainLyrics`, `trackName`, `artistName`, `duration` |
| Lyrics.ovh | `lyrics` |

## Payloads (request-side)

- Lyrics queries: URL-encoded artist/title from `PlaybackState` / track metadata; empty artist coerced to `"Artist"` for Lyrics.ovh.
- Downloads: `yt-dlp` with `player_client=mweb,web_safari,tv_embedded,web`, output template into `~/Music/Mooziac/.downloading/<jobId>/`, then ffmpeg to final mp3.
- Discord IPC: Handshake → SET_ACTIVITY with presence payload (state, details, timestamps, assets, button).

## Callers/threading

| Caller | Threading |
| :--- | :--- |
| `LyricsManager.fetchLyrics` | completions on main (except cache-hit on caller thread, `fetchRawSyncedLRC` on URLSession thread) |
| `TrackNotificationManager.downloadImage` | completion on URLSession queue (not main) |
| `AppArtworkHelper` | artwork fetch (URLSession-free) |
| `DiscordRPCManager` | socket write on worker |

## Error handling summary

| Caller | Behavior |
| :--- | :--- |
| LyricsManager | status codes ignored; non-200/HTML → `[]` → next tier |
| TrackNotificationManager | `nil` → no notification |
| DownloadManager | failed jobs recorded; cleanup of `.downloading` |
| DiscordRPC | silent fail when socket absent |

## Security notes

- No API keys embedded in the binary (no external SPM deps, no secrets found).
- Sign-in is cookie-based (YouTube session cookies in the WKWebView data store) — never persisted to our own storage.
- See `12_SECURITY/`.

## Related

- `09_NETWORK/NETWORK_FLOW.md`, `EXTERNAL_SERVICES.md`, `REQUEST_PIPELINES.md`, `ERROR_HANDLING.md`.