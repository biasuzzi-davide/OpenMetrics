import Foundation
import Security

struct AIUsageReader: Sendable {
    func read() async -> [AIProviderUsage] {
        async let claude = readClaude()
        async let codex = readCodex()
        return await [claude, codex]
    }

    private func readClaude() async -> AIProviderUsage {
        guard var credentials = loadClaudeCredentials() else {
            return AIProviderUsage(id: .claude, status: .missingCredentials)
        }

        do {
            if credentials.needsRefresh {
                credentials = try await refreshClaude(credentials)
            }

            do {
                let usage = try await fetchClaudeUsage(accessToken: credentials.accessToken)
                return AIProviderUsage(
                    id: .claude,
                    status: .available,
                    plan: AIUsageMapper.claudePlan(credentials),
                    metrics: AIUsageMapper.mapClaude(usage)
                )
            } catch AIUsageError.unauthorized {
                credentials = try await refreshClaude(credentials)
                let usage = try await fetchClaudeUsage(accessToken: credentials.accessToken)
                return AIProviderUsage(
                    id: .claude,
                    status: .available,
                    plan: AIUsageMapper.claudePlan(credentials),
                    metrics: AIUsageMapper.mapClaude(usage)
                )
            }
        } catch {
            return AIProviderUsage(id: .claude, status: .failed(AIUsageError.message(for: error)))
        }
    }

    private func readCodex() async -> AIProviderUsage {
        guard var credentials = loadCodexCredentials() else {
            return AIProviderUsage(id: .codex, status: .missingCredentials)
        }

        do {
            if credentials.needsRefresh {
                credentials = try await refreshCodex(credentials)
            }

            do {
                let usage = try await fetchCodexUsage(credentials: credentials)
                return AIProviderUsage(
                    id: .codex,
                    status: .available,
                    plan: usage.planType?.capitalized,
                    metrics: AIUsageMapper.mapCodex(usage)
                )
            } catch AIUsageError.unauthorized {
                credentials = try await refreshCodex(credentials)
                let usage = try await fetchCodexUsage(credentials: credentials)
                return AIProviderUsage(
                    id: .codex,
                    status: .available,
                    plan: usage.planType?.capitalized,
                    metrics: AIUsageMapper.mapCodex(usage)
                )
            }
        } catch {
            return AIProviderUsage(id: .codex, status: .failed(AIUsageError.message(for: error)))
        }
    }

    private func fetchClaudeUsage(accessToken: String) async throws -> ClaudeUsageResponse {
        guard !accessToken.isEmpty else { throw AIUsageError.missingRefreshToken }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        return try JSONDecoder.aiUsage.decode(ClaudeUsageResponse.self, from: try await data(for: request))
    }

    private func fetchCodexUsage(credentials: CodexCredentials) async throws -> CodexUsageResponse {
        guard !credentials.accessToken.isEmpty else { throw AIUsageError.missingRefreshToken }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        return try JSONDecoder.aiUsage.decode(CodexUsageResponse.self, from: try await data(for: request))
    }

    // ponytail: refreshed tokens stay in memory; add lossless file/keychain writes if refresh rotation becomes a real issue.
    private func refreshClaude(_ credentials: ClaudeCredentials) async throws -> ClaudeCredentials {
        guard !credentials.refreshToken.isEmpty else { throw AIUsageError.missingRefreshToken }

        var request = URLRequest(url: URL(string: "https://platform.claude.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
            "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
        ])

        let response = try JSONDecoder.aiUsage.decode(ClaudeRefreshResponse.self, from: try await data(for: request))
        guard !response.accessToken.isEmpty else { throw AIUsageError.invalidResponse }

        return credentials.refreshed(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )
    }

    private func refreshCodex(_ credentials: CodexCredentials) async throws -> CodexCredentials {
        guard !credentials.refreshToken.isEmpty else { throw AIUsageError.missingRefreshToken }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: "app_EMoamEEZ73f0CkXaXp7hrann"),
            URLQueryItem(name: "refresh_token", value: credentials.refreshToken)
        ]

        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let response = try JSONDecoder.aiUsage.decode(CodexRefreshResponse.self, from: try await data(for: request))
        guard !response.accessToken.isEmpty else { throw AIUsageError.invalidResponse }

        return credentials.refreshed(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            idToken: response.idToken
        )
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIUsageError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw AIUsageError.unauthorized
        default:
            throw AIUsageError.httpStatus(http.statusCode)
        }
    }
}

enum AIUsageMapper {
    static func mapClaude(_ response: ClaudeUsageResponse) -> [AIUsageMetric] {
        var metrics: [AIUsageMetric] = []
        appendPercentMetric(response.fiveHour, icon: "timer", title: "Sessione", to: &metrics)
        appendPercentMetric(response.sevenDay, icon: "calendar", title: "Settimanale", to: &metrics)
        appendPercentMetric(response.sevenDaySonnet, icon: "waveform", title: "Sonnet", to: &metrics)
        appendPercentMetric(response.sevenDayOpus, icon: "music.quarternote.3", title: "Opus", to: &metrics)
        appendPercentMetric(response.sevenDayOmelette, icon: "paintpalette", title: "Design", to: &metrics)

        if response.extraUsage?.isEnabled == true, let usedCents = response.extraUsage?.usedCredits {
            let spent = usedCents / 100
            if let limitCents = response.extraUsage?.monthlyLimit, limitCents > 0 {
                let limit = limitCents / 100
                metrics.append(AIUsageMetric(
                    icon: "creditcard",
                    title: "Extra",
                    value: "\(dollars(spent)) / \(dollars(limit))",
                    detail: "spesa mensile",
                    progress: spent / limit
                ))
            } else if spent > 0 {
                metrics.append(AIUsageMetric(
                    icon: "creditcard",
                    title: "Extra",
                    value: dollars(spent),
                    detail: "spesa senza limite mensile",
                    progress: nil
                ))
            }
        }

        return metrics
    }

    static func mapCodex(_ response: CodexUsageResponse) -> [AIUsageMetric] {
        var metrics: [AIUsageMetric] = []
        appendPercentMetric(response.rateLimit?.primaryWindow, icon: "timer", title: "Sessione", to: &metrics)
        appendPercentMetric(response.rateLimit?.secondaryWindow, icon: "calendar", title: "Settimanale", to: &metrics)
        appendPercentMetric(response.codeReviewRateLimit?.primaryWindow, icon: "checkmark.seal", title: "Code review", to: &metrics)

        if let available = response.rateLimitResetCredits?.availableCount, available > 0 {
            metrics.append(AIUsageMetric(
                icon: "arrow.counterclockwise",
                title: "Reset",
                value: "\(available)",
                detail: available == 1 ? "disponibile" : "disponibili",
                progress: nil
            ))
        }

        if response.credits?.hasCredits == true {
            if response.credits?.unlimited == true {
                metrics.append(AIUsageMetric(
                    icon: "creditcard",
                    title: "Crediti",
                    value: "Illimitati",
                    detail: "saldo",
                    progress: nil
                ))
            } else if let balance = response.credits?.balance {
                let credits = floor(balance)
                metrics.append(AIUsageMetric(
                    icon: "creditcard",
                    title: "Crediti",
                    value: dollars(credits * 0.04),
                    detail: "\(Int(credits)) crediti",
                    progress: nil
                ))
            }
        }

        return metrics
    }

    static func claudePlan(_ credentials: ClaudeCredentials) -> String? {
        guard let subscription = credentials.subscriptionType?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subscription.isEmpty
        else {
            return nil
        }

        let plan = subscription.capitalized
        guard let tier = credentials.rateLimitTier,
              let range = tier.range(of: #"\d+x"#, options: .regularExpression)
        else {
            return plan
        }

        return "\(plan) \(tier[range])"
    }

    private static func appendPercentMetric(_ window: ClaudeUsageWindow?, icon: String, title: String, to metrics: inout [AIUsageMetric]) {
        guard let used = window?.utilization else { return }
        appendPercentMetric(used: used, resetAt: window?.resetDate, icon: icon, title: title, to: &metrics)
    }

    private static func appendPercentMetric(_ window: CodexUsageWindow?, icon: String, title: String, to metrics: inout [AIUsageMetric]) {
        guard let used = window?.usedPercent else { return }
        appendPercentMetric(used: used, resetAt: window?.resetDate, icon: icon, title: title, to: &metrics)
    }

    private static func appendPercentMetric(used: Double, resetAt: Date?, icon: String, title: String, to metrics: inout [AIUsageMetric]) {
        let progress = min(max(used / 100, 0), 1)
        metrics.append(AIUsageMetric(
            icon: icon,
            title: title,
            value: MetricsFormatter.percent(progress),
            detail: resetText(resetAt),
            progress: progress,
            usedFraction: progress,
            resetAt: resetAt
        ))
    }

    private static func resetText(_ date: Date?) -> String {
        guard let date else { return "reset n/d" }
        if date <= Date() { return "reset ora" }
        return "reset \(date.formatted(date: .omitted, time: .shortened))"
    }

    private static func dollars(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

struct ClaudeUsageResponse: Decodable, Equatable, Sendable {
    var fiveHour: ClaudeUsageWindow?
    var sevenDay: ClaudeUsageWindow?
    var sevenDaySonnet: ClaudeUsageWindow?
    var sevenDayOpus: ClaudeUsageWindow?
    var sevenDayOmelette: ClaudeUsageWindow?
    var extraUsage: ClaudeExtraUsage?
}

struct ClaudeUsageWindow: Decodable, Equatable, Sendable {
    var utilization: Double?
    var resetsAt: String?

    var resetDate: Date? { Self.isoDate(resetsAt) }

    private static func isoDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct ClaudeExtraUsage: Decodable, Equatable, Sendable {
    var isEnabled: Bool?
    var usedCredits: Double?
    var monthlyLimit: Double?
}

struct CodexUsageResponse: Decodable, Equatable, Sendable {
    var planType: String?
    var rateLimit: CodexRateLimit?
    var codeReviewRateLimit: CodexCodeReviewRateLimit?
    var credits: CodexCredits?
    var rateLimitResetCredits: CodexResetCredits?
}

struct CodexRateLimit: Decodable, Equatable, Sendable {
    var primaryWindow: CodexUsageWindow?
    var secondaryWindow: CodexUsageWindow?
}

struct CodexCodeReviewRateLimit: Decodable, Equatable, Sendable {
    var primaryWindow: CodexUsageWindow?
}

struct CodexUsageWindow: Decodable, Equatable, Sendable {
    var usedPercent: Double?
    var resetAt: Double?
    var limitWindowSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent
        case resetAt
        case limitWindowSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = container.flexibleDouble(forKey: .usedPercent)
        resetAt = container.flexibleDouble(forKey: .resetAt)
        limitWindowSeconds = container.flexibleDouble(forKey: .limitWindowSeconds)
    }

    var resetDate: Date? {
        guard let resetAt else { return nil }
        return Date(timeIntervalSince1970: resetAt)
    }
}

struct CodexCredits: Decodable, Equatable, Sendable {
    var hasCredits: Bool?
    var unlimited: Bool?
    var balance: Double?

    enum CodingKeys: String, CodingKey {
        case hasCredits
        case unlimited
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits)
        unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited)
        balance = container.flexibleDouble(forKey: .balance)
    }
}

struct CodexResetCredits: Decodable, Equatable, Sendable {
    var availableCount: Int?

    enum CodingKeys: String, CodingKey {
        case availableCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decodeIfPresent(Int.self, forKey: .availableCount) {
            availableCount = value
        } else {
            availableCount = container.flexibleDouble(forKey: .availableCount).map(Int.init)
        }
    }
}

struct ClaudeCredentials: Decodable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date?
    var subscriptionType: String?
    var rateLimitTier: String?

    var needsRefresh: Bool {
        accessToken.isEmpty || expiresAt.map { $0.timeIntervalSinceNow < 300 } ?? false
    }

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiresAt
        case subscriptionType
        case rateLimitTier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        subscriptionType = try container.decodeIfPresent(String.self, forKey: .subscriptionType)
        rateLimitTier = try container.decodeIfPresent(String.self, forKey: .rateLimitTier)

        if let milliseconds = try container.decodeIfPresent(Double.self, forKey: .expiresAt), milliseconds > 0 {
            expiresAt = Date(timeIntervalSince1970: milliseconds / 1000)
        } else {
            expiresAt = nil
        }
    }

    func refreshed(accessToken: String, refreshToken: String?, expiresIn: Double?) -> ClaudeCredentials {
        ClaudeCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken ?? self.refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn ?? 3_600),
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier
        )
    }

    private init(accessToken: String, refreshToken: String, expiresAt: Date?, subscriptionType: String?, rateLimitTier: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
        self.rateLimitTier = rateLimitTier
    }
}

struct CodexCredentials: Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var idToken: String?
    var accountID: String?
    var lastRefresh: Date?

    var needsRefresh: Bool {
        accessToken.isEmpty || lastRefresh.map { Date().timeIntervalSince($0) > 8 * 86_400 } ?? false
    }

    func refreshed(accessToken: String, refreshToken: String?, idToken: String?) -> CodexCredentials {
        CodexCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken ?? self.refreshToken,
            idToken: idToken ?? self.idToken,
            accountID: accountID,
            lastRefresh: Date()
        )
    }
}

private struct ClaudeCredentialsEnvelope: Decodable {
    var claudeAiOauth: ClaudeCredentials?
}

private struct CodexAuthFile: Decodable {
    var tokens: CodexTokens?
    var lastRefresh: String?

    var credentials: CodexCredentials? {
        guard let tokens else { return nil }
        return CodexCredentials(
            accessToken: tokens.accessToken ?? "",
            refreshToken: tokens.refreshToken ?? "",
            idToken: tokens.idToken,
            accountID: tokens.accountId,
            lastRefresh: lastRefresh.flatMap(Self.isoDate)
        )
    }

    private static func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct CodexTokens: Decodable {
    var accessToken: String?
    var refreshToken: String?
    var idToken: String?
    var accountId: String?
}

private struct ClaudeRefreshResponse: Decodable {
    var accessToken: String
    var refreshToken: String?
    var expiresIn: Double?
}

private struct CodexRefreshResponse: Decodable {
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
}

private enum AIUsageError: Error, LocalizedError, Equatable {
    case missingRefreshToken
    case invalidResponse
    case unauthorized
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "refresh token mancante"
        case .invalidResponse:
            return "risposta non valida"
        case .unauthorized:
            return "sessione scaduta"
        case .httpStatus(let status):
            return "HTTP \(status)"
        }
    }

    static func message(for error: Error) -> String {
        if let usageError = error as? AIUsageError {
            return usageError.errorDescription ?? "errore sconosciuto"
        }
        return error.localizedDescription
    }
}

private extension AIUsageReader {
    func loadClaudeCredentials() -> ClaudeCredentials? {
        if let credentials = keychainJSON(ClaudeCredentialsEnvelope.self, service: "Claude Code-credentials")?.claudeAiOauth {
            return credentials
        }

        var urls: [URL] = []
        if let config = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !config.isEmpty {
            urls.append(URL(fileURLWithPath: (config as NSString).expandingTildeInPath).appendingPathComponent(".credentials.json"))
        }
        urls.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude")
                .appendingPathComponent(".credentials.json")
        )

        for url in urls {
            if let credentials = fileJSON(ClaudeCredentialsEnvelope.self, url: url)?.claudeAiOauth {
                return credentials
            }
        }

        return nil
    }

    func loadCodexCredentials() -> CodexCredentials? {
        var urls: [URL] = []
        if let home = ProcessInfo.processInfo.environment["CODEX_HOME"], !home.isEmpty {
            urls.append(URL(fileURLWithPath: (home as NSString).expandingTildeInPath).appendingPathComponent("auth.json"))
        }

        let userHome = FileManager.default.homeDirectoryForCurrentUser
        urls.append(
            userHome
                .appendingPathComponent(".config")
                .appendingPathComponent("codex")
                .appendingPathComponent("auth.json")
        )
        urls.append(
            userHome
                .appendingPathComponent(".codex")
                .appendingPathComponent("auth.json")
        )

        for url in urls {
            if let credentials = fileJSON(CodexAuthFile.self, url: url)?.credentials {
                return credentials
            }
        }

        return keychainJSON(CodexAuthFile.self, service: "Codex Auth")?.credentials
    }

    func fileJSON<T: Decodable>(_ type: T.Type, url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.aiUsage.decode(type, from: data)
    }

    func keychainJSON<T: Decodable>(_ type: T.Type, service: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }

        return try? JSONDecoder.aiUsage.decode(type, from: data)
    }
}

extension JSONDecoder {
    static var aiUsage: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension KeyedDecodingContainer {
    func flexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
