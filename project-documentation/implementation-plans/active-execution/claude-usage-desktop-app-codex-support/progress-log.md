# Progress Log: Claude Usage Desktop App Codex Support

## Active Work

- Project status: Active
- Linear project: `Claude Usage Desktop App Codex Support` (`8fd871e1416e`)
- Umbrella: `PRODUCT-2276`
- Tracking wave: W00 — complete
- Current delivery batch: B01 — Restore deterministic baseline
- Current phase: P01 — Restore a deterministic green app baseline
- Active implementation worker: None
- Next action: Commit B01 and run `$codex-ship-pr skip-review --auto-merge --linear PRODUCT-2282`

## Repository State at Initialization

- Base: `upstream/main`
- Base commit: `aaeb9e74747f0197dc7d8935a2b64ea37a4e81e5`
- Project branch: `feature/codex-subscription-support`
- B01 branch: `feature/codex-support-baseline`
- Project worktree: `/Users/jason/gitclone/hc-repo/worktrees/Claude-Usage-Tracker/worktree-a`
- B01 worktree: `/Users/jason/gitclone/hc-repo/worktrees/Claude-Usage-Tracker/phase-01-baseline`
- Existing untracked paths preserved: `.cache/`, `.serena/`

## Known Baseline

- `xcodebuild -list` succeeds.
- The app has one app target and one unit-test target.
- The original baseline ran 103 unit tests with one parser failure.
- P01 now runs 104 unit tests: 104 pass, 0 fail, 0 skip.
- `UsageLimitParsing` rejects explicit incompatible or malformed kinds while retaining missing-kind compatibility.
- `SharedDataStoreTests` now use isolated, injected UserDefaults suites; 20 repeated runs pass.
- Localization validation currently fails for every non-English catalog.
- Localization debt is assigned to P15 after provider UI strings stabilize; it is not a B01 acceptance gate.
- Current CI builds Debug, runs unit tests, builds Release, and uploads an unsigned artifact.
- Current CI does not gate localization, package tests, UI tests, signing, or release smoke tests.
- Original upstream contains no Codex/OpenAI subscription support.

## Wave Status

| Wave | Description | Phases | Status |
|---|---|---|---|
| W00 | Linear tracking initialization | 17 child issues | Complete |
| W01 | Green baseline | P01 | Verified; pending ship |
| W02 | Safety foundations | P02, P03, P04 | Pending |
| W03A | UsageKit boundary | P05 | Pending |
| W03B | Transport and profile model | P06, P07 | Pending |
| W03C | Codex provider | P08 | Pending |
| W03D | Refresh integration | P09 | Pending |
| W04 | Provider-aware UI parity | P10, P11, P12 | Pending |
| W05A | Cross-cutting parity and distribution | P13, P14, P16 | Pending |
| W05B | Localization/accessibility/UI automation | P15 | Pending |
| W05C | Final parity and ship audit | P17 | Pending |

## Delivery PRs

| Batch | Branch | PR | CI | Review Gate | Merge | Status |
|---|---|---|---|---|---|---|
| B01 Baseline | `feature/codex-support-baseline` | — | Local green | Pending | — | Verified; pending ship |
| B02 Foundations | `feature/codex-support-foundations` | — | — | — | — | Pending |
| B03 Provider core | `feature/codex-support-provider-core` | — | — | — | — | Pending |
| B04 UI parity | `feature/codex-support-ui-parity` | — | — | — | — | Pending |
| B05 Release readiness | `feature/codex-support-release-readiness` | — | — | — | — | Pending |

## Completed Phases

| Phase | Linear | Worker | Commit | Batch PR | Completed | Summary |
|---|---|---|---|---|---|---|
| P01 | PRODUCT-2282 | baseline_audit | Pending commit | Pending | Pending merge | Parser correctness, hermetic UserDefaults tests, canonical validation docs |

## Verification Evidence

| Date | Scope | Command/check | Result | Evidence |
|---|---|---|---|---|
| 2026-07-29 | P01 unit suite | `xcodebuild test ... -destination "platform=macOS"` | PASS | 104 passed, 0 failed, 0 skipped |
| 2026-07-29 | P01 storage isolation | `SharedDataStoreTests` repeated 20 times | PASS | Per-test UUID suites remained isolated |
| 2026-07-29 | P01 Debug build | unsigned `xcodebuild build -configuration Debug` | PASS | `** BUILD SUCCEEDED **` |
| 2026-07-29 | P01 Release build | unsigned `xcodebuild build -configuration Release` | PASS | `** BUILD SUCCEEDED **` |
| 2026-07-29 | P01 diff hygiene | `git diff --check` | PASS | No whitespace errors |

## Blockers

- None at initialization.
- Release signing, notarization, Pages/appcast, and Homebrew publication may require Revenium secrets or repository permissions; verify during P16.

## Decisions

- All architecture decisions are settled in `decisions.md`.
- No open decisions at initialization.

## Daily Summaries

### 2026-07-29 / 2026-07-30 UTC

- Completed upstream, repository, architecture, Codex app-server, baseline-test, localization, CI, and release-infrastructure audits.
- Chose one modular app with a Foundation-only UsageKit seam.
- Defined 17 work units, dependency waves, and five sequential PR batches.
- Created the Linear project, PRODUCT-2276 umbrella, all 17 child issues, dependency relations, and links to PRODUCT-1022/PRODUCT-1237.
- Implemented and independently verified P01 on `feature/codex-support-baseline`.
- User authorized implementation and audited auto-merge for every delivery PR.
