import XCTest
@testable import Claude_Usage

final class ClaudeUsageTests: XCTestCase {

    // MARK: - Status Level Tests (Deprecated Property - uses remaining-based thresholds)

    func testStatusLevelSafe() {
        // statusLevel uses remaining-based thresholds: safe when remaining >= 20%
        let usage = createUsage(sessionPercentage: 0)  // 100% remaining
        XCTAssertEqual(usage.statusLevel, .safe)

        let usage25 = createUsage(sessionPercentage: 25)  // 75% remaining
        XCTAssertEqual(usage.statusLevel, .safe)

        let usage80 = createUsage(sessionPercentage: 80)  // 20% remaining (exact boundary)
        XCTAssertEqual(usage.statusLevel, .safe)
    }

    func testStatusLevelModerate() {
        // statusLevel uses remaining-based thresholds: moderate when 10% <= remaining < 20%
        let usage81 = createUsage(sessionPercentage: 81)  // 19% remaining
        XCTAssertEqual(usage81.statusLevel, .moderate)

        let usage85 = createUsage(sessionPercentage: 85)  // 15% remaining
        XCTAssertEqual(usage85.statusLevel, .moderate)

        let usage90 = createUsage(sessionPercentage: 90)  // 10% remaining (exact boundary)
        XCTAssertEqual(usage90.statusLevel, .moderate)
    }

    func testStatusLevelCritical() {
        // statusLevel uses remaining-based thresholds: critical when remaining < 10%
        let usage91 = createUsage(sessionPercentage: 91)  // 9% remaining
        XCTAssertEqual(usage91.statusLevel, .critical)

        let usage95 = createUsage(sessionPercentage: 95)  // 5% remaining
        XCTAssertEqual(usage95.statusLevel, .critical)

        let usage100 = createUsage(sessionPercentage: 100)  // 0% remaining
        XCTAssertEqual(usage100.statusLevel, .critical)
    }

    // MARK: - Empty Usage Tests

    func testEmptyUsage() {
        let empty = ClaudeUsage.empty

        XCTAssertEqual(empty.sessionTokensUsed, 0)
        XCTAssertEqual(empty.sessionPercentage, 0)
        XCTAssertEqual(empty.weeklyTokensUsed, 0)
        XCTAssertEqual(empty.weeklyPercentage, 0)
        XCTAssertEqual(empty.statusLevel, .safe)
        XCTAssertNil(empty.costUsed)
        XCTAssertNil(empty.costLimit)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = createUsage(sessionPercentage: 45.5)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClaudeUsage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - UsageLimitParsing Tests

    func testParseWeeklyScopedLimitMatchesFable() {
        let limits: [[String: Any]] = [
            [
                "kind": "weekly_scoped",
                "group": "weekly",
                "percent": 32,
                "resets_at": "2026-07-21T08:59:59.801278+00:00",
                "scope": ["model": ["id": NSNull(), "display_name": "Fable"]]
            ]
        ]

        let result = UsageLimitParsing.parseWeeklyScopedLimit(from: limits, modelDisplayName: "Fable")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.percentage, 32)
        XCTAssertNotNil(result?.resetTime)
    }

    func testParseWeeklyScopedLimitIsCaseInsensitive() {
        let limits: [[String: Any]] = [
            ["kind": "weekly_scoped", "group": "WEEKLY", "percent": 10,
             "scope": ["model": ["display_name": "fable"]]]
        ]

        let result = UsageLimitParsing.parseWeeklyScopedLimit(from: limits, modelDisplayName: "Fable")
        XCTAssertEqual(result?.percentage, 10)
    }

    func testParseWeeklyScopedLimitAcceptsWholeSecondResetTimeAndMissingKind() {
        let limits: [[String: Any]] = [
            ["group": "weekly", "percent": 25,
             "resets_at": "2026-07-21T08:59:59Z",
             "scope": ["model": ["display_name": "Fable"]]]
        ]

        let result = UsageLimitParsing.parseWeeklyScopedLimit(from: limits, modelDisplayName: "Fable")

        XCTAssertEqual(result?.percentage, 25)
        XCTAssertNotNil(result?.resetTime)
    }

    func testParseWeeklyScopedLimitIgnoresNonWeeklyScopedKind() {
        let limits: [[String: Any]] = [
            ["kind": "session", "group": "weekly", "percent": 90,
             "scope": ["model": ["display_name": "Fable"]]]
        ]

        XCTAssertNil(UsageLimitParsing.parseWeeklyScopedLimit(from: limits, modelDisplayName: "Fable"))
    }

    func testParseWeeklyScopedLimitReturnsNilWhenAbsent() {
        XCTAssertNil(UsageLimitParsing.parseWeeklyScopedLimit(from: nil, modelDisplayName: "Fable"))
        XCTAssertNil(UsageLimitParsing.parseWeeklyScopedLimit(from: [], modelDisplayName: "Fable"))

        let limits: [[String: Any]] = [
            ["kind": "weekly_scoped", "group": "weekly", "percent": 50,
             "scope": ["model": ["display_name": "Opus"]]]
        ]
        XCTAssertNil(UsageLimitParsing.parseWeeklyScopedLimit(from: limits, modelDisplayName: "Fable"))
    }

    func testParseUtilizationClampsOutOfRangeValues() {
        XCTAssertEqual(UsageLimitParsing.parseUtilization(1e300), 100.0)
        XCTAssertEqual(UsageLimitParsing.parseUtilization(-50), 0.0)
        XCTAssertEqual(UsageLimitParsing.parseUtilization(Double.nan), 0.0)
        XCTAssertEqual(UsageLimitParsing.parseUtilization(Double.infinity), 0.0)
        XCTAssertEqual(UsageLimitParsing.parseUtilization(42), 42.0)
    }

    // MARK: - Helpers

    private func createUsage(sessionPercentage: Double) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPercentage * 1000),
            sessionLimit: 100000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 500000,
            weeklyLimit: 1000000,
            weeklyPercentage: 50,
            weeklyResetTime: Date().addingTimeInterval(86400),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            fableWeeklyTokensUsed: 0,
            fableWeeklyPercentage: 0,
            fableWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )
    }
}
