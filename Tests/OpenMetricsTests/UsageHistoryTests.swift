import Foundation
import Testing
@testable import OpenMetrics

private func record(
    provider: AIProviderID = .claude,
    day: Int,
    model: String = "claude-opus-5",
    project: String = "/Users/tester/Alpha",
    input: Int = 0,
    output: Int = 0,
    cacheWrite5m: Int = 0,
    cacheWrite1h: Int = 0,
    cacheRead: Int = 0
) -> UsageRecord {
    UsageRecord(
        provider: provider,
        timestamp: Date(timeIntervalSince1970: Double(day) * 86_400 + 43_200),
        model: model,
        projectPath: project,
        sessionID: "s\(day)",
        inputTokens: input,
        outputTokens: output,
        cacheWrite5mTokens: cacheWrite5m,
        cacheWrite1hTokens: cacheWrite1h,
        cacheReadTokens: cacheRead,
        reasoningTokens: 0
    )
}

private func allTimeFilter(_ transform: (inout UsageFilter) -> Void = { _ in }) -> UsageFilter {
    var filter = UsageFilter()
    filter.preset = .all
    transform(&filter)
    return filter
}

@Test func fastISO8601MatchesFoundation() throws {
    let samples = [
        "2026-06-15T16:46:58.395Z",
        "2025-09-17T00:00:00Z",
        "2024-02-29T23:59:59.999Z",
        "2026-12-31T12:00:00.5Z"
    ]

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    for sample in samples {
        let fast = try #require(FastISO8601.date(from: sample), "\(sample)")
        let reference = formatter.date(from: sample) ?? ISO8601DateFormatter().date(from: sample)
        let expected = try #require(reference, "\(sample)")
        #expect(abs(fast.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.001, "\(sample)")
    }

    #expect(FastISO8601.date(from: "non una data") == nil)
}

@Test func pricingNormalizesDatedModelAliases() {
    let pricing = PricingTable()
    #expect(pricing.hasPricing(for: "claude-haiku-4-5-20251001"))
    #expect(pricing.pricing(for: "claude-haiku-4-5-20251001") == pricing.pricing(for: "claude-haiku-4-5"))
    #expect(pricing.hasPricing(for: "modello-che-non-esiste") == false)
}

@Test func pricingAppliesCacheMultipliers() throws {
    let pricing = PricingTable()
    let opus = try #require(pricing.pricing(for: "claude-opus-5"))

    // $5 input: cache write 5m a 1.25x, 1h a 2x.
    #expect(abs(opus.cacheWrite5mPerMTok - 6.25) < 0.0001)
    #expect(abs(opus.cacheWrite1hPerMTok - 10) < 0.0001)

    let sample = record(day: 0, input: 1_000_000, output: 1_000_000, cacheWrite5m: 1_000_000, cacheRead: 1_000_000)
    let cost = try #require(pricing.cost(for: sample))
    #expect(abs(cost - (5 + 25 + 6.25 + 0.5)) < 0.0001)
}

@Test func unpricedModelsAreCountedNotGuessed() {
    let pricing = PricingTable()
    var totals = UsageTotals()
    totals.add(record(provider: .codex, day: 0, model: "codex-auto-review", input: 1_000, output: 500), pricing: pricing)

    #expect(totals.costUSD == 0)
    #expect(totals.hasUnpriced)
    #expect(totals.unpricedTokens == 1_500)
}

@Test func analyzerBucketsAndFiltersRecords() throws {
    let records = [
        record(day: 0, input: 1_000, output: 100),
        record(day: 0, model: "claude-sonnet-5", input: 500, output: 50),
        record(day: 1, project: "/Users/tester/Beta", input: 2_000, output: 200),
        record(provider: .codex, day: 1, model: "codex-auto-review", project: "/Users/tester/Beta", input: 9_000)
    ]

    let pricing = PricingTable()
    let calendar = Calendar(identifier: .gregorian)

    let all = UsageAnalyzer.analyze(records: records, filter: allTimeFilter(), pricing: pricing, calendar: calendar)
    #expect(all.totals.requests == 4)
    #expect(all.buckets.count == 2)
    #expect(all.byProject.count == 2)
    #expect(all.unpricedModels == ["codex-auto-review"])

    let claudeOnly = UsageAnalyzer.analyze(
        records: records,
        filter: allTimeFilter { $0.providers = [.claude] },
        pricing: pricing,
        calendar: calendar
    )
    #expect(claudeOnly.totals.requests == 3)
    #expect(claudeOnly.unpricedModels.isEmpty)

    let betaOnly = UsageAnalyzer.analyze(
        records: records,
        filter: allTimeFilter { $0.projects = ["/Users/tester/Beta"] },
        pricing: pricing,
        calendar: calendar
    )
    #expect(betaOnly.totals.requests == 2)
    #expect(betaOnly.buckets.count == 1)

    let searched = UsageAnalyzer.analyze(
        records: records,
        filter: allTimeFilter { $0.search = "sonnet" },
        pricing: pricing,
        calendar: calendar
    )
    #expect(searched.totals.requests == 1)
    #expect(searched.totals.inputTokens == 500)
}

@Test func monthlyGranularityCollapsesDays() {
    let records = (0..<40).map { record(day: $0, input: 100, output: 10) }
    let calendar = Calendar(identifier: .gregorian)

    let daily = UsageAnalyzer.analyze(records: records, filter: allTimeFilter(), pricing: PricingTable(), calendar: calendar)
    let monthly = UsageAnalyzer.analyze(
        records: records,
        filter: allTimeFilter { $0.granularity = .month },
        pricing: PricingTable(),
        calendar: calendar
    )

    #expect(daily.buckets.count == 40)
    #expect(monthly.buckets.count < daily.buckets.count)
    #expect(monthly.totals.totalTokens == daily.totals.totalTokens)
}

@Test func componentStackSplitsTokensWithoutLoss() {
    let records = [record(day: 0, input: 700, output: 200, cacheWrite5m: 60, cacheRead: 40)]
    let analysis = UsageAnalyzer.analyze(
        records: records,
        filter: allTimeFilter { $0.stack = .component },
        pricing: PricingTable(),
        calendar: Calendar(identifier: .gregorian)
    )

    let charted = analysis.seriesPoints.reduce(0) { $0 + $1.value }
    #expect(Int(charted) == analysis.totals.totalTokens)
    #expect(analysis.totals.totalTokens == 1_000)
}

@Test func rangePresetLimitsRecords() {
    let now = Date(timeIntervalSince1970: 100 * 86_400)
    let records = [
        record(day: 98, input: 10),
        record(day: 80, input: 10),
        record(day: 10, input: 10)
    ]

    var filter = UsageFilter()
    filter.preset = .last7Days
    let recent = UsageAnalyzer.analyze(
        records: records,
        filter: filter,
        pricing: PricingTable(),
        calendar: Calendar(identifier: .gregorian),
        now: now
    )

    #expect(recent.totals.requests == 1)
}

@Test func binaryCodecRoundTripsIndex() throws {
    var index = UsageIndex()
    index.records = [
        record(day: 0, input: 1_234, output: 56, cacheWrite5m: 7, cacheWrite1h: 8, cacheRead: 9),
        record(provider: .codex, day: 3, model: "gpt-5.5", project: "/Users/tester/Beta", input: 4_000)
    ]
    index.dedupKeys = ["msg_1|req_1", "msg_2|req_2"]
    index.files = [
        "/tmp/a.jsonl": FileScanState(size: 120, offset: 118, modified: Date(timeIntervalSince1970: 1_000))
    ]

    let decoded = try UsageIndexCodec.decode(UsageIndexCodec.encode(index))

    #expect(decoded.version == index.version)
    #expect(decoded.records == index.records)
    #expect(Set(decoded.dedupKeys) == Set(index.dedupKeys))
    #expect(decoded.files == index.files)
}

@Test func binaryCodecRejectsGarbage() {
    #expect(throws: (any Error).self) {
        try UsageIndexCodec.decode(Data("non un indice".utf8))
    }
}

@Test func codecSharesRepeatedStrings() throws {
    let records = (0..<50).map { record(day: $0, model: "claude-opus-5", project: "/Users/tester/Alpha") }
    var index = UsageIndex()
    index.records = records

    let decoded = try UsageIndexCodec.decode(UsageIndexCodec.encode(index))
    #expect(decoded.records.count == 50)
    #expect(Set(decoded.records.map(\.model)).count == 1)
    // La tabella stringhe scrive un solo valore per progetto e modello.
    #expect(UsageIndexCodec.encode(index).count < 50 * 80)
}

/// Byte congelati prodotti dal formato corrente. Se cambia il layout o la semantica di
/// un campo (per esempio la base temporale delle date) questo test fallisce e obbliga
/// ad alzare `formatVersion`: senza, una cache vecchia verrebbe riletta con regole
/// nuove e produrrebbe date sbagliate senza nessun errore.
private let goldenIndexHex = """
4f4d55490200000001000000060000000d000000636c617564652d6f7075732d350a0000002f746d702f41\
6c706861020000007331070000006770742d352e35090000002f746d702f426574610200000073320200000\
000000000406ee4c7410000000001000000020000000b00000016000000210000002c0000003700000042000\
0000100008063e8ecc74103000000040000000500000001000000020000000000000000000000030000000400\
0000010000000200000\
06b31010000000c0000002f746d702f612e6a736f6e6c090000000000000009000000000000000000004014\
82c541
"""

private func goldenIndex() -> UsageIndex {
    var index = UsageIndex()
    index.records = [
        UsageRecord(
            provider: .claude, timestamp: Date(timeIntervalSince1970: 1_780_000_000),
            model: "claude-opus-5", projectPath: "/tmp/Alpha", sessionID: "s1",
            inputTokens: 11, outputTokens: 22, cacheWrite5mTokens: 33,
            cacheWrite1hTokens: 44, cacheReadTokens: 55, reasoningTokens: 66
        ),
        UsageRecord(
            provider: .codex, timestamp: Date(timeIntervalSince1970: 1_781_111_111),
            model: "gpt-5.5", projectPath: "/tmp/Beta", sessionID: "s2",
            inputTokens: 1, outputTokens: 2, cacheWrite5mTokens: 0,
            cacheWrite1hTokens: 0, cacheReadTokens: 3, reasoningTokens: 4
        )
    ]
    index.dedupKeys = ["k1"]
    index.files = [
        "/tmp/a.jsonl": FileScanState(size: 9, offset: 9, modified: Date(timeIntervalSince1970: 1_700_000_000))
    ]
    return index
}

private func bytes(fromHex hex: String) -> Data {
    let cleaned = hex.filter { !$0.isWhitespace }
    var data = Data(capacity: cleaned.count / 2)
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
        let next = cleaned.index(index, offsetBy: 2)
        data.append(UInt8(cleaned[index..<next], radix: 16)!)
        index = next
    }
    return data
}

@Test func cacheFormatIsFrozen() {
    let encoded = UsageIndexCodec.encode(goldenIndex())
    #expect(
        encoded == bytes(fromHex: goldenIndexHex),
        "Il formato su disco e cambiato: alza formatVersion in UsageIndexCodec e rigenera questi byte."
    )
}

@Test func decodesFrozenCacheBytes() throws {
    let decoded = try UsageIndexCodec.decode(bytes(fromHex: goldenIndexHex))
    let expected = goldenIndex()

    #expect(decoded.records == expected.records)
    #expect(decoded.files == expected.files)
    // La data deve tornare identica al secondo, non spostata di 978307200.
    #expect(decoded.records[0].timestamp.timeIntervalSince1970 == 1_780_000_000)
}

@Test func rejectsCacheWrittenByAnotherFormatVersion() {
    var stale = Array(bytes(fromHex: goldenIndexHex))
    stale[4] = 1  // versione precedente

    #expect(throws: (any Error).self) {
        try UsageIndexCodec.decode(Data(stale))
    }
}

@Test func pricesOpenAIModelsFromPublishedRates() throws {
    let pricing = PricingTable()
    let sol = try #require(pricing.pricing(for: "gpt-5.6-sol"))

    #expect(sol.inputPerMTok == 4)
    #expect(sol.outputPerMTok == 20)
    #expect(sol.cacheReadPerMTok == 0.40)
    // OpenAI non fattura la scrittura in cache: quei token valgono input pieno.
    #expect(sol.cacheWrite5mPerMTok == 4)
    #expect(sol.cacheWrite1hPerMTok == 4)

    #expect(pricing.hasPricing(for: "gpt-5.5"))
    #expect(pricing.hasPricing(for: "gpt-6-astra"))
    // Modello interno di Codex, senza listino pubblico: resta segnalato.
    #expect(pricing.hasPricing(for: "codex-auto-review") == false)
}

@Test func selectionTreatsEmptySetAsEverything() {
    let universe = ["a", "b", "c"]

    #expect(UsageSelection.isSelected("a", in: []))
    #expect(UsageSelection.isSelected("a", in: ["b"]) == false)

    // Togliere una voce partendo da "tutti" deve tenere le altre.
    let afterRemoval = UsageSelection.toggling("b", to: false, in: [], universe: universe)
    #expect(afterRemoval == ["a", "c"])

    // Rimetterla riporta a "tutti", cioe insieme vuoto.
    #expect(UsageSelection.toggling("b", to: true, in: afterRemoval, universe: universe).isEmpty)
}

@Test func selectionIgnoresWhatSearchIsHiding() {
    // La lista mostra solo "b" per via di una ricerca, ma l'universo resta completo:
    // togliere "b" non deve far sparire "a" e "c".
    let universe = ["a", "b", "c"]
    let updated = UsageSelection.toggling("b", to: false, in: [], universe: universe)

    #expect(updated.contains("a"))
    #expect(updated.contains("c"))
    #expect(updated.contains("b") == false)
}
