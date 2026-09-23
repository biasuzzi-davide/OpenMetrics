import SwiftUI

/// Ogni metrica ha una tinta stabile, cosi si riconosce a colpo d'occhio senza leggere
/// l'etichetta. Sopra soglia la tinta cede il posto ad arancio e rosso.
enum MetricTint {
    static let cpu = Color.blue
    static let memory = Color.purple
    static let disk = Color.orange
    static let battery = Color.green
    static let networkIn = Color.teal
    static let networkOut = Color.indigo
    static let temperature = Color.pink
    static let uptime = Color.gray
    static let system = Color.gray

    static func provider(_ id: AIProviderID) -> Color {
        switch id {
        case .claude:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:
            return Color(red: 0.06, green: 0.64, blue: 0.50)
        }
    }

    /// Tinta per una frazione di utilizzo: normale, alta o critica.
    static func usage(_ fraction: Double?, base: Color, warning: Double = 0.8, critical: Double = 0.95) -> Color {
        guard let fraction else { return base }
        if fraction >= critical { return .red }
        if fraction >= warning { return .orange }
        return base
    }

    /// La batteria preoccupa quando scende, non quando sale.
    static func battery(_ fraction: Double, charging: Bool) -> Color {
        guard !charging else { return battery }
        if fraction <= 0.1 { return .red }
        if fraction <= 0.25 { return .orange }
        return battery
    }

    static func thermal(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}
