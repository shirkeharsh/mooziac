<p align="center">
  <a href="https://mooziac.threeten.site">
    <img src="Resources/banner.svg" alt="Mooziac — macOS Music Player" width="100%">
  </a>
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><img src="https://img.shields.io/badge/Website-mooziac.threeten.site-FA4059?style=flat-square&logo=safari&logoColor=white" alt="Mooziac Website"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/macOS-13.0%2B%20Ventura%20%7C%20Sonoma%20%7C%20Sequoia-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+ Compatibility"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen?style=flat-square" alt="Universal 2 Binary"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/github/v/release/shirkeharsh/mooziac?style=flat-square&color=8B7BFF" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="MIT License"></a>
  <a href="#-privacy-first-architecture"><img src="https://img.shields.io/badge/Privacy-100%25%20Local--First-28cd41?style=flat-square&logo=shield" alt="Zero Telemetry"></a>
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

</p>

---

## ⚡ What is Mooziac?

**Mooziac** is an ultra-lightweight, open-source macOS music player engineered from the ground up in **pure Swift 5.9 and AppKit**. 

Instead of running heavy web browser tabs or resource-hungry Electron wrappers, Mooziac docks discreetly in your Mac’s menu bar. It delivers instantaneous playback controls, seamless **YouTube Music** integration, an offline lossless audio engine, live synchronized lyrics, and innovative trackpad edge volume gestures — all while consuming a fraction of the RAM and battery of standard players.

---

<br>

<p align="center">
  <img src="Resources/Animals.png" alt="Mooziac macOS Menu Bar Interface" width="700">

## 🌟 Core Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎵 Native Menu Bar Player</h3>
      <ul>
        <li><b>Pixel-Perfect 8px Grid:</b> Strict alignment across 3 rows without overlap or text clipping.</li>
        <li><b>Real-Time Waveform Seeker:</b> Interactive audio wave rendering with scrub-and-drag seeking.</li>
        <li><b>Ambient Chromatic Glow:</b> Dynamically samples primary colors from active album art.</li>
        <li><b>Micro-Spring Physics:</b> Smooth Apple-style spring animations on playback actions.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>🖐️ MultiTouch Edge Slider</h3>
      <ul>
        <li><b>1mm Right-Edge Volume:</b> Slide along the rightmost trackpad edge for smooth volume adjustment.</li>
        <li><b>Tactile Haptic Feedback:</b> Subtle haptic ticks as system volume rises and lowers.</li>
        <li><b>Corner Tap Shortcuts:</b> Double/triple tap trackpad corners to skip tracks or play/pause.</li>
        <li><b>Safety Velocity Clamping:</b> Touch ID & single-finger filters prevent false triggers.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Dual Playback Engines</h3>
      <ul>
        <li><b>YouTube Music Sync:</b> Sandboxed WebKit bridge syncs Liked Songs, playlists, and history.</li>
        <li><b>Lossless Offline Player:</b> Native AVFoundation engine for <code>.mp3</code>, <code>.flac</code>, <code>.wav</code>, <code>.aac</code>, <code>.m4a</code>.</li>
        <li><b>Continuous Queue:</b> Seamless transition across Liked Songs and local audio libraries.</li>
        <li><b>Offline Downloads:</b> Integrated <code>yt-dlp</code> engine with auto-tagging.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>📜 Synced Lyrics HUD</h3>
      <ul>
        <li><b>Line-by-Line Synchronized:</b> Real-time <code>.lrc</code> lyric synchronization via LRCLib & Lyrics.ovh.</li>
        <li><b>Menu Bar Anchored:</b> Floating, non-intrusive HUD centered directly under your menu bar.</li>
        <li><b>Full-Text Fallback:</b> Automatically falls back to plain unsynced lyrics when LRC is unavailable.</li>
        <li><b>Offline Lyric Caching:</b> Synced lyrics stored locally for instant subsequent loads.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎮 Discord Rich Presence</h3>
      <ul>
        <li><b>Direct Unix Socket IPC:</b> Zero-latency connection to local Discord client without external SDKs.</li>
        <li><b>Live Now Playing Card:</b> Displays song title, artist name, elapsed track time, and album artwork.</li>
        <li><b>Play/Pause Status:</b> Real-time status sync when pausing or resuming playback.</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>🛡️ Privacy-First Architecture</h3>
      <ul>
        <li><b>Zero Telemetry:</b> Absolutely no analytics SDKs, error tracking beacons, or data harvesting.</li>
        <li><b>100% Local SQLite:</b> Playlists, listening history, and preferences stay on your Mac.</li>
        <li><b>Isolated Auth:</b> Google / YouTube credentials stay inside Apple's sandboxed <code>WKWebView</code>.</li>
      </ul>
    </td>
  </tr>
</table>

---

## 🖐️ Hardware Gestures & Shortcuts

### Trackpad MultiTouch Gestures

| Gesture | Trackpad Region | Action |
| :--- | :--- | :--- |
| **Edge Slide** | Far-right 1mm border | Smooth system volume adjustment with tactile haptics |
| **Double Tap** | Bottom-right corner | Skip to Next Track (`⏭`) |
| **Triple Tap** | Bottom-right corner | Return to Previous Track (`⏮`) |
| **Double Tap** | Bottom-left corner | Play / Pause Toggle (`⏯`) |
| **Scroll Wheel** | Hovered over Menu Bar Icon | Instant volume nudge |

### Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `⌘ + →` | Next Track |
| `⌘ + ←` | Previous Track |
| `L` | Like / Unlike Song |
| `⌘ + R` | Reload Web Engine |
| `⌘ + Q` | Quit Mooziac |

---

## 📥 Installation

### Option 1: Direct Download (Recommended)
1. Download **[`Mooziac.dmg`](https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg)** (or [`Mooziac.zip`](https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.zip)).
2. Open `Mooziac.dmg` and drag **Mooziac** into your **Applications** folder.
3. Launch Mooziac from Spotlight (`⌘ + Space`) or `/Applications`.

### 💡 First-Time Launch (macOS Gatekeeper)
Because Mooziac is distributed independently as an open-source binary outside the Mac App Store, macOS may show an unverified developer prompt on first launch:
- **Option A (UI Approval):** Right-click `Mooziac.app` ➔ click **Open** ➔ select **Open Anyway** (or go to *System Settings ➔ Privacy & Security* and approve).
- **Option B (Terminal 1-Liner):** Run this once in Terminal:
  ```bash
  xattr -cr /Applications/Mooziac.app
  ```

---

## 🏗️ Architecture & Source Code Layout

Mooziac is built as a single Swift Package Manager target with **zero third-party dependencies** — powered entirely by Apple native frameworks and OS-bundled C libraries:

```
mp3kal/
├── Package.swift                         # SPM Manifest (macOS 13+, Swift 5.9, 0 external deps)
├── build_app.sh                          # Fast development build & app launcher
├── mooziac.sh                            # Universal 2 production DMG packager
├── Mooziac.entitlements                  # Hardened Runtime security entitlements
├── Sources/Mooziac/                      # Native Swift & AppKit Source
│   ├── App/                              # Application lifecycle, AppDelegate, launch animation
│   ├── Core/                             # Central state & coordinators (NowPlayingManager, StatusItem)
│   ├── Audio/                            # CoreAudio volume hook & AVFoundation native player
│   ├── Input/                            # MultiTouch private framework gesture engine & hotkeys
│   ├── Managers/                         # Local SQLite3, Downloads, Synced Lyrics & Discord RPC
│   ├── Models/                           # Pure data structures and state snapshots
│   ├── Views/                            # Menu bar player UI, Waveform bar, lyrics HUD
│   ├── Web/                              # Sandboxed WebKit bridge for YouTube Music
│   └── Support/                          # Color palettes, string helpers, system extensions
└── Resources/                            # Visual assets, SVG banner, themes, and menu bar icons
```

---

## 🛠️ Building from Source

### Prerequisites
- macOS 13.0+ (Ventura, Sonoma, Sequoia)
- Xcode 15+ or Xcode Command Line Tools (`xcode-select --install`)

```bash
# Clone repository
git clone https://github.com/shirkeharsh/mooziac.git
cd mooziac

# Compile and launch development build
./build_app.sh

# Package production Universal 2 DMG (Apple Silicon + Intel)
./mooziac.sh
```

---

## 📄 License & Legal

- **License:** Distributed under the [MIT License](LICENSE). Copyright © 2026 ThreeTen.
- **Privacy Policy:** Read our [Privacy Policy](docs/PRIVACY.md).
- **Terms of Service:** Read our [Terms of Service](docs/TERMS.md).
- **Security Policy:** Read our [Security Policy](SECURITY.md).
- **Disclaimer:** *YouTube Music is a trademark of Google LLC. Mooziac is an independent open-source project and is not affiliated with, authorized, or endorsed by Google LLC.*
