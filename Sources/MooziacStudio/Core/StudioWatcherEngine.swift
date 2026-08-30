import Foundation
import CoreServices
import AppKit

public final class StudioWatcherEngine: ObservableObject {
    public static let shared = StudioWatcherEngine()
    
    private var streamRef: FSEventStreamRef?
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var lastEventSummary: String = "Idle"
    @Published public private(set) var totalEventsDetected: Int = 0
    @Published public private(set) var lastEventTimestamp: Date? = nil
    
    private let queue = DispatchQueue(label: "app.mooziac.studio.watcher.queue", qos: .utility)
    private var debounceTimer: DispatchWorkItem?
    private var pendingChangedPaths: Set<String> = []
    
    public var onChangesDetected: (([String]) -> Void)?
    
    private let ignoredPatterns: [String] = [
        "/.mooziac-brain",
        "/.git",
        "/.build",
        "/__pycache__",
        "/node_modules",
        "/.DS_Store",
        "/.swiftpm",
        "/dist",
        "/temp.dmg",
        ".swp",
        ".tmp",
        ".log"
    ]
    
    private init() {}
    
    public func toggle(rootPath: String) {
        if isRunning {
            stop()
        } else {
            start(rootPath: rootPath)
        }
    }
    
    public func start(rootPath: String) {
        guard !isRunning else { return }
        
        let pathsToWatch = [rootPath] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let watcher = Unmanaged<StudioWatcherEngine>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            watcher.handleEvents(paths: paths)
        }
        
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )
        
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            print("⚠️ [StudioWatcherEngine] Failed to create FSEventStream for \(rootPath)")
            return
        }
        
        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.lastEventSummary = "Watching workspace live"
        }
        print("👀 [StudioWatcherEngine] Native FSEvents watching: \(rootPath)")
    }
    
    public func stop() {
        guard isRunning, let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.streamRef = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.lastEventSummary = "Watcher stopped"
        }
        print("🛑 [StudioWatcherEngine] Stopped watching.")
    }
    
    private func handleEvents(paths: [String]) {
        let validPaths = paths.filter { path in
            for ignored in ignoredPatterns {
                if path.contains(ignored) {
                    return false
                }
            }
            return true
        }
        
        guard !validPaths.isEmpty else { return }
        
        debounceTimer?.cancel()
        for p in validPaths {
            pendingChangedPaths.insert(p)
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let paths = Array(self.pendingChangedPaths)
            self.pendingChangedPaths.removeAll()
            
            let count = paths.count
            let shortNames = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.prefix(2).joined(separator: ", ")
            let summary = count > 2 ? "\(shortNames) +\(count - 2) files" : shortNames
            
            DispatchQueue.main.async {
                self.totalEventsDetected += 1
                self.lastEventTimestamp = Date()
                self.lastEventSummary = "Modified: \(summary)"
                self.onChangesDetected?(paths)
            }
        }
        
        debounceTimer = workItem
        queue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
