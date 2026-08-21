import Foundation
import AppKit

enum RPCOpcode: UInt32 {
    case handshake = 0
    case frame = 1
    case close = 2
    case ping = 3
    case pong = 4
}

final class DiscordRPCManager {
    static let shared = DiscordRPCManager()
    
    private var socketFd: Int32 = -1
    private var _isConnected: Bool = false
    public var isConnected: Bool {
        queue.sync { _isConnected }
    }
    
    // Official Mooziac Discord RPC Client ID (Authenticated & Registered with Discord)
    private let clientId = "1537169013174435870"
    private var reconnectTimer: Timer?
    private var periodicRefreshCounter: Int = 0
    private let queue = DispatchQueue(label: "com.mooziac.discordrpc", qos: .utility)
    
    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_discordRPC_enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "YTM_discordRPC_enabled")
            queue.async { [weak self] in
                guard let self = self else { return }
                if newValue {
                    self.tryConnectInternal()
                    self.updatePresenceInternal(state: NowPlayingManager.shared.currentState)
                } else {
                    self.clearPresenceInternal()
                    self.closeSocketInternal()
                }
            }
        }
    }
    
    private init() {
        // Prevent process termination on SIGPIPE when socket writes fail (EPIPE)
        signal(SIGPIPE, SIG_IGN)
        startReconnectLoop()
    }
    
    deinit {
        stopReconnectLoop()
        queue.sync {
            self.closeSocketInternal()
        }
    }
    
    public func startReconnectLoop() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.queue.async { [weak self] in
                    guard let self = self, self.isEnabled else { return }
                    if !self._isConnected {
                        self.tryConnectInternal()
                    } else {
                        // Periodic heartbeat/refresh every 12 seconds to prevent presence timeouts
                        self.periodicRefreshCounter += 1
                        if self.periodicRefreshCounter >= 3 {
                            self.periodicRefreshCounter = 0
                            self.drainSocket()
                            if self._isConnected {
                                self.updatePresenceInternal(state: NowPlayingManager.shared.currentState)
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func stopReconnectLoop() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = nil
        }
    }
    
    public func tryConnect() {
        queue.async { [weak self] in
            self?.tryConnectInternal()
        }
    }
    
    private func tryConnectInternal() {
        guard isEnabled, !_isConnected else { return }
        guard let socketPath = findDiscordIPCSocket() else { return }
        if connectToSocket(path: socketPath) {
            updatePresenceInternal(state: NowPlayingManager.shared.currentState)
        }
    }
    
    private func findDiscordIPCSocket() -> String? {
        let tmpDir = NSTemporaryDirectory()
        let envTmp = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"
        let fm = FileManager.default
        
        let candidateDirs = ["/tmp", tmpDir, envTmp]
        
        for dir in candidateDirs {
            let cleanDir = dir.hasSuffix("/") ? String(dir.dropLast()) : dir
            for i in 0..<10 {
                let path = "\(cleanDir)/discord-ipc-\(i)"
                if fm.fileExists(atPath: path) {
                    return path
                }
            }
        }
        
        if let subdirs = try? fm.contentsOfDirectory(atPath: tmpDir) {
            for sub in subdirs where sub.hasPrefix("discord-ipc-") {
                let full = (tmpDir as NSString).appendingPathComponent(sub)
                if fm.fileExists(atPath: full) { return full }
            }
        }
        
        return nil
    }
    
    private func connectToSocket(path: String) -> Bool {
        closeSocketInternal()
        
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        
        // Disable SIGPIPE signal for this socket on Darwin/macOS
        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))
        
        // Set a 2-second timeout for handshake
        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_un()
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            return false
        }
        
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            for (i, byte) in pathBytes.enumerated() {
                raw[i] = byte
            }
        }
        
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(fd, saPtr, size)
            }
        }
        
        guard result == 0 else {
            close(fd)
            return false
        }
        
        // Send Handshake
        let handshakeJSON = "{\"v\":1,\"client_id\":\"\(clientId)\"}"
        guard let hsData = handshakeJSON.data(using: .utf8) else {
            close(fd)
            return false
        }
        
        var op: UInt32 = RPCOpcode.handshake.rawValue.littleEndian
        var len = UInt32(hsData.count).littleEndian
        var packet = Data()
        packet.append(Data(bytes: &op, count: 4))
        packet.append(Data(bytes: &len, count: 4))
        packet.append(hsData)
        
        let sent = packet.withUnsafeBytes { send(fd, $0.baseAddress, packet.count, 0) }
        guard sent == packet.count else {
            close(fd)
            return false
        }
        
        // Synchronously read and verify READY frame from Discord
        var headerBuf = [UInt8](repeating: 0, count: 8)
        let headerRead = recv(fd, &headerBuf, 8, 0)
        guard headerRead == 8 else {
            close(fd)
            return false
        }
        
        let respLen = headerBuf[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) }
        guard respLen > 0 && respLen < 65536 else {
            close(fd)
            return false
        }
        
        var bodyBuf = [UInt8](repeating: 0, count: Int(respLen))
        let bodyRead = recv(fd, &bodyBuf, Int(respLen), 0)
        guard bodyRead == Int(respLen) else {
            close(fd)
            return false
        }
        
        let respBody = String(bytes: bodyBuf, encoding: .utf8) ?? ""
        guard respBody.contains("READY") else {
            close(fd)
            return false
        }
        
        self.socketFd = fd
        self._isConnected = true
        self.periodicRefreshCounter = 0
        return true
    }
    
    private func closeSocketInternal() {
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }
        _isConnected = false
    }
    
    private func drainSocket() {
        guard socketFd >= 0 else { return }
        var headerBuf = [UInt8](repeating: 0, count: 8)
        
        while true {
            let bytesRead = recv(socketFd, &headerBuf, 8, MSG_DONTWAIT)
            if bytesRead <= 0 {
                let err = errno
                if bytesRead == 0 || (bytesRead < 0 && err != EWOULDBLOCK && err != EAGAIN) {
                    closeSocketInternal()
                }
                break
            }
            
            if bytesRead == 8 {
                let opcode = headerBuf[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) }
                let payloadLen = headerBuf[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) }
                
                if payloadLen > 0 && payloadLen < 65536 {
                    var bodyBuf = [UInt8](repeating: 0, count: Int(payloadLen))
                    let bRead = recv(socketFd, &bodyBuf, Int(payloadLen), 0)
                    if bRead <= 0 {
                        closeSocketInternal()
                        break
                    }
                    
                    // Reply to Discord PING with PONG
                    if opcode == RPCOpcode.ping.rawValue {
                        let pingPayload = String(bytes: bodyBuf, encoding: .utf8) ?? "{}"
                        _ = sendFrame(opcode: .pong, payload: pingPayload)
                    }
                }
            }
        }
    }
    
    private func sendFrame(opcode: RPCOpcode, payload: String) -> Bool {
        guard socketFd >= 0 else { return false }
        guard let payloadData = payload.data(using: .utf8) else { return false }
        
        var op = opcode.rawValue.littleEndian
        var len = UInt32(payloadData.count).littleEndian
        
        var header = Data()
        header.append(Data(bytes: &op, count: 4))
        header.append(Data(bytes: &len, count: 4))
        
        let packet = header + payloadData
        let bytesSent = packet.withUnsafeBytes { ptr in
            send(socketFd, ptr.baseAddress, packet.count, 0)
        }
        
        if bytesSent != packet.count {
            closeSocketInternal()
            return false
        }
        
        drainSocket()
        return true
    }
    
    public func updatePresence(state: PlaybackState) {
        queue.async { [weak self] in
            self?.updatePresenceInternal(state: state)
        }
    }
    
    private func updatePresenceInternal(state: PlaybackState) {
        guard isEnabled else { return }
        
        if !_isConnected {
            guard let socketPath = findDiscordIPCSocket(), connectToSocket(path: socketPath) else { return }
        }

        // When paused, stopped, or no track, immediately clear presence from Discord profile
        guard state.isPlaying, !state.title.isEmpty && state.title != "Not Playing" else {
            clearPresenceInternal()
            return
        }
        
        let pid = ProcessInfo.processInfo.processIdentifier
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        
        let titleStr = String(state.title.prefix(128))
        let artistStr = state.artist.isEmpty ? "Mooziac" : String("by \(state.artist) • Mooziac".prefix(128))
        
        var assetsDict: [String: Any] = [
            "small_image": "mooziac",
            "large_text": titleStr,
            "small_text": "Mooziac — Native YouTube Music for Mac"
        ]
        
        if !state.artworkUrl.isEmpty && (state.artworkUrl.hasPrefix("http://") || state.artworkUrl.hasPrefix("https://")) {
            assetsDict["large_image"] = state.artworkUrl
        } else {
            assetsDict["large_image"] = "mooziac"
        }
        
        var activity: [String: Any] = [
            "type": 2, // 2 = Listening to
            "details": titleStr,
            "state": artistStr,
            "assets": assetsDict
        ]
        
        let accurateTime = state.getAccurateTime()
        if state.duration > 0 &&
           !accurateTime.isNaN && !accurateTime.isInfinite &&
           !state.duration.isNaN && !state.duration.isInfinite {
            let validAccurate = max(0, accurateTime)
            let validDuration = max(0, state.duration)
            let remaining = max(0, validDuration - validAccurate)
            let startTimeMs = nowMs - Int64(validAccurate * 1000)
            let endTimeMs = nowMs + Int64(remaining * 1000)
            if startTimeMs > 0 && endTimeMs >= startTimeMs {
                activity["timestamps"] = [
                    "start": startTimeMs,
                    "end": endTimeMs
                ]
            }
        }
        
        var targetUrl = state.pageUrl
        if !state.videoId.isEmpty {
            targetUrl = "https://music.youtube.com/watch?v=\(state.videoId)"
        }
        
        if !targetUrl.isEmpty &&
            (targetUrl.hasPrefix("https://") || targetUrl.hasPrefix("http://")) &&
            targetUrl.contains("music.youtube.com") {
            let validUrl = String(targetUrl.prefix(512))
            activity["buttons"] = [
                ["label": "Listen on YouTube Music", "url": validUrl]
            ]
        }
        
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": pid,
                "activity": activity
            ],
            "nonce": UUID().uuidString
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            if !sendFrame(opcode: .frame, payload: jsonString) {
                closeSocketInternal()
            }
        }
    }
    
    public func clearPresence() {
        queue.async { [weak self] in
            self?.clearPresenceInternal()
        }
    }
    
    private func clearPresenceInternal() {
        guard _isConnected else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": pid,
                "activity": NSNull()
            ],
            "nonce": UUID().uuidString
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            if !sendFrame(opcode: .frame, payload: jsonString) {
                closeSocketInternal()
            }
        }
    }
}
