<p align="center">
  <img src="Resources/launch_transparent.png" alt="Mooziac Logo - Native macOS Music Player" width="300">
</p>

<h1 align="center">Mooziac — Native macOS Music Player</h1>

<p align="center">
  <strong>Mooziac is a beautiful native macOS music player built with Swift and SwiftUI.</strong><br>
  A fast, distraction-free YouTube Music & local audio player tucked right into your Mac’s menu bar.
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><img src="https://img.shields.io/badge/Website-mooziac.threeten.site-007AFF?style=flat-square&logo=safari&logoColor=white" alt="Mooziac Website"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/macOS-13.0+-black?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+ Compatibility"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/Apple%20Silicon%20+%20Intel-Universal%202-success?style=flat-square" alt="Universal 2 Binary"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/github/v/release/shirkeharsh/mooziac?style=flat-square&color=orange" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="MIT License"></a>
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><strong>🌐 Official Website</strong></a> •
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg"><strong>⬇️ Download DMG</strong></a> •
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><strong>📦 Release Notes</strong></a> •
  <a href="#-building-from-source"><strong>🛠️ Build from Source</strong></a>
</p>

<br>

<p align="center">
  <img src="Resources/Animals.png" alt="Mooziac native macOS music player interface with real-time waveform and album art" width="640">
</p>

---

## 🎵 What is Mooziac?

**Mooziac** is a lightweight, open-source **macOS music player** engineered from the ground up as a **native macOS app** using **Swift** and **SwiftUI**. Instead of running heavy browser tabs or resource-hungry desktop wrappers, Mooziac sits discreetly in your Mac’s menu bar, giving you instant playback controls, **YouTube Music** integration, offline local audio playback, synchronized lyrics, and innovative trackpad edge volume gestures.

---

## ✨ Features

- 🏝️ **Menu Bar Native** — Sits seamlessly in your macOS menu bar. Click the icon or hit a global hotkey to pop open your controls; click away and it tucks itself back into the status bar.
- 🔄 **YouTube Music Streaming** — Securely connect your YouTube Music account to stream Liked Songs, artist radios, and personalized playlists without keeping a browser open.
- 📁 **High-Res Local Audio Playback** — Built-in native CoreAudio engine to play offline `.mp3`, `.flac`, `.wav`, and `.m4a` files with drag-and-drop ease.
- 🎨 **Adaptive Dynamic Island UI** — Real-time audio waveform visualizer, fluid spring animations, and an ambient color glow dynamically sampled from the current album art.
- 🖐️ **Physical Trackpad Gestures** — Slide your finger along the far-right edge of your MacBook trackpad to adjust volume with tactile haptic feedback ticks.
- 📜 **Synchronized LRC Lyrics** — Real-time `.lrc` lyric flow synchronized line-by-line with the music.
- 🎮 **Discord Rich Presence** — Automatically broadcast what you’re playing (song title, artist, album art, and timestamps) to your Discord status.
- 🔒 **Zero Telemetry & 100% Private** — No ads, no tracking scripts, and no background telemetry. Your library, playlists, and history stay strictly local in a SQLite database on your Mac.
- ⚡ **Universal 2 Architecture** — Optimized natively for Apple Silicon (M1/M2/M3/M4) and Intel-based Macs.

---

## 🖐️ Gestures & Shortcuts

### Trackpad Multitouch Gestures
| Gesture | Location | Action |
| :--- | :--- | :--- |
| **Edge Slide** | Rightmost 1mm of trackpad | Smooth volume adjustment with haptic tick |
| **Double Tap** | Bottom-right corner | Next track |
| **Triple Tap** | Bottom-right corner | Previous track |
| **Double Tap** | Bottom-left corner | Play / Pause |
| **Scroll Wheel** | Over menu bar icon | Quick volume nudge |

### Keyboard Shortcuts
| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `⌘ + →` | Next track |
| `⌘ + ←` | Previous track |
| `L` | Like / Unlike song |
| `⌘ + R` | Reload web engine |
| `⌘ + Q` | Quit Mooziac |

---

## 💻 System Compatibility

- **Operating System:** macOS 13.0 (Ventura), macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), and later.
- **Hardware Architecture:** Universal Binary supporting both Apple Silicon (`arm64`) and Intel (`x86_64`).
- **Dependencies:** Standalone native app (no external runtimes or framework dependencies needed).

---

## 📦 Installation

### Option 1: Direct Download (Recommended)
1. Download the latest **[Mooziac.dmg](https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg)**.
2. Open the `.dmg` file.
3. Drag **Mooziac** into your **Applications** folder.
4. Launch Mooziac from your Applications or Spotlight.

### Option 2: Building from Source
Mooziac uses standard **Swift Package Manager (SPM)**. You only need Xcode Command Line Tools installed.

```bash
# Clone the Mooziac repository
git clone https://github.com/shirkeharsh/mooziac.git
cd mooziac

# Compile and launch the app
./build_app.sh
```

To build a standalone `.dmg` installer without launching:
```bash
./build_app.sh --no-launch
```
The output `.app` and `.dmg` will be generated in the `dist/` directory.

---

## 📂 Source Code Layout

```
Sources/Mooziac/
├── App/        # Lifecycle, AppDelegate, and sleep prevention
├── Audio/      # CoreAudio engine, native file player, and edge volume hook
├── Core/       # NowPlayingManager, menu bar status item & main controllers
├── Input/      # Multitouch trackpad gestures and global hotkeys
├── Managers/   # SQLite database, downloads, synced lyrics, and Discord RPC
├── Models/     # Pure data models and player state
├── Support/    # Extensions and system helpers
├── Views/      # Player UI, waveform bar, lyrics overlay, and libraries
└── Web/        # Sandboxed WebKit bridge for YouTube Music
```

---

## 📄 License

Mooziac is open-source software licensed under the [MIT License](LICENSE).  
Feel free to star, fork, and contribute!
