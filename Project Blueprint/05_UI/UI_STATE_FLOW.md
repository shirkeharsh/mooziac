# UI State Flow

How UI state is produced, pushed, and consumed. The core invariant: **UI is a mirror of `NowPlayingManager.shared.currentState` (`PlaybackState`)**, refreshed by observers and notifications.

## State propagation model

```
Source of truth: NowPlayingManager.currentState (PlaybackState)
      │
      ├─ notifyObservers() → [MainViewController → DynamicIslandPlayerView.updateState(state),
      │                       CenteredMenuBarLyricsWindowController, Discord presence]
      ├─ updateSystemNowPlayingInfo() → MPNowPlayingInfoCenter
      └─ persisted via UserDefaults (YTM_last*) for session restore
```

### Trigger points for state push

| Trigger | Producer |
| :--- | :--- |
| JS `nowPlayingHandler` message (online: play/pause/seek/track-change/like) | `ObserverBridge.userContentController` |
| Offline periodic time broadcast (0.25 s) + play/pause/next/prev/seek | `NativeAudioPlayer.broadcastPlaybackState` |
| Optimistic like flip | `PlayerControls.toggleLike` (online, not signed in) |

## Per-screen state flow

| Screen | Mirrors | Refreshes via | Action handlers → backend |
| :--- | :--- | :--- | :--- |
| Compact player | `state.isPlaying`, `isLiked`, `repeatMode`, duration/currentTime, artwork | observer `updateState` | delegate → NowPlayingManager/PlayerControls |
| Settings drawer | library contents, download statuses | `Mooziac_LibraryUpdated`, `Mooziac_DownloadProgress`, `Mooziac_DownloadQueueChanged`, `YTM_playerDesignChanged`, `ProgressStyleDidChange` | direct manager calls (PlaylistManager, DownloadManager, LikedSongsManager, HistoryManager) |
| PlaylistLibraryView | playlists, liked songs, downloads, history | `Mooziac_LibraryUpdated`, `YTM_playerDesignChanged`, `YTM_ambientThemeChanged`, `NetworkMonitorStatusChanged` | delegate → MainViewController + manager calls |
| OfflineLibraryView | `LocalLibraryManager.allTracks`, theme | `Mooziac_LibraryUpdated`, theme notifications | delegate → play/import |
| Lyrics HUD | current line (from state currentTime + lyrics) | 0.1 s timer; observer | `LyricsManager` |
| Menu bar panel | position, dock/float | `NSWindow.didMoveNotification`, display changes | StatusItemManager |

## Interaction matrix (Component → State → Action → Handler → Backend → Update → Visual)

### Compact player (Core.swift)

| Component | Reflects | User action | Handler | Backend | Update | Visual |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| playPauseButton | `isPlaying` | click | `playPauseTapped` | delegate → toggle | optimistic icon | icon flips |
| next/prev | — | click | `nextTapped`/`previousTapped` | delegate → next/prev | — | bounce |
| likeButton | `isLiked` | click | `likeTapped` | `toggleLike()` | `isLiked` | heart-pop + red |
| repeatButton | `repeatMode` | click | `repeatTapped` | `setRepeatMode` | `repeatMode` | repeat↔repeat.1 cyan |
| search | expanded | click/Enter | `searchIconTapped`/`searchSubmitted` | `dynamicIslandDidSearch` | — | slide-out 0.30s |
| waveform | duration/progress | drag | `onSeek` | `dynamicIslandDidSeek` | scrubbing | waveform fills |
| download | task state | click | `downloadCurrentTrackTapped` | DownloadManager queue/cancel | download state | ring/spinner/check |
| browser | settings mode | click | `browserTapped` | — | drawer | drawer expand |
| addToPlaylist | settings mode | click | `addToPlaylistButtonTapped` | — | drawer mode | playlist subview |
| fullScreen | — | click | `fullScreenTapped` | `dynamicIslandDidTapWebBrowser` | collapse | full web view |
| resetPosition | drag state | click | `resetPositionTapped` | `dynamicIslandDidTapResetPosition` | — | snap to menu bar |
| toast | transient | — | `showToastBanner` | — | — | 2.8s banner |
| drawer | settings | double-click/outside | `mouseDown`/`PillContainerView.onBackgroundClick` | — | `isSettingsExpanded` | drawer toggles |
| view | keyboard | key | `keyDown` | KeyboardCommandHandler | — | media keys + overlay |

### Settings drawer (SettingsPanel.swift)

| Component | Reflects | Action | Handler | Backend | Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Theme row | `PlayerDesign.current` | tap | `themeCycleTapped` | set current (posts) | re-theme + toast |
| Progress row | `ProgressStyle.current` | tap | `progressStyleCycleTapped` | set current (posts) | re-render + toast |
| App-only sound | `isAppVolumeOnly` | tap | onToggle | AppVolumeManager | persisted |
| Master gestures | `EdgeVolumeEngine.isEnabled` | tap | onToggle | set isEnabled | enable/disable |
| Lyrics | `isEnabled` | tap | onToggle | LyricsWindowController | HUD on/off |
| Discord | `isEnabled` | tap | onToggle | DiscordRPCManager | presence on/off |
| Library nav | `activeLibraryTab` | click | `handleLibraryNavTapped` | tab switch | list re-render |
| Playlist row | playlist list | click/right/swipe | `onRowClicked`/menu/`onDelete`/`onRightSwipePlay` | PlaylistManager | detail/delete/play |
| Detail row | playlist items | play/download/drag/right | various handlers | startPlaylist/DownloadManager/reorder | playback/ring/reorder |
| Downloads tab | `allTracks` | import/play-all/shuffle | import/play handlers | importFiles/playOfflineTrack | toasts + refresh |
| History tab | HistoryManager | play/download | `handlePlayHistoryRecord` etc. | playHistoryItem/queueTrack | playback + toast |
| Liked tab | LikedSongsManager | play/remove | `handlePlayLikedSong`/`removeLikedSong` | play/DB remove | playback + toast |
| Search | `isPlaylistSearchActive` | type | `handlePlaylistSearchChanged` | live filter | width anim 165, filtered |
| Create ＋ | `isPlaylistCreateOpen` | click/Enter | `handleCreateNewPlaylistFromHeader` etc. | createPlaylist | inline field + toast |
| Select/Done/BulkDelete | selection mode | click | toggle/bulk handlers | deletePlaylist | checkboxes/alert/toast |
| Download All | plan | click | `handleDownloadAllFromDetailHeader` | planDownloads+queueTracks | toast + tooltip |

### Artwork theming

| Component | Reflects | Trigger | Handler | Result |
| :--- | :--- | :--- | :--- | :--- |
| artworkImageView | `state.artworkUrl` | updateState | `loadArtwork` | cached fade-in |
| pill bg/border | artwork avg color | artwork loaded | `updateAmbientGlow` | tinted glow |
| all UI | `PlayerDesign.current` | setter posts | `applyTheme` | re-themed |

### Lyrics HUD

| Component | Reflects | Trigger | Handler | Result |
| :--- | :--- | :--- | :--- | :--- |
| lyricsLabel | LRC line | 0.1s timer | `activeLineAndWord(0.35)` | faded swap |
| window | center/notch | enable/playing | `repositionInCenter` | animated frame (0.25s) |
| window | status | overlay calls | `showVolumeOverlay`/`showCustomTextOverlay` | transient toast 1.5s |

## State pitfalls (see `15_ISSUES_AND_RISKS`)

- Window-hidden `updateState` skips visuals but still updates track-diff caches → possible stale labels on re-show.
- Optimistic like flip bypasses `notifyObservers` → Discord presence not updated.
- `isSettingsExpanded`/`activeSettingsMode`/`isPlaylistSearchActive` etc. are plain flags on the view — no single UI-state store; re-render cascades (`refreshPlaylistsSection` + `resetPlaylistSectionChrome` + `updateSettingsThemeHighlight`) can be O(n) per interaction.