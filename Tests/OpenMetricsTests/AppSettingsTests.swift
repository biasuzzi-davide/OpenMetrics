import Foundation
import Testing
@testable import OpenMetrics

@MainActor
@Test func appSettingsPersistMenuBarAIFlags() {
    let suiteName = "OpenMetricsTests-\(UUID().uuidString)"
    let defaults = try! #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    settings.showClaudeInMenuBar = true
    settings.showCodexInMenuBar = true

    #expect(defaults.bool(forKey: SettingsKey.showClaudeInMenuBar))
    #expect(defaults.bool(forKey: SettingsKey.showCodexInMenuBar))
}
