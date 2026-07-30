# Decisions Log: Claude Usage Desktop App Codex Support

All decisions below were settled during planning and approved before implementation. There are no open decisions at initialization.

---

### D001 — Ship one modular application
- Context: Full parity could use the existing app, a companion, or multiple targets.
- Options: One modular app / Separate companion / Multiple targets with shared core
- **Decision: One modular app with an enforced provider seam.**
- Rationale: A separate parity app retains most implementation cost and adds release, migration, support, and UX complexity.
- Status: RESOLVED — approved 2026-07-29

### D002 — Enforce the seam with a local static Swift package
- Context: Provider abstractions need a boundary that prevents UI and persistence coupling.
- Options: Local UsageKit package / App-folder protocols / Runtime plugins
- **Decision: Add a Foundation-only UsageKit package containing UsageCore and CodexUsageProvider.**
- Rationale: It provides a compile-time boundary without plugin-SDK complexity.
- Status: RESOLVED — approved 2026-07-29

### D003 — Normalize usage instead of extending ClaudeUsage
- Context: Codex exposes dynamic groups and windows that do not fit Claude’s fixed model.
- Options: Add Codex fields to ClaudeUsage / Dynamic UsageReport / Unrelated models indefinitely
- **Decision: Move view and storage consumers toward normalized UsageReport, with a Claude adapter.**
- Rationale: Dynamic provider-neutral groups avoid repeated provider conditionals.
- Status: RESOLVED — approved 2026-07-29

### D004 — Keep app-specific concerns outside UsageKit
- Context: Persistence and presentation dependencies could leak into provider code.
- Options: Package owns everything / App owns platform and persistence concerns
- **Decision: UsageKit remains Foundation-only; the app owns persistence, Keychain, UI, localization, and lifecycle.**
- Rationale: Provider code stays independently testable.
- Status: RESOLVED — approved 2026-07-29

### D005 — Use one provider per profile
- Context: A profile could combine providers or represent one provider identity.
- Options: Mixed-provider profile / One provider per profile
- **Decision: Each profile has one tagged provider; existing untagged profiles default to Claude.**
- Rationale: It preserves identity, refresh, credential, history, and notification isolation.
- Status: RESOLVED — approved 2026-07-29

### D006 — Isolate Codex accounts by CODEX_HOME
- Context: Codex multi-account support needs a safe identity boundary.
- Options: Swap tokens/auth files / Canonical CODEX_HOME per profile
- **Decision: Store only a canonical CODEX_HOME reference and reject duplicate or symlink-equivalent homes.**
- Rationale: This uses Codex’s official boundary without touching credentials.
- Status: RESOLVED — approved 2026-07-29

### D007 — Require the official installed Codex CLI/app-server
- Context: The app could bundle Codex, read files directly, or use the installed service.
- Options: Bundle CLI / Read files / Require installed CLI and app-server
- **Decision: Require a capability-equivalent installed Codex CLI/app-server.**
- Rationale: It uses supported account/usage APIs without bundled binaries or credential parsing.
- Status: RESOLVED — approved 2026-07-29

### D008 — Support linking and official in-app login
- Context: Codex profiles need setup and authentication.
- Options: Existing-home only / In-app login only / Both
- **Decision: Support linking an existing CODEX_HOME and official browser/device login through app-server.**
- Rationale: This covers existing and first-time users without inventing authentication.
- Status: RESOLVED — approved 2026-07-29

### D009 — Unlink without deleting credentials
- Context: Removing a Codex profile could affect the underlying Codex account.
- Options: Delete credentials / Unlink only
- **Decision: Disconnect and profile deletion only unlink app state.**
- Rationale: The app does not own Codex authentication data.
- Status: RESOLVED — approved 2026-07-29

### D010 — Never access auth.json or swap tokens
- Context: Direct credential access creates security and ownership risks.
- Options: Read/copy/edit auth.json / Official app-server only
- **Decision: Never read, copy, edit, delete, or log auth.json; never swap tokens or mutate the shell.**
- Rationale: Official APIs provide the needed account and usage data.
- Status: RESOLVED — approved 2026-07-29

### D011 — Scope support to ChatGPT/Codex subscriptions
- Context: OpenAI Platform billing is a different product and data model.
- Options: Subscription only / Subscription plus Platform billing
- **Decision: Support ChatGPT/Codex subscription usage only.**
- Rationale: This matches Claude subscription parity without conflating billing systems.
- Status: RESOLVED — approved 2026-07-29

### D012 — Display reset credits without redemption
- Context: App-server exposes credit/reset information.
- Options: Display only / Redemption controls
- **Decision: Display reset credits read-only.**
- Rationale: Redemption is outside usage-monitor scope and is consequential.
- Status: RESOLVED — approved 2026-07-29

### D013 — Use bounded request-scoped app-server sessions
- Context: App-server can launch per request or remain persistent.
- Options: Request-scoped / Persistent pool / XPC helper
- **Decision: Use request-scoped refresh sessions and login-scoped login sessions behind injected transport.**
- Rationale: Startup is small, lifecycle complexity is lower, and future pooling remains possible.
- Status: RESOLVED — approved 2026-07-29

### D014 — Preserve product compatibility and branding
- Context: Adding Codex could trigger a rename or new identity.
- Options: Rename/rebundle / Preserve Claude Usage identity
- **Decision: Keep the app name, bundle identity, preferences, migration behavior, macOS 14 minimum, and current nine locales.**
- Rationale: It avoids an unrelated migration and distribution expansion.
- Status: RESOLVED — approved 2026-07-29

### D015 — Rehome releases to Revenium
- Context: The fork still references the original maintainer’s release infrastructure.
- Options: Keep original destinations / Move to Revenium
- **Decision: Move release, update, support, source, feedback, appcast, and Homebrew destinations to Revenium.**
- Rationale: A Revenium build must not publish through or update into the original maintainer’s channels.
- Status: RESOLVED — approved 2026-07-29

### D016 — Selectively adapt upstream work
- Context: Original upstream has many post-fork commits but no Codex implementation.
- Options: Wholesale merge / Ignore / Selectively adapt
- **Decision: Selectively adapt verified Keychain, file persistence, bounded-process, and menu/window reliability ideas.**
- Rationale: Wholesale merge would overwrite Revenium profile switching and Fable work.
- Status: RESOLVED — approved 2026-07-29

### D017 — Exclude unrelated upstream features
- Context: Upstream includes Dynamic Island, sponsor/heartbeat, statusline expansion, locale additions, and Fable changes.
- Options: Include all / Keep Codex scope focused
- **Decision: Exclude those unrelated features and broad menu refactors.**
- Rationale: They do not reduce Codex parity risk and enlarge regression scope.
- Status: RESOLVED — approved 2026-07-29

### D018 — Use five sequential audited PR batches
- Context: One PR is too large, while 17 PRs add coordination overhead.
- Options: One PR / Seventeen PRs / Five cohesive batches
- **Decision: Deliver baseline, foundations, provider core, UI parity, and release readiness as five PRs to upstream/main.**
- Rationale: The batches keep review coherent while preserving dependency order.
- Status: RESOLVED — approved 2026-07-29

### D019 — Permit audited auto-merge
- Context: Each PR otherwise needs separate human merge approval.
- Options: Stop ready / Merge after verified gates
- **Decision: Run `$codex-ship-pr skip-review --auto-merge` for each PR and merge when all gates pass.**
- Rationale: Jason explicitly granted merge authority.
- Status: RESOLVED — approved 2026-07-29

### D020 — Keep Codex feature-gated until final parity
- Context: Intermediate batches may compile while surfaces remain incomplete.
- Options: Enable incrementally / Keep internal until final audit
- **Decision: Keep Codex disabled for normal users until P17 passes.**
- Rationale: This prevents partial exposure while allowing mergeable batches.
- Status: RESOLVED — approved 2026-07-29

### D021 — Avoid premature provider-framework complexity
- Context: Future providers are possible but not planned.
- Options: Full plugin SDK / Clean static seams
- **Decision: Keep clean provider contracts without runtime discovery or universal authentication.**
- Rationale: It preserves reasonable extensibility without speculative complexity.
- Status: RESOLVED — approved 2026-07-29

### D022 — Defer localization remediation to P15
- Context: Existing non-English catalogs have baseline debt, and Codex UI strings will continue changing through B04.
- Options: Repair all catalogs in B01 / Remediate once after provider UI stabilizes
- **Decision: Track existing and new localization remediation in P15, not B01.**
- Rationale: This avoids translating a moving string surface twice while preserving a final mandatory CI gate.
- Status: RESOLVED — directed 2026-07-29

---

## Open Decisions

None.
