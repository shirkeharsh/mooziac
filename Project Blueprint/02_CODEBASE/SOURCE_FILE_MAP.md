# Source File Map

Subsystem → file → primary types → where to read more. Types were extracted directly from the source (authoritative grep).

## App — lifecycle & entry

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `App/main.swift` | (top-level code) | 01_CORE_LAYER, 13_WORKFLOWS/APP_STARTUP |
| `App/AppDelegate.swift` | `class AppDelegate: NSObject, NSApplicationDelegate` | 01_CORE_LAYER |
| `App/BackgroundMediaController.swift` | `final class BackgroundMediaController` | 01_CORE_LAYER |

## Audio — playback engines & CoreAudio

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Audio/NativeAudioPlayer.swift` | `public final class NativeAudioPlayer: NSObject` | 02_AUDIO_WEB_INPUT, 06_AUDIO/* |
| `Audio/EdgeVolumeEngine.swift` | `final class VolumeController`, `final class EdgeVolumeEngine`, `private final class ActiveEngineBox` | 02_AUDIO_WEB_INPUT |
| `Audio/AppVolumeManager.swift` | `public final class AppVolumeManager` | 02_AUDIO_WEB_INPUT |
| `Audio/AudioRouteMonitor.swift` | `final class AudioRouteMonitor` | 02_AUDIO_WEB_INPUT |
| `Audio/ClickSound.swift` | `public final class ClickSound` | 02_AUDIO_WEB_INPUT |

## Core — controllers & central state

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Core/MainViewController.swift` | `final class PassthroughBrowserContainerView`, `class MainViewController: NSViewController` + 4 delegate protocols | 01_CORE_LAYER |
| `Core/DisplayManager.swift` | `public final class DisplayManager: NSObject` | 01_CORE_LAYER |
| `Core/NowPlayingManager/NowPlayingManager.swift` | `class NowPlayingManager: NSObject, WKScriptMessageHandler` | 01_CORE_LAYER |
| `Core/NowPlayingManager/ObserverBridge.swift` | (extension methods on NowPlayingManager; injected JS) | 01_CORE_LAYER |
| `Core/NowPlayingManager/PlayerControls.swift` | (extension: playback command dispatch) | 01_CORE_LAYER |
| `Core/NowPlayingManager/Queue.swift` | (extension: queue logic; DTOs `QueueItemInfo`, `AutomixItemInfo`, `UpNextSnapshot`) | 01_CORE_LAYER |
| `Core/StatusItemManager/StatusItemManager.swift` | `class StatusItemManager: NSObject` | 01_CORE_LAYER |
| `Core/StatusItemManager/StatusItemPanel.swift` | `final class StatusItemPanel: NSPanel` | 01_CORE_LAYER |
| `Core/StatusItemManager/ContextMenu.swift` | (extension: builds context menu) | 01_CORE_LAYER |

## Input — gestures & hotkeys

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Input/GestureMappingManager.swift` | `public final class GestureMappingManager` | 02_AUDIO_WEB_INPUT |
| `Input/GlobalHotKeyManager.swift` | `public final class GlobalHotKeyManager` | 02_AUDIO_WEB_INPUT |
| `Input/KeyboardCommandHandler.swift` | `enum KeyboardCommandHandler` | 02_AUDIO_WEB_INPUT |

## Managers — services & persistence

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Managers/LocalDatabaseManager.swift` | `CachedTrackRecord`, `PlaylistRecord`, `PlaylistItemRecord`, `HistoryRecord`, `public final class LocalDatabaseManager` | 03_DATA_MANAGERS |
| `Managers/LocalLibraryManager.swift` | `public final class LocalLibraryManager: NSObject` | 03_DATA_MANAGERS |
| `Managers/PlaylistManager.swift` | `PlaylistLibraryIndex`, `public final class PlaylistManager: NSObject` | 03_DATA_MANAGERS |
| `Managers/DownloadManager.swift` | `DownloadStatus`, `DownloadProgressInfo`, `public final class DownloadManager: NSObject` | 03_DATA_MANAGERS |
| `Managers/LyricsManager.swift` | `public final class LyricsManager` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/SyncedLyricsParser.swift` | `LRCWord`, `LRCLine`, `public final class SyncedLyricsParser` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/HistoryManager.swift` | `public final class HistoryManager` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/LikedSongsManager.swift` | `public class LikedSongsManager` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/DiscordRPCManager.swift` | `enum RPCOpcode: UInt32`, `final class DiscordRPCManager` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/TrackNotificationManager.swift` | `public class TrackNotificationManager: NSObject, UNUserNotificationCenterDelegate` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/NetworkMonitor.swift` | `public final class NetworkMonitor` | 04_LYRICS_MANAGERS_MODELS |
| `Managers/AppArtworkHelper.swift` | `public final class AppArtworkHelper` | 04_LYRICS_MANAGERS_MODELS |

## Models — pure data

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Models/LocalTrack.swift` | `public struct LocalTrack: Identifiable, Equatable` | 04 |
| `Models/PlaybackState.swift` | `struct PlaybackState` | 04 |
| `Models/PlaybackEngineMode.swift` | `public enum PlaybackEngineMode: String, Codable` | 04 |
| `Models/RepeatMode.swift` | `public enum RepeatMode: Int, Codable` | 04 |
| `Models/PlayerDesign.swift` | `public enum PlayerDesign: String, CaseIterable` | 04 |
| `Models/ProgressStyle.swift` | `public enum ProgressStyle: String, CaseIterable, Codable` | 04 |
| `Models/GestureMappingModels.swift` | `public enum GestureType`, `public enum GestureAction` | 04 |
| `Models/LikedSongRecord.swift` | `public struct LikedSongRecord` | 04 |
| `Models/LaunchAnimationTimeline.swift` | `struct LaunchAnimationTimeline: Equatable` | 04 |

## Support — extensions

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Support/AppExtensions.swift` | extension `NSImage` → `floppyDiskIcon` (only) | 02 |

## Views

### Player & windows
| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Views/Player/DynamicIslandPlayerView/Core.swift` | `protocol DynamicIslandPlayerViewDelegate`, `class DynamicIslandPlayerView: NSView`, `final class PillContainerView` | 05_PLAYER_WINDOWS_UI |
| `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift` | extension; private helpers `SettingsFlippedDocView`, `SettingsFlippedClipView`, `DownloadRowView`, `LibraryNavButton`, `DetailItemRowView`, `VerticalPanGestureRecognizer`, `HistoryRowView`, `LikedSongRowView` | 05_PLAYER_WINDOWS_UI |
| `Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift` | (extension: artwork loading + color extraction) | 05_PLAYER_WINDOWS_UI |
| `Views/Windows/CenteredMenuBarLyricsWindowController.swift` | `public class CenteredMenuBarLyricsWindowController: NSWindowController` | 05_PLAYER_WINDOWS_UI |
| `Views/Windows/LaunchAnimationController.swift` | `final class LaunchAnimationController` | 05_PLAYER_WINDOWS_UI |
| `Views/Windows/LaunchOverlayView.swift` | `final class LaunchOverlayModel: ObservableObject`, `struct LaunchOverlayView: View` | 05_PLAYER_WINDOWS_UI |
| `Views/Windows/NativeGestureTutorialWindowController.swift` | `final class NativeGestureTutorialWindowController: NSWindowController` | 05_PLAYER_WINDOWS_UI |

### Libraries
| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Views/Libraries/PlaylistLibraryView.swift` | `protocol PlaylistLibraryViewDelegate`, `public class PlaylistLibraryView: NSView` + nested `Tab`/`Mode`, `PlaylistTableView`, 5 private cell classes | 06 |
| `Views/Libraries/OfflineLibraryView.swift` | `protocol OfflineLibraryViewDelegate`, `public class OfflineLibraryView: NSView` + `OfflineTrackCellView`, `OfflineTableView` | 06 |
| `Views/Libraries/OfflineOverlayView.swift` | `public final class OfflineOverlayView: NSView` | 06 |
| `Views/Libraries/SwipeToDeleteContainerView.swift` | `public final class SwipeActionCoordinator`, `public class SwipeContentCardView`, `public class SwipeToDeleteContainerView` | 06 |

### Components
| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Views/Components/CircularProgressDownloadButton.swift` | `final class CircularProgressDownloadButton: ReactiveIconButton` | 06 |
| `Views/Components/GlassSearchField.swift` | `final class GlassSearchFieldCell: NSSearchFieldCell`, `public class GlassSearchField: NSSearchField` | 06 |
| `Views/Components/HeaderView.swift` | `protocol HeaderViewDelegate`, `class HeaderView: NSView` | 06 |
| `Views/Components/LiquidGlassSegmentedSlider.swift` | `enum SettingsTone`, `final class LiquidSegmentedControl: NSView`, `PassThroughView` | 06 |
| `Views/Components/NativeCapsuleToggleView.swift` | `final class NativeCapsuleToggleView: NSControl` | 06 |
| `Views/Components/ReactiveIconButton.swift` | `class ReactiveIconButton: NSButton` | 06 |
| `Views/Components/WaveformProgressView.swift` | `class InteractiveWaveformProgressView: NSView` | 06 |

## Web — WebKit integration

| File | Primary types | Docs |
| :--- | :--- | :--- |
| `Web/YTMWebView.swift` | `class YTMWebViewContainer: NSView, WKNavigationDelegate, WKUIDelegate` | 02 |
| `Web/URLFilter.swift` | `struct URLFilter` | 02 |

## Type count summary (authoritative grep)

- **95 top-level type declarations** (classes, structs, enums, protocols) across the 60 source files.
- **673 function/method declarations.**