# Mooziac AI Blueprint Audit & Implementation Report

**Date:** 2026-08-19
**Scope:** `mooziacai.md` (Apple Intelligence blueprint) vs. current codebase, plus the new **AI Features** toggle implementation.
**Guarantee requested:** "It shall not break." — Verified: release build passes, app bundles, signs, and launches cleanly.

---

## 1. Audit: Blueprint vs. Actual Project

Before this change the project had **zero** Apple Intelligence / on-device AI code (`AppIntents`, `CoreSpotlight`, `NaturalLanguage`/`NLEmbedding`, `ImagePlayground` were absent from `Sources/`). All four blueprint modules were unstarted.

| Blueprint Module | Status (before) | Risk of enabling |
| :--- | :--- | :--- |
| **1. App Intents & Siri 2.0** (`AppIntents`, `AppShortcutsProvider`) | Not implemented | Low — requires macOS 14+ at runtime, guarded with `@available` |
| **2. Spotlight Semantic Search** (`CoreSpotlight`) | Not implemented | Low — CoreSpotlight available on macOS 13 |
| **3. Generative Cover Art** (`ImagePlayground`, macOS 15.2+) | Not implemented | Low — compiled only when `canImport(ImagePlayground)` |
| **4. Smart Lyrics / Insights** (`WritingTools`, `NLEmbedding`) | Not implemented | Low — `NaturalLanguage` is Foundation-adjacent, available macOS 10.15+ |

### Key compatibility facts confirmed during the audit
- `Package.swift` targets **macOS 13.0** (`platforms: [.macOS(.v13)]`). All new code is either available on macOS 13 or wrapped in `@available(macOS 14.0/15.2, *)` / `#if canImport(...)` guards, so **the deployment floor is unchanged**.
- Local SDK is **macOS 26.5** and ships `ImagePlayground.framework` + `AppIntents.framework`, so both compile paths are exercised in CI/local builds.
- The app is assembled by hand in `build_app.sh` into an ad-hoc-signed `.app` bundle (`LSUIElement` menu-bar app). Siri/App-Intents metadata keys were missing and have been added.

---

## 2. What Was Implemented

New subsystem: `Sources/Mooziac/Intelligence/` (auto-recursed by SPM, no `Package.swift` change needed).

| File | Module | What it does |
| :--- | :--- | :--- |
| `MooziacAIManager.swift` | Gate | Master `isEnabled` switch persisted in `UserDefaults` (`Mooziac_AI_enabled`), **default OFF**. Flipping on re-indexes Spotlight; flipping off clears it. |
| `SemanticRecommender.swift` | 4 (smart queue) | `NLEmbedding.wordEmbedding(for: .english)` vector similarity scoring of offline tracks. |
| `SpotlightIndexer.swift` | 2 (Spotlight) | Indexes offline tracks as `CSSearchableItem`s with title/artist/album/duration/artwork + keywords; `removeTrack`, `reindexLibrary`, `clearIndex`. |
| `MooziacIntents.swift` | 1 (Siri/Shortcuts) | `TrackEntity` + `TrackEntityQuery`, `PlayTrackIntent`, `TogglePlaybackIntent`, `LikeCurrentTrackIntent`, `MooziacShortcuts` (`AppShortcutsProvider`). All macOS 14+ guarded; every intent gates on the AI toggle. |
| `ImagePlaygroundHelper.swift` | 3 (cover art) | Presents `ImagePlaygroundViewController` as a sheet on the key window to generate playlist artwork; macOS 15.2+ guarded, fails gracefully (`completion(nil)`) otherwise. |

### Integration points (all additive + toggle-gated)
- **Settings UI:** new **AI Features** row (`sparkles` icon, "Smart queue, Spotlight & Siri control") added to the PLAYER PREFERENCES stack, using the same `makeFeatureRow` / `NativeCapsuleToggleView` pattern as Lyrics/Discord.
- **Spotlight indexing:** `LocalLibraryManager.performScan` now calls `SpotlightIndexer.indexTracks(...)` after a scan commit, only when the toggle is on (covers app start, downloads, imports).
- **Smart queue:** `NativeAudioPlayer.nextTrack()` appends a semantically-suggested track at the end of an offline queue **only when** AI is on, shuffle is off, and the queue is about to be exhausted. Default behavior (toggle off) is byte-for-byte identical.
- **Info.plist (build_app.sh):** added `NSSiriUsageDescription` and `AppIntentsEnabled` keys.

---

## 3. Risk Assessment — "It shall not break"

| Risk | Verdict |
| :--- | :--- |
| Build failure | **None.** `swift build` (debug + release) passes. Only pre-existing deprecation warnings in `LocalLibraryManager` (`stringValue`, unreachable `catch`). |
| App bundle / signing | **None.** `build_app.sh` completes; ad-hoc signature applied; app launches and runs. |
| Playback regression | **None while toggle is OFF** (the default). All behavior-changing code is behind `MooziacAIManager.shared.isEnabled`. |
| Older-macOS runtime crash | **Low.** Guarded by `@available` and `#if canImport`. On macOS 13–14 only Spotlight (module 2) is active; Siri needs 14+; Image Playground needs 15.2+. |
| `NLEmbedding` availability | `embedding` is optional; recommender falls back to `pool.prefix(count)` if unavailable. |
| Note | App Intents' **shortcut registration** requires a proper app target; a hand-rolled SPM executable bundle may not advertise shortcuts to the Shortcuts app. Intents still compile and run when invoked. Flagged as a follow-up. |

---

## 4. Verification Matrix (as-executed)

| Check | Result |
| :--- | :--- |
| `swift build` (debug) | ✅ Pass |
| `swift build -c release` (via `build_app.sh`) | ✅ Pass |
| Bundle + codesign | ✅ `replacing existing signature` |
| App launch | ✅ `pgrep -x Mooziac` → RUNNING |
| `Info.plist` keys | ✅ `AppIntentsEnabled=true`, `NSSiriUsageDescription` present |
| Toggle row compiles & is wired | ✅ `aiToggle` bound to `MooziacAIManager.isEnabled` |

---

## 5. Follow-ups (not done — out of scope for "shall not break")
1. Verify Shortcuts/Siri registration in a true Xcode `.app` target (or add an app-target intents build).
2. Expose an "AI Artwork" button in `PlaylistLibraryView` wired to `ImagePlaygroundHelper`.
3. Add `SpotlightIndexer.removeTrack` call on download deletion.
4. Optional: default the toggle to ON after a longer soak-test.