# 🎵 Mooziac — Native macOS Menu Bar Music Player

[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B%20Ventura%20%7C%20Sonoma%20%7C%20Sequoia-black?style=for-the-badge&logo=apple)](https://developer.apple.com/macos/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![Universal 2](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen?style=for-the-badge)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

**Mooziac** is an ultra-lightweight, native macOS menu bar app designed for **YouTube Music** and **local audio playback**. Built with Swift and AppKit, it delivers a **Dynamic Island** audio player experience, real-time synchronized lyrics, gesture-based volume/track navigation, zero background battery drain, and complete user privacy.

---

## 📸 Architecture & Design System

Mooziac is crafted following Apple’s **Human Interface Guidelines (HIG)** and an **8px Spacing Grid System**. It features a glassmorphic Dynamic Island player interface, a custom text-centered glass search field, reactive micro-animations, and ambient track artwork themes.

```
┌────────────────────────────────────────────────────────────────────────┐
│ 🎵 Song Title (Bold)                            [❤️]  [🎨]  [⋯]         │
│    Artist Name (Medium)                                                │
│                                                                        │
│ ◀◀  ▶  ▶▶   [ Search songs, artists...                          ]     │
│                                                                        │
│ ─── ▂ ▃ ▅ ▆ █ ▇ ▅ ▃ ▂ ─── Waveform Progress Bar ───────────── 01:42 / 03:45 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🌟 Comprehensive Feature Breakdown

### 1. 🏝️ Dynamic Island Media Player View
- **8px Grid Layout**: Strict alignment across 3 rows without overlap regardless of window sizing or track title length.
- **Interactive Waveform Progress Bar**: Renders real-time audio wave visualization with click-and-drag seeking.
- **Micro-Animations**: Spring pop and bounce animations on button interactions.
- **Dual Design Engine**: Toggle between **Adaptive Ambient Track Theme** (extracts primary color from album art) and **OLED Pitch Black Dark Mode**.

### 2. 🖐️ Multitouch Trackpad Gestures Engine
Interact with playback directly from your Mac’s trackpad without looking at the screen:
- **Right-Edge Volume Slider**: Slide your finger along the far-right 1mm of your trackpad to smoothly adjust system volume with tactile haptic feedback.
- **Corner Tap Navigation**: Double/triple tap corners to skip tracks or toggle play/pause.
- **Safety Clamp & ID Lock**: Touch ID matching and single-swipe clamping prevent false triggers or sudden volume jumps.

### 3. 🔄 YouTube Music Sync & Local Library
- **Account Sync**: Synchronize Liked Songs, custom playlists, and listening history.
- **Continuous Queue**: Seamlessly steps through Liked Songs and playlists.
- **Local Audio Player**: Full native support for offline MP3, FLAC, WAV, AAC, and M4A playback with `.lrc` synced lyrics.

### 4. 🎮 Discord Rich Presence
- Live IPC socket connection displaying currently playing track, artist, album art, and elapsed time on your Discord profile.

### 5. 🛡️ Privacy-First Guarantee
- **Zero Telemetry**: No analytics or background data collection.
- **Local Storage**: All playlists and data stay in your local SQLite database (`~/Library/Application Support/Mooziac/`).

---

## 🛠️ Build Pipeline

### Build & Run App
```bash
./build_app.sh
```
*Compiles release binary, creates `~/Applications/Mooziac.app`, codesigns with Hardened Runtime, and launches the app.*

### Universal DMG & ZIP Packaging
```bash
./build_app.sh --no-launch
```
*Compiles a **Universal 2 Binary** (`arm64` + `x86_64`), codesigns with Hardened Runtime entitlements, and packages **`dist/Mooziac.dmg`** and **`dist/Mooziac.zip`** with Finder metadata and volume icons.*

---

## 🏗️ Source Code Layout

```
mooziac/
├── Package.swift                         # Swift Package Manager Manifest
├── build_app.sh                          # Build, packaging & launch pipeline
├── Mooziac.entitlements                  # Hardened Runtime entitlements
├── Sources/
│   └── Mooziac/                          # Single SPM target (compiled recursively)
│       ├── App/                          # App lifecycle (main.swift, AppDelegate)
│       ├── Core/                         # Central controllers & state
│       │   ├── MainViewController.swift
│       │   ├── StatusItemManager/        # Menu bar item, panel & context menu
│       │   └── NowPlayingManager/        # Playback state, queue, controls, JS bridge
│       ├── Models/                       # Pure data types & enums (no AppKit)
│       ├── Managers/                     # Service singletons (DB, downloads, playlists, updates, RPC…)
│       ├── Audio/                        # Native playback & CoreAudio engines
│       ├── Views/                        # All NSView / NSViewController
│       ├── Web/                          # WebKit integration (YTMWebView, URLFilter)
│       ├── Input/                        # Trackpad gestures & global hotkeys
│       └── Support/                      # Shared extensions & helpers
└── Resources/                            # Icons, artwork, DMG background & HTML assets
```

---

## 📄 License

Distributed under the MIT License. Copyright © 2026 ThreeTen. All rights reserved.
