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

    // MARK: - Organization picker
    //
    // The five organizations below are the exact payload the maintainer's
    // claude.ai session key returns (2026-08-22). Three of them are named
    // "Revenium"; picking the wrong one leaves the popover permanently
    // reading "Usage is currently unavailable".

    /// Server order, verbatim.
    private var liveOrganizations: [ClaudeAPIService.AccountInfo] {
        [
            .init(
                uuid: "c8f80080-51bc-46fb-b04f-69eabd48e1ec",
                name: "Revenium",
                capabilities: ["api"]
            ),
            .init(
                uuid: "a3bd5eb8-7a36-4125-b309-e1cbc95fde5e",
                name: "Revenium",
                capabilities: ["api"]
            ),
            .init(
                uuid: "ef142542-c027-47d7-9b93-80f8415554a9",
                name: "jason.cumberland@revenium.io's Organization",
                capabilities: ["chat", "claude_max"]
            ),
            .init(
                uuid: "665a6475-2eb6-4da8-8379-d5529d283568",
                name: "Revenium",
                capabilities: ["chat", "raven"],
                ravenType: "team"
            ),
            .init(
                uuid: "9d473653-df6e-4313-9a9c-2128ab10ad0a",
                name: "Revenium-Enterprise",
                capabilities: [
                    "raven_enterprise", "raven", "chat",
                    "analytics_api", "compliance_logging"
                ],
                ravenType: "enterprise"
            )
        ]
    }

    /// The name alone cannot tell three "Revenium" rows apart, so the kind
    /// label is what the picker is relying on.
    func testDescriptorNamesTheKindOfEveryLiveOrganization() {
        XCTAssertEqual(
            liveOrganizations.map(ClaudeOrganizationClassifier.descriptor),
            [
                "API only · no Claude subscription",
                "API only · no Claude subscription",
                "Personal · Max",
                "Team",
                "Enterprise"
            ]
        )
    }

    /// An Enterprise organization also carries "raven"; checking Team first
    /// would label it "Team".
    func testDescriptorPrefersEnterpriseOverTeamWhenBothSignalsArePresent() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.descriptor(
                .init(
                    uuid: "org-ent",
                    name: "Acme",
                    capabilities: ["raven_enterprise", "raven", "chat"],
                    ravenType: "enterprise"
                )
            ),
            "Enterprise"
        )
    }

    /// A chat organization with no recognized plan capability is still
    /// selectable, so it gets a neutral label rather than the API-only one.
    func testDescriptorFallsBackToUnknownForAnUnrecognizedChatOrganization() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.descriptor(
                .init(uuid: "org-x", name: "Acme", capabilities: ["chat"])
            ),
            "Unknown"
        )
    }

    func testDescriptorLabelsAProOrganization() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.descriptor(
                .init(
                    uuid: "org-pro",
                    name: "someone@example.com's Organization",
                    capabilities: ["chat", "claude_pro"]
                )
            ),
            "Personal · Pro"
        )
    }

    /// Usable organizations first, server order kept inside each group, and
    /// nothing dropped: an unusable row stays visible so the account holder
    /// can see why it cannot be chosen.
    func testPickerOrderPutsChatOrganizationsFirstAndKeepsServerOrder() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.pickerOrder(liveOrganizations)
                .map(\.uuid),
            [
                "ef142542-c027-47d7-9b93-80f8415554a9",
                "665a6475-2eb6-4da8-8379-d5529d283568",
                "9d473653-df6e-4313-9a9c-2128ab10ad0a",
                "c8f80080-51bc-46fb-b04f-69eabd48e1ec",
                "a3bd5eb8-7a36-4125-b309-e1cbc95fde5e"
            ]
        )
    }

    /// The defect: the first row was a console organization, and it was the
    /// one that got picked.
    func testDefaultSelectionIsTheFirstChatOrganizationNotTheFirstRow() {
        XCTAssertEqual(
            ClaudeOrganizationClassifier.defaultSelection(liveOrganizations),
            "ef142542-c027-47d7-9b93-80f8415554a9"
        )
    }

    func testDefaultSelectionIsNilWhenNoOrganizationCanCarryUsage() {
        let consoleOnly = Array(liveOrganizations.prefix(2))

        XCTAssertNil(ClaudeOrganizationClassifier.defaultSelection(consoleOnly))
        XCTAssertFalse(
            ClaudeOrganizationClassifier.hasSelectableOrganization(consoleOnly)
        )
    }

    /// The save guard must hold even if the UI failed to disable the row.
    func testSaveIsRefusedForAConsoleOrganization() {
        XCTAssertFalse(
            ClaudeOrganizationClassifier.permitsSelection(
                of: "c8f80080-51bc-46fb-b04f-69eabd48e1ec",
                from: liveOrganizations
            )
        )
        XCTAssertTrue(
            ClaudeOrganizationClassifier.permitsSelection(
                of: "665a6475-2eb6-4da8-8379-d5529d283568",
                from: liveOrganizations
            )
        )
    }

    /// No selection, and an id from outside the offered list, are both
    /// refused: the list under test is the only legitimate source of the id.
    func testSaveIsRefusedWithoutAMatchingOfferedOrganization() {
        XCTAssertFalse(
            ClaudeOrganizationClassifier.permitsSelection(
                of: nil,
                from: liveOrganizations
            )
        )
        XCTAssertFalse(
            ClaudeOrganizationClassifier.permitsSelection(
                of: "not-an-offered-organization",
                from: liveOrganizations
            )
        )
    }

    /// The kind labels are the whole disambiguation, so pin the English text
    /// rather than only the key lookup.
    func testEnglishCatalogCarriesEveryOrganizationKindLabel() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "en", ofType: "lproj")
        )
        let english = try XCTUnwrap(Bundle(path: path))

        let expected = [
            "wizard.org_kind.team": "Team",
            "wizard.org_kind.enterprise": "Enterprise",
            "wizard.org_kind.personal_max": "Personal · Max",
            "wizard.org_kind.personal_pro": "Personal · Pro",
            "wizard.org_kind.api_only": "API only · no Claude subscription",
            "wizard.org_kind.unknown": "Unknown"
        ]
        for (key, value) in expected {
            XCTAssertEqual(
                english.localizedString(forKey: key, value: nil, table: nil),
                value,
                "catalog value for \(key)"
            )
        }
        XCTAssertFalse(
            english.localizedString(
                forKey: "wizard.no_claude_organizations",
                value: nil,
                table: nil
            ) == "wizard.no_claude_organizations",
            "the no-subscription explanation must be translated, not a raw key"
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
