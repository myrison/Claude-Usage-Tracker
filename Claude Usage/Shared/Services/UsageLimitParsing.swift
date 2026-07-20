import Foundation

/// Parses model-scoped weekly usage limits from the generic `limits` array that Anthropic's
/// usage API returns alongside (and, for some models, instead of) the older fixed
/// `seven_day_opus`/`seven_day_sonnet` top-level keys. Shared by ClaudeAPIService and
/// AutoStartSessionService, which both parse the same response shape independently.
enum UsageLimitParsing {
    /// Finds a model-scoped weekly limit entry by display name (e.g. "Opus", "Sonnet", "Fable").
    /// Entries look like:
    /// `{ "kind": "weekly_scoped", "group": "weekly", "percent": 32,
    ///    "scope": { "model": { "display_name": "Fable" } }, "resets_at": "..." }`
    /// - Returns: nil if the array is absent or no entry matches the given model name.
    static func parseWeeklyScopedLimit(
        from limits: [[String: Any]]?,
        modelDisplayName: String
    ) -> (percentage: Double, resetTime: Date?)? {
        guard let limits else { return nil }

        for limit in limits {
            guard let kind = limit["kind"] as? String, kind == "weekly_scoped" else { continue }
            guard let group = limit["group"] as? String,
                  group.caseInsensitiveCompare("weekly") == .orderedSame else { continue }
            guard let scope = limit["scope"] as? [String: Any],
                  let model = scope["model"] as? [String: Any],
                  let displayName = model["display_name"] as? String,
                  displayName.caseInsensitiveCompare(modelDisplayName) == .orderedSame else { continue }
            guard let percent = limit["percent"] else { continue }

            let percentage = parseUtilization(percent)
            var resetTime: Date? = nil
            if let resetsAt = limit["resets_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                resetTime = formatter.date(from: resetsAt)
            }
            return (percentage, resetTime)
        }

        return nil
    }

    /// Robust utilization parser that handles Int, Double, or String types, clamped to a
    /// finite 0...100 range — the API is a first-party service but this guards against
    /// extreme/non-finite values causing a trap in downstream `Int(Double(...))` conversions.
    static func parseUtilization(_ value: Any) -> Double {
        let raw: Double
        if let intValue = value as? Int {
            raw = Double(intValue)
        } else if let doubleValue = value as? Double {
            raw = doubleValue
        } else if let stringValue = value as? String {
            let cleaned = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "%", with: "")
            raw = Double(cleaned) ?? 0.0
        } else {
            raw = 0.0
        }

        guard raw.isFinite else { return 0.0 }
        return min(max(raw, 0.0), 100.0)
    }
}
