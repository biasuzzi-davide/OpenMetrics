import Darwin
import Foundation
import IOKit.ps

final class SystemReader {
    private var previousCPU: [processor_cpu_load_info]?
    private var previousNetwork: NetworkSample?

    func read() -> SystemSnapshot {
        let memory = readMemory()
        let disk = readDisk()
        let network = readNetwork()
        let battery = readBattery()

        return SystemSnapshot(
            cpuUsage: readCPUUsage(),
            loadAverage: readLoadAverage(),
            processorCount: ProcessInfo.processInfo.processorCount,
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            memoryFree: memory.free,
            memoryCached: memory.cached,
            memoryWired: memory.wired,
            memoryCompressed: memory.compressed,
            swapUsed: memory.swapUsed,
            swapTotal: memory.swapTotal,
            diskUsed: disk.used,
            diskTotal: disk.total,
            diskAvailable: disk.available,
            batteryPercent: battery?.percent,
            batteryIsCharging: battery?.isCharging,
            batteryTimeRemainingMinutes: battery?.timeRemainingMinutes,
            networkInPerSecond: network.receivedPerSecond,
            networkOutPerSecond: network.sentPerSecond,
            networkInterface: network.interfaceName,
            ipAddress: network.ipAddress,
            uptime: ProcessInfo.processInfo.systemUptime,
            thermalState: ProcessInfo.processInfo.thermalState,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            hostName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            updatedAt: .now
        )
    }

    private func readCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let loads = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) {
            Array(UnsafeBufferPointer(start: $0, count: Int(cpuCount)))
        }

        guard let previousCPU, previousCPU.count == loads.count else {
            previousCPU = loads
            return 0
        }

        var idle: UInt64 = 0
        var total: UInt64 = 0

        for (current, previous) in zip(loads, previousCPU) {
            let currentTicks = ticks(current)
            let previousTicks = ticks(previous)

            for index in currentTicks.indices {
                let delta = UInt64(currentTicks[index] &- previousTicks[index])
                total += delta
                if index == CPU_STATE_IDLE {
                    idle += delta
                }
            }
        }

        self.previousCPU = loads
        guard total > 0 else { return 0 }
        return 1 - (Double(idle) / Double(total))
    }

    private func ticks(_ load: processor_cpu_load_info) -> [UInt32] {
        [load.cpu_ticks.0, load.cpu_ticks.1, load.cpu_ticks.2, load.cpu_ticks.3]
    }

    private func readLoadAverage() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        guard getloadavg(&values, Int32(values.count)) == Int32(values.count) else {
            return [0, 0, 0]
        }
        return values
    }

    private func readMemory() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        let swap = readSwap()
        guard result == KERN_SUCCESS else {
            return MemorySnapshot.empty(total: total, swap: swap)
        }

        let pageSize = UInt64(getpagesize())
        let free = UInt64(stats.free_count) * pageSize
        let cached = UInt64(stats.inactive_count + stats.speculative_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let used = min(active + wired + compressed, total)

        return MemorySnapshot(
            used: used,
            total: total,
            free: free,
            cached: cached,
            wired: wired,
            compressed: compressed,
            swapUsed: swap.used,
            swapTotal: swap.total
        )
    }

    private func readSwap() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else {
            return (0, 0)
        }
        return (usage.xsu_used, usage.xsu_total)
    }

    private func readDisk() -> (used: UInt64, total: UInt64, available: UInt64) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = UInt64(max(values?.volumeTotalCapacity ?? 0, 0))
        let available = UInt64(max(values?.volumeAvailableCapacityForImportantUsage ?? 0, 0))
        return (total > available ? total - available : 0, total, available)
    }

    private func readBattery() -> BatterySnapshot? {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            guard description[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Double ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Double ?? 0
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let empty = description[kIOPSTimeToEmptyKey as String] as? Int
            let full = description[kIOPSTimeToFullChargeKey as String] as? Int
            let timeRemaining = isCharging ? validMinutes(full) : validMinutes(empty)

            guard maxCapacity > 0 else { return nil }

            return BatterySnapshot(
                percent: min(max(current / maxCapacity, 0), 1),
                isCharging: isCharging,
                timeRemainingMinutes: timeRemaining
            )
        }

        return nil
    }

    private func validMinutes(_ value: Int?) -> Int? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private func readNetwork() -> NetworkSnapshot {
        let current = readNetworkTotals()
        defer {
            previousNetwork = NetworkSample(totals: current.totals, timestamp: current.timestamp)
        }

        guard let previousNetwork else {
            return NetworkSnapshot(
                receivedPerSecond: 0,
                sentPerSecond: 0,
                interfaceName: current.interfaceName,
                ipAddress: current.ipAddress
            )
        }

        let seconds = max(current.timestamp.timeIntervalSince(previousNetwork.timestamp), 0.1)
        let received = current.totals.received >= previousNetwork.totals.received ? current.totals.received - previousNetwork.totals.received : 0
        let sent = current.totals.sent >= previousNetwork.totals.sent ? current.totals.sent - previousNetwork.totals.sent : 0

        return NetworkSnapshot(
            receivedPerSecond: UInt64(Double(received) / seconds),
            sentPerSecond: UInt64(Double(sent) / seconds),
            interfaceName: current.interfaceName,
            ipAddress: current.ipAddress
        )
    }

    private func readNetworkTotals() -> NetworkRead {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let first = addressList else {
            return NetworkRead.empty
        }
        defer { freeifaddrs(addressList) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var interfaceName: String?
        var ipAddress: String?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let pointer = cursor {
            let interface = pointer.pointee
            defer { cursor = interface.ifa_next }

            guard let address = interface.ifa_addr else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp, !isLoopback else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            let family = address.pointee.sa_family

            if family == UInt8(AF_LINK), let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                received += UInt64(data.ifi_ibytes)
                sent += UInt64(data.ifi_obytes)
                interfaceName = interfaceName ?? name
            }

            if family == UInt8(AF_INET), ipAddress == nil {
                ipAddress = numericAddress(from: address)
                interfaceName = interfaceName ?? name
            }
        }

        return NetworkRead(
            totals: NetworkTotals(received: received, sent: sent),
            timestamp: .now,
            interfaceName: interfaceName,
            ipAddress: ipAddress
        )
    }

    private func numericAddress(from address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        guard result == 0 else { return nil }
        let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

private struct MemorySnapshot {
    var used: UInt64
    var total: UInt64
    var free: UInt64
    var cached: UInt64
    var wired: UInt64
    var compressed: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64

    static func empty(total: UInt64, swap: (used: UInt64, total: UInt64)) -> MemorySnapshot {
        MemorySnapshot(
            used: 0,
            total: total,
            free: 0,
            cached: 0,
            wired: 0,
            compressed: 0,
            swapUsed: swap.used,
            swapTotal: swap.total
        )
    }
}

private struct BatterySnapshot {
    var percent: Double
    var isCharging: Bool
    var timeRemainingMinutes: Int?
}

private struct NetworkSnapshot {
    var receivedPerSecond: UInt64
    var sentPerSecond: UInt64
    var interfaceName: String?
    var ipAddress: String?
}

private struct NetworkRead {
    var totals: NetworkTotals
    var timestamp: Date
    var interfaceName: String?
    var ipAddress: String?

    static let empty = NetworkRead(
        totals: NetworkTotals(received: 0, sent: 0),
        timestamp: .now,
        interfaceName: nil,
        ipAddress: nil
    )
}

private struct NetworkSample {
    var totals: NetworkTotals
    var timestamp: Date
}

private struct NetworkTotals {
    var received: UInt64
    var sent: UInt64
}
