import Foundation

struct SystemSnapshot: Equatable {
    var cpuUsage: Double
    var loadAverage: [Double]
    var processorCount: Int
    var activeProcessorCount: Int
    var memoryUsed: UInt64
    var memoryTotal: UInt64
    var memoryFree: UInt64
    var memoryCached: UInt64
    var memoryWired: UInt64
    var memoryCompressed: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var diskUsed: UInt64
    var diskTotal: UInt64
    var diskAvailable: UInt64
    var batteryPercent: Double?
    var batteryIsCharging: Bool?
    var batteryTimeRemainingMinutes: Int?
    var networkInPerSecond: UInt64
    var networkOutPerSecond: UInt64
    var networkInterface: String?
    var ipAddress: String?
    var uptime: TimeInterval
    var thermalState: ProcessInfo.ThermalState
    var lowPowerModeEnabled: Bool
    var hostName: String
    var osVersion: String
    var componentTemperatures: [String: Double]
    var updatedAt: Date

    static let empty = SystemSnapshot(
        cpuUsage: 0,
        loadAverage: [0, 0, 0],
        processorCount: ProcessInfo.processInfo.processorCount,
        activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
        memoryUsed: 0,
        memoryTotal: 1,
        memoryFree: 0,
        memoryCached: 0,
        memoryWired: 0,
        memoryCompressed: 0,
        swapUsed: 0,
        swapTotal: 0,
        diskUsed: 0,
        diskTotal: 1,
        diskAvailable: 0,
        batteryPercent: nil,
        batteryIsCharging: nil,
        batteryTimeRemainingMinutes: nil,
        networkInPerSecond: 0,
        networkOutPerSecond: 0,
        networkInterface: nil,
        ipAddress: nil,
        uptime: 0,
        thermalState: .nominal,
        lowPowerModeEnabled: false,
        hostName: "Mac",
        osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        componentTemperatures: [:],
        updatedAt: .now
    )

    var memoryUsage: Double { Self.fraction(memoryUsed, memoryTotal) }
    var diskUsage: Double { Self.fraction(diskUsed, diskTotal) }
    var swapUsage: Double { Self.fraction(swapUsed, swapTotal) }

    private static func fraction(_ used: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }
}
