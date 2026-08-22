import Foundation

/// Determines whether a claude.ai organization is a single-person
/// organization (a personal Max/Pro subscription, where the org IS the user)
/// or a shared one (Team/Enterprise, where org-scoped figures belong to the
/// company rather than to the signed-in member).
///
/// Only the extra-usage scope depends on this today: `/organizations/{id}/
/// overage_spend_limit` reports the whole organization's spend, which is the
/// individual's own spend precisely when the organization has one member.
///
/// Shapes observed on a live five-organization account (2026-08-22):
///
/// | kind             | `capabilities`                            | `raven_type`   |
/// |------------------|-------------------------------------------|----------------|
/// | personal Max     | `["chat", "claude_max"]`                  | `nil`          |
/// | Team             | `["chat", "raven"]`                       | `"team"`       |
/// | Enterprise       | `["raven_enterprise", "raven", "chat", …]`| `"enterprise"` |
/// | console/API only | `["api"]`                                 | `nil`          |
///
/// "raven" is Anthropic's internal name for Team/Enterprise. Note that the
/// equivalent field on `api.anthropic.com/api/oauth/profile` is spelled
/// differently — `organization_type`, with values `"claude_max"` and
/// `"claude_team"` — so do not assume one endpoint's vocabulary applies to
/// the other.
enum ClaudeOrganizationClassifier {
    /// Capabilities that mark an organization as shared (Team/Enterprise).
    private static let sharedCapabilities: Set<String> = ["raven", "raven_enterprise"]

    /// Capabilities that mark an organization as one person's subscription.
    private static let personalCapabilities: Set<String> = ["claude_max", "claude_pro"]

    /// The capability an organization must have for any Claude subscription
    /// usage to exist against it. Console/API-only organizations lack it.
    static let chatCapability = "chat"

    /// - Returns: `true` personal, `false` shared, `nil` indeterminate.
    ///
    /// Both `nil` and `false` must be treated as organization-wide by callers:
    /// showing a company figure labelled as one person's is the failure this
    /// exists to prevent, so "unknown" errs toward the wider label.
    static func isPersonal(_ info: ClaudeAPIService.AccountInfo) -> Bool? {
        // Shared organizations are identified by `raven_type` when present,
        // and by the "raven" capabilities otherwise. Checked first so an
        // Enterprise org that also lists a personal-looking capability is
        // never misread as an individual's.
        if info.ravenType != nil {
            return false
        }
        if !sharedCapabilities.isDisjoint(with: info.capabilities) {
            return false
        }
        if !personalCapabilities.isDisjoint(with: info.capabilities) {
            return true
        }
        // Console/API-only organizations (`["api"]`) and anything unrecognized:
        // no personal Claude subscription is known to sit behind them.
        return nil
    }

    /// Whether the organization can carry Claude subscription usage at all.
    ///
    /// The `/organizations` list mixes Claude organizations with console/API
    /// organizations. The latter have no usage, no limits and no extra-usage
    /// budget, so binding a profile to one produces nothing but failed
    /// requests.
    static func isChatCapable(_ info: ClaudeAPIService.AccountInfo) -> Bool {
        info.capabilities.contains(chatCapability)
    }
}
