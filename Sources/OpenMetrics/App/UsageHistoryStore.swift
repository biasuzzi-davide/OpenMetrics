import Combine
import Foundation

@MainActor
final class UsageHistoryStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loadingCache
        case scanning(UsageScanProgress)
        case ready(Date)
        case failed(String)
    }

    @Published private(set) var state = LoadState.idle
    @Published private(set) var catalog = UsageCatalog()
    @Published private(set) var analysis = UsageAnalysis()
    @Published private(set) var pricing = PricingTable()
    @Published var filter = UsageFilter() {
        didSet { if filter != oldValue { scheduleAnalysis() } }
    }

    private var records: [UsageRecord] = []
    private var loadTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var hasLoaded = false

    var isBusy: Bool {
        switch state {
        case .loadingCache, .scanning: return true
        case .idle, .ready, .failed: return false
        }
    }

    var recordCount: Int { records.count }

    /// Modelli presenti nei dati che non hanno una tariffa: il costo mostrato li esclude.
    var unpricedModels: [String] {
        catalog.models.filter { !pricing.hasPricing(for: $0) }
    }

    /// Primo caricamento: cache su disco, poi scansione incrementale dei log.
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        refresh()
    }

    func refresh() {
        guard loadTask == nil else { return }

        state = records.isEmpty ? .loadingCache : .scanning(UsageScanProgress(scannedFiles: 0, totalFiles: 0))
        pricing = PricingTable.loadingOverrides()

        loadTask = Task { [weak self] in
            guard let self else { return }

            if records.isEmpty, let cached = await Self.loadCachedIndex() {
                apply(index: cached, persist: false)
                state = .scanning(UsageScanProgress(scannedFiles: 0, totalFiles: 0))
            }

            let base = UsageIndex(
                version: UsageIndex.currentVersion,
                records: records,
                dedupKeys: cachedDedupKeys,
                files: cachedFiles
            )

            let scanned = await Self.scan(base: base) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state = .scanning(progress)
                }
            }

            switch scanned {
            case .success(let index):
                apply(index: index, persist: true)
                state = .ready(.now)
            case .failure(let error):
                state = .failed(error.localizedDescription)
            }

            loadTask = nil
        }
    }

    /// Ricarica solo il listino, dopo che l'utente ha modificato `pricing.json`.
    func reloadPricing() {
        pricing = PricingTable.loadingOverrides()
        scheduleAnalysis()
    }

    func resetFilters() {
        filter = UsageFilter()
    }

    /// Esporta i bucket correnti in CSV, per chi vuole rifare i conti altrove.
    func exportCSV(to url: URL) throws {
        var lines = ["periodo;richieste;input;output;cache_write;cache_read;token_totali;costo_usd"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for bucket in analysis.buckets {
            let totals = bucket.totals
            lines.append(
                [
                    formatter.string(from: bucket.start),
                    String(totals.requests),
                    String(totals.inputTokens),
                    String(totals.outputTokens),
                    String(totals.cacheWriteTokens),
                    String(totals.cacheReadTokens),
                    String(totals.totalTokens),
                    String(format: "%.4f", totals.costUSD)
                ].joined(separator: ";")
            )
        }

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// Crea `pricing.json` con i modelli senza tariffa, pronto da compilare.
    @discardableResult
    func writePricingTemplate() throws -> URL {
        try pricing.writeOverrideTemplate(missingModels: unpricedModels)
    }

    // MARK: - Interno

    private var cachedDedupKeys: [String] = []
    private var cachedFiles: [String: FileScanState] = [:]

    private func apply(index: UsageIndex, persist: Bool) {
        records = index.records
        cachedDedupKeys = index.dedupKeys
        cachedFiles = index.files
        catalog = UsageCatalog.build(from: index.records)
        scheduleAnalysis()

        guard persist else { return }
        Task.detached(priority: .background) {
            try? Self.saveCachedIndex(index)
        }
    }

    private func scheduleAnalysis() {
        analysisTask?.cancel()
        let snapshot = records
        let filter = filter
        let pricing = pricing

        analysisTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                UsageAnalyzer.analyze(records: snapshot, filter: filter, pricing: pricing)
            }.value

            guard !Task.isCancelled else { return }
            self?.analysis = result
        }
    }

    private nonisolated static func scan(
        base: UsageIndex,
        progress: @escaping @Sendable (UsageScanProgress) -> Void
    ) async -> Result<UsageIndex, Error> {
        await Task.detached(priority: .utility) {
            let reader = UsageHistoryReader()
            // Una notifica ogni 25 file: 2700 hop sul main actor non servono a nessuno.
            let counter = ScanThrottle(every: 25, forward: progress)
            let index = reader.scan(previous: base) { counter.report($0) }
            return Result<UsageIndex, Error>.success(index)
        }.value
    }

    private nonisolated static func loadCachedIndex() async -> UsageIndex? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: UsageStorage.indexURL, options: .mappedIfSafe) else { return nil }
            return try? UsageIndexCodec.decode(data)
        }.value
    }

    private nonisolated static func saveCachedIndex(_ index: UsageIndex) throws {
        try FileManager.default.createDirectory(at: UsageStorage.directory, withIntermediateDirectories: true)
        try UsageIndexCodec.encode(index).write(to: UsageStorage.indexURL, options: .atomic)
    }
}

/// Riduce la frequenza delle notifiche di avanzamento.
private final class ScanThrottle: @unchecked Sendable {
    private let every: Int
    private let forward: @Sendable (UsageScanProgress) -> Void
    private let lock = NSLock()
    private var seen = 0

    init(every: Int, forward: @escaping @Sendable (UsageScanProgress) -> Void) {
        self.every = every
        self.forward = forward
    }

    func report(_ progress: UsageScanProgress) {
        lock.lock()
        seen += 1
        let shouldForward = seen % every == 0 || progress.scannedFiles == progress.totalFiles
        lock.unlock()

        if shouldForward {
            forward(progress)
        }
    }
}
