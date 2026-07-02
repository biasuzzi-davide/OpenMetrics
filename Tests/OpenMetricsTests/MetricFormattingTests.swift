import Testing
@testable import OpenMetrics

@Test func clampsPercentValues() {
    #expect(MetricsFormatter.percent(-1) == "0%")
    #expect(MetricsFormatter.percent(0.123) == "12%")
    #expect(MetricsFormatter.percent(2) == "100%")
}

@Test func formatsShortDurations() {
    #expect(MetricsFormatter.duration(59) == "0m")
    #expect(MetricsFormatter.duration(3_900) == "1h 5m")
    #expect(MetricsFormatter.duration(180_000) == "2g 2h")
}

@Test func formatsMenuBarSelection() {
    var snapshot = SystemSnapshot.empty
    snapshot.cpuUsage = 0.42
    snapshot.memoryUsed = 6
    snapshot.memoryTotal = 10
    snapshot.batteryPercent = 0.81

    #expect(MetricsFormatter.menuBarText(
        snapshot: snapshot,
        showCPU: true,
        showRAM: true,
        showDisk: false,
        showBattery: true,
        showNetwork: false
    ) == "CPU 42%  RAM 60%  BAT 81%")

    #expect(MetricsFormatter.menuBarText(
        snapshot: snapshot,
        showCPU: false,
        showRAM: false,
        showDisk: false,
        showBattery: false,
        showNetwork: false
    ) == "OpenMetrics")
}
