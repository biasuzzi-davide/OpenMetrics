import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: SettingsKey.refreshInterval) }
    }
    @Published var showCPUInMenuBar: Bool {
        didSet { defaults.set(showCPUInMenuBar, forKey: SettingsKey.showCPUInMenuBar) }
    }
    @Published var showRAMInMenuBar: Bool {
        didSet { defaults.set(showRAMInMenuBar, forKey: SettingsKey.showRAMInMenuBar) }
    }
    @Published var showDiskInMenuBar: Bool {
        didSet { defaults.set(showDiskInMenuBar, forKey: SettingsKey.showDiskInMenuBar) }
    }
    @Published var showBatteryInMenuBar: Bool {
        didSet { defaults.set(showBatteryInMenuBar, forKey: SettingsKey.showBatteryInMenuBar) }
    }
    @Published var showNetworkInMenuBar: Bool {
        didSet { defaults.set(showNetworkInMenuBar, forKey: SettingsKey.showNetworkInMenuBar) }
    }
    @Published var showClaudeInMenuBar: Bool {
        didSet { defaults.set(showClaudeInMenuBar, forKey: SettingsKey.showClaudeInMenuBar) }
    }
    @Published var showCodexInMenuBar: Bool {
        didSet { defaults.set(showCodexInMenuBar, forKey: SettingsKey.showCodexInMenuBar) }
    }
    @Published var aiUsageDisplayMode: String {
        didSet { defaults.set(aiUsageDisplayMode, forKey: SettingsKey.aiUsageDisplayMode) }
    }
    @Published var aiResetDisplayMode: String {
        didSet { defaults.set(aiResetDisplayMode, forKey: SettingsKey.aiResetDisplayMode) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: SettingsKey.launchAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            SettingsKey.refreshInterval: 1,
            SettingsKey.showCPUInMenuBar: true,
            SettingsKey.showRAMInMenuBar: true,
            SettingsKey.showDiskInMenuBar: false,
            SettingsKey.showBatteryInMenuBar: true,
            SettingsKey.showNetworkInMenuBar: false,
            SettingsKey.showClaudeInMenuBar: false,
            SettingsKey.showCodexInMenuBar: false,
            SettingsKey.aiUsageDisplayMode: AIUsageDisplayMode.used.rawValue,
            SettingsKey.aiResetDisplayMode: AIResetDisplayMode.relative.rawValue,
            SettingsKey.launchAtLogin: false
        ])

        refreshInterval = defaults.integer(forKey: SettingsKey.refreshInterval)
        showCPUInMenuBar = defaults.bool(forKey: SettingsKey.showCPUInMenuBar)
        showRAMInMenuBar = defaults.bool(forKey: SettingsKey.showRAMInMenuBar)
        showDiskInMenuBar = defaults.bool(forKey: SettingsKey.showDiskInMenuBar)
        showBatteryInMenuBar = defaults.bool(forKey: SettingsKey.showBatteryInMenuBar)
        showNetworkInMenuBar = defaults.bool(forKey: SettingsKey.showNetworkInMenuBar)
        showClaudeInMenuBar = defaults.bool(forKey: SettingsKey.showClaudeInMenuBar)
        showCodexInMenuBar = defaults.bool(forKey: SettingsKey.showCodexInMenuBar)
        aiUsageDisplayMode = defaults.string(forKey: SettingsKey.aiUsageDisplayMode) ?? AIUsageDisplayMode.used.rawValue
        aiResetDisplayMode = defaults.string(forKey: SettingsKey.aiResetDisplayMode) ?? AIResetDisplayMode.relative.rawValue
        launchAtLogin = defaults.bool(forKey: SettingsKey.launchAtLogin)
    }
}
