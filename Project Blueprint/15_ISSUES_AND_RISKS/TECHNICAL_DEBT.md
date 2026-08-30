# Technical Debt

Structural and quality liabilities (not necessarily bugs).

## Dead code & unused members

| Item | Source |
| :--- | :--- |
| `Mooziac_EngineModeChanged` posted 3×, **zero listeners** | A1 |
| `BackgroundMediaController.audioEngine`/`audioPlayerNode` never assigned | A2 |
| 7 dead toggles/selectors (`toggleMasterGestures`, `toggleAutoPauseOnDisconnect`, `toggleRightEdgeVolume`, `toggleRightCornerTaps`, `toggleLeftCornerTaps`, `StatusItemManager.toggleFromMenu`, `toggleCenteredLyricsFromMenu`) | A3 |
| `NowPlayingManager.lastTrackChangeTime` written never read | A4 |
| `NativeAudioPlayer.itemEndObserverToken` declared, never used | B1 |
| `ClickSound.stop()` no-op stub; `setupAudioSession()` empty stub | B27/28, E8 |
| `Carbon` import unused (NSEvent monitors used); `WebKit` import unused in AppVolumeManager | B18/12 |
| `LocalDatabaseManager.currentSchemaVersion = 3` stale (real = 4); `filePaths(byVideoID:)` no callers | C13/14 |
| `PlaylistManager.currentNowPlayingVideoID`, `localTracks(in:)`, `appendCurrentTrack(to:)`, `clearActiveContext()` dead | C15 |
| `NetworkMonitor.stopMonitoring()` no callers; `DiscordRPCManager.deinit` effectively dead | D3/4 |
| `HistoryManager.pendingStartTime`/`pendingRecord`/`hasCommittedCurrentPending`/`commitTimer` — abandoned timer design | D1 |
| `LocalTrack` imports AVFoundation unused; `LocalTrack.init(isLiked:)` ignored | D2/5 |
| `LaunchAnimationTimeline` model unused (controller uses hardcoded timings) | E7 |
| DynamicIsland dead delegates (`dynamicIslandDidTapShuffle/Repeat`), `isRepeatActive`, `themeSlider`, `themeSectionLabel`, `flashGlowOnButton`, 6 drawer handlers | E1-6 |
| `PlaylistLibraryViewDelegate.playlistLibraryDidPlayOnline` no in-file invocation; `InteractiveWaveformProgressView.formatTime` external caller unknown; ReactiveIconButton animation methods uncalled; `NSGestureRecognizerDelegate` unimplemented | F4 |

## Duplicated logic

| Duplication | Source |
| :--- | :--- |
| JS pause IIFE pasted in `playCurrentTrack()` and `play()` | B2 |
| 3× per-cell static `webImageCache` + `currentArtworkKey` (~60-line artwork blocks) in PlaylistItemRowCellView/HistoryRowCellView/LikedSongRowCellView | F2 |
| Download-state resolution 4× (Core.updateDownloadButtonState, DetailItemRowView, HistoryRowView, history scan) | E9 |
| `handleDoubleAction`/`handleReturnAction` byte-identical switch bodies | F3 |
| `fetchHistory` + `fetchHistoryCount` duplicate dedup CASE expression | C17 |
| Context-menu builders `contextMenu(for:)` ×4 near-identical | E12 |
| `makeFeatureRow` vs `makeThemeFeatureRow`/`makeProgressStyleFeatureRow` copy/paste | E11 |
| Status-bar target math duplicated (`LaunchAnimationController.play` vs `computeStatusItemTarget`, slightly different fallbacks) | E13 |
| Download dedup logic differs between `queueTrack` (title wildcard) and `queueTracks` (signature set) | C18 |
| Dead JS helper `window.clickYTMElement` defined, never called | A28 |
| `findAndPlayTopTrack`/`simulateClick` re-implemented across observerJS/PlayerControls/Queue | A28 |
| `AppVolumeManager.setEffectiveVolume` identical overlay blocks in both branches | B13 |
| DB index `idx_tracks_yt_video_id` created in v1 AND migrateToV2 (IF NOT EXISTS harmless) | C32 |
| `refreshPlaylistsSection` + `resetPlaylistSectionChrome` + `updateSettingsThemeHighlight` cascade after every drawer action | E22 |

## Architectural debt

| Item | Source |
| :--- | :--- |
| Singletons + NotificationCenter throughout; no DI/protocols; hard to test | (observed) |
| All threading funneled to main; background tasks via ad-hoc queues; data races in flags | B7, C1-7 |
| JS/DOM selector strings scattered across ObserverBridge/PlayerControls/Queue/YTMWebView — brittle, silent failure (try/catch) | A27 |
| No unified logging/error reporting; `print` scattered; errors swallowed with `try?` | E14, D-E1 |
| No test targets in Package.swift; no CI | (observed) |
| Build app bundle assembled by hand (build_app.sh); assets must be manually added to copy block | AGENTS.md |
| Per-call `sqlite3_prepare` (no statement reuse); FULLMUTEX assumed for cross-thread safety | C30 |
| `DateFormatter` allocated per `HistoryRecord.relativePlayedTimeString` call | C28 |
| Main-thread DB reads in table `viewFor` per scroll reuse | F16 |
| Hardcoded absolute developer paths in `AppArtworkHelper` (lines 42–43) | D-F3 |
| Legacy `YTM_is*` and current `YTM_v3_*` setting variants — inconsistent read paths | (observed) |
| `spotifyPlayerDidTapLogin` misnamed legacy method | A30 |

## Related

- `15_ISSUES_AND_RISKS/KNOWN_ISSUES.md`, `POTENTIAL_BUGS.md`, `RISK_AREAS.md`.