<p align="center">
  <a href="https://mooziac.threeten.site">
    <img src="Resources/banner3.svg" alt="Mooziac macOS Music Player" width="100%">
  </a>
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><img src="https://img.shields.io/badge/Website-mooziac.threeten.site-FA4059?style=flat-square&logo=safari&logoColor=white" alt="Mooziac Website"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/macOS-13.0%2B%20Ventura%20%7C%20Sonoma%20%7C%20Sequoia-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+ Compatibility"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen?style=flat-square" alt="Universal Binary"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/github/v/release/shirkeharsh/mooziac?style=flat-square&color=8B7BFF" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="MIT License"></a>
  <a href="#privacy-first-architecture"><img src="https://img.shields.io/badge/Privacy-100%25%20Local--First-28cd41?style=flat-square&logo=shield" alt="Zero Telemetry"></a>
</p>

<p align="center">
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg">
    <img src="https://img.shields.io/badge/Download-Mooziac.dmg-FA4059?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.zip">
    <img src="https://img.shields.io/badge/Download-Mooziac.zip-8B7BFF?style=for-the-badge&logo=zip&logoColor=white" alt="Download ZIP">
  </a>
  &nbsp;&nbsp;
  <a href="https://mooziac.threeten.site">
    <img src="https://img.shields.io/badge/Explore-Official%20Site-34C759?style=for-the-badge&logo=safari&logoColor=white" alt="Official Website">
  </a>
</p>

<br>

---

## Overview

Mooziac is a native macOS music player written in Swift and AppKit. It lives in the macOS menu bar, providing instant playback controls, YouTube Music integration, offline audio playback, real-time synchronized lyrics, and trackpad edge volume gestures with minimal resource usage.

---

<p align="center">
  <img src="Resources/Animals 2.png" alt="Mooziac macOS Menu Bar Interface" width="700">
</p>

## Core Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>Native Menu Bar Interface</h3>
      <ul>
        <li><b>Grid Layout:</b> Compact 3-row layout engineered specifically for macOS menu bar presentation.</li>
        <li><b>Interactive Waveform:</b> Real-time audio waveform visualization with drag seeking.</li>
        <li><b>Adaptive Palette:</b> Dynamically samples primary colors from active album artwork.</li>
        <li><b>Native Animations:</b> Smooth spring-based animations on playback interactions.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>MultiTouch Edge Gestures</h3>
      <ul>
        <li><b>Edge Volume Slider:</b> Slide along the rightmost 1mm trackpad border for smooth volume adjustment.</li>
        <li><b>Haptic Feedback:</b> Tactile ticks as system volume changes.</li>
        <li><b>Corner Taps:</b> Configurable corner taps to skip tracks or toggle playback.</li>
        <li><b>Input Filtering:</b> Touch ID and single-finger filters prevent unintended gesture activation.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>Dual Audio Engines</h3>
      <ul>
        <li><b>YouTube Music Bridge:</b> Sandboxed WebKit bridge syncing playlists, liked songs, and listening history.</li>
        <li><b>Offline Playback:</b> Native AVFoundation engine supporting MP3, FLAC, WAV, AAC, and M4A.</li>
        <li><b>Unified Queue:</b> Seamless transition between online streams and local audio files.</li>
        <li><b>Offline Storage:</b> Integrated yt-dlp downloader with automatic metadata extraction.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>Synchronized Lyrics HUD</h3>
      <ul>
        <li><b>Line-by-Line LRC:</b> Real-time synchronized lyrics fetched via LRCLib and fallback providers.</li>
        <li><b>Menu Bar Anchored:</b> Floating, non-intrusive HUD positioned below the active menu bar item.</li>
        <li><b>Plain Text Fallback:</b> Automatically displays unsynced lyrics when timing markers are unavailable.</li>
        <li><b>Local Cache:</b> Lyrics are cached locally for offline and instant retrieval.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>Discord Rich Presence</h3>
      <ul>
        <li><b>Native Unix Socket IPC:</b> Direct connection to local Discord client with zero third-party dependencies.</li>
        <li><b>Now Playing Card:</b> Displays track title, artist, elapsed time, and album art.</li>
        <li><b>Status Synchronization:</b> Real-time playback status updates on pause and resume.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3 id="privacy-first-architecture">Privacy-First Architecture</h3>
      <ul>
        <li><b>Zero Telemetry:</b> No analytics SDKs, error tracking beacons, or remote logging.</li>
        <li><b>Local SQLite Database:</b> Playlists, history, and preferences are stored exclusively on your Mac.</li>
        <li><b>Isolated Credentials:</b> Google and YouTube authentication stays inside Apple's sandboxed WKWebView.</li>
      </ul>
    </td>
  </tr>
</table>

---

## Gestures and Keyboard Shortcuts

### Trackpad MultiTouch Gestures

| Gesture | Trackpad Region | Action |
| :--- | :--- | :--- |
| **Edge Slide** | Far-right 1mm border | Adjust system volume with tactile haptics |
| **Double Tap** | Bottom-right corner | Next Track |
| **Triple Tap** | Bottom-right corner | Previous Track |
| **Double Tap** | Bottom-left corner | Play / Pause Toggle |
| **Scroll** | Over Menu Bar Icon | Volume Adjustment |

### Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `Command + Right Arrow` | Next Track |
| `Command + Left Arrow` | Previous Track |
| `L` | Like / Unlike Song |
| `Command + R` | Reload Web Engine |
| `Command + Q` | Quit Mooziac |

---

## Installation

### Pre-built Binary

1. Download [`Mooziac.dmg`](https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg) or [`Mooziac.zip`](https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.zip).
2. Open `Mooziac.dmg` and drag **Mooziac** into your **Applications** folder.
3. Launch Mooziac from Spotlight (`Command + Space`) or `/Applications`.

### Gatekeeper Note
Because Mooziac is distributed directly outside the Mac App Store:
- **System Settings:** If prompted, open *System Settings > Privacy & Security* and select *Open Anyway*.
- **Terminal Command:** Alternatively, clear the quarantine attribute:
  ```bash
  xattr -cr /Applications/Mooziac.app
  ```

---

## Architecture and Project Structure

Mooziac is built as a Swift Package Manager project with zero third-party dependencies, leveraging native macOS frameworks (AppKit, AVFoundation, WebKit, SQLite3, and Unified Logging):

```
Mooziac/
├── .github/workflows/ci.yml              # Headless GitHub Actions CI (build and test)
├── Package.swift                         # SPM Manifest (macOS 13+, Swift 5.9)
├── Mooziac.entitlements                  # Hardened Runtime security entitlements
├── build_app.sh                          # Development build and launch script
├── mooziac.sh                            # Universal binary DMG packager
├── Sources/Mooziac/                      # Main application target
│   ├── App/                              # Application lifecycle, AppDelegate, background media
│   ├── Audio/                            # CoreAudio volume hooks and AVFoundation native player
│   ├── Core/                             # Central state coordinators and logging (Log.swift)
│   │   ├── NowPlayingManager/            # Now playing session and media controls
│   │   └── StatusItemManager/            # Menu bar status item, menu, and controllers
│   ├── Input/                            # MultiTouch gesture engine and keyboard shortcuts
│   ├── Managers/                         # Local SQLite3, download queue, synced lyrics, updates
│   ├── Models/                           # Data models and state representations
│   ├── Support/                          # Color palettes, string utilities, system extensions
│   ├── Views/                            # Menu bar player UI, waveform, lyrics HUD
│   │   ├── Components/                   # Reusable UI controls, buttons, search field
│   │   ├── Libraries/                    # Local, offline, and playlist management views
│   │   ├── Player/                       # Dynamic Island and settings drawer views
│   │   └── Windows/                      # Floating HUD, tutorial, and overlay windows
│   └── Web/                              # Sandboxed WebKit bridge for YouTube Music
├── Tests/MooziacTests/                   # Comprehensive unit test suite
│   ├── DownloadManagerURLTests.swift     # URL extraction and validation tests
│   ├── DownloadQueuePersistenceTests.swift# Queue serialization and persistence tests
│   ├── MooziacTests.swift                # Environment and build sanity tests
│   ├── SyncedLyricsParserTests.swift     # LRC timestamp and line parsing tests
│   └── URLFilterTests.swift              # Search query URL filter tests
└── Resources/                            # Visual assets, SVG banner, themes, and icons
```

---

## Building from Source

### Requirements
- macOS 13.0 or later
- Xcode 15+ or Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9 toolchain

### Build Commands

```bash
# Build debug binary
swift build

# Run unit tests
swift test --parallel

# Build optimized release binary
swift build -c release

# Build and run the app locally
./build_app.sh

# Build release package without launching
./build_app.sh --release-only
```

---

## License and Disclaimer

- **License:** Distributed under the [MIT License](LICENSE). Copyright 2026 ThreeTen.
- **Disclaimer:** YouTube Music is a trademark of Google LLC. Mooziac is an independent open-source project and is not affiliated with, authorized, or endorsed by Google LLC.
