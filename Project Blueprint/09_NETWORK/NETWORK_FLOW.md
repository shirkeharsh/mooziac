# Network Flow

How data travels in and out of Mooziac.

## Categories of network activity

```
┌────────────────────────────────────────────────────────────────┐
│ 1. WebKit (primary) — YouTube Music page + embedded media      │
│    - WKWebView load, JS eval, WKScriptMessageHandler replies   │
│    - media streams play in WebContent process (not app)        │
│ 2. URLSession (auxiliary) — lyrics, artwork, notifications     │
│ 3. Subprocess (downloads) — yt-dlp + ffmpeg                    │
│ 4. Local IPC (presence) — Discord UNIX socket                  │
└────────────────────────────────────────────────────────────────┘
```

## WebKit flow

```
MainViewController → YTMWebViewContainer.webView.load(URL)
  → YouTube Music page renders (network in WebContent process)
  → injected JS (ObserverBridge, PlayerControls, URLFilter) observes
  → JS → evaluateJavaScript(command) → results returned synchronously
  → JS → webkit.messageHandlers.nowPlayingHandler.postMessage(payload)
  → ObserverBridge.userContentController(didReceive:) → PlaybackState
  → UI update + persistence (YTM_last*) + Discord + history
```

- **Content blocking**: `URLFilter` decides block/allow; `YTMBlockRules` content-blocking JSON embedded in `YTMWebView.swift`.
- **Media**: audio never routes through app networking; streams stay in WebKit.
- **Restore**: on launch, `YTM_lastUrl` (must contain `watch?v=`) + `YTM_lastTime` replayed via `cueVideoById` (paused).
- **Recovery**: `recoveryWatchdog` (20 s) + `webViewWebContentProcessDidTerminate` re-inject observers and restore playback.

## URLSession flow (example: lyrics)

```
LyricsManager.fetchLyrics(track)
  → URLSession.shared.dataTask(url: lrclib /api/get)
  → JSON decode
  → match gates (duration ≤12s, title ≥0.6, artist ≥0.4/subset)
  → parse LRC / synthesize plain (4.0s)
  → cache to ~/Library/Caches/Mooziac/Lyrics/
  → completion(main)
```

## Download flow (yt-dlp)

```
DownloadManager.enqueue(videoId)
  → task → subprocess yt-dlp (player_client=mweb,web_safari,tv_embedded,web)
  → write ~/Music/Mooziac/.downloading/<jobId>/
  → ffmpeg → final mp3/m4a...
  → LocalLibraryManager rescan → SQLite upsert → Mooziac_LibraryUpdated
  → progress posted via Mooziac_DownloadProgress
```

## Discord presence flow

```
PlaybackState change
  → DiscordRPCManager → connect UNIX socket /tmp/discord-ipc-0..9
  → HANDSHAKE → SET_ACTIVITY(activity JSON)
  → silent retry/backoff on failure
```

## Network monitor

- `NetworkMonitor` posts `NetworkMonitorStatusChanged` / `NetworkMonitorReconnected`.
- Consumed by NowPlayingManager engine switching, HistoryManager playback fallback, DownloadManager queue gating.

## Network-bound writes (state persistence)

| Trigger | Destination |
| :--- | :--- |
| nowPlayingHandler message | UserDefaults `YTM_last*` |
| track play | SQLite `listening_history` (HistoryManager) |
| like toggle (online) | `liked_songs` (LikedSongsManager) + JS state |

## Related

- `09_NETWORK/REQUEST_PIPELINES.md`, `10_BACKGROUND_SYSTEMS/SYSTEM_INTEGRATIONS.md`.