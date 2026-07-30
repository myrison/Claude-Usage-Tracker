# Phase Worker: {{PHASE_ID}} — {{PHASE_NAME}}

## Project Context

You are implementing one bounded work unit in the Claude Usage Desktop App Codex Support project.

The product remains one macOS app with a static Foundation-only `UsageKit` provider seam. Claude behavior must remain compatible. Codex uses the official installed CLI/app-server and a canonical `CODEX_HOME`. Never read, copy, edit, delete, or log `auth.json`; never swap tokens or mutate the shell.

## Assignment

- Batch: {{BATCH_ID}} — {{BATCH_NAME}}
- Phase: {{PHASE_ID}} — {{PHASE_NAME}}
- Linear issue: {{LINEAR_ISSUE}}
- Branch: {{PHASE_BRANCH}}
- Worktree: {{WORKTREE_PATH}}
- Depends on: {{DEPENDENCIES}}
- Acceptance:

{{ACCEPTANCE_CRITERIA}}

## File Ownership

You may create only:

{{OWNS_FILES}}

You may modify only:

{{TOUCHES_FILES}}

You may inspect other files read-only. If implementation requires editing any other file, stop and report the exact path and reason to the PM. Do not broaden your own scope.

Never edit:

- `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/state.json`
- `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/progress-log.md`
- `project-documentation/implementation-plans/active-execution/claude-usage-desktop-app-codex-support/decisions.md`
- Another worker’s worktree or files
- Unrelated user changes, including `.cache/` and `.serena/`

## Before Starting

1. Confirm `pwd`, branch, worktree, and scoped status.
2. Read repository `AGENTS.md`, `CLAUDE.md`, and `CLAUDE.local.md` if present.
3. Read settled project decisions and dependency summaries supplied by the PM.
4. Inspect existing code and tests relevant to your paths.
5. Do not create a worktree, rebase, merge, push, open a PR, or update Linear.

## Implementation Requirements

- Implement the smallest cohesive change satisfying every assigned criterion.
- Preserve Claude behavior unless the phase explicitly changes it.
- Add focused deterministic tests for relevant success, failure, migration, concurrency, and redaction paths.
- Inject process, clock, storage, environment, and transport boundaries.
- Do not introduce AppKit, SwiftUI, UserDefaults, Keychain, localization, or singletons into UsageKit.
- Do not build a plugin framework, XPC helper, persistent process pool, or database.
- Do not add Platform billing, credential copying, token switching, or reset-credit redemption.
- Consult current primary documentation before using an external SDK/API/library.
- Preserve unrelated dirty changes.
- Use `apply_patch` for edits.
- Personally verify behavior before reporting success.

## Verification

At minimum:

1. Run focused tests.
2. Run the smallest relevant compile/build gate.
3. Run `git diff --check`.
4. Confirm every changed path is assigned.
5. Search changed output and fixtures for sensitive auth data where relevant.

The PM runs batch-wide builds and tests after integration.

## Commit

Create one cohesive local commit on your assigned branch. Do not push or open a PR unless the PM explicitly changes this instruction.

## Completion Report

Return:

- Phase and Linear identifier.
- Outcome in one sentence.
- Commit SHA.
- Exact files created and modified.
- Interfaces/types/functions added or changed.
- Test commands and results.
- Acceptance evidence item by item.
- Migration, compatibility, security, or follow-on notes.
- Any requested scope expansion not performed.
- Any genuinely new decision or blocker.

Do not edit PM state; the PM records your result centrally.
