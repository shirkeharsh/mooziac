# Terminology

Naming conventions and marker conventions used in this blueprint.

## Accuracy markers

Every statement in this blueprint is labeled (explicitly or implicitly):

| Marker | Meaning |
| :--- | :--- |
| `CONFIRMED FROM SOURCE` | directly observed in the code |
| `INFERRED FROM SOURCE` | reasonable deduction from the code, not runtime-verified |
| `UNKNOWN — requires runtime verification` | cannot be determined from source alone |

Unmarked statements are confirmed from source; the markers appear where confidence is lower.

## File/function references

- References use `Path/File.swift:line` (e.g. `ObserverBridge.swift:411`).
- "raw notes" = `99_APPENDIX/RAW_DISCOVERY_NOTES/01_CORE_LAYER.md … 06_LIBRARIES_COMPONENTS_UI.md`.
- "Source: A12" style cross-references map to the numbered RISKS/OBSERVATIONS entries in the raw notes (A = core layer, B = audio/web/input, C = data/managers, D = lyrics/models, E = player/windows, F = libraries/components).

## Naming conventions in the app

| Pattern | Example | Meaning |
| :--- | :--- | :--- |
| `public` top-level types | `NowPlayingManager` | single-module visibility convention |
| `func trackDid…` / `handle…` | `trackDidStartOffline` | event handlers |
| `update…` | `updateSystemNowPlayingInfo` | state-sync to external systems |
| `set…` / `toggle…` | `setRepeatMode`, `toggleLike` | command surface |
| `fetch…` / `load…` | `fetchQueue`, `loadArtwork` | async reads |
| JS-injected funcs | `observerJS`, `autoPlayJS` | `evaluateJavaScript` payloads |
| `isXxx` / `hasXxx` flags | `isNetworkAvailable`, `hasActiveContext` | booleans |
| Protocol `…Delegate` | `DynamicIslandPlayerViewDelegate` | delegate interfaces |

## Key-count conventions used in the final report

- Repository files inspected = 60 Swift source files in `Sources/Mooziac/`.
- Classes documented = 95 top-level types.
- Functions/methods documented = 673 `func` declarations.
- Storage systems = SQLite, UserDefaults, lyrics cache, thumbnail cache, memory caches, audio files, notification art, Discord socket.
- Risks documented ≈ 160 observations across the six raw-note RISKS sections.