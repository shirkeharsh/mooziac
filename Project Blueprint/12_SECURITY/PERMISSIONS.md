# Permissions

macOS permissions Mooziac requests (or avoids).

## Sandbox / entitlements

- **No App Sandbox** entitlement — the app has full user-level filesystem access.
- **No entitlements file** exists in the repo; ad-hoc signing (`codesign --force --deep --sign -`) adds none.
- Consequences:
  - Full read/write to user home (music folder, App Support, Caches).
  - Network unrestricted (no `com.apple.security.network.client` needed since not sandboxed).
  - No TCC prompts triggered by the app itself.

## TCC-sensitive capabilities

| Capability | Used? | How |
| :--- | :--- | :--- |
| Camera / Microphone | ❌ | none |
| Location | ❌ | none |
| Contacts / Calendar / Photos | ❌ | none |
| Input monitoring (Accessibility) | ❌ (INDIRECT) | **does not request** — relies on active-window key events; global hotkeys may not fire when another app is focused (see risk B30) |
| Screen recording | ❌ | none |
| File access (Downloads/Documents/Desktop) | ⚠ (UNCERTAIN) | reads `~/Music` + App Support; if the default music folder were under a TCC-protected location, the OS would prompt — current default is `~/Music/Mooziac` (user-owned, generally accessible) |
| Notifications | ✅ (requested) | `UNUserNotificationCenter` for track-change notifications |

## Runtime permission checks in code

- Notification permission: requested when track notifications are enabled (`TrackNotificationManager`).
- No `AXIsProcessTrusted` / accessibility prompts found.
- No `CNCopySupportedServices` / contact framework usage.
- Hotkey handling relies on `NSEvent.addGlobalMonitorForEvents` — requires **Input Monitoring** permission in the user's System Settings on modern macOS to receive events while another app is focused; the app itself does not request it (`UNKNOWN — requires runtime verification` whether it prompts).

## Privacy-preserving posture

- `LSUIElement = true` → no Dock icon, minimal footprint.
- No telemetry/crash reporting SDKs.
- No analytics.

## Related

- `12_SECURITY/PRIVACY.md`, `10_BACKGROUND_SYSTEMS/SYSTEM_INTEGRATIONS.md`.