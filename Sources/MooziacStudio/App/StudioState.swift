import SwiftUI
import Combine

public enum StudioTab: String, CaseIterable, Identifiable {
    case terminal = "Active Terminal"
    case pipeline = "One-Click Ship"
    case build = "Build & Package"
    case web = "Web & VPS Deploy"
    case github = "GitHub Releases"
    case telemetry = "Telemetry & DB"
    case brain = "AI Brain & AST"
    case assets = "Visual Asset Lab"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .terminal: return "terminal.fill"
        case .pipeline: return "paperplane.fill"
        case .build: return "hammer.fill"
        case .web: return "globe"
        case .github: return "shippingbox.fill"
        case .telemetry: return "chart.xyaxis.line"
        case .brain: return "brain.head.profile"
        case .assets: return "paintpalette.fill"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .terminal: return ColorTheme.accentTeal
        case .pipeline: return ColorTheme.accentOrange
        case .build: return ColorTheme.accentBlue
        case .web: return ColorTheme.accentGreen
        case .github: return ColorTheme.accentPurple
        case .telemetry: return ColorTheme.accentBlue
        case .brain: return ColorTheme.accentOrange
        case .assets: return ColorTheme.accentRed
        }
    }
}

public final class StudioState: ObservableObject {
    public static let shared = StudioState()
    
    @Published public var selectedTab: StudioTab = .terminal
    @Published public var logs: [ConsoleLogEntry] = []
    @Published public var isRunningTask: Bool = false
    @Published public var currentTaskName: String = ""
    
    // Active Terminal State
    @Published public var customDirectoryPath: String = ""
    @Published public var commandHistory: [String] = []
    @Published public var historyIndex: Int = -1
    @Published public var terminalFilterText: String = ""
    @Published public var terminalRunningCommand: String = ""
    @Published public var terminalPID: Int32? = nil
    @Published public var terminalStartTime: Date? = nil
    @Published public var terminalDurationSeconds: Double = 0.0
    
    // Telemetry
    @Published public var playerTelemetry: PlayerTelemetryInfo = PlayerTelemetryInfo()
    @Published public var vpsTelemetry: VpsTelemetryInfo = VpsTelemetryInfo()
    @Published public var brainStats: BrainStats = BrainStats()
    @Published public var sqliteTables: [SQLiteTableStats] = []
    @Published public var selectedSqliteTable: String? = nil
    @Published public var sqliteSampleRows: [SQLiteRecordRow] = []
    
    // Release configuration
    @Published public var currentVersion: String = "1.0.1"
    @Published public var targetVersion: String = "1.0.2"
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
    private var timerCancellable: AnyCancellable?
    
    public var currentWorkingDirPath: String {
        return StudioProcessRunner.shared.workspacePath
    }
    
    public init() {
        appendLog("🚀 Mooziac Studio initialized. Workspace ready.", type: .info)
        appendLog("💻 Active Terminal ready in Mooziac", type: .standard)
        refreshAllTelemetry()
        startTelemetryLoop()
        startExecutionTimer()
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
        appendLog("Console logs cleared.", type: .info)
    }
    
    public func executeTerminalCommand(_ rawCmd: String) {
        let trimmed = rawCmd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Handle built-in fast commands
        if trimmed == "clear" || trimmed == "cls" {
            clearLogs()
            return
        }
        
        // Push to history
        if commandHistory.last != trimmed {
            commandHistory.append(trimmed)
            if commandHistory.count > 100 {
                commandHistory.removeFirst()
            }
        }
        historyIndex = commandHistory.count
        
        isRunningTask = true
        terminalRunningCommand = trimmed
        currentTaskName = trimmed
        terminalStartTime = Date()
        terminalDurationSeconds = 0.0
        
        let targetDir = currentWorkingDirPath
        
        StudioProcessRunner.shared.executeCommand(trimmed, workingDir: targetDir) { [weak self] text, type in
            self?.appendLog(text, type: type)
        } onComplete: { [weak self] success, code in
            guard let self = self else { return }
            self.isRunningTask = false
            self.terminalRunningCommand = ""
            self.currentTaskName = ""
            self.terminalPID = nil
            self.terminalStartTime = nil
            self.refreshAllTelemetry()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.terminalPID = StudioProcessRunner.shared.currentPID
        }
    }
    
    public func killActiveCommand() {
        StudioProcessRunner.shared.killRunningProcess()
        appendLog("⏹ Process killed by user (SIGINT/SIGTERM).", .warning)
        isRunningTask = false
        terminalRunningCommand = ""
        currentTaskName = ""
        terminalPID = nil
        terminalStartTime = nil
    }
    
    public func previousHistoryCommand() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        if historyIndex > 0 {
            historyIndex -= 1
            return commandHistory[historyIndex]
        } else if historyIndex == 0 {
            return commandHistory[0]
        }
        return nil
    }
    
    public func nextHistoryCommand() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            return commandHistory[historyIndex]
        } else {
            historyIndex = commandHistory.count
            return ""
        }
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
    
    private func startTelemetryLoop() {
        telemetryCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isRunningTask else { return }
                self.refreshAllTelemetry()
            }
    }
    
    private func startExecutionTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.terminalStartTime else { return }
                self.terminalDurationSeconds = Date().timeIntervalSince(start)
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
