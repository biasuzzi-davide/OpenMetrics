import Foundation

/// Ultimi campioni delle metriche che hanno senso nel tempo: alimentano le sparkline del pannello.
struct MetricHistory: Equatable, Sendable {
    static let capacity = 60

    private(set) var cpu: [Double] = []
    private(set) var memory: [Double] = []
    private(set) var networkIn: [Double] = []
    private(set) var networkOut: [Double] = []

    mutating func append(_ snapshot: SystemSnapshot) {
        Self.push(&cpu, snapshot.cpuUsage)
        Self.push(&memory, snapshot.memoryUsage)
        Self.push(&networkIn, Double(snapshot.networkInPerSecond))
        Self.push(&networkOut, Double(snapshot.networkOutPerSecond))
    }

    private static func push(_ values: inout [Double], _ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }
}
