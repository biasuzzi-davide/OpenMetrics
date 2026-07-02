import Foundation

struct AIUsageSnapshot: Equatable, Sendable {
    var providers: [AIProviderUsage]
    var updatedAt: Date?

    static let empty = AIUsageSnapshot(
        providers: AIProviderID.allCases.map { AIProviderUsage(id: $0, status: .idle) },
        updatedAt: nil
    )
}

enum AIProviderID: String, CaseIterable, Identifiable, Sendable {
    case claude = "Claude"
    case codex = "Codex"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claude:
            return "sparkles"
        case .codex:
            return "terminal"
        }
    }
}

enum AIProviderStatus: Equatable, Sendable {
    case idle
    case loading
    case available
    case missingCredentials
    case failed(String)
}

struct AIProviderUsage: Identifiable, Equatable, Sendable {
    var id: AIProviderID
    var status: AIProviderStatus
    var plan: String?
    var metrics: [AIUsageMetric]

    init(id: AIProviderID, status: AIProviderStatus, plan: String? = nil, metrics: [AIUsageMetric] = []) {
        self.id = id
        self.status = status
        self.plan = plan
        self.metrics = metrics
    }
}

struct AIUsageMetric: Identifiable, Equatable, Sendable {
    var icon: String
    var title: String
    var value: String
    var detail: String
    var progress: Double?
    var usedFraction: Double? = nil
    var resetAt: Date? = nil

    var id: String { "\(title)-\(value)-\(detail)-\(usedFraction ?? -1)-\(resetAt?.timeIntervalSince1970 ?? -1)" }

    func displayValue(usageMode: AIUsageDisplayMode) -> String {
        guard let usedFraction else { return value }

        switch usageMode {
        case .used:
            return MetricsFormatter.percent(usedFraction)
        case .left:
            return MetricsFormatter.percent(1 - usedFraction)
        }
    }

    func displayDetail(resetMode: AIResetDisplayMode, now: Date = .now) -> String {
        guard let resetAt else { return detail }
        return resetText(resetAt, resetMode: resetMode, now: now, includePrefix: true)
    }

    func displayProgress(usageMode: AIUsageDisplayMode) -> Double? {
        guard let usedFraction else { return progress }

        switch usageMode {
        case .used:
            return usedFraction
        case .left:
            return 1 - usedFraction
        }
    }

    func menuBarReset(resetMode: AIResetDisplayMode, now: Date = .now) -> String? {
        guard let resetAt else { return nil }
        return resetText(resetAt, resetMode: resetMode, now: now, includePrefix: false)
    }

    private func resetText(_ date: Date, resetMode: AIResetDisplayMode, now: Date, includePrefix: Bool) -> String {
        switch resetMode {
        case .absolute:
            let value = date <= now ? "ora" : date.formatted(date: .omitted, time: .shortened)
            return includePrefix ? "reset \(value)" : value
        case .relative:
            let value = relativeReset(date, now: now)
            return includePrefix ? "reset tra \(value)" : value
        }
    }

    private func relativeReset(_ date: Date, now: Date) -> String {
        let seconds = max(Int(ceil(date.timeIntervalSince(now))), 0)
        guard seconds > 0 else { return "ora" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = max(1, (seconds % 3_600) / 60)

        if days > 0 { return "\(days)g \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

enum AIUsageDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case used
    case left

    var id: String { rawValue }

    var title: String {
        switch self {
        case .used:
            return "USED"
        case .left:
            return "LEFT"
        }
    }
}

enum AIResetDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case relative
    case absolute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relative:
            return "Relativo"
        case .absolute:
            return "Assoluto"
        }
    }
}
