# Playback Workflow

End-to-end playback scenario: "play a song and follow its lifecycle."

## Scenario: play from online search/YTM

```
1. User searches in YTM webview (or clicks queue/suggested item)
2. JS mutation observers detect play state change
3. ObserverBridge.nowPlayingHandler(message) → 15-field payload
4. NowPlayingManager.currentState rebuilt
5. updateSystemNowPlayingInfo() → MPNowPlayingInfoCenter
6. notifyObservers()
     ├─ DynamicIslandPlayerView.updateState → labels/artwork/waveform
     ├─ DiscordRPCManager.updatePresence
     ├─ Lyrics HUD fetch + current line
     └─ TrackNotificationManager (if track changed & enabled)
7. HistoryManager records listening_history entry
8. Persist YTM_lastTitle/Artist/Artwork/Url/VideoId/Time
```

## Scenario: play from offline library

```
1. OfflineLibraryView / PlaylistLibraryView / LikedSongsView select track
2. NativeAudioPlayer.play(track:in:)
3. engineMode = .offline; JS pause snippet evaluated (silent if web not loaded)
4. HistoryManager.trackDidStartOffline
5. AVPlayerItem prepared; replaceCurrentItem
6. setupTimeObserver(0.25s) → broadcastPlaybackState → currentState + notifyObservers
7. system Now Playing artwork set (MPMediaItemArtwork)
8. End-of-track: repeat-mode logic → next in playlist context or queue
```

## Scenario: next/previous

| Command | Online | Offline |
| :--- | :--- | :--- |
| Next | priority: active playlist context → JS next-button click → next queue item → `player.nextVideo()` | priority: playlist context → native next (shuffled queue if shuffle) |
| Prev | mirrored | native prev; restart if >3 s elapsed |

## Scenario: engine fallback (network drop)

```
NetworkMonitorStatusChanged (offline)
  → NowPlayingManager stays/enters offline-capable state
  → playback continues via webview if buffered; downloads gated
  → NetworkMonitorReconnected → requeue downloads; UI reflects online
```

## Scenario: like

```
User taps like (player UI / context menu)
  ├─ Online: optimistic flip (UI) + LikedSongsManager record + JS click to persist
  │          (note: Discord presence not updated on optimistic flip — risk)
  └─ Offline: LocalTrack.isLiked toggle ↔ SQLite liked_songs ↔ LocalLibraryManager
```

## Scenario: repeat / shuffle

```
Repeat: toggleRepeat → setRepeatMode → JS window.ytmRepeatMode (online) / native (offline)
Shuffle: setShuffleState → JS window.ytmShuffleActive (online) / shuffledQueue (offline)
```

## Scenario: track ends

```
AVPlayerItemDidPlayToEndTime (offline)
  ├─ repeat .one → seek(0)+play
  ├─ playlist context active → playNextTrackInPlaylist()
  └─ else nextTrack() / queue-end stop
Online end → JS ended event → YTM auto-advances; nowPlayingHandler updates state
```

## Related

- `06_AUDIO/PLAYBACK_PIPELINE.md`, `06_AUDIO/QUEUE_SYSTEM.md`, `13_WORKFLOWS/SEARCH_WORKFLOW.md`.