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

@Test func buildsMenuBarItemsFromSelection() {
    var snapshot = SystemSnapshot.empty
    snapshot.cpuUsage = 0.42
    snapshot.memoryUsed = 6
    snapshot.memoryTotal = 10
    snapshot.batteryPercent = 0.81
    snapshot.batteryIsCharging = true
    snapshot.networkInPerSecond = 12_345
    snapshot.networkOutPerSecond = 1_234_567

    let items = MetricsFormatter.menuBarItems(
        snapshot: snapshot,
        showCPU: true,
        showRAM: true,
        showDisk: false,
        showBattery: true,
        showNetwork: true
    )

    #expect(items.map(\.symbol) == ["cpu", "memorychip", "battery.100.bolt", "arrow.down", "arrow.up"])
    #expect(items.map(\.text) == ["42%", "60%", "81%", "12K", "1M"])
    #expect(items.map(\.template) == ["888%", "888%", "888%", "888M", "888M"])
}

@Test func menuBarItemsAreEmptyWithoutSelection() {
    let items = MetricsFormatter.menuBarItems(
        snapshot: .empty,
        showCPU: false,
        showRAM: false,
        showDisk: false,
        showBattery: false,
        showNetwork: false
    )

    #expect(items.isEmpty)
}

@Test func menuBarTemplateReservesTwoDigitsPerNumber() {
    #expect(MenuBarLabelSizing.template(for: "C9 R74") == "C88 R88")
    #expect(MenuBarLabelSizing.template(for: "CPU 9%  BAT 100%") == "CPU 88%  BAT 888%")
    #expect(MenuBarLabelSizing.template(for: "N12K/1M") == "N88K/88M")
    #expect(MenuBarLabelSizing.template(for: "OpenMetrics") == "OpenMetrics")
}

@Test func formatsRatesCompactly() {
    #expect(MetricsFormatter.rate(0) == "0 B/s")
    #expect(MetricsFormatter.rate(942) == "942 B/s")
    #expect(MetricsFormatter.rate(12_345).hasSuffix(" KB/s"))
    #expect(MetricsFormatter.rate(12_345).hasPrefix("12"))
    #expect(MetricsFormatter.rate(1_150_000).hasSuffix(" MB/s"))
    #expect(MetricsFormatter.rate(1_150_000).hasPrefix("1"))
}
