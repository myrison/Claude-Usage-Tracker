import Foundation
import UsageCore

/// Pure inputs supplied by the app when normalizing a previously fetched
/// `ClaudeUsage` value.
///
/// Account, health, and freshness are explicit so this mapping never reaches
/// into profile, credential, refresh, or lifecycle singletons.
struct ClaudeUsageProviderContext: Equatable {
    var account: ProviderAccount?
    var health: ProviderHealth
    var fetchedAt: Date
    var staleAt: Date?

    init(
        account: ProviderAccount? = nil,
        health: ProviderHealth,
        fetchedAt: Date,
        staleAt: Date? = nil
    ) {
        self.account = account
        self.health = health
        self.fetchedAt = fetchedAt
        self.staleAt = staleAt
    }
}

/// Characterization seam from the app's existing Claude subscription model to
/// provider-neutral UsageCore data.
///
/// This type intentionally does not conform to `UsageProvider`: fetching,
/// authentication, cancellation, and profile-keyed refresh ownership remain in
/// the app and are introduced by the provider-aware refresh work. The adapter
/// only maps data already obtained by those services. It also deliberately
/// excludes the separate `APIUsage` Platform-billing model.
enum ClaudeUsageProviderAdapter {
    static let capabilities = ProviderCapabilities([
        .account: .available,
        .health: .available,
        .usageLimits: .available,
        .usageSummary: .unavailable,
        .credits: .available,
        .resetCredits: .unavailable,
        .interactiveLogin: .unavailable,
        .automaticSessionStart: .available,
        .automaticProfileSwitch: .available,
        .usageHistory: .available,
        .usageNotifications: .available,
        .cliAccountSync: .available,
        .apiBilling: .available
    ])

    /// Claude's API only ever reports utilization *percentages* for the
    /// session/weekly/model windows below — it does not expose absolute
    /// token counts, and without knowing the user's plan tier there is no
    /// reliable token limit to divide against. Any token count previously
    /// derived from `percentage * assumedLimit` was fabricated, not real
    /// usage data. So every Claude `UsageWindow` here intentionally carries
    /// `quantity: nil`; the UI renders percentage + reset time only. (The
    /// "extra-usage" currency window below is unrelated real monetary data
    /// and is unaffected.)
    static func makeReport(
        from usage: ClaudeUsage,
        context: ClaudeUsageProviderContext
    ) throws -> UsageReport {
        var groups = [
            try UsageLimitGroup(
                id: UsageLimitGroupID("subscription"),
                windows: [
                    try UsageWindow(
                        id: UsageWindowID("session"),
                        // Match ClaudeUsage.effectiveSessionPercentage without
                        // its implicit Date() dependency.
                        usedPercentage: usage.sessionResetTime < context.fetchedAt
                            ? 0
                            : usage.sessionPercentage,
                        quantity: nil,
                        resetsAt: usage.sessionResetTime,
                        duration: Constants.sessionWindow
                    ),
                    try UsageWindow(
                        id: UsageWindowID("weekly"),
                        usedPercentage: usage.weeklyPercentage,
                        quantity: nil,
                        resetsAt: usage.weeklyResetTime,
                        duration: Constants.weeklyWindow
                    )
                ]
            )
        ]

        // Preserve the current app's model-window availability semantics:
        // Opus and Sonnet are present when their token fields indicate that the
        // API supplied the window. Fable has a dedicated availability flag so
        // a supported 0% window remains visible immediately after reset.
        if usage.opusWeeklyTokensUsed > 0 {
            groups.append(
                try modelGroup(
                    id: "opus",
                    usedPercentage: usage.opusWeeklyPercentage,
                    tokensUsed: usage.opusWeeklyTokensUsed,
                    resetsAt: nil
                )
            )
        }

        if usage.sonnetWeeklyTokensUsed > 0 {
            groups.append(
                try modelGroup(
                    id: "sonnet",
                    usedPercentage: usage.sonnetWeeklyPercentage,
                    tokensUsed: usage.sonnetWeeklyTokensUsed,
                    resetsAt: usage.sonnetWeeklyResetTime
                )
            )
        }

        if usage.fableWeeklyLimitAvailable {
            groups.append(
                try modelGroup(
                    id: "fable",
                    usedPercentage: usage.fableWeeklyPercentage,
                    tokensUsed: usage.fableWeeklyTokensUsed,
                    resetsAt: usage.fableWeeklyResetTime
                )
            )
        }

        if let used = usage.costUsed,
           let limit = usage.costLimit,
           let rawCurrency = usage.costCurrency,
           limit > 0 {
            let currency = try UsageCurrencyCode(rawCurrency)
            groups.append(
                try UsageLimitGroup(
                    id: UsageLimitGroupID("extra-usage"),
                    displayName: extraUsageDisplayName(for: usage.costScope),
                    windows: [
                        try UsageWindow(
                            id: UsageWindowID("current"),
                            usedPercentage: used / limit * 100,
                            quantity: try UsageQuantity(
                                // ClaudeUsage stores monetary values in minor
                                // currency units; UsageCore carries display
                                // values in major units with an explicit code.
                                used: used / 100,
                                limit: limit / 100,
                                unit: .currency,
                                currencyCode: currency
                            )
                        )
                    ]
                )
            )
        }

        var credits: [UsageCredit] = []
        if let balance = usage.overageBalance,
           let rawCurrency = usage.overageBalanceCurrency {
            credits.append(
                try UsageCredit(
                    id: UsageMetricID("overage-balance"),
                    displayName: overageBalanceDisplayName(for: usage.costScope),
                    balance: balance / 100,
                    unit: .currency,
                    currencyCode: UsageCurrencyCode(rawCurrency)
                )
            )
        }

        return try UsageReport(
            providerID: .claude,
            account: context.account,
            health: context.health,
            limitGroups: groups,
            credits: credits,
            sourceUpdatedAt: usage.lastUpdated,
            fetchedAt: context.fetchedAt,
            staleAt: context.staleAt
        )
    }

    /// Header for the extra-usage group.
    ///
    /// The amounts come from an organization-scoped endpoint, so on a Team or
    /// Enterprise account they are the company's spend and not the viewer's.
    /// An unclassified organization (`nil`) gets the same wider label: saying
    /// "organization" about one person is mildly wrong, saying nothing about a
    /// whole company's spend sitting under someone's personal bars is not.
    /// The organization's own name is deliberately absent — the popover keeps
    /// names out of prose and has no width for them.
    static func extraUsageDisplayName(
        for scope: ClaudeUsage.ExtraUsageScope?
    ) -> String {
        switch scope {
        case .personal:
            return ProviderUILocalization.text(
                "menubar.extra_usage",
                fallback: "Extra Usage"
            )
        case .organization, nil:
            return ProviderUILocalization.text(
                "menubar.extra_usage_organization",
                fallback: "Extra Usage · Organization"
            )
        }
    }

    /// Label for the overage credit balance.
    ///
    /// `overage_credit_grant` is organization-scoped for the same reason
    /// `overage_spend_limit` is, so the remaining balance shown to a member of
    /// a Team or Enterprise account is the company's pool, not theirs. Scope
    /// wording is kept identical to the extra-usage group header so the two
    /// read as one fact rather than two.
    static func overageBalanceDisplayName(
        for scope: ClaudeUsage.ExtraUsageScope?
    ) -> String {
        switch scope {
        case .personal:
            return ProviderUILocalization.text(
                "menubar.overage_balance",
                fallback: "Credit Balance"
            )
        case .organization, nil:
            return ProviderUILocalization.text(
                "menubar.overage_balance_organization",
                fallback: "Credit Balance · Organization"
            )
        }
    }

    private static func modelGroup(
        id: String,
        usedPercentage: Double,
        tokensUsed: Int,
        resetsAt: Date?
    ) throws -> UsageLimitGroup {
        try UsageLimitGroup(
            id: UsageLimitGroupID(id),
            windows: [
                try UsageWindow(
                    id: UsageWindowID("weekly"),
                    usedPercentage: usedPercentage,
                    quantity: nil,
                    resetsAt: resetsAt,
                    duration: Constants.weeklyWindow
                )
            ]
        )
    }
}
