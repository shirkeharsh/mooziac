# Privacy

What personal data Mooziac collects, stores, and shares.

## Data stored locally

| Data | Where | Persistence |
| :--- | :--- | :--- |
| Listening history (title, artist, album, artwork URL, video id, file path, played_at, duration, source) | `library.sqlite3` → `listening_history` | persistent, plaintext |
| Liked songs (title/artist/album/artwork/duration/date) | `library.sqlite3` → `liked_songs` | persistent, plaintext |
| Offline library metadata | `library.sqlite3` → `tracks` | persistent, plaintext |
| Playlists | `library.sqlite3` → `playlists`/`playlist_items` | persistent, plaintext |
| Lyrics (fetched) | `~/Library/Caches/Mooziac/Lyrics/` | persistent, plaintext |
| Artwork thumbnails | `~/Library/Caches/Mooziac/Thumbnails/` | persistent |
| Downloaded audio | music folder | persistent |
| Last-session state (`YTM_lastTitle/Artist/Artwork/Url/VideoId/Time/Duration`) | UserDefaults | persistent, plaintext |

## Data shared externally

| Recipient | What | When |
| :--- | :--- | :--- |
| YouTube Music (WebKit) | playback/session (via cookies) | app use |
| LRCLib | artist + track name (query) | lyrics fetch |
| Lyrics.ovh | artist + track name (path) | lyrics fallback |
| YouTube (yt-dlp) | video URL/id | downloads |
| Discord | currently playing title/artist/artwork URL/page URL | presence enabled (`YTM_discordRPC_enabled`) |
| Track notification artwork | `<tmp>/ytm_art_*.jpg` (local only) | notifications |

## Absent data practices

- ❌ No analytics / telemetry / crash reporting.
- ❌ No user account, no signup.
- ❌ No contact/address-book/location/calendar access.
- ❌ No cookies read or copied by the app (WebKit owns them).
- ❌ No data export/delete UI (history can be cleared via context menu; `clearHistory`).

## Retention & deletion

| Data | Deletion path |
| :--- | :--- |
| History | `clearHistory()` (context menu) / entry delete |
| Liked songs | unlike → removed from `liked_songs` |
| Downloads | file removal + DB cleanup (`handleTrackDeleted`) |
| Session state | `flushSessionState(keepCookies: false)` (keeps `YTM_lastArtwork`) |
| Cookies | login-reset clears `WKWebsiteDataStore` |
| Caches | none app-initiated (OS-managed) |

## Risks / caveats

- History and likes are **plaintext** — sensitive if machine is shared.
- Lyrics cache and artwork cache are unencrypted.
- No encryption-at-rest for any local data.
- Discord presence can leak listening habits to observers of the user's Discord profile.
- URL query of lyrics includes full artist/title — unavoidable for the feature.

## Related

- `12_SECURITY/SECURITY_ARCHITECTURE.md`, `08_DATA/STORAGE.md`.