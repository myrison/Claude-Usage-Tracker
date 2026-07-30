# Claude Usage Desktop App — Codex Subscription Support

## Objective

Add complete Codex ChatGPT-subscription usage support to the existing Claude Usage macOS application while preserving Claude behavior and compatibility. Coverage includes profiles, onboarding, login, configuration, refresh, menu systems, status items, popover presentation, history, exports, notifications, diagnostics, localization, accessibility, testing, release infrastructure, and distribution.

The work is tracked in the Product Linear project `Claude Usage Desktop App Codex Support` (`8fd871e1416e`) under umbrella issue `PRODUCT-2276`.

## Architecture

Ship one app, bundle, process, and UX. A separate Codex companion would retain most parity work while adding a second release, migration, support, and settings surface.

Introduce a local static Swift package at `Packages/UsageKit`:

- `UsageCore` target: `ProviderID`, `UsageReport`, `UsageLimitGroup`, `UsageWindow`, `ProviderCapabilities`, provider protocols, and provider-neutral errors.
- `CodexUsageProvider` target: bounded process transport, app-server JSONL protocol, account/login/health/usage implementation, and deterministic fakes.
- App target: file persistence, Keychain, localization, AppKit/SwiftUI, lifecycle, notification integration, profile orchestration, and `ClaudeUsageProviderAdapter`.

`UsageKit` is Foundation-only: no AppKit, SwiftUI, UserDefaults, Keychain, localization, or app singletons. Do not force dynamic Codex data into `ClaudeUsage`; gradually move view and storage consumers to normalized `UsageReport`.

## Profile and Authentication Model

- Exactly one provider per profile; existing profiles with no provider tag migrate as Claude.
- Mixed Claude/Codex profile collections are supported.
- A Codex profile stores only a canonical `CODEX_HOME` reference and non-secret metadata.
- Reject duplicate and symlink-equivalent Codex homes.
- Never swap tokens, mutate a shell, or read/copy/edit/delete/log `auth.json`.
- Require a capability-equivalent installed Codex CLI/app-server; do not bundle it.
- Support linking an existing `CODEX_HOME` and official browser/device login through app-server.
- Disconnect and profile deletion unlink app state only; they never delete Codex credentials.

## Codex Contract

Use the official app-server protocol over JSONL stdio:

1. Start with the profile’s injected `CODEX_HOME`.
2. Send `initialize`, then `initialized`.
3. Use `account/read`, `account/rateLimits/read`, and optional `account/usage/read`.
4. Prefer dynamic `rateLimitsByLimitId`, retaining primary/secondary windows, used percentage, reset time, duration, plan, credits, and read-only reset credits.
5. Tolerate missing optional lifetime/peak/streak and daily token data.
6. Keep a documented legacy response fallback.
7. Treat API-key and Bedrock accounts as unsupported for subscription tracking.

Use short-lived request-scoped app-server sessions for refresh and a login-scoped session for login. Keep transport injected so pooling can be reconsidered from evidence later; do not add a persistent pool or XPC helper in this version.

## Storage and Safety Foundations

- Move existing profile secrets from plaintext profile JSON to profile-keyed Keychain entries.
- Delete legacy secrets only after successful Keychain write and readback.
- Move current usage and history to atomic file-backed storage outside profile records.
- Delete legacy UserDefaults data only after verified write and decode.
- Preserve backwards decoding, idempotent migrations, recovery from partial failure, and multi-profile isolation.
- Make refresh orchestration an actor keyed by profile UUID to prevent stale results crossing profiles.
- Redact tokens, credential JSON, auth payloads, environment secrets, and sensitive paths from logs and diagnostics.

## UI and Behavior Coverage

- Onboarding and profile creation: Claude or Codex selection, existing-home linking, official login, validation, duplicate-home errors, edit, unlink, and delete.
- Settings: provider identity, account state, health, login, refresh, capabilities, appearance, history, notifications, updates, support, and diagnostics.
- Popover: dynamic limit groups/windows, reset times, plans, credits, optional usage summaries, loading/stale/empty/error/unsupported states, and mixed-profile display.
- Menus and status items: all left-click/right-click actions, profile switching, manual refresh, settings, quit, provider-aware metrics, thresholds, used/remaining display, appearance, and error state.
- History/export: provider-tagged normalized records with group/window/reset semantics.
- Notifications: threshold/reset handling for dynamic Codex windows with deduplication.
- Automation: Claude-only statusline, auto-start, and related actions are hidden or explained through provider capabilities.
- Errors: actionable missing-CLI, invalid-home, unauthenticated, unsupported-auth, timeout, protocol-drift, malformed-response, and unavailable-endpoint recovery.

## Upstream Audit

The original `hamed-elfayome/Claude-Usage-Tracker` repository contains no Codex/OpenAI subscription implementation. Do not wholesale merge or rebase its post-fork work because that would overwrite Revenium profile switching and Fable changes.

Selectively adapt:

- Verified file-backed persistence ideas, correcting the legacy-deletion failure path.
- Keychain migration with readback verification.
- Bounded subprocess concepts, implemented as a robust shared transport.
- Right-click Refresh/Settings/Quit, full-screen popover, visibility, CGImage rendering, profile/detach crash, macOS 26/27 recursion, and Cmd+W fixes.

Exclude Dynamic Island, sponsor/heartbeat, peak-hour/statusline additions, upstream Fable code, broad menu refactors, and bulk locale expansion.

## Work Items

1. Restore a deterministic green app baseline.
2. Move profile secrets to Keychain with verified migration.
3. Add verified file-backed current usage/history.
4. Adopt selected upstream menu/window reliability fixes.
5. Introduce UsageKit contracts and the Claude characterization adapter.
6. Build bounded Codex subprocess and JSON-RPC transport.
7. Add provider-tagged profiles and migration.
8. Implement Codex account, login, health, and usage provider.
9. Add provider-aware profile-keyed refresh orchestration.
10. Make onboarding, profiles, and settings provider-aware.
11. Render normalized Claude and Codex usage in the popover.
12. Make menus, status items, icons, and appearance provider-aware.
13. Add provider-aware history, export, notifications, and automation gating.
14. Add provider-aware errors, redaction, health checks, and diagnostics.
15. Complete localization, accessibility, documentation, and UI automation.
16. Move release and update infrastructure to Revenium.
17. Run final parity audit, UAT, and ship verification.

## Dependency Waves

- W00: Linear project, umbrella, child issues, dependencies, and existing issue relations.
- W01: item 1.
- W02 in parallel: items 2, 3, and 4.
- W03A: item 5.
- W03B in parallel: items 6 and 7.
- W03C: item 8.
- W03D: item 9.
- W04 in parallel: items 10, 11, and 12.
- W05A in parallel: items 13, 14, and 16.
- W05B: item 15.
- W05C: item 17.

At most three implementation workers run concurrently. Parallel assignments have disjoint file ownership. The project manager alone edits project state and integrates worker commits.

## Delivery Batches

All PRs target `upstream/main` and are strictly sequential:

1. `feature/codex-support-baseline`: item 1.
2. `feature/codex-support-foundations`: items 2–4.
3. `feature/codex-support-provider-core`: items 5–9.
4. `feature/codex-support-ui-parity`: items 10–12.
5. `feature/codex-support-release-readiness`: items 13–17.

Codex remains internally feature-gated until item 17 passes. For every PR, run `$codex-ship-pr skip-review --auto-merge --linear <primary-issue>`, satisfy its canonical review gate and final audit, respect the maximum of two delivered Greptile reviews, and merge under the user-granted authority.

## Verification

### Unit and Migration

- Parser baseline, deterministic UserDefaults isolation, profile backwards decoding.
- Keychain success, readback failure, partial failure, deletion, idempotency, and profile isolation.
- Atomic file storage, corrupt/interrupted files, version skew, bounded retention, and legacy preservation.

### Package, Process, and Protocol

- Independent `swift test` for UsageKit.
- Initialize handshake, request IDs, notifications, partial lines, stderr, timeouts, cancellation, early exit, malformed JSON, bounded output, and redaction.
- Dynamic and legacy rate-limit shapes, optional usage, credits, unsupported auth, missing CLI, invalid home, and protocol drift.

### Integration and Concurrency

- Mixed provider profiles, duplicate/symlink homes, rapid switching, overlapping refreshes, deletion during refresh, retry, cancellation, and stale-result suppression.
- Claude characterization tests prove no regression.

### UI and Accessibility

- First-run Codex setup, existing-home link, official login, mixed profiles, all menu paths, popover states, settings, history, notifications, errors, refresh, unlink, and delete.
- Keyboard, focus, labels, values, dynamic type/layout, stale/error annunciation, and all current nine locales.
- Localization remediation and validation are completed in item 15, after the provider UI strings stabilize.

### Live and Distribution

- Smoke test against an installed capability-equivalent Codex CLI/app-server and ChatGPT subscription.
- Debug and Release builds, full package/app/UI suites, and localization gate.
- Signed/notarized app, Gatekeeper, ZIP, checksum, Sparkle appcast, and Homebrew validation where Revenium permissions and secrets are available.
- Rehome source, support, feedback, update, release, appcast, and Homebrew destinations to Revenium while retaining the current app name, bundle identity, preference domain, nine locales, and macOS 14 minimum.

## Explicit Exclusions

- Separate companion app or second target.
- Runtime provider plugin SDK or universal authentication framework.
- OpenAI Platform billing.
- Bundled Codex CLI.
- Token swapping or any `auth.json` access.
- Reset-credit redemption.
- Database, XPC helper, or persistent app-server pool.
- Dynamic Island, sponsor/heartbeat, unrelated upstream Fable work, and additional locales.
