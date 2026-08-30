# Excluded-Fix Risk Estimates

Estimated risk of applying each fix that was excluded from `RECOMMENDEDFIX.md`.

- **Crash risk** = probability the change causes an app crash/abort.
- **Visible-issue risk** = probability the change causes wrong behavior / UX bug.
- Estimates based on static analysis of the codebase; not measurements.

| Fix | Crash risk | Visible-issue risk |
| :--- | :--- | :--- |
| K1 purge removal | ~0% | ~15% (stale like state until JS re-sync) |
| K3 init side-effect | ~0% | ~20% (unexpected DB writes from model init) |
| K4 Discord artwork | ~0% | ~10% (unchanged/no-op) |
| K6 sync gating | ~0% | ~25% (sync runs less often) |
| K7 repeat JS | ~5% | ~35% (YTM DOM match could fail silently) |
| K8 EQ JS | ~5% | ~40% (audio graph re-link, possible double-connect) |
| **K9 engine switch** | **~15%** | **~50%** (dual audio / engine drift if not byte-equivalent) |
| K10 queue math | ~0% | ~25% (wrong queue position in edge cases) |
| K15 drag reorder | ~0% | ~30% (order corruption under filter already present) |
| K17 mouseDown | ~0% | ~25% (double-click now hits slider only) |
| K11 notifyObservers | ~0% | ~20% (extra fan-out churn) |
| P1/P2 optional-ify | ~10% | ~40% (compile errors + many call sites, missed IUO deref) |
| P4/P5 Multitouch | ~15% | ~45% (gesture disable / phantom input on layout mismatch) |
| P6 playlist recursion | ~5% | ~25% (loop vs recursion edge cases) |
| **P8 lock-vs-sleep** | ~0% | **~50%** (auto-pause may not fire — core feature) |
| P9 autoPlayJS | ~5% | ~30% (JS selector drift) |
| P15 shuffle insert | ~0% | ~20% (different shuffle placement) |
| P16 normalization | ~0% | ~15% (match scoring changes) |
| P22 move-up/down | ~0% | ~20% (wrong row moved) |
| P26 schema migration | ~10% | ~35% (migration failure → DB stuck) |
| P28 async artwork fetch | ~5% | ~30% (finalize ordering changes) |
| P33 content-rule precompile | ~5% | ~25% (first-load blocking timing) |
| P35 focus change | ~0% | ~25% (panel focus behavior) |
| R1–R4, R6–R8 | ~10-20% | ~40-60% (architecture rewrites) |

## Bottom line

- Most dangerous excluded items: **K9** (~15% / ~50%) and **P8** (~0% / ~50%).
- Architecture items (**R***) are the riskiest overall: ~10-20% crash / ~40-60% visible.
- Everything else is low crash risk with moderate visible-issue risk — consistent with why they were excluded from `RECOMMENDEDFIX.md`.

## Related

- `Project Blueprint/15_ISSUES_AND_RISKS/RECOMMENDEDFIX.md`
- `Project Blueprint/15_ISSUES_AND_RISKS/HOWTOFIX.md`