# Mooziac — Queue Feature Blueprint & System Design

> **Scope contract:** This document tracks ONLY the Queue feature. All changes must stay within the
> files/functions listed below. Anything outside the Queue requires explicit user permission.

## 1. Project Context (Queue-relevant)

- **App:** Mooziac — macOS menu-bar floating YouTube Music client (SwiftPM, AppKit, no external deps).
- **Entry:** `Sources/Mooziac/main.swift` → `AppDelegate` → `StatusItemManager.shared` → `MainViewController` (hosts the `WKWebView` wrapping YouTube Music).
- **Player HUD:** `DynamicIslandPlayerView` is hosted by `FloatingIslandWindowController`.
- **Playback core:** `NowPlayingManager` (singleton) polls the WebView via injected JS and exposes playback state + queue actions.
- **Build:** `swift build` (debug) / `build_app.sh`.

## 2. Queue Architecture

```
WKWebView (YouTube Music DOM / Polymer data model / playerApi)
        │  evaluateJavaScript(...)
        ▼
NowPlayingManager  (queue data + queue actions, JS injection)
        │  fetchQueue → [QueueItemInfo]
        ▼
DynamicIslandPlayerView  (queue UI: toggle, header, autoplay, list container)
        │  expand/collapse
        ▼
FloatingIslandWindowController  (window resize via dynamicIslandDidToggleQueue)
```

### 2.1 Files that control the Queue

| File | Role |
|------|------|
| `Sources/Mooziac/NowPlayingManager.swift` | Queue **data/actions** (singleton). |
| `Sources/Mooziac/DynamicIslandPlayerView.swift` | Queue **UI** (toggle button, container, header, autoplay btn, list host). |
| `Sources/Mooziac/FloatingIslandWindowController.swift` | Window sizing when queue expands/collapses (line 147). |

### 2.2 Data model — `QueueItemInfo` (`NowPlayingManager.swift:978`)

```swift
public struct QueueItemInfo {
    public let index: Int
    public let title: String
    public let artist: String
    public let isSelected: Bool   // currently playing row
}
```

### 2.3 Queue read pipeline — `fetchQueue(completion:)` (`NowPlayingManager.swift:985`)

Single JS routine injected into the WebView. Three fallback strategies, first non-empty wins:

1. **DOM scan** — reads live `ytmusic-player-queue-item` nodes in the active `#contents` container.
   - Filters non-visible/shadow-template duplicates (`offsetParent === null`, zero rect).
   - Dedupes by `title___artist` key (`seenTitleArtist`).
   - **Includes the currently-playing selected track** (by design).
2. **Polymer data model** — `ytmusic-player-queue.queue.items` (`playlistPanelVideoRenderer`).
3. **player API** — `api.getPlaylist()/getPlaylistIndex()/getVideoData()`.

Auto-populate: if `res.length <= 1`, clicks the Autoplay toggle / Radio button to seed "Up Next".

### 2.4 Queue mutation APIs (`NowPlayingManager.swift`)

| Function | Line | Behavior |
|----------|------|----------|
| `playQueueItem(at:)` | 1149 | Simulates mousedown/up/click/`.click()` on the nth visible queue item. |
| `removeQueueItem(at:)` | 1195 | Clicks the row's Remove button (`aria-label*="Remove"` etc.); falls back to DOM removal + Polymer `items.splice` + `notifyPath`. |
| `playNextQueueItem(from:)` | 1228 | Fetches queue, finds selected index, moves item to spot after current track. |
| `triggerAutoplayRadio()` | 1240 | Clicks Autoplay toggle + Radio button. |
| `moveQueueItem(from:to:)` | 1264 | DOM `insertBefore` reorder + Polymer `items.splice` + `notifyPath('queue.items')`. |

### 2.5 Queue UI (`DynamicIslandPlayerView.swift`)

| Piece | Lines | Notes |
|-------|-------|-------|
| `queueButton` (list.bullet) | 384, 570 | Toggle → `queueTapped()` (990). |
| `isQueueExpanded`, `queueContainerView`, `queueHostView`, `queueHeaderLabel` | 392–398 | Header label carries live count. |
| `expandQueue()/collapseQueue()` | 971 / 956 | ANIMATES + swaps `containerPillBottom{Expanded,Collapsed}Constraint`, calls `delegate?.dynamicIslandDidToggleQueue`. |
| `refreshQueue()` | 1001 | `fetchQueue` → reload list, scroll to selected row. |
| `autoplayTapped()` | 1014 | `triggerAutoplayRadio()` + toast + delayed `refreshQueue()`. |
| `applyTheme()` | 1119 | Restyles queue container/header per theme. |
| Row 4 layout | 785–801 | `queueContainerView` 230pt fixed height under waveform. |

`DynamicIslandPlayerViewDelegate.dynamicIslandDidToggleQueue(expanded:)` forwards window resize to `FloatingIslandWindowController` (New height 380 expanded / 120 collapsed).

## 3. CURRENT STATE ⚠️ — BROKEN BUILD

The Queue UI is mid-refactor (uncommitted working-tree changes) and **does not compile**. Root cause: the
new `queueHostView` (plain `NSView`, line 397) replaced the old `NSTableView`, but stale references were left behind:

**Missing declarations (all Queue-scoped, in `DynamicIslandPlayerView.swift`):**
- `autoplayBtn` — referenced at lines 683–691, 699, 795–796, 1015; never declared.
- `queueItems` — referenced at line 1004 (`self.queueItems = items`); never declared.
- `queueTableView` — a dead `NSTableView`: referenced at 1006, 1009, 1156, 1187, 1223; never declared, no delegate/dataSource, never added as subview.

No other compile errors exist. These are the ONLY errors.

## 4. Change Log

| Date | Change | Files |
|------|--------|-------|
| 2026-08-12 | **UP NEXT system (YTM behavior).** Backend: `UpNextSnapshot`/`AutomixItemInfo` + combined `fetchUpNextSnapshot()` (ordered items incl. current, current title/artist, "Playing from" context, autoplay toggle, automix previews) + `playAutomixItem(at:)`; `fetchQueue` untouched. UI (`DynamicIslandPlayerView`): `UpNextRow{kind: queue/recommendation/sectionHeader}`, `Playing from` context label, autoplay section with dimmed "↻" rows, header `UP NEXT (N)`, snapshot-driven rebuild excluding current track (first row = exact next), 2.5s live-sync timer while expanded, theme-aware. Built/launched via `./build_app.sh`. | `NowPlayingManager.swift`, `DynamicIslandPlayerView.swift` |
| 2026-08-12 | **"Up Next only" queue.** `refreshQueue()` now filters out the currently-playing track (`isSelected`), shows header `"UP NEXT (N)"`, and scrolls to top; row-tap replays by the item's true DOM `index` (`queueItems[row].index`) so removed-up-next tracks still play correctly. Build green. | `Sources/Mooziac/DynamicIslandPlayerView.swift` |
| 2026-08-12 | **FIXED build errors.** Declared `autoplayBtn` (`ReactiveIconButton`), `queueItems` array, and `queueTableView` (`NSTableView`); configured the table (plain, headerless, 30pt rows, clear bg) pinned inside `queueHostView`; added `NSTableViewDataSource`/`NSTableViewDelegate` extension with row rendering (`QueueRowView`: bold-11pt white title + regular-10pt gray artist, firstBaseline 6pt stack, theme-aware incl. glassMode; now-playing row tinted header-cyan) and tap-to-play via `NowPlayingManager.shared.playQueueItem(at:)`. `swift build` now passes. | `Sources/Mooziac/DynamicIslandPlayerView.swift` |
| 2026-08-12 | Initial blueprint; documented architecture + identified broken-build state (missing `autoplayBtn`, `queueItems`, `queueTableView`) | `QUEUE_BLUEPRINT.md` |

## 5. Open Questions / Constraints

- ~~The stale `queueTableView` references may mean the intended design is either (a) restore the table view or (b) a fully native custom list inside `queueHostView`. Decide before fixing~~ → **Resolved:** table view restored inside `queueHostView` (minimal fix honoring existing references).
- Queue row interaction (click-to-play ✓, remove, drag reorder) currently ships via the JS APIs in §2.4 — remove/reorder native actions not yet wired to the table.

## 6. IN-PROGRESS — "Up Next" redesign (YouTube Music behavior reference)

### 6.1 Design decisions
- **Single source of truth:** YTM live DOM/Polymer queue read (same read path as `fetchQueue`). No app-side parallel queue.
- `NowPlayingManager` gains `UpNextSnapshot` (+ `AutomixItemInfo`) and one combined JS read `fetchUpNextSnapshot()` returning: full ordered `items` (incl. selected), `currentTitle/Artist`, `contextTitle` ("Playing from"), `autoplayEnabled`, `automixItems`.
- `fetchQueue` stays unchanged (internal `playNextQueueItem` still depends on it).
- UI (`DynamicIslandPlayerView`): native table rows modelled as `UpNextRow { kind: .queue | .recommendation | .sectionHeader }`, built ONLY from the snapshot. Upcoming = snapshot.items minus selected/current, order preserved. `.sectionHeader` ("AUTOPLAY") + `.recommendation` rows rendered dimmed/tappable (click YTM automix preview node).
- `Playing from` label: contextTitle → fallback `currentState.album` → current title.
- Live sync: 2.5s refresh Timer while queue expanded (covers end-of-song, skip, external reorder) on top of existing track-change refresh.
- Tap `.queue` row → `playQueueItem(at: domIndex)`; tap `.recommendation` → new `playAutomixItem(at:)`.

### 6.2 Status
- [x] `NowPlayingManager`: `AutomixItemInfo` + `UpNextSnapshot` + `fetchUpNextSnapshot()` + `playAutomixItem(at:)`
- [x] `DynamicIslandPlayerView`: `UpNextRow` model, context label, snapshot-driven `refreshQueue`, kind-aware rendering/tap, periodic live-sync timer
- [x] Theme styling for new rows/labels
- [x] Build via `./build_app.sh` and verify sequencing

### 6.3 Architecture (as built)
- **Source of truth:** one combined JS read `NowPlayingManager.fetchUpNextSnapshot()` → `UpNextSnapshot { contextTitle, autoplayEnabled, items (incl. selected), automixItems, currentTitle, currentArtist }`. `fetchQueue` untouched (still feeds `playNextQueueItem`).
- `applySnapshot(snapshot)`:
  - Upcoming rows = `snapshot.items` minus the selected/current track (isSelected OR equals `currentState.title`), DOM order preserved → first row is always the exact next track.
  - If `automixItems` non-empty (YTM renders these only when Autoplay/Automix is on), append `.sectionHeader` "AUTOPLAY" + dimmed `.recommendation` rows.
  - Header shows `UP NEXT (N)` where N = upcoming count only. `Playing from  {context}` = contextTitle → fallback `currentState.album` → current title.
- **Live sync:** track-change refresh (via `updateState`) + 2.5s `Timer` (runloop `.common`) active only while queue expanded → covers end-of-song, skip, and web-side reorder.
- **Tap:** `.queue` → `playQueueItem(at: domIndex)`; `.recommendation` → `playAutomixItem(at: domIndex)`; `.sectionHeader` not selectable.

### 6.4 Requirement trace
| Req | How satisfied |
|-----|---------------|
| 1 header "UP NEXT" | `queueHeaderLabel` = `UP NEXT (N)` |
| 2 "Playing from" | `playingFromLabel` |
| 3 upcoming below | native table under context label |
| 4 current not in list | dropped in `applySnapshot` |
| 5 first = exact next | DOM order minus current |
| 6 real playback order | reads live YTM queue |
| 7 finish → advance | track-change refresh + 2.5s poll |
| 8 skip → recalc | same + poll |
| 9 ten-song slide | drop-head rebuild each refresh |
| 10 no second queue | single snapshot read, no app-side store |
| 11 autoplay recs below | AUTOPLAY section from automix DOM nodes |
| 12 recs don't replace queue | separate rows; only click preview node |
| 13 distinguish types | context row / normal rows / dimmed "↻" recs + header |
| 14 tap → update state | `playQueueItem` → track change → re-refresh |
| 15 reorder → follow | 2.5s poll re-reads DOM while open |