# Purpose & Goals

## Product purpose

Mooziac exists to deliver a **native, lightweight, always-on menu-bar music player for YouTube Music** that is dramatically more efficient and privacy-respecting than running YouTube Music in a browser tab, while adding macOS-native features browsers cannot provide.

## Stated goals (from README)

1. **Ultra-lightweight** — near-zero CPU/GPU/RAM/battery footprint. README benchmarks: 0.5–1.8% CPU, 114–122 MB RAM, 0% Metal idle / 12% interactive, vs. 8–18% CPU and 450–850 MB for a browser. *These are project-claimed numbers, not runtime-verified by this archive.*
2. **Native macOS experience** — Dynamic Island player, menu-bar-first design, media keys, Now Playing integration, notifications, screen-lock awareness, trackpad gestures.
3. **24/7 background operation** — the app must keep playing while the display locks/sleeps, launch at login, restore session, and live only in the menu bar.
4. **Complete privacy** — zero local listening-history telemetry, no analytics, Google credentials stay in system web storage.

## Feature goals

- Online + offline playback from a single unified player.
- Real-time synchronized lyrics in a menu-bar-centered HUD.
- Trackpad gestures (right-edge volume, corner taps) without looking at the screen.
- Playlists, downloads (via `yt-dlp`), history, liked songs, cross-library playlist insertion.
- Auto-pause on lock/sleep/device disconnect; auto-resume on unlock (opt-in).
- Discord Rich Presence.
- 3 theme variants (Adaptive Ambient, OLED Pitch Black, Premium Warm Off-White).

## Non-goals / explicitly out of scope (observed in source)

- No analytics/telemetry SDKs.
- No listening-log persistence beyond an in-app history feature (which the user can clear).
- No equalizer persistence across page navigations (the EQ graph is per-page ephemeral).
- No official global-hotkey registration via Carbon `RegisterEventHotKey` (uses `NSEvent` global monitors instead).
- No AirPlay selector, no 10-band EQ (listed as roadmap, unimplemented).
- No sandbox entitlements / hardened runtime in the ad-hoc bundle.

## Roadmap items (from README, unimplemented as of this archive)

- Global hotkey customization UI.
- Built-in 10-band equalizer.
- Offline cache helper / AirPlay 2 output picker.
- More gesture/trackpad sensitivity tuning.
- Lyrics HUD font-size/opacity customization.