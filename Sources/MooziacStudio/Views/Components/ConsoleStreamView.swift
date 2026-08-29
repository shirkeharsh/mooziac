import SwiftUI
import AppKit

public struct ConsoleStreamView: View {
    @ObservedObject var state: StudioState
    @State private var autoScroll: Bool = true
    @State private var quickCommandInput: String = ""
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow).frame(width: 8, height: 8)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    
                    Text("STUDIO AUTOMATION TERMINAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                    
                    Text("[Mooziac]")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(ColorTheme.accentOrange)
                }
                
                Spacer()
                
                if state.isRunningTask {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(state.currentTaskName)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.accentOrange)
                        
                        Button(action: {
                            state.killActiveCommand()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTheme.accentRed)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 8)
                }
                
                Button(action: {
                    autoScroll.toggle()
                }) {
                    Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "arrow.down.to.line")
                        .font(.system(size: 10))
                        .foregroundColor(autoScroll ? ColorTheme.accentGreen : .secondary)
                }
                .buttonStyle(.plain)
                .help(autoScroll ? "Auto-scroll Enabled" : "Auto-scroll Paused")
                
                Button(action: {
                    copyLogsToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy All Logs")
                
                Button(action: {
                    state.clearLogs()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Terminal")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))
            
            Divider().opacity(0.2)
            
            // Console Scroll List
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(state.logs) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.timestamp, style: .time)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .frame(width: 55, alignment: .leading)
                                
                                Text(entry.text)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(colorForType(entry.type))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: state.logs.count) { _ in
                    if autoScroll, let last = state.logs.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider().opacity(0.2)
            
            // Bottom Quick Interactive Input Bar
            HStack(spacing: 6) {
                Text("❯")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.accentTeal)
                
                TextField("Run shell command...", text: $quickCommandInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit {
                        executeQuickCommand()
                    }
                
                if !quickCommandInput.isEmpty {
                    Button(action: {
                        quickCommandInput = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    executeQuickCommand()
                }) {
                    Text("↵ Run")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ColorTheme.accentTeal.opacity(0.85))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(quickCommandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isRunningTask)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.3))
        }
        .background(ColorTheme.terminalBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
    }
    
    private func executeQuickCommand() {
        let trimmed = quickCommandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quickCommandInput = ""
        state.executeTerminalCommand(trimmed)
    }
    
    private func colorForType(_ type: ConsoleLogEntry.LogType) -> Color {
        switch type {
        case .standard: return Color(white: 0.85)
        case .success: return ColorTheme.accentGreen
        case .warning: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .error: return ColorTheme.accentRed
        case .command: return ColorTheme.accentTeal
        case .info: return ColorTheme.accentPurple
        }
    }
    
    private func copyLogsToClipboard() {
        let text = state.logs.map { "\($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
