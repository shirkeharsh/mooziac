# Class Reference

Every top-level type (class/struct/enum/protocol) in the module, extracted directly from source. Line numbers are file-relative. For each type's full documentation (responsibilities, properties, public/private API, dependencies, consumers, lifecycle, what breaks if removed) see the CLASS ENTRY sections in the raw discovery notes:

- `99_APPENDIX/RAW_DISCOVERY_NOTES/01_CORE_LAYER.md` (App + Core)
- `99_APPENDIX/RAW_DISCOVERY_NOTES/02_AUDIO_WEB_INPUT.md`
- `99_APPENDIX/RAW_DISCOVERY_NOTES/03_DATA_MANAGERS.md`
- `99_APPENDIX/RAW_DISCOVERY_NOTES/04_LYRICS_MANAGERS_MODELS.md`
- `99_APPENDIX/RAW_DISCOVERY_NOTES/05_PLAYER_WINDOWS_UI.md`
- `99_APPENDIX/RAW_DISCOVERY_NOTES/06_LIBRARIES_COMPONENTS_UI.md`

Total: 95 top-level types.

---

## Core/DisplayManager.swift

- `public final class DisplayManager` (line 4)
## Core/MainViewController.swift

- `final class PassthroughBrowserContainerView` (line 4)
- `class MainViewController` (line 13)
## Core/NowPlayingManager/NowPlayingManager.swift

- `class NowPlayingManager` (line 5)
## Core/StatusItemManager/StatusItemManager.swift

- `class StatusItemManager` (line 4)
## Core/StatusItemManager/StatusItemPanel.swift

- `final class StatusItemPanel` (line 3)
## App/BackgroundMediaController.swift

- `final class BackgroundMediaController {` (line 6)
## App/AppDelegate.swift

- `class AppDelegate` (line 3)
## Input/GestureMappingManager.swift

- `public final class GestureMappingManager {` (line 4)
## Input/KeyboardCommandHandler.swift

- `enum KeyboardCommandHandler {` (line 6)
## Input/GlobalHotKeyManager.swift

- `public final class GlobalHotKeyManager {` (line 4)
## Web/URLFilter.swift

- `struct URLFilter {` (line 3)
## Web/YTMWebView.swift

- `class YTMWebViewContainer` (line 5)
## Managers/SyncedLyricsParser.swift

- `public struct LRCWord {` (line 3)
- `public struct LRCLine {` (line 10)
- `public final class SyncedLyricsParser {` (line 51)
## Managers/LikedSongsManager.swift

- `public class LikedSongsManager {` (line 4)
## Managers/LocalDatabaseManager.swift

- `public struct CachedTrackRecord {` (line 5)
- `public struct PlaylistRecord {` (line 67)
- `public struct PlaylistItemRecord {` (line 83)
- `public struct HistoryRecord` (line 126)
- `public final class LocalDatabaseManager {` (line 183)
## Managers/PlaylistManager.swift

- `public struct PlaylistLibraryIndex {` (line 4)
- `public final class PlaylistManager` (line 26)
## Managers/LocalLibraryManager.swift

- `public final class LocalLibraryManager` (line 5)
## Managers/LyricsManager.swift

- `public final class LyricsManager {` (line 4)
## Managers/DownloadManager.swift

- `public enum DownloadStatus` (line 6)
- `public struct DownloadProgressInfo {` (line 13)
- `public final class DownloadManager` (line 24)
## Managers/AppArtworkHelper.swift

- `public final class AppArtworkHelper {` (line 7)
## Managers/DiscordRPCManager.swift

- `enum RPCOpcode` (line 4)
- `final class DiscordRPCManager {` (line 12)
## Managers/TrackNotificationManager.swift

- `public class TrackNotificationManager` (line 4)
## Managers/HistoryManager.swift

- `public final class HistoryManager {` (line 4)
## Managers/NetworkMonitor.swift

- `public final class NetworkMonitor {` (line 5)
## Models/LocalTrack.swift

- `public struct LocalTrack` (line 5)
## Models/PlaybackEngineMode.swift

- `public enum PlaybackEngineMode` (line 3)
## Models/ProgressStyle.swift

- `public enum ProgressStyle` (line 3)
## Models/GestureMappingModels.swift

- `public enum GestureType` (line 4)
- `public enum GestureAction` (line 30)
## Models/RepeatMode.swift

- `public enum RepeatMode` (line 3)
## Models/LaunchAnimationTimeline.swift

- `struct LaunchAnimationTimeline` (line 4)
## Models/LikedSongRecord.swift

- `public struct LikedSongRecord {` (line 3)
## Models/PlayerDesign.swift

- `public enum PlayerDesign` (line 3)
## Models/PlaybackState.swift

- `struct PlaybackState {` (line 4)
## Audio/ClickSound.swift

- `public final class ClickSound {` (line 5)
## Audio/AudioRouteMonitor.swift

- `final class AudioRouteMonitor {` (line 4)
## Audio/NativeAudioPlayer.swift

- `public final class NativeAudioPlayer` (line 6)
## Audio/AppVolumeManager.swift

- `public final class AppVolumeManager {` (line 5)
## Audio/EdgeVolumeEngine.swift

- `final class VolumeController {` (line 6)
- `final class EdgeVolumeEngine {` (line 156)
- `private final class ActiveEngineBox {` (line 498)
## Views/Libraries/OfflineOverlayView.swift

- `public final class OfflineOverlayView` (line 3)
## Views/Libraries/PlaylistLibraryView.swift

- `protocol PlaylistLibraryViewDelegate` (line 5)
- `public class PlaylistLibraryView` (line 10)
- `public class PlaylistTableView` (line 2285)
- `private class PlaylistRowCellView` (line 2303)
- `private class PlaylistItemRowCellView` (line 2463)
- `private class DownloadRowCellView` (line 2738)
- `private class HistoryRowCellView` (line 2938)
- `private class LikedSongRowCellView` (line 3180)
## Views/Libraries/SwipeToDeleteContainerView.swift

- `public final class SwipeActionCoordinator {` (line 7)
- `public class SwipeContentCardView` (line 53)
- `public class SwipeToDeleteContainerView` (line 176)
## Views/Libraries/OfflineLibraryView.swift

- `protocol OfflineLibraryViewDelegate` (line 4)
- `public class OfflineLibraryView` (line 10)
- `private class OfflineTrackCellView` (line 569)
- `public class OfflineTableView` (line 788)
## Views/Components/ReactiveIconButton.swift

- `class ReactiveIconButton` (line 4)
## Views/Components/WaveformProgressView.swift

- `class InteractiveWaveformProgressView` (line 5)
## Views/Components/HeaderView.swift

- `protocol HeaderViewDelegate` (line 3)
- `class HeaderView` (line 13)
## Views/Components/LiquidGlassSegmentedSlider.swift

- `enum SettingsTone {` (line 4)
- `final class LiquidSegmentedControl` (line 64)
- `private final class PassThroughView` (line 304)
## Views/Components/NativeCapsuleToggleView.swift

- `final class NativeCapsuleToggleView` (line 4)
## Views/Components/GlassSearchField.swift

- `final class GlassSearchFieldCell` (line 3)
- `public class GlassSearchField` (line 54)
## Views/Components/CircularProgressDownloadButton.swift

- `final class CircularProgressDownloadButton` (line 4)
## Views/Windows/LaunchAnimationController.swift

- `final class LaunchAnimationController {` (line 5)
## Views/Windows/NativeGestureTutorialWindowController.swift

- `final class NativeGestureTutorialWindowController` (line 4)
## Views/Windows/CenteredMenuBarLyricsWindowController.swift

- `public class CenteredMenuBarLyricsWindowController` (line 4)
## Views/Windows/LaunchOverlayView.swift

- `final class LaunchOverlayModel` (line 4)
- `struct LaunchOverlayView` (line 19)
## Views/Player/DynamicIslandPlayerView/SettingsPanel.swift

- `private class SettingsFlippedDocView` (line 2769)
- `private class SettingsFlippedClipView` (line 2773)
- `private class DownloadRowView` (line 2778)
- `class LibraryNavButton` (line 2881)
- `private class DetailItemRowView` (line 3022)
- `private class VerticalPanGestureRecognizer` (line 3254)
- `private class HistoryRowView` (line 3292)
- `private class LikedSongRowView` (line 3460)
## Views/Player/DynamicIslandPlayerView/Core.swift

- `protocol DynamicIslandPlayerViewDelegate` (line 5)
- `class DynamicIslandPlayerView` (line 20)
- `final class PillContainerView` (line 1167)
