import Foundation

public final class StudioProcessRunner {
    public static let shared = StudioProcessRunner()
    
    private var currentProcess: Process?
    private var standardInputPipe: Pipe?
    private let queue = DispatchQueue(label: "app.mooziac.studio.process", qos: .userInitiated)
    
    public var workspacePath: String {
        let current = FileManager.default.currentDirectoryPath
        if FileManager.default.fileExists(atPath: "\(current)/Package.swift") {
            return current
        }
        let fallback = "/Users/harshshirke/local/projects/Mooziac/mp3kal"
        if FileManager.default.fileExists(atPath: fallback) {
            return fallback
        }
        let rootFallback = "/Users/harshshirke/local/projects/Mooziac"
        if FileManager.default.fileExists(atPath: rootFallback) {
            return rootFallback
        }
        return current
    }
    
    public var isRunning: Bool {
        return currentProcess?.isRunning ?? false
    }
    
    public var currentPID: Int32? {
        if let proc = currentProcess, proc.isRunning {
            return proc.processIdentifier
        }
        return nil
    }
    
    public init() {}
    
    public func executeCommand(
        _ command: String,
        workingDir: String? = nil,
        onOutput: @escaping (String, ConsoleLogEntry.LogType) -> Void,
        onComplete: @escaping (Bool, Int32) -> Void
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.killRunningProcess()
            
            let process = Process()
            self.currentProcess = process
            
            let inPipe = Pipe()
            self.standardInputPipe = inPipe
            process.standardInput = inPipe
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            
            let targetDir = workingDir ?? self.workspacePath
            process.currentDirectoryURL = URL(fileURLWithPath: targetDir)
            
            // Set up environment with common PATHs (Xcode, Homebrew, local bin, cargo, nvm, etc.)
            var env = ProcessInfo.processInfo.environment
            let customPath = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:\(NSHomeDirectory())/.cargo/bin:\(NSHomeDirectory())/.nvm/versions/node/current/bin"
            env["PATH"] = customPath + ":" + (env["PATH"] ?? "")
            env["TERM"] = "xterm-256color"
            process.environment = env
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            let outHandle = outputPipe.fileHandleForReading
            
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                
                let lines = text.components(separatedBy: .newlines)
                for line in lines where !line.isEmpty {
                    let parsed = ANSIParser.parse(line)
                    DispatchQueue.main.async {
                        onOutput(parsed.cleanText, parsed.type)
                    }
                }
            }
            
            DispatchQueue.main.async {
                onOutput("❯ [Mooziac] $ \(command)", .command)
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                outHandle.readabilityHandler = nil
                
                let status = process.terminationStatus
                let success = (status == 0)
                
                DispatchQueue.main.async {
                    if success {
                        onOutput("✔ Finished [exit code \(status)]", .success)
                    } else {
                        onOutput("✖ Exited with code \(status)", .error)
                    }
                    self.currentProcess = nil
                    self.standardInputPipe = nil
                    onComplete(success, status)
                }
            } catch {
                outHandle.readabilityHandler = nil
                DispatchQueue.main.async {
                    onOutput("❌ Execution error: \(error.localizedDescription)", .error)
                    self.currentProcess = nil
                    self.standardInputPipe = nil
                    onComplete(false, -1)
                }
            }
        }
    }
    
    public func sendInput(_ text: String) {
        guard let inPipe = standardInputPipe, let data = (text + "\n").data(using: .utf8) else { return }
        try? inPipe.fileHandleForWriting.write(contentsOf: data)
    }
    
    public func killRunningProcess() {
        if let proc = currentProcess, proc.isRunning {
            proc.interrupt()
            // If still running after small tick, force terminate
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                if proc.isRunning {
                    proc.terminate()
                }
            }
            currentProcess = nil
            standardInputPipe = nil
        }
    }
}
