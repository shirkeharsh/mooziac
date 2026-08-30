# Fix 26 — Risk-Assessment Gate (K/P/R items: reference/test only)

Status: NO implementation changes made. This report records exact callsites,
current behavior, failure conditions, crash/visible risk, and required
regression coverage for the excluded K/P/R items so they can be scoped
separately later.

## K-series (excluded risk areas)

### K1 — Liked-state purge in `init()`
- Callsite: `Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift:48-49`
- Behavior: `override init()` unconditionally removes
  `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` on every launch. These are
  written by `ObserverBridge.swift:434` on track change and read back by
  `DynamicIslandPlayerView/Core.swift:203` (`restoreSavedState()`).
- Failure: last-liked indicator always resets to "not liked" at startup.
- Risk: removing the purge could restore stale JS truth; keeping it can
  desync the indicator from YTM account state. Do not remove without a
  before/after audit of DB state vs Swift state vs YTM JS state.
- Regression coverage: startup liked-state characterization (DB vs Swift vs
  JS), like-state persistence across relaunch, Like/Unlike round-trip.

### K6 — Like-sync gating
- Callsite: `Sources/Mooziac/Managers/LikedSongsManager.swift:125-161`
  (`syncUnsyncedToAccount` / `syncNext`); secondary
  `PlayerControls.swift:550-616` (`toggleLike`).
- Behavior: background sync plays each unsynced video and unconditionally
  calls `clickLikeButton()` (~line 151) then `readLikeState` after delays.
  No guard against a fresh user Like/Unlike during the sync window.
- Failure: a background sync click can overwrite a just-made user toggle.
- Risk: user like state corruption / account desync; visible heart flips.
- Regression coverage: stress background sync against simultaneous user
  Like/Unlike; confirm fresh user change wins; no stale overwrite.

### K3/K4 — Playback-adjacent JS injection
- Callsite: `PlayerControls.swift:106-185` (`togglePlayPause`/`pause`/`play`
  injected JS); secondary `NowPlayingManager.swift:21-36` (`playOfflineTrack`),
  `ObserverBridge.swift:242-287` (`bindVideoEvents`).
- Behavior: play/pause driven by injected JS (`playVideo()/pauseVideo()` or
  direct `video.play()/pause()`); direct video-element manipulation bypasses
  YTM's state machine and can race the DOM observer.
- Risk: state-machine desync, duplicate or dropped play/pause, mid-song
  flicker. No changes here in this batch.

### K7–K11 — JS injection / WebAudio / queue math
- WebAudio/EQ: `PlayerControls.swift:618-674` (`setEQPreset`) — creates
  `AudioContext`, `createMediaElementSource(video)`, chains 3 biquad filters,
  re-routes the element audio. Risk: detaching element from YTM audio
  pipeline.
- Queue extraction: `Core/NowPlayingManager/Queue.swift:6-175`
  (`fetchQueue`) — scrapes `ytmusic-player-queue` and, when short, clicks the
  automix/radio UI to force "Up Next" population (mutates user queue state).
- Queue insertion math: `NativeAudioPlayer.swift:53-82`
  (`playNext`/`appendToQueue` insert at `currentIndex+1`);
  `PlaylistManager.swift:733-764` (shuffle/startIndex math, `loadVideoById`
  JS at 822-852).
- Risk: unexpected queue mutation, wrong insert position, EQ breaking
  playback audio.

### K15 — Drag reorder
- Callsite: `Views/Libraries/PlaylistLibraryView.swift:2245-2281` (drag
  source/drop reorder via `reorderItems`); secondary
  `SettingsPanel.swift:3244-3293` (playlist detail stack + pan gesture);
  persistence `LocalDatabaseManager.swift:1083-1102`.
- Risk: incorrect reorder persistence, ghost rows, index drift during drag.

### K17 — Mouse event behavior
- Callsite: `Core/StatusItemManager/StatusItemManager.swift:411-459`
  (local+global mouse monitors auto-close panel); scrollWheel monitor ~107;
  `SwipeToDeleteContainerView.swift:75-148,418-473`; `Core.swift:1113-1137`
  (double-click expand/collapse, click-outside collapse).
- Risk: panel auto-close races, swallowed clicks, swipe/drag conflicts.

## P-series (callsite + invariant)

### P8 — Lock-vs-sleep / auto-pause
- Callsite: `NowPlayingManager.swift:69-85` (`setupSleepObservers`);
  `AudioRouteMonitor.swift:78-92` (auto-pause on device change, gated by
  `guard !isSleeping`).
- Invariant: JS playback control is suppressed during sleep/lock
  (`evaluateJS`/`evaluateJSWithResult` return early, 247-276), while
  `BackgroundMediaController.swift:18-53` + `AppDelegate.swift:23` prevent
  idle system sleep during playback.
- Risk: conflicting sleep-policy behaviors; auto-pause firing on unlock.

### P9 — autoPlay JS selector behavior
- Callsite: `Web/YTMWebView.swift:250-352` (`autoPlayJS`, 250ms polling up to
  30 attempts); duplicate in `Core/MainViewController.swift:237-347` (5
  staggered injections 0.4-2.5s).
- Invariant: first play button clicked then `playVideo()` forced.
- Risk: aggressive synthetic clicks + forced play on fresh pages; double
  injection from two locations.

### P15 — Shuffle insertion
- Callsite: `NativeAudioPlayer.swift:32-82` (`shuffledQueue = queue.shuffled()`,
  `playNext` inserts at `currentIndex+1`); `PlaylistManager.swift:737-744`
  (shuffles then inserts `startItem` at index 0).
- Invariant: insertion position computed against `currentIndex` rather than
  the track's shuffle position.
- Risk: non-random-feeling insertions, duplicated or skipped tracks.

### P16 — Normalization / matching
- Callsite: `LocalTrack.swift:64-70` (`cleanTitle`/`cleanArtist` →
  `LyricsManager.cleanSongInfo`); `LyricsManager.swift:48-64`
  (`normalizeForMatch`) and `83-123` (`matchScore`, hard duration gate,
  Jaccard ≥ 0.6). Used by lyric lookup, local-track search matching
  (`MainViewController.swift:350-391`), and dedupe
  (`LocalLibraryManager.swift:248`).
- Risk: false-positive/negative track matches from normalization edge cases.

### P22 — Move-up/down UI reorder
- Callsite: `PlaylistLibraryView.swift:1407-1425` (`handleContextMoveUpItem`/
  `handleContextMoveDownItem`, `swapAt` + `reorderItems`); context items at
  1147-1157, 2014-2024 with bounds checks.
- Risk: index drift after reorder, out-of-sync ordered ID list.

### P26 — Schema migration
- Callsite: `LocalDatabaseManager.swift:275-313` (`applySchemaIfNeeded`,
  gated by `PRAGMA user_version`); migrations V1-V4 at 335-417; one-time
  liked-keys migration `migrateLikedKeysFromUserDefaultsIfNeeded` at 655-666
  (called from `LocalLibraryManager.swift:173`).
- Invariant: no migration beyond V4; upgrade path V1→V4.
- Risk: migration failure on corrupt/partial DBs; new schema would need a
  fresh migration version.

### P28 — Async artwork finalization
- Callsite: `AppArtworkHelper.swift:161-199` (`loadThumbnail` async via serial
  `ioQueue`); sync `getThumbnail` at 134-159 invoked from `LocalTrack.artwork`
  getter (`LocalTrack.swift:13-21`) — any UI touch can block. Online path:
  `ArtworkTheme.swift:6-34`.
- Invariant: memory → disk → extract pipeline; disk writes atomic.
- Risk: main-thread blocking on sync path; stale/partial thumbnails.

### P33 — Content-rule precompile
- Callsite: `Web/YTMWebView.swift:92-96` — `WKContentRuleListStore.compileContentRuleList`
  runs asynchronously and the compiled list is added in the completion; no
  error handling/logging.
- Risk: ad-block rules may not be installed before first page load; silent
  compile failure.

### P35 — Focus / window behavior
- Callsite: `AppDelegate.swift:8` (`NSApp.setActivationPolicy(.accessory)`);
  `StatusItemPanel.swift:7,16-28` (nonactivating panel, `canBecomeKey`/`Main`
  true); `StatusItemManager.swift:356-383` (`showPanel`/`closePanel`);
  `Core.swift:1139-1159` (keyDown routing to `KeyboardCommandHandler`).
- Invariant: menu-bar app never activates as a normal app; panel can take
  keyboard focus without activation.
- Risk: focus-steal, key event routing conflicts, panel dismissal races.

## R-series (excluded systemic architecture)

- R1–R4, R6–R8 remain separate architecture areas.
- Narrow drafts already shipped in this batch:
  - Fix 22 → R4 engine-mode observability (done)
  - Fix 23 → R3 queue persistence (done)
  - Fix 24 → R1 Part A selector fallback (done)
  - Fix 25 → R1 Part B health telemetry (done)

## Batch verification (per final safety prompt)

1. Online → offline → online playback — PASS
2. Media keys — PASS
3. Like/unlike — PASS
4. History — PASS
5. Download queue/cancellation — PASS
6. Relevant UI state — PASS

No excluded K/P/R item was implemented as part of Fixes 1–25.