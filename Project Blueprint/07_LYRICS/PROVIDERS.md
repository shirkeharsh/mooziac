# Providers

Lyrics data sources. Mechanisms only — no secret values.

## 1. LRCLib (`lrclib.net`)

| Attribute | Value |
| :--- | :--- |
| Endpoints | `GET /api/get?artist_name=<q>&track_name=<q>` (exact) · `GET /api/search?q=<q>` (search) |
| Auth | none |
| Response | JSON: `{ lyrics, syncedLyrics, plainLyrics, artistName, trackName, duration }` |
| Used for | synced `.lrc` + plain lyrics |
| Usage tiers | exact → search tier 1 → search tier 2 (differing score weights 0.65/0.35) |
| Parser | `SyncedLyricsParser.parseLRC` for `syncedLyrics` |

## 2. Lyrics.ovh (`api.lyrics.ovh`)

| Attribute | Value |
| :--- | :--- |
| Endpoint | `GET /api.lyrics.ovh/v1/<artist>/<title>` |
| Auth | none |
| Response | JSON `{ lyrics: String }` (plain text) |
| Used for | final fallback; converted via `synthesizeLRC` (4.0 s line spacing) |

## 3. Local sidecar `.lrc` files

| Attribute | Value |
| :--- | :--- |
| Location | next to audio files in the music folder (`LocalTrack.lrcURL`) |
| Format | standard `[mm:ss.xx]` LRC |
| Parsed by | `SyncedLyricsParser.parseLRC` |

## 4. Matching / scoring (all constants verified)

- LRCLib duration tolerance **12.0 s**.
- Title gate **≥0.6**, artist gate **≥0.4** or subset.
- Asymmetric-artist title gate **≥0.8**.
- Local-filename title gate **≥0.8**, artist gate **≥0.5**.
- Score weights **0.65 / 0.35**.

## Request creator / parser / error handling

- Creator: `URLSession` in `LyricsManager` (URL strings built in code; values URL-encoded from track metadata).
- Parser: JSON decode + `SyncedLyricsParser`.
- Errors: status codes ignored (non-200 → empty → next tier); decoding failures → `[]`.
- Retry: none (fallthrough to next provider).
- Cache: disk cache `~/Library/Caches/Mooziac/Lyrics/` written after successful fetch; cache-hit returns synchronously (inconsistent contract, see risks).

## Callers / consumers

- `LyricsManager.fetchLyrics` — player views, `CenteredMenuBarLyricsWindowController`.
- `LyricsManager.fetchRawSyncedLRC` — download flow (attach `.lrc` to downloads).
- Consumers: lyrics HUD, download metadata.