# Changelog

All notable changes to Mooziac are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.2.6] - 2026-11-28

### Added
- Unified Google Session & Account Menu: Shared sign-in across both YouTube Music and YouTube Mode (`WKWebsiteDataStore.default()`), with an organized Account & Sync menu showing signed-in identity, Sign In / Sign Out, YouTube Music sync, and a Scrobbling submenu.
- Full YouTube Music Two-Way Playlist Sync: Syncs remote YouTube Music playlists into the player, creates playlists from local tracks/folders, updates metadata/privacy, deletes playlists locally or from YouTube Music, and supports move/reorder operations plus WebView-backed SAPISID/internal API requests.
- Local Songs Folder Playlists: Import any local music folder directly as a named playlist (using the folder name instead of placing tracks into Downloads), renameable and editable afterward.
- Playlist Organization & Smart Playlists: Added playlist folders, smart playlists, custom sort modes (Custom, Title, Artist, Duration, Date Added), cover/description/privacy editing, Duplicate & Merge actions, batch multi-select actions, and M3U8/JSON import & export.
- YouTube Mode Shorts & Offline Playlists: Added a Shorts button to the YouTube Mode header bar, plus YouTube Mode playlist queue playback (Play All / Shuffle Play), track reordering/removal, saved-video search, and M3U8/JSON import & export.
- Quick Controls Ad Blocker Toggle: Added an Ad Blocker toggle directly in the Music Player Quick Controls menu and defaulted Ad Blocker to OFF when signed in so users can re-enable it as needed.
- Automatic yt-dlp Helper Installation: Added automatic yt-dlp helper installation and expanded binary lookup paths with MP4/M4A format fallback selectors for YouTube downloads.

### Improved
- Playback Reliability: Improved play/toggle-play/skip logic to check whether a video ID is loaded, resolve DOM watch cards, and prompt users to finish Google sign-in if `accounts.google.com` is open.
- PiP Window Restoration: Minimizing YouTube Mode while Picture-in-Picture is active keeps the host window alive transparently so macOS's "Return to Window" button and menu bar toggles reliably restore the player window.

### Fixed
- Music Autoplay When Opening YouTube Mode: Removed the hidden YouTube Music WKWebView reload from `MainVideoWindowController.checkAuthenticationStatus()` and guarded `YTMWebViewContainer` `didFinish` loads during YouTube Mode so Mooziac stays paused when switching to YouTube.
- Single-Account Schema Consolidation: Consolidated local and YouTube SQLite tables back to clean single-account schemas without losing existing liked songs, playlists, folders, or history.

## [1.2.5] - 2026-11-25

### Added
- Scrobbling Controls: Added native toggles for Last.fm and ListenBrainz in Quick Controls (right-click menu) with instant account connect and disconnect options.
- Smart Scrobble Engine: Automatically cleans YouTube video clutter from track titles, ignores ads and early skips, and retries failed scrobbles when back online.
- Launch at Login Toggle: Added a native toggle in Quick Controls that syncs directly with macOS Login Items.

### Improved
- Lyrics Text Contrast: Added subtle black border outlines to lyrics in the Hero visual stage for sharp readability across bright album covers.
- Window Dragging: Smoothed out window movement to prevent edge outline jitter and flickering while repositioning the player.
- Player Sizing & Transitions: Refined Hero view heights (176 pt idle / 304 pt with controls) and fixed browser view resets when exiting video playback.

### Security
- Cloudflare Serverless Proxy: Last.fm authentication and signing are routed through Cloudflare Pages proxy (https://mooziac.pages.dev/api/lastfm), eliminating hardcoded API keys and secrets from the client.

## [1.2.4] - 2026-11-23

### Added
- Global Shortcuts Toggle: Added native toggle in Quick Controls (menu bar right-click menu) to easily enable or disable system-wide media shortcuts (e.g. `Control + Option + Right Arrow`, `Cmd + Shift + Space`).
- Borderless Hero Player: Immersive borderless player mode with edge-to-edge album artwork presentation and auto-hiding playback controls during idle listening.
- Interactive Artwork Toggle: Click directly on the album artwork in the player to effortlessly expand and collapse the Hero Player visual stage.
- Up Next Queue & Alerts: Live interactive Up Next queue management with drag reordering, track removal, playlist saving, and menu bar alerts for upcoming songs.
- Instant Video Search (/): Prefix any search query with / (e.g. / Starboy or / Bohemian Rhapsody) to instantly search and play the official video directly in the video window.
- 3D Dynamic Lyrics Stage: Multi-layered perspective lyrics experience with tuned Gaussian background blur and crystal-clear text contrast.
- Automated Test Suite: Added automated unit tests for menu bar title truncation, hero player layout, artwork blur caching, and waveform theming.

### Changed
- Waveform Progress Theme Styling: Frosted glass theme now features refined greyish unplayed track bars and enhanced played contrast for crisp visibility in light and dark modes.
- Menu Bar Title Truncation: Long song titles exceeding 30 characters in the macOS menu bar are gracefully truncated with `...` to prevent crowding status bar icons.

## [1.2.3] - 2026-11-21

### Added
- Mini-Player Live Search: Integrated live YouTube Music search results directly into the dynamic search field with debounced autocomplete and instant track playback.
- Optimistic Track Updates: Dynamic Island mini-player UI updates metadata in under 16ms on skips without waiting for network buffering.

### Changed
- Context Menu Layout: Promoted "Pin Player on Top", "Focus Audio", "Prevent Wake Auto-Play", and "Hide Mooziac Branding" to the very top of the menu bar right-click menu.
- Native Text Alignment: Adjusted capsule toggle label margins from 21pt to 14pt, achieving pixel-perfect alignment with standard macOS menu items.
- Focus Audio Relocation: Extracted "Focus Audio" from the Trackpad Gestures submenu and placed it alongside primary player toggles.

### Improved
- In-Place SPA Navigation: Replaced full web page reloads with in-place client navigation (`resolveCommand`), eliminating queue conflicts and audio stuttering during track changes.
- YouTube Ad Suppression: Updated ad element filtering and video preroll skipping rules.
- Headless Build Pipeline: Added headless environment detection to `build_app.sh` and CI workflows to prevent Finder AppleScript freezes during DMG creation.

## [1.2.2] - 2026-11-15

### Added
- Wake Auto-Play Suppression: Added an option to prevent playback from automatically starting when waking your Mac from sleep or unlocking after idle.
- Discord Status Customization: Added settings to hide Mooziac branding and interactive buttons in Discord Rich Presence.
- Community & Support Prompt: Added a native Bento Grid prompt to Star on GitHub, Buy Me a Coffee, or access the Support portal with a 14-day local snooze.

### Changed
- Settings Control Styling: Modernized capsule toggles and step switches with improved theme baseline alignment and hover feedback.

### Fixed
- IME & Accent Popup Layering: Adjusted panel window ordering so Chinese and Japanese candidate lists and accent key hold popups appear above the search bar.
- Search Shortcut Interception: Prevented global player hotkeys (such as "M" for mute) from firing while typing in the search field.
- Mini-Player Track Selection: Resolved search dropdown click race conditions and eliminated millisecond audio overlap during track switches.
- Artwork Cache Synchronization: Resolved an issue where album artwork could fail to load during rapid track navigation.

## [1.2.1] - 2026-10-30

### Added
- Auto-Hiding Fullscreen Overlay: Header bar floats over fullscreen video playback and auto-reveals on top-edge hover or cursor proximity.
- Window Fullscreen Shortcut: Added Control+Command+F shortcut to toggle standard macOS window fullscreen mode independently of player video fullscreen.
- Multi-Space Picture-in-Picture: Added setting and notification support to keep picture-in-picture windows floating across all macOS desktop spaces.
- Live Caption Integration: Added caption state tracking and bridge telemetry to the video playback model.

### Changed
- Dynamic Sleep Prevention: Replaced persistent system sleep prevention on launch with state-driven assertions that engage only during active audio or video playback.
- Status Item Click Toggle: Left-clicking the status item in YouTube mode now toggles the window between frontmost and hidden.
- DOM Mutation Optimization: Streamlined element classification for modal and toast overlays to eliminate redundant tree walks and lower CPU usage during long playback sessions.
- Quality Badges: Standardized video quality selector labels to AUTO, SD, HD, FHD, 2K, and 4K.
- Default Download Folder: Set default video download location to ~/Downloads/MooziacTube.

### Fixed
- SQLite String Deallocation Crash: Replaced raw pointer bindings with SQLITE_TRANSIENT across all prepared statements in YouTubeDatabaseManager.
- Double Volume Attenuation: Fixed an issue where web volume was reduced in addition to macOS system volume adjustments.
- Keyboard Shortcut Focus Stealing: Added strict key window checks to prevent shortcut interception while typing in other windows or text inputs.
- Playback Command Routing: Restricted MPRemoteCommandCenter media key handlers strictly to the active player mode.
- Download Cancellation Alert: Suppressed erroneous failure alerts when downloads are intentionally cancelled by the user.

## [1.2.0] - 2026-10-21

### Added
- Native YouTube Video Player: Added dedicated YouTube video viewing mode with seamless switching between the menu bar music player and the standalone video window.
- VideoToolbox Hardware Decode: VideoToolbox hardware decode preference with VP9 and H.264 optimization, reducing power draw to ~2.8W and lowering CPU cluster load.
- Distraction-Free Playback & SponsorBlock: Embedded declarative content styling and clutter filtering rules alongside automatic SponsorBlock segment skipping.
- Fullscreen & Playback Hotkeys: Native fullscreen toggle via F key, playback seeking via J/K/L, speed adjustment via [ / ], and timestamped URL copying via Cmd+Shift+C.
- Unit Test Suite: Added test coverage for video quality levels, thermal defaults, video playback state calculations, shorts URL extraction, and settings notifications.

### Changed
- Thermal & Battery Optimization: Eliminated status item animation CPU spin, disabled unnecessary high-frequency mouse tracking, and defaulted playback quality to 1080p Full HD for cool running on Apple Silicon and Intel Macs.
- Trackpad Edge Volume Continuity: Unified edge volume sliding across music and video playback with continuous CoreAudio volume tracking and physical haptic feedback.
- Clean Text Alignment: Removed non-standard emojis and symbols across menus and documentation for uniform left alignment.

## [1.1.8] - 2026-09-29

### Added
- **Fluid Circular Download Animation**: Integrated GPU-accelerated Core Animation for real-time, buttery-smooth progress tracking during track downloads.
- **Stage-Aware Download Progress**: Granular progress reporting across network downloading, audio conversion, and metadata/lyrics finalization to eliminate progress stalls.
- **Help & Support Menu Item**: Added quick access to the Mooziac Support portal directly from the menu bar context menu.

### Changed
- **Redesigned Settings Footer**: Clean minimal 3-column utility bar featuring `Git Star` (aligned under preferences), a centered version badge (`v1.1.8`), and `Support` (Buy Me a Coffee).
- **Theme-Adaptive Utility Styling**: Standardized typography, baseline alignment, and interactive hover highlights across all player appearances.

### Fixed
- Fixed download button progress skipping and premature state resets during post-processing.

## [1.1.7] - 2026-09-21

### Added
- Menu bar status item scroll wheel and trackpad gesture support to adjust volume directly across all spaces and active applications.
- Smooth menu bar status icon fadeout animation (0.22s ease-out) when quitting from the context menu.
- Loudness metadata prefetching and in-memory caching for seamless track transitions.

### Changed
- Compacted menu bar track titles and artists to 15 characters with ellipsis (`...`) to prevent menu bar overcrowding while keeping continuous display active.
- Universal 2 build pipeline with architecture-isolated scratch compilation directories (`.build/arm64` and `.build/x86_64`) and automated cache purging.

### Fixed
- Fixed loudness leveling volume surge on track change by removing unnormalized volume resets, correcting decibel normalization conversion math, and adding smooth 250ms cosine volume easing.
- Replaced the confirmation dialog on quit with instant, clean process termination and zero orphaned background processes.
- Prevented spacebar play/pause hotkey interception when typing into web search inputs, comments, and text fields.

## [1.1.6] - 2026-09-17

### Added
- Multi-tier hotkey seeking: hold Option for 15-second jumps or Shift for 30-second jumps using Left/Right arrow keys.
- Trackpad gesture mapping options for 15-second and 30-second forward and backward seeking.
- Smart track advancement when seeking within 1.5 seconds of a track's end.
- Loudness Leveling toggle integrated directly into Player Preferences.
- Focus Audio toggle integrated into Trackpad Gesture Settings under the Trackpad Master toggle.
- Buy Me a Coffee support action in the update manager dialog.
- Unit test suite coverage for gesture actions, variable seek durations, and queue transitions.

### Changed
- Relocated Focus Audio toggle from Player Preferences to Trackpad Gesture Settings.
- Centered Menu Bar Lyrics now update instantly with zero flying or sliding animations.
- Redesigned in-app software update dialog with improved typography, layout alignment, and persistent support actions.

### Fixed
- Preserved playlist queue context and active anchor track when advancing between songs.
- Prevented unlinked state shifts during rapid track transitions.

## [1.1.5] - 2026-09-08

### Added
- Unit test suite (`MooziacTests`) covering download URL extraction, queue persistence, synced LRC lyrics parsing, and query filters.
- Continuous Integration workflow (`.github/workflows/ci.yml`) running headless debug and release builds and parallel unit tests on macOS 14 runners.
- Apple Unified Logging (`os.Logger`) across network, database, audio, lyrics, and lifecycle subsystems.

### Changed
- Refactored `SettingsPanel` (4,790 lines) and `PlaylistLibraryView` (3,706 lines) into focused, modular components.
- Reduced singleton footprint from 31 to 24 core services, migrating private helpers to dependency injection.
- Audited all silent error sites (`try?`) with structured do-catch blocks and diagnostic logging.
- Cleaned and updated documentation with accurate architectural maps and zero promotional hype.

### Removed
- Dead build target configurations and unused icon and graphic assets.

## [1.1.4] - 2026-09-08

### Added
- Floating Synced Menu Bar Lyrics HUD with instant song transitions, ad metadata suppression, and multi-script support.

### Changed
- Background playback engine with continuous Web Audio keepalive to prevent WebKit process throttling during menu bar interactions.
- Forced high-bitrate stream selection (256 kbps AAC / 160 kbps Opus) with real-time stream diagnostics.
- Playlist and queue reliability improvements for autoplay recovery and metadata synchronization.
- Search bar animation transitions refined to eliminate horizontal flicker during expansion.
- In-app update dialog decoupled from GitHub star button.

## [1.1.3] - 2026-09-07

### Fixed
- Fixed lyric persistence bug where offline LRC lyrics remained active after switching to online playback.
- Decoupled LRC sidecar files strictly to offline playback mode to avoid cross-engine state contamination.
- Reduced lyric synchronization drift and increased WebKit observer polling frequency to 4 Hz when HUD is visible.

## [1.1.2] - 2026-09-03

### Changed
- Reduced idle CPU usage to under 0.4% by allowing WebKit rendering engines to enter low-power sleep when playback is paused.
- Reduced active playback CPU usage by approximately 50%.

### Fixed
- Resolved recursive sync loop in `PlaylistSyncManager` on network errors or expired session tokens.
- Graceful network error handling during playlist sync, preserving local database state for subsequent cycles.

## [1.1.1] - 2026-09-01

### Added
- Dynamic light and dark mode appearance switching with real-time theme updates.
- Refined contrast rims and search field focus borders across glass and liquid themes.
