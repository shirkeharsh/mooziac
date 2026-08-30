import SwiftUI
import AppKit

public struct ConsoleStreamView: View {
    @ObservedObject var state: StudioState
    @State private var autoScroll: Bool = true
    @State private var searchFilter: String = ""
    
    public init(state: StudioState) {
        self.state = state
    }
    
    private var filteredLogs: [ConsoleLogEntry] {
        let trimmed = searchFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return state.logs
        }
        return state.logs.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Bar (Monochrome Obsidian Style)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isRunningTask ? ColorTheme.accentOrange : ColorTheme.statusGreen)
                        .frame(width: 7, height: 7)
                        .shadow(color: (state.isRunningTask ? ColorTheme.accentOrange : ColorTheme.statusGreen).opacity(0.6), radius: 3)
                    
                    Text("EXECUTION & AUDIT STREAM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if state.isRunningTask {
                        HStack(spacing: 5) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text(state.currentTaskName)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(ColorTheme.warningYellow)
                        }
                    }
                }
                
                Spacer()
                
                // Search Filter Pill
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundColor(ColorTheme.secondaryGray)
                    
                    TextField("Filter...", text: $searchFilter)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 70)
                    
                    if !searchFilter.isEmpty {
                        Button(action: { searchFilter = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 8.5))
                                .foregroundColor(ColorTheme.dimGray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)
                
                Divider().frame(height: 12).opacity(0.25)
                
                // Stop Active Task Button
                if state.isRunningTask {
                    Button(action: {
                        state.killActiveCommand()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ColorTheme.accentRed)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Halt Running Process")
                }
                
                // Auto Scroll Toggle
                Button(action: {
                    autoScroll.toggle()
                }) {
                    Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "arrow.down.to.line")
                        .font(.system(size: 10))
                        .foregroundColor(autoScroll ? ColorTheme.statusGreen : ColorTheme.secondaryGray)
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(autoScroll ? "Auto-scroll: ON" : "Auto-scroll: OFF")
                
                // Copy Logs Button
                Button(action: {
                    copyLogsToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.secondaryGray)
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Copy Log Entries")
                
                // Clear Logs Button
                Button(action: {
                    state.clearLogs()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.secondaryGray)
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Clear Activity Log")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.40))
            
            Divider().opacity(0.20)
            
            // MARK: - Native Fast NSTextView / SwiftUI Scrollable Feed
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if filteredLogs.isEmpty {
                            HStack {
                                Spacer()
                                Text("No activity recorded yet.")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.dimGray)
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                        } else {
                            ForEach(filteredLogs) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.timestamp, style: .time)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color(white: 0.40))
                                        .frame(width: 52, alignment: .leading)
                                    
                                    Text(entry.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorForType(entry.type))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: state.logs.count) { _ in
                    if autoScroll, let last = filteredLogs.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(ColorTheme.panelDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
    }
    
    private func colorForType(_ type: ConsoleLogEntry.LogType) -> Color {
        switch type {
        case .standard: return Color(white: 0.88)
        case .success: return ColorTheme.statusGreen
        case .warning: return ColorTheme.warningYellow
        case .error: return ColorTheme.accentRed
        case .command: return ColorTheme.accentTeal
        case .info: return Color(white: 0.75)
        }
    }
    
    private func copyLogsToClipboard() {
        let text = state.logs.map { "\($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
