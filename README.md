<p align="center">
  <img src="Resources/launch_transparent.png" alt="Mooziac Logo" width="280">
</p>

<p align="center">
  <strong>A fast, distraction-free YouTube Music & local audio player tucked right into your Mac’s menu bar.</strong>
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><img src="https://img.shields.io/badge/Website-mooziac.threeten.site-007AFF?style=flat-square&logo=safari&logoColor=white" alt="Website"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/macOS-13.0+-black?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+"></a>
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest"><img src="https://img.shields.io/badge/Apple%20Silicon%20+%20Intel-Universal%202-success?style=flat-square" alt="Universal Binary"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://mooziac.threeten.site"><strong>Explore Website</strong></a> •
  <a href="https://github.com/shirkeharsh/mooziac/releases/latest/download/Mooziac.dmg"><strong>Download DMG</strong></a> •
  <a href="#-building-from-source"><strong>Build from Source</strong></a>
</p>

<br>

<p align="center">
  <img src="Resources/Animals.png" alt="Mooziac Player Interface" width="620">
</p>

---

## ✨ Why Mooziac?

Heavy desktop apps and open browser tabs eat up battery and clutter your screen. Mooziac is written from the ground up in **pure Swift and AppKit** so it stays featherlight, instantaneous, and out of your way:

- 🏝️ **Lives in your menu bar** — Click the icon or hit a shortcut to peek at controls; click away and it tucks itself back into the status bar.
- 🎨 **Adaptive Dynamic Island UI** — Real-time audio waveform progress bar, smooth bouncy animations, and an ambient color glow that extracts tones from your current album art.
- 🖐️ **Physical trackpad gestures** — Slide your finger along the far-right edge of your trackpad to smoothly adjust system volume with tactile haptics.
- 🔄 **YouTube Music + Local Files** — Connect your account to play Liked Songs and playlists, or drop in offline `.mp3`, `.flac`, `.wav`, and `.m4a` files.
- 📜 **Synchronized Lyrics** — Real-time `.lrc` lyric flow that syncs line-by-line with the music.
- 🎮 **Discord Rich Presence** — Broadcasts what you’re playing to your Discord status with artwork and timestamp.
- 🔒 **Zero telemetry, 100% private** — No background analytics, no ads. Your library, playlists, and history stay right on your Mac in a local SQLite file.

---

## 🖐️ Gestures & Shortcuts

### Trackpad Gestures
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
| `⌘ + Q` | Quit |

---

## 🛠️ Building from Source

Mooziac uses the standard **Swift Package Manager**. You only need Xcode Command Line Tools installed.

```bash
# Clone the repository
git clone https://github.com/shirkeharsh/mooziac.git
cd mooziac

# Compile and launch the app
./build_app.sh
```

To build a standalone `.dmg` installer without launching:
```bash
./build_app.sh --no-launch
```
The output `.app` and `.dmg` will be generated in `dist/`.

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
Feel free to fork, customize, and make it your own!
