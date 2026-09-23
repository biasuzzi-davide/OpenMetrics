import Foundation

/// Formato binario compatto per l'indice su disco.
///
/// Le date viaggiano come `timeIntervalSinceReferenceDate`, il campo nativo di `Date`:
/// passare da `timeIntervalSince1970` somma e sottrae 978307200 e perde i bit bassi,
/// rendendo diverse due date che dovrebbero essere identiche.
///
/// `PropertyListEncoder` costruisce un albero di oggetti intermedi per ogni campo di
/// ogni record: su oltre centomila richieste il picco di memoria supera i 250 MB e resta
/// occupato. Qui si scrivono una tabella stringhe e record a dimensione fissa, quindi
/// scrittura e lettura allocano quasi solo l'array finale.
enum UsageIndexCodec {
    private static let magic: [UInt8] = Array("OMUI".utf8)
    /// Va alzata a ogni modifica del formato **o della semantica** dei campi.
    /// Dimenticarlo fa rileggere una cache vecchia con regole nuove: le date scritte
    /// come `timeIntervalSince1970` e rilette come `timeIntervalSinceReferenceDate`
    /// finiscono 31 anni avanti, e l'indice sembra vuoto senza nessun errore.
    private static let formatVersion: UInt32 = 2

    enum CodecError: Error {
        case malformed
        case unsupportedVersion
    }

    // MARK: - Scrittura

    static func encode(_ index: UsageIndex) -> Data {
        var strings = StringTable()
        var body = Data()
        body.reserveCapacity(index.records.count * 48 + index.dedupKeys.count * 48)

        body.appendLE(UInt32(index.records.count))
        for record in index.records {
            body.append(record.provider == .claude ? 0 : 1)
            body.appendLE(record.timestamp.timeIntervalSinceReferenceDate.bitPattern)
            body.appendLE(strings.index(of: record.model))
            body.appendLE(strings.index(of: record.projectPath))
            body.appendLE(strings.index(of: record.sessionID))
            body.appendLE(UInt32(clamping: record.inputTokens))
            body.appendLE(UInt32(clamping: record.outputTokens))
            body.appendLE(UInt32(clamping: record.cacheWrite5mTokens))
            body.appendLE(UInt32(clamping: record.cacheWrite1hTokens))
            body.appendLE(UInt32(clamping: record.cacheReadTokens))
            body.appendLE(UInt32(clamping: record.reasoningTokens))
        }

        body.appendLE(UInt32(index.dedupKeys.count))
        for key in index.dedupKeys {
            body.appendString(key)
        }

        body.appendLE(UInt32(index.files.count))
        for (path, state) in index.files {
            body.appendString(path)
            body.appendLE(state.size)
            body.appendLE(state.offset)
            body.appendLE(state.modified.timeIntervalSinceReferenceDate.bitPattern)
        }

        var data = Data(magic)
        data.appendLE(formatVersion)
        data.appendLE(UInt32(index.version))
        data.appendLE(UInt32(strings.values.count))
        for value in strings.values {
            data.appendString(value)
        }
        data.append(body)
        return data
    }

    // MARK: - Lettura

    static func decode(_ data: Data) throws -> UsageIndex {
        var cursor = Cursor(data)

        guard try cursor.readBytes(magic.count) == magic else { throw CodecError.malformed }
        guard try cursor.readUInt32() == formatVersion else { throw CodecError.unsupportedVersion }

        var index = UsageIndex()
        index.version = Int(try cursor.readUInt32())

        let stringCount = Int(try cursor.readUInt32())
        var strings = [String]()
        strings.reserveCapacity(stringCount)
        for _ in 0..<stringCount {
            strings.append(try cursor.readString())
        }

        func string(_ position: UInt32) throws -> String {
            let offset = Int(position)
            guard strings.indices.contains(offset) else { throw CodecError.malformed }
            return strings[offset]
        }

        let recordCount = Int(try cursor.readUInt32())
        index.records.reserveCapacity(recordCount)
        for _ in 0..<recordCount {
            let provider: AIProviderID = try cursor.readByte() == 0 ? .claude : .codex
            let timestamp = Date(timeIntervalSinceReferenceDate: Double(bitPattern: try cursor.readUInt64()))
            let model = try string(try cursor.readUInt32())
            let project = try string(try cursor.readUInt32())
            let session = try string(try cursor.readUInt32())

            index.records.append(
                UsageRecord(
                    provider: provider,
                    timestamp: timestamp,
                    model: model,
                    projectPath: project,
                    sessionID: session,
                    inputTokens: Int(try cursor.readUInt32()),
                    outputTokens: Int(try cursor.readUInt32()),
                    cacheWrite5mTokens: Int(try cursor.readUInt32()),
                    cacheWrite1hTokens: Int(try cursor.readUInt32()),
                    cacheReadTokens: Int(try cursor.readUInt32()),
                    reasoningTokens: Int(try cursor.readUInt32())
                )
            )
        }

        let dedupCount = Int(try cursor.readUInt32())
        index.dedupKeys.reserveCapacity(dedupCount)
        for _ in 0..<dedupCount {
            index.dedupKeys.append(try cursor.readString())
        }

        let fileCount = Int(try cursor.readUInt32())
        index.files.reserveCapacity(fileCount)
        for _ in 0..<fileCount {
            let path = try cursor.readString()
            index.files[path] = FileScanState(
                size: try cursor.readUInt64(),
                offset: try cursor.readUInt64(),
                modified: Date(timeIntervalSinceReferenceDate: Double(bitPattern: try cursor.readUInt64()))
            )
        }

        return index
    }

    /// Assegna un indice stabile a ogni stringa distinta.
    private struct StringTable {
        private(set) var values: [String] = []
        private var positions: [String: UInt32] = [:]

        mutating func index(of value: String) -> UInt32 {
            if let existing = positions[value] { return existing }
            let position = UInt32(values.count)
            values.append(value)
            positions[value] = position
            return position
        }
    }

    private struct Cursor {
        private let data: Data
        private var offset: Int

        init(_ data: Data) {
            self.data = data
            offset = data.startIndex
        }

        mutating func readBytes(_ count: Int) throws -> [UInt8] {
            guard offset + count <= data.endIndex else { throw CodecError.malformed }
            defer { offset += count }
            return Array(data[offset..<(offset + count)])
        }

        mutating func readByte() throws -> UInt8 {
            guard offset < data.endIndex else { throw CodecError.malformed }
            defer { offset += 1 }
            return data[offset]
        }

        mutating func readUInt32() throws -> UInt32 {
            var value: UInt32 = 0
            for (shift, byte) in try readBytes(4).enumerated() {
                value |= UInt32(byte) << (8 * shift)
            }
            return value
        }

        mutating func readUInt64() throws -> UInt64 {
            var value: UInt64 = 0
            for (shift, byte) in try readBytes(8).enumerated() {
                value |= UInt64(byte) << (8 * shift)
            }
            return value
        }

        mutating func readString() throws -> String {
            let length = Int(try readUInt32())
            guard let text = String(bytes: try readBytes(length), encoding: .utf8) else {
                throw CodecError.malformed
            }
            return text
        }
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        for shift in 0..<4 {
            append(UInt8(truncatingIfNeeded: value >> (8 * shift)))
        }
    }

    mutating func appendLE(_ value: UInt64) {
        for shift in 0..<8 {
            append(UInt8(truncatingIfNeeded: value >> (8 * shift)))
        }
    }

    mutating func appendString(_ value: String) {
        let bytes = Array(value.utf8)
        appendLE(UInt32(bytes.count))
        append(contentsOf: bytes)
    }
}
