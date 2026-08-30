# Diagnostic: "Audio-only not available" popup appearing repeatedly

Status: READ-ONLY. No code was modified. No fix implemented.

## What the popup is

The string "Audio-only not available" does **not** exist anywhere in the Swift codebase
(grep over `Sources/Mooziac` finds zero occurrences). `TrackNotificationManager.swift`
only ever posts "Playing on YouTube Music" track-change banners — it cannot produce this text.

Therefore the popup is **YouTube Music's own in-page toast/error UI rendered inside the
WKWebView**. It is triggered every time the app clicks the "Song / audio-only" toggle button
(`ytmusic-av-toggle button.song-button`) for a track whose audio-only version is not
available. Because the web view is not visible in playlist/player mode, the toast can still
flash repeatedly when the browser becomes visible, or surface via the hidden web view's
queued popups.

## Trigger function

`enforceSongMode()` — the JS helper that clicks the audio-only toggle:

- Defined in `Sources/Mooziac/NowPlayingManager/ObserverBridge.swift:201-211`
- Same logic re-implemented in `Sources/Mooziac/YTMWebView.swift:203-233` (`selectSongTab`)
  and `Sources/Mooziac/YTMWebView.swift:317-327` (`buildRestorePlaybackJS.enforceSong`)

Behavior: if `ytmusic-av-toggle[playback-mode] == "OMV_PREFERRED"`, click
`button.song-button`. Each such click on an unavailable song yields the popup.

## Call chain

```
ytmusic-av-toggle button.song-button  <- clicked by 8 paths (below)
   |  YT Music attempts audio-only switch
   |  audio-only version unavailable  ->  "Audio-only not available" toast
   |  toggle stays in OMV_PREFERRED   ->  next tick clicks again  (self-sustaining)
```

## Possible trigger paths (8)

| # | Path | Event/callback | Repeats? |
|---|------|----------------|----------|
| 1 | **ObserverBridge `setInterval(..., 3000)`** (`ObserverBridge.swift:278-281`) | Every 3 s, forever, for the lifetime of the page | **YES — infinite** |
| 2 | ObserverBridge video event listeners (`ObserverBridge.swift:218-224`) | `play`/`playing`/`pause`/`ended`/`ratechange`/`seeked`/`loadedmetadata`/`canplay` | Per event |
| 3 | ObserverBridge new-track detection (`ObserverBridge.swift:44`) | `updateNowPlaying` sees a new track | Per track |
| 4 | `YTMWebView.didFinish(navigation:)` (`YTMWebView.swift:242,244,247`) | Every page load finishes → `selectSongTab()` at +0 s, +0.5 s, +1.5 s; each has its own retry interval (`YTMWebView.swift:223-229`) | Per navigation (up to ~8 clicks) |
| 5 | `PlaylistManager.playOnlineVideo` (`PlaylistManager.swift:237`) | Delayed +1.5 s after loading the watch URL → `selectSongTab()` (own retry interval, up to 5 clicks) | Per online-playlist play |
| 6 | `PlaylistManager.playOnlineVideo` play-click (`PlaylistManager.swift:239-257`) | Injected `playVideo()`/play-button click → fires `play`/`playing` events → re-enters path 2 | Cascades into path 2 |
| 7 | `MainViewController.setBrowserVisible(true)` (`MainViewController.swift:139`) | User opens the browser window | Per open |
| 8 | `YTMWebView.buildRestorePlaybackJS.enforceSong` (`YTMWebView.swift:317-327, 328+`) | Crash-recovery retry loop | Per recovery, looped |

## Why it repeats — root cause

**Path 1 is the culprit.** `enforceSongMode()` is invoked from an unconditional
`setInterval` every 3000 ms for the entire lifetime of the page (`ObserverBridge.swift:278-281`).
The injected script guards against double-injection with `window.ytmObserverInjected`
(`ObserverBridge.swift:12`), but the interval it installs never self-terminates.

The failure is **self-sustaining**:

1. A track in `OMV_PREFERRED` mode has no available audio-only version.
2. The click fails; the toggle stays in `OMV_PREFERRED`.
3. 3 s later the interval sees `OMV_PREFERRED` again → clicks again → popup again.

This happens with zero involvement of playlist/queue logic. `playOnlineVideo` runs once per
play; the repetition comes entirely from the web-view observer interval plus the video-event
listeners.

## Classification

- **NOT** a playlist retry loop — playlist playback is attempted once; nothing re-invokes it.
- **NOT** a queue/observer `notifyObservers` loop — those are pure Swift-side state pushes and
  never click the toggle.
- **NOT** notification duplication — the popup is a web toast, not a `UNUserNotification`.
- **IS** a **WebView JS observer interval loop** (path 1), amplified by video-event
  re-enforcement (path 2) and the `selectSongTab` retries (paths 4-5).
- Same track: yes — the *audio-only switch* is re-attempted dozens of times on the same track;
  the *load* is not repeated.

## No debounce/cooldown

There is no cooldown anywhere: the web toast is YT Music's own UI (unseen by the app), and
`enforceSongMode()`/`selectSongTab()`/`enforceSong` have no "already tried for this track /
mode" guard. The only guard is `ytmObserverInjected`, which prevents duplicate intervals, not
repeated clicks.

## Error propagation

None. Nothing reads the popup or feeds it back into playlist/queue logic. The repetition is
fully internal to the web view.

## Exact recommended minimal fix (NOT applied)

Primary fix — make the song-toggle click **transition-based** instead of interval-based,
inside `enforceSongMode()` in `ObserverBridge.swift`:

- Cache the last observed `playback-mode` (and last clicked videoId) in window scope.
- Only click `button.song-button` when the mode **changed** to `OMV_PREFERRED` (new track /
  navigation), not on every 3 s tick.
- If the mode is already `OMV_PREFERRED` and we already clicked once for the current
  `videoId`, do nothing — this stops the "audio-only not available" toast from reappearing.

Secondary (recommended alongside, still minimal):

- Remove the `enforceSongMode()` call from the 3 s interval (`ObserverBridge.swift:280`);
  keep `bindVideoEvents()` there. New-track detection (`ObserverBridge.swift:44`) and
  `didFinish` already cover the legit case.
- Leave `selectSongTab()` retries (`YTMWebView.swift:223-229`) capped as-is; they only run
  near navigation time, so their clicks are subsumed by the transition guard above.