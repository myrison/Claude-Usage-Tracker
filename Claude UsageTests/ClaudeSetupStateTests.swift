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
}
