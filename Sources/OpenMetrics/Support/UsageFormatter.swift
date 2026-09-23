import Foundation

enum UsageFormatter {
    private static let grouping: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func integer(_ value: Int) -> String {
        grouping.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Token in forma compatta: 1.2M, 345k, 820.
    static func tokens(_ value: Int) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        }
        if magnitude >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if magnitude >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return String(value)
    }

    static func dollars(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if abs(value) >= 1_000 {
            return String(format: "$%.0f", value)
        }
        if abs(value) >= 1 {
            return String(format: "$%.2f", value)
        }
        return String(format: "$%.3f", value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func axisValue(_ value: Double, metric: UsageMetricKind) -> String {
        switch metric {
        case .tokens: return tokens(Int(value))
        case .cost: return dollars(value)
        case .requests: return integer(Int(value))
        }
    }

    static func metricValue(_ totals: UsageTotals, metric: UsageMetricKind) -> String {
        switch metric {
        case .tokens: return tokens(totals.totalTokens)
        case .cost: return dollars(totals.costUSD)
        case .requests: return integer(totals.requests)
        }
    }

    static func bucketLabel(_ date: Date, granularity: UsageGranularity) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        switch granularity {
        case .day:
            formatter.dateFormat = "d MMM yyyy"
        case .week:
            formatter.dateFormat = "'sett.' w, yyyy"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
        }
        return formatter.string(from: date)
    }

    static func shortBucketLabel(_ date: Date, granularity: UsageGranularity) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        switch granularity {
        case .day:
            formatter.dateFormat = "d MMM"
        case .week:
            formatter.dateFormat = "d MMM"
        case .month:
            formatter.dateFormat = "LLL yy"
        }
        return formatter.string(from: date)
    }
}
