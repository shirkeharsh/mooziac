import Foundation
import Darwin

public final class NativePTYSession: ObservableObject {
    public static let shared = NativePTYSession()
    
    private var masterFd: Int32 = -1
    private var childPID: pid_t = -1
    private var readThread: Thread?
    private var isReading: Bool = false
    
    @Published public var isRunning: Bool = false
    @Published public var currentPID: Int32? = nil
    @Published public var activeDirectory: String = ""
    
    public var onDataReceived: ((Data) -> Void)?
    public var onSessionTerminated: ((Int32) -> Void)?
    
    private let writeQueue = DispatchQueue(label: "app.mooziac.studio.pty.write", qos: .userInteractive)
    
    public init() {}
    
    public func startSession(workingDir: String? = nil, initialCols: Int32 = 90, initialRows: Int32 = 28) {
        terminate()
        
        let targetDir = workingDir ?? StudioProcessRunner.shared.workspacePath
        self.activeDirectory = targetDir
        
        var win = winsize(
            ws_row: UInt16(max(10, initialRows)),
            ws_col: UInt16(max(20, initialCols)),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        
        var master: Int32 = -1
        var slave: Int32 = -1
        
        let ptyRes = openpty(&master, &slave, nil, nil, &win)
        guard ptyRes == 0 else {
            print("❌ Failed to openpty: \(ptyRes)")
            return
        }
        
        self.masterFd = master
        
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, master)
        posix_spawn_file_actions_addclose(&fileActions, slave)
        
        if FileManager.default.fileExists(atPath: targetDir) {
            posix_spawn_file_actions_addchdir_np(&fileActions, targetDir)
        }
        
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        let flags: Int16 = Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)
        posix_spawnattr_setflags(&attr, flags)
        
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let isZsh = shellPath.hasSuffix("zsh")
        
        var argv: [UnsafeMutablePointer<CChar>?] = []
        if isZsh {
            argv = [
                strdup(shellPath),
                strdup("-l"),
                strdup("-o"),
                strdup("NO_PROMPT_SP"),
                nil
            ]
        } else {
            argv = [
                strdup(shellPath),
                strdup("-l"),
                nil
            ]
        }
        
        var envDict = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(NSHomeDirectory())/.cargo/bin:\(NSHomeDirectory())/.nvm/versions/node/current/bin"
        envDict["PATH"] = extraPaths + ":" + (envDict["PATH"] ?? "")
        envDict["TERM"] = "xterm-256color"
        envDict["COLORTERM"] = "truecolor"
        envDict["LANG"] = "en_US.UTF-8"
        envDict["LC_ALL"] = "en_US.UTF-8"
        envDict["USER"] = NSUserName()
        envDict["HOME"] = NSHomeDirectory()
        envDict["PWD"] = targetDir
        envDict["PROMPT_EOL_MARK"] = ""
        envDict["ZSH_SILENCE_COMMAND_NOT_FOUND"] = "1"
        
        let envp: [UnsafeMutablePointer<CChar>?] = envDict.map { key, value in
            strdup("\(key)=\(value)")
        } + [nil]
        
        var pid: pid_t = 0
        let spawnRes = posix_spawn(&pid, shellPath, &fileActions, &attr, argv, envp)
        
        posix_spawn_file_actions_destroy(&fileActions)
        posix_spawnattr_destroy(&attr)
        close(slave)
        
        // Clean up heap allocated C strings
        for ptr in argv where ptr != nil { free(ptr) }
        for ptr in envp where ptr != nil { free(ptr) }
        
        guard spawnRes == 0 else {
            print("❌ posix_spawn failed with code: \(spawnRes)")
            close(master)
            self.masterFd = -1
            return
        }
        
        self.childPID = pid
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.currentPID = pid
        }
        
        startReadingMaster()
    }
    
    private func startReadingMaster() {
        guard masterFd >= 0 else { return }
        isReading = true
        let fd = masterFd
        
        let thread = Thread { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            
            while let self = self, self.isReading && fd >= 0 {
                let bytesRead = read(fd, &buffer, buffer.count)
                if bytesRead > 0 {
                    let chunk = Data(buffer.prefix(bytesRead))
                    self.onDataReceived?(chunk)
                } else {
                    // EOF or Error
                    break
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isRunning = false
                self.currentPID = nil
                self.onSessionTerminated?(0)
            }
        }
        
        self.readThread = thread
        thread.name = "app.mooziac.studio.pty.read"
        thread.qualityOfService = .userInteractive
        thread.start()
    }
    
    public func write(data: Data) {
        guard masterFd >= 0, isRunning else { return }
        let fd = masterFd
        writeQueue.async {
            data.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                _ = Darwin.write(fd, base, data.count)
            }
        }
    }
    
    public func write(string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data: data)
    }
    
    public func sendCommand(_ command: String) {
        write(string: "\(command)\n")
    }
    
    public func sendCtrlC() {
        write(string: "\u{0003}")
    }
    
    public func sendCtrlZ() {
        write(string: "\u{001A}")
    }
    
    public func resize(cols: Int32, rows: Int32) {
        guard masterFd >= 0 else { return }
        var win = winsize(
            ws_row: UInt16(max(5, rows)),
            ws_col: UInt16(max(10, cols)),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFd, TIOCSWINSZ, &win)
    }
    
    public func sendSignal(_ sig: Int32) {
        if childPID > 0 {
            kill(childPID, sig)
        }
    }
    
    public func terminate() {
        isReading = false
        if childPID > 0 {
            kill(childPID, SIGTERM)
            // Wait briefly or force kill
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [pid = childPID] in
                if pid > 0 {
                    kill(pid, SIGKILL)
                }
            }
            childPID = -1
        }
        if masterFd >= 0 {
            close(masterFd)
            masterFd = -1
        }
        readThread = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentPID = nil
        }
    }
    
    public func restart(workingDir: String? = nil) {
        let dir = workingDir ?? activeDirectory
        startSession(workingDir: dir)
    }
    
    deinit {
        terminate()
    }
}
