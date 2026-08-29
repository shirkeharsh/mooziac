import Foundation
import Combine
import SwiftUI

public struct ActivityLogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let type: ChangeBadgeType
    public let blastRadiusCount: Int
    
    public enum ChangeBadgeType: String {
        case modified = "MODIFIED"
        case added = "ADDED"
        case deleted = "DELETED"
        case renamed = "RENAMED"
        case synced = "SYNCED"
        case system = "SYSTEM"
        
        public var color: Color {
            switch self {
            case .modified: return .orange
            case .added: return .green
            case .deleted: return .red
            case .renamed: return .purple
            case .synced: return .blue
            case .system: return .cyan
            }
        }
    }
}

@MainActor
public final class BrainState: ObservableObject {
    public static let shared = BrainState()
    
    @Published public var isWatching: Bool = true {
        didSet {
            if isWatching {
                FileWatcherEngine.shared.start(rootPath: BrainProcessRunner.shared.workspacePath)
                logSystemEvent("Auto-Sync Watching Resumed")
            } else {
                FileWatcherEngine.shared.stop()
                logSystemEvent("Auto-Sync Watching Paused")
            }
        }
    }
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = Date()
    @Published public var statusMessage: String = "All changes synchronized"
    
    // Metrics
    @Published public var totalFiles: Int = 0
    @Published public var appFiles: Int = 0
    @Published public var githubFiles: Int = 0
    @Published public var websiteFiles: Int = 0
    @Published public var totalSymbols: Int = 0
    @Published public var totalConcepts: Int = 12
    
    // Live Activity Stream
    @Published public var recentActivity: [ActivityLogEntry] = []
    
    // Search
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [BrainSearchResultItem] = []
    @Published public var isSearching: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var searchDebounce: AnyCancellable?
    
    private init() {
        setupWatcherCallbacks()
        loadLocalMetrics()
        
        // Initial system event
        logSystemEvent("Mooziac Brain Live Watcher Started")
        
        // Start watching automatically
        FileWatcherEngine.shared.start(rootPath: BrainProcessRunner.shared.workspacePath)
    }
    
    private func setupWatcherCallbacks() {
        FileWatcherEngine.shared.onChangesDetected = { [weak self] changedPaths in
            guard let self = self, self.isWatching else { return }
            self.triggerIncrementalSync(triggeredPaths: changedPaths)
        }
    }
    
    public func triggerIncrementalSync(triggeredPaths: [String] = []) {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Syncing code changes with Brain..."
        
        let pathPreviews = triggeredPaths.prefix(3).map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        if !triggeredPaths.isEmpty {
            logActivity(
                title: "Files Changed (\(triggeredPaths.count))",
                detail: pathPreviews + (triggeredPaths.count > 3 ? " (+\(triggeredPaths.count - 3) more)" : ""),
                type: .system,
                blastRadiusCount: 0
            )
        }
        
        BrainProcessRunner.shared.runScan { [weak self] result in
            guard let self = self else { return }
            self.isSyncing = false
            self.lastSyncDate = Date()
            
            switch result {
            case .success(let scanResult):
                if scanResult.isFresh {
                    self.statusMessage = "Brain up to date (0 drift)"
                } else {
                    self.statusMessage = "Updated \(scanResult.changesCount) files in Brain"
                    for change in scanResult.changes {
                        let type: ActivityLogEntry.ChangeBadgeType
                        if change.contains("[MODIFIED]") { type = .modified }
                        else if change.contains("[ADDED]") { type = .added }
                        else if change.contains("[DELETED]") { type = .deleted }
                        else if change.contains("[RENAMED]") { type = .renamed }
                        else { type = .synced }
                        
                        self.logActivity(
                            title: change,
                            detail: "Propagated to Symbol Index, Graph & SQLite FTS5",
                            type: type,
                            blastRadiusCount: 1
                        )
                    }
                }
                self.loadLocalMetrics()
                
            case .failure(let error):
                self.statusMessage = "Sync Error: \(error.localizedDescription)"
                self.logActivity(
                    title: "Sync Error",
                    detail: error.localizedDescription,
                    type: .deleted,
                    blastRadiusCount: 0
                )
            }
        }
    }
    
    public func triggerDeepRebuild() {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Performing full deep scan & rebuild..."
        
        BrainProcessRunner.shared.runInit { [weak self] result in
            guard let self = self else { return }
            self.isSyncing = false
            self.lastSyncDate = Date()
            
            switch result {
            case .success:
                self.statusMessage = "Brain completely rebuilt & fresh"
                self.logActivity(
                    title: "Deep Rebuild Complete",
                    detail: "All 3 sources, 5,800+ symbols and concepts refreshed",
                    type: .synced,
                    blastRadiusCount: 0
                )
                self.loadLocalMetrics()
            case .failure(let err):
                self.statusMessage = "Rebuild Failed: \(err.localizedDescription)"
            }
        }
    }
    
    public func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        BrainProcessRunner.shared.runSearch(query: trimmed) { [weak self] result in
            guard let self = self else { return }
            self.isSearching = false
            if case .success(let items) = result {
                self.searchResults = items
            }
        }
    }
    
    public func loadLocalMetrics() {
        let root = BrainProcessRunner.shared.workspacePath
        let filesJsonPath = URL(fileURLWithPath: root).appendingPathComponent(".mooziac-brain/index/files.json")
        let symbolsJsonPath = URL(fileURLWithPath: root).appendingPathComponent(".mooziac-brain/index/symbols.json")
        let conceptsJsonPath = URL(fileURLWithPath: root).appendingPathComponent(".mooziac-brain/index/concepts.json")
        
        if let data = try? Data(contentsOf: filesJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            self.totalFiles = json.count
            self.appFiles = json.values.filter { ($0["source_category"] as? String) == "app" }.count
            self.githubFiles = json.values.filter { ($0["source_category"] as? String) == "github" }.count
            self.websiteFiles = json.values.filter { ($0["source_category"] as? String) == "website" }.count
        }
        
        if let data = try? Data(contentsOf: symbolsJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.totalSymbols = json.count
        }
        
        if let data = try? Data(contentsOf: conceptsJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.totalConcepts = json.count
        }
    }
    
    private func logActivity(title: String, detail: String, type: ActivityLogEntry.ChangeBadgeType, blastRadiusCount: Int) {
        let entry = ActivityLogEntry(
            timestamp: Date(),
            title: title,
            detail: detail,
            type: type,
            blastRadiusCount: blastRadiusCount
        )
        recentActivity.insert(entry, at: 0)
        if recentActivity.count > 50 {
            recentActivity.removeLast()
        }
    }
    
    private func logSystemEvent(_ title: String) {
        logActivity(title: title, detail: "Workspace: \(BrainProcessRunner.shared.workspacePath)", type: .system, blastRadiusCount: 0)
    }
}
