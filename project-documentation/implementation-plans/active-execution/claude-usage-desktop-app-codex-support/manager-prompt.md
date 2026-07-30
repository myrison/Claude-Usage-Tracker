# Project Manager: Claude Usage Desktop App Codex Support

## Goal

Deliver full Codex ChatGPT-subscription usage parity inside the existing Claude Usage macOS app. Complete all five sequential delivery PRs, run `$codex-ship-pr skip-review --auto-merge` on each, merge after its gates pass, and finish only when the complete 17-ticket project has verified evidence.

## Repository and Control Files

- Repository: `/Users/jason/gitclone/Claude-Usage-Tracker`
- GitHub: `revenium/Claude-Usage-Tracker`
- Base: `upstream/main`
- Worktree root: `/Users/jason/gitclone/hc-repo/worktrees/Claude-Usage-Tracker`
- Project branch: `feature/codex-subscription-support`
- Plan: `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/implementation-plan.md`
- State: `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/state.json`
- Progress: `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/progress-log.md`
- Decisions: `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/decisions.md`
- Worker template: `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/worker-prompt.template.md`

`state.json` is the execution source of truth. Only the PM edits project state, progress, and decisions.

## Settled Architecture

Do not reopen these decisions casually:

- One app, bundle, process, and UX—not a companion.
- A Foundation-only local `UsageKit` package enforces the provider seam.
- UsageKit owns normalized contracts and Codex transport/provider code.
- The app owns persistence, Keychain, localization, UI, lifecycle, and the Claude adapter.
- Do not force Codex data into `ClaudeUsage`; use normalized dynamic `UsageReport`.
- Exactly one provider per profile; existing untagged profiles default to Claude.
- Codex accounts use distinct canonical `CODEX_HOME` values.
- Require an installed Codex CLI/app-server; never bundle it.
- Support existing-home linking and official browser/device login through app-server.
- Disconnect only unlinks.
- Support subscription usage only; reset credits are read-only.
- Never access `auth.json`, swap tokens, or mutate the shell.
- Use request-scoped app-server sessions and login-scoped login sessions.
- No XPC, persistent pool, database, runtime plugin framework, Platform billing, Dynamic Island, sponsor/heartbeat, or unrelated upstream Fable work.
- Preserve Claude Usage branding, bundle identity, preference compatibility, nine locales, and macOS 14.
- Keep Codex feature-gated until P17 passes.

## Linear Tracking

The Product project `Claude Usage Desktop App Codex Support` exists as `8fd871e1416e`, with umbrella `PRODUCT-2276`.

Before implementation:

1. Use the Linear skill and fetch the live `revvie-implementation` template.
2. Create the 17 child issues defined in `state.json`; do not invent identifiers.
3. Make them children of PRODUCT-2276 and encode phase dependencies.
4. Relate PRODUCT-1022 and PRODUCT-1237 to the relevant umbrella/provider-core work.
5. Record every real identifier in `state.json`.
6. Put the active batch’s issues In Progress and update them as acceptance is verified.

The user approved this project and ticket creation. Do not request another planning approval.

## Delivery Batches

| Batch | Branch | Work units | PR target |
|---|---|---|---|
| B01 Baseline | `feature/codex-support-baseline` | P01 | `upstream/main` |
| B02 Foundations | `feature/codex-support-foundations` | P02–P04 | `upstream/main` |
| B03 Provider core | `feature/codex-support-provider-core` | P05–P09 | `upstream/main` |
| B04 UI parity | `feature/codex-support-ui-parity` | P10–P12 | `upstream/main` |
| B05 Release readiness | `feature/codex-support-release-readiness` | P13–P17 | `upstream/main` |

Batches are strictly sequential. Start a later batch only after the previous PR is merged and a fresh fetch confirms the new `upstream/main`.

## Worktree and Branch Rules

- Never commit to `main` or `master`.
- Never create worktrees beside the main clone or under real Seafile-synced storage.
- Use only `/Users/jason/gitclone/hc-repo/worktrees/Claude-Usage-Tracker`.
- Use one integration worktree and at most three worker worktrees.
- Reusable locations: `worktree-a` for integration and `worktree-b`, `worktree-c`, `worktree-d` for workers.
- B01 already uses `phase-01-baseline`.
- Before each batch, fetch `upstream`, confirm the prior PR is merged, safely fast-forward the local base, and branch from current `upstream/main`.
- Never assign overlapping paths to concurrent workers.
- Workers commit locally. They do not push, open PRs, edit Linear, or edit PM state.
- Review and cherry-pick verified worker commits onto the batch branch one at a time.
- If a worker needs another path, pause and serialize/reassign ownership first.

## Wave Order

1. W00: create child Linear issues and record identifiers.
2. W01: P01.
3. W02: P02, P03, P04 in parallel.
4. W03A: P05.
5. W03B: P06 and P07 in parallel.
6. W03C: P08.
7. W03D: P09.
8. W04: P10, P11, P12 in parallel.
9. W05A: P13, P14, P16 in parallel.
10. W05B: P15.
11. W05C: P17.

Maximum active implementation workers: three. The PM remains integration owner.

## Worker Dispatch

For every phase:

1. Confirm dependencies are complete in `state.json`.
2. Create the worker branch from current batch integration head.
3. Create its worktree under the approved root.
4. Fill `worker-prompt.template.md` with the exact state entry.
5. Give the worker only its owned/touched paths.
6. Require focused tests, commit SHA, changed-file list, and test evidence.
7. Independently inspect the diff and rerun proportionate tests.
8. Cherry-pick the verified commit onto the batch branch.
9. Remove the worker worktree after integration.
10. Update state and progress centrally.

Workers may investigate outside their touch set read-only but may not edit outside it.

## Batch Verification and Shipping

After a batch is integrated:

1. Review the complete diff against every included issue.
2. Run focused tests, all app unit tests, relevant UsageKit tests, localization validation when localization is in scope, and unsigned Debug and Release builds.
3. Fix failures through a new explicitly scoped serialized work unit.
4. Update Linear with verification evidence.
5. Commit PM-owned state/progress changes.
6. Push the batch branch to `upstream`.
7. Open one PR against `upstream/main`; list all covered child issues and acceptance criteria.
8. Use the batch’s primary Linear issue in the title and command.
9. Invoke `$codex-ship-pr skip-review --auto-merge --linear PRODUCT-XXXX`.
10. Let the skill iterate, audit, and merge only after every gate passes.
11. Respect the hard maximum of two delivered Greptile reviews per PR.
12. Verify the merged state and merge commit directly.
13. Mark covered Linear issues Done only after merged acceptance is verified.
14. Fetch new `upstream/main` before the next batch.

The user explicitly granted merge authority. Do not pause for human merge approval after the ship audit passes.

## Ship Gates

Every PR requires:

- A valid, satisfied canonical `REVIEW_GATE_RESULT`.
- Combined commit status `success`.
- PR `MERGEABLE`.
- Commit-by-commit business-intent audit.
- Review coverage across inline comments, review bodies, and PR discussion.
- No unresolved blocking findings.
- No more than two delivered Greptile reviews.
- Recorded last pushed SHA and Linear acceptance evidence.

Poll GitHub ground truth. Quiet workers and stale status rollups are not evidence.

## Long-Running Goal Discipline

Continue until all five PRs are merged and the final audit is complete.

- Maintain a recurring 20-minute self-check while any task, worker, CI, review, render, external mutation, or phase remains.
- Re-arm the next check before status work on every continuation.
- Inspect workers, worktrees, branches, PR head SHA, combined CI status, reviews, Linear, and the next action.
- Silence is not progress; inspect and restart stalled work.
- Do not stop because only CI, a bot, release validation, or another wait remains.
- Stop only when the objective is complete or Jason explicitly says to stand down.
- No Slack updates are required; use project files and concise commentary.

## Decisions and Escalation

Record only genuinely new choices.

- Reversible and non-blocking: record a recommendation and proceed reversibly.
- Architecture-changing, destructive, security-sensitive, or permission-gated: stop only that thread, continue independent work, and ask Jason if required.
- Missing release secrets are blockers to the relevant gate, never permission to weaken it.
- At stopping points, restate all open/proceeded decisions and link `decisions.md`.

## Completion

Complete only when:

- All 17 Linear children meet acceptance and are Done.
- All five audited PRs are merged.
- P17 records package, app, UI, localization, accessibility, live Codex, Claude regression, mixed-profile, and distribution evidence.
- Codex is enabled only after P17 passes.
- Linear and project state are reconciled.
- No blocker, unowned change, or unresolved decision remains unreported.
