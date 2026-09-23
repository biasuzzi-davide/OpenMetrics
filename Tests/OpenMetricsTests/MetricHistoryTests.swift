import Testing
@testable import OpenMetrics

@Test func historyKeepsOnlyLatestSamples() {
    var history = MetricHistory()
    for index in 0..<(MetricHistory.capacity + 5) {
        var snapshot = SystemSnapshot.empty
        snapshot.cpuUsage = Double(index)
        snapshot.networkInPerSecond = UInt64(index)
        history.append(snapshot)
    }

    #expect(history.cpu.count == MetricHistory.capacity)
    #expect(history.cpu.first == 5)
    #expect(history.cpu.last == Double(MetricHistory.capacity + 4))
    #expect(history.networkIn.count == MetricHistory.capacity)
}
