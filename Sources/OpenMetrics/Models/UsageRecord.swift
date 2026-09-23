import Foundation

/// Una singola richiesta fatturabile ricostruita dai log locali di Claude Code o Codex.
struct UsageRecord: Codable, Equatable, Sendable {
    var provider: AIProviderID
    var timestamp: Date
    var model: String
    /// Path assoluto della working directory della sessione.
    var projectPath: String
    var sessionID: String
    var inputTokens: Int
    var outputTokens: Int
    /// Token scritti in cache con TTL 5 minuti (tariffa 1.25x input).
    var cacheWrite5mTokens: Int
    /// Token scritti in cache con TTL 1 ora (tariffa 2x input).
    var cacheWrite1hTokens: Int
    var cacheReadTokens: Int
    /// Solo Codex: token di reasoning, gia inclusi negli output secondo il formato rollout.
    var reasoningTokens: Int

    var cacheWriteTokens: Int { cacheWrite5mTokens + cacheWrite1hTokens }

    /// Somma fatturabile: i token di reasoning non si contano a parte perche Codex li
    /// riporta gia dentro `output_tokens`.
    var totalTokens: Int { inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens }

    var projectName: String {
        let trimmed = projectPath.hasSuffix("/") ? String(projectPath.dropLast()) : projectPath
        let name = (trimmed as NSString).lastPathComponent
        return name.isEmpty ? trimmed : name
    }
}

enum UsageComponent: String, CaseIterable, Identifiable, Sendable {
    case input
    case output
    case cacheWrite
    case cacheRead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .input: return "Input"
        case .output: return "Output"
        case .cacheWrite: return "Cache write"
        case .cacheRead: return "Cache read"
        }
    }

    func tokens(in record: UsageRecord) -> Int {
        switch self {
        case .input: return record.inputTokens
        case .output: return record.outputTokens
        case .cacheWrite: return record.cacheWriteTokens
        case .cacheRead: return record.cacheReadTokens
        }
    }
}

/// Totali aggregati su un insieme arbitrario di record.
struct UsageTotals: Equatable, Sendable {
    var requests = 0
    var inputTokens = 0
    var outputTokens = 0
    var cacheWrite5mTokens = 0
    var cacheWrite1hTokens = 0
    var cacheReadTokens = 0
    var reasoningTokens = 0
    var costUSD = 0.0
    /// Token che non hanno prodotto costo perche il modello non e in tabella prezzi.
    var unpricedTokens = 0

    var cacheWriteTokens: Int { cacheWrite5mTokens + cacheWrite1hTokens }
    var totalTokens: Int { inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens }

    /// Quota di input serviti dalla cache invece che riletti per intero.
    var cacheHitRatio: Double {
        let base = inputTokens + cacheWriteTokens + cacheReadTokens
        guard base > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(base)
    }

    var hasUnpriced: Bool { unpricedTokens > 0 }

    mutating func add(_ record: UsageRecord, pricing: PricingTable) {
        add(record, cost: pricing.cost(for: record))
    }

    /// Variante per chi ha gia risolto il listino: l'aggregazione tocca lo stesso record
    /// da piu angolazioni e ricalcolare il costo ogni volta domina il tempo totale.
    mutating func add(_ record: UsageRecord, cost: Double?) {
        requests += 1
        inputTokens += record.inputTokens
        outputTokens += record.outputTokens
        cacheWrite5mTokens += record.cacheWrite5mTokens
        cacheWrite1hTokens += record.cacheWrite1hTokens
        cacheReadTokens += record.cacheReadTokens
        reasoningTokens += record.reasoningTokens

        if let cost {
            costUSD += cost
        } else {
            unpricedTokens += record.totalTokens
        }
    }

    static func + (lhs: UsageTotals, rhs: UsageTotals) -> UsageTotals {
        UsageTotals(
            requests: lhs.requests + rhs.requests,
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheWrite5mTokens: lhs.cacheWrite5mTokens + rhs.cacheWrite5mTokens,
            cacheWrite1hTokens: lhs.cacheWrite1hTokens + rhs.cacheWrite1hTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            reasoningTokens: lhs.reasoningTokens + rhs.reasoningTokens,
            costUSD: lhs.costUSD + rhs.costUSD,
            unpricedTokens: lhs.unpricedTokens + rhs.unpricedTokens
        )
    }
}

/// Una riga del grafico temporale: un giorno, una settimana o un mese.
struct UsageBucket: Identifiable, Equatable, Sendable {
    var start: Date
    var totals: UsageTotals

    var id: Date { start }
}

/// Una riga delle tabelle di breakdown (per modello, per progetto, per provider).
struct UsageBreakdownRow: Identifiable, Equatable, Sendable {
    var key: String
    var label: String
    var provider: AIProviderID?
    var totals: UsageTotals

    var id: String { key }
}
