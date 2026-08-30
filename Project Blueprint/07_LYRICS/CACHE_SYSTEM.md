# Cache System

Lyrics caching in Mooziac.

## Disk cache

| Attribute | Value |
| :--- | :--- |
| Location | `~/Library/Caches/Mooziac/Lyrics/` |
| Writer | `LyricsManager.saveToLocalLyricsCache` (after successful fetch) |
| Reader | `LyricsManager.fetchLyrics` (cache-hit short-circuit) |
| Format | LRC text files (per-track) |
| Keying | per-track identifier |
| Lifecycle | app-lifetime; no explicit eviction/cleanup found |
| Failure | write errors swallowed (`try?`); missing cache = normal miss path |

## Sidecar `.lrc` files

| Attribute | Value |
| :--- | :--- |
| Location | alongside audio files in the music folder (`~/Music/Mooziac`) |
| Writer | user/external (not the app) |
| Reader | `LyricsManager` (offline path, `LocalTrack.lrcURL`) |
| Format | standard LRC |

## Behavior notes

- Cache-hit path returns **synchronously on the caller thread** while all miss paths return async on main — an inconsistent contract that callers must handle (see risks).
- No staleness/versioning on cached lyrics; no cleanup mechanism.
- Cache is unencrypted plain text (privacy note in `12_SECURITY/PRIVACY.md`).

## Related

- `08_DATA/CACHE.md` (all caches), `07_LYRICS/LYRICS_PIPELINE.md`.