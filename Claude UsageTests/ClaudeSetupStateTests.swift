import XCTest
@testable import Claude_Usage

final class ClaudeSetupStateTests: HostedAppTestCase {
    func testCompleteWhenBrowserAndTerminalSignInsArePresent() {
        let profile = Profile(
            name: "Complete",
            claudeSessionKey: "session-key",
            organizationId: "organization-id",
            cliCredentialsJSON: "terminal-sign-in"
        )

        XCTAssertEqual(ClaudeSetupState.of(profile), .complete)
    }

    func testBrowserOnlyWhenOnlyBrowserSignInIsPresent() {
        let profile = Profile(
            name: "Browser only",
            claudeSessionKey: "session-key",
            organizationId: "organization-id"
        )

        XCTAssertEqual(ClaudeSetupState.of(profile), .browserOnly)
    }

    func testTerminalOnlyWhenOnlyTerminalSignInIsPresent() {
        let profile = Profile(
            name: "Terminal only",
            hasCliAccount: true
        )

        XCTAssertEqual(ClaudeSetupState.of(profile), .terminalOnly)
    }

    func testNoneWhenNeitherSignInIsPresent() {
        let profile = Profile(name: "Not set up")

        XCTAssertEqual(ClaudeSetupState.of(profile), .none)
    }

    func testOnlyTerminalOnlyClaudeProfilesNeedPersistentAttention() {
        let terminalOnly = Profile(
            name: "Terminal",
            cliCredentialsJSON: "{}",
            hasCliAccount: true
        )
        let browserOnly = Profile(
            name: "Browser",
            claudeSessionKey: "session",
            organizationId: "org"
        )
        let complete = Profile(
            name: "Complete",
            claudeSessionKey: "session",
            organizationId: "org",
            cliCredentialsJSON: "{}",
            hasCliAccount: true
        )
        let codex = Profile(
            name: "Codex",
            providerConfiguration: .codex(
                CodexProfileConfiguration(linkedHome: nil)
            ),
            cliCredentialsJSON: "{}",
            hasCliAccount: true
        )

        XCTAssertTrue(
            ClaudeAccountAttention.isSetupIncomplete(terminalOnly)
        )
        XCTAssertFalse(
            ClaudeAccountAttention.isSetupIncomplete(browserOnly)
        )
        XCTAssertFalse(
            ClaudeAccountAttention.isSetupIncomplete(complete)
        )
        XCTAssertFalse(
            ClaudeAccountAttention.isSetupIncomplete(codex)
        )
    }

    func testTerminalSummaryMarksExpiredAndTokenlessSignInsAsUnhealthy() {
        let expired = Profile(
            name: "Expired",
            claudeSessionKey: "browser",
            organizationId: "org",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"old","expiresAt":1}}"#,
            hasCliAccount: true
        )
        let tokenless = Profile(
            name: "Signed out",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":""}}"#,
            hasCliAccount: true
        )

        XCTAssertEqual(
            ClaudeAccountView.terminalSummaryHealth(expired),
            .needsAttention
        )
        XCTAssertEqual(
            ClaudeAccountView.terminalSummaryHealth(tokenless),
            .needsAttention
        )
    }

    func testTerminalSummaryOnlyUsesGreenForUsableSignIns() {
        let valid = #"{"claudeAiOauth":{"accessToken":"working"}}"#
        let complete = Profile(
            name: "Complete",
            claudeSessionKey: "browser",
            organizationId: "org",
            cliCredentialsJSON: valid,
            hasCliAccount: true
        )
        let terminalOnly = Profile(
            name: "Terminal",
            cliCredentialsJSON: valid,
            hasCliAccount: true
        )

        XCTAssertEqual(
            ClaudeAccountView.terminalSummaryHealth(complete),
            .working
        )
        XCTAssertEqual(
            ClaudeAccountView.terminalSummaryHealth(terminalOnly),
            .workingNotRenewable
        )
    }

    func testBrowserCredentialSaveMetadataIsOptionalAndPersists() throws {
        let legacy = Profile(name: "Before metadata")
        let legacyRoundTrip = try JSONDecoder().decode(
            Profile.self,
            from: JSONEncoder().encode(legacy)
        )
        XCTAssertNil(legacyRoundTrip.claudeBrowserCredentialSavedAt)

        let timestamp = Date(timeIntervalSinceReferenceDate: 8_400)
        let current = Profile(
            name: "With metadata",
            claudeBrowserCredentialSavedAt: timestamp
        )
        let currentRoundTrip = try JSONDecoder().decode(
            Profile.self,
            from: JSONEncoder().encode(current)
        )
        XCTAssertEqual(
            currentRoundTrip.claudeBrowserCredentialSavedAt,
            timestamp
        )
    }

    func testBrowserDetailNeverSubstitutesLastUsedForUnknownSaveTime() {
        let activityTime = Date(timeIntervalSinceReferenceDate: 7_700)
        let legacy = Profile(
            name: "Legacy",
            organizationId: "org",
            lastUsedAt: activityTime
        )
        let detail = ClaudeBrowserCredentialDetail(profile: legacy)

        XCTAssertEqual(detail.organization, "org")
        XCTAssertNil(detail.savedAt)
        XCTAssertNotEqual(detail.savedAt, legacy.lastUsedAt)
    }

    func testSessionOnlyWarningIsScopedToDisplayedProfile() {
        let displayed = UUID()
        let other = UUID()

        XCTAssertTrue(
            ClaudeAccountView.showsBrowserCredentialNotSavedWarning(
                profileID: displayed,
                sessionOnlyProfileIDs: [displayed, other]
            )
        )
        XCTAssertFalse(
            ClaudeAccountView.showsBrowserCredentialNotSavedWarning(
                profileID: displayed,
                sessionOnlyProfileIDs: [other]
            )
        )
    }

    @MainActor
    func testDurableBrowserSaveStampsExactSaveTime() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 9_100)
        let profile = Profile(name: "Browser save")
        let store = retain(makeIsolatedProfileStore())
        try seedProfilesForTesting([profile], in: store)
        let manager = retain(
            ProfileManager(profileStore: store, now: { timestamp })
        )
        manager.loadProfiles()

        try manager.saveCredentials(
            for: profile.id,
            credentials: ProfileCredentials(
                claudeSessionKey: "session",
                organizationId: "org"
            ),
            browserCredentialSave: true
        )

        XCTAssertEqual(
            manager.profiles.first?.claudeBrowserCredentialSavedAt,
            timestamp
        )
        XCTAssertEqual(
            store.loadProfiles().first?.claudeBrowserCredentialSavedAt,
            timestamp
        )
    }

    @MainActor
    func testSessionOnlyBrowserSaveStampsOnlyAfterRetrySucceeds() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 9_200)
        let profile = Profile(name: "Retry save")
        let secrets = RetryableBrowserSecretStore()
        let store = retain(
            makeIsolatedProfileStore(
                defaults: IsolatedProfileDefaults(),
                secretStore: secrets
            )
        )
        try seedProfilesForTesting([profile], in: store)
        let manager = retain(
            ProfileManager(profileStore: store, now: { timestamp })
        )
        manager.loadProfiles()

        secrets.refusesWrites = true
        try manager.saveCredentials(
            for: profile.id,
            credentials: ProfileCredentials(
                claudeSessionKey: "session",
                organizationId: "org"
            ),
            acceptingSessionOnly: true,
            browserCredentialSave: true
        )
        XCTAssertNil(
            manager.profiles.first?.claudeBrowserCredentialSavedAt
        )
        XCTAssertTrue(
            manager.sessionOnlyCredentialProfileIDs.contains(profile.id)
        )

        secrets.refusesWrites = false
        XCTAssertTrue(
            manager.retrySessionOnlyCredentialSave(profileID: profile.id)
        )
        XCTAssertEqual(
            manager.profiles.first?.claudeBrowserCredentialSavedAt,
            timestamp
        )
    }
}

private final class RetryableBrowserSecretStore: ProfileSecretStore {
    enum Refusal: Error { case expected }
    var refusesWrites = false
    private var values: [ProfileSecretLocator: String] = [:]

    func read(
        _ locator: ProfileSecretLocator
    ) throws -> ProfileSecretReadResult {
        values[locator].map(ProfileSecretReadResult.value) ?? .absent
    }

    func write(_ value: String, to locator: ProfileSecretLocator) throws {
        if refusesWrites { throw Refusal.expected }
        values[locator] = value
    }

    func delete(_ locator: ProfileSecretLocator) throws {
        values.removeValue(forKey: locator)
    }
}
