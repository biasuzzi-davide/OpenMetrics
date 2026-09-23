import Foundation

enum UsageRangePreset: String, CaseIterable, Identifiable, Sendable {
    case last7Days
    case last30Days
    case last90Days
    case thisMonth
    case all
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days: return "7 giorni"
        case .last30Days: return "30 giorni"
        case .last90Days: return "90 giorni"
        case .thisMonth: return "Questo mese"
        case .all: return "Tutto"
        case .custom: return "Personalizzato"
        }
    }
}

enum UsageGranularity: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Giorno"
        case .week: return "Settimana"
        case .month: return "Mese"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

/// Cosa misura l'asse Y del grafico.
enum UsageMetricKind: String, CaseIterable, Identifiable, Sendable {
    case tokens
    case cost
    case requests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tokens: return "Token"
        case .cost: return "Costo"
        case .requests: return "Richieste"
        }
    }
}

/// Come viene spezzata ogni barra del grafico.
enum UsageStackDimension: String, CaseIterable, Identifiable, Sendable {
    case component
    case model
    case project
    case provider

    var id: String { rawValue }

    var title: String {
        switch self {
        case .component: return "Tipo token"
        case .model: return "Modello"
        case .project: return "Progetto"
        case .provider: return "Provider"
        }
    }
}

struct UsageFilter: Equatable, Sendable {
    var preset: UsageRangePreset = .last30Days
    var customStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    var customEnd = Date.now
    var providers: Set<AIProviderID> = Set(AIProviderID.allCases)
    /// Vuoto significa "tutti": evita di dover risincronizzare il set quando compaiono modelli nuovi.
    var models: Set<String> = []
    var projects: Set<String> = []
    var search = ""
    var granularity: UsageGranularity = .day
    var metric: UsageMetricKind = .tokens
    var stack: UsageStackDimension = .component

    var isFiltered: Bool {
        providers.count != AIProviderID.allCases.count
            || !models.isEmpty
            || !projects.isEmpty
            || !search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Intervallo effettivo, o `nil` per "tutto lo storico".
    func dateInterval(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        switch preset {
        case .all:
            return nil
        case .last7Days:
            return interval(days: 7, calendar: calendar, end: endOfToday)
        case .last30Days:
            return interval(days: 30, calendar: calendar, end: endOfToday)
        case .last90Days:
            return interval(days: 90, calendar: calendar, end: endOfToday)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return DateInterval(start: start, end: endOfToday)
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(customStart, customEnd))) ?? endOfToday
            return DateInterval(start: start, end: end)
        }
    }

    private func interval(days: Int, calendar: Calendar, end: Date) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        return DateInterval(start: start, end: end)
    }
}

/// Un punto del grafico: un bucket temporale, una serie dello stack, un valore.
struct UsageSeriesPoint: Identifiable, Equatable, Sendable {
    var bucketStart: Date
    var series: String
    var value: Double

    var id: String { "\(bucketStart.timeIntervalSince1970)|\(series)" }
}

struct UsageAnalysis: Equatable, Sendable {
    var totals = UsageTotals()
    var buckets: [UsageBucket] = []
    var seriesPoints: [UsageSeriesPoint] = []
    var seriesOrder: [String] = []
    var byModel: [UsageBreakdownRow] = []
    var byProject: [UsageBreakdownRow] = []
    var byProvider: [UsageBreakdownRow] = []
    /// Modelli presenti nel periodo per cui manca una tariffa: il costo mostrato li esclude.
    var unpricedModels: [String] = []
    var busiestBucket: UsageBucket?
    var activeDays = 0

    var isEmpty: Bool { totals.requests == 0 }

    /// Media giornaliera calcolata sui soli giorni con attivita.
    var averageCostPerActiveDay: Double {
        activeDays > 0 ? totals.costUSD / Double(activeDays) : 0
    }

    var averageTokensPerActiveDay: Double {
        activeDays > 0 ? Double(totals.totalTokens) / Double(activeDays) : 0
    }
}

/// Elenchi per popolare i menu dei filtri, ricavati dall'intero storico.
struct UsageCatalog: Equatable, Sendable {
    struct Project: Identifiable, Equatable, Sendable {
        var path: String
        var name: String
        var id: String { path }
    }

    var models: [String] = []
    var projects: [Project] = []
    var firstRecord: Date?
    var lastRecord: Date?

    static func build(from records: [UsageRecord]) -> UsageCatalog {
        var models = Set<String>()
        var projects = [String: String]()
        var first: Date?
        var last: Date?

        for record in records {
            models.insert(record.model)
            if projects[record.projectPath] == nil {
                projects[record.projectPath] = record.projectName
            }
            if first == nil || record.timestamp < first! { first = record.timestamp }
            if last == nil || record.timestamp > last! { last = record.timestamp }
        }

        return UsageCatalog(
            models: models.sorted(),
            projects: projects
                .map { Project(path: $0.key, name: $0.value.isEmpty ? "(senza progetto)" : $0.value) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            firstRecord: first,
            lastRecord: last
        )
    }
}

/// Regole di un filtro a spunte dove l'insieme vuoto significa "tutti".
enum UsageSelection {
    /// Calcola la nuova selezione dopo che una voce e stata spuntata o tolta.
    /// `universe` sono tutti gli id esistenti, non solo quelli visibili: partire dai
    /// visibili scarterebbe silenziosamente cio che una ricerca sta nascondendo.
    static func toggling(
        _ id: String,
        to isOn: Bool,
        in selection: Set<String>,
        universe: [String]
    ) -> Set<String> {
        var updated = selection.isEmpty ? Set(universe) : selection
        if isOn {
            updated.insert(id)
        } else {
            updated.remove(id)
        }
        return updated.count == universe.count ? [] : updated
    }

    static func isSelected(_ id: String, in selection: Set<String>) -> Bool {
        selection.isEmpty || selection.contains(id)
    }
}

private struct ProjectAccumulator {
    var label: String
    var provider: AIProviderID
    var totals = UsageTotals()
}

enum UsageAnalyzer {
    static func analyze(
        records: [UsageRecord],
        filter: UsageFilter,
        pricing: PricingTable,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> UsageAnalysis {
        let interval = filter.dateInterval(calendar: calendar, now: now)
        let needle = filter.search.trimmingCharacters(in: .whitespaces).lowercased()

        var analysis = UsageAnalysis()
        var buckets = [Date: UsageTotals]()
        var series = [Date: [String: Double]]()
        var seriesWeight = [String: Double]()
        var models = [String: UsageTotals]()
        var projects = [String: ProjectAccumulator]()
        var providers = [AIProviderID: UsageTotals]()
        var unpriced = Set<String>()
        var days = Set<Date>()

        for record in records {
            guard filter.providers.contains(record.provider) else { continue }
            if let interval, !(record.timestamp >= interval.start && record.timestamp < interval.end) { continue }
            if !filter.models.isEmpty, !filter.models.contains(record.model) { continue }
            if !filter.projects.isEmpty, !filter.projects.contains(record.projectPath) { continue }
            if !needle.isEmpty,
               !record.projectName.lowercased().contains(needle),
               !record.projectPath.lowercased().contains(needle),
               !record.model.lowercased().contains(needle) {
                continue
            }

            let rates = pricing.pricing(for: record.model)
            let cost = rates?.cost(
                input: record.inputTokens,
                output: record.outputTokens,
                cacheWrite5m: record.cacheWrite5mTokens,
                cacheWrite1h: record.cacheWrite1hTokens,
                cacheRead: record.cacheReadTokens
            )

            analysis.totals.add(record, cost: cost)
            if rates == nil {
                unpriced.insert(record.model)
            }

            let bucketStart = bucket(for: record.timestamp, granularity: filter.granularity, calendar: calendar)
            buckets[bucketStart, default: UsageTotals()].add(record, cost: cost)
            days.insert(calendar.startOfDay(for: record.timestamp))

            models[record.model, default: UsageTotals()].add(record, cost: cost)
            providers[record.provider, default: UsageTotals()].add(record, cost: cost)

            // Subscript con default: una sola risoluzione dell'hash del path, e
            // `projectName` (che passa da NSString) si paga solo al primo record.
            projects[
                record.projectPath,
                default: ProjectAccumulator(
                    label: record.projectName.isEmpty ? "(senza progetto)" : record.projectName,
                    provider: record.provider
                )
            ].totals.add(record, cost: cost)

            for (name, value) in stackValues(for: record, filter: filter, rates: rates, cost: cost) {
                series[bucketStart, default: [:]][name, default: 0] += value
                seriesWeight[name, default: 0] += value
            }
        }

        analysis.activeDays = days.count
        analysis.unpricedModels = unpriced.sorted()
        analysis.buckets = buckets
            .map { UsageBucket(start: $0.key, totals: $0.value) }
            .sorted { $0.start < $1.start }
        analysis.busiestBucket = analysis.buckets.max { lhs, rhs in
            value(of: lhs.totals, metric: filter.metric) < value(of: rhs.totals, metric: filter.metric)
        }

        // Le serie piu pesanti prima: la legenda e l'ordine dello stack restano stabili.
        analysis.seriesOrder = seriesWeight
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
        analysis.seriesPoints = series.flatMap { start, values in
            values.map { UsageSeriesPoint(bucketStart: start, series: $0.key, value: $0.value) }
        }
        .sorted { $0.bucketStart < $1.bucketStart }

        analysis.byModel = models
            .map { UsageBreakdownRow(key: $0.key, label: $0.key, provider: nil, totals: $0.value) }
            .sorted { $0.totals.totalTokens > $1.totals.totalTokens }
        analysis.byProject = projects
            .map { UsageBreakdownRow(key: $0.key, label: $0.value.label, provider: $0.value.provider, totals: $0.value.totals) }
            .sorted { $0.totals.totalTokens > $1.totals.totalTokens }
        analysis.byProvider = providers
            .map { UsageBreakdownRow(key: $0.key.rawValue, label: $0.key.rawValue, provider: $0.key, totals: $0.value) }
            .sorted { $0.totals.totalTokens > $1.totals.totalTokens }

        return analysis
    }

    static func bucket(for date: Date, granularity: UsageGranularity, calendar: Calendar = .current) -> Date {
        switch granularity {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    static func value(of totals: UsageTotals, metric: UsageMetricKind) -> Double {
        switch metric {
        case .tokens: return Double(totals.totalTokens)
        case .cost: return totals.costUSD
        case .requests: return Double(totals.requests)
        }
    }

    private static func stackValues(
        for record: UsageRecord,
        filter: UsageFilter,
        rates: ModelPricing?,
        cost: Double?
    ) -> [(String, Double)] {
        switch filter.stack {
        case .component:
            return UsageComponent.allCases.compactMap { component in
                let value = componentValue(component, record: record, filter: filter, rates: rates)
                return value > 0 ? (component.title, value) : nil
            }
        case .model:
            return [(record.model, recordValue(record, filter: filter, cost: cost))]
        case .project:
            let name = record.projectName.isEmpty ? "(senza progetto)" : record.projectName
            return [(name, recordValue(record, filter: filter, cost: cost))]
        case .provider:
            return [(record.provider.rawValue, recordValue(record, filter: filter, cost: cost))]
        }
    }

    private static func recordValue(
        _ record: UsageRecord,
        filter: UsageFilter,
        cost: Double?
    ) -> Double {
        switch filter.metric {
        case .tokens: return Double(record.totalTokens)
        case .cost: return cost ?? 0
        case .requests: return 1
        }
    }

    /// Con metrica "richieste" lo split per tipo di token non ha senso: si conta la richiesta intera.
    private static func componentValue(
        _ component: UsageComponent,
        record: UsageRecord,
        filter: UsageFilter,
        rates: ModelPricing?
    ) -> Double {
        switch filter.metric {
        case .tokens:
            return Double(component.tokens(in: record))
        case .requests:
            return component == .output ? 1 : 0
        case .cost:
            guard let rates else { return 0 }
            let million = 1_000_000.0
            switch component {
            case .input:
                return Double(record.inputTokens) / million * rates.inputPerMTok
            case .output:
                return Double(record.outputTokens) / million * rates.outputPerMTok
            case .cacheWrite:
                return Double(record.cacheWrite5mTokens) / million * rates.cacheWrite5mPerMTok
                    + Double(record.cacheWrite1hTokens) / million * rates.cacheWrite1hPerMTok
            case .cacheRead:
                return Double(record.cacheReadTokens) / million * rates.cacheReadPerMTok
            }
        }
    }
}
