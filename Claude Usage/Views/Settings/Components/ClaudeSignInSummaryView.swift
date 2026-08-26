//
//  ClaudeSignInSummaryView.swift
//  Claude Usage
//

import SwiftUI

/// A reusable summary of the browser and terminal sign-ins for a Claude profile.
///
/// The caller supplies live, context-specific detail text; this view owns the
/// shared verdict, row labels, and status presentation.
struct ClaudeSignInSummaryView: View {
    let state: ClaudeSetupState
    let browserDetail: String
    let terminalDetail: String
    let browserAction: ClaudeSignInSummaryAction?
    let terminalAction: ClaudeSignInSummaryAction?
    let terminalWorkingButNotRenewable: Bool

    init(
        state: ClaudeSetupState,
        browserDetail: String,
        terminalDetail: String,
        browserAction: ClaudeSignInSummaryAction? = nil,
        terminalAction: ClaudeSignInSummaryAction? = nil,
        terminalWorkingButNotRenewable: Bool = false
    ) {
        self.state = state
        self.browserDetail = browserDetail
        self.terminalDetail = terminalDetail
        self.browserAction = browserAction
        self.terminalAction = terminalAction
        self.terminalWorkingButNotRenewable =
            terminalWorkingButNotRenewable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            verdictBanner

            VStack(spacing: 0) {
                signInRow(
                    title: localized("claude_account.summary.browser.title"),
                    detail: browserDetail,
                    status: browserStatus
                )

                Divider()
                    .padding(.leading, Spacing.lg)

                signInRow(
                    title: localized("claude_account.summary.terminal.title"),
                    detail: terminalDetail,
                    status: terminalStatus
                )
            }
            .background(SettingsColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.radiusLarge)
                    .strokeBorder(SettingsColors.border, lineWidth: 0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verdictBanner: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: verdict.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(verdict.color)
                .accessibilityHidden(true)

            Text(localized(verdict.localizationKey))
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdict.color.opacity(verdict.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge))
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusLarge)
                .strokeBorder(verdict.color.opacity(0.24), lineWidth: 0.5)
        }
    }

    private func signInRow(
        title: String,
        detail: String,
        status: Status
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.sectionHeader)
                        .foregroundStyle(.primary)

                    statusPill(status)
                }

                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusPill(_ status: Status) -> some View {
        Text(localized(status.localizationKey))
            .font(Typography.badge)
            .foregroundStyle(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(status.color.opacity(0.28), lineWidth: 0.5)
            }
            .accessibilityLabel(localized(status.localizationKey))
    }

    private var browserStatus: Status {
        switch state {
        case .complete, .browserOnly:
            return .working
        case .terminalOnly, .none:
            return .missing
        }
    }

    private var terminalStatus: Status {
        if terminalWorkingButNotRenewable {
            return .workingNotRenewable
        }
        switch state {
        case .complete, .terminalOnly:
            return .working
        case .browserOnly, .none:
            return .notLinked
        }
    }

    private var verdict: Verdict {
        switch state {
        case .complete:
            return Verdict(
                localizationKey: "claude_account.summary.verdict.complete",
                icon: "checkmark.circle.fill",
                color: SettingsColors.success,
                backgroundOpacity: 0.10
            )
        case .browserOnly:
            return Verdict(
                localizationKey: "claude_account.summary.verdict.browser_only",
                icon: "info.circle.fill",
                color: SettingsColors.secondary,
                backgroundOpacity: 0.07
            )
        case .terminalOnly:
            return Verdict(
                localizationKey: "claude_account.summary.verdict.terminal_only",
                icon: "exclamationmark.triangle.fill",
                color: SettingsColors.error,
                backgroundOpacity: 0.09
            )
        case .none:
            return Verdict(
                localizationKey: "claude_account.summary.verdict.none",
                icon: "exclamationmark.circle.fill",
                color: SettingsColors.error,
                backgroundOpacity: 0.09
            )
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct Verdict {
    let localizationKey: String
    let icon: String
    let color: Color
    let backgroundOpacity: Double
}

private enum Status {
    case working
    case workingNotRenewable
    case notLinked
    case missing

    var localizationKey: String {
        switch self {
        case .working:
            return "claude_account.summary.status.working"
        case .workingNotRenewable:
            return "claude_account.summary.status.working_not_renewable"
        case .notLinked:
            return "claude_account.summary.status.not_linked"
        case .missing:
            return "claude_account.summary.status.missing"
        }
    }

    var color: Color {
        switch self {
        case .working:
            return SettingsColors.success
        case .workingNotRenewable:
            return SettingsColors.error
        case .notLinked:
            return SettingsColors.secondary
        case .missing:
            return SettingsColors.error
        }
    }
}
