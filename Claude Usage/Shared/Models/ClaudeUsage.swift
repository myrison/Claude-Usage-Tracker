import Foundation

/// Main data model representing Claude Code usage statistics
struct ClaudeUsage: Codable, Equatable {
    // Session data (5-hour rolling window)
    var sessionTokensUsed: Int
    var sessionLimit: Int
    var sessionPercentage: Double
    var sessionResetTime: Date

    /// Returns 0% if the 5-hour session window has expired, otherwise the raw percentage.
    var effectiveSessionPercentage: Double {
        sessionResetTime < Date() ? 0.0 : sessionPercentage
    }

    // Weekly data (all models)
    var weeklyTokensUsed: Int
    var weeklyLimit: Int
    var weeklyPercentage: Double
    var weeklyResetTime: Date

    // Weekly data (Opus only)
    var opusWeeklyTokensUsed: Int
    var opusWeeklyPercentage: Double

    // Weekly data (Sonnet only)
    var sonnetWeeklyTokensUsed: Int
    var sonnetWeeklyPercentage: Double
    var sonnetWeeklyResetTime: Date?

    // Weekly data (Fable only)
    var fableWeeklyTokensUsed: Int
    var fableWeeklyPercentage: Double
    var fableWeeklyResetTime: Date?

    // Extra usage data
    var costUsed: Double?
    var costLimit: Double?
    var costCurrency: String?

    // Overage credit grant balance
    var overageBalance: Double?
    var overageBalanceCurrency: String?

    // Metadata
    var lastUpdated: Date
    var userTimezone: TimeZone

    init(
        sessionTokensUsed: Int,
        sessionLimit: Int,
        sessionPercentage: Double,
        sessionResetTime: Date,
        weeklyTokensUsed: Int,
        weeklyLimit: Int,
        weeklyPercentage: Double,
        weeklyResetTime: Date,
        opusWeeklyTokensUsed: Int,
        opusWeeklyPercentage: Double,
        sonnetWeeklyTokensUsed: Int,
        sonnetWeeklyPercentage: Double,
        sonnetWeeklyResetTime: Date?,
        fableWeeklyTokensUsed: Int,
        fableWeeklyPercentage: Double,
        fableWeeklyResetTime: Date?,
        costUsed: Double?,
        costLimit: Double?,
        costCurrency: String?,
        overageBalance: Double? = nil,
        overageBalanceCurrency: String? = nil,
        lastUpdated: Date,
        userTimezone: TimeZone
    ) {
        self.sessionTokensUsed = sessionTokensUsed
        self.sessionLimit = sessionLimit
        self.sessionPercentage = sessionPercentage
        self.sessionResetTime = sessionResetTime
        self.weeklyTokensUsed = weeklyTokensUsed
        self.weeklyLimit = weeklyLimit
        self.weeklyPercentage = weeklyPercentage
        self.weeklyResetTime = weeklyResetTime
        self.opusWeeklyTokensUsed = opusWeeklyTokensUsed
        self.opusWeeklyPercentage = opusWeeklyPercentage
        self.sonnetWeeklyTokensUsed = sonnetWeeklyTokensUsed
        self.sonnetWeeklyPercentage = sonnetWeeklyPercentage
        self.sonnetWeeklyResetTime = sonnetWeeklyResetTime
        self.fableWeeklyTokensUsed = fableWeeklyTokensUsed
        self.fableWeeklyPercentage = fableWeeklyPercentage
        self.fableWeeklyResetTime = fableWeeklyResetTime
        self.costUsed = costUsed
        self.costLimit = costLimit
        self.costCurrency = costCurrency
        self.overageBalance = overageBalance
        self.overageBalanceCurrency = overageBalanceCurrency
        self.lastUpdated = lastUpdated
        self.userTimezone = userTimezone
    }

    /// Custom decoding so that fields added after this struct's first release (like the Fable
    /// weekly fields) don't break decoding of usage data cached by older app versions — missing
    /// keys default instead of failing the whole decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionTokensUsed = try container.decode(Int.self, forKey: .sessionTokensUsed)
        sessionLimit = try container.decode(Int.self, forKey: .sessionLimit)
        sessionPercentage = try container.decode(Double.self, forKey: .sessionPercentage)
        sessionResetTime = try container.decode(Date.self, forKey: .sessionResetTime)
        weeklyTokensUsed = try container.decode(Int.self, forKey: .weeklyTokensUsed)
        weeklyLimit = try container.decode(Int.self, forKey: .weeklyLimit)
        weeklyPercentage = try container.decode(Double.self, forKey: .weeklyPercentage)
        weeklyResetTime = try container.decode(Date.self, forKey: .weeklyResetTime)
        opusWeeklyTokensUsed = try container.decode(Int.self, forKey: .opusWeeklyTokensUsed)
        opusWeeklyPercentage = try container.decode(Double.self, forKey: .opusWeeklyPercentage)
        sonnetWeeklyTokensUsed = try container.decode(Int.self, forKey: .sonnetWeeklyTokensUsed)
        sonnetWeeklyPercentage = try container.decode(Double.self, forKey: .sonnetWeeklyPercentage)
        sonnetWeeklyResetTime = try container.decodeIfPresent(Date.self, forKey: .sonnetWeeklyResetTime)
        fableWeeklyTokensUsed = try container.decodeIfPresent(Int.self, forKey: .fableWeeklyTokensUsed) ?? 0
        fableWeeklyPercentage = try container.decodeIfPresent(Double.self, forKey: .fableWeeklyPercentage) ?? 0
        fableWeeklyResetTime = try container.decodeIfPresent(Date.self, forKey: .fableWeeklyResetTime)
        costUsed = try container.decodeIfPresent(Double.self, forKey: .costUsed)
        costLimit = try container.decodeIfPresent(Double.self, forKey: .costLimit)
        costCurrency = try container.decodeIfPresent(String.self, forKey: .costCurrency)
        overageBalance = try container.decodeIfPresent(Double.self, forKey: .overageBalance)
        overageBalanceCurrency = try container.decodeIfPresent(String.self, forKey: .overageBalanceCurrency)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        userTimezone = try container.decode(TimeZone.self, forKey: .userTimezone)
    }

    /// Remaining percentage (100 - used percentage)
    var remainingPercentage: Double {
        max(0, 100 - effectiveSessionPercentage)
    }

    /// Returns the status level based on remaining percentage (like Mac battery indicator)
    /// DEPRECATED: Use UsageStatusCalculator.calculateStatus() instead for display-aware logic
    /// This property remains for backwards compatibility only
    /// - > 20% remaining: safe (green)
    /// - 10-20% remaining: moderate (orange)
    /// - < 10% remaining: critical (red)
    @available(*, deprecated, message: "Use UsageStatusCalculator.calculateStatus() with showRemaining parameter")
    var statusLevel: UsageStatusLevel {
        switch remainingPercentage {
        case 20...:
            return .safe
        case 10..<20:
            return .moderate
        default:
            return .critical
        }
    }

    /// Empty usage data (used when no data is available)
    static var empty: ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: 0,
            sessionLimit: 0,
            sessionPercentage: 0,
            sessionResetTime: Date().addingTimeInterval(5 * 60 * 60),
            weeklyTokensUsed: 0,
            weeklyLimit: 1_000_000,
            weeklyPercentage: 0,
            weeklyResetTime: Date().nextMonday1259pm(),
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
            overageBalance: nil,
            overageBalanceCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )
    }

}

/// Usage status level for color coding
/// Thresholds depend on display mode (used vs remaining percentage)
enum UsageStatusLevel {
    case safe       // Used mode: 0-50% used | Remaining mode: >20% remaining
    case moderate   // Used mode: 50-80% used | Remaining mode: 10-20% remaining
    case critical   // Used mode: 80-100% used | Remaining mode: <10% remaining
}
