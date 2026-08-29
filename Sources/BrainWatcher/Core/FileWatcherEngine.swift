import Foundation
import CoreServices

/// Low-latency, native macOS FSEvents file watcher for the Mooziac workspace.
public final class FileWatcherEngine {
    public static let shared = FileWatcherEngine()
    
    private var streamRef: FSEventStreamRef?
    private var isRunning = false
    private let queue = DispatchQueue(label: "app.mooziac.brainwatcher.queue", qos: .utility)
    private var debounceTimer: DispatchWorkItem?
    private var pendingChangedPaths: Set<String> = []
    
    public var onChangesDetected: (([String]) -> Void)?
    
    /// Ignored paths and directories that should not trigger brain updates
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
        ".tmp"
    ]
    
    private init() {}
    
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
            let watcher = Unmanaged<FileWatcherEngine>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
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
            print("⚠️ [FileWatcherEngine] Failed to create FSEventStream for \(rootPath)")
            return
        }
        
        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        isRunning = true
        print("👀 [FileWatcherEngine] Native FSEvents watching: \(rootPath)")
    }
    
    public func stop() {
        guard isRunning, let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.streamRef = nil
        self.isRunning = false
        print("🛑 [FileWatcherEngine] Stopped watching.")
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
        
        // Debounce multi-file writes (from IDEs, Agy, OpenCode, Git operations)
        debounceTimer?.cancel()
        for p in validPaths {
            pendingChangedPaths.insert(p)
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let paths = Array(self.pendingChangedPaths)
            self.pendingChangedPaths.removeAll()
            DispatchQueue.main.async {
                self.onChangesDetected?(paths)
            }
        }
        
        debounceTimer = workItem
        queue.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }
}
