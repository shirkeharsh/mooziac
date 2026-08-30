# Audio Architecture

Two independent playback engines coordinate through `NowPlayingManager.shared.engineMode`. This document covers the audio layer (`Sources/Mooziac/Audio/`) and its relationships.

## Engine overview

| | Online engine | Offline engine |
| :--- | :--- | :--- |
| Media source | YouTube Music web (WebKit) | Local files (`~/Music/Mooziac`, `Offline/`) |
| Audio playback | WebKit's media stack (in WebContent process) | `AVPlayer` (in app process) |
| Driver | JS injection into YTM page (`ObserverBridge`, `PlayerControls`) | `NativeAudioPlayer` |
| Control path | `evaluateJavaScript` | direct Swift calls |
| State source | `nowPlayingHandler` JS messages | `broadcastPlaybackState` (0.25 s periodic) |
| Formats | any YTM stream | mp3, m4a, flac, wav, aac, ogg, opus |

## Files

| File | Responsibility |
| :--- | :--- |
| `NativeAudioPlayer.swift` (442) | Offline AVPlayer engine: queue, shuffle, repeat, seek/ff/rw, volume, like, end-of-track handling, time broadcast, system-Now-Playing artwork |
| `EdgeVolumeEngine.swift` (520) | Private-Multitouch right-edge volume engine (`VolumeController`, `ActiveEngineBox`) |
| `AppVolumeManager.swift` (101) | System↔app volume mapping; per-app volume mode; muted-state handling; overlay toasts |
| `AudioRouteMonitor.swift` (126) | CoreAudio output-device-change listener; auto-pause on disconnect; lock/sleep pause |
| `ClickSound.swift` (14) | System feedback sounds (`stop()` is a no-op) |

## Volume system

```
System volume (CoreAudio "vmvo" AudioObjectSetPropertyData)
   ▲                                    
   │ AppVolumeManager.setVolume/delta    │ AppVolumeManager.getEffectiveVolume
   │                                    
EdgeVolumeEngine (trackpad right-edge)   ──►  haptics + CenteredMenuBar overlay
   │
   └─► NowPlayingManager.adjustVolume (±4% scroll) → JS video.volume (online)
   └─► NativeAudioPlayer.setVolume (offline)
   └─► Pre-mute state "YTM_preMuteVolume"; last-known "YTM_lastKnownSystemVolume"
```

- **App-volume-only mode** (`isAppVolumeOnly`): volume gestures change the persisted `Mooziac_MediaVolume` (app/web), not the system scalar.
- Safety: ±25% per-swipe clamp, 3.0 mm arming threshold, ID lock (`touchID == activeTouchID`).

## Auto-pause system

| Trigger | Detector | Behavior |
| :--- | :--- | :--- |
| Screen lock (`com.apple.screenIsLocked`) | `NowPlayingManager`, `AudioRouteMonitor`, `EdgeVolumeEngine` | pause (if enabled); `isSystemSleeping=true` |
| System sleep (`willSleep`) | `NowPlayingManager` | pause |
| Unlock / wake | DNC + `didWake` | optional resume (preference-gated) |
| Headphones/device disconnect | `AudioRouteMonitor` CoreAudio listener | pause (unless `isSystemSleeping` or preference off) |

## Sleep prevention

`BackgroundMediaController` creates an `IOPMAssertion` (`kIOPMAssertionTypePreventUserIdleSystemSleep`) + `ProcessInfo.beginActivity(.userInitiated, .idleSystemSleepDisabled)` so audio keeps playing while the display locks/sleeps (lid open).

## Notifications & defaults

- Observes `.AVPlayerItemDidPlayToEndTime`.
- Posts no direct notifications; state flows through `NowPlayingManager.notifyObservers`.
- Writes `Mooziac_LastPlayedLocalTrackId` / `Mooziac_LastPlayedLocalTrackTitle` (NativeAudioPlayer); removes them on track delete.
- Reads `Mooziac_MediaVolume`, `YTM_preMuteVolume`, `YTM_lastKnownSystemVolume`, `YTM_isAutoPauseOnDisconnectEnabled`.

## Risks (summarized)

- `itemEndObserverToken` dead property; duplicated JS pause snippet; hardcoded 3.0 s prev-threshold; potential dual-engine concurrency if JS pause silently fails; Multitouch ABI fragility; cross-thread flag reads in `EdgeVolumeEngine`; `AudioRouteMonitor` treats lock==sleep; `setupAudioSession()` empty stub; `ClickSound.stop()` no-op.
- Detail: `99_APPENDIX/RAW_DISCOVERY_NOTES/02_AUDIO_WEB_INPUT.md` + `15_ISSUES_AND_RISKS/`.