# Security Architecture

Security posture of Mooziac. Mechanisms only; no secrets, cookies, or credential values.

## Overview

Mooziac is an **un-sandboxed** menu-bar app (no entitlements, ad-hoc signed) that relies on:
1. **Cookie-based sign-in** to YouTube Music via WKWebView's persistent data store (no first-party token/API auth).
2. **Standard macOS privacy boundaries** (no TCC-gated data accessed; no keychain use).
3. **Defense by isolation**: downloads sandboxed in `.downloading/<jobId>/` until finalized.

## Trust boundaries

| Boundary | Notes |
| :--- | :--- |
| App ↔ Web (YT Music) | WebKit in-process; JS bridge via `nowPlayingHandler` messages; content-blocking rules applied (`YTMBlockRules`) |
| App ↔ Discord IPC | local UNIX socket; presence payloads only |
| App ↔ yt-dlp/ffmpeg | subprocess invocation with user-controlled URLs |
| App ↔ filesystem | full user access (no sandbox); music folder + App Support + Caches |

## Sign-in model

- Sign-in state is inferred from WebKit cookies (`isSignedIn`, SAPISID presence detection in `YTMWebView`).
- `YTM_hasLoggedInOnce` boolean persisted in UserDefaults (non-sensitive marker only).
- **Cookie clearing**: `ContextMenu` login-reset clears `WKWebsiteDataStore` all data; `flushSessionState(keepCookies: false)` additionally removes `YTM_last*` session keys (except `YTM_lastArtwork` — asymmetry, see risks) so stale session data doesn't resurrect sign-in state.
- No OAuth client id, no access token, no refresh token stored anywhere in the app.

## Data classification

| Data | Sensitivity | Storage |
| :--- | :--- | :--- |
| YouTube session cookies | high | WKWebView data store (system-managed) |
| Listening history | medium (PII) | SQLite plaintext |
| Liked songs | medium | SQLite plaintext |
| Downloaded audio | medium | user Music folder plaintext |
| Lyrics cache | low | Caches plaintext |
| Track metadata | low | UserDefaults/SQLite |
| Discord activity | low | transient IPC |

## Threat notes

| Threat | Posture |
| :--- | :--- |
| Secrets exposure | none present (no API keys in binary) |
| URL scheme | `mooziac://` declared; handling behavior minimal |
| Web content | content-block rules; WebKit defaults (no custom scheme handlers found) |
| Subprocess injection | URLs passed to yt-dlp are user/library-derived; no shell string interpolation found (Process args) |
| Disk forensics | history/likes/lyrics stored unencrypted |

## Related

- `12_SECURITY/KEY_STORAGE.md`, `PERMISSIONS.md`, `PRIVACY.md`, `09_NETWORK/API_CATALOG.md`.