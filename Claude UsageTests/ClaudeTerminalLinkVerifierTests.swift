import XCTest
@testable import Claude_Usage

final class ClaudeTerminalLinkVerifierTests: XCTestCase {
    private let profileID = UUID()
    private let valid =
        #"{"claudeAiOauth":{"accessToken":"working"}}"#
    private let tokenless =
        #"{"claudeAiOauth":{"accessToken":""}}"#

    func testKeychainSuccessWinsWithoutReadingLinkedFile() throws {
        var calls: [String] = []
        let verifier = ClaudeTerminalLinkVerifier(
            syncKeychainToProfile: { _ in calls.append("keychain") },
            readLinkedAccountCredential: { _ in
                calls.append("file")
                return self.valid
            },
            persistLinkedAccountCredential: { _, _ in
                calls.append("persist")
            }
        )

        XCTAssertEqual(
            try verifier.verify(
                profileID: profileID,
                accountName: "account"
            ),
            .keychain
        )
        XCTAssertEqual(calls, ["keychain"])
    }

    func testAbsentKeychainFallsBackToValidLinkedFile() throws {
        var calls: [String] = []
        let verifier = ClaudeTerminalLinkVerifier(
            syncKeychainToProfile: { _ in
                calls.append("keychain")
                throw ClaudeCodeError.noCredentialsFound
            },
            readLinkedAccountCredential: { _ in
                calls.append("file")
                return self.valid
            },
            persistLinkedAccountCredential: { _, json in
                calls.append("persist")
                XCTAssertEqual(json, self.valid)
            }
        )

        XCTAssertEqual(
            try verifier.verify(
                profileID: profileID,
                accountName: "account"
            ),
            .linkedAccountFile
        )
        XCTAssertEqual(calls, ["keychain", "file", "persist"])
    }

    func testTokenlessLinkedFileIsRejectedAfterAbsentKeychain() {
        var persisted = false
        let verifier = ClaudeTerminalLinkVerifier(
            syncKeychainToProfile: { _ in
                throw ClaudeCodeError.noCredentialsFound
            },
            readLinkedAccountCredential: { _ in self.tokenless },
            persistLinkedAccountCredential: { _, _ in persisted = true }
        )

        XCTAssertThrowsError(
            try verifier.verify(
                profileID: profileID,
                accountName: "account"
            )
        ) { error in
            guard case ClaudeCodeError.noCredentialsFound = error else {
                return XCTFail("Expected noCredentialsFound, got \(error)")
            }
        }
        XCTAssertFalse(persisted)
    }

    func testKeychainFailureDoesNotSilentlyFallBack() {
        var readFile = false
        let verifier = ClaudeTerminalLinkVerifier(
            syncKeychainToProfile: { _ in
                throw ClaudeCodeError.keychainReadFailed(
                    exitCode: 1,
                    message: "denied"
                )
            },
            readLinkedAccountCredential: { _ in
                readFile = true
                return self.valid
            },
            persistLinkedAccountCredential: { _, _ in }
        )

        XCTAssertThrowsError(
            try verifier.verify(
                profileID: profileID,
                accountName: "account"
            )
        )
        XCTAssertFalse(readFile)
    }

    func testPresentButTokenlessKeychainDoesNotFallBackToFile() {
        var readFile = false
        let verifier = ClaudeTerminalLinkVerifier(
            syncKeychainToProfile: { _ in
                throw ClaudeCodeError.invalidJSON
            },
            readLinkedAccountCredential: { _ in
                readFile = true
                return self.valid
            },
            persistLinkedAccountCredential: { _, _ in }
        )

        XCTAssertThrowsError(
            try verifier.verify(
                profileID: profileID,
                accountName: "account"
            )
        ) { error in
            guard case ClaudeCodeError.invalidJSON = error else {
                return XCTFail("Expected invalidJSON, got \(error)")
            }
        }
        XCTAssertFalse(readFile)
    }

    func testOnlyVerifiedSourcesRenderTheReadyVerdict() {
        XCTAssertFalse(ClaudeTerminalLinkVerificationState.unverified.isReady)
        XCTAssertFalse(ClaudeTerminalLinkVerificationState.failed.isReady)
        XCTAssertTrue(
            ClaudeTerminalLinkVerificationState.ready(.keychain).isReady
        )
        XCTAssertTrue(
            ClaudeTerminalLinkVerificationState.ready(
                .linkedAccountFile
            ).isReady
        )
    }

    func testValidCredentialWithoutLinkedDirectoryOffersLinkNotResync() {
        let profile = Profile(
            name: "Detected login",
            cliCredentialsJSON: valid,
            hasCliAccount: true,
            cliAccountName: nil
        )

        XCTAssertEqual(
            ClaudeTerminalAccountActions.forProfile(profile),
            ClaudeTerminalAccountActions(
                primary: .link,
                canUnlink: false
            )
        )
    }
}

final class ClaudeAccountFrozenTargetTests: XCTestCase {
    func testTerminalSheetKeepsPresentedProfileAfterAnotherProfileIsShown() {
        let presented = Profile(name: "Presented")
        let newlyActive = Profile(name: "Newly active")
        let target = ClaudeAccountSheetTarget(id: presented.id)

        // Reordering models a profile-chip switch. Resolution remains by the
        // ID captured when the sheet was presented, never by list position or
        // whichever profile the surrounding page now displays.
        XCTAssertEqual(
            target.profile(in: [newlyActive, presented])?.id,
            presented.id
        )
    }

    func testBrowserAttemptAcceptsFrozenTargetAfterOtherProfileSwitch() {
        let presented = Profile(name: "Presented")
        let newlyActive = Profile(name: "Newly active")
        var state = WizardState(targetProfileID: presented.id)
        state.sessionKey = "captured-key"
        let generation = state.attempt.generation

        XCTAssertTrue(
            PersonalUsageAttemptGate.acceptsCompletion(
                wizardState: state,
                targetID: presented.id,
                generation: generation,
                key: "captured-key",
                profiles: [newlyActive, presented]
            )
        )
        XCTAssertFalse(
            PersonalUsageAttemptGate.acceptsCompletion(
                wizardState: state,
                targetID: newlyActive.id,
                generation: generation,
                key: "captured-key",
                profiles: [newlyActive, presented]
            )
        )
    }
}
