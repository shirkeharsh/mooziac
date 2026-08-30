# Project Overview

**Mooziac** is an ultra-lightweight, native macOS **menu bar music player for YouTube Music**, built with Swift 5.9 + AppKit. It presents itself as a glassmorphic **Dynamic Island–style floating player**, with deep integration into macOS (media keys, Now Playing, notifications, screen-lock awareness, trackpad gestures, Discord Rich Presence) and a hybrid **online (WebKit) / offline (AVPlayer)** playback architecture.

## At a glance

| Attribute | Value |
| :--- | :--- |
| Product name | Mooziac |
| Type | Native macOS menu bar application (`LSUIElement`, accessory activation) |
| Platform | macOS 13.0+ (Ventura / Sonoma / Sequoia) |
| Language / framework | Swift 5.9, AppKit, WebKit, AVFoundation, CoreAudio, MediaPlayer, IOKit |
| Package manager | Swift Package Manager (single executable target, zero external dependencies) |
| Version | 1.0.0 |
| License | MIT |
| Build | `swift build` / `./build_app.sh` (release + bundle + ad-hoc sign + launch) |

## What it does

1. **Online playback** — embeds YouTube Music in a `WKWebView`, filters ads/telemetry via content rule lists, injects a JavaScript observer to continuously track the now-playing song, and drives playback via injected JS.
2. **Offline playback** — plays local audio (`mp3`, `m4a`, `flac`, `wav`, `aac`, `ogg`, `opus`) from `~/Music/Mooziac` and `~/Library/Application Support/Mooziac/Offline` using a native `AVPlayer` engine with queue, shuffle, repeat.
3. **Dynamic Island player UI** — a compact floating "pill" with an expanding drawer (settings, playlists, downloads, history, liked songs), an interactive waveform seek bar, album-art-reactive theming, and 3 design themes (Adaptive Ambient, OLED Pitch Black, Premium Warm Off-White).
4. **Gestures & input** — right-edge trackpad volume swipe (private Multitouch framework), corner-tap shortcuts (next/prev/play-pause), scroll-wheel volume on the menu bar icon, global hotkeys, keyboard shortcuts.
5. **Menu-bar HUD** — centered synced-lyrics window, status toasts (Volume/Next Track/Playing/Paused), and a full context menu.
6. **Data & persistence** — SQLite database (`library.sqlite3`) for tracks/playlists/history/likes, UserDefaults for settings and session restoration, filesystem caches for lyrics/artwork.
7. **Background behavior** — prevents system sleep while playing, auto-pauses on lock/sleep/headphone disconnect, resumes on unlock (preference-gated), network-reachability fallback to offline library, Discord Rich Presence, track notifications, 24/7 menu-bar operation.

## Design language

Follows Apple HIG and an **8px spacing grid**. Key visual traits: frosted/liquid-glass panels, spring micro-animations, ambient artwork theming, OLED-black and warm-off-white variants.

## Architecture in one sentence

A single Swift module where `NowPlayingManager` coordinates two engines (`ObserverBridge`/`YTMWebView` for online, `NativeAudioPlayer` for offline) and fans a `PlaybackState` snapshot out to the UI (Dynamic Island player, lyrics HUD, library views), the system (Now Playing, media keys, notifications), and third parties (Discord RPC).

## Deep documentation

- Per-file / per-function exhaustive detail: `99_APPENDIX/RAW_DISCOVERY_NOTES/` (6 work packages).
- Architecture: `03_ARCHITECTURE/`.
- Workflows: `13_WORKFLOWS/`.
- Risks & known issues: `15_ISSUES_AND_RISKS/`.