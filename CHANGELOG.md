# Changelog

All notable changes to Mooziac are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
