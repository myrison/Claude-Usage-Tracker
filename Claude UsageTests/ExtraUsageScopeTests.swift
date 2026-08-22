import Foundation
import XCTest
@testable import Claude_Usage

/// The extra-usage figures come from an organization-scoped endpoint, so the
/// popover must say whose spend it is showing. These tests pin the scope field
/// through persistence and the popover label, and pin the organization
/// selection that feeds it.
final class ExtraUsageScopeTests: XCTestCase {

    // MARK: - Persistence compatibility

    /// Usage history written before the scope existed must still decode. A
    /// record without the key is not "personal" — it predates the question.
    func testUsageRecordWithoutScopeKeyDecodesWithNilScope() throws {
        let json = """
        {
            "sessionTokensUsed": 1250,
            "sessionLimit": 10000,
            "sessionPercentage": 12.5,
            "sessionResetTime": 20000,
            "weeklyTokensUsed": 480000,
            "weeklyLimit": 1000000,
            "weeklyPercentage": 48,
            "weeklyResetTime": 30000,
            "opusWeeklyTokensUsed": 0,
            "opusWeeklyPercentage": 0,
            "sonnetWeeklyTokensUsed": 0,
            "sonnetWeeklyPercentage": 0,
            "costUsed": 259316,
            "costLimit": 500000,
            "costCurrency": "USD",
            "lastUpdated": 10000,
            "userTimezone": {"identifier": "GMT"}
        }
        """

        let usage = try JSONDecoder().decode(
            ClaudeUsage.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(usage.costScope)
        XCTAssertEqual(usage.costUsed, 259_316)
        XCTAssertEqual(usage.costLimit, 500_000)
    }

    func testScopeSurvivesAnEncodeDecodeRoundTrip() throws {
        var usage = ClaudeUsage.empty
        usage.costUsed = 259_316
        usage.costLimit = 500_000
        usage.costCurrency = "USD"
        usage.costScope = .organization

        let decoded = try JSONDecoder().decode(
            ClaudeUsage.self,
            from: JSONEncoder().encode(usage)
        )

        XCTAssertEqual(decoded.costScope, .organization)
    }

    // MARK: - English catalog

    /// The scope word is the whole point of the label, so pin the English
    /// text itself rather than only the key lookup.
    func testEnglishCatalogSpellsOutBothScopes() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "en", ofType: "lproj")
        )
        let english = try XCTUnwrap(Bundle(path: path))

        XCTAssertEqual(
            english.localizedString(
                forKey: "menubar.extra_usage",
                value: nil,
                table: nil
            ),
            "Extra Usage"
        )
        XCTAssertEqual(
            english.localizedString(
                forKey: "menubar.extra_usage_organization",
                value: nil,
                table: nil
            ),
            "Extra Usage · Organization"
        )
    }

    // MARK: - Organization selection

    /// `organizations.first!` used to crash the app when claude.ai returned no
    /// organizations at all.
    @MainActor
    func testFetchOrganizationIdThrowsOnAnEmptyOrganizationList() async throws {
        StubOrganizationsURLProtocol.responseBody = Data("[]".utf8)
        URLProtocol.registerClass(StubOrganizationsURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubOrganizationsURLProtocol.self)
            StubOrganizationsURLProtocol.responseBody = nil
        }

        let service = makeIsolatedService()

        do {
            let organizationId = try await service.fetchOrganizationId(
                sessionKey: "sk-ant-sid01-fixture-session-key-value"
            )
            XCTFail("Expected a thrown error, got \(organizationId)")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiParsingFailed)
        }
    }

    /// A profile with no stored organization adopts the only one on offer.
    @MainActor
    func testFetchOrganizationIdAdoptsASingleOrganization() async throws {
        StubOrganizationsURLProtocol.responseBody = Data(
            """
            [{"uuid": "org-1", "name": "Acme", "capabilities": ["chat"]}]
            """.utf8
        )
        URLProtocol.registerClass(StubOrganizationsURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubOrganizationsURLProtocol.self)
            StubOrganizationsURLProtocol.responseBody = nil
        }

        let service = makeIsolatedService()

        let organizationId = try await service.fetchOrganizationId(
            sessionKey: "sk-ant-sid01-fixture-session-key-value"
        )

        XCTAssertEqual(organizationId, "org-1")
    }

    /// The `/organizations` list mixes Claude organizations with console/API
    /// ones. On a real account an API-only organization was the FIRST entry,
    /// so taking `.first` bound the profile to an organization that can never
    /// report usage.
    @MainActor
    func testFetchOrganizationIdSkipsApiOnlyOrganizations() async throws {
        StubOrganizationsURLProtocol.responseBody = Data(
            """
            [{"uuid": "console-org", "name": "Acme", "capabilities": ["api"]},
             {"uuid": "claude-org", "name": "Acme", "capabilities": ["chat", "raven"],
              "raven_type": "team"}]
            """.utf8
        )
        URLProtocol.registerClass(StubOrganizationsURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubOrganizationsURLProtocol.self)
            StubOrganizationsURLProtocol.responseBody = nil
        }

        let service = makeIsolatedService()

        let organizationId = try await service.fetchOrganizationId(
            sessionKey: "sk-ant-sid01-fixture-session-key-value"
        )

        XCTAssertEqual(organizationId, "claude-org")
    }

    /// An account with only console organizations has no Claude usage to show,
    /// and must say so rather than bind to one and fail every later request.
    @MainActor
    func testFetchOrganizationIdThrowsWhenNoOrganizationHasChat() async throws {
        StubOrganizationsURLProtocol.responseBody = Data(
            """
            [{"uuid": "console-a", "name": "Acme", "capabilities": ["api"]},
             {"uuid": "console-b", "name": "Acme", "capabilities": ["api"]}]
            """.utf8
        )
        URLProtocol.registerClass(StubOrganizationsURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubOrganizationsURLProtocol.self)
            StubOrganizationsURLProtocol.responseBody = nil
        }

        let service = makeIsolatedService()

        do {
            let organizationId = try await service.fetchOrganizationId(
                sessionKey: "sk-ant-sid01-fixture-session-key-value"
            )
            XCTFail("Expected a thrown error, got \(organizationId)")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiParsingFailed)
        }
    }

    // MARK: - Classifier
    //
    // Fixtures are the shapes observed on a live five-organization account on
    // 2026-08-22, not invented ones.

    func testClassifierCallsAPersonalMaxOrganizationPersonal() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.isPersonal(
                .init(
                    uuid: "org-max",
                    name: "someone@example.com's Organization",
                    capabilities: ["chat", "claude_max"],
                    ravenType: nil
                )
            ),
            true
        )
    }

    func testClassifierCallsATeamOrganizationShared() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.isPersonal(
                .init(
                    uuid: "org-team",
                    name: "Acme",
                    capabilities: ["chat", "raven"],
                    ravenType: "team"
                )
            ),
            false
        )
    }

    func testClassifierCallsAnEnterpriseOrganizationShared() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.isPersonal(
                .init(
                    uuid: "org-ent",
                    name: "Acme-Enterprise",
                    capabilities: [
                        "raven_enterprise", "raven", "chat",
                        "analytics_api", "compliance_logging"
                    ],
                    ravenType: "enterprise"
                )
            ),
            false
        )
    }

    /// A console organization has no personal subscription behind it, so it is
    /// neither — and "neither" must not collapse into "personal".
    func testClassifierReportsIndeterminateForAnApiOnlyOrganization() {
        XCTAssertNil(
            ClaudeOrganizationClassifier.isPersonal(
                .init(
                    uuid: "console-org",
                    name: "Acme",
                    capabilities: ["api"],
                    ravenType: nil
                )
            )
        )
    }

    /// The capability list alone is enough when `raven_type` is missing, so a
    /// payload that omits the field is still classified correctly.
    func testClassifierUsesCapabilitiesWhenRavenTypeIsAbsent() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.isPersonal(
                .init(
                    uuid: "org-team",
                    name: "Acme",
                    capabilities: ["chat", "raven"],
                    ravenType: nil
                )
            ),
            false
        )
    }

    func testChatCapabilityGatesUsableOrganizations() {
        XCTAssertTrue(
            ClaudeOrganizationClassifier.isChatCapable(
                .init(uuid: "a", name: "A", capabilities: ["chat", "raven"])
            )
        )
        XCTAssertFalse(
            ClaudeOrganizationClassifier.isChatCapable(
                .init(uuid: "b", name: "B", capabilities: ["api"])
            )
        )
    }

    // MARK: - Labels

    /// Charlie's reported figure, and the one reproduced on our own team.
    func testOrganizationScopedFiguresAreLabelledAsSuch() {
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.extraUsageDisplayName(for: .organization),
            "Extra Usage · Organization"
        )
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.extraUsageDisplayName(for: nil),
            "Extra Usage · Organization"
        )
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.extraUsageDisplayName(for: .personal),
            "Extra Usage"
        )
    }

    /// The credit balance comes from a sibling organization-scoped endpoint
    /// and carries the same scope wording.
    func testCreditBalanceCarriesTheSameScopeWording() {
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.overageBalanceDisplayName(for: .organization),
            "Credit Balance · Organization"
        )
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.overageBalanceDisplayName(for: nil),
            "Credit Balance · Organization"
        )
        XCTAssertEqual(
            ClaudeUsageProviderAdapter.overageBalanceDisplayName(for: .personal),
            "Credit Balance"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func makeIsolatedService() -> ClaudeAPIService {
        let defaults = UserDefaults(
            suiteName: "ExtraUsageScopeTests-\(UUID().uuidString)"
        )!
        let store = ProfileStore(
            defaults: defaults,
            secretStore: UnusedProfileSecretStore()
        )
        // Deliberately not loaded: with no profiles there is no stored
        // organization to short-circuit the lookup under test.
        let manager = ProfileManager(profileStore: store)
        return ClaudeAPIService(profileManager: manager)
    }
}

/// Serves one canned `/organizations` body to `URLSession.shared` for the
/// duration of a single test.
private nonisolated final class StubOrganizationsURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        responseBody != nil
            && request.url?.path.hasSuffix("/organizations") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let body = Self.responseBody,
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The organization lookup never reaches secure storage: the session key is
/// passed in directly. Any call here is a test setup mistake.
private nonisolated final class UnusedProfileSecretStore: ProfileSecretStore {
    func read(_ locator: ProfileSecretLocator) throws -> ProfileSecretReadResult {
        .absent
    }

    func write(_ value: String, to locator: ProfileSecretLocator) throws {
        XCTFail("Unexpected secret write for \(locator.safeDescription)")
    }

    func delete(_ locator: ProfileSecretLocator) throws {
        XCTFail("Unexpected secret delete for \(locator.safeDescription)")
    }
}
