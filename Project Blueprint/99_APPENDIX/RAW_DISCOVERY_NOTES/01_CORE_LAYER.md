# Mooziac Core Blueprint — Work Package A (Core Layer)

Reverse-engineering archive of the Mooziac app core. READ-ONLY analysis; no source was modified.

Scope: 12 files
- `Sources/Mooziac/App/main.swift`
- `Sources/Mooziac/App/AppDelegate.swift`
- `Sources/Mooziac/App/BackgroundMediaController.swift`
- `Sources/Mooziac/Core/MainViewController.swift`
- `Sources/Mooziac/Core/DisplayManager.swift`
- `Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`
- `Sources/Mooziac/Core/NowPlayingManager/ObserverBridge.swift`
- `Sources/Mooziac/Core/NowPlayingManager/PlayerControls.swift`
- `Sources/Mooziac/Core/NowPlayingManager/Queue.swift`
- `Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift`
- `Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift`
- `Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift`

Conventions used below:
- Line numbers refer to the files as read during this analysis (line 1 = first line of the file).
- Facts are directly verified in source. Anything not directly visible in these files is labelled `INFERRED FROM SOURCE` (from cross-referenced files) or `UNKNOWN — requires runtime verification.`
- Model types referenced but defined elsewhere: `PlaybackState` (`Models/PlaybackState.swift`), `RepeatMode` (`Models/RepeatMode.swift`), `PlaybackEngineMode` (`Models/PlaybackEngineMode.swift`), `LocalTrack` (`Models/LocalTrack.swift`). All exist in the repo.

---

# FILE 1: Sources/Mooziac/App/main.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/App/main.swift`
- **Purpose**: Process entry point. Bootstraps `NSApplication`, installs the `AppDelegate`, and starts the AppKit event loop. 7 lines total.
- **Subsystem**: App lifecycle (entry).
- **What depends on it / what it depends on**:
  - Depends on: `AppDelegate` (same module, `App/AppDelegate.swift`), `AppKit`.
  - Depends on it: nothing at compile-time (it is the entry point); it drives the entire app.
- **Important imports**: `import AppKit`
- **Classes defined**: none (top-level executable code only).
- **Functions/methods defined**: none declared; one top-level statement sequence.
- **Constants**: none.
- **Properties/state**: none declared (the `app` local is top-level).
- **Events emitted/listened to**: none directly; the app event loop processes all AppKit events from here.
- **Side effects**: Sets `NSApplication.shared` as active app, assigns delegate, runs the main run loop (`app.run()` — blocking, never returns until app terminates).
- **External APIs / system frameworks**: AppKit (`NSApplication`).
- **Files it communicates with**: `App/AppDelegate.swift` (delegate object).

## FUNCTION ENTRY

- **Function**: Top-level entry sequence (lines 1–6)
- **File**: `Sources/Mooziac/App/main.swift`
- **Location**: lines 1–6 (whole file)
- **Purpose**: Create the shared app object, wire the delegate, run the event loop.
- **Inputs**: none.
- **Output**: none (process runs until quit).
- **Called by**: The Swift runtime / `swift` toolchain entry point (`NSApplicationMain` equivalent performed manually).
- **Calls**: `AppDelegate()` init, `NSApplication.run()`.
- **Reads**: nothing.
- **Writes**: `NSApp.delegate`.
- **Side effects**: AppKit event loop starts; all subsequent startup happens in `AppDelegate.applicationDidFinishLaunching`.
- **Errors**: none handled.
- **Async behavior**: none; `run()` is synchronous and blocks.
- **Events**: none.
- **Execution flow**:
  1. `let app = NSApplication.shared` — creates/obtains the shared app instance.
  2. `let delegate = AppDelegate()` — constructs the delegate (all lazy work deferred).
  3. `app.delegate = delegate` — assigns delegate (strongly retained by NSApp).
  4. `app.run()` — starts the main run loop; returns only on termination.

---

# FILE 2: Sources/Mooziac/App/AppDelegate.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/App/AppDelegate.swift`
- **Purpose**: Application lifecycle controller. On launch: sets `.accessory` activation policy (no Dock icon), builds a minimal Edit menu (for copy/paste/undo shortcuts in WebKit), purges legacy v1/v2 UserDefaults keys, starts all background services, and creates the `StatusItemManager` (which owns the menu-bar item + popover). On terminate: stops sleep prevention.
- **Subsystem**: App lifecycle.
- **What depends on it / what it depends on**:
  - Depends on: `StatusItemManager`, `BackgroundMediaController.shared`, `EdgeVolumeEngine.shared`, `AudioRouteMonitor.shared`, `NetworkMonitor.shared`, `DiscordRPCManager.shared`, `LaunchAnimationController.shared` (all same module).
  - Depends on it: nothing directly; it is the delegate consumed by `NSApplication`. It owns `statusItemManager`.
- **Important imports**: `import AppKit`
- **Classes defined**: `AppDelegate`
- **Functions/methods defined**: `applicationDidFinishLaunching(_:)`, `setupMainMenu()`, `applicationShouldTerminateAfterLastWindowClosed(_:)`, `applicationWillTerminate(_:)`.
- **Constants**: the `legacyKeys` local array (lines 12–17).
- **Properties/state**: `private var statusItemManager: StatusItemManager?` (line 4) — sole app-lifetime owner of the menu bar manager.
- **Events emitted/listened to**: Listens (via NSApplicationDelegate callbacks) to `applicationDidFinishLaunching` and `applicationWillTerminate`. Does not post notifications.
- **Side effects**: Purges 10 legacy UserDefaults keys on every launch (see USERDEFAULTS); starts sleep-prevention assertion; starts EdgeVolumeEngine, AudioRouteMonitor, NetworkMonitor, DiscordRPCManager; plays launch animation.
- **External APIs / system frameworks**: AppKit (`NSApplication`, `NSMenu`, `NSText`), Foundation (`UserDefaults`, `Notification`).
- **Files it communicates with**: `main.swift` (delegate target), `StatusItemManager/StatusItemManager.swift` (instantiates), `BackgroundMediaController.swift`, and the singleton managers listed above.

## CLASS ENTRY — AppDelegate

- **Class**: `AppDelegate: NSObject, NSApplicationDelegate`
- **Purpose**: Central app lifecycle coordinator; wires up the whole app in one place at launch.
- **Responsibilities**:
  - Set `.accessory` activation policy (menu-bar app, no Dock icon).
  - Build a minimal Edit menu so text editing shortcuts work inside WebKit/fields.
  - Remove legacy v1/v2 UserDefaults keys.
  - Start every background service (sleep prevention, edge volume, audio route monitoring, network monitoring, Discord RPC).
  - Instantiate the `StatusItemManager` (menu bar item + popover panel).
  - Play the launch animation.
  - Keep the app running when the last window closes.
  - Stop sleep prevention on terminate.
- **Constructor/init**: implicit `NSObject` init; no custom init.
- **Properties (with types)**:
  - `private var statusItemManager: StatusItemManager?` (line 4)
- **Public vs private API**: all methods are public (protocol conformance) except `setupMainMenu()` which is `private` (line 45).
- **Dependencies**: `StatusItemManager`, `BackgroundMediaController`, `EdgeVolumeEngine`, `AudioRouteMonitor`, `NetworkMonitor`, `DiscordRPCManager`, `LaunchAnimationController`.
- **Consumers (who uses it)**: `NSApplication` (set as delegate in `main.swift`).
- **Lifecycle**: Created in `main.swift` before `app.run()`; retained by NSApp for app lifetime.
- **State**: `statusItemManager` (nil until `applicationDidFinishLaunching`).
- **Events**: receives `applicationDidFinishLaunching`, `applicationWillTerminate`; NSApplicationDelegate query `applicationShouldTerminateAfterLastWindowClosed`.
- **Relationships**: owns `StatusItemManager`; initializes all global singletons.
- **What would break if removed**: The app would launch with no services, no menu bar item, no Edit menu, and would remain in the Dock — the app would be non-functional as a menu-bar player. `main.swift` would need a replacement delegate.

## FUNCTION ENTRIES — AppDelegate

### applicationDidFinishLaunching(_ notification: Notification)
- **File**: `App/AppDelegate.swift`; **Class**: `AppDelegate`; **Location**: lines 6–43.
- **Purpose**: Launch-time setup of the entire app.
- **Inputs**: `notification: Notification` (unused).
- **Output**: none.
- **Called by**: AppKit (delegate callback).
- **Calls**: `NSApp.setActivationPolicy(.accessory)`; `setupMainMenu()`; `UserDefaults.standard.removeObject(forKey:)` ×10; `BackgroundMediaController.shared.startPreventingSleep()`; `EdgeVolumeEngine.shared.start()`; `AudioRouteMonitor.shared.startMonitoring()`; `NetworkMonitor.shared.startMonitoring()`; `DiscordRPCManager.shared.startReconnectLoop()`; `DiscordRPCManager.shared.tryConnect()`; `StatusItemManager()` init; `LaunchAnimationController.shared.play()`.
- **Reads**: nothing persistent (only writes).
- **Writes**: `NSApp.activationPolicy`; removes 10 UserDefaults keys; assigns `statusItemManager`.
- **Side effects**: Purges legacy keys so v3 defaults are used; starts all services; creates the status item; plays animation.
- **Errors**: none handled (service starts assumed to be non-throwing).
- **Async behavior**: none directly (the services spawn their own work).
- **Events**: none.
- **Execution flow**:
  1. `NSApp.setActivationPolicy(.accessory)` — hide Dock icon.
  2. `setupMainMenu()` — install Edit menu.
  3. Loop over `legacyKeys`, `removeObject(forKey:)` each.
  4. `BackgroundMediaController.shared.startPreventingSleep()` — IOKit assertion + process activity.
  5. `EdgeVolumeEngine.shared.start()` — trackpad edge engine.
  6. `AudioRouteMonitor.shared.startMonitoring()`.
  7. `NetworkMonitor.shared.startMonitoring()`.
  8. `DiscordRPCManager.shared.startReconnectLoop()` then `tryConnect()`.
  9. `statusItemManager = StatusItemManager()` — creates status item, panel, main view controller.
  10. `LaunchAnimationController.shared.play()`.

### setupMainMenu()
- **File**: `App/AppDelegate.swift`; **Class**: `AppDelegate`; **Location**: lines 45–61.
- **Purpose**: Builds a top-level Edit menu (Undo/Redo/Cut/Copy/Paste/Select All) so AppKit standard selectors work in text inputs and WebKit.
- **Inputs**: none. **Output**: none.
- **Called by**: `applicationDidFinishLaunching`.
- **Calls**: `NSMenu()`/`NSMenuItem()` constructors, `menu.addItem(withTitle:action:keyEquivalent:)` ×6, `NSMenuItem.separator()`.
- **Reads**: nothing. **Writes**: `NSApp.mainMenu`.
- **Side effects**: sets app main menu.
- **Selectors used**: `Selector(("undo:"))`, `Selector(("redo:"))`, `#selector(NSText.cut(_:))`, `#selector(NSText.copy(_:))`, `#selector(NSText.paste(_:))`, `#selector(NSText.selectAll(_:))`. Key equivalents `z`, `Z`, `x`, `c`, `v`, `a`.
- **Errors/async/events**: none.
- **Execution flow**: Build menu tree → assign `NSApp.mainMenu`.

### applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
- **File**: `App/AppDelegate.swift`; **Class**: `AppDelegate`; **Location**: lines 63–65.
- **Purpose**: Keep the app alive with no windows (menu-bar app semantics).
- **Output**: `false`.
- **Called by**: AppKit. **Calls/reads/writes**: none.

### applicationWillTerminate(_ notification: Notification)
- **File**: `App/AppDelegate.swift`; **Class**: `AppDelegate`; **Location**: lines 67–69.
- **Purpose**: Release the sleep-prevention assertion/activity on quit.
- **Inputs**: `notification: Notification` (unused).
- **Called by**: AppKit.
- **Calls**: `BackgroundMediaController.shared.stopPreventingSleep()`.
- **Side effects**: releases IOKit assertion + process activity + stops audio engine.

---

# FILE 3: Sources/Mooziac/App/BackgroundMediaController.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/App/BackgroundMediaController.swift`
- **Purpose**: Keeps macOS from sleeping/idle-NAPing while music plays, and provides a (currently unused) AVAudioEngine scaffold for keeping audio alive.
- **Subsystem**: App lifecycle / power management.
- **What depends on it / what it depends on**:
  - Depends on: `IOKit.pwr_mgt`, `AVFoundation`, `Foundation`.
  - Depends on it: `AppDelegate` (start/stop on launch/terminate).
- **Important imports**: `import Foundation`, `import IOKit.pwr_mgt`, `import AVFoundation`
- **Classes defined**: `BackgroundMediaController` (final, singleton).
- **Functions/methods defined**: `init()`, `startPreventingSleep()`, `stopPreventingSleep()`.
- **Constants**: none (reason string `"Background Music Playback"` is a local).
- **Properties/state**: `assertionID: IOPMAssertionID = 0`, `processActivity: NSObjectProtocol?`, `audioEngine: AVAudioEngine?`, `audioPlayerNode: AVAudioPlayerNode?`.
- **Events emitted/listened to**: none.
- **Side effects**: On init already creates an IOPMAssertion + process activity; on stop releases them.
- **External APIs / system frameworks**: IOKit (`IOPMAssertionCreateWithName`, `IOPMAssertionRelease`, `kIOPMAssertionTypePreventUserIdleSystemSleep`, `IOPMAssertionLevelOn`), Foundation (`ProcessInfo.beginActivity/endActivity`), AVFoundation (`AVAudioEngine`, `AVAudioPlayerNode`).
- **Files it communicates with**: `App/AppDelegate.swift`.

## CLASS ENTRY — BackgroundMediaController

- **Class**: `BackgroundMediaController` (final)
- **Purpose**: Power-management guard for uninterrupted background playback.
- **Responsibilities**: create/release an idle-sleep assertion; disable App Nap; optionally hold an audio engine.
- **Constructor/init**: `init()` calls `startPreventingSleep()` — i.e., the assertion is created as soon as the singleton is touched, not only via explicit call.
- **Properties**:
  - `static let shared: BackgroundMediaController` (line 7)
  - `private var assertionID: IOPMAssertionID = 0` (line 9)
  - `private var processActivity: NSObjectProtocol?` (line 10)
  - `private var audioEngine: AVAudioEngine?` (line 11)
  - `private var audioPlayerNode: AVAudioPlayerNode?` (line 12)
- **Public vs private API**: `shared`, `startPreventingSleep()`, `stopPreventingSleep()` are internal; the rest private.
- **Dependencies**: IOKit, Foundation, AVFoundation.
- **Consumers**: `AppDelegate` (calls `startPreventingSleep` in `applicationDidFinishLaunching`, `stopPreventingSleep` in `applicationWillTerminate`). Also invoked implicitly by `init`.
- **Lifecycle**: app lifetime (singleton).
- **State**: `assertionID`, `processActivity`.
- **Events**: none.
- **Relationships**: none beyond AppDelegate.
- **What would break if removed**: playback could be paused by system sleep/idle when the display locks; App Nap may throttle playback. Note: `audioEngine`/`audioPlayerNode` are declared but **never assigned anywhere in the codebase** (`INFERRED FROM SOURCE` — no writer found) — the "audio engine" part is dead scaffold.

## FUNCTION ENTRIES — BackgroundMediaController

### init()
- **File**: `App/BackgroundMediaController.swift`; **Class**: `BackgroundMediaController`; **Location**: lines 14–16.
- **Purpose**: Immediately start sleep prevention on first touch of the singleton.
- **Calls**: `startPreventingSleep()`.
- **Side effects**: creates the IOKit assertion + process activity at first access (this happens when `AppDelegate` calls `shared.startPreventingSleep()` on launch, and again the explicit call is idempotent-guarded).

### startPreventingSleep()
- **File**: `App/BackgroundMediaController.swift`; **Location**: lines 18–38.
- **Purpose**: Create an idle-sleep assertion and disable App Nap.
- **Inputs**: none. **Output**: none (Void).
- **Called by**: `init()`, `AppDelegate.applicationDidFinishLaunching`.
- **Calls**: `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep, IOPMAssertionLevelOn, "Background Music Playback", &assertionID)`; `ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Background Music Playback")`.
- **Reads**: `assertionID` (guard == 0).
- **Writes**: `assertionID`, `processActivity`.
- **Side effects**: system sleep prevention active while app runs.
- **Errors**: prints a log on `kIOReturnSuccess`; failure is silently ignored (no else branch).
- **Guard**: early-return if `assertionID != 0` (idempotent).
- **Execution flow**: guard → create assertion → if success print → begin process activity.

### stopPreventingSleep()
- **File**: `App/BackgroundMediaController.swift`; **Location**: lines 40–53.
- **Purpose**: Release assertion, end activity, tear down audio engine if present.
- **Called by**: `AppDelegate.applicationWillTerminate`.
- **Calls**: `IOPMAssertionRelease`, `ProcessInfo.processInfo.endActivity`, `audioPlayerNode?.stop()`, `audioEngine?.stop()`.
- **Writes**: `assertionID = 0`, `processActivity = nil`, `audioPlayerNode = nil`, `audioEngine = nil`.
- **Side effects**: re-enables normal idle sleep; nils the audio engine nodes (they are never created anyway — dead code, see RISKS).

---

# FILE 4: Sources/Mooziac/Core/MainViewController.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/MainViewController.swift`
- **Purpose**: Root content view controller of the popover panel. Owns the player ("dynamic island") view, the YTM browser container (header + webview), the offline library view, and the playlist library view; switches between player/browser/library modes and resizes the host panel via `onChangeSize`. Also implements search (online + local fallback), autoplay-JS injection, and delegates for the player/library/header.
- **Subsystem**: Core UI controller (panel content).
- **What depends on it / what it depends on**:
  - Depends on: `HeaderView`, `YTMWebViewContainer`, `DynamicIslandPlayerView`, `OfflineLibraryView`, `PlaylistLibraryView`, `NowPlayingManager.shared`, `NetworkMonitor.shared`, `LocalLibraryManager.shared`, `PlaylistManager.shared`, `GlobalHotKeyManager.shared`, `StatusItemManager.shared`, `CenteredMenuBarLyricsWindowController.shared`, `LocalTrack` (model).
  - Depends on it: `StatusItemManager` (constructs it and installs it as the panel's contentViewController; wires `onChangeSize`/`onResetPosition`).
- **Important imports**: `import AppKit`, `import WebKit`
- **Classes defined**: `PassthroughBrowserContainerView` (NSView subclass), `MainViewController`.
- **Functions/methods defined**: see FUNCTION ENTRIES below (34 total including `hitTest`).
- **Constants**: none beyond hard-coded layout sizes (360×120 pill, 360×650 browser, 380×420 libraries, 360×480 expanded).
- **Properties/state**: mode flags `isBrowserMode`, `isOfflineLibraryMode`, `isPlaylistLibraryMode`; closures `onChangeSize`, `onResetPosition`; the five subviews.
- **Events emitted/listened to**: observes `NowPlayingManager` observers (adds one in `setupObservers`); posts none itself.
- **Side effects**: When shown, resizes the host window via `onChangeSize`; loads URLs/JS into the webview; can show text overlays via `CenteredMenuBarLyricsWindowController`.
- **External APIs / system frameworks**: AppKit, WebKit (`WKWebView.evaluateJavaScript`, `load`), `NSAlert`.
- **Files it communicates with**: `StatusItemManager/StatusItemManager.swift`, `NowPlayingManager/*`, `DisplayManager` (indirectly via StatusItemManager), `Views/Player/DynamicIslandPlayerView/*`, `Views/Components/HeaderView.swift`, `Views/Libraries/*`, `Web/YTMWebView.swift`, `Input/GlobalHotKeyManager.swift`.

## CLASS ENTRY — PassthroughBrowserContainerView

- **Class**: `final class PassthroughBrowserContainerView: NSView` (lines 4–11)
- **Purpose**: A hit-test gate for the browser container. When `isHitTestingEnabled == false` the view swallows hits (`hitTest` returns nil) so the underlying player view receives clicks; when true, normal hit testing applies.
- **Properties**: `var isHitTestingEnabled: Bool = false`.
- **Public vs private**: internal.
- **Consumers**: `MainViewController` (owns `browserContainerView`), and `setBrowserVisible` toggles `isHitTestingEnabled` to match browser mode.
- **What would break if removed**: clicks would fall through or be blocked in wrong modes (player-mode buttons overlapped by invisible browser container).

### FUNCTION — `override func hitTest(_ point: NSPoint) -> NSView?` (lines 7–10)
- **Purpose**: Return nil (transparent to hit testing) unless enabled.
- **Input**: `point: NSPoint`. **Output**: `NSView?` (nil when disabled).
- **Called by**: AppKit hit-testing.
- **Reads**: `isHitTestingEnabled`. **Side effects**: none.

## CLASS ENTRY — MainViewController

- **Class**: `MainViewController: NSViewController, DynamicIslandPlayerViewDelegate, HeaderViewDelegate, OfflineLibraryViewDelegate, PlaylistLibraryViewDelegate` (lines 13–529)
- **Purpose**: Central content controller coordinating the four UI modes (player, browser, offline library, playlist library) and bridging UI actions into `NowPlayingManager`/`PlaylistManager`/`LocalLibraryManager`.
- **Responsibilities**:
  - Lay out and constrain the five subviews (player on top, browser/header behind, libraries).
  - Toggle modes with `setBrowserVisible`/`setOfflineLibraryVisible`/`setPlaylistLibraryVisible`, each mutually exclusive, and each emitting `onChangeSize` to resize the panel.
  - Implement search with online YTM navigation + autoplay JS, plus offline local fallback with a scoring function.
  - Forward player control taps to `NowPlayingManager`.
  - Forward browser header navigation (back/forward/reload/home/account/player-only/quit).
  - Forward library selection to `NowPlayingManager`/`PlaylistManager`.
  - Start `GlobalHotKeyManager`.
- **Constructor/init**: implicit `init(nibName:bundle:)`/`init()` from `NSViewController`; no custom init. Real init work in `viewDidLoad`.
- **Properties (with types)**:
  - `let headerView: HeaderView` (14)
  - `let webViewContainer: YTMWebViewContainer` (15)
  - `let dynamicIslandPlayer: DynamicIslandPlayerView` (16)
  - `let offlineLibraryView: OfflineLibraryView` (17)
  - `let playlistLibraryView: PlaylistLibraryView` (18)
  - `private let browserContainerView: PassthroughBrowserContainerView` (19)
  - `var onChangeSize: ((CGFloat, CGFloat) -> Void)?` (21)
  - `var onResetPosition: (() -> Void)?` (22)
  - `public var isBrowserMode: Bool = false` (23)
  - `public var isOfflineLibraryMode: Bool = false` (24)
  - `public var isPlaylistLibraryMode: Bool = false` (25)
- **Public vs private API**: mode flags are public; views are `let` (internal); `setupUI`/`setupObservers`/`findBestLocalTrack` private; `loadView`, `viewDidLoad`, mode setters, and all delegate methods internal.
- **Dependencies**: HeaderView, YTMWebViewContainer, DynamicIslandPlayerView, OfflineLibraryView, PlaylistLibraryView, NowPlayingManager, NetworkMonitor, LocalLibraryManager, PlaylistManager, GlobalHotKeyManager, StatusItemManager, CenteredMenuBarLyricsWindowController.
- **Consumers**: `StatusItemManager` (creates it, sets closures, uses `mainViewController` for webview access from NowPlayingManager/PlaylistManager/HistoryManager).
- **Lifecycle**: created eagerly by `StatusItemManager.init`; lives as long as the app (panel content).
- **State**: three mode booleans; view is a 360×120 clear window at load.
- **Events**: adds an observer to NowPlayingManager; `onChangeSize`/`onResetPosition` callbacks consumed by StatusItemManager.
- **Relationships**: strong parent of the five subviews; delegate target for four view classes; closure source for StatusItemManager.
- **What would break if removed**: the panel would have no content; browser mode, libraries, search, and all player controls would be gone.

## FUNCTION ENTRIES — MainViewController

### loadView() (lines 27–29)
- **Purpose**: Set root view to an empty 360×120 `NSView`.
- **Calls/writes**: `self.view = NSView(frame: NSRect(x:0,y:0,width:360,height:120))`.
- **Called by**: AppKit when view is accessed.

### viewDidLoad() (lines 31–41)
- **Purpose**: Set up UI, observers, default to player-only mode, start global hotkeys.
- **Calls**: `setupUI()`, `setupObservers()`, `setBrowserVisible(false)`, `setOfflineLibraryVisible(false)`, `setPlaylistLibraryVisible(false)`, `GlobalHotKeyManager.shared.startMonitoring()`.
- **Side effects**: Player mode is the default; hotkey monitoring begins.
- **Note**: `setBrowserVisible(false)` etc. call `onChangeSize` — this fires before StatusItemManager has wired `onChangeSize` (StatusItemManager wires it in its own `setupPanel` after constructing the VC). `INFERRED FROM SOURCE`: since the closure is nil at that point, the resize is a no-op during setup.

### setupUI() (lines 43–113)
- **Purpose**: Configure layer/transparency, wire delegates, hide library views, style the browser container, add all subviews, activate all Auto Layout constraints.
- **Calls**: `dynamicIslandPlayer.collapseSettings()` (indirect, in mode setters) — not here. Direct: `addSubview` ×4, `NSLayoutConstraint.activate([...])`.
- **Key constants**: browser background `NSColor(red:0.08,green:0.08,blue:0.10,alpha:0.98)`, cornerRadius 20, border `NSColor(white:1.0,alpha:0.15)`, header height 36, initial `browserContainerView.alphaValue = 0.001`.
- **Notable**: `headerView.isHidden = true` — header intentionally hidden in player mode to avoid hit-test overlap with player buttons (comment line 70).

### setupObservers() (lines 115–119)
- **Purpose**: Subscribe to NowPlayingManager state updates and forward them to the player view.
- **Calls**: `NowPlayingManager.shared.addObserver { [weak self] state in self?.dynamicIslandPlayer.updateState(state) }`.
- **Side effects**: The observer immediately receives the current state (addObserver invokes synchronously).

### setBrowserVisible(_ visible: Bool) (lines 121–149)
- **Purpose**: Toggle YTM browser mode.
- **Reads**: `isBrowserMode`, `isOfflineLibraryMode`, `isPlaylistLibraryMode`.
- **Writes**: `isBrowserMode`, `browserContainerView.isHitTestingEnabled`, `headerView.isHidden`, `browserContainerView.isHidden/alphaValue`, `dynamicIslandPlayer.isHidden`, `offlineLibraryView.isHidden`, `playlistLibraryView.isHidden`.
- **Calls**: `dynamicIslandPlayer.collapseSettings()` (always), `setOfflineLibraryVisible(false)`/`setPlaylistLibraryVisible(false)` (when showing), `onChangeSize?(360,650)` (show) or `onChangeSize?(360,120)` (hide, when no other mode active), `webViewContainer.selectSongTab()` (show).
- **Side effects**: Resizes panel; in hide mode keeps browser container present but nearly invisible (alpha 0.001) rather than hidden, so hit testing is gated only by `isHitTestingEnabled`.

### setOfflineLibraryVisible(_ visible: Bool) (lines 151–176)
- **Purpose**: Toggle offline library mode.
- **Calls**: `dynamicIslandPlayer.collapseSettings()`; on show: `setBrowserVisible(false)`/`setPlaylistLibraryVisible(false)` if needed, `offlineLibraryView.refreshLibrary()`, `onChangeSize?(380,420)`; on hide: `onChangeSize?(360,120)` if no other mode.
- **Writes**: `isOfflineLibraryMode`, visibility of four views.

### setPlaylistLibraryVisible(_ visible: Bool) (lines 178–203)
- **Purpose**: Toggle playlist library mode. Mirrors offline library logic with `playlistLibraryView.refresh()` and size 380×420.

### dynamicIslandDidSearch(query: String) (lines 206–348)
- **Purpose**: Handle search from the player view; offline/online branching.
- **Input**: raw query string.
- **Reads**: `NowPlayingManager.shared.engineMode`, `NetworkMonitor.shared.isReachable`, `LocalLibraryManager.shared.allTracks`.
- **Calls**: `findBestLocalTrack(for:)`, `NowPlayingManager.shared.playOfflineTrack`, `CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay`, `setBrowserVisible(false)`, `setOfflineLibraryVisible(false)`, `NowPlayingManager.shared.switchToOnlineMode()`, `webViewContainer.webView.load(URLRequest(url:))`, `webViewContainer.webView.evaluateJavaScript(autoPlayJS, completionHandler: nil)` (at delays 0.4/0.8/1.3/1.8/2.5s).
- **Side effects**: Auto-plays first search result via injected JS; shows overlay text; switches engine mode.
- **JS detail**: `autoPlayJS` IIFE (lines 237–341) does: `triggerClick` helper (dispatch mousedown/mouseup/click + `element.click()`), `ensurePlaying` (play via player API / video element / player-bar button), `findAndPlayTopTrack` (priority: top-card play button → first song row → any play button; one-click guard via `clickedTrack`), polling `setInterval` every 250ms up to 30 attempts.
- **Errors**: wrapped in try/catch inside JS; Swift side ignores failures.

### findBestLocalTrack(for query: String) -> (best: LocalTrack, matches: [LocalTrack])? (lines 350–394)
- **Purpose**: Score all local tracks against a query and return best + full ranked list.
- **Input**: raw query. **Output**: tuple or nil.
- **Scoring** (lines 366–382): exact title match +1000; prefix +500; contains +300; title/artist combination +400; per-word: title +50, artist +30, album +10.
- **Reads**: `LocalLibraryManager.shared.allTracks`.
- **Writes**: local `scored` array. Sorts descending; returns top + all matches.
- **Side effects**: none.

### Player-control delegate methods (lines 396–414)
- `dynamicIslandDidTapPlayPause()` (396–398): `NowPlayingManager.shared.togglePlayPause()`.
- `dynamicIslandDidTapNext()` (400–402): `NowPlayingManager.shared.nextTrack()`.
- `dynamicIslandDidTapPrevious()` (404–406): `NowPlayingManager.shared.previousTrack()`.
- `dynamicIslandDidTapShuffle()` (408–410): `NowPlayingManager.shared.toggleShuffle()`.
- `dynamicIslandDidTapRepeat()` (412–414): `NowPlayingManager.shared.toggleRepeat()`.
- All: called by `DynamicIslandPlayerView` (delegate); trivial forwards.

### dynamicIslandDidToggleExpanded(expanded: Bool) (lines 416–422)
- **Purpose**: Resize panel between 360×120 (collapsed) and 360×480 (expanded) via `onChangeSize`.
- **Reads**: `expanded`.

### dynamicIslandDidSeek(to seconds: Double) (lines 424–426)
- **Purpose**: `NowPlayingManager.shared.seek(to: seconds)`.

### dynamicIslandDidTapWebBrowser() (lines 428–433)
- **Purpose**: Toggle browser mode on main queue.
- **Calls**: `setBrowserVisible(!isBrowserMode)`.

### dynamicIslandDidTapOfflineLibrary() (lines 435–444)
- **Purpose**: Toggle playlist-library mode (note: despite the name it toggles `isPlaylistLibraryMode`, not offline library) and refresh if shown.
- **Calls**: `setPlaylistLibraryVisible(willShow)` where `willShow = !self.isPlaylistLibraryMode`; `playlistLibraryView.refresh()` when shown.

### dynamicIslandDidTapResetPosition() (lines 446–449)
- **Purpose**: Dock the dragged panel back under the status item.
- **Calls**: `StatusItemManager.shared?.dockBackToMenuBar()`, `onResetPosition?()`.
- **Note**: calls both — potential double-handling (see RISKS).

### dynamicIslandDidTapPlaylistLibrary(playlistID: String?) (lines 451–458)
- **Purpose**: Open playlist library, optionally into a specific playlist.
- **Calls**: `setPlaylistLibraryVisible(true)`; `playlistLibraryView.openPlaylist(id:)` or `openPlaylists()`.

### offlineLibraryDidSelectTrack(_ track: LocalTrack, in queue: [LocalTrack]) (lines 461–464)
- **Purpose**: Play selected offline track and return to player mode.
- **Calls**: `NowPlayingManager.shared.playOfflineTrack(track, in: queue)`, `setOfflineLibraryVisible(false)`.

### offlineLibraryDidRequestClose() (lines 466–468)
- **Purpose**: `setOfflineLibraryVisible(false)`.

### offlineLibraryDidRequestImport() (lines 470–472)
- **Purpose**: no-op stub; import handled inside OfflineLibraryView (comment).

### playlistLibraryDidRequestClose() (lines 475–477)
- **Purpose**: `setPlaylistLibraryVisible(false)`.

### playlistLibraryDidPlayOnline(videoId: String) (lines 479–483)
- **Purpose**: Play an online video from the playlist library.
- **Calls**: `NowPlayingManager.shared.switchToOnlineMode()`, `setPlaylistLibraryVisible(false)`, `PlaylistManager.shared.playOnlineVideo(videoId: videoId)`.

### HeaderView delegate methods (lines 486–523)
- `headerViewDidTapBack()` (486–488): `webViewContainer.webView.goBack()` if `canGoBack`.
- `headerViewDidTapForward()` (490–492): `goForward()` if `canGoForward`.
- `headerViewDidTapReload()` (494–496): `webViewContainer.webView.reload()`.
- `headerViewDidTapHome()` (498–502): load `https://music.youtube.com/`.
- `headerViewDidTapAccount()` (504–507): `setBrowserVisible(true)` + `webViewContainer.loadGoogleLogin()`.
- `headerViewDidTapPlayerOnly()` (509–511): `setBrowserVisible(false)`.
- `headerViewDidTapQuit()` (513–523): modal `NSAlert`; on `.alertFirstButtonReturn` → `NSApplication.shared.terminate(nil)`.
- All called by `HeaderView` (delegate).

### spotifyPlayerDidTapLogin() (lines 525–528)
- **Purpose**: Legacy/named-mismatch method; shows browser + Google login.
- **Calls**: `setBrowserVisible(true)`, `webViewContainer.loadGoogleLogin()`.
- **Note**: name references Spotify but it logs into Google/YTM (`INFERRED FROM SOURCE` — likely copy-paste artifact; dead unless some delegate references it).

---

# FILE 5: Sources/Mooziac/Core/DisplayManager.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/DisplayManager.swift`
- **Purpose**: Centralized display detection, saved-frame persistence, and safe-area boundary manager. Maps `NSScreen` ↔ `CGDirectDisplayID`, finds target screens for saved positions, clamps window frames inside visible bounds, and reports notch/menu-bar safe boundaries. Emits a callback when display configuration changes.
- **Subsystem**: Core (display geometry).
- **What depends on it / what it depends on**:
  - Depends on: AppKit only.
  - Depends on it: `StatusItemManager` (repositioning on display change and while dragging), plus any other consumer of `findScreen`/`clampFrameToVisibleBounds`/`displayID`.
- **Important imports**: `import AppKit`
- **Classes defined**: `DisplayManager` (public final, singleton).
- **Functions/methods defined**: `setupObservers()`, `handleDisplayParametersChange()`, `displayID(for:)`, `findScreen(forSavedID:fallbackOrigin:)`, `clampFrameToVisibleBounds(_:on:margin:)`, `hasNotch(screen:)`, `safeTopBoundary(for:)`.
- **Constants**: `margin` defaults (0.0/8/12) are caller-supplied; no file constants.
- **Properties/state**: `public var onDisplayConfigurationChanged: (() -> Void)?`.
- **Events emitted/listened to**: observes `NSApplication.didChangeScreenParametersNotification`.
- **Side effects**: none persistent.
- **External APIs / system frameworks**: AppKit (`NSScreen`, `NSApplication`, `CGDirectDisplayID` via `NSDeviceDescriptionKey("NSScreenNumber")`), QuartzCore implicit.
- **Files it communicates with**: `StatusItemManager/StatusItemManager.swift` (primary consumer).

## CLASS ENTRY — DisplayManager

- **Class**: `public final class DisplayManager: NSObject` (lines 4–92)
- **Purpose**: Single source of truth for screen geometry/identity for the app.
- **Responsibilities**: resolve display ID for a screen; pick a screen for a saved ID/origin; clamp frames to visible bounds with margins; detect notch; compute safe top boundary; notify on display changes.
- **Constructor/init**: `private override init()` calls `setupObservers()`.
- **Properties**: `public static let shared`, `public var onDisplayConfigurationChanged: (() -> Void)?`.
- **Public vs private**: `shared`, `onDisplayConfigurationChanged`, `displayID`, `findScreen`, `clampFrameToVisibleBounds`, `hasNotch`, `safeTopBoundary` public; `init`, `setupObservers`, `handleDisplayParametersChange` private.
- **Dependencies**: AppKit.
- **Consumers**: `StatusItemManager` (lines 143/145/205/217/263/265/289 of its file).
- **Lifecycle**: app lifetime singleton (lazily created on first access).
- **State**: only the callback.
- **Events**: `onDisplayConfigurationChanged` invoked (on main queue) when `didChangeScreenParametersNotification` fires.
- **Relationships**: assigned as `StatusItemManager`'s display-change handler.
- **What would break if removed**: dragged-window repositioning across display changes and frame clamping would break; StatusItemManager would need its own screen math.

## FUNCTION ENTRIES — DisplayManager

### private override init() (lines 9–12)
- Calls `setupObservers()`. Registers notification observer.

### private func setupObservers() (lines 14–21)
- Adds observer for `NSApplication.didChangeScreenParametersNotification` with selector `#selector(handleDisplayParametersChange)`, object nil.

### @objc private func handleDisplayParametersChange() (lines 23–27)
- Dispatches to main queue and invokes `onDisplayConfigurationChanged?()`.
- **Called by**: NotificationCenter. **Async**: hop to main queue (could already be main).

### public func displayID(for screen: NSScreen) -> CGDirectDisplayID? (lines 30–35)
- **Input**: `NSScreen`. **Output**: `CGDirectDisplayID?`.
- Reads `screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber` → `uint32Value`.
- Returns nil if key absent.

### public func findScreen(forSavedID savedID: CGDirectDisplayID?, fallbackOrigin: CGPoint? = nil) -> NSScreen (lines 38–53)
- **Logic**: if `savedID` matches a screen's `displayID` → return it; else if `fallbackOrigin` lies in a screen's `frame` → return it; else `NSScreen.main` or first screen.
- **Edge**: `NSScreen.screens.isEmpty` guard: returns `NSScreen.main ?? NSScreen.screens.first!` — force-unwrap on empty screens is a crash risk (see RISKS).

### public func clampFrameToVisibleBounds(_ frame: NSRect, on screen: NSScreen, margin: CGFloat = 0.0) -> NSRect (lines 56–75)
- **Purpose**: Clamp frame inside `screen.visibleFrame` (excludes Dock/menu bar) with margin; clamp width/height too.
- **Details**: `width = min(frame.width, visible.width - margin*2)`; `height = min(frame.height, visible.height)`; horizontal clamp between `visible.minX+margin` and `visible.maxX-width-margin`; vertical clamp between `visible.minY+margin` and `visible.maxY-height` (flush to menu bar allowed).

### public func hasNotch(screen: NSScreen) -> Bool (lines 78–83)
- macOS 12+: `screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil`. Else false.

### public func safeTopBoundary(for screen: NSScreen) -> CGFloat (lines 86–91)
- `menuBarHeight = max(24, screenFrame.maxY - visibleFrame.maxY)`; returns `screenFrame.maxY - menuBarHeight`.

---

# FILE 6: Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift`
- **Purpose**: The central playback-state coordinator. Holds current `PlaybackState`, engine mode (online/offline), repeat/shuffle state, an observer list for state broadcasts, track-liked persistence, offline/online engine switching, WebKit JS evaluation helpers, sleep/network monitors, and WebContent-crash recovery flags. Also declares the queue-related DTO structs used by `Queue.swift`.
- **Subsystem**: Core (playback coordination).
- **What depends on it / what it depends on**:
  - Depends on: `StatusItemManager.shared.mainViewController.webViewContainer.webView` (runtime), `NativeAudioPlayer.shared`, `LocalLibraryManager.shared`, `NetworkMonitor.shared`, `DiscordRPCManager.shared`.
  - Depends on it: `MainViewController`, `DynamicIslandPlayerView`, `CenteredMenuBarLyricsWindowController`, `PlaylistManager`, `LikedSongsManager`, `AppVolumeManager`, `NativeAudioPlayer`, `YTMWebView`, `HistoryManager`, and the extensions in this folder (`ObserverBridge`, `PlayerControls`, `Queue`).
- **Important imports**: `import AppKit`, `import WebKit`, `import MediaPlayer`
- **Classes defined**: `NowPlayingManager`; nested structs `QueueItemInfo`, `AutomixItemInfo`, `UpNextSnapshot`.
- **Functions/methods defined**: see FUNCTION ENTRIES below.
- **Constants**: presence-key separator `"|"` built inline; default queue param `[]`.
- **Properties/state**: see CLASS ENTRY.
- **Events emitted/listened to**: posts `Notification.Name("Mooziac_EngineModeChanged")`; observes `NetworkMonitor.statusChangedNotification`, `NSWorkspace.willSleepNotification`/`didWakeNotification`, Distributed `com.apple.screenIsLocked`/`com.apple.screenIsUnlocked`. Serves as `WKScriptMessageHandler` for `"nowPlayingHandler"`.
- **Side effects**: reads/writes `UserDefaults` (`YTM_likedTrackKeysSet`, `YTM_lastIsLiked`, `YTM_lastUrl/VideoId/Time/Title/Artist`); executes JS in the shared webview; changes engine mode.
- **External APIs / system frameworks**: AppKit, WebKit (`WKUserContentController`, `WKWebView`), MediaPlayer (`MPNowPlayingInfoCenter` used via `PlayerControls.swift`), QuartzCore (`CACurrentMediaTime`).
- **Files it communicates with**: `StatusItemManager/StatusItemManager.swift`, `Web/YTMWebView.swift`, `Audio/NativeAudioPlayer.swift`, `Managers/{NetworkMonitor,LocalLibraryManager,DiscordRPCManager}.swift`, the sibling extensions `ObserverBridge.swift`, `PlayerControls.swift`, `Queue.swift`.

## CLASS ENTRY — NowPlayingManager

- **Class**: `NowPlayingManager: NSObject, WKScriptMessageHandler` (lines 5–273)
- **Purpose**: Authoritative runtime state for "what is playing" and the hub for all playback mutation + JS messaging.
- **Responsibilities**:
  - Keep `currentState`, `engineMode`, `repeatMode`, `isShuffleActive`.
  - Observer list + broadcast (`notifyObservers` also pushes to Discord presence).
  - Engine mode switching (offline↔online) with notification post.
  - Offline track playback handoff to `NativeAudioPlayer`.
  - Persist last-track metadata to UserDefaults (via ObserverBridge).
  - Liked-track set persistence (`YTM_likedTrackKeysSet`).
  - Evaluate JS in the shared webview (with sleep guard).
  - WebContent termination recovery state machine.
  - Sleep/network monitoring that toggles `isSystemSleeping` and engine mode.
- **Constructor/init**: `override init()` (lines 45–51): removes `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` defaults, sets up sleep + network observers.
- **Properties (with types)**:
  - `static let shared: NowPlayingManager` (6)
  - `var currentState: PlaybackState = PlaybackState()` (8)
  - `var engineMode: PlaybackEngineMode = .online` (9)
  - `var repeatMode: RepeatMode = .off` (10)
  - `var isShuffleActive: Bool = false` (11)
  - `var observers: [(PlaybackState) -> Void] = []` (12)
  - `var lastSavedTitle = ""` (14)
  - `var lastSavedArtist = ""` (15)
  - `var lastIsPlayingState = false` (16)
  - `var isSystemSleeping = false` (18)
  - `var currentVideoId = ""` (108)
  - `var lastTrackChangeTime: CFTimeInterval = 0` (109)
  - `var isRestoringAfterTermination = false` (110)
  - `var lastDiscordPresenceKey = ""` (111)
- **Public vs private API**: `playOfflineTrack`, `switchToOnlineMode`, `trackKey`, `isTrackLiked`, `setTrackLiked`, `flushSessionState`, and the DTO structs are public; the rest internal.
- **Dependencies**: `StatusItemManager` (runtime), `NativeAudioPlayer`, `NetworkMonitor`, `LocalLibraryManager`, `DiscordRPCManager`, `WKWebView`.
- **Consumers**: see "Depends on it" above.
- **Lifecycle**: singleton, app lifetime.
- **State**: currentState, engineMode, repeatMode, isShuffleActive, observers[], lastSaved*, lastIsPlayingState, isSystemSleeping, currentVideoId, lastTrackChangeTime, isRestoringAfterTermination, lastDiscordPresenceKey.
- **Events**: emits `Mooziac_EngineModeChanged`; invokes observers with `PlaybackState`; observes network/sleep notifications.
- **Relationships**: attaches itself to the webview's `userContentController` via `attach(to:)`; message handler for `nowPlayingHandler`.
- **What would break if removed**: all playback state, engine switching, observer broadcast, JS bridge, liked-set persistence, and queue fetch would stop working; essentially the entire player would be inert.

## FUNCTION ENTRIES — NowPlayingManager.swift

### public func playOfflineTrack(_ track: LocalTrack, in queue: [LocalTrack] = []) (lines 20–35)
- **Purpose**: Switch to offline mode, pause any WebKit playback, play the track via NativeAudioPlayer, notify engine mode change.
- **Inputs**: `track: LocalTrack`, `queue: [LocalTrack]` (default `[]`).
- **Calls**: `evaluateJS(...)` (pause video + `#movie_player.pauseVideo`), `NativeAudioPlayer.shared.play(track:in:)`, `NotificationCenter.default.post(name: NSNotification.Name("Mooziac_EngineModeChanged"))`.
- **Writes**: `engineMode = .offline`.
- **Side effects**: posts notification; pauses web player.
- **Execution flow**: set engineMode → evaluateJS pause → native play → post notification.

### public func switchToOnlineMode() (lines 37–43)
- **Purpose**: If currently offline, pause native audio, set online, post notification.
- **Guard**: `if engineMode == .offline`.
- **Calls**: `NativeAudioPlayer.shared.pause()`, post `Mooziac_EngineModeChanged`.

### override init() (lines 45–51)
- Removes defaults `YTM_likedTrackKeysSet`, `YTM_lastIsLiked`; calls `setupSleepObservers()`, `setupNetworkObserver()`.
- **Side effect**: clears liked-set persistence and last-liked flag on every launch.

### func setupNetworkObserver() (lines 53–64)
- Adds observer on `NetworkMonitor.statusChangedNotification` (main queue).
- **Handler**: if `!NetworkMonitor.shared.isReachable`: print, set `engineMode = .offline`, and if `NativeAudioPlayer.shared.currentTrack == nil && !LocalLibraryManager.shared.allTracks.isEmpty` → `NativeAudioPlayer.shared.primeLastOrFirstTrack()`.

### func setupSleepObservers() (lines 66–82)
- Observes via `NSWorkspace.shared.notificationCenter`: `NSWorkspace.willSleepNotification` → `isSystemSleeping = true`; `NSWorkspace.didWakeNotification` → `false`.
- Observes via `DistributedNotificationCenter.default()`: `NSNotification.Name("com.apple.screenIsLocked")` → `true`; `NSNotification.Name("com.apple.screenIsUnlocked")` → `false`.
- **Note**: observers added with queue `.main` and blocks that are never removed (no token stored) — they live for app lifetime (intended).

### func attach(to webView: WKWebView) (lines 84–86)
- Calls `setupInWebView(webView.configuration.userContentController)`.
- **Called by**: `YTMWebView` (line 170).

### func handleWebContentTermination() (lines 92–99)
- **Purpose**: WebContent crash recovery — suppress stale callbacks and re-register the bridge.
- **Writes**: `isRestoringAfterTermination = true`.
- **Calls**: on main queue → `StatusItemManager.shared?.mainViewController.webViewContainer.webView.configuration.userContentController` → `setupInWebView`.
- **Called by**: `YTMWebView` (line 473).

### func markTerminationRecoveryComplete() (lines 102–105)
- `isRestoringAfterTermination = false`.
- **Called by**: `YTMWebView` (lines 375, 507) after the restored page finishes loading.

### func addObserver(_ observer: @escaping (PlaybackState) -> Void) (lines 113–116)
- Appends observer, then invokes it immediately with `currentState`.
- **Called by**: `MainViewController.setupObservers`, `CenteredMenuBarLyricsWindowController` (line 95).

### func notifyObservers(_ state: PlaybackState) (lines 118–127)
- Iterates `observers` invoking each with `state`.
- Then computes `presenceKey = "\(title)|\(artist)|\(trackID)|\(isPlaying)"`; if `!= lastDiscordPresenceKey` → `DiscordRPCManager.shared.updatePresence(state:)` and update key.
- **Called by**: `userContentController(didReceive:)` (ObserverBridge) and `toggleLike` (PlayerControls) indirectly via observer invocation.

### public func trackKey(title: String, artist: String, videoId: String) -> String (lines 129–137)
- If `videoId` non-empty → `"VID_" + videoId`. Else `"TRACK_" + trimmedLowercased(title) + "_" + trimmedLowercased(artist)`. Empty title → `""`.

### public func isTrackLiked(title: String, artist: String, videoId: String) -> Bool (lines 139–144)
- Reads `UserDefaults.standard.stringArray(forKey: "YTM_likedTrackKeysSet") ?? []`, returns `contains(trackKey(...))`.

### public func setTrackLiked(_ liked: Bool, title: String, artist: String, videoId: String) (lines 146–156)
- Mutates `YTM_likedTrackKeysSet` (as Set→Array) adding/removing `trackKey`.

### public func flushSessionState(keepCookies: Bool = true) (lines 159–185)
- **Purpose**: Clear session state + client caches.
- **Writes**: `URLCache.shared.removeAllCachedResponses()`; resets `currentVideoId`, `lastSavedTitle`, `lastSavedArtist`, `currentState = PlaybackState()`.
- **Calls**: on main queue evaluates `window.ytmObserverInjected = false;` JS in the webview (forces observer re-injection).
- **If `!keepCookies`**: removes `YTM_lastUrl`, `YTM_lastVideoId`, `YTM_lastTime`, `YTM_lastTitle`, `YTM_lastArtist`.
- Prints a flush log.
- **Called by**: `YTMWebView` (line 575).

### func evaluateJS(_ code: String) (lines 243–253)
- **Guard**: `!isSystemSleeping` else return.
- On main queue: get `StatusItemManager.shared?.mainViewController`, `evaluateJavaScript(code)` with error logging only.
- **Called by**: `playOfflineTrack`, `PlayerControls.*`, `Queue.playAutomixItem/playQueueItem/removeQueueItem/triggerAutoplayRadio/moveQueueItem`, `AppVolumeManager`, `NativeAudioPlayer`, `PlaylistManager`, `LikedSongsManager`.

### func evaluateJSWithResult(_ code: String, completion: ((Any?) -> Void)? = nil) (lines 255–272)
- Same as `evaluateJS` but returns `result` via completion; calls `completion?(nil)` when sleeping or no mainVC.
- **Called by**: `LikedSongsManager` (lines 51, 211).

### struct QueueItemInfo (lines 187–211)
- Fields: `index: Int`, `title: String`, `artist: String`, `isSelected: Bool`, `artworkUrl: String = ""`, `duration: String = ""`, `videoId: String = ""`; memberwise public init.

### struct AutomixItemInfo (lines 213–217)
- Fields: `index: Int`, `title: String`, `artist: String`; implicit memberwise init.

### struct UpNextSnapshot (lines 219–240)
- Fields: `contextTitle: String = ""`, `autoplayEnabled: Bool = false`, `items: [QueueItemInfo] = []`, `automixItems: [AutomixItemInfo] = []`, `currentTitle: String = ""`, `currentArtist: String = ""`; public init with defaults.

---

# FILE 7: Sources/Mooziac/Core/NowPlayingManager/ObserverBridge.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/NowPlayingManager/ObserverBridge.swift`
- **Purpose**: Bridges the YouTube Music DOM/player state into native Swift. Registers the `nowPlayingHandler` WKScriptMessage handler, injects a large observer JS bundle (`observerJS`) at document end, and converts incoming messages into `PlaybackState` updates persisted to UserDefaults + broadcast to observers + system Now Playing info.
- **Subsystem**: Core (JS↔native bridge).
- **What depends on it / what it depends on**:
  - Depends on: `WKUserContentController`, `WKScriptMessage`, `NowPlayingManager` (self), `PlaylistManager`, `LikedSongsManager`, `NativeAudioPlayer`, `TrackNotificationManager`, `HistoryManager`, `DiscordRPCManager` (via notifyObservers).
  - Depends on it: `NowPlayingManager.attach` and `handleWebContentTermination`.
- **Important imports**: `import AppKit`, `import WebKit`, `import MediaPlayer`
- **Classes defined**: none (extension of `NowPlayingManager`).
- **Functions/methods defined**: `setupInWebView(_:)`, `userContentController(_:didReceive:)` (native); embedded JS functions: `updateNowPlaying`, `clickYTMElement`, `enforceHighAudioQuality`, `enforceSongMode`, `bindVideoEvents`, `bypassAdsAndPopups`.
- **Constants**: handler name `"nowPlayingHandler"`; JS guard flag `window.ytmObserverInjected`; default artwork fallback `"https://i.ytimg.com/vi/"+videoId+"/hqdefault.jpg"`.
- **Properties/state**: none new (uses NowPlayingManager state).
- **Events emitted/listened to**: WKScriptMessage `nowPlayingHandler`; posts `Mooziac_EngineModeChanged` in offline→online forced switch.
- **Side effects**: injects a persistent user script; handles `videoEnded` events; writes many UserDefaults keys.
- **External APIs / system frameworks**: WebKit (`WKUserScript`, `WKScriptMessage`), MediaPlayer (via updateSystemNowPlayingInfo), QuartzCore (`CACurrentMediaTime`).
- **Files it communicates with**: `Web/YTMWebView.swift` (attach/recovery), `Managers/{PlaylistManager,LikedSongsManager,TrackNotificationManager,HistoryManager}.swift`, `Audio/NativeAudioPlayer.swift`, `PlayerControls.swift` (updateSystemNowPlayingInfo).

## FUNCTION ENTRY — setupInWebView(_ userContentController: WKUserContentController)

- **File**: `ObserverBridge.swift`; **Location**: lines 6–318.
- **Purpose**: (Re)register the message handler and (re)inject the observer JS.
- **Called by**: `NowPlayingManager.attach(to:)`, `handleWebContentTermination()`.
- **Calls**: `userContentController.removeScriptMessageHandler(forName: "nowPlayingHandler")` then `add(self, name: "nowPlayingHandler")`; `userContentController.addUserScript(WKUserScript(source: observerJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))`.
- **JS detail — observerJS** (lines 10–314), an IIFE guarded by `window.ytmObserverInjected`:
  - Caches: `cachedTitle/Artist/Artwork/Album/VideoId`, `lastMetaCheck`, `lastSongModeAttemptID`, plus closure state `lastIsPlaying`, `lastTime`.
  - `updateNowPlaying(force)` (19–162): reads `<video>` (`isPlaying`, `currentTime`, `duration`, `playbackRate`); early-returns on idle without change (line 30: `!force && !isPlaying && lastIsPlaying === false && |currentTime-lastTime| < 0.1`); detects new track (`meta title/artist change` or `currentTime<2 && lastTime>5`); throttles metadata re-read to >3000ms; falls back to DOM selectors for title/artist/artwork; extracts `videoId` from `#movie_player.getVideoData()` or URL `?v=`; defaults artwork to i.ytimg.com when empty/data-URI; reads like status (`ytmusic-like-button-renderer` like-status or aria-label heuristics); reads shuffle/repeat state from player-bar buttons; posts a message with 15 fields: `title, artist, album, artworkUrl, isPlaying, currentTime, duration, playbackRate, pageUrl, videoId, trackID, isLiked, isShuffle, isRepeat` (145–160).
  - `window.clickYTMElement = function(selectors)` (164–185): exposes a global click helper dispatching synthetic mouse events on element/button/icon-button.
  - `enforceHighAudioQuality()` (187–200): sets `AUDIO_QUALITY_HIGH` via player API/options.
  - `enforceSongMode()` (202–229): if `ytmusic-av-toggle` `playback-mode` is `OMV_PREFERRED` (video mode), clicks the `.song-button` once per videoId (`lastSongModeAttemptID` guard) to force audio-only.
  - `bindVideoEvents()` (231–276): binds `play, playing, pause, ended, ratechange, seeked, loadedmetadata, canplay` → `enforceHighAudioQuality(); enforceSongMode(); updateNowPlaying(true)`; `timeupdate` → `updateNowPlaying(false)`; `ended` → if `window.ytmRepeatMode === 1` seekTo(0)+play else post `{event:'videoEnded', videoId}`.
  - `bypassAdsAndPopups()` (278–300): clicks ad skip buttons; for `ad-showing/ad-interrupting` muting video + seeking to duration−0.1 + playbackRate 16; clicks "You There?" dialog buttons.
  - Timers: `bindVideoEvents()` every 3s; `bypassAdsAndPopups` every 1s; a 1s update loop posting when playing.
- **Errors**: all JS in try/catch.

## FUNCTION ENTRY — userContentController(_:didReceive message: WKScriptMessage)

- **File**: `ObserverBridge.swift`; **Location**: lines 320–460.
- **Purpose**: Convert `nowPlayingHandler` messages into state, persistence, system Now Playing, notifications, history, and observer broadcast.
- **Input**: `message: WKScriptMessage`.
- **Guards**: `message.name == "nowPlayingHandler"`; `body as? [String: Any]`; `!isRestoringAfterTermination`.
- **videoEnded handling** (328–340): if `repeatMode == .one` → `seek(to:0); play()`; else if `PlaylistManager.shared.hasActiveContext` and `playNextTrackInPlaylist()` → return; else return.
- **Offline mutual-exclusion** (346–356): if `engineMode == .offline`: if `isPlaying && title non-empty && != "Not Playing"` → `NativeAudioPlayer.shared.pause()`, `engineMode = .online`, post `Mooziac_EngineModeChanged`; else → `return` (ignore in-flight events).
- **Track-change detection** (369–378): `trackChanged = !title.isEmpty && title != "Not Playing" && msgTrackID != currentVideoId`. On change: `currentVideoId = msgTrackID`, `currentTime = 0.0`, `lastTrackChangeTime = CACurrentMediaTime()`. Else if `msgTrackID` non-empty and different → `return` (reject stale).
- **Liked resolution** (380–385): use `isLiked` from JS; if `engineMode == .online && !LikedSongsManager.shared.isSignedIn && !videoId.isEmpty` → `effectiveLiked = LikedSongsManager.shared.isLiked(videoId:)`.
- **State construction** (387–403): `newState = PlaybackState(title, artist, album, artworkUrl, isPlaying, currentTime, duration, pageUrl, videoId, trackID, hostTimestamp: CACurrentMediaTime(), playbackRate, isLiked, isShuffleOn, isRepeatOn)`; `currentState = newState`.
- **Persistence** (407–451): on trackChanged — set `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastIsLiked`; if videoId → `YTM_lastVideoId` + `YTM_lastUrl` (`https://music.youtube.com/watch?v=<id>`); else if pageUrl is a watch URL → `YTM_lastUrl`. On trackChanged → set `YTM_lastTime = 0.0` + `TrackNotificationManager.shared.notifyTrackChange(title:artist:artworkUrl:)`. Else if `isPlaying && currentTime > 1.0` and `|currentTime - YTM_lastTime| >= 5.0` → set `YTM_lastTime`. If `isPlaying` → `HistoryManager.shared.trackDidStartOnline(title:artist:album:artworkUrl:videoId:duration:)`.
- **System info + broadcast** (453–459): `isPlayingChanged = lastIsPlayingState != isPlaying`; `lastIsPlayingState = isPlaying`; if `trackChanged || isPlayingChanged` → `updateSystemNowPlayingInfo(newState)`; `notifyObservers(newState)`.

---

# FILE 8: Sources/Mooziac/Core/NowPlayingManager/PlayerControls.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/NowPlayingManager/PlayerControls.swift`
- **Purpose**: All playback control operations (play/pause/next/previous/seek/repeat/shuffle/like/volume/EQ) executed either against the native offline player or via injected JS in the YTM webview. Also updates `MPNowPlayingInfoCenter`.
- **Subsystem**: Core (playback controls).
- **What depends on it / what it depends on**:
  - Depends on: `NowPlayingManager` (self), `NativeAudioPlayer.shared`, `NetworkMonitor.shared`, `LocalLibraryManager.shared`, `PlaylistManager.shared`, `LikedSongsManager.shared`, `DownloadManager` (static `extractVideoID`), `MPNowPlayingInfoCenter`.
  - Depends on it: all UI controls (DynamicIslandPlayer, keyboard commands via NowPlayingManager), MPRemoteCommand handlers elsewhere (`INFERRED FROM SOURCE` — none in these files).
- **Important imports**: `import AppKit`, `import WebKit`, `import MediaPlayer`
- **Classes defined**: none (extension).
- **Functions/methods defined**: `updateSystemNowPlayingInfo(_:)`, `togglePlayPause()`, `pause()`, `play()`, `nextTrack()`, `previousTrack()`, `setRepeatMode(_:)`, `setShuffleState(_:)`, `toggleShuffle()`, `toggleRepeat()`, `fastForward(seconds:)`, `rewind(seconds:)`, `seek(to:)`, `toggleLike()`, `setEQPreset(_:)`, `adjustVolume(deltaPercent:)`.
- **Constants**: default seek step 10.0s; volume step 4% (from StatusItemManager caller); EQ gain values in JS.
- **Properties/state**: none new.
- **Events emitted/listened to**: none directly (indirectly mutates `currentState`, triggers `notifyObservers` in `toggleLike`).
- **Side effects**: writes JS vars `window.ytmRepeatMode`, `window.ytmShuffleActive`, `window.ytmAudioContext`/`ytmSource`/filters; calls `NativeAudioPlayer`; posts `Mooziac_EngineModeChanged` (via engine switches).
- **External APIs / system frameworks**: WebKit, MediaPlayer (`MPNowPlayingInfoCenter`, `MPMediaItemProperty*`, `MPNowPlayingInfoProperty*`).
- **Files it communicates with**: `Audio/NativeAudioPlayer.swift`, `Managers/{PlaylistManager,LikedSongsManager,DownloadManager,NetworkMonitor,LocalLibraryManager}.swift`.

## FUNCTION ENTRIES — PlayerControls.swift

### func updateSystemNowPlayingInfo(_ state: PlaybackState) (lines 6–19)
- Writes to `MPNowPlayingInfoCenter.default().nowPlayingInfo`: `MPMediaItemPropertyTitle`, `MPMediaItemPropertyArtist`, `MPMediaItemPropertyAlbumTitle`, `MPNowPlayingInfoPropertyElapsedPlaybackTime`, `MPMediaItemPropertyPlaybackDuration`, `MPNowPlayingInfoPropertyPlaybackRate` (1.0 playing / 0.0 paused).
- **Note**: no `MPMediaItemPropertyArtwork`, no remote-command registration here.

### func togglePlayPause() (lines 22–70)
- **Branch 1** (23–33): `engineMode == .offline || !NetworkMonitor.shared.isReachable` → ensure offline engine, if no current track `playLastOrFirstTrack()` else `NativeAudioPlayer.shared.togglePlayPause()`.
- **Branch 2** (36–42): if offline and player idle (empty title / "Not Playing", not playing) and local tracks exist → set offline, `playLastOrFirstTrack()`.
- **Branch 3** (44–69): `NativeAudioPlayer.shared.pause()`; inject JS toggling `#movie_player` play/pause via `getPlayerState()===1`, else `<video>`, else player-bar button.

### func pause() (lines 72–93)
- Offline/no-network → `NativeAudioPlayer.shared.pause()`. Else JS: `pauseVideo()` or `video.pause()`.

### func play() (lines 95–126)
- Offline/no-network → set offline engine, `playLastOrFirstTrack()` if none, else `NativeAudioPlayer.shared.play()`. Else `NativeAudioPlayer.shared.pause()` + JS `playVideo()`/`video.play()`.

### func nextTrack() (lines 128–216)
- If `PlaylistManager.shared.hasActiveContext` → `playNextTrackInPlaylist()`; if true return.
- Offline/no-network → native `nextTrack()` (or `playLastOrFirstTrack()` if none).
- Else JS with 3 priorities: (1) player-bar next button (`ytmusic-player-bar .next-button`, `.next-button`, `#next-button`, `tp-yt-paper-icon-button.next-button`, `button[aria-label*="Next"]`, `[title*="Next"]`); (2) next visible queue item after the selected one; (3) `player.nextVideo()`.

### func previousTrack() (lines 218–306)
- Mirror of `nextTrack` with previous button / previous queue item / `player.previousVideo()`.

### public func setRepeatMode(_ mode: RepeatMode) (lines 308–361)
- Sets `self.repeatMode`; calls `NativeAudioPlayer.shared.setRepeatMode(mode)`.
- JS: sets `window.ytmRepeatMode = mode.rawValue` (0/1), `v.loop = false`, `player.setLoop(mode===1)`, and clicks the player-bar repeat button with 120ms re-click retry until `getRepeatState` matches (states: 1=repeat-one, 2=repeat-all, 0=off).

### public func setShuffleState(_ active: Bool) (lines 363–385)
- `self.isShuffleActive = active`; offline → `NativeAudioPlayer.shared.setShuffleState(active)`; else JS sets `window.ytmShuffleActive` and clicks player-bar shuffle button.

### func toggleShuffle() (lines 387–389)
- `setShuffleState(!isShuffleActive)`.

### func toggleRepeat() (lines 391–396)
- `off → .one`, `.one → .off` via `setRepeatMode`.

### func fastForward(seconds: Double = 10.0) (lines 398–419)
- Offline → `NativeAudioPlayer.shared.fastForward(seconds:)`. Else JS `player.seekTo(min(dur, curr+seconds))` or `video.currentTime`.

### func rewind(seconds: Double = 10.0) (lines 421–441)
- Offline → native `rewind`. Else JS `seekTo(max(0, curr-seconds))`.

### func seek(to seconds: Double) (lines 443–462)
- Offline → `NativeAudioPlayer.shared.seek(to:)`. Else JS `player.seekTo(seconds, true)` or `video.currentTime = seconds`.

### func toggleLike() (lines 464–517)
- Offline/no-network → `NativeAudioPlayer.shared.toggleLike()`; if `currentTrack` exists → `LikedSongsManager.shared.mirrorOfflineLike(trackID:)`.
- Online: `desiredLiked = !currentState.isLiked`; derive `videoId` from `currentState.videoId` or `DownloadManager.extractVideoID(from: pageUrl)`; if non-empty → `LikedSongsManager.shared.recordOnlineLikeToggle(...)`.
- If `!LikedSongsManager.shared.isSignedIn` → optimistic local update: `currentState.isLiked = desiredLiked`; `observers.forEach { $0(currentState) }`; return (does NOT click YTM button).
- If signed in → JS clicks the like button in `ytmusic-like-button-renderer` and after 250ms calls `updateNowPlaying(true)`.

### func setEQPreset(_ preset: String) (lines 519–575)
- JS creates a `WebAudio` chain (`ytmAudioContext`, `ytmSource` from `<video>`, lowshelf `ytmLowFilter` 250Hz, peaking `ytmMidFilter` 1500Hz Q=1, highshelf `ytmHighFilter` 4000Hz) on first call, then applies preset gains:
  - `bass boost`: 8 / −1 / 2
  - `vocal booster`: −2 / 7 / 3
  - `treble boost`: −2 / 2 / 8
  - `pop / edm`: 5 / −3 / 6
  - anything else ("Flat"): 0 / 0 / 0
- **Note**: connecting a MediaElementSource steals routing; reconnection across page loads requires `ytmAudioContext` reset (per-page state, lost on navigation — see RISKS).

### func adjustVolume(deltaPercent: Double) (lines 577–589)
- JS: `video.volume = clamp(current + deltaPercent/100, 0, 1)`.
- **Called by**: `StatusItemManager` scroll-wheel monitor (±4% per step).

---

# FILE 9: Sources/Mooziac/Core/NowPlayingManager/Queue.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/NowPlayingManager/Queue.swift`
- **Purpose**: Queue/Up-Next operations executed against the YTM DOM/player API — fetch queue, fetch Up-Next snapshot, play/remove/move queue items, play automix items, and trigger autoplay radio.
- **Subsystem**: Core (queue bridge).
- **What depends on it / what it depends on**:
  - Depends on: `NowPlayingManager` (self, `evaluateJS`), `StatusItemManager.shared.mainViewController.webViewContainer.webView`.
  - Depends on it: `PlaylistManager` (calls `fetchUpNextSnapshot`), and UI queue views.
- **Important imports**: `import AppKit`, `import WebKit`, `import MediaPlayer`
- **Classes defined**: none (extension).
- **Functions/methods defined**: `fetchQueue(completion:)`, `fetchUpNextSnapshot(completion:)`, `playAutomixItem(at:)`, `playQueueItem(at:)`, `removeQueueItem(at:)`, `playNextQueueItem(from:)`, `triggerAutoplayRadio()`, `moveQueueItem(from:to:)`.
- **Constants**: none (embedded JS uses inline selectors).
- **Properties/state**: none new.
- **Events emitted/listened to**: none (pure JS bridge + completion callbacks).
- **Side effects**: clicks DOM buttons (autoplay toggle, radio button), mutates Polymer queue model (`queueObj.items.splice`, `q.notifyPath('queue.items')`).
- **External APIs / system frameworks**: WebKit (JS evaluation with result).
- **Files it communicates with**: `StatusItemManager/StatusItemManager.swift`, `Managers/PlaylistManager.swift`.

## FUNCTION ENTRIES — Queue.swift

### public func fetchQueue(completion: @escaping ([QueueItemInfo]) -> Void) (lines 6–195)
- **Purpose**: Read the current queue as `[QueueItemInfo]`.
- JS strategy (3 priorities): (1) DOM `ytmusic-player-queue-item` nodes (dedup by title+artist lowercase key; skips hidden template nodes with zero rect); (2) Polymer model `q.queue/q.playerQueue/(q.data && q.data.queue).items` with `playlistPanelVideoRenderer`; (3) `ytmusic-player-bar.playerApi`/`#movie_player.getPlaylist()` + `getPlaylistIndex()`. If `res.length <= 1` → click autoplay toggle if off + click radio button to populate Up Next.
- Returns array over the JS bridge; Swift maps `[[String:Any]]` → `QueueItemInfo`. Runs on main queue; `completion([])` when no webview/parse fail.

### public func fetchUpNextSnapshot(completion: @escaping (UpNextSnapshot) -> Void) (lines 197–435)
- **Purpose**: Rich snapshot for the Up Next UI: queue items (with artworkUrl/duration/videoId), automix previews, autoplay-enabled, context title, current title/artist.
- JS: helper `visible`, `extractText`, `extractThumb`, `extractDuration`, `extractVideoId`; priority DOM→model extraction; automix from `ytmusic-automix-preview-video-renderer`; context title from header selectors; returns `{items, automix, autoplayEnabled, contextTitle, currentTitle, currentArtist}`.
- Swift maps to `UpNextSnapshot`; `completion(UpNextSnapshot())` on failure.
- **Called by**: `PlaylistManager` (line 296).

### public func playAutomixItem(at index: Int) (lines 437–472)
- JS: finds nth visible `ytmusic-automix-preview-video-renderer`, synthetic-clicks thumbnail/link/button. Uses `evaluateJS`.

### public func playQueueItem(at index: Int) (lines 474–518)
- JS: nth visible `ytmusic-player-queue-item` → `simulateClick` (button/icon-button/play-button/self).

### public func removeQueueItem(at index: Int) (lines 520–551)
- JS: nth visible queue item → click remove button (`[aria-label*="Remove"]`, `.remove-button`, `[icon*="close"]`, etc.); else `targetItem.remove()` + splice Polymer `queueObj.items` + `q.notifyPath('queue.items')`.

### public func playNextQueueItem(from fromIndex: Int) (lines 553–563)
- Calls `fetchQueue`; computes `currentIndex = items.firstIndex(where: isSelected) ?? 0`; `targetIndex = min(count-1, currentIndex+1)`; if `fromIndex != targetIndex` and in range → `moveQueueItem(from:to:)`. (Note: `fromIndex` is essentially ignored except as a validity check.)
- **Called by**: UI "Play Next" action (`INFERRED FROM SOURCE`).

### public func triggerAutoplayRadio() (lines 565–587)
- JS: click autoplay toggle if off + click radio button (same selectors as fetchQueue's automix trigger).

### public func moveQueueItem(from fromIndex: Int, to toIndex: Int) (lines 589–633)
- JS: DOM `insertBefore` move between visible queue items; also splice-move Polymer `queueObj.items` and `notifyPath('queue.items')`.

---

# FILE 10: Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift`
- **Purpose**: Owns the menu bar status item, the popover `NSPanel`, the `MainViewController`, panel positioning (docked vs. free-floating/dragged), event monitors (click-outside close, keyboard commands, global clicks), scroll-wheel volume control, and menu-bar/panel lifecycle. Persists dragged-panel frame state.
- **Subsystem**: Core (menu bar UI management).
- **What depends on it / what it depends on**:
  - Depends on: `StatusItemPanel`, `MainViewController`, `DisplayManager.shared`, `NowPlayingManager.shared`, `KeyboardCommandHandler`, `CenteredMenuBarLyricsWindowController.shared`, `WKWebsiteDataStore`.
  - Depends on it: `AppDelegate` (creates it), `NowPlayingManager`/`Queue`/`PlaylistManager`/`HistoryManager`/`LaunchAnimationController`/`GestureMappingManager`/`NativeGestureTutorialWindowController` (access `shared`/`mainViewController`/`statusItem.button`).
- **Important imports**: `import AppKit`, `import WebKit`
- **Classes defined**: `StatusItemManager`.
- **Functions/methods defined**: see FUNCTION ENTRIES (24 + computed property).
- **Constants**: sizing constants inline (360 wide, 120 tall panel, margins 8/12).
- **Properties/state**: see CLASS ENTRY.
- **Events emitted/listened to**: observes `NSWindow.didMoveNotification` (panel), `NSApplication.didResignActiveNotification`; receives scroll-wheel events via local monitor; `DisplayManager.shared.onDisplayConfigurationChanged` callback.
- **Side effects**: writes `YTM_isDraggedFromDock`, `YTM_playerFrameX`, `YTM_playerFrameY`, `YTM_playerTopY`, `YTM_savedDisplayID`, `YTM_hasLoggedInOnce`; creates/removes event monitors; presents panel/context menu.
- **External APIs / system frameworks**: AppKit (`NSStatusItem`, `NSEvent`, `NSPanel`, `NSMenu`, `NSAlert`), WebKit (`WKWebsiteDataStore`).
- **Files it communicates with**: `StatusItemPanel.swift`, `ContextMenu.swift` (extension in same folder), `MainViewController.swift`, `DisplayManager.swift`, `App/AppDelegate.swift`.

## CLASS ENTRY — StatusItemManager

- **Class**: `StatusItemManager: NSObject` (lines 4–495)
- **Purpose**: Menu-bar presence + panel geometry + input monitoring hub.
- **Responsibilities**: create status item with icon; create panel with MainViewController; position panel docked under the status item or at a saved dragged location; detect user drags via `panelDidMove`; persist dragged frame; close panel on outside clicks / resign-active; forward keyboard commands; scroll-wheel volume; context menu (delegated to `ContextMenu.swift`); login reset (cookies) and reload/quit actions.
- **Constructor/init**: `override init()` (34–39): `StatusItemManager.shared = self; setupStatusItem(); setupPanel()`.
- **Properties (with types)**:
  - `public static weak var shared: StatusItemManager?` (5) — weak on purpose; `AppDelegate` holds the strong ref.
  - `public private(set) var statusItem: NSStatusItem!` (7)
  - `var panel: StatusItemPanel!` (8)
  - `let mainViewController = MainViewController()` (9)
  - `public private(set) var isDraggedFromDock: Bool = false` (10)
  - `private var globalEventMonitor: Any?` (12)
  - `private var localEventMonitor: Any?` (13)
  - `private var keyEventMonitor: Any?` (14)
  - `private var isProgrammaticallyPositioning: Bool = false` (156)
  - `private var dragDebounceTimer: Timer?` (157)
  - computed `public var statusButtonCenterInScreen: CGPoint?` (16–32)
- **Public vs private**: `shared`, `statusItem`, `isDraggedFromDock`, `statusButtonCenterInScreen`, `playLaunchPopAnimation`, `dockBackToMenuBar`, `resetLoginFromMenu`, `reloadFromMenu`, `quitFromMenu` public; rest internal/private.
- **Dependencies**: MainViewController, StatusItemPanel, DisplayManager, NowPlayingManager, KeyboardCommandHandler, CenteredMenuBarLyricsWindowController.
- **Consumers**: AppDelegate; LaunchAnimationController (`playLaunchPopAnimation`, `statusButtonCenterInScreen`); GestureMappingManager (`statusItem.button`, `togglePanel`); NativeGestureTutorialWindowController; NowPlayingManager/Queue/PlaylistManager/HistoryManager (`mainViewController.webViewContainer.webView`).
- **Lifecycle**: created in `applicationDidFinishLaunching`; strong-held by AppDelegate; `deinit` stops monitors.
- **State**: isDraggedFromDock, panel visibility, monitors, programmatic-positioning flag, debounce timer.
- **Events**: `NSWindow.didMoveNotification` (panel), `NSApplication.didResignActiveNotification`; DisplayManager callback.
- **Relationships**: owns panel + mainViewController; wires `onChangeSize`/`onResetPosition`; sets `DisplayManager.shared.onDisplayConfigurationChanged`.
- **What would break if removed**: no menu bar icon, no panel, no NowPlaying/Playlist/Queue access to the webview (they all dereference `StatusItemManager.shared?.mainViewController`), no launch animation anchor.

## FUNCTION ENTRIES — StatusItemManager.swift

### public var statusButtonCenterInScreen: CGPoint? (lines 16–32)
- Computed: uses `statusItem.button`; prefers `button.window.frame` mid-point if valid (`width>0 && height>0 && minY>0`), else converts button bounds to screen; returns nil otherwise.
- **Consumers**: `LaunchAnimationController` (lines 27, 58).

### override init() (lines 34–39)
- `StatusItemManager.shared = self; setupStatusItem(); setupPanel()`.

### public func playLaunchPopAnimation() (lines 41–53)
- Scales status button from 0.4→1.0 with alpha 0→1 over 0.38s easeOut.
- **Called by**: `LaunchAnimationController` (line 116).

### deinit (lines 55–57)
- `stopEventMonitors()`.

### private func setupStatusItem() (lines 59–81)
- Creates `NSStatusItem` (variable length); sets alpha 0; `restoreDefaultIcon`; target/action `#selector(statusItemClicked(_:))`; `sendAction(on: [.leftMouseUp, .rightMouseUp])`; toolTip `"Mooziac Music Player (Scroll to adjust volume)"`.
- Adds local scroll-wheel monitor (line 71–80): if `event.window == statusItem.button.window` and `|deltaY| > 0.1` → `NowPlayingManager.shared.adjustVolume(deltaPercent: delta > 0 ? 4.0 : -4.0)`, consume event; else pass through.

### private func restoreDefaultIcon(_ button: NSStatusBarButton) (lines 83–98)
- Loads `MenuBarIcon` or `MOOZIAC_transparent` from bundle, resized to 16×16, `isTemplate = true`; else SF Symbol `"music.note"` (pointSize 12, semibold), template.

### private func setupPanel() (lines 100–131)
- `panel = StatusItemPanel(contentViewController: mainViewController)`.
- Forces docked start: `isDraggedFromDock = false`; `UserDefaults.standard.set(false, forKey: "YTM_isDraggedFromDock")`; `panel.level = .statusBar`; `dynamicIslandPlayer.setResetPositionButtonHidden(true)`.
- Wires `mainViewController.onChangeSize = { [weak self] width, height in self?.positionPanel(width:height:) }` (109–112).
- Wires `mainViewController.onResetPosition = { ... }` (114–123): sets `isDraggedFromDock = false`, persists false, `panel.level = .statusBar`, repositions current size, hides reset button.
- Observer: `NSWindow.didMoveNotification` with object `panel` → `#selector(panelDidMove)` (125).
- Assigns `DisplayManager.shared.onDisplayConfigurationChanged` (128–130).

### @objc private func handleDisplayConfigurationChanged() (lines 133–154)
- Guards `panel != nil`.
- If `isDraggedFromDock`: read `YTM_playerFrameX/Y`, `YTM_savedDisplayID`; `findScreen(forSavedID:fallbackOrigin:)`; clamp with margin 12; `panel.setFrame(clampedFrame, display:true, animate:true)`.
- Else `positionPanel(width:height:)` with current view size.
- Then `CenteredMenuBarLyricsWindowController.shared.repositionInCenter(contentWidth: 280)`.

### @objc private func panelDidMove() (lines 159–221)
- **Purpose**: Detect user dragging the panel away from the menu bar (floating player mode) and persist the frame.
- **Guards** (160–166): `!isProgrammaticallyPositioning`; panel/button/window present; `!isBrowserMode && !isOfflineLibraryMode`; panel size ≤ 360×120; mouse pressed (`pressedMouseButtons & 1 != 0` or `.leftMouseDragged`).
- Computes target position under the status button if button is on-screen (x in (50, width−5)), else top-right fallback.
- `isDragged = distance > 25`; when changed, toggles `isDraggedFromDock`, updates reset-button hidden state, and if dragged sets `panel.level = .floating`.
- Debounce timer 0.12s: if dragged, clamp frame (margin 8, `isProgrammaticallyPositioning` toggled around `setFrame`), persist `YTM_isDraggedFromDock=true`, `YTM_playerFrameX/Y`, `YTM_playerTopY`, `YTM_savedDisplayID` (from `DisplayManager.shared.displayID(for:)`).

### func positionPanel(width: CGFloat, height: CGFloat) (lines 223–225)
- Forwards to `positionCustomWindow(panel, width:width, height:height)`.

### func positionCustomWindow(_ targetWindow: NSWindow, width: CGFloat, height: CGFloat) (lines 227–291)
- **Purpose**: Place the window under the status item or restore a saved floating position.
- Sets `isProgrammaticallyPositioning = true` (deferred reset).
- If `isDraggedFromDock && width <= 360 && !isBrowserMode && !isOfflineLibraryMode && YTM_playerFrameX != nil` (249–269): use saved frame (`YTM_playerFrameX`, `YTM_playerTopY` or `YTM_playerFrameY`, `YTM_savedDisplayID`), clamp margin 8, `setFrame`.
- Else: compute target under button (centered horizontally, bottom edge at button minY) when button position is valid, else top-right under menu bar; clamp margin 0; `setFrame`.

### @objc private func statusItemClicked(_ sender: NSStatusBarButton) (lines 293–302)
- If event is `.rightMouseUp`/`.rightMouseDown` → `showContextMenu(sender)`.
- Else if `clickCount == 2` → `showPanel(sender)`.
- Else → `togglePanel(sender)`.

### public func dockBackToMenuBar() (lines 304–310)
- `isDraggedFromDock = false`; `panel.level = .statusBar`; reposition current size; hide reset button.
- **Called by**: `MainViewController.dynamicIslandDidTapResetPosition`.

### func togglePanel(_ sender: NSStatusBarButton) (lines 312–318)
- If visible and alpha > 0.5 → `closePanel()`; else `showPanel(sender)`.

### func showPanel(_ sender: NSStatusBarButton) (lines 320–335)
- Positions panel at current view size; alpha 0; `makeKeyAndOrderFront(nil)`; `NSApp.activate(ignoringOtherApps: true)`; fade to alpha 1 over 0.12s; `startEventMonitors()`.

### func closePanel() (lines 337–347)
- `dynamicIslandPlayer.collapseSettings()`; fade alpha to 0 over 0.10s; completion → `panel.orderOut(nil)` + `stopEventMonitors()`.

### private func isClickInsidePanelOrStatusButton(mouseLoc: NSPoint) -> Bool (lines 349–373)
- True if inside panel frame, or status button screen frame / button window frame, or any `panel.childWindows`.

### private func startEventMonitors() (lines 375–429)
- Calls `stopEventMonitors()` first.
- localEventMonitor (378–389): left/right/other mouse-down; if panel not visible or dragged → pass; if click inside panel/button → pass; else `closePanel()`.
- keyEventMonitor (391–414): keyDown; if panel not visible → pass; if firstResponder is text-ish (`NSText`/`NSTextView`/`NSTextField`/`NSSearchField`) → pass; if responder class contains `"WK"`/`"Web"` or is descendant of `webViewContainer.webView` → pass; else `KeyboardCommandHandler.handle(keyCode:event.isARepeat, showOverlay: { CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text:) })`; if handled → consume (`return nil`).
- globalEventMonitor (416–426): global left/right mouse-down; same outside-click → `closePanel()`.
- Adds observer for `NSApplication.didResignActiveNotification` → `#selector(appDidResignActive)`.

### func stopEventMonitors() (lines 431–445)
- Removes all three monitors (nil-ing them) and removes the resign-active observer.

### @objc private func appDidResignActive() (lines 447–454)
- If panel visible and not dragged and click outside → `closePanel()`.

### @objc private func toggleFromMenu() (lines 455–459)
- `togglePanel(statusItem.button)` (used by context menu / hotkeys; not referenced in ContextMenu.swift — see RISKS).

### @objc private func toggleCenteredLyricsFromMenu() (lines 461–463)
- `CenteredMenuBarLyricsWindowController.shared.toggleOverlay()` (not referenced in ContextMenu.swift — see RISKS).

### @objc func resetLoginFromMenu() (lines 465–478)
- Clears all `WKWebsiteDataStore` data; then sets `YTM_hasLoggedInOnce = false`; `setBrowserVisible(true)`; `webViewContainer.loadGoogleLogin()`; overlay "Cleared Web Cookies".
- **Used by**: `ContextMenu.swift` menu item "Reset Login (Fresh Start)".

### @objc func reloadFromMenu() (lines 480–482)
- `mainViewController.webViewContainer.webView.reload()`.
- **Used by**: ContextMenu "Reload Player Engine".

### @objc func quitFromMenu() (lines 484–494)
- Modal `NSAlert` (Quit/Cancel); on `.alertFirstButtonReturn` → `NSApplication.shared.terminate(nil)`.
- **Used by**: ContextMenu "Quit Mooziac".

---

# FILE 11: Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift`
- **Purpose**: The borderless, transparent, non-activating panel that hosts the `MainViewController` popover.
- **Subsystem**: Core (panel).
- **What depends on it / what it depends on**: depends on `MainViewController` (content); depended on by `StatusItemManager`.
- **Important imports**: `import AppKit`
- **Classes defined**: `StatusItemPanel` (final, `NSPanel`).
- **Functions/methods defined**: `init(contentViewController:)`, overrides `canBecomeKey`, `canBecomeMain`.
- **Constants**: initial contentRect 360×120.
- **Properties/state**: none beyond NSPanel inherited.
- **Events emitted/listened to**: none; emits `NSWindow.didMoveNotification` (observed by StatusItemManager).
- **Side effects**: none persistent.
- **External APIs / system frameworks**: AppKit (`NSPanel`).
- **Files it communicates with**: `StatusItemManager.swift`.

## CLASS ENTRY — StatusItemPanel

- **Class**: `final class StatusItemPanel: NSPanel` (lines 3–29)
- **Purpose**: Custom popover panel with transparent background, shadow, status-bar level, full-screen auxiliary behavior.
- **Constructor/init**: `init(contentViewController:)` (4–20): `contentRect 360×120`, styleMask `[.borderless, .nonactivatingPanel]`, backing `.buffered`, `defer: false`; sets `contentViewController`, `isOpaque=false`, `backgroundColor = .clear`, `hasShadow = true`, `level = .statusBar`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`, `isMovableByWindowBackground = true`, `hidesOnDeactivate = false`.
- **Properties**: none custom.
- **Public vs private**: internal; `canBecomeKey`/`canBecomeMain` overrides return `true`.
- **Dependencies**: AppKit.
- **Consumers**: `StatusItemManager`.
- **Lifecycle**: created once in `StatusItemManager.setupPanel`.
- **State**: NSPanel visible/alpha/frame managed by StatusItemManager.
- **Events**: `NSWindow.didMoveNotification` observed externally.
- **Relationships**: content = MainViewController.
- **What would break if removed**: no panel to present the player UI; StatusItemManager broken.

---

# FILE 12: Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift

## FILE ENTRY

- **File**: `Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift`
- **Purpose**: Builds and presents the right-click context menu for the status item: gesture settings (master toggle + individual toggles + custom gesture mappings + tutorial), settings (download location, clear history), reset login, reload engine, quit.
- **Subsystem**: Core (menu bar UI).
- **What depends on it / what it depends on**:
  - Depends on: `NativeCapsuleToggleView`, `GestureMappingManager`, `GestureType`, `GestureAction` (Models), `EdgeVolumeEngine.shared`, `AudioRouteMonitor.shared`, `LocalLibraryManager.shared`, `HistoryManager.shared`, `CenteredMenuBarLyricsWindowController.shared`, `NativeGestureTutorialWindowController.shared`.
  - Depends on it: `StatusItemManager` (extension).
- **Important imports**: `import AppKit`
- **Classes defined**: none (extension of `StatusItemManager`).
- **Functions/methods defined**: 14 (see FUNCTION ENTRIES).
- **Constants**: menu layout sizes (container 280×26, label 220×20 at (12,3), toggle 32×18 at (236,4)).
- **Properties/state**: local captured toggle refs (`volumeSwipeToggle`, `rightCornerToggle`, `leftCornerToggle`) so the master toggle can sync children.
- **Events emitted/listened to**: none (menu actions).
- **Side effects**: mutates `EdgeVolumeEngine`/`AudioRouteMonitor` settings, `LocalLibraryManager` music folder defaults (`YTM_downloadsFolder`), clears history, resets login, quits app.
- **External APIs / system frameworks**: AppKit (`NSMenu`, `NSMenuItem`, `NSOpenPanel`, `NSAlert`, `NSTextField`).
- **Files it communicates with**: `StatusItemManager.swift`, `Input/GestureMappingManager.swift`, `Models/GestureMappingModels.swift`, `Audio/EdgeVolumeEngine.swift`, `Audio/AudioRouteMonitor.swift`, `Managers/{LocalLibraryManager,HistoryManager}.swift`, `Views/Windows/{CenteredMenuBarLyricsWindowController,NativeGestureTutorialWindowController}.swift`, `Views/Components/NativeCapsuleToggleView.swift`.

## FUNCTION ENTRIES — ContextMenu.swift

### private func makeCapsuleToggleMenuItem(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> (menuItem: NSMenuItem, toggleView: NativeCapsuleToggleView) (lines 4–22)
- Builds a 280×26 container with a 12pt label and a `NativeCapsuleToggleView`; returns menuItem + toggleView for later sync.

### private func makeGestureMappingMenuItem(for gesture: GestureType) -> NSMenuItem (lines 24–43)
- Parent item with submenu of all `GestureAction.allCases`; marks current mapping (`GestureMappingManager.shared.getAction(for:)`) with `.on`; each item's `representedObject = ["gestureRaw":..., "actionRaw":...]`, action `#selector(didSelectGestureMapping(_:))`, target self.

### @objc private func didSelectGestureMapping(_ sender: NSMenuItem) (lines 45–53)
- Parses `representedObject`; `GestureMappingManager.shared.setAction(action, for: gesture)`; overlay `"\(gesture.displayName): \(action.displayName)"`.

### func showContextMenu(_ sender: NSStatusBarButton) (lines 55–172)
- If panel visible → collapse settings, alpha 0, `orderOut`, `stopEventMonitors`.
- Builds menu:
  - Gesture submenu: Master toggle (isOn = `EdgeVolumeEngine.shared.isEnabled`) whose onToggle syncs the three child toggles; separator; Right Edge Volume Swipe (`isRightEdgeVolumeEnabled`); Bottom-Right Corner Taps (`isRightCornerTapsEnabled`); Bottom-Left Corner Taps (`isLeftCornerTapsEnabled`); separator; "Custom Gesture Mappings" submenu (one mapping submenu per `GestureType.allCases`); separator; "Show Gesture Tutorial" (`#selector(showGestureTutorialFromMenu)`, key `t`).
  - Settings submenu: disabled "Download Location" info (`📁 \(currentDownloadLocationTitle())`), "Select Download Location…" (`#selector(selectDownloadLocationFromMenu)`), "Reset to Default Location" (`#selector(resetDownloadLocationFromMenu)`), "Clear Listening History" (`#selector(clearListeningHistoryFromMenu)`).
  - "Reset Login (Fresh Start)" → `#selector(resetLoginFromMenu)`; "Reload Player Engine" → `#selector(reloadFromMenu)` (key `r`); "Quit Mooziac" → `#selector(quitFromMenu)` (key `q`).
- Sets all nil targets to self (163–167); assigns `statusItem.menu = menu`, `performClick(nil)`, then `statusItem.menu = nil` (menu-bar menu presentation trick).
- **Note**: keyEquivalent `"r"` and `"q"` on menu items that are NOT in a proper menu bar menu — may be inert while the menu is a temporary status-item menu (see RISKS).

### @objc private func showGestureTutorialFromMenu() (lines 174–176)
- `NativeGestureTutorialWindowController.shared.showTutorial()`.

### private func currentDownloadLocationTitle() -> String (lines 178–185)
- Reads `YTM_downloadsFolder`; if set returns `LocalLibraryManager.shared.musicFolderURL.path`; else `"Default — \(defaultMusicFolderURL.path)"`.
- **Bug note**: when custom folder is set it still returns the same as the else branch (custom path = musicFolderURL; the display never shows "Default —" but always prints path) — logic is fine but redundant; effectively both branches return folder paths.

### @objc private func selectDownloadLocationFromMenu() (lines 187–206)
- `NSOpenPanel` (directories only); completion: `LocalLibraryManager.shared.setMusicFolder(url)`; overlay `"📁 Download location set to \(url.lastPathComponent)"`; if panel visible → `dynamicIslandPlayer.refreshPlaylistsSection()`.

### @objc private func resetDownloadLocationFromMenu() (lines 208–214)
- `LocalLibraryManager.shared.resetMusicFolderToDefault()`; overlay reset text; refresh playlists if panel visible.

### @objc private func clearListeningHistoryFromMenu() (lines 216–231)
- Warning `NSAlert`; on `.alertFirstButtonReturn` → `HistoryManager.shared.clearHistory()`; overlay `"🗑 Listening history cleared"`; refresh playlists if panel visible.

### @objc private func toggleMasterGestures() (lines 233–235)
- `EdgeVolumeEngine.shared.isEnabled.toggle()` — **dead code** (no menu item references this selector; master toggle uses `makeCapsuleToggleMenuItem`'s closure instead).

### @objc private func toggleAutoPauseOnDisconnect() (lines 237–239)
- `AudioRouteMonitor.shared.isAutoPauseOnDisconnectEnabled.toggle()` — **dead code** (not referenced by any menu item).

### @objc private func toggleRightEdgeVolume() (lines 241–243)
- `EdgeVolumeEngine.shared.isRightEdgeVolumeEnabled.toggle()` — **dead code**.

### @objc private func toggleRightCornerTaps() (lines 245–247)
- `EdgeVolumeEngine.shared.isRightCornerTapsEnabled.toggle()` — **dead code**.

### @objc private func toggleLeftCornerTaps() (lines 249–251)
- `EdgeVolumeEngine.shared.isLeftCornerTapsEnabled.toggle()` — **dead code** (all five toggle* selectors are superseded by the capsule-toggle closures).

---

# STATE

Every important state store owned by these files:

| Store | Owner | Initial | Written by | Read by | Persistence | Lifecycle | Race risks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `statusItemManager` | `AppDelegate` | nil | `applicationDidFinishLaunching` | (dealloc only) | none | app | — |
| `StatusItemManager.shared` (weak static) | StatusItemManager | nil | `StatusItemManager.init` | NowPlayingManager, Queue, PlaylistManager, HistoryManager, LaunchAnimationController, GestureMappingManager, NativeGestureTutorialWindowController | none | app (weak; strong ref in AppDelegate) | If AppDelegate releases, shared could dangle → nil-safe optionals everywhere |
| `assertionID` / `processActivity` | BackgroundMediaController | 0 / nil | start/stopPreventingSleep | guard in start | none | app | `init()` already calls start; AppDelegate calls again (idempotent) |
| `audioEngine`/`audioPlayerNode` | BackgroundMediaController | nil | **never** | stop (no-op) | none | — | dead code |
| Mode flags `isBrowserMode`/`isOfflineLibraryMode`/`isPlaylistLibraryMode` | MainViewController | false | setBrowserVisible/setOfflineLibraryVisible/setPlaylistLibraryVisible | panelDidMove/positionCustomWindow, delegate methods | none | panel life | mode-set calls are not atomic; nested calls during transitions (e.g. search → setBrowserVisible(false)+setOfflineLibraryVisible(false)) |
| `onChangeSize`/`onResetPosition` | MainViewController | nil | StatusItemManager.setupPanel | mode setters, dynamicIslandDidToggleExpanded, dynamicIslandDidTapResetPosition | none | app | `viewDidLoad` fires mode setters before closures wired → no-ops at startup |
| `currentState` | NowPlayingManager | `PlaybackState()` | userContentController(didReceive:), toggleLike, flushSessionState | observers, HistoryManager, PlaylistManager, DiscordRPC | in-memory (reset by flush) | app | Written on main queue only (message handler main? see RISKS) |
| `engineMode` | NowPlayingManager | `.online` | playOfflineTrack, switchToOnlineMode, network observer, userContentController | PlayerControls, MainViewController, LikedSongsManager | in-memory | app | Multiple writers; notification `Mooziac_EngineModeChanged` has no listeners (see RISKS) |
| `repeatMode` | NowPlayingManager | `.off` | setRepeatMode, (toggleRepeat) | userContentController (videoEnded), setRepeatMode JS | in-memory | app | JS state (`window.ytmRepeatMode`) can drift from Swift value if user toggles in YTM directly |
| `isShuffleActive` | NowPlayingManager | false | setShuffleState, toggleShuffle | toggleShuffle | in-memory | app | Same drift risk |
| `observers: [(PlaybackState)->Void]` | NowPlayingManager | [] | addObserver | notifyObservers, toggleLike | in-memory | app; never removed (leak of closures capturing views) | Closures captured by `[weak self]` in MainViewController; CenteredMenuBarLyricsWindowController closure may capture strong (line 95 — `INFERRED FROM SOURCE`) |
| `lastSavedTitle`/`lastSavedArtist` | NowPlayingManager | "" | userContentController | (persisted to UserDefaults) | in-memory + mirrored to defaults | app | — |
| `lastIsPlayingState` | NowPlayingManager | false | userContentController | isPlayingChanged computation | none | app | — |
| `isSystemSleeping` | NowPlayingManager | false | sleep/lock observers | evaluateJS/evaluateJSWithResult guards | none | app | Lock+Sleep notifications ordering (lock sets true; unlock/wake sets false) — potential flicker |
| `currentVideoId` | NowPlayingManager | "" | userContentController, flushSessionState | trackChanged logic | in-memory | app | Stale-track rejection relies on this; JS `cachedVideoId` also tracks it (dual sources) |
| `lastTrackChangeTime` | NowPlayingManager | 0 | userContentController | (only written) | none | app | Written, never read elsewhere in these files — effectively dead state |
| `isRestoringAfterTermination` | NowPlayingManager | false | handleWebContentTermination / markTerminationRecoveryComplete | message guard | none | app | Toggled on main queue via dispatch; message handler may fire on any thread — ordering risk |
| `lastDiscordPresenceKey` | NowPlayingManager | "" | notifyObservers | dedupe Discord updates | none | app | — |
| `panel` visibility/alpha/frame | StatusItemManager | hidden | showPanel/closePanel/position* | togglePanel, monitors | frame persisted (`YTM_playerFrame*`) | app | closePanel is async (animation completion) — rapid toggle can interleave |
| `isDraggedFromDock` | StatusItemManager | false | init, panelDidMove, onResetPosition, dockBackToMenuBar | positioning, monitors, display-change | UserDefaults `YTM_isDraggedFromDock` | app | panelDidMove sets it based on drag distance; debounce timer persists asynchronously — value vs persisted can diverge briefly |
| `isProgrammaticallyPositioning` | StatusItemManager | false | positionCustomWindow (set+defer reset) | panelDidMove guard | none | app | Bool flag; not thread-safe but always main (event-driven) |
| `dragDebounceTimer` | StatusItemManager | nil | panelDidMove (reschedule) | panelDidMove completion | none | app | `invalidate()`+recreate each move; completion reads `self.panel.frame` — if panel closed meanwhile, `panel` is non-nil (implicitly unwrapped) but `orderOut`; frame clamp still safe |
| Event monitors (global/local/key) | StatusItemManager | nil | startEventMonitors | closePanel/stopEventMonitors | none | per panel-show | startEventMonitors calls stopEventMonitors first; both touch monitors on main |
| `DisplayManager.onDisplayConfigurationChanged` | DisplayManager | nil | StatusItemManager.setupPanel | handleDisplayConfigurationChanged | none | app | Single-slot closure; overwritten if another owner assigns |

---

# EVENTS

## NotificationCenter notifications (default center)
| Name | Posted | Observed | Payload | Listeners (in these files) |
| :--- | :--- | :--- | :--- | :--- |
| `NSApplication.didChangeScreenParametersNotification` | AppKit | DisplayManager.setupObservers (selector `handleDisplayParametersChange`) | none | DisplayManager |
| `NSWindow.didMoveNotification` | AppKit (panel) | StatusItemManager.setupPanel (selector `panelDidMove`, object: panel) | window | StatusItemManager |
| `NSApplication.didResignActiveNotification` | AppKit | StatusItemManager.startEventMonitors (selector `appDidResignActive`) | none | StatusItemManager |
| `NSNotification.Name("Mooziac_EngineModeChanged")` | NowPlayingManager.playOfflineTrack (34), switchToOnlineMode (41), ObserverBridge (351) | **no listener found in repo** | none | — |

## NSWorkspace notifications (NSWorkspace.shared.notificationCenter)
| Name | Payload | Observed by |
| :--- | :--- | :--- |
| `NSWorkspace.willSleepNotification` | none | NowPlayingManager.setupSleepObservers → `isSystemSleeping = true` |
| `NSWorkspace.didWakeNotification` | none | NowPlayingManager.setupSleepObservers → `isSystemSleeping = false` |

## DistributedNotificationCenter notifications
| Name (exact string) | Payload | Observed by |
| :--- | :--- | :--- |
| `"com.apple.screenIsLocked"` | none | NowPlayingManager.setupSleepObservers → `isSystemSleeping = true` |
| `"com.apple.screenIsUnlocked"` | none | NowPlayingManager.setupSleepObservers → `isSystemSleeping = false` |

## Named notifications from other files (referenced but defined elsewhere)
| Name | Defined | Observed here |
| :--- | :--- | :--- |
| `NetworkMonitor.statusChangedNotification` = `"NetworkMonitorStatusChanged"` | Managers/NetworkMonitor.swift:8 | NowPlayingManager.setupNetworkObserver |

## WKScriptMessage handlers
| Handler name | Registered by | Messages |
| :--- | :--- | :--- |
| `"nowPlayingHandler"` | ObserverBridge.setupInWebView (`removeScriptMessageHandler` then `add(self, name:)`) | 15-field state dict (title, artist, album, artworkUrl, isPlaying, currentTime, duration, playbackRate, pageUrl, videoId, trackID, isLiked, isShuffle, isRepeat) + `{event:"videoEnded", videoId}` |

## Selector actions (target/action)
- Status button: `statusItemClicked(_:)` (left/right up; double-click show).
- Context menu items: `didSelectGestureMapping(_:)`, `showGestureTutorialFromMenu`, `selectDownloadLocationFromMenu`, `resetDownloadLocationFromMenu`, `clearListeningHistoryFromMenu`, `resetLoginFromMenu`, `reloadFromMenu`, `quitFromMenu`.
- Unused-but-declared selectors: `toggleFromMenu`, `toggleCenteredLyricsFromMenu`, `toggleMasterGestures`, `toggleAutoPauseOnDisconnect`, `toggleRightEdgeVolume`, `toggleRightCornerTaps`, `toggleLeftCornerTaps`.

## KVO
- None in these files.

## MPRemoteCommand
- None in these files. `MPNowPlayingInfoCenter` is written but no `MPRemoteCommandCenter` handlers are registered here (`INFERRED FROM SOURCE`: remote commands would be handled elsewhere or are absent — requires runtime verification).

## Delegate callbacks
- `DynamicIslandPlayerViewDelegate` → MainViewController: `dynamicIslandDidSearch`, `dynamicIslandDidTapPlayPause/Next/Previous/Shuffle/Repeat`, `dynamicIslandDidToggleExpanded`, `dynamicIslandDidSeek`, `dynamicIslandDidTapWebBrowser`, `dynamicIslandDidTapOfflineLibrary`, `dynamicIslandDidTapResetPosition`, `dynamicIslandDidTapPlaylistLibrary`.
- `OfflineLibraryViewDelegate` → MainViewController: `offlineLibraryDidSelectTrack(_:in:)`, `offlineLibraryDidRequestClose`, `offlineLibraryDidRequestImport`.
- `PlaylistLibraryViewDelegate` → MainViewController: `playlistLibraryDidRequestClose`, `playlistLibraryDidPlayOnline(videoId:)`.
- `HeaderViewDelegate` → MainViewController: `headerViewDidTapBack/Forward/Reload/Home/Account/PlayerOnly/Quit`.
- `MainViewController.onChangeSize` / `onResetPosition` closures → StatusItemManager.
- `DisplayManager.onDisplayConfigurationChanged` → StatusItemManager.
- `WKScriptMessageHandler` → NowPlayingManager (`userContentController(_:didReceive:)`).
- `NativeCapsuleToggleView.onToggle` closure → ContextMenu capsule items.
- `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)` → StatusItemManager key monitor.

## JS globals set by the app (bridge contract)
| JS global | Set by | Meaning |
| :--- | :--- | :--- |
| `window.ytmObserverInjected` | observerJS guard + flushSessionState reset | observer injection guard |
| `window.ytmRepeatMode` | setRepeatMode JS; read in video `ended` handler | repeat mode 0/1 |
| `window.ytmShuffleActive` | setShuffleState JS | shuffle flag |
| `window.clickYTMElement` | observerJS | global click helper |
| `window.ytmAudioContext`, `ytmSource`, `ytmLowFilter`, `ytmMidFilter`, `ytmHighFilter` | setEQPreset JS | WebAudio EQ chain |
| `video.ytmBound` | bindVideoEvents | per-video event-binding guard |

---

# USERDEFAULTS KEYS (exact strings) used by these files

| Key | Read (file:line) | Written (file:line) | Removed (file:line) |
| :--- | :--- | :--- | :--- |
| `"YTM_isEdgeEngineEnabled"` | — | — | AppDelegate:13 (legacy purge) |
| `"YTM_isCenteredLyricsEnabled"` | — | — | AppDelegate:13 |
| `"YTM_isRightEdgeVolumeEnabled"` | — | — | AppDelegate:14 |
| `"YTM_isRightCornerTapsEnabled"` | — | — | AppDelegate:14 |
| `"YTM_isLeftCornerTapsEnabled"` | — | — | AppDelegate:15 |
| `"YTM_hasInitializedDefaultSettingsV2"` | — | — | AppDelegate:15 |
| `"YTM_isDraggedFromDock"` | — | StatusItemManager:105,117,213; ContextMenu — | AppDelegate:16 (purge) |
| `"YTM_playerFrameX"` | StatusItemManager:138,251 | StatusItemManager:214 | AppDelegate:16 |
| `"YTM_playerFrameY"` | StatusItemManager:139,258 | StatusItemManager:215 | AppDelegate:16 |
| `"YTM_playerTopY"` | StatusItemManager:252 | StatusItemManager:216 | AppDelegate:16 |
| `"YTM_likedTrackKeysSet"` | NowPlayingManager:142,149 | NowPlayingManager:155 | NowPlayingManager:47 (on init) |
| `"YTM_lastIsLiked"` | — (read by DynamicIslandPlayerView:203) | ObserverBridge:414 | NowPlayingManager:48 (on init) |
| `"YTM_lastTitle"` | — (read by DynamicIslandPlayerView:192, PlaylistLibraryView, YTMWebView, HistoryManager, PlaylistManager) | ObserverBridge:411 | NowPlayingManager:181 (flush !keepCookies) |
| `"YTM_lastArtist"` | — (read by DynamicIslandPlayerView:195, HistoryManager:92, PlaylistManager:355) | ObserverBridge:412 | NowPlayingManager:182 (flush !keepCookies) |
| `"YTM_lastArtwork"` | — (read by DynamicIslandPlayerView:198, HistoryManager:94, PlaylistManager:357) | ObserverBridge:413 | — (not removed on flush) |
| `"YTM_lastVideoId"` | — (read by YTMWebView:172,466,564, PlaylistLibraryView, HistoryManager, PlaylistManager) | ObserverBridge:420 | NowPlayingManager:179 (flush !keepCookies) |
| `"YTM_lastUrl"` | — (read by YTMWebView:175,478,563) | ObserverBridge:421,424 | NowPlayingManager:178 (flush !keepCookies) |
| `"YTM_lastTime"` | ObserverBridge:436 | ObserverBridge:430,437; (also YTMWebView:193) | NowPlayingManager:180 (flush !keepCookies) |
| `"YTM_hasLoggedInOnce"` | — | StatusItemManager:471 (=false) | — |
| `"YTM_savedDisplayID"` | StatusItemManager:140,260 | StatusItemManager:218 | — |
| `"YTM_downloadsFolder"` | ContextMenu:179 | (LocalLibraryManager:61, via menu) | (LocalLibraryManager:66, via menu) |

Note: `YTM_lastArtwork` is written but never removed by `flushSessionState(keepCookies:false)` (line 177–183 list) — asymmetry (see RISKS).

---

# DATA FLOW (real flows traced in source)

## Flow 1: Status item click → panel shows (StatusItemManager)
1. `NSStatusItem.button` action → `statusItemClicked(_:)` (StatusItemManager:293).
2. If right mouse → `showContextMenu(_:)` (ContextMenu:55). If double-click → `showPanel`. Else → `togglePanel` (312).
3. `showPanel` (320): `positionPanel(width:height:)` → `positionCustomWindow(panel, width:height:)` (227) → places window under button (or saved dragged spot) → `makeKeyAndOrderFront` → `NSApp.activate(ignoringOtherApps:)` → fade-in → `startEventMonitors()` (375) which installs outside-click/global/keyboard monitors + resign-active observer.
4. Outside click → local monitor `closePanel()` (387) → fade-out → `orderOut` → `stopEventMonitors()`.

## Flow 2: Play/pause tap (DynamicIslandPlayer → JS/native)
1. `MainViewController.dynamicIslandDidTapPlayPause()` (396) → `NowPlayingManager.shared.togglePlayPause()` (PlayerControls:22).
2. If offline/offline-network → native branch: `NativeAudioPlayer.shared.playLastOrFirstTrack()`/`togglePlayPause()`.
3. Else → `NativeAudioPlayer.shared.pause()` then `evaluateJS(toggle JS)` (PlayerControls:46) → webview `#movie_player` play/pause.
4. Video event fires in JS (`play`/`pause`) → `bindVideoEvents` handler → `updateNowPlaying(true)` → `webkit.messageHandlers.nowPlayingHandler.postMessage(...)`.
5. `userContentController(didReceive:)` (ObserverBridge:320) rebuilds `PlaybackState`, sets `currentState`, persists `YTM_last*`, and calls `updateSystemNowPlayingInfo` (MPNowPlayingInfoCenter) + `notifyObservers` (NowPlayingManager:118).
6. Observers: `DynamicIslandPlayerView.updateState(state)` (via MainViewController.setupObservers:116), `CenteredMenuBarLyricsWindowController` (line 95); `notifyObservers` also updates Discord presence if key changed.

## Flow 3: Search (MainViewController.dynamicIslandDidSearch)
1. Query trimmed; if offline engine or network down → `findBestLocalTrack` (scoring) → `playOfflineTrack` → native playback + overlay + hide browser/library modes.
2. Else → `switchToOnlineMode` → `setBrowserVisible(false)`, `setOfflineLibraryVisible(false)` → load `https://music.youtube.com/search?q=<encoded>` in webview → overlay.
3. `autoPlayJS` evaluated at 0.4/0.8/1.3/1.8/2.5s; polls `findAndPlayTopTrack` every 250ms up to 30 attempts; clicks top result → track plays → JS observer posts state → native state updates.

## Flow 4: Next/Previous
1. `MainViewController.dynamicIslandDidTapNext()` (400) → `NowPlayingManager.nextTrack()` (PlayerControls:128).
2. If `PlaylistManager.hasActiveContext` → `playNextTrackInPlaylist()` and return.
3. If offline/no-network → native next.
4. Else JS: priority next-button click → next queue item click → `player.nextVideo()`. (previousTrack mirrors.)

## Flow 5: videoEnded → repeat-one or playlist advance (ObserverBridge:328)
1. JS `ended` event: if `window.ytmRepeatMode === 1` → seekTo(0)+play (JS-side only). Else post `{event:'videoEnded', videoId}`.
2. Native: if `repeatMode == .one` → `seek(to:0.0)`+`play()`; else if `PlaylistManager.hasActiveContext` → `playNextTrackInPlaylist()`.

## Flow 6: Scroll on status icon → volume (StatusItemManager:71)
- Local scrollWheel monitor: if `|deltaY|>0.1` → `NowPlayingManager.adjustVolume(deltaPercent: ±4)` (PlayerControls:577) → JS `video.volume` clamp; event consumed.

## Flow 7: Panel drag → floating player + persistence (StatusItemManager.panelDidMove:159)
1. `NSWindow.didMoveNotification` (panel) → `panelDidMove`.
2. Guards pass (player mode, ≤360×120, mouse pressed).
3. Compute desired position; `isDragged` if >25pt from docked anchor → flip `isDraggedFromDock`, show reset button, `panel.level = .floating`.
4. Debounce 0.12s → clamp frame, persist `YTM_isDraggedFromDock/YTM_playerFrameX/Y/YTM_playerTopY/YTM_savedDisplayID`.
5. Reset via `dockBackToMenuBar` (304) or `onResetPosition` (114) restores docked position and level.

## Flow 8: Display change → reposition (DisplayManager + StatusItemManager:133)
1. AppKit posts `didChangeScreenParametersNotification`.
2. `DisplayManager.handleDisplayParametersChange` → main queue → `onDisplayConfigurationChanged`.
3. StatusItemManager.handleDisplayConfigurationChanged: dragged → reload saved frame + clamp on target screen; docked → `positionPanel`. Also repositions lyrics overlay.

## Flow 9: Like toggle (PlayerControls.toggleLike:464)
- Offline: native toggleLike + `mirrorOfflineLike`. Online: record toggle in LikedSongsManager; if signed in → JS click YTM like button (+250ms `updateNowPlaying(true)`); else optimistic local `currentState.isLiked` flip + direct observer fan-out.

## Flow 10: Keyboard command (StatusItemManager key monitor:391)
- keyDown while panel visible, not in text field/WebKit → `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)`; if handled consume event; overlay shown via CenteredMenuBarLyricsWindowController.

---

# STARTUP & SHUTDOWN FLOWS (as implemented)

## Startup (AppDelegate.applicationDidFinishLaunching, lines 6–43)
1. `NSApp.setActivationPolicy(.accessory)`.
2. `setupMainMenu()` — Edit menu (undo/redo/cut/copy/paste/select-all).
3. Purge legacy keys (10 keys, lines 12–20).
4. `BackgroundMediaController.shared.startPreventingSleep()` — IOKit assertion + process activity.
5. `EdgeVolumeEngine.shared.start()`.
6. `AudioRouteMonitor.shared.startMonitoring()`.
7. `NetworkMonitor.shared.startMonitoring()`.
8. `DiscordRPCManager.shared.startReconnectLoop()` + `tryConnect()`.
9. `statusItemManager = StatusItemManager()` — creates status item (icon restore, button action, scroll monitor) + panel (docked, `YTM_isDraggedFromDock=false`) + `MainViewController` (which runs `viewDidLoad` → starts `GlobalHotKeyManager`).
10. `LaunchAnimationController.shared.play()` — pop animation on the status button.

Note: `NowPlayingManager.shared` is first touched (lazily) during viewDidLoad observers; its `init` clears `YTM_likedTrackKeysSet`/`YTM_lastIsLiked` and installs sleep/network observers. `YTMWebView` will call `attach(to:)` later when its webview is created (Web/YTMWebView.swift:170).

## Shutdown (applicationWillTerminate, lines 67–69)
- `BackgroundMediaController.shared.stopPreventingSleep()` — release assertion, end activity, nil audio engine nodes.
- (No explicit cleanup of monitors/observers here; `StatusItemManager` has `deinit` → `stopEventMonitors`.)

---

# SQLite / JS-bridge / MPNowPlayingInfoCenter interactions

- **SQLite**: none in these 12 files. (`HistoryManager` is the likely persistence owner — not part of this work package; `UNKNOWN — requires runtime verification.`)
- **JS bridge**: two directions — (a) injected `WKUserScript` (`observerJS`, atDocumentEnd, main frame only) drives state messages via `nowPlayingHandler`; (b) native→JS via `evaluateJS`/`evaluateJSWithResult` (commands, EQ, volume, queue ops, like clicks, ad bypass). `removeScriptMessageHandler(forName:)+add` on re-injection handles WebContent restart. Injection is re-gated by `window.ytmObserverInjected`.
- **MPNowPlayingInfoCenter**: `updateSystemNowPlayingInfo` writes title/artist/album/elapsed/duration/rate on track change or play-state change. No `MPMediaItemPropertyArtwork`, no `MPRemoteCommandCenter`, no `MPNowPlayingInfoCenter` reads in these files.

---

# RISKS & OBSERVATIONS

1. **Dead notification**: `"Mooziac_EngineModeChanged"` is posted in three places (NowPlayingManager.swift:34,41; ObserverBridge.swift:351) but has **no registered observer anywhere in the repo** — the engine-mode broadcast is inert. Either listeners were removed or this is vestigial.
2. **Dead code — BackgroundMediaController audio engine**: `audioEngine`/`audioPlayerNode` are declared (lines 11–12) and touched only by `stopPreventingSleep` (49–52) but never assigned. The AVAudioEngine scaffold is inert.
3. **Dead code — context-menu toggles**: `toggleMasterGestures`, `toggleAutoPauseOnDisconnect`, `toggleRightEdgeVolume`, `toggleRightCornerTaps`, `toggleLeftCornerTaps` (ContextMenu.swift:233–251) are never referenced by any menu item (they were replaced by capsule-toggle closures). Same for `StatusItemManager.toggleFromMenu` (455) and `toggleCenteredLyricsFromMenu` (461).
4. **Unused state**: `NowPlayingManager.lastTrackChangeTime` (109) is written but never read in these files.
5. **`init()` side effect surprise**: `BackgroundMediaController.init()` already calls `startPreventingSleep()`; the AppDelegate's explicit call is redundant but guarded (assertionID != 0) so harmless.
6. **Engine-mode notification reliance**: offline↔online transitions happen without any in-repo listener being notified; consumers (e.g. player UI) may not know the engine switched unless they read `engineMode` directly.
7. **`observerJS` injection guard + flush race**: `flushSessionState` resets `window.ytmObserverInjected=false` and the observer will re-inject on next navigation; meanwhile `isRestoringAfterTermination` gating in the message handler can drop legit early messages during recovery.
8. **Offline mutual-exclusion return**: while offline, all `nowPlayingHandler` messages that are not a "starting playback" are dropped (ObserverBridge:346–356) — includes pause/idle state; after the forced switch to online, the next message resumes normal handling. Edge: an offline track's own state never reaches observers (intended, but the `PlaybackState` continues to describe the last online song).
9. **`setRepeatMode` drift**: `window.ytmRepeatMode` is JS-side; if the user changes repeat inside YTM directly, Swift `repeatMode` and JS state desync; `videoEnded` repeat-one logic could misbehave (double seek or none).
10. **EQ is per-page ephemeral**: `setEQPreset` builds a WebAudio graph tied to the current `<video>`/document; navigating YTM pages tears it down (graph lost, `ytmAudioContext` persists pointing at a dead source) — EQ stops working after navigation until preset is re-applied, and re-application may double-connect. Potential WebKit audio-path contention when `NativeAudioPlayer` also plays.
11. **`findBestLocalTrack` scores on lowercased but un-normalized strings** — non-ASCII/punctuation differences can zero out matches; acceptable heuristic, but exact-match path only triggers on case-insensitive equality.
12. **`autoPlayJS` is injected 5 times at fixed delays even if the first click succeeded** — redundant evaluations; harmless because `clickedTrack` is per-injection closure (each injection has its own `clickedTrack`), so multiple injections could each click a result; risk of double-clicks/radio starts. `attempts>30` cap ~7.5s.
13. **`statusItem.menu` trick in `showContextMenu`**: setting `statusItem.menu = menu` then `performClick(nil)` then `statusItem.menu = nil` is the standard "pop menu under the status item" hack; `keyEquivalent` on such items is unreliable (`INFERRED FROM SOURCE`).
14. **Implicitly-unwrapped optionals**: `statusItem: NSStatusItem!`, `panel: StatusItemPanel!` — dereferenced in several places (e.g. `handleDisplayConfigurationChanged`, `panelDidMove`) with only partial guards; if a future code path deallocates panel before these run → crash.
15. **`findScreen` force-unwrap** (DisplayManager.swift:40,52): `NSScreen.screens.first!` and `NSScreen.main` path crash if no screens — unlikely in practice.
16. **Observer retention**: `NowPlayingManager.observers` are never removed; closures capturing view controllers may retain them for app lifetime (MainViewController's uses `[weak self]`; CenteredMenuBarLyricsWindowController at line 95 — capture list `INFERRED FROM SOURCE`, needs verification).
17. **`panelDidMove` guard depends on `isBrowserMode`/`isOfflineLibraryMode` but not `isPlaylistLibraryMode`** — dragging while playlist library is open (size 380×420 > 360×120 guard anyway blocks) — the size guard covers it, but the flag asymmetry is a latent inconsistency.
18. **Double handling in reset**: `MainViewController.dynamicIslandDidTapResetPosition` calls both `StatusItemManager.shared?.dockBackToMenuBar()` and `onResetPosition?()` (StatusItemManager.swift:114) — both perform essentially the same reset (docked flag, level, reposition, hide reset button). Redundant but idempotent.
19. **`toggleLike` optimistic path mutates `currentState`** then fans observers manually — bypasses `notifyObservers`, so Discord presence is not updated for the optimistic like flip (minor inconsistency).
20. **`flushSessionState(keepCookies:false)` removes `YTM_lastUrl/VideoId/Time/Title/Artist` but not `YTM_lastArtwork`** — asymmetric cleanup; stale artwork persists.
21. **Init-time defaults removal**: `NowPlayingManager.init` deletes `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` on **every launch** — any liked-track persistence is wiped each launch (likes will appear unliked until re-set via JS). This looks intentional (reset to JS truth) but is a data-loss footgun.
22. **Throttled time persistence**: `YTM_lastTime` only written when delta ≥ 5s (ObserverBridge:436–438) — on quit, resume position could be up to ~5s stale. Resume logic lives in YTMWebView (outside this set).
23. **`isProgrammaticallyPositioning` is a plain Bool flag** toggled synchronously around `setFrame`; any asynchronous frame-setting (e.g. animated `setFrame` during display change with `animate: true`) may fire `didMove` while flag is already reset — a 0.12s debounce mitigates but doesn't eliminate spurious drag detection.
24. **`showPanel` calls `NSApp.activate(ignoringOtherApps: true)`** — aggressive focus steal every time the panel opens; combined with `.nonactivatingPanel` there may be focus quirks (`UNKNOWN — requires runtime verification`).
25. **`statusButtonCenterInScreen` returns `buttonWindow.frame` mid-point directly when window valid** (StatusItemManager:19–23) — uses window frame, not button bounds; with zero-size status windows falls to bounds path. Launch animation anchors on this.
26. **Scroll-wheel monitor is installed once** (setupStatusItem) and never removed until app quit — fine, but it is a local monitor with a strong reference held forever (intended).
27. **JS selectors are brittle by design** — dozens of DOM selector strings across ObserverBridge/PlayerControls/Queue target YTM's Polymer internals; any YTM DOM/class change silently breaks autoplay, queue ops, ad bypass, like/eq detection (all wrapped in try/catch so failures are invisible).
28. **Duplicate logic**: `findAndPlayTopTrack`/`simulateClick` patterns are re-implemented in observerJS, PlayerControls (next/previous), and Queue (playQueueItem/playAutomixItem/moveQueueItem) — maintenance duplication; a shared injected helper (`window.clickYTMElement`) exists but is only used by... actually it is defined (ObserverBridge:164) and never called elsewhere in these files (`INFERRED FROM SOURCE`) — dead JS helper.
29. **`playNextQueueItem(from:)` ignores `fromIndex` semantically** — computes target from current selected index, using `fromIndex` only for bounds checks; callers passing a different intended origin get surprising behavior.
30. **`spotifyPlayerDidTapLogin`** (MainViewController:525) — misnamed legacy method (Spotify naming, Google/YTM login); only dead unless a delegate declares it.

---

# SUMMARY

- Files documented: 12
- Classes documented: 8 classes (`AppDelegate`, `BackgroundMediaController`, `PassthroughBrowserContainerView`, `MainViewController`, `DisplayManager`, `NowPlayingManager`, `StatusItemManager`, `StatusItemPanel`) + 3 DTO structs (`QueueItemInfo`, `AutomixItemInfo`, `UpNextSnapshot`)
- Functions documented: 141 (including inits, deinits, computed properties, JS-injected functions, and top-level entry)
- UserDefaults keys found: 21 distinct (see USERDEFAULTS section)
- Notification names found: 7 NotificationCenter/Distributed names + 1 in-repo named notification (`NetworkMonitorStatusChanged`) + 1 WKScriptMessage handler (`nowPlayingHandler`)
- Notable risks: dead notification `Mooziac_EngineModeChanged` (no listeners), dead BackgroundMediaController audio engine, 7 dead selectors/methods, per-launch deletion of `YTM_likedTrackKeysSet`, asymmetric cookie-flush leaving `YTM_lastArtwork`, JS/DOM-selector fragility, optimistic like without Discord update, `findScreen` force-unwraps, observer retention, EQ per-page ephemerality, redundant double-reset in reset-position path.