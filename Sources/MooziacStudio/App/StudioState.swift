import SwiftUI
import Combine
import AppKit

public enum StudioTab: String, CaseIterable, Identifiable {
    case overview = "Mission Control"
    case build = "Build & Package"
    case web = "Web & Deploy"
    case ship = "Ship Pipeline"
    case telemetry = "Telemetry & DB"
    case brain = "AI Brain & AST"
    case assets = "Asset Lab"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .overview: return "gauge.with.needle.fill"
        case .build: return "hammer.fill"
        case .web: return "globe"
        case .ship: return "paperplane.fill"
        case .telemetry: return "chart.xyaxis.line"
        case .brain: return "brain.head.profile"
        case .assets: return "paintpalette.fill"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .overview: return ColorTheme.accentTeal
        case .build: return ColorTheme.accentBlue
        case .web: return ColorTheme.accentGreen
        case .ship: return ColorTheme.accentOrange
        case .telemetry: return ColorTheme.accentBlue
        case .brain: return ColorTheme.accentPurple
        case .assets: return ColorTheme.accentRed
        }
    }
}

public final class StudioState: ObservableObject {
    public static let shared = StudioState()
    
    @Published public var selectedTab: StudioTab = .overview
    @Published public var logs: [ConsoleLogEntry] = []
    @Published public var isRunningTask: Bool = false
    @Published public var currentTaskName: String = ""
    
    // Telemetry & Runtime
    @Published public var playerTelemetry: PlayerTelemetryInfo = PlayerTelemetryInfo()
    @Published public var vpsTelemetry: VpsTelemetryInfo = VpsTelemetryInfo()
    @Published public var brainStats: BrainStats = BrainStats()
    @Published public var sqliteTables: [SQLiteTableStats] = []
    @Published public var selectedSqliteTable: String? = nil
    @Published public var sqliteSampleRows: [SQLiteRecordRow] = []
    
    // Brain Issues & Todo List Intelligence
    @Published public var brainIssues: [BrainIssueRecord] = []
    @Published public var todoItems: [StudioTodoItem] = []
    
    // Release configuration & Live Version Intelligence
    @Published public var versionInfo: StudioVersionInfo = StudioVersionInfo()
    @Published public var currentVersion: String = "1.0.4"
    @Published public var targetVersion: String = "1.0.5"
    @Published public var releaseNotesText: String = "• Native performance improvements\n• Enhanced edge trackpad volume curve\n• YouTube Music WebKit DOM sync stability"
    
    // Pipeline stage tracker
    @Published public var pipelineSteps: [PipelineStep] = [
        PipelineStep(title: "Pre-Flight & Git Check", status: .pending),
        PipelineStep(title: "Compile Universal 2 Release", status: .pending),
        PipelineStep(title: "Sign & Hardened Runtime", status: .pending),
        PipelineStep(title: "Assemble Styled DMG & ZIP", status: .pending),
        PipelineStep(title: "Sync & Deploy Web to VPS", status: .pending),
        PipelineStep(title: "Tag & Draft GitHub Release", status: .pending)
    ]
    
    private var telemetryCancellable: AnyCancellable?
    
    public var currentWorkingDirPath: String {
        return StudioProcessRunner.shared.workspacePath
    }
    
    // Watcher Engine Integration
    @Published public var isWatcherActive: Bool = false
    
    public init() {
        appendLog("🚀 Mooziac Studio Mission Control initialized. Workspace ready.", type: .info)
        refreshVersionInfo()
        refreshAllTelemetry()
        refreshBrainAndTodos()
        startTelemetryLoop()
        
        StudioWatcherEngine.shared.onChangesDetected = { [weak self] paths in
            guard let self = self else { return }
            let count = paths.count
            let shortNames = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.prefix(2).joined(separator: ", ")
            let summary = count > 2 ? "\(shortNames) +\(count - 2) files" : shortNames
            self.appendLog("👀 [Watcher] File changed: \(summary)", type: .info)
            self.refreshVersionInfo()
        }
    }
    
    public func refreshBrainAndTodos() {
        let ws = StudioProcessRunner.shared.workspacePath
        brainIssues = BrainBridge.shared.loadBrainIssues(workspacePath: ws)
        todoItems = BrainBridge.shared.loadTodoList(workspacePath: ws)
        brainStats = BrainBridge.shared.fetchBrainStats(workspacePath: ws)
    }
    
    public func addIssueToBrain(issue: GitHubIssueItem) {
        let ws = StudioProcessRunner.shared.workspacePath
        _ = BrainBridge.shared.saveIssueToBrain(issue: issue, workspacePath: ws)
        refreshBrainAndTodos()
        appendLog("🧠 [Brain] Issue #\(issue.number) '\(issue.title)' indexed into .mooziac-brain/issues/", .success)
    }
    
    public func addIssueToTodo(issue: GitHubIssueItem) {
        let ws = StudioProcessRunner.shared.workspacePath
        let item = BrainBridge.shared.addIssueToTodoList(issue: issue, workspacePath: ws)
        refreshBrainAndTodos()
        appendLog("✅ [TODO] Task '\(item.title)' added to Work List", .success)
    }
    
    public func toggleTodoItem(id: String) {
        let ws = StudioProcessRunner.shared.workspacePath
        if let idx = todoItems.firstIndex(where: { $0.id == id }) {
            todoItems[idx].isDone.toggle()
            BrainBridge.shared.saveTodoList(items: todoItems, workspacePath: ws)
            let status = todoItems[idx].isDone ? "completed" : "reopened"
            appendLog("📋 [TODO] Task \(status): \(todoItems[idx].title)", .info)
        }
    }
    
    public func addTodoItem(title: String, category: String = "General") {
        let ws = StudioProcessRunner.shared.workspacePath
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let newItem = StudioTodoItem(title: clean, category: category)
        todoItems.insert(newItem, at: 0)
        BrainBridge.shared.saveTodoList(items: todoItems, workspacePath: ws)
        appendLog("📋 [TODO] New task added: \(clean)", .success)
    }
    
    public func toggleWatcher() {
        let ws = StudioProcessRunner.shared.workspacePath
        StudioWatcherEngine.shared.toggle(rootPath: ws)
        isWatcherActive = StudioWatcherEngine.shared.isRunning
        if isWatcherActive {
            appendLog("👀 [Watcher] Live FSEvents workspace monitoring ACTIVE", type: .info)
        } else {
            appendLog("🛑 [Watcher] Live workspace monitoring STOPPED", type: .warning)
        }
    }
    
    public func appendLog(_ text: String, type: ConsoleLogEntry.LogType = .standard) {
        DispatchQueue.main.async {
            self.logs.append(ConsoleLogEntry(text: text, type: type))
            if self.logs.count > 1500 {
                self.logs.removeFirst(200)
            }
        }
    }
    
    public func appendLog(_ text: String, _ type: ConsoleLogEntry.LogType) {
        appendLog(text, type: type)
    }
    
    public func clearLogs() {
        logs.removeAll()
        appendLog("Activity log cleared.", type: .info)
    }
    
    public func executeTerminalCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if trimmed == "clear" || trimmed == "cls" {
            clearLogs()
            return
        }
        
        isRunningTask = true
        currentTaskName = trimmed
        
        StudioProcessRunner.shared.executeCommand(trimmed) { [weak self] output, type in
            self?.appendLog(output, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if !success && code != 0 {
                self.appendLog("Exited with code \(code)", .warning)
            }
        }
    }
    
    public func killActiveCommand() {
        StudioProcessRunner.shared.killRunningProcess()
        appendLog("⏹ Process halted by user.", .warning)
        isRunningTask = false
        currentTaskName = ""
    }
    
    public func refreshAllTelemetry() {
        let ws = StudioProcessRunner.shared.workspacePath
        self.brainStats = BrainBridge.shared.fetchBrainStats(workspacePath: ws)
        
        TelemetryMonitor.shared.fetchPlayerTelemetry { [weak self] info in
            self?.playerTelemetry = info
        }
        
        TelemetryMonitor.shared.pingVpsServer { [weak self] info in
            self?.vpsTelemetry = info
        }
        
        let tables = SQLiteInspector.shared.fetchTableStats()
        self.sqliteTables = tables
        
        if let selected = self.selectedSqliteTable, tables.contains(where: { $0.name == selected }) {
            self.sqliteSampleRows = SQLiteInspector.shared.fetchSampleRows(from: selected)
        } else if let first = tables.first {
            self.selectedSqliteTable = first.name
            self.sqliteSampleRows = SQLiteInspector.shared.fetchSampleRows(from: first.name)
        } else {
            self.selectedSqliteTable = nil
            self.sqliteSampleRows = []
        }
    }
    
    public func refreshVersionInfo() {
        let ws = StudioProcessRunner.shared.workspacePath
        StudioVersionManager.shared.fetchAllVersionInfo(workspacePath: ws) { [weak self] info in
            guard let self = self else { return }
            self.versionInfo = info
            self.currentVersion = info.projectVersion
            self.targetVersion = info.computedNextVersion
        }
    }
    
    // MARK: - Direct Action Commands
    public func triggerBuildApp(universal: Bool) {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = universal ? "cd \"\(ws)\" && ./build_app.sh --no-launch" : "cd \"\(ws)\" && ./build_app.sh"
        isRunningTask = true
        currentTaskName = universal ? "Building Universal 2 DMG..." : "Fast Dev Build & Run..."
        
        appendLog("==========================================", .info)
        appendLog("  🔨 Triggering Mooziac Build Pipeline     ", .info)
        appendLog("==========================================", .info)
        
        StudioProcessRunner.shared.executeCommand(cmd) { [weak self] output, type in
            self?.appendLog(output, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("✅ Build completed successfully!", .success)
                self.refreshVersionInfo()
            } else {
                self.appendLog("❌ Build process exited with code \(code).", .error)
            }
        }
    }
    
    public func triggerDeployWebsite() {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)/www\" && ./push.sh"
        isRunningTask = true
        currentTaskName = "Deploying Website to VPS..."
        
        appendLog("==========================================", .info)
        appendLog("  🌐 Triggering Website Deployment (push.sh)", .info)
        appendLog("==========================================", .info)
        
        StudioProcessRunner.shared.executeCommand(cmd) { [weak self] output, type in
            self?.appendLog(output, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("✅ Website deployment sync finished!", .success)
                self.pingWebsite()
            } else {
                self.appendLog("❌ Web deploy exited with code \(code).", .error)
            }
        }
    }
    
    public func triggerAutoBumpPushAndRelease() {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        
        let (newVer, newBuild, newTag) = StudioVersionManager.shared.bumpAndApplyVersion(workspacePath: ws)
        
        isRunningTask = true
        currentTaskName = "Bumping to \(newTag) & Pushing Release..."
        
        appendLog("==========================================", .info)
        appendLog("  🚀 BUMPING VERSION & SHIPPING RELEASE   ", .info)
        appendLog("  • New Version:  v\(newVer) (Build \(newBuild))", .info)
        appendLog("  • Release Tag:  \(newTag)", .info)
        appendLog("==========================================", .info)
        
        let cmd = "cd \"\(ws)\" && (git add -A && git commit -m \"Release \(newTag) (Build \(newBuild))\" || true) && git push origin HEAD && (git tag -d \(newTag) 2>/dev/null || true) && git tag -a \(newTag) -m \"Mooziac \(newVer) Release\" && git push origin \(newTag) && git status -s"
        
        StudioProcessRunner.shared.executeCommand(cmd) { [weak self] output, type in
            self?.appendLog(output, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("✅ Released & Pushed \(newTag) to GitHub! CI/CD Runner triggered.", .success)
            } else {
                self.appendLog("❌ Release push failed with exit code \(code). Check Git output above.", .error)
            }
            self.refreshVersionInfo()
        }
    }
    
    public func triggerGitHubRelease(tag: String, title: String) {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTag.isEmpty else { return }
        
        let cmd = "cd \"\(ws)\" && git push origin HEAD && (git tag -d \(cleanTag) 2>/dev/null || true) && git tag -a \(cleanTag) -m \"\(cleanTitle)\" && git push origin \(cleanTag) && git status -s"
        isRunningTask = true
        currentTaskName = "Syncing Code & Pushing \(cleanTag)..."
        
        appendLog("==========================================", .info)
        appendLog("  🐙 Syncing Source Code & Tagging: \(cleanTag)", .info)
        appendLog("==========================================", .info)
        
        StudioProcessRunner.shared.executeCommand(cmd) { [weak self] output, type in
            self?.appendLog(output, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("🏷️ Git release tag \(cleanTag) created and pushed to GitHub!", .success)
            } else {
                self.appendLog("❌ Git tag/push failed with code \(code). Check output above.", .error)
            }
            self.refreshVersionInfo()
        }
    }
    
    public func launchPlayerApp() {
        let appPath = "\(NSHomeDirectory())/Applications/Mooziac.app"
        if FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            appendLog("🚀 Launched Mooziac.app from \(appPath)", .success)
            refreshAllTelemetry()
        } else {
            appendLog("🔨 Mooziac.app not installed yet. Running Fast Dev Build...", .info)
            triggerBuildApp(universal: false)
        }
    }
    
    public func killPlayerProcess() {
        StudioProcessRunner.shared.executeCommand("killall Mooziac 2>/dev/null || true") { [weak self] text, type in
            self?.appendLog(text, type: type)
        } onComplete: { [weak self] _, _ in
            self?.appendLog("🛑 Mooziac player processes terminated.", .warning)
            self?.refreshAllTelemetry()
        }
    }
    
    public func syncBrain() {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        isRunningTask = true
        currentTaskName = "Syncing AI Brain Index..."
        appendLog("🧠 Triggering AI Brain Index Synchronization...", .info)
        
        StudioProcessRunner.shared.executeCommand("cd \"\(ws)\" && ./brain sync") { [weak self] text, type in
            self?.appendLog(text, type: type)
        } onComplete: { [weak self] success, _ in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("✅ AI Brain Index synchronized successfully!", .success)
                self.refreshAllTelemetry()
            }
        }
    }
    
    public func cleanBuildCache() {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        isRunningTask = true
        currentTaskName = "Cleaning Build Cache (.build)..."
        appendLog("🧹 Purging Swift Package build cache...", .info)
        
        StudioProcessRunner.shared.executeCommand("cd \"\(ws)\" && swift package clean && rm -rf .build") { [weak self] text, type in
            self?.appendLog(text, type: type)
        } onComplete: { [weak self] success, _ in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            self.appendLog("✨ Build cache cleaned.", .success)
        }
    }
    
    public func regenerateDmgArtwork() {
        guard !isRunningTask else { return }
        let ws = StudioProcessRunner.shared.workspacePath
        isRunningTask = true
        currentTaskName = "Rendering DMG Background Artwork..."
        
        StudioProcessRunner.shared.executeCommand("cd \"\(ws)\" && swift scripts/generate_dmg_background.swift") { [weak self] text, type in
            self?.appendLog(text, type: type)
        } onComplete: { [weak self] success, _ in
            guard let self = self else { return }
            self.isRunningTask = false
            self.currentTaskName = ""
            if success {
                self.appendLog("🎨 DMG Background artwork updated at Resources/dmg_background.png", .success)
            }
        }
    }
    
    public func revealProjectInFinder() {
        let ws = StudioProcessRunner.shared.workspacePath
        NSWorkspace.shared.open(URL(fileURLWithPath: ws))
    }
    
    public func revealDistInFinder() {
        let ws = StudioProcessRunner.shared.workspacePath
        let distURL = URL(fileURLWithPath: "\(ws)/dist")
        NSWorkspace.shared.open(distURL)
    }
    
    public func openWebsiteInBrowser() {
        if let url = URL(string: "https://mooziac.threeten.site") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func pingWebsite() {
        TelemetryMonitor.shared.pingVpsServer { [weak self] info in
            self?.vpsTelemetry = info
        }
    }
    
    private func startTelemetryLoop() {
        telemetryCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isRunningTask else { return }
                self.refreshAllTelemetry()
            }
    }
    
    public func loadTableRows(_ tableName: String) {
        self.selectedSqliteTable = tableName
        self.sqliteSampleRows = SQLiteInspector.shared.fetchSampleRows(from: tableName)
    }
}

public struct PipelineStep: Identifiable {
    public let id = UUID()
    public let title: String
    public var status: StepStatus
    
    public enum StepStatus {
        case pending
        case running
        case completed
        case failed
    }
}
