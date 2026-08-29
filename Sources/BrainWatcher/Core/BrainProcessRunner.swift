import Foundation

public struct ScanResult {
    public let rawOutput: String
    public let changesCount: Int
    public let changes: [String]
    public let isFresh: Bool
}

public struct BrainSearchResultItem: Codable, Identifiable {
    public var id: String { "\(file_path ?? "")-\(title)-\(line_start ?? 0)" }
    public let title: String
    public let category: String
    public let doc_type: String
    public let file_path: String?
    public let line_start: Int?
    public let line_end: Int?
    public let content: String
    public let score: Double
}

/// Runs Mooziac Brain Python CLI operations asynchronously with real-time streaming output.
public final class BrainProcessRunner {
    public static let shared = BrainProcessRunner()
    
    public let workspacePath: String
    private let processQueue = DispatchQueue(label: "app.mooziac.brainrunner.queue", qos: .userInitiated)
    private var isBusy = false
    
    public init(workspacePath: String? = nil) {
        if let workspacePath = workspacePath {
            self.workspacePath = workspacePath
        } else if let envRoot = ProcessInfo.processInfo.environment["MOOZIAC_ROOT"] {
            self.workspacePath = envRoot
        } else {
            // Default to working directory or locate by marker
            let cwd = FileManager.default.currentDirectoryPath
            if FileManager.default.fileExists(atPath: URL(fileURLWithPath: cwd).appendingPathComponent("mooziac_brain").path) {
                self.workspacePath = cwd
            } else {
                self.workspacePath = "/Users/harshshirke/local/projects/mp3kal"
            }
        }
    }
    
    public func runScan(completion: @escaping (Result<ScanResult, Error>) -> Void) {
        guard !isBusy else {
            completion(.failure(NSError(domain: "BrainProcessRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scan already running"])))
            return
        }
        
        isBusy = true
        runCommand(arguments: ["scan"]) { [weak self] result in
            self?.isBusy = false
            switch result {
            case .success(let output):
                let scanResult = self?.parseScanOutput(output) ?? ScanResult(rawOutput: output, changesCount: 0, changes: [], isFresh: true)
                completion(.success(scanResult))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func runInit(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isBusy else {
            completion(.failure(NSError(domain: "BrainProcessRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Process already running"])))
            return
        }
        
        isBusy = true
        runCommand(arguments: ["init"]) { [weak self] result in
            self?.isBusy = false
            completion(result)
        }
    }
    
    public func runSearch(query: String, completion: @escaping (Result<[BrainSearchResultItem], Error>) -> Void) {
        runCommand(arguments: ["search", query, "--json"]) { result in
            switch result {
            case .success(let jsonString):
                // Extract JSON array if any extra print statements exist
                if let startIdx = jsonString.firstIndex(of: "["),
                   let endIdx = jsonString.lastIndex(of: "]") {
                    let cleanedJSON = String(jsonString[startIdx...endIdx])
                    if let data = cleanedJSON.data(using: .utf8),
                       let items = try? JSONDecoder().decode([BrainSearchResultItem].self, from: data) {
                        completion(.success(items))
                        return
                    }
                }
                completion(.success([]))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    private func runCommand(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        processQueue.async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            let brainScript = URL(fileURLWithPath: self.workspacePath).appendingPathComponent("brain").path
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            
            if FileManager.default.fileExists(atPath: brainScript) {
                process.arguments = [brainScript] + arguments
            } else {
                process.arguments = ["-m", "mooziac_brain.cli"] + arguments
            }
            
            process.currentDirectoryURL = URL(fileURLWithPath: self.workspacePath)
            
            var env = ProcessInfo.processInfo.environment
            env["MOOZIAC_ROOT"] = self.workspacePath
            env["PYTHONUNBUFFERED"] = "1"
            process.environment = env
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    completion(.success(output))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func parseScanOutput(_ output: String) -> ScanResult {
        var changesCount = 0
        var changesList: [String] = []
        let isFresh = output.contains("No changes detected")
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Detected") && trimmed.contains("changed files:") {
                let parts = trimmed.components(separatedBy: " ")
                if let countIdx = parts.firstIndex(of: "Detected"), countIdx + 1 < parts.count,
                   let count = Int(parts[countIdx + 1]) {
                    changesCount = count
                }
            } else if trimmed.hasPrefix("- [") {
                changesList.append(trimmed.replacingOccurrences(of: "- ", with: ""))
            }
        }
        
        return ScanResult(
            rawOutput: output,
            changesCount: changesCount > 0 ? changesCount : changesList.count,
            changes: changesList,
            isFresh: isFresh
        )
    }
}
