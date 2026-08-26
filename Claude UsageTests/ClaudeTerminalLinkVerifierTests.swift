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
            syncToProfile: { _ in calls.append("keychain") },
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
            syncToProfile: { _ in
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
            syncToProfile: { _ in
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
            syncToProfile: { _ in
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
}
