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

@Test func formatsCompactMenuBarSelection() {
    var snapshot = SystemSnapshot.empty
    snapshot.cpuUsage = 0.42
    snapshot.memoryUsed = 6
    snapshot.memoryTotal = 10
    snapshot.batteryPercent = 0.81
    snapshot.networkInPerSecond = 12_345
    snapshot.networkOutPerSecond = 1_234_567

    #expect(MetricsFormatter.compactMenuBarText(
        snapshot: snapshot,
        showCPU: true,
        showRAM: true,
        showDisk: false,
        showBattery: true,
        showNetwork: true
    ) == "C42 R60 B81 N12K/1M")
}

@Test func menuBarTemplateReservesTwoDigitsPerNumber() {
    #expect(MenuBarLabelSizing.template(for: "C9 R74") == "C88 R88")
    #expect(MenuBarLabelSizing.template(for: "CPU 9%  BAT 100%") == "CPU 88%  BAT 888%")
    #expect(MenuBarLabelSizing.template(for: "N12K/1M") == "N88K/88M")
    #expect(MenuBarLabelSizing.template(for: "OpenMetrics") == "OpenMetrics")
}
