# Config Files

Every configuration file in the repo and what it controls.

## Repository files

| File | Purpose | Format |
| :--- | :--- | :--- |
| `Package.swift` | SPM package: name `Mooziac`, macOS 13+, executable target `Mooziac`, **zero external dependencies**, path `Sources/Mooziac` | SwiftPM |
| `build_app.sh` | Full pipeline: release build → `.app` bundle → ad-hoc sign → launch | bash |
| `.gitignore` | Excludes `.build/`, `.DS_Store`, secrets (`client_secret*.json`, `*.secret.json`, `credentials.json`), `dev/` | gitignore |
| `AGENTS.md` | agent guidance: build commands, source layout, conventions | markdown |
| `AGY.md` | supplementary guidance | markdown |
| `CHANGELOG.md` | feature history | markdown |
| `README.md` | user-facing intro | markdown |
| `LICENSE` | licensing | text |
| `Resources/` | runtime assets (see `02_CODEBASE/ASSET_MAP.md`) | png/jpg/html/icns |

## Application runtime configuration

| Config | Mechanism | Owner |
| :--- | :--- | :--- |
| All user settings | `UserDefaults` (38 keys) | managers/views |
| Offline music folder | `YTM_downloadsFolder` (default `~/Music/Mooziac`) | DownloadManager/LocalLibraryManager |
| Player design | `YTM_playerDesign` | MainViewController |
| Progress style | `YTM_progressStyle` | ProgressStyleManager |
| Engine flags | `YTM_isEdgeEngineEnabled`, `YTM_isRightEdgeVolumeEnabled`, `YTM_isRightCornerTapsEnabled`, `YTM_isLeftCornerTapsEnabled` (+`YTM_v3_` variants) | EdgeVolumeEngine/MainViewController |
| Centered lyrics | `YTM_isCenteredLyricsEnabled` | MainViewController |
| Discord | `YTM_discordRPC_enabled` | DiscordRPCManager |
| Window geometry | `YTM_playerFrameX/Y`, `YTM_playerTopY`, `YTM_savedDisplayID`, `YTM_isDraggedFromDock` | StatusItemManager |
| Session | `YTM_last*` keys | NowPlayingManager/YTMWebView |
| Auto-pause | `YTM_isAutoPauseOnDisconnectEnabled` | AudioRouteMonitor |
| Init flags | `YTM_hasInitializedDefaultSettingsV2`, `YTM_hasLoggedInOnce` | AppDelegate |

## Bundled runtime assets (embedded, not config files)

| Asset | Consumer |
| :--- | :--- |
| `trackpad.html` + `macbook_panel.jpg` | trackpad gesture demo (coupled pair — keep together) |
| `AppIcon.icns`, `MOOZIAC_transparent.png`, `MOOZIAC.png`, `launch_transparent.png`, `MenuBarIcon.png`/`@2x` | branding/UI |

## Generated at runtime

| File | Location | Owner |
| :--- | :--- | :--- |
| `library.sqlite3` (+wal/shm) | `~/Library/Application Support/Mooziac/` | LocalDatabaseManager |
| Lyrics cache | `~/Library/Caches/Mooziac/Lyrics/` | LyricsManager |
| Thumbnails cache | `~/Library/Caches/Mooziac/Thumbnails/` | AppArtworkHelper |
| Temp notification art | `<tmp>/ytm_art_*.jpg` | TrackNotificationManager |
| `.downloading/` sandbox | inside music folder | DownloadManager |

## Related

- `11_CONFIGURATION/BUILD_CONFIGURATION.md`, `ENVIRONMENT.md`, `DEPENDENCIES.md`.