import AppKit
import Foundation
import Darwin
import IOKit

public struct ProcessNodeTelemetry: Identifiable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let role: String
    public let ramMB: Double
    public let ramFootprintMB: Double
    public let cpuPercent: Double
    public let diskReadMB: Double
    public let diskWriteMB: Double
    public let threadCount: Int
    
    public init(
        pid: Int32,
        name: String,
        role: String,
        ramMB: Double,
        ramFootprintMB: Double,
        cpuPercent: Double,
        diskReadMB: Double,
        diskWriteMB: Double,
        threadCount: Int
    ) {
        self.pid = pid
        self.name = name
        self.role = role
        self.ramMB = ramMB
        self.ramFootprintMB = ramFootprintMB
        self.cpuPercent = cpuPercent
        self.diskReadMB = diskReadMB
        self.diskWriteMB = diskWriteMB
        self.threadCount = threadCount
    }
}

public struct PlayerTelemetryInfo {
    public var isRunning: Bool = false
    public var hostPid: Int32 = 0
    public var processCount: Int = 0
    public var totalCpuPercent: Double = 0.0
    public var totalRamMB: Double = 0.0
    public var totalRamFootprintMB: Double = 0.0
    public var gpuPercent: Double = 0.0
    public var totalDiskReadMB: Double = 0.0
    public var totalDiskWriteMB: Double = 0.0
    public var totalDiskStorageMB: Double = 0.0
    public var totalThreadCount: Int = 0
    public var subProcesses: [ProcessNodeTelemetry] = []
    public var lastUpdated: Date = Date()
    
    // Convenience properties for compatibility
    public var pid: Int32 { hostPid }
    public var cpuPercent: Double { totalCpuPercent }
    public var memoryMB: Double { totalRamMB }
    public var memoryFootprintMB: Double { totalRamFootprintMB }
    public var diskReadMB: Double { totalDiskReadMB }
    public var diskWriteMB: Double { totalDiskWriteMB }
    public var diskStorageMB: Double { totalDiskStorageMB }
    public var threadCount: Int { totalThreadCount }
    
    public init(
        isRunning: Bool = false,
        hostPid: Int32 = 0,
        processCount: Int = 0,
        totalCpuPercent: Double = 0.0,
        totalRamMB: Double = 0.0,
        totalRamFootprintMB: Double = 0.0,
        gpuPercent: Double = 0.0,
        totalDiskReadMB: Double = 0.0,
        totalDiskWriteMB: Double = 0.0,
        totalDiskStorageMB: Double = 0.0,
        totalThreadCount: Int = 0,
        subProcesses: [ProcessNodeTelemetry] = [],
        lastUpdated: Date = Date()
    ) {
        self.isRunning = isRunning
        self.hostPid = hostPid
        self.processCount = processCount
        self.totalCpuPercent = totalCpuPercent
        self.totalRamMB = totalRamMB
        self.totalRamFootprintMB = totalRamFootprintMB
        self.gpuPercent = gpuPercent
        self.totalDiskReadMB = totalDiskReadMB
        self.totalDiskWriteMB = totalDiskWriteMB
        self.totalDiskStorageMB = totalDiskStorageMB
        self.totalThreadCount = totalThreadCount
        self.subProcesses = subProcesses
        self.lastUpdated = lastUpdated
    }
}

public struct VpsTelemetryInfo {
    public var isReachable: Bool = false
    public var httpStatusCode: Int = 0
    public var latencyMs: Int = 0
    public var host: String = "13.234.245.199"
    public var url: String = "https://mooziac.threeten.site"
    public var lastChecked: Date = Date()
}

public final class TelemetryMonitor {
    public static let shared = TelemetryMonitor()
    
    private var lastCpuTimes: [pid_t: UInt64] = [:]
    private var lastTimestamps: [pid_t: CFAbsoluteTime] = [:]
    private let queue = DispatchQueue(label: "app.mooziac.studio.telemetry", qos: .userInteractive)
    
    public init() {}
    
    private func getMooziacHostPid() -> pid_t? {
        let byBundle = NSRunningApplication.runningApplications(withBundleIdentifier: "app.mooziac.mac")
        if let first = byBundle.first {
            return first.processIdentifier
        }
        let allApps = NSWorkspace.shared.runningApplications
        if let found = allApps.first(where: {
            ($0.localizedName == "Mooziac" || $0.bundleIdentifier == "app.mooziac.mac") &&
            $0.bundleIdentifier != "app.mooziac.studio"
        }) {
            return found.processIdentifier
        }
        return nil
    }
    
    private func getTreePids() -> [(pid: pid_t, name: String, role: String)] {
        guard let hostPid = getMooziacHostPid() else { return [] }
        var list: [(pid: pid_t, name: String, role: String)] = [
            (hostPid, "Mooziac", "Host App Player")
        ]
        
        let numPids = proc_listallpids(nil, 0)
        if numPids > 0 {
            var allPids = [pid_t](repeating: 0, count: Int(numPids))
            let actual = proc_listallpids(&allPids, Int32(allPids.count * MemoryLayout<pid_t>.size))
            for i in 0..<Int(actual) {
                let p = allPids[i]
                guard p > 0 && p != hostPid else { continue }
                
                var nameBuf = [CChar](repeating: 0, count: 1024)
                proc_name(p, &nameBuf, 1024)
                let name = String(cString: nameBuf)
                
                if name == "com.apple.WebKit.WebContent" {
                    list.append((p, name, "WebKit WebContent (DOM/Audio)"))
                } else if name == "com.apple.WebKit.GPU" {
                    list.append((p, name, "WebKit GPU Acceleration"))
                } else if name == "com.apple.WebKit.Networking" {
                    list.append((p, name, "WebKit Network Engine"))
                }
            }
        }
        return list
    }
    
    public func fetchPlayerTelemetry(completion: @escaping (PlayerTelemetryInfo) -> Void) {
        queue.async {
            let tree = self.getTreePids()
            guard !tree.isEmpty, let hostItem = tree.first else {
                DispatchQueue.main.async { completion(PlayerTelemetryInfo()) }
                return
            }
            
            var totalRamRes: Double = 0
            var totalRamFoot: Double = 0
            var totalCpu: Double = 0
            var totalRead: Double = 0
            var totalWrite: Double = 0
            var totalThreads: Int = 0
            var nodeMetrics: [ProcessNodeTelemetry] = []
            
            let now = CFAbsoluteTimeGetCurrent()
            for item in tree {
                var rusage = rusage_info_v4()
                let res = withUnsafeMutablePointer(to: &rusage) { ptr in
                    ptr.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) { rusagePtr in
                        proc_pid_rusage(item.pid, RUSAGE_INFO_V4, rusagePtr)
                    }
                }
                let ramMB = (res == 0) ? Double(rusage.ri_resident_size) / 1_048_576.0 : 0
                let footMB = (res == 0) ? Double(rusage.ri_phys_footprint) / 1_048_576.0 : 0
                let rMB = (res == 0) ? Double(rusage.ri_diskio_bytesread) / 1_048_576.0 : 0
                let wMB = (res == 0) ? Double(rusage.ri_diskio_byteswritten) / 1_048_576.0 : 0
                
                totalRamRes += ramMB
                totalRamFoot += footMB
                totalRead += rMB
                totalWrite += wMB
                
                var procCpu: Double = 0
                var taskInfo = proc_taskinfo()
                let size = Int32(MemoryLayout<proc_taskinfo>.size)
                var pThreads = 0
                if proc_pidinfo(item.pid, PROC_PIDTASKINFO, 0, &taskInfo, size) == size {
                    pThreads = Int(taskInfo.pti_threadnum)
                    totalThreads += pThreads
                    let totalCpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
                    if let lastT = self.lastTimestamps[item.pid], let lastCpu = self.lastCpuTimes[item.pid], now > lastT && totalCpuTime >= lastCpu {
                        let deltaNs = Double(totalCpuTime - lastCpu)
                        let deltaSec = now - lastT
                        procCpu = (deltaNs / 1_000_000_000.0) / deltaSec * 100.0
                    }
                    self.lastCpuTimes[item.pid] = totalCpuTime
                    self.lastTimestamps[item.pid] = now
                }
                totalCpu += procCpu
                
                nodeMetrics.append(ProcessNodeTelemetry(
                    pid: item.pid,
                    name: item.name,
                    role: item.role,
                    ramMB: ramMB,
                    ramFootprintMB: footMB,
                    cpuPercent: procCpu,
                    diskReadMB: rMB,
                    diskWriteMB: wMB,
                    threadCount: pThreads
                ))
            }
            
            // Live GPU Hardware via IOKit
            var gpuPercent: Double = 0.0
            var iterator = io_iterator_t()
            let matching = IOServiceMatching("IOAccelerator")
            if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
                var service = IOIteratorNext(iterator)
                while service != 0 {
                    var props: Unmanaged<CFMutableDictionary>?
                    if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                       let dict = props?.takeRetainedValue() as? [String: Any],
                       let stats = dict["PerformanceStatistics"] as? [String: Any] {
                        if let util = stats["Device Utilization %"] as? Double {
                            gpuPercent = util
                        } else if let util = stats["Device Utilization %"] as? Int {
                            gpuPercent = Double(util)
                        }
                    }
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }
                IOObjectRelease(iterator)
            }
            
            // Total Disk Storage across App Support, WebKit Data, Caches, & Music Library
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
            let mooziacDir = appSupport.appendingPathComponent("Mooziac")
            var storageBytes: Int64 = 0
            let pathsToMeasure = [
                mooziacDir,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/app.mooziac.mac"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/WebKit/app.mooziac.mac"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Mooziac")
            ]
            for folder in pathsToMeasure {
                if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                            storageBytes += Int64(size)
                        }
                    }
                }
            }
            let storageMB = Double(storageBytes) / 1_048_576.0
            
            let info = PlayerTelemetryInfo(
                isRunning: true,
                hostPid: hostItem.pid,
                processCount: tree.count,
                totalCpuPercent: totalCpu,
                totalRamMB: totalRamRes,
                totalRamFootprintMB: totalRamFoot,
                gpuPercent: gpuPercent,
                totalDiskReadMB: totalRead,
                totalDiskWriteMB: totalWrite,
                totalDiskStorageMB: storageMB,
                totalThreadCount: totalThreads,
                subProcesses: nodeMetrics,
                lastUpdated: Date()
            )
            
            DispatchQueue.main.async {
                completion(info)
            }
        }
    }
    
    public func pingVpsServer(completion: @escaping (VpsTelemetryInfo) -> Void) {
        guard let url = URL(string: "https://mooziac.threeten.site") else {
            completion(VpsTelemetryInfo())
            return
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let latency = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let isReachable = (error == nil && (200...399).contains(statusCode))
            
            let info = VpsTelemetryInfo(
                isReachable: isReachable,
                httpStatusCode: statusCode,
                latencyMs: latency,
                host: "13.234.245.199",
                url: "https://mooziac.threeten.site",
                lastChecked: Date()
            )
            DispatchQueue.main.async { completion(info) }
        }.resume()
    }
}
