# Environment

Runtime and build environment requirements.

## Minimum environment

| Requirement | Value |
| :--- | :--- |
| macOS | 13.0+ (Ventura) — `Package.swift` platform |
| Swift | 5.9+ toolchain (`swift-tools-version: 5.9`) |
| Xcode | any that ships Swift 5.9 (CLI `swift` suffices) |
| Architecture | Apple Silicon / Intel (single universal-less build) |
| System tools (runtime) | `yt-dlp` + `ffmpeg` on `PATH` for downloads |
| Display | menu bar + notification center (LSUIElement app) |

## App characteristics

| Attribute | Value |
| :--- | :--- |
| Bundle id | `com.local.Mooziac` |
| UI element | `LSUIElement = true` (menu-bar app, no Dock icon) |
| URL scheme | `mooziac://` (declared in Info.plist) |
| Sandbox | not sandboxed (full user access) |
| Signature | ad-hoc (`codesign --force --deep --sign -`) |

## Runtime data environment

| Path | Purpose |
| :--- | :--- |
| `~/Library/Application Support/Mooziac/` | SQLite DB |
| `~/Library/Application Support/Mooziac/Offline/` | downloaded audio (default) |
| `~/Music/Mooziac/` | user music folder (default; `YTM_downloadsFolder`) |
| `~/Library/Caches/Mooziac/Lyrics/` | lyrics cache |
| `~/Library/Caches/Mooziac/Thumbnails/` | artwork cache |
| `/tmp` | transient notification artwork |
| `/tmp/discord-ipc-0…9` | Discord presence socket |

## Environment branches in code

| Condition | Branch |
| :--- | :--- |
| Network available/offline | `NetworkMonitorStatusChanged` → engine mode, download gating |
| Screen locked/unlocked | pause/resume |
| System sleeping | `isSystemSleeping` + pause |
| Display ID change | window re-anchor to saved display |
| yt-dlp/ffmpeg missing | download jobs fail (startup warning path) |
| Discord running | presence on; else silent no-op |

## Dev workflow

```bash
swift build            # debug
swift build -c release # release
./build_app.sh         # full pipeline → ~/Applications/Mooziac.app → launch
```

- `build_app.sh` kills old processes (`Mooziac`, legacy `YTMMenuBar`), rebuilds, assembles bundle by hand, copies assets from `Resources/`, writes Info.plist, ad-hoc signs, launches.
- **Caveat:** bundle copies assets **only from `Resources/`** — any new asset must be added to the script's copy block.

## Related

- `11_CONFIGURATION/BUILD_CONFIGURATION.md`, `CONFIG_FILES.md`.