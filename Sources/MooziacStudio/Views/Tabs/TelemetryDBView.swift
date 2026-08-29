import SwiftUI
import AppKit

public struct TelemetryDBView: View {
    @ObservedObject var state: StudioState
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🔍 Telemetry & SQLite Database Cockpit")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Unified ecosystem telemetry (Host + WebKit WebContent, GPU & Networking) & SQLite browser.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        let path = SQLiteInspector.shared.dbPath
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("Reveal DB")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTheme.panelDark)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        state.refreshAllTelemetry()
                        if let table = state.selectedSqliteTable {
                            state.loadTableRows(table)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTheme.accentBlue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Process Telemetry Combined Grid (6 Cards)
            HStack(spacing: 8) {
                StatCard(
                    title: "Player Ecosystem",
                    value: state.playerTelemetry.isRunning ? "\(state.playerTelemetry.processCount) Processes" : "STOPPED",
                    icon: "app.badge.checkmark",
                    color: state.playerTelemetry.isRunning ? ColorTheme.accentGreen : Color.gray,
                    subtext: state.playerTelemetry.isRunning ? "Host PID \(state.playerTelemetry.pid) • \(state.playerTelemetry.threadCount) thds" : "Not active"
                )
                
                StatCard(
                    title: "Combined CPU",
                    value: String(format: "%.1f %%", state.playerTelemetry.totalCpuPercent),
                    icon: "gauge.with.needle",
                    color: ColorTheme.accentBlue,
                    subtext: "Host + WebKit Engines"
                )
                
                StatCard(
                    title: "Combined RAM",
                    value: String(format: "%.1f MB", state.playerTelemetry.totalRamMB),
                    icon: "memorychip",
                    color: ColorTheme.accentPurple,
                    subtext: "Phys: \(String(format: "%.1f MB", state.playerTelemetry.totalRamFootprintMB))"
                )
                
                StatCard(
                    title: "GPU Hardware",
                    value: String(format: "%.1f %%", state.playerTelemetry.gpuPercent),
                    icon: "sparkles.tv",
                    color: ColorTheme.accentOrange,
                    subtext: "Metal / IOAccelerator"
                )
                
                StatCard(
                    title: "Storage & I/O",
                    value: String(format: "%.1f MB", state.playerTelemetry.totalDiskStorageMB),
                    icon: "internaldrive",
                    color: ColorTheme.accentTeal,
                    subtext: "R:\(String(format: "%.1f", state.playerTelemetry.totalDiskReadMB))M W:\(String(format: "%.1f", state.playerTelemetry.totalDiskWriteMB))M"
                )
                
                StatCard(
                    title: "Database Tables",
                    value: "\(state.sqliteTables.count)",
                    icon: "cylinder.split.1x2",
                    color: ColorTheme.accentYellow,
                    subtext: "\(SQLiteInspector.shared.dbFileName) (\(SQLiteInspector.shared.dbFileSizeString))"
                )
            }
            
            // Subprocesses Breakdown Bar
            if state.playerTelemetry.isRunning && !state.playerTelemetry.subProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("PROCESS TREE BREAKDOWN (HOST & WEBKIT ENGINES)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(state.playerTelemetry.subProcesses.count) active tasks")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.playerTelemetry.subProcesses) { proc in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(proc.name == "Mooziac" ? ColorTheme.accentGreen : ColorTheme.accentPurple)
                                        .frame(width: 6, height: 6)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(proc.role)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 6) {
                                            Text("PID \(proc.pid)")
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundColor(.secondary)
                                            
                                            Text("•")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                            
                                            Text("RAM: \(String(format: "%.1f MB", proc.ramMB))")
                                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                                .foregroundColor(ColorTheme.accentPurple)
                                            
                                            Text("•")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                            
                                            Text("CPU: \(String(format: "%.1f%%", proc.cpuPercent))")
                                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                                .foregroundColor(ColorTheme.accentBlue)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(ColorTheme.panelBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.panelDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorTheme.panelBorder, lineWidth: 1)
                        )
                )
            }
            
            // SQLite Tables & Record Browser
            HStack(alignment: .top, spacing: 12) {
                // Table Selector List
                VStack(alignment: .leading, spacing: 6) {
                    Text("SQLITE TABLES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    if state.sqliteTables.isEmpty {
                        VStack(spacing: 6) {
                            Text("No SQLite database found yet.\nLaunch Mooziac to initialize.")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(state.sqliteTables) { table in
                                    Button(action: {
                                        state.loadTableRows(table.name)
                                    }) {
                                        HStack {
                                            Text(table.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(state.selectedSqliteTable == table.name ? .white : .secondary)
                                            
                                            Spacer()
                                            
                                            Text("\(table.rowCount)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(4)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(state.selectedSqliteTable == table.name ? ColorTheme.accentOrange.opacity(0.3) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(width: 170)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.panelDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorTheme.panelBorder, lineWidth: 1)
                        )
                )
                
                // Sample Data Table
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(state.selectedSqliteTable != nil ? "RECORDS: \(state.selectedSqliteTable!)" : "SELECT A TABLE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(state.sqliteSampleRows.count) rows shown")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    if state.sqliteSampleRows.isEmpty {
                        VStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "tablecells")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.4))
                            Text(state.selectedSqliteTable != nil ? "Table '\(state.selectedSqliteTable!)' is currently empty" : "Select a table on the left to preview data")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(state.sqliteSampleRows) { row in
                                    HStack(spacing: 8) {
                                        ForEach(row.columns, id: \.self) { key in
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(key)
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(ColorTheme.accentBlue)
                                                Text(row.values[key] ?? "")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                            .padding(4)
                                            .background(Color.black.opacity(0.2))
                                            .cornerRadius(4)
                                            .frame(minWidth: 90, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.panelDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorTheme.panelBorder, lineWidth: 1)
                        )
                )
            }
            .frame(height: 200)
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
}
