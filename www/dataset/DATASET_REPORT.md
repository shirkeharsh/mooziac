# Mooziac Support AI Dataset Report

This report documents the knowledge, conversational, troubleshooting, and architectural datasets constructed for fine-tuning a future local small language model (SLM) serving as the official **Mooziac Support AI**.

All technical facts, numerical thresholds, gesture boundaries, and failure modes have been strictly extracted from the authoritative **Mooziac codebase** (`shirkeharsh/mooziac`), official documentation, GitHub issue tracking, changelogs, and user support records. No unsupported generic music-player features have been assumed.

---

## 1. Executive Summary & Dataset Metrics

| Dataset File | Format | Entry Count | Metric Description |
| :--- | :--- | :--- | :--- |
| `01_mooziac_knowledge.jsonl` | JSONL | **98** facts | Atomic, verified architectural & functional ground-truth facts |
| `02_mooziac_qa.jsonl` | JSONL | **142** pairs | Multi-phrased Q&A pairs covering formal, casual, & colloquial questions |
| `03_mooziac_troubleshooting.jsonl` | JSONL | **25** trees | Complete diagnostic trees (problem, causes, solutions, features, source) |
| `04_mooziac_features.jsonl` | JSONL | **35** features | Explicitly separated `current` (29), `planned` (3), & `requested` (3) features |
| `05_mooziac_faq.jsonl` | JSONL | **35** entries | Canonical FAQs accompanied by **150** natural language question variations |
| `06_mooziac_conversations.jsonl` | JSONL | **20** dialogues | **80** multi-turn turns handling debugging, frustration, & resolution |
| `07_mooziac_capabilities.json` | JSON | **7** domains | Comprehensive structured capability matrix |
| `08_mooziac_limitations.json` | JSON | **7** domains | Explicit non-capabilities, hardware boundaries, & architectural limits |
| `09_mooziac_source_map.jsonl` | JSONL | **35** sources | Complete traceability map linking datasets back to exact code & docs |

### Key Aggregated Metrics
* **Total Knowledge Entries:** 98 atomic facts
* **Total Q&A Examples:** 142 pairs
* **Total Troubleshooting Diagnostic Trees:** 25 problems
* **Total Multi-Turn Dialogues:** 20 full conversations (80 conversational turns)
* **Total Distinct Topics Covered:** 126 specific subtopics
* **Total Natural-Language Question Variations:** **367** variations (including slang, colloquialisms, typos, and frustrated expressions)

---

## 2. Topic Coverage Breakdown

The dataset provides exhaustive, verified coverage across every layer of the Mooziac architecture:

1. **What is Mooziac & Architecture:**
   * Pure Swift 5.9 + AppKit native desktop application (zero Electron, zero Chromium, zero CocoaPods/Carthage).
   * Universal 2 binary supporting Apple Silicon (`arm64`: M1/M2/M3/M4) and Intel (`x86_64`) on macOS 13.0 Ventura, macOS 14 Sonoma, and macOS 15 Sequoia.
   * Tiny memory footprint (40–90MB during local playback; ~120–180MB with WebKit YTM streaming) and ultra-low CPU usage (<1.5%).

2. **Installation, Gatekeeper & Lifecycle:**
   * Distributed as a `.dmg` via GitHub releases without paid Apple Developer ID notarization.
   * Gatekeeper quarantine removal commands (`xattr -cr /Applications/Mooziac.app` and System Settings "Open Anyway").
   * Complete uninstallation pathways (`~/Library/Application Support/Mooziac/`, `~/Library/Caches/`, `~/Library/Preferences/site.threeten.mooziac.plist`).
   * Window closing behavior (red button hides UI while audio continues in the menu bar; Cmd+Q to quit).
   * Menu Bar Only Mode (`ActivationPolicy.accessory`) to completely hide the macOS Dock icon.

3. **Trackpad Edge Volume & Corner Gestures (`EdgeVolumeEngine.swift`):**
   * Private dynamic linking to `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport` (zero accessibility/input monitoring permissions required).
   * Extreme right edge 2.5mm zone (normalized x >= 0.982), starting in the top 30% (y >= 0.70).
   * Vertical movement deadzone of >= 3.0mm to prevent accidental activation during typing.
   * Full travel scale of 160mm mapping to 0%–100% volume.
   * Bottom corners (y <= 0.15): Bottom-right 2 taps (Next Track), 3 taps (Previous Track); Bottom-left 2 taps (Play/Pause), 3 taps (Toggle Notch Lyrics HUD). Remappable to 16 actions in Settings.
   * Hardware boundaries: Strictly requires built-in MacBook trackpad or Apple Magic Trackpad; does not trigger on USB/Bluetooth mice or Magic Mouse.

4. **Audio Engine, Volume & Loudness Normalization:**
   * Supported local codecs: FLAC (lossless), MP3, WAV (lossless), AAC, M4A, AIFF (lossless), AIF, OGG, and OPUS up to 24-bit/192kHz.
   * Dual volume modes: "System Sound" (manipulating macOS CoreAudio master output via `AudioObjectSetPropertyData`) versus "Focus Audio" / "Separate App Sound" (adjusting WebKit and AVPlayer gain independently).
   * Loudness Normalization: Target -14 LUFS with smooth 250ms cosine volume easing transitions to prevent jarring jumps between tracks.
   * Headphone disconnect protection (`AudioRouteMonitor.swift`): Automatically pauses playback upon `kAudioHardwarePropertyDefaultOutputDevice` changes.

5. **Multi-Tier Synced Lyrics Pipeline (`LyricsManager.swift`):**
   * Tier 0: Local `.lrc` sidecar files in audio folder and `~/Music/Mooziac/`.
   * Tier 0.5: Local disk cache in `~/Library/Caches/Mooziac/Lyrics/` (verified via `[ti:...]` tag similarity).
   * Tier 0.8: YouTube Music InnerTube synchronized lyrics endpoint.
   * Tier 1.0–3.0: LRCLib API (exact track duration match -> query search -> fuzzy title search).
   * Tier 4.0: Plain text fallback spaced every 4.0s.
   * Display HUD (`CenteredMenuBarLyricsWindowController.swift`): Floating borderless pill panel anchored directly below the MacBook display notch or menu bar.

6. **YouTube Music Streaming & Offline Downloads:**
   * WKWebView container running desktop Safari User-Agent to permit Google account login without embedded-browser phishing blocks.
   * SQLite persistent storage for Liked Songs, personal playlists, and listening history (`LocalDatabaseManager.swift`).
   * Automated download helper: `DependencyManager.swift` auto-downloads standalone `yt-dlp` binary into `~/Library/Application Support/Mooziac/bin/yt-dlp` with `chmod +x` (no Homebrew/Python required).
   * Default download destination: `~/Music/Mooziac/` (customizable in Settings).

7. **Discord Rich Presence (`DiscordRPCManager.swift`):**
   * Native pure-Swift Unix domain socket IPC (`/tmp/discord-ipc-0` through `/tmp/discord-ipc-9`).
   * Application Client ID: `1537169013174435870`.
   * Broadcasts track title, artist, album art, elapsed time, and total duration without any Node.js/Python daemons.

8. **Themes & Progress Bar Customization:**
   * 4 Themes: OLED Dark Mode (`#000000` true black), Adaptive Ambient (color palette extracted from album art), Pure Crystal Glass (1.2px `#B3B8B5` rim stroke), Watery Pure Transparent (macOS NSVisualEffectView vibrancy).
   * 4 Progress Bars: Waveform (32-bar reactive wave), Neon Glow (liquid capsule scrubber), Cyber Dots (retro pulsing LED matrix), Minimal Line (zero-overhead 2px precision line).

---

## 3. Natural Language Variety & Colloquialisms

To ensure that the future local SLM does not falter when encountering real-world human phrasing, the dataset explicitly trains on colloquial speech, slang, typing shortcuts, typos, and frustrated user inputs:

### Exact User Phrases Included
* *“how do I make this louder”* -> Addressed via volume modes and -14 LUFS loudness normalizer explanation.
* *“yo why aren’t my lyrics showing”* -> Addressed via multi-tier fallback, metadata cleaning, and local `.lrc` sidecars.
* *“where did my downloaded song go”* / *“bro where did my music go”* -> Addressed via `~/Music/Mooziac/` path and Finder shortcuts.
* *“can I use this without internet”* / *“can I listen offline”* -> Confirmed offline playback for local and downloaded files.
* *“does this work with flac”* / *“does this support flac files?”* -> Confirmed native 24-bit bit-perfect FLAC decoding via AVFoundation.
* *“why isn’t my track playing”* / *“my song isn’t playing”* -> Addressed via missing file paths, DRM files, or headphone disconnect auto-pause.
* *“how do I get this thing out of the menu bar”* -> Addressed via Menu Bar settings and Dock accessory mode toggles.
* *“why is my volume gesture not working”* / *“why tf is the volume gesture not working”* -> Clarified top 30% entry zone, rightmost 2.5mm, 3.0mm movement deadzone, and trackpad hardware requirement.
* *“can I use my own music”* -> Addressed via `Add Music Folder…` (Cmd+O) and local SQLite library indexing.
* *“does this work on an intel mac”* -> Confirmed Universal 2 native x86_64 architecture slice.
* *“why does macOS say it can’t verify the developer”* -> Addressed with Gatekeeper quarantine context and `xattr -cr` command.
* *“how do I uninstall it”* / *“how to get rid of it”* -> Provided complete deletion paths for `Application Support`, `Caches`, and `Preferences`.
* *“can I import my playlist”* -> Clarified automatic YouTube Music sync vs local music folder import.
* *“why is discord not showing what I’m listening to”* -> Addressed Discord desktop client requirement, `/tmp/discord-ipc-0` socket, and Activity Privacy settings.
* *“it downloaded but I can’t find it”* -> Clarified difference between browser downloads and `~/Music/Mooziac/`.
* *“what formats does it take”* -> Complete list: FLAC, MP3, WAV, AAC, M4A, AIFF, AIF, OGG, OPUS.
* *“it just stopped working”* / *“how do I fix this”* -> Guided diagnostic procedures in multi-turn conversations.

---

## 4. Audit of Sources Used

The dataset was generated from a rigorous multi-source audit:

1. **Primary Ground Truth: Local Codebase (`Sources/Mooziac/`)**
   * Services: `EdgeVolumeEngine.swift`, `AppVolumeManager.swift`, `VolumeController.swift`, `LyricsManager.swift`, `SyncedLyricsParser.swift`, `DownloadManager.swift`, `DependencyManager.swift`, `LocalLibraryManager.swift`, `LocalDatabaseManager.swift`, `DiscordRPCManager.swift`, `NowPlayingManager.swift`, `GlobalHotKeyManager.swift`, `UpdateManager.swift`.
   * UI: `CenteredMenuBarLyricsWindowController.swift`, `StatusItemManager.swift`, `SettingsPanel.swift`, `ThemeManager.swift`, `ProgressBarStyles.swift`, `YTMWebView.swift`, `QueueViewController.swift`, `KeyboardCommandHandler.swift`, `MainWindowController.swift`, `AppDelegate.swift`.
   * Audio: `AudioEngine.swift`, `LoudnessNormalizer.swift`, `AudioRouteMonitor.swift`, `LocalAudioMetadataParser.swift`.
   * Build & Config: `Package.swift`, `build_app.sh`, `Mooziac.entitlements`.

2. **Documentation & Policy Files:**
   * `README.md`: Architecture overview, installation, memory benchmarks, system requirements.
   * `CHANGELOG.md`: Complete release history (v1.0.0 through v1.1.7).
   * `SECURITY.md`: Privacy statement, zero telemetry confirmation, local database architecture.
   * `docs/UNINSTALL.md`: Filesystem removal instructions.

3. **Web & Community Data:**
   * Official Website (`https://mooziac.threeten.site`): Marketing descriptions, visual feature names.
   * Support Tickets (`www/support_tickets.json` & `www/support.html`): User queries, recurring points of confusion.
   * GitHub Issues Tracker (`github.com/shirkeharsh/mooziac/issues`): Issues #1 through #6 covering fixed bugs and open requests.
   * Reddit Discussions: Mac community feedback on trackpad edge ergonomics and lightweight memory footprint.

---

## 5. Conflicting Information Found & Resolutions

During dataset collection and codebase cross-referencing, several discrepancies across documentation, historical changelogs, and user expectations were identified and resolved:

| Conflicting Area | Source A (Doc / User Expectation) | Source B (Codebase Ground Truth) | Resolution & Ground Truth Adopted |
| :--- | :--- | :--- | :--- |
| **Menu Bar Volume Scrolling** | Issue #6 reported volume scroll was broken or unresponsive. | Fixed in `StatusItemManager.swift` (v1.1.7) using discrete 6pt trackpad / notch accumulator. | Dataset records this as a resolved bug: v1.1.7+ works smoothly; earlier versions had the bug. |
| **Spacebar in Search Inputs** | Issue #5 reported Spacebar paused songs while typing search terms. | Fixed in `KeyboardCommandHandler.swift` (v1.1.7) with first-responder check on `WKWebView` text inputs. | Dataset clarifies this was an early bug resolved in v1.1.7+. |
| **macOS 27 Beta Theme Contrast** | White-on-white text reported on macOS 27 beta in Adaptive Mode. | Resolved in `SettingsPanel.swift` (v1.1.1) by enforcing `.dark` semantic tone. | Flagged as fixed in v1.1.1; model is taught to recommend updating or switching to OLED mode. |
| **Mac App Store Availability** | Some users expect to install Mooziac via Mac App Store or Sandboxed Homebrew. | Codebase uses private `MultitouchSupport` linking and direct `/tmp/discord-ipc-0` sockets. | App Store distribution is impossible without breaking core features. Dataset explicitly clarifies why it is distributed as DMG. |
| **Playlist File Export** | Users ask to export playlists to `.m3u8` or `.json`. | Playlists are stored solely in local SQLite database; Issue #3 is an open feature request. | Feature classified strictly as `planned` / `Issue #3`, not as an existing capability. |
| **Custom Hotkey Rebinding** | Users assume shortcuts can be remapped in Settings GUI. | Global hotkeys are hardcoded in `GlobalHotKeyManager.swift`; Issue #2 is an open request. | Feature classified strictly as `planned` / `Issue #2`. |
| **Graphic Equalizer** | Users expect a 10-band EQ or bass booster like other players. | `AudioEngine.swift` renders bit-perfect audio with -14 LUFS loudness normalizer; no EQ exists. | Explicitly classified as `requested` (unimplemented). Model recommends eqMac/SoundSource as temporary workaround. |

---

## 6. Missing Information & Unaddressed Gaps

1. **YouTube Music InnerTube Encryption Shifts:**
   * Google periodically modifies internal InnerTube API signatures and WebKit DOM selectors. While `DependencyManager.swift` keeps `yt-dlp` updated, sudden YouTube streaming format updates can temporarily disrupt downloads until `yt-dlp` publishes an upstream patch.
2. **Multi-Display Desktop Space Switching:**
   * While `CenteredMenuBarLyricsWindowController` dynamically docks to the active `NSScreen`, rapid Mission Control space-switching across mixed-DPI external monitors can occasionally experience a single-frame reposition lag.
3. **Audio Tag Modification:**
   * Users frequently ask to edit song titles or embedded album artwork directly within Mooziac. The codebase currently only extracts metadata via `AVAsset` and does not write ID3/Vorbis tags.

---

## 7. Potential Hallucination Risks for Small Language Models (SLMs)

When fine-tuning small parameter language models (e.g. 1B to 8B parameter models), specific guardrails must be preserved to avoid common failure modes:

1. **Hallucinating Generic Music Player Features:**
   * *Risk:* The SLM may assume Mooziac supports Spotify Connect, Apple Music streaming, Tidal Masters, or a 10-band graphic equalizer simply because it is a "music player".
   * *Mitigation:* `08_mooziac_limitations.json` and `04_mooziac_features.jsonl` explicitly enumerate unsupported streaming platforms and missing EQ features.
2. **Hallucinating Hardware Compatibility for Gestures:**
   * *Risk:* The SLM might tell a user that edge volume works by dragging the mouse pointer or using a Logitech mouse wheel.
   * *Mitigation:* The dataset stresses that `EdgeVolumeEngine.swift` requires raw Apple Multitouch digitizer frames, strictly limiting the gesture to built-in MacBook trackpads and Apple Magic Trackpads.
3. **Conflating System Sound with App Focus Audio:**
   * *Risk:* The SLM might confuse Mooziac's dual volume modes, advising users that edge volume always changes macOS system volume.
   * *Mitigation:* Multiple Q&A and knowledge facts define the exact difference between CoreAudio Master Volume and internal WebKit/AVPlayer gain.
4. **Assuming Windows or Linux Compatibility:**
   * *Risk:* The SLM might generate Linux `apt-get` or Windows `.exe` installation instructions.
   * *Mitigation:* Dataset reinforces macOS 13.0+ exclusivity across all files.

---

## 8. Recommended Next Data Collection Steps

1. **Continuous Scraping of GitHub Releases & Issues:**
   * Implement a GitHub Action or local hook that monitors `shirkeharsh/mooziac` for newly closed issues and releases (e.g. when Issue #2, #3, or #4 are merged) to transition them from `planned` to `current` in `04_mooziac_features.jsonl`.
2. **Anonymized Support Query Harvesting:**
   * Periodically export user submissions from `www/support_tickets.json` to extract newly emerging slang, edge-case hardware setups (e.g. multi-monitor USB-C hubs, external DAC configurations), and novel bug reports.
3. **Multilingual Query Augmentation:**
   * If Mooziac expands internationally, translate natural question variations into French, German, Spanish, Japanese, and Mandarin while retaining exact English technical paths (e.g. `~/Music/Mooziac/`, `xattr -cr`).
4. **Direct Fine-Tuning Formatting:**
   * Prior to fine-tuning, compile `02_mooziac_qa.jsonl` and `06_mooziac_conversations.jsonl` into standard ChatML, Llama-3-Instruct, or Gemma-2-IT format with a specialized Mooziac Support system prompt.

---
*Report generated and validated autonomously against the live Mooziac codebase on 2026-09-29.*
