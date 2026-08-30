# Documentation Status

Status of every documentation artifact in the Project Blueprint, as of the build date of this archive.

---

## Confidence legend

- **CONFIRMED FROM SOURCE** — verified directly in implementation.
- **INFERRED FROM SOURCE** — implied by code, not runtime-verified.
- **UNKNOWN — requires runtime verification** — cannot be resolved statically.

## Document Status Matrix

| Folder / Document | Status | Source of truth | Notes |
| :--- | :--- | :--- | :--- |
| **00_INDEX** | | | |
| MASTER_INDEX.md | COMPLETE | whole repo | Entry point. |
| DOCUMENTATION_STATUS.md | COMPLETE | this file | |
| COVERAGE_CHECKLIST.md | COMPLETE | second-pass audit | See final audit. |
| **01_PROJECT_OVERVIEW** | | | |
| PROJECT_OVERVIEW.md | COMPLETE | README, AGY.md, source | |
| PURPOSE_AND_GOALS.md | COMPLETE | README, source | |
| ROADMAP.md | COMPLETE | audit findings (15_ISSUES_AND_RISKS) | Prioritized P0–P3 plan. |
| TECHNOLOGY_STACK.md | COMPLETE | Package.swift, source | |
| PROJECT_HISTORY.md | COMPLETE | CHANGELOG, AGY.md, git log | |
| **02_CODEBASE** | | | |
| COMPLETE_FILE_TREE.md | COMPLETE | `find` scan | All repo files (excl. `.git`, `.build`). |
| FILE_CATALOG.md | COMPLETE | per-file analysis (raw notes) | One row per file. |
| SOURCE_FILE_MAP.md | COMPLETE | grep of type declarations | Subsystem → files → types → docs. |
| ASSET_MAP.md | COMPLETE | `Resources/` scan | |
| **03_ARCHITECTURE** | | | |
| SYSTEM_ARCHITECTURE.md | COMPLETE | raw notes A–F | |
| APPLICATION_LAYERS.md | COMPLETE | raw notes A–F | |
| MODULE_ARCHITECTURE.md | COMPLETE | raw notes A–F | |
| DATA_FLOW.md | COMPLETE | raw note A (flows 1–10) + others | |
| EVENT_FLOW.md | COMPLETE | raw notes, grep of notifications | |
| DEPENDENCY_GRAPH.md | COMPLETE | raw notes A–F | |
| **04_FUNCTIONS** | | | |
| FUNCTION_INDEX.md | COMPLETE | grep of `func` declarations | 673 entries. |
| FUNCTION_REFERENCE.md | COMPLETE | raw notes | Pointer index into raw notes. |
| CLASS_REFERENCE.md | COMPLETE | grep + raw notes | 95 types. |
| METHOD_REFERENCE.md | COMPLETE | raw notes | Pointer index. |
| CALLBACK_REFERENCE.md | COMPLETE | raw notes | Observers/selectors/closures. |
| **05_UI** | COMPLETE | raw notes E + F | |
| **06_AUDIO** | COMPLETE | raw note B + A | |
| **07_LYRICS** | COMPLETE | raw note D | |
| **08_DATA** | COMPLETE | raw notes C + D | |
| **09_NETWORK** | COMPLETE | raw notes B + D | |
| **10_BACKGROUND_SYSTEMS** | COMPLETE | raw notes A + B + D | |
| **11_CONFIGURATION** | COMPLETE | Package.swift, build_app.sh, gitignore | |
| **12_SECURITY** | COMPLETE | raw notes (security sections) | |
| **13_WORKFLOWS** | COMPLETE | raw notes A–F | |
| **14_DIAGRAMS** | COMPLETE | synthesized | |
| **15_ISSUES_AND_RISKS** | COMPLETE | all raw note RISKS sections | 160+ observations. |
| **99_APPENDIX** | | | |
| GLOSSARY.md | COMPLETE | synthesized | |
| TERMINOLOGY.md | COMPLETE | synthesized | |
| RAW_DISCOVERY_NOTES/*.md (6) | COMPLETE | deep per-file reads | The exhaustive detail layer. |

---

## What is intentionally NOT documented as "confirmed"

Items that could only be resolved at runtime (each marked **UNKNOWN — requires runtime verification** in the relevant documents):

- Actual GPU/CPU/RAM behavior of WebKit vs native playback.
- Whether the private Multitouch framework layout assumption holds on all supported macOS versions.
- Whether Discord RPC `large_image` with remote URLs renders.
- Whether trackpad threshold tuning matches physical hardware.
- Exact behavior of the "double-handling" reset path and gesture-inversion oddity in `GestureMappingManager`/`KeyboardCommandHandler`.
- JS DOM-selector resilience across YouTube layout changes (continuously shifting).

## Maintenance note

The raw discovery notes (`99_APPENDIX/RAW_DISCOVERY_NOTES/`) are the deepest layer and were produced by line-by-line reading. If this blueprint is kept in sync with future code changes, the raw notes and `15_ISSUES_AND_RISKS` require the most attention.