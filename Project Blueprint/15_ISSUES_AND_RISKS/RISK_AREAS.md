# Risk Areas

Systemic risk themes and their exposure.

## 1. JS/DOM coupling to YouTube Music internals

**Exposure:** High — core features break silently.
- Dozens of DOM selector strings (`ytmusic-av-toggle`, `ytmusic-player-queue`, `ytmusic-like-button-renderer`, `#button-shape-like button`, `ytmusic-card-shelf-renderer`, `ytmusic-responsive-list-item-renderer`), Polymer data-model access, `SAPISID`/`__Secure-*PAPISID` cookie heuristics.
- All wrapped in `try/catch` → failures invisible.
- YTM redesigns or A/B DOM changes can silently kill autoplay, queue ops, like/eq detection, restore.
- Mitigation: none (no feature flags, no fallback detection).

## 2. Concurrency & threading

**Exposure:** Medium — latent races.
- Main-thread funnel + URLSession/queue completions off-main.
- Data races: Multitouch flag reads (B7), `lastBroadcastProgress` (C3), `activeProcess` (C4), `activeContext` (C5), artwork `ioQueue` concurrent (D-R4).
- DB: FULLMUTEX assumed; mixed prepared statements across threads; transaction groups not atomic under an exception.
- Lyrics cache-hit threading contract inconsistent (D-R1).
- No central engine-mode mutex (B15).

## 3. Private API / fragile platform assumptions

**Exposure:** Medium-High — breaks on OS updates.
- Multitouch framework: raw `loadUnaligned`, hardcoded 96-byte strides, function-pointer bit-casts, hardcoded trackpad width.
- CoreAudio output-device listener; IOPMAssertion; global `URLCache` mutation.
- Window-class string matching (`"Status"/"StatusBar"`) for status-bar target.

## 4. Silent data loss

**Exposure:** Medium — user-visible.
- `recoverCorruptDatabase` deletes + rebuilds (data loss, logged only).
- Per-launch deletion of liked-state keys.
- Swallowed write errors (`try?`), ignored `sqlite3_step` results, silent row drops.
- In-memory download queue lost on quit (stale sandboxes cleaned).

## 5. Feature dead-ends / half-finished features

**Exposure:** Medium — misleading.
- `Mooziac_EngineModeChanged` inert (no listeners) — engine switching unobservable.
- `BackgroundMediaController` audio engine scaffold dead.
- `MPRemoteCommandCenter` handlers absent — physical media keys, Control Center, and Touch Bar playback widget do NOT control the app (`UNKNOWN — requires runtime verification`).
- EQ per-page ephemeral; `.native` PlayerDesign unreachable (maps to `.adaptive`); `RepeatMode` has no repeat-all enum value.

## 6. Security & privacy posture

**Exposure:** Low-Medium.
- Un-sandboxed; full user filesystem access.
- History/likes/lyrics unencrypted plaintext.
- Cookie names enumerated for sign-in detection (values never read).
- Discord presence leaks listening habits (by design).
- No keychain, no API keys, no telemetry (positive).

## 7. Performance

**Exposure:** Low-Medium.
- Full-library view rebuild per drawer action (O(n) view creation).
- Main-thread DB reads per row on scroll.
- Per-call `DateFormatter`; per-call `sqlite3_prepare`.
- 0.1 s HUD timer + 0.25 s broadcast + waveform redraw contention on main.
- `Data(contentsOf:)` synchronous artwork fetch can stall download queue.

## 8. Resilience / error handling

**Exposure:** Medium.
- Fail-silent design: most errors produce nil/[] with no user signal.
- No retry/backoff for lyrics providers; single-shot.
- No unified logging; no crash reporter.
- HTTP status codes ignored in lyrics.

## Risk register (by likelihood × impact)

| Risk | Likelihood | Impact |
| :--- | :--- | :--- |
| YTM DOM change breaks JS features | High | High |
| OS update breaks Multitouch/CoreAudio assumptions | Medium | Medium |
| Data loss on DB rebuild / liked-state reset | Low-Med | Medium-High |
| Race in download cancel path (missed completion) | Low | Medium |
| Media keys non-functional | High (confirmed absent) | Low-Med |
| Hotkey permission friction | Medium | Low |

## Related

- `15_ISSUES_AND_RISKS/KNOWN_ISSUES.md`, `POTENTIAL_BUGS.md`, `TECHNICAL_DEBT.md`, `00_INDEX/COVERAGE_CHECKLIST.md`.