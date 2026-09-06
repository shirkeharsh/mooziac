# Changelog

All notable changes to Mooziac are documented in this file.

## [1.1.3] - 2026-09-07

### 🎵 Synced Lyrics & Engine Mode Isolation
- **Offline / Online Session Flushing**: Fixed an issue where lyrics from an offline track's `.lrc` file persisted on screen and in memory after reconnecting to the internet and switching back to YouTube Music playback.
- **Engine Mode Decoupling**: Gated `.lrc` sidecar candidates to offline playback mode only, preventing cross-engine lyric contamination.
- **Tighter Timing & Drift Reduction**: Eliminated artificial lead offsets, decoupled pseudo-timestamps on plain lyrics, and increased WebKit observer frequency to 4 Hz when the HUD is active.

## [1.1.2] - 2026-09-03

### ⚡ Performance & Battery Optimization
- **Near-Zero Idle CPU (< 0.4%)**: Fixed a critical background process issue where Mooziac consumed ~10%–11% CPU continuously even when playback was paused. Idle CPU now drops to `0.0% – 0.4%`, dramatically improving MacBook battery life.
- **Active Playback Efficiency**: Reduced total system CPU usage during active music playback by ~50% (from ~17% down to ~8.5%).
- **WebKit Low-Power Sleep**: WebKit rendering engines and process throttlers now properly enter low-power sleep when music is paused.

### 🐛 Bug Fixes
- **Resolved Infinite Sync Loop**: Fixed a recursion bug in `PlaylistSyncManager` (`pushUnsyncedPlaylists`, `pushDirtySyncedPlaylists`, and `pushUnsyncedLikedSongs`) where failed cloud uploads (such as expired session tokens or 401s) re-queried the database in a rapid loop instead of passing remaining items.
- **Graceful Sync Failure Handling**: Network and authentication failures during two-way sync now log once, safely preserve local playlists for future attempts, and terminate the sync cycle cleanly.

### 🛡️ Stability
- Zero impact on local SQLite database integrity, trackpad volume gestures, global media hotkeys, and native/online playback.

---

## [1.1.1] - 2026-09-01

### ✨ Highlights & Fixes
- **Adaptive Artwork Theme in Light Mode**: Resolved contrast issues on light backgrounds.
- **Dynamic Appearance Switching**: Real-time theme switching on macOS appearance change.
- **Search Bar Polish**: Pure white inputs and cleaned focus rings.
- **Contrast Rims**: Crisp perimeter borders in glass and liquid themes.
