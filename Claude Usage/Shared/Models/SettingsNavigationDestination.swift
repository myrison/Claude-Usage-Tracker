import Foundation

/// A provider-neutral request for a specific settings destination.
///
/// Menu and status-item code can issue these requests without depending on the
/// concrete settings sidebar. The settings composition root owns the mapping to
/// its current view hierarchy.
enum SettingsNavigationDestination: Equatable, Hashable, Sendable {
    case defaultView
    case providerAccount(profileID: UUID)
    case appearance(profileID: UUID)
    case general(profileID: UUID)
    case history(profileID: UUID)
    /// Settings → Claude Account for one Claude profile. Browser and
    /// terminal sign-in repairs deliberately converge on this destination.
    case claudeAccount(profileID: UUID)
    case manageProfiles
}

/// Shared with the UI-test bootstrap so its routing switch is covered by the
/// ordinary unit-test target even though the bootstrap file is compiled only
/// in UI-testing configurations.
enum UITestSettingsRoute {
    static func recordedAction(
        for destination: SettingsNavigationDestination
    ) -> String {
        switch destination {
        case .providerAccount: return "settings.account"
        case .appearance: return "settings.appearance"
        case .claudeAccount: return "settings.claude_account"
        case .manageProfiles: return "settings.profiles"
        case .defaultView: return "settings.default"
        case .general: return "settings.general"
        case .history: return "settings.history"
        }
    }
}
