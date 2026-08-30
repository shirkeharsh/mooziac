# Windows

All windows and panels in Mooziac.

## 1. StatusItemPanel (main player window)

| Attribute | Value |
| :--- | :--- |
| Type | `NSPanel` subclass (`StatusItemPanel.swift`, 29 lines) |
| Created by | `StatusItemManager.setupPanel` |
| Content | `MainViewController` (player pill → browser → libraries) |
| Level | `.floating` when dragged out, `.normal` when docked |
| Style | transparent, glass/liquid look, rounded corners |
| Positioning | under the status button, or at the saved dragged frame (`YTM_playerFrameX/Y`, `YTM_playerTopY`, `YTM_savedDisplayID`) |
| Persistence | docked/undocked state via `YTM_isDraggedFromDock` |
| Drag | `NSWindow.didMoveNotification` → `panelDidMove` → float transition (debounced 0.12 s) |

## 2. CenteredMenuBarLyricsWindowController (HUD overlay)

| Attribute | Value |
| :--- | :--- |
| Type | `NSWindowController` (282 lines) |
| Purpose | Menu-bar-centered HUD: real-time synced lyrics + status toasts (`Volume: 65%`, `Next Track`, `Paused`, `Playing`) |
| Position | Top-center of the screen (`repositionInCenter`), notch-aware |
| Visibility | Always-visible floating overlay window; enabled via `YTM_v3_isCenteredLyricsEnabled` |
| Update loop | 0.1 s timer → `SyncedLyricsParser.activeLineAndWord(leadOffset: 0.35)` → fade-swap label |
| Overlays | `showVolumeOverlay`, `showCustomTextOverlay` (auto-dismiss ~1.5 s) |
| Theme | Capsule styling; repositions on display change |

## 3. LaunchAnimationController + LaunchOverlayView (startup)

| Attribute | Value |
| :--- | :--- |
| Controller | `LaunchAnimationController` (173 lines, singleton `shared`, `play()` on launch) |
| Overlay | SwiftUI `LaunchOverlayView` (`LaunchOverlayModel: ObservableObject`) |
| Sequence | full-screen transparent panel → fade/breath → fly/shrink into the status icon → sparkle burst → dismiss |
| Anchors | `StatusItemManager.statusButtonCenterInScreen` + `computeStatusItemTarget` |
| Timing | model `LaunchAnimationTimeline` exists but controller uses hardcoded timings (dead-model risk) |
| Sound | `ClickSound.play` (system sound 1104 at 0.52 s) — no haptic, no toggle |

## 4. NativeGestureTutorialWindowController (tutorial)

| Attribute | Value |
| :--- | :--- |
| Type | `NSWindowController` (85 lines) |
| Content | `WKWebView` loading bundled `trackpad.html` (which loads `macbook_panel.jpg`) |
| Purpose | Interactive trackpad gesture tutorial (right-edge volume, corner taps) |
| Positioning | anchored at the player position under the status bar |
| Open/close | `showTutorial` / `closeTutorial` (✕); opened from context menu "Gesture Tutorial" |

## Window-level summary

| Window | Level | Non-activating | Transparent |
| :--- | :--- | :--- | :--- |
| StatusItemPanel (docked) | `.normal` | panel-style | yes |
| StatusItemPanel (floating) | `.floating` | panel-style | yes |
| Lyrics HUD | floating | yes | yes |
| Launch overlay | high | yes | yes |
| Tutorial | normal | — | content is pitch-black |

## Positioning logic (shared)

`DisplayManager` provides `displayID(for:)`, `findScreen(forSavedID:fallbackOrigin:)`, `clampFrameToVisibleBounds`, `hasNotch`, `safeTopBoundary` — used by StatusItemManager, launch animation, and lyrics HUD.