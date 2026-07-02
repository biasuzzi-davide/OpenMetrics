import Foundation
import Testing
@testable import OpenMetrics

@Test func mapsClaudeUsageWindows() throws {
    let data = Data("""
    {
      "five_hour": { "utilization": 25, "resets_at": "2026-01-28T15:00:00Z" },
      "seven_day": { "utilization": 40, "resets_at": "2026-02-01T00:00:00Z" },
      "extra_usage": {
        "is_enabled": true,
        "used_credits": 500,
        "monthly_limit": 10000
      }
    }
    """.utf8)

    let response = try JSONDecoder.aiUsage.decode(ClaudeUsageResponse.self, from: data)
    let metrics = AIUsageMapper.mapClaude(response)

    #expect(metrics.first { $0.title == "Sessione" }?.value == "25%")
    #expect(metrics.first { $0.title == "Sessione" }?.displayValue(usageMode: .left) == "75%")
    #expect(metrics.first { $0.title == "Settimanale" }?.value == "40%")
    #expect(metrics.first { $0.title == "Extra" }?.value == "$5.00 / $100.00")

    let now = try #require(ISO8601DateFormatter().date(from: "2026-01-28T13:30:00Z"))
    #expect(metrics.first { $0.title == "Sessione" }?.displayDetail(resetMode: .relative, now: now) == "reset tra 1h 30m")
}

@Test func mapsCodexUsageCredits() throws {
    let data = Data("""
    {
      "plan_type": "plus",
      "rate_limit": {
        "primary_window": { "used_percent": 6, "reset_at": 1738300000, "limit_window_seconds": 18000 },
        "secondary_window": { "used_percent": 24, "reset_at": 1738900000, "limit_window_seconds": 604800 }
      },
      "credits": {
        "has_credits": true,
        "unlimited": false,
        "balance": "820.6969075"
      },
      "rate_limit_reset_credits": { "available_count": 1 }
    }
    """.utf8)

    let response = try JSONDecoder.aiUsage.decode(CodexUsageResponse.self, from: data)
    let metrics = AIUsageMapper.mapCodex(response)

    #expect(metrics.first { $0.title == "Sessione" }?.value == "6%")
    #expect(metrics.first { $0.title == "Settimanale" }?.value == "24%")
    #expect(metrics.first { $0.title == "Crediti" }?.value == "$32.80")
    #expect(metrics.first { $0.title == "Reset" }?.detail == "disponibile")
}

@Test func formatsAIMenuBarSelection() {
    let snapshot = AIUsageSnapshot(
        providers: [
            AIProviderUsage(
                id: .claude,
                status: .available,
                metrics: [
                    AIUsageMetric(
                        icon: "timer",
                        title: "Sessione",
                        value: "25%",
                        detail: "reset n/d",
                        progress: 0.25,
                        usedFraction: 0.25,
                        resetAt: nil
                    )
                ]
            ),
            AIProviderUsage(id: .codex, status: .missingCredentials)
        ],
        updatedAt: nil
    )

    #expect(MetricsFormatter.aiMenuBarText(
        snapshot: snapshot,
        showClaude: true,
        showCodex: true,
        usageMode: .left,
        resetMode: .relative
    ) == "CLA 75%")
}
