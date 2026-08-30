# Key Storage

How credentials and sensitive values are handled.

## What exists

| Item | Stored where | Format | Notes |
| :--- | :--- | :--- | :--- |
| YouTube session cookies | WKWebView persistent data store (system `~/Library/WebKit` domain) | system-managed | app never reads/writes cookie values |
| `YTM_hasLoggedInOnce` | UserDefaults | boolean | non-sensitive marker |
| Discord presence data | transient memory + IPC | JSON | no auth keys |
| Downloads | filesystem | media | no credentials |

## What does NOT exist

- ❌ No OAuth client id / client secret / API keys embedded in the binary.
- ❌ No Keychain usage (`SecItem*` calls: none found).
- ❌ No token files (`credentials.json`, `client_secret*.json` are gitignored legacy artifacts, not app-read).
- ❌ No user-supplied passwords stored.
- ❌ No HTTP `Authorization` headers constructed.

## Sign-in flow (no stored secrets)

```
Sign in via UI → loadGoogleLogin() → WKWebView shows Google/YTM auth page
  → user completes flow in webview (single-window auth, targetFrame nil → reuse)
  → cookies written to WKWebView persistent store by system
  → app detects sign-in via cookie/SAPISID presence → Mooziac_SignInStatusChanged
```

The app never extracts or persists the credential material itself — it relies on WebKit's data store, which the OS owns and protects.

## Clearing

- Login-reset: `WKWebsiteDataStore` all data removed → effectively logs the user out of YouTube in-app.
- `flushSessionState(keepCookies: false)` removes `YTM_lastUrl/VideoId/Time/Title/Artist` session keys (keeps `YTM_lastArtwork` — asymmetry risk).
- `URLCache.shared.removeAllCachedResponses()` clears web caches on session flush.

## Risks

- If cookies are unencrypted-at-rest in the WebKit data store, a local attacker with user-level access could exfiltrate the session — this is the standard macOS WebKit model, **not app-specific**.
- Session keys in UserDefaults (`YTM_last*`) include plaintext track URLs/ids — low sensitivity.
- No mitigation for clipboard/screen capture of auth pages (out of scope for a menu-bar player).

## Related

- `12_SECURITY/SECURITY_ARCHITECTURE.md`, `PRIVACY.md`.