import Foundation

/// Tariffe per milione di token di un singolo modello.
struct ModelPricing: Codable, Equatable, Sendable {
    var inputPerMTok: Double
    var outputPerMTok: Double
    var cacheWrite5mPerMTok: Double
    var cacheWrite1hPerMTok: Double
    var cacheReadPerMTok: Double

    /// I moltiplicatori standard: cache write 1.25x (TTL 5m) e 2x (TTL 1h) sull'input.
    init(
        input: Double,
        output: Double,
        cacheRead: Double,
        cacheWrite5m: Double? = nil,
        cacheWrite1h: Double? = nil
    ) {
        inputPerMTok = input
        outputPerMTok = output
        cacheReadPerMTok = cacheRead
        cacheWrite5mPerMTok = cacheWrite5m ?? input * 1.25
        cacheWrite1hPerMTok = cacheWrite1h ?? input * 2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let input = try container.decode(Double.self, forKey: .inputPerMTok)
        self.init(
            input: input,
            output: try container.decode(Double.self, forKey: .outputPerMTok),
            cacheRead: try container.decodeIfPresent(Double.self, forKey: .cacheReadPerMTok) ?? input * 0.1,
            cacheWrite5m: try container.decodeIfPresent(Double.self, forKey: .cacheWrite5mPerMTok),
            cacheWrite1h: try container.decodeIfPresent(Double.self, forKey: .cacheWrite1hPerMTok)
        )
    }

    /// Falso finche il file di override contiene solo il modello vuoto da compilare.
    var isConfigured: Bool {
        inputPerMTok > 0 || outputPerMTok > 0 || cacheReadPerMTok > 0
    }

    func cost(
        input: Int,
        output: Int,
        cacheWrite5m: Int,
        cacheWrite1h: Int,
        cacheRead: Int
    ) -> Double {
        let million = 1_000_000.0
        return Double(input) / million * inputPerMTok
            + Double(output) / million * outputPerMTok
            + Double(cacheWrite5m) / million * cacheWrite5mPerMTok
            + Double(cacheWrite1h) / million * cacheWrite1hPerMTok
            + Double(cacheRead) / million * cacheReadPerMTok
    }
}

/// Listino modelli. Le tariffe Claude sono quelle first-party Anthropic; i modelli
/// non presenti restano senza prezzo e il loro costo non viene inventato.
struct PricingTable: Equatable, Sendable {
    private var rates: [String: ModelPricing]

    init(rates: [String: ModelPricing] = PricingTable.builtIn) {
        self.rates = rates
    }

    /// Path del file con cui l'utente aggiunge o sovrascrive tariffe.
    static var overrideURL: URL {
        UsageStorage.directory.appendingPathComponent("pricing.json")
    }

    static let builtIn: [String: ModelPricing] = [
        "claude-fable-5-1": ModelPricing(input: 10, output: 50, cacheRead: 0.25, cacheWrite5m: 12.50, cacheWrite1h: 20),
        "claude-mythos-5-1": ModelPricing(input: 10, output: 50, cacheRead: 0.25, cacheWrite5m: 12.50, cacheWrite1h: 20),
        "claude-fable-5": ModelPricing(input: 10, output: 50, cacheRead: 1.00, cacheWrite5m: 12.50, cacheWrite1h: 20),
        "claude-mythos-5": ModelPricing(input: 10, output: 50, cacheRead: 1.00, cacheWrite5m: 12.50, cacheWrite1h: 20),
        "claude-opus-5-5": ModelPricing(input: 4, output: 20, cacheRead: 0.20, cacheWrite5m: 5, cacheWrite1h: 8),
        "claude-opus-5": ModelPricing(input: 5, output: 25, cacheRead: 0.50),
        "claude-opus-4-8": ModelPricing(input: 5, output: 25, cacheRead: 0.50),
        "claude-opus-4-7": ModelPricing(input: 5, output: 25, cacheRead: 0.50),
        "claude-opus-4-6": ModelPricing(input: 5, output: 25, cacheRead: 0.50),
        "claude-sonnet-5": ModelPricing(input: 2, output: 10, cacheRead: 0.20),
        "claude-sonnet-4-6": ModelPricing(input: 3, output: 15, cacheRead: 0.30),
        "claude-haiku-4-5": ModelPricing(input: 1, output: 5, cacheRead: 0.10),

        // Listino API OpenAI. Qui non esiste il concetto di cache write: si paga
        // l'input pieno e le riletture scendono alla tariffa "cached input".
        "gpt-6-astra": openAI(input: 10, cached: 1, output: 50),
        "gpt-6-sol": openAI(input: 2, cached: 0.20, output: 10),
        "gpt-6-luna": openAI(input: 0.10, cached: 0.01, output: 0.50),
        "gpt-5.6-sol": openAI(input: 4, cached: 0.40, output: 20),
        "gpt-5.6-terra": openAI(input: 2, cached: 0.20, output: 12),
        "gpt-5.6-luna": openAI(input: 0.20, cached: 0.02, output: 1.20),
        "gpt-5.5": openAI(input: 5, cached: 0.50, output: 30),
        "gpt-5.5-pro": openAI(input: 30, cached: 30, output: 180),
        "gpt-5.4": openAI(input: 2.50, cached: 0.25, output: 15),
        "gpt-5.4-mini": openAI(input: 0.75, cached: 0.075, output: 4.50),
        "gpt-5.4-nano": openAI(input: 0.20, cached: 0.02, output: 1.25),
        "gpt-5.4-pro": openAI(input: 30, cached: 30, output: 180),
        "gpt-5.3-codex": openAI(input: 1.75, cached: 0.175, output: 14),
        // Non compaiono nel listino pubblico OpenAI: applico la tariffa del modello
        // da cui derivano. Cifre da rivedere se OpenAI le pubblica.
        "gpt-5.3-codex-spark": openAI(input: 1.75, cached: 0.175, output: 14),
        "gpt-5-codex": openAI(input: 1.25, cached: 0.125, output: 10),
        "gpt-5.2": openAI(input: 1.75, cached: 0.175, output: 14),
        "gpt-5.2-pro": openAI(input: 21, cached: 21, output: 168),
        "gpt-5.1": openAI(input: 1.25, cached: 0.125, output: 10),
        "gpt-5": openAI(input: 1.25, cached: 0.125, output: 10),
        "gpt-5-mini": openAI(input: 0.25, cached: 0.025, output: 2),
        "gpt-5-nano": openAI(input: 0.05, cached: 0.005, output: 0.40),
        "gpt-5-pro": openAI(input: 15, cached: 15, output: 120)
    ]

    /// I modelli OpenAI non hanno una tariffa di scrittura in cache: quei token,
    /// quando compaiono, vanno contati come input normale.
    private static func openAI(input: Double, cached: Double, output: Double) -> ModelPricing {
        ModelPricing(
            input: input,
            output: output,
            cacheRead: cached,
            cacheWrite5m: input,
            cacheWrite1h: input
        )
    }

    /// Legge il file di override e lo fonde sopra le tariffe integrate.
    static func loadingOverrides() -> PricingTable {
        var rates = builtIn
        guard let data = try? Data(contentsOf: overrideURL),
              let custom = try? JSONDecoder().decode([String: ModelPricing].self, from: data)
        else {
            return PricingTable(rates: rates)
        }

        for (model, pricing) in custom {
            // Il template nasce con tutte le tariffe a zero: finche resta cosi il modello
            // va considerato senza prezzo, altrimenti sparirebbe l'avviso restituendo $0.
            guard pricing.isConfigured else { continue }
            rates[normalize(model)] = pricing
        }
        return PricingTable(rates: rates)
    }

    /// Gli alias datati (`claude-haiku-4-5-20251001`) condividono il listino del modello base.
    /// Niente espressioni regolari: questo metodo viene invocato una volta per record.
    static func normalize(_ model: String) -> String {
        let lowered = model.lowercased()
        let suffix = Array(lowered.utf8.suffix(9))
        guard suffix.count == 9, suffix[0] == UInt8(ascii: "-"), suffix[1] == UInt8(ascii: "2"), suffix[2] == UInt8(ascii: "0") else {
            return lowered
        }
        guard suffix.dropFirst().allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }) else {
            return lowered
        }
        return String(lowered.dropLast(9))
    }

    func pricing(for model: String) -> ModelPricing? {
        rates[PricingTable.normalize(model)]
    }

    func hasPricing(for model: String) -> Bool {
        pricing(for: model) != nil
    }

    func cost(for record: UsageRecord) -> Double? {
        guard let pricing = pricing(for: record.model) else { return nil }
        return pricing.cost(
            input: record.inputTokens,
            output: record.outputTokens,
            cacheWrite5m: record.cacheWrite5mTokens,
            cacheWrite1h: record.cacheWrite1hTokens,
            cacheRead: record.cacheReadTokens
        )
    }

    /// Scrive un file di esempio con i modelli ancora senza tariffa, da compilare a mano.
    @discardableResult
    func writeOverrideTemplate(missingModels: [String]) throws -> URL {
        var payload = [String: ModelPricing]()
        for model in missingModels {
            payload[PricingTable.normalize(model)] = ModelPricing(input: 0, output: 0, cacheRead: 0)
        }

        try FileManager.default.createDirectory(at: UsageStorage.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: PricingTable.overrideURL, options: .atomic)
        return PricingTable.overrideURL
    }
}

enum UsageStorage {
    /// `~/Library/Application Support/OpenMetrics`
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("OpenMetrics", isDirectory: true)
    }

    static var indexURL: URL {
        directory.appendingPathComponent("usage-index.bin")
    }
}
