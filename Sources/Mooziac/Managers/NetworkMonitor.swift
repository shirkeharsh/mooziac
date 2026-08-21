import Foundation
import Network
import AppKit

public final class NetworkMonitor {
    public static let shared = NetworkMonitor()
    
    public static let statusChangedNotification = Notification.Name("NetworkMonitorStatusChanged")
    public static let reconnectedNotification = Notification.Name("NetworkMonitorReconnected")
    
    public enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case other = "Network"
        case none = "Offline"
    }
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.mooziac.networkmonitor", qos: .utility)
    
    private(set) public var isReachable: Bool = true {
        didSet {
            if oldValue != isReachable {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NetworkMonitor.statusChangedNotification,
                        object: self,
                        userInfo: [
                            "isReachable": self.isReachable,
                            "connectionType": self.connectionType
                        ]
                    )
                    if self.isReachable {
                        NotificationCenter.default.post(
                            name: NetworkMonitor.reconnectedNotification,
                            object: self
                        )
                    }
                }
            }
        }
    }
    
    private(set) public var connectionType: ConnectionType = .wifi
    private var isMonitoring = false
    
    private init() {
        monitor = NWPathMonitor()
    }
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let status = path.status == .satisfied
            let type = self.getInterfaceType(from: path)
            
            self.connectionType = status ? type : .none
            self.isReachable = status
            
            print("[NetworkMonitor] Status changed: \(status ? "ONLINE (\(type.rawValue))" : "OFFLINE")")
        }
        
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
    }
    
    private func getInterfaceType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .other
        }
    }
}
