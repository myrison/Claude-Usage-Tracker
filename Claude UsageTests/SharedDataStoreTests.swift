import XCTest
@testable import Claude_Usage

final class SharedDataStoreTests: XCTestCase {

    var sharedDataStore: SharedDataStore!
    private var defaults: UserDefaults?
    private var defaultsSuiteName: String?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let (testDefaults, suiteName) = try HostedTestDefaults.defaults(
            "ClaudeUsageTests.SharedDataStoreTests"
        )
        HostedTestDefaults.reset(testDefaults, suiteName: suiteName)

        defaultsSuiteName = suiteName
        defaults = testDefaults
        sharedDataStore = SharedDataStore(defaults: testDefaults)
    }

    override func tearDownWithError() throws {
        if let defaults, let defaultsSuiteName {
            HostedTestDefaults.finish(defaults, suiteName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil

        try super.tearDownWithError()
    }

    // MARK: - Language Settings Tests

    func testLanguageCode() {
        sharedDataStore.saveLanguageCode("en")
        XCTAssertEqual(sharedDataStore.loadLanguageCode(), "en")

        sharedDataStore.saveLanguageCode("ko")
        XCTAssertEqual(sharedDataStore.loadLanguageCode(), "ko")

        sharedDataStore.saveLanguageCode("ja")
        XCTAssertEqual(sharedDataStore.loadLanguageCode(), "ja")
    }

    func testLanguageCodeNil() {
        XCTAssertNil(sharedDataStore.loadLanguageCode())
    }

    // MARK: - Setup Status Tests

    func testHasCompletedSetup() {
        sharedDataStore.saveHasCompletedSetup(false)
        XCTAssertFalse(sharedDataStore.hasCompletedSetup())

        sharedDataStore.saveHasCompletedSetup(true)
        XCTAssertTrue(sharedDataStore.hasCompletedSetup())
    }

    func testClaudeAccountUpgradeClassificationIsRecordedOnce() {
        let terminalOnlyID = UUID()
        let browserOnlyID = UUID()
        let terminalOnly = Profile(
            id: terminalOnlyID,
            name: "Legacy terminal",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"token"}}"#,
            hasCliAccount: true
        )
        let browserOnly = Profile(
            id: browserOnlyID,
            name: "Browser",
            claudeSessionKey: "session",
            organizationId: "org"
        )

        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce([
                terminalOnly, browserOnly
            ]),
            [terminalOnlyID]
        )
        XCTAssertTrue(
            sharedDataStore.wasTerminalOnlyAtClaudeAccountUpgrade(
                terminalOnlyID
            )
        )

        // A later profile must not be folded into the historical cohort.
        let later = Profile(
            name: "Later terminal",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"later"}}"#,
            hasCliAccount: true
        )
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce([later]),
            [terminalOnlyID]
        )
        XCTAssertFalse(
            sharedDataStore.wasTerminalOnlyAtClaudeAccountUpgrade(later.id)
        )
    }

    func testEmptyClaudeAccountUpgradeClassificationStillRunsOnlyOnce() {
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce([]),
            []
        )
        let later = Profile(
            name: "Later terminal",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"later"}}"#,
            hasCliAccount: true
        )
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce([later]),
            []
        )
        XCTAssertFalse(
            sharedDataStore.wasTerminalOnlyAtClaudeAccountUpgrade(later.id)
        )
    }

    func testNonAuthoritativeUpgradeClassificationDefersUntilRecovery() {
        let terminalOnly = Profile(
            name: "Recovered terminal",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"recovered"}}"#,
            hasCliAccount: true
        )

        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce(
                [terminalOnly],
                isAuthoritative: false
            ),
            []
        )
        XCTAssertFalse(
            defaults!.bool(forKey: "didClassifyClaudeAccountUpgradeV41")
        )
        XCTAssertNil(
            defaults!.object(
                forKey: "terminalOnlyClaudeAccountUpgradeProfileIDsV41"
            )
        )
        XCTAssertEqual(
            defaults!.stringArray(
                forKey: "claudeAccountUpgradeBoundaryProfileIDsV41"
            ),
            [terminalOnly.id.uuidString]
        )
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce(
                [terminalOnly],
                isAuthoritative: true
            ),
            [terminalOnly.id]
        )

        let later = Profile(
            name: "Later terminal",
            cliCredentialsJSON:
                #"{"claudeAiOauth":{"accessToken":"later"}}"#,
            hasCliAccount: true
        )
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce(
                [later],
                isAuthoritative: true
            ),
            [terminalOnly.id]
        )
        XCTAssertFalse(
            sharedDataStore.wasTerminalOnlyAtClaudeAccountUpgrade(later.id)
        )
    }

    func testUnreadableProfileMetadataDefersBoundaryCapture() {
        XCTAssertEqual(
            sharedDataStore.classifyClaudeAccountsForUpgradeOnce(
                [],
                isProfileIdentitySetAuthoritative: false,
                isAuthoritative: false
            ),
            []
        )
        XCTAssertNil(
            defaults!.object(
                forKey: "claudeAccountUpgradeBoundaryProfileIDsV41"
            )
        )
        XCTAssertFalse(
            defaults!.bool(forKey: "didClassifyClaudeAccountUpgradeV41")
        )
    }

    // MARK: - GitHub Star Prompt Tests

    func testFirstLaunchDate() {
        let testDate = Date()
        sharedDataStore.saveFirstLaunchDate(testDate)

        let loaded = sharedDataStore.loadFirstLaunchDate()
        XCTAssertNotNil(loaded)

        // Compare timestamps (allow 1 second difference for encoding/decoding)
        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testLastGitHubStarPromptDate() {
        let testDate = Date()
        sharedDataStore.saveLastGitHubStarPromptDate(testDate)

        let loaded = sharedDataStore.loadLastGitHubStarPromptDate()
        XCTAssertNotNil(loaded)

        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testHasStarredGitHub() {
        sharedDataStore.saveHasStarredGitHub(false)
        XCTAssertFalse(sharedDataStore.loadHasStarredGitHub())

        sharedDataStore.saveHasStarredGitHub(true)
        XCTAssertTrue(sharedDataStore.loadHasStarredGitHub())
    }

    func testNeverShowGitHubPrompt() {
        sharedDataStore.saveNeverShowGitHubPrompt(false)
        XCTAssertFalse(sharedDataStore.loadNeverShowGitHubPrompt())

        sharedDataStore.saveNeverShowGitHubPrompt(true)
        XCTAssertTrue(sharedDataStore.loadNeverShowGitHubPrompt())
    }

    func testShouldShowGitHubStarPrompt() {
        // Reset state
        sharedDataStore.saveHasStarredGitHub(false)
        sharedDataStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 3 days ago
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        sharedDataStore.saveFirstLaunchDate(threeDaysAgo)

        // Should show prompt (>2 days, not starred, not dismissed)
        XCTAssertTrue(sharedDataStore.shouldShowGitHubStarPrompt())

        // Mark as starred - should no longer show
        sharedDataStore.saveHasStarredGitHub(true)
        XCTAssertFalse(sharedDataStore.shouldShowGitHubStarPrompt())

        // Reset starred, set never show - should not show
        sharedDataStore.saveHasStarredGitHub(false)
        sharedDataStore.saveNeverShowGitHubPrompt(true)
        XCTAssertFalse(sharedDataStore.shouldShowGitHubStarPrompt())
    }

    func testShouldNotShowGitHubPromptWhenTooEarly() {
        // Reset state
        sharedDataStore.saveHasStarredGitHub(false)
        sharedDataStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 12 hours ago (less than 1 day threshold)
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 60 * 60)
        sharedDataStore.saveFirstLaunchDate(twelveHoursAgo)

        // Should NOT show prompt (< 1 day threshold)
        XCTAssertFalse(sharedDataStore.shouldShowGitHubStarPrompt())
    }

    func testResetGitHubStarPromptForTesting() {
        // Set some state
        sharedDataStore.saveHasStarredGitHub(true)
        sharedDataStore.saveNeverShowGitHubPrompt(true)
        sharedDataStore.saveLastGitHubStarPromptDate(Date())

        // Reset for testing
        sharedDataStore.resetGitHubStarPromptForTesting()

        // Should be reset
        XCTAssertFalse(sharedDataStore.loadHasStarredGitHub())
        XCTAssertFalse(sharedDataStore.loadNeverShowGitHubPrompt())
        XCTAssertNil(sharedDataStore.loadLastGitHubStarPromptDate())
    }
}
