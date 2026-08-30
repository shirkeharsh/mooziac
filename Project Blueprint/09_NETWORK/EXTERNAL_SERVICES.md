# External Services

All third-party services and tools Mooziac depends on.

## Runtime dependencies

| Service | Type | Purpose | Failure behavior |
| :--- | :--- | :--- | :--- |
| YouTube Music (music.youtube.com) | remote web app | primary playback source, library, search, lyrics context | page fails → recovery watchdog / offline mode |
| LRCLib (lrclib.net) | remote API | synced lyrics (exact + search) | fall to next tier / `[]` |
| Lyrics.ovh (api.lyrics.ovh) | remote API | plain lyrics fallback | `[]` → "title • artist" HUD |
| Discord Desktop IPC | local socket | Rich Presence | silent fail, no-op |
| YouTube (via yt-dlp) | remote media CDN | offline downloads | job marked failed, queue continues |

## External subprocesses

| Tool | Used by | Version req | Invocation |
| :--- | :--- | :--- | :--- |
| `yt-dlp` | DownloadManager | present on PATH (checked) | `yt-dlp ... --player-client=mweb,web_safari,tv_embedded,web` (comma-joined) |
| `ffmpeg` | DownloadManager | present on PATH | post-processing / muxing to final format |
| `swift`/`swiftc` | build (dev-only) | Swift 5.9+ | `swift build` |

## Integration points

### WebKit (primary)

- WKWebView configured with persistent data store (cookies/session for YouTube sign-in).
- Content-blocking rules: `YTMBlockRules` JSON embedded in `YTMWebView.swift`.
- No SPM external packages — WebKit is a system framework.

### Discord

- `DiscordRPCManager` connects to `/tmp/discord-ipc-0…9`.
- Presence: state = title, details = artist, timestamps, assets (small_image `mooziac`), button "Listen on YouTube Music" (validated URL, ≤512 chars).
- Gated by `YTM_discordRPC_enabled`.

### User-facing data providers (read-only)

| Provider | Data |
| :--- | :--- |
| File system (`~/Music/Mooziac`, `~/Library/Application Support/Mooziac`) | offline library, downloads |
| macOS APIs | media keys (NOT wired), now-playing info, CoreAudio, Multitouch, screen lock |

## Sign-in

- Cookie-based: app detects sign-in via WebKit cookies/SAPISID presence (`YTMWebView` → `NowPlayingManager.isSignedIn`).
- `YTM_hasLoggedInOnce` tracked; `YTM_SignInStatusChanged` posted.
- No first-party auth token storage (see `12_SECURITY/KEY_STORAGE.md`).

## Notes / risks

- All service URLs/hosts hardcoded; no endpoint abstraction layer.
- Downloading depends on yt-dlp/ffmpeg being installed — startup warning `YTM_ffmpeg_not_installed` path (see raw notes C).
- LRCLib/Lyrics.ovh availability is assumed; no graceful degradation beyond fallback tiers.