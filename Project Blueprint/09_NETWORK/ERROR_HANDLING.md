# Error Handling

How network and I/O failures are handled across the app.

## Philosophy

Mooziac is **fail-silent / degrade-gracefully** by design: most network failures produce `nil`/`[]` and the UI falls back rather than surfacing errors.

## By subsystem

### Lyrics (`LyricsManager`)
| Failure | Handling |
| :--- | :--- |
| Non-200 HTTP (incl. HTML body) | treated as empty → next tier (**status codes ignored**, risk E1) |
| JSON decode failure | `[]` → fallback |
| LRCLib/Lyrics.ovh down | Tier fallthrough → HUD shows "title • artist" |
| Cache write failure | swallowed (`try?`) |
| In-flight task replaced | `currentTask?.cancel()` |
| Stale response | `requestID == currentRequestID` guard in fetchLyrics (missing in `fetchRawSyncedLRC`) |

### WebKit (YTM)
| Failure | Handling |
| :--- | :--- |
| WebContent process crash | `webViewWebContentProcessDidTerminate` → re-inject + restore playback |
| Page never becomes ready | `recoveryWatchdog` (20 s) re-tries restore |
| JS eval failures | `try? evaluateJavaScript` (silent) |
| Network offline | `NetworkMonitor` → offline mode; UI reflects state |

### Downloads (`DownloadManager`)
| Failure | Handling |
| :--- | :--- |
| yt-dlp/ffmpeg missing | job fails; startup warning path |
| Network interruption | `NetworkMonitorReconnected` → requeue handling |
| Partial/failed download | cleanup `.downloading` artifacts; job marked failed; queue continues |
| Restart with stale downloads | `cleanupStaleDownloads` on startup |

### Discord (`DiscordRPCManager`)
| Failure | Handling |
| :--- | :--- |
| Socket missing (Discord closed) | silent no-op |
| Write error | silent; retry on next state change |

### Database (`LocalDatabaseManager`)
| Failure | Handling |
| :--- | :--- |
| Corrupt DB at open | delete + rebuild from scratch (**data loss** — logged) |
| Prepare/step errors | some paths ignored (risks) |
| DB nil (rebuild failed) | guarded no-ops |

### Artwork (`AppArtworkHelper`)
| Failure | Handling |
| :--- | :--- |
| Download failure | `nil` → default artwork icon |

### File system (library scan)
| Failure | Handling |
| :--- | :--- |
| Unreadable/unparseable audio | skipped (format-filtered) |

## Error surfacing summary

- **To user:** none for network; toasts only for volume and a few explicit actions.
- **To logs:** `print`/`os_log` scattered; no unified logger.
- **To crash/analytics:** none — no crash reporter/telemetry.

## Structural risks

- URLSession completions on non-main threads (lyrics raw fetch, notification artwork) → potential UI races.
- Errors in `try?` swallow context needed for diagnosis.
- No retry/backoff for lyric providers; single-shot per track.
- `recoverCorruptDatabase` destroys user data silently (logged only).

## Related

- `09_NETWORK/REQUEST_PIPELINES.md`, `15_ISSUES_AND_RISKS/RISK_AREAS.md`.