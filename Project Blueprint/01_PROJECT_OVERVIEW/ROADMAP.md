# Roadmap

Prioritized engineering + product plan derived from the blueprint audit. Docs-only — implementation is a separate task. Each item cites the finding that motivates it (raw-note risk IDs and `15_ISSUES_AND_RISKS/` docs).

Legend: effort S/M/L · priority P0 (fix now) / P1 (next) / P2 (later) / P3 (nice-to-have).

---

## Phase 1 — Correctness & user-visible gaps (P0)

Fixes for confirmed defects and missing core functionality. Small, independent, high impact.

| # | Goal | Motivation | Effort | Acceptance criteria |
| :--- | :--- | :--- | :--- | :--- |
| R1 | **Wire `MPRemoteCommandCenter` handlers** (play/pause/next/prev/seek/change-playback-rate) for both engines | `06_AUDIO/MEDIA_CONTROLS.md` — handlers absent; physical media keys, Control Center, Touch Bar widget dead | M | Media keys control online + offline playback; Now Playing info stays accurate |
| R2 | **Stop deleting liked-state at launch** | Risk A21 — `NowPlayingManager.init` removes `YTM_likedTrackKeysSet`/`YTM_lastIsLiked`; K1 | S | Like state survives relaunch; still re-syncs from JS truth |
| R3 | **Persist the download queue** | `13_WORKFLOWS/DOWNLOAD_WORKFLOW.md`, APP_SHUTDOWN — queue in-memory, jobs lost on quit | M | Quit/relaunch resumes pending downloads; `.downloading` sandboxes checkpointed |
| R4 | **Make engine mode observable** | Risk A1 — `Mooziac_EngineModeChanged` posted 3×, zero listeners; K1 area | S | Add listeners or remove the notification; UI reflects online↔offline switches |
| R5 | **Fix like-toggle toast inversion** | E25 / K12 — drawer toast uses pre-toggle value | S | Toast matches actual new state |
| R6 | **Fix gesture overlay inversion** | B19 / K13 — one of GestureMappingManager/KeyboardCommandHandler labels wrong | S | Play/pause overlays consistent across both paths |

## Phase 2 — Reliability & data integrity (P1)

| # | Goal | Motivation | Effort | Acceptance criteria |
| :--- | :--- | :--- | :--- | :--- |
| R7 | **Harden session restore** | B16/B17 / K22/K23 — 20 s watchdog vs slow networks; crash-restore only from `watch?v=` | M | Restore survives slow loads; watchdog state keyed to nav lifecycle |
| R8 | **Fix download cancel completion** | C20 / P13 — cancel branch can skip task completion callback | M | Cancel always fires completion + advances queue exactly once |
| R9 | **Check `sqlite3_step` results; atomic transactions** | C8/C1/P23 — silently dropped rows; open transactions on prepare failure | M | No silent row loss; transaction wrapper guarantees rollback |
| R10 | **Guard lyrics concurrency** | D-R2/K19 — `fetchRawSyncedLRC` stale-response race; E1 status-code handling | S | Request-ID guard; non-200 handled explicitly |
| R11 | **Remove per-launch legacy-key resets that users can change** | `13_WORKFLOWS/APP_STARTUP.md` — 10 keys removed every launch | S | Settings survive relaunch; only intended session keys reset |
| R12 | **Fix playlist drag-reorder under search filter** | F3 / P10 — unfiltered vs filtered index mismatch corrupts order | S | Reorder correct with active search filter in `.detail` |

## Phase 3 — Platform resilience (P1/P2)

| # | Goal | Motivation | Effort | Acceptance criteria |
| :--- | :--- | :--- | :--- | :--- |
| R13 | **Isolate Multitouch assumptions** | B8/B9/P4/P5 — raw stride reads, function-pointer bit-casts, hardcoded trackpad width | M | Version-guarded layout reads; graceful disable if layout mismatch detected |
| R14 | **Replace YTM DOM scraping with stable hooks** | A27, B24, F1 — dozens of brittle selectors; silent `try/catch` failures | L | Feature flags per capability; JS failure telemetry/logging; shared injected helpers |
| R15 | **Add retry/backoff for lyric providers** | `09_NETWORK/ERROR_HANDLING.md` — single-shot, no retry | S | Transient failures retry; user feedback on persistent failure |
| R16 | **Escape-validate interpolated IDs in JS** | C25/P29 — `videoId` into JS strings | S | Injection-safe; PM re-validates IDs |

## Phase 4 — Engineering hygiene (P2)

| # | Goal | Motivation | Effort | Acceptance criteria |
| :--- | :--- | :--- | :--- | :--- |
| R17 | **Dead-code removal** | `15_ISSUES_AND_RISKS/TECHNICAL_DEBT.md` (~30 items: inert audio engine, 7 dead toggles, empty stubs, stale `currentSchemaVersion`) | L | Compile-clean after removal; no behavior change (move-only verification via `swift build`) |
| R18 | **Deduplicate logic** | E9/E11/E12/F2 — artwork caches, download-state resolution, context menus, JS pause snippet | M | Shared helpers; single source of truth |
| R19 | **Add tests + CI** | Package.swift has zero test targets | L | Unit tests: `LocalDatabaseManager`, `SyncedLyricsParser`, matching gates, history dedup; CI runs `swift build` + tests |
| R20 | **Unify logging/error handling** | `09_NETWORK/ERROR_HANDLING.md` — fail-silent, no crash reporter | M | Central logger; non-silent user-facing errors for destructive paths |

## Phase 5 — Product expansion (P3, from README + audit)

| # | Goal | Motivation | Effort |
| :--- | :--- | :--- | :--- |
| R21 | Global hotkey customization UI | README roadmap | M |
| R22 | Built-in 10-band EQ (persisted, not per-page) | README; A10 | L |
| R23 | AirPlay 2 output picker | README roadmap | L |
| R24 | Lyrics HUD font-size/opacity customization | README roadmap | S |
| R25 | Trackpad gesture sensitivity tuning | B10, F8 | S |

---

## Sequencing notes

- Phases 1–2 are independent and can proceed in parallel by different owners.
- R1 (media keys) is the single highest-value user-facing item — it's the one feature in the README/blueprint that is entirely missing rather than incomplete.
- R14 (DOM coupling) is the highest-latent-risk item — a single YTM redesign can break autoplay, queue, likes, EQ, and restore at once, invisibly.
- R17/R18 (debt) should be batched AFTER R1–R6 to avoid conflating behavior changes with cleanup.
- Any phase-triggering production decision (e.g. R13 layout mismatch) should first be validated at runtime (blueprint marks these `UNKNOWN — requires runtime verification`).

## Related

- `01_PROJECT_OVERVIEW/PURPOSE_AND_GOALS.md` (existing non-goals/roadmap)
- `15_ISSUES_AND_RISKS/KNOWN_ISSUES.md`, `POTENTIAL_BUGS.md`, `TECHNICAL_DEBT.md`, `RISK_AREAS.md`
- Raw notes `99_APPENDIX/RAW_DISCOVERY_NOTES/`