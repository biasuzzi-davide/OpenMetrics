import Foundation

/// Stato di scansione di un singolo file di log, per rileggere solo la coda nuova.
struct FileScanState: Codable, Equatable, Sendable {
    var size: UInt64
    var offset: UInt64
    var modified: Date
}

/// Indice persistito: record gia estratti piu lo stato di avanzamento per file.
struct UsageIndex: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = UsageIndex.currentVersion
    var records: [UsageRecord] = []
    /// Chiavi di deduplica dei record Claude: le sessioni riprese ricopiano la cronologia.
    var dedupKeys: [String] = []
    var files: [String: FileScanState] = [:]

    var isEmpty: Bool { records.isEmpty }

    var lastTimestamp: Date? { records.map(\.timestamp).max() }
}

struct UsageScanProgress: Equatable, Sendable {
    var scannedFiles: Int
    var totalFiles: Int

    var fraction: Double {
        totalFiles > 0 ? Double(scannedFiles) / Double(totalFiles) : 1
    }
}

/// Ricostruisce lo storico di utilizzo leggendo i log JSONL che Claude Code e Codex
/// scrivono in locale. Nessuna chiamata di rete: i dati non escono dalla macchina.
struct UsageHistoryReader: Sendable {
    /// Byte letti per volta dai file grandi (il rollout Codex piu grande supera i 100 MB).
    private static let chunkSize = 4 * 1_024 * 1_024

    func scan(previous: UsageIndex, progress: @Sendable (UsageScanProgress) -> Void = { _ in }) -> UsageIndex {
        var index = previous.version == UsageIndex.currentVersion ? previous : UsageIndex()
        var dedup = Set(index.dedupKeys)
        // Modelli, progetti e sessioni sono poche decine o migliaia di valori ripetuti su
        // oltre centomila record: senza condividerli si paga una stringa per riga.
        var pool = StringPool(seed: index.records)

        let claudeFiles = discoverClaudeFiles()
        let codexFiles = discoverCodexFiles()
        let total = claudeFiles.count + codexFiles.count
        var scanned = 0
        progress(UsageScanProgress(scannedFiles: 0, totalFiles: total))

        var liveFiles = Set<String>()

        for url in claudeFiles {
            liveFiles.insert(url.path)
            scanClaudeFile(url, index: &index, dedup: &dedup, pool: &pool)
            scanned += 1
            progress(UsageScanProgress(scannedFiles: scanned, totalFiles: total))
        }

        for url in codexFiles {
            liveFiles.insert(url.path)
            scanCodexFile(url, index: &index, pool: &pool)
            scanned += 1
            progress(UsageScanProgress(scannedFiles: scanned, totalFiles: total))
        }

        // I file spariti restano nei record ma non serve piu tenerne lo stato.
        index.files = index.files.filter { liveFiles.contains($0.key) }
        index.dedupKeys = Array(dedup)
        index.records.sort { $0.timestamp < $1.timestamp }
        return index
    }

    // MARK: - Individuazione file

    private func discoverClaudeFiles() -> [URL] {
        var roots: [URL] = []
        if let config = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !config.isEmpty {
            for path in config.split(separator: ",") {
                let trimmed = path.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                roots.append(URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath))
            }
        }
        roots.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"))

        return jsonlFiles(in: roots.map { $0.appendingPathComponent("projects") })
    }

    private func discoverCodexFiles() -> [URL] {
        var roots: [URL] = []
        if let home = ProcessInfo.processInfo.environment["CODEX_HOME"], !home.isEmpty {
            roots.append(URL(fileURLWithPath: (home as NSString).expandingTildeInPath))
        }
        let userHome = FileManager.default.homeDirectoryForCurrentUser
        roots.append(userHome.appendingPathComponent(".codex"))
        roots.append(userHome.appendingPathComponent(".config").appendingPathComponent("codex"))

        return jsonlFiles(in: roots.map { $0.appendingPathComponent("sessions") })
    }

    private func jsonlFiles(in roots: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for root in roots {
            guard let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in walker where url.pathExtension == "jsonl" {
                let resolved = url.resolvingSymlinksInPath().path
                if seen.insert(resolved).inserted {
                    result.append(url)
                }
            }
        }

        return result
    }

    // MARK: - Claude Code

    private static let claudeMarkers = [Array("\"usage\"".utf8)]

    private func scanClaudeFile(_ url: URL, index: inout UsageIndex, dedup: inout Set<String>, pool: inout StringPool) {
        guard let plan = readPlan(for: url, state: index.files) else { return }
        let sessionID = url.deletingPathExtension().lastPathComponent

        let scanned = readNewLines(of: url, plan: plan, markers: Self.claudeMarkers) { line in
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  object["type"] as? String == "assistant",
                  let message = object["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { return }

            let model = message["model"] as? String ?? ""
            // `<synthetic>` marca i messaggi generati dal client: nessuna richiesta, nessun costo.
            guard !model.isEmpty, model != "<synthetic>" else { return }

            let messageID = message["id"] as? String
            let requestID = object["requestId"] as? String
            let key: String
            if let messageID, let requestID {
                key = "\(messageID)|\(requestID)"
            } else if let uuid = object["uuid"] as? String {
                key = "uuid|\(uuid)"
            } else {
                key = "line|\(url.path)|\(index.records.count)"
            }
            guard dedup.insert(key).inserted else { return }

            guard let stamp = object["timestamp"] as? String,
                  let timestamp = FastISO8601.date(from: stamp)
            else { return }

            let creation = usage["cache_creation"] as? [String: Any]
            let write5m = creation?["ephemeral_5m_input_tokens"] as? Int
            let write1h = creation?["ephemeral_1h_input_tokens"] as? Int
            // Senza il dettaglio per TTL si assume il default a 5 minuti.
            let fallbackWrite = usage["cache_creation_input_tokens"] as? Int ?? 0

            index.records.append(
                UsageRecord(
                    provider: .claude,
                    timestamp: timestamp,
                    model: pool.shared(model),
                    projectPath: pool.shared(object["cwd"] as? String ?? ""),
                    sessionID: pool.shared(object["sessionId"] as? String ?? sessionID),
                    inputTokens: usage["input_tokens"] as? Int ?? 0,
                    outputTokens: usage["output_tokens"] as? Int ?? 0,
                    cacheWrite5mTokens: write5m ?? (write1h == nil ? fallbackWrite : 0),
                    cacheWrite1hTokens: write1h ?? 0,
                    cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                    reasoningTokens: 0
                )
            )
        }

        index.files[url.path] = scanned
    }

    // MARK: - Codex

    private static let codexMarkers = [
        Array("\"token_count\"".utf8),
        Array("\"turn_context\"".utf8),
        Array("\"session_meta\"".utf8)
    ]

    private func scanCodexFile(_ url: URL, index: inout UsageIndex, pool: inout StringPool) {
        guard let plan = readPlan(for: url, state: index.files) else { return }

        // cwd e modello arrivano da righe separate e valgono fino al turno successivo.
        var sessionID = url.deletingPathExtension().lastPathComponent
        var cwd = ""
        var model = ""
        // I rollout piu vecchi emettono il primo `token_count` prima di `turn_context`:
        // quei record restano senza modello finche non lo si legge, poi vanno riempiti.
        var awaitingModel: [Int] = []

        // Una ripresa di scansione parte a meta file: recupera il contesto dalla testa.
        // Solo quando c'e davvero coda nuova, altrimenti rileggeremmo 1700 file per niente.
        if plan.start > 0 {
            (sessionID, cwd, model) = codexContextHead(of: url, fallbackSession: sessionID)
        }

        let scanned = readNewLines(of: url, plan: plan, markers: Self.codexMarkers) { line in
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = object["payload"] as? [String: Any]
            else { return }

            switch object["type"] as? String {
            case "session_meta":
                sessionID = payload["session_id"] as? String ?? sessionID
                cwd = payload["cwd"] as? String ?? cwd
                model = payload["model"] as? String ?? model
                backfill(&index, awaiting: &awaitingModel, model: model, project: cwd, pool: &pool)
                return
            case "turn_context":
                cwd = payload["cwd"] as? String ?? cwd
                model = payload["model"] as? String ?? model
                backfill(&index, awaiting: &awaitingModel, model: model, project: cwd, pool: &pool)
                return
            default:
                break
            }

            guard payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let last = info["last_token_usage"] as? [String: Any],
                  let stamp = object["timestamp"] as? String,
                  let timestamp = FastISO8601.date(from: stamp)
            else { return }

            let input = last["input_tokens"] as? Int ?? 0
            let cached = last["cached_input_tokens"] as? Int ?? 0
            let output = last["output_tokens"] as? Int ?? 0
            let cacheWrite = last["cache_write_input_tokens"] as? Int ?? 0
            guard input + output + cached + cacheWrite > 0 else { return }

            if model.isEmpty {
                awaitingModel.append(index.records.count)
            }

            index.records.append(
                UsageRecord(
                    provider: .codex,
                    timestamp: timestamp,
                    // In Codex `input_tokens` comprende la quota servita dalla cache.
                    model: pool.shared(model.isEmpty ? "sconosciuto" : model),
                    projectPath: pool.shared(cwd),
                    sessionID: pool.shared(sessionID),
                    inputTokens: max(0, input - cached),
                    outputTokens: output,
                    cacheWrite5mTokens: cacheWrite,
                    cacheWrite1hTokens: 0,
                    cacheReadTokens: cached,
                    reasoningTokens: last["reasoning_output_tokens"] as? Int ?? 0
                )
            )
        }

        index.files[url.path] = scanned
    }

    /// Assegna il primo modello (e cwd) visto nel file ai record emessi prima di conoscerlo.
    private func backfill(
        _ index: inout UsageIndex,
        awaiting: inout [Int],
        model: String,
        project: String,
        pool: inout StringPool
    ) {
        guard !awaiting.isEmpty, !model.isEmpty else { return }
        let shared = pool.shared(model)
        let sharedProject = pool.shared(project)
        for position in awaiting where index.records.indices.contains(position) {
            index.records[position].model = shared
            if index.records[position].projectPath.isEmpty {
                index.records[position].projectPath = sharedProject
            }
        }
        awaiting.removeAll()
    }

    /// Rilegge solo l'inizio del rollout per recuperare sessione, cwd e modello correnti.
    private func codexContextHead(of url: URL, fallbackSession: String) -> (String, String, String) {
        var sessionID = fallbackSession
        var cwd = ""
        var model = ""

        guard let handle = try? FileHandle(forReadingFrom: url) else { return (sessionID, cwd, model) }
        defer { try? handle.close() }

        guard let head = try? handle.read(upToCount: UsageHistoryReader.chunkSize) else {
            return (sessionID, cwd, model)
        }

        for line in head.split(separator: UInt8(ascii: "\n")) {
            guard let object = autoreleasepool(invoking: { try? JSONSerialization.jsonObject(with: Data(line)) }) as? [String: Any],
                  let payload = object["payload"] as? [String: Any]
            else { continue }

            switch object["type"] as? String {
            case "session_meta":
                sessionID = payload["session_id"] as? String ?? sessionID
                cwd = payload["cwd"] as? String ?? cwd
                model = payload["model"] as? String ?? model
            case "turn_context":
                cwd = payload["cwd"] as? String ?? cwd
                model = payload["model"] as? String ?? model
            default:
                continue
            }
        }

        return (sessionID, cwd, model)
    }

    // MARK: - Lettura incrementale

    /// Cosa resta da leggere di un file, oppure `nil` se e gia stato consumato tutto.
    private func readPlan(for url: URL, state: [String: FileScanState]) -> FileReadPlan? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = attributes?[.modificationDate] as? Date ?? .distantPast
        guard size > 0 else { return nil }

        guard let known = state[url.path] else {
            return FileReadPlan(start: 0, size: size, modified: modified)
        }

        if known.size == size, known.modified == modified, known.offset >= size { return nil }
        // File troncato o ruotato: riparti da capo.
        let start = size >= known.size ? known.offset : 0
        guard start < size else { return nil }
        return FileReadPlan(start: start, size: size, modified: modified)
    }

    /// Legge le righe complete non ancora viste e aggiorna lo stato del file.
    /// L'offset avanza solo fino all'ultimo `\n`: una riga scritta a meta viene riletta dopo.
    /// Il filtro sui marker gira sui byte grezzi, cosi si evita di costruire una `Data`
    /// e di invocare il parser JSON per righe che non interessano.
    private func readNewLines(
        of url: URL,
        plan: FileReadPlan,
        markers: [[UInt8]],
        handleLine: (Data) -> Void
    ) -> FileScanState {
        let untouched = FileScanState(size: plan.size, offset: plan.start, modified: plan.modified)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return untouched }
        defer { try? handle.close() }
        if plan.start > 0 {
            try? handle.seek(toOffset: plan.start)
        }

        // Righe spezzate tra due chunk: la coda incompleta aspetta qui il resto.
        var carry = [UInt8]()
        var totalRead = 0

        // `FileHandle.read` e `JSONSerialization` restituiscono oggetti autoreleased: senza
        // un pool per chunk resterebbero vivi tutti i byte letti, cioe l'intero log.
        var hasMore = true
        while hasMore {
            autoreleasepool {
                guard let chunk = try? handle.read(upToCount: UsageHistoryReader.chunkSize), !chunk.isEmpty else {
                    hasMore = false
                    return
                }
                totalRead += chunk.count

                chunk.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    var cursor = 0

                    while cursor < chunk.count {
                        guard let newline = memchr(base + cursor, Int32(UInt8(ascii: "\n")), chunk.count - cursor) else {
                            break
                        }
                        let end = base.distance(to: newline.assumingMemoryBound(to: UInt8.self))
                        let length = end - cursor

                        if carry.isEmpty {
                            if length > 0, Self.contains(base + cursor, length, markers) {
                                handleLine(Data(bytes: base + cursor, count: length))
                            }
                        } else {
                            carry.append(contentsOf: UnsafeBufferPointer(start: base + cursor, count: length))
                            carry.withUnsafeBufferPointer { buffer in
                                guard let start = buffer.baseAddress, !buffer.isEmpty else { return }
                                if Self.contains(start, buffer.count, markers) {
                                    handleLine(Data(bytes: start, count: buffer.count))
                                }
                            }
                            carry.removeAll(keepingCapacity: true)
                        }

                        cursor = end + 1
                    }

                    if cursor < chunk.count {
                        carry.append(contentsOf: UnsafeBufferPointer(start: base + cursor, count: chunk.count - cursor))
                    }
                }

            }
        }

        // Tutto cio che e stato letto tranne la riga ancora incompleta.
        let consumed = plan.start + UInt64(max(0, totalRead - carry.count))
        return FileScanState(size: plan.size, offset: consumed, modified: plan.modified)
    }

    /// Vero se almeno uno dei marker compare nei byte indicati.
    private static func contains(_ pointer: UnsafePointer<UInt8>, _ count: Int, _ markers: [[UInt8]]) -> Bool {
        for marker in markers {
            let found = marker.withUnsafeBufferPointer { needle -> Bool in
                guard let start = needle.baseAddress, needle.count <= count else { return false }
                return memmem(pointer, count, start, needle.count) != nil
            }
            if found { return true }
        }
        return false
    }
}

/// Riusa una sola istanza per ogni valore ripetuto, invece di tenerne una copia per record.
struct StringPool {
    private var values: Set<String>

    init(seed: [UsageRecord] = []) {
        values = []
        for record in seed {
            values.insert(record.model)
            values.insert(record.projectPath)
            values.insert(record.sessionID)
        }
    }

    mutating func shared(_ value: String) -> String {
        if let existing = values.firstIndex(of: value) { return values[existing] }
        values.insert(value)
        return value
    }
}

/// Porzione di file ancora da leggere.
private struct FileReadPlan {
    var start: UInt64
    var size: UInt64
    var modified: Date
}

/// Parser dedicato al formato `YYYY-MM-DDTHH:MM:SS[.sss]Z` usato nei log.
/// `ISO8601DateFormatter` costa troppo su centinaia di migliaia di righe.
enum FastISO8601 {
    static func date(from string: String) -> Date? {
        let bytes = Array(string.utf8)
        guard bytes.count >= 19,
              bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-"),
              bytes[10] == UInt8(ascii: "T"),
              bytes[13] == UInt8(ascii: ":"), bytes[16] == UInt8(ascii: ":"),
              let year = integer(bytes, 0, 4),
              let month = integer(bytes, 5, 2),
              let day = integer(bytes, 8, 2),
              let hour = integer(bytes, 11, 2),
              let minute = integer(bytes, 14, 2),
              let second = integer(bytes, 17, 2)
        else {
            return fallback(string)
        }

        var seconds = Double(daysFromCivil(year: year, month: month, day: day)) * 86_400
            + Double(hour * 3_600 + minute * 60 + second)

        if bytes.count > 19, bytes[19] == UInt8(ascii: ".") {
            var index = 20
            var scale = 0.1
            while index < bytes.count, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
                seconds += Double(bytes[index] - UInt8(ascii: "0")) * scale
                scale /= 10
                index += 1
            }
            if index < bytes.count, bytes[index] != UInt8(ascii: "Z") {
                return fallback(string)
            }
        } else if bytes.count > 19, bytes[19] != UInt8(ascii: "Z") {
            // Offset esplicito (+02:00): lascia il lavoro al formatter.
            return fallback(string)
        }

        return Date(timeIntervalSince1970: seconds)
    }

    private static func integer(_ bytes: [UInt8], _ offset: Int, _ count: Int) -> Int? {
        var value = 0
        for index in offset..<(offset + count) {
            let byte = bytes[index]
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
            value = value * 10 + Int(byte - UInt8(ascii: "0"))
        }
        return value
    }

    /// Giorni dal 1970-01-01, algoritmo days-from-civil di Howard Hinnant.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func fallback(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
