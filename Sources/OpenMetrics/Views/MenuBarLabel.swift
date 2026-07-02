import SwiftUI

struct MenuBarLabel: View {
    var snapshot: SystemSnapshot

    @AppStorage(SettingsKey.showCPUInMenuBar) private var showCPU = true
    @AppStorage(SettingsKey.showRAMInMenuBar) private var showRAM = true
    @AppStorage(SettingsKey.showDiskInMenuBar) private var showDisk = false
    @AppStorage(SettingsKey.showBatteryInMenuBar) private var showBattery = true
    @AppStorage(SettingsKey.showNetworkInMenuBar) private var showNetwork = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
            Text(MetricsFormatter.menuBarText(
                snapshot: snapshot,
                showCPU: showCPU,
                showRAM: showRAM,
                showDisk: showDisk,
                showBattery: showBattery,
                showNetwork: showNetwork
            ))
            .monospacedDigit()
        }
    }
}
