import SwiftUI
import AppKit

// MARK: - VS Code-Style Integrated Terminal (Pure, Minimal, Zero Fluff)
public struct NativeTerminalView: View {
    @ObservedObject var state: StudioState
    @ObservedObject var pty: NativePTYSession = .shared
    @State private var viewMode: TerminalViewMode = .interactiveTerminal
    
    public enum TerminalViewMode {
        case interactiveTerminal
        case auditStream
    }
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - VS Code Terminal Header Bar
            HStack(spacing: 8) {
                // Window traffic dots + Terminal Tab Title
                HStack(spacing: 6) {
                    Circle().fill(Color(white: 0.35)).frame(width: 7, height: 7)
                    Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7)
                    Circle().fill(Color(white: 0.18)).frame(width: 7, height: 7)
                    
                    Text("TERMINAL")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.leading, 4)
                }
                
                // Mode Switcher: [ 1: zsh ] [ Audit Log ]
                HStack(spacing: 2) {
                    Button(action: { viewMode = .interactiveTerminal }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(pty.isRunning ? ColorTheme.statusGreen : Color(white: 0.3))
                                .frame(width: 5, height: 5)
                            Text("1: zsh")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(viewMode == .interactiveTerminal ? Color.white.opacity(0.15) : Color.clear)
                        .foregroundColor(viewMode == .interactiveTerminal ? .white : ColorTheme.secondaryGray)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewMode = .auditStream }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 8.5))
                            Text("Audit Stream")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(viewMode == .auditStream ? Color.white.opacity(0.15) : Color.clear)
                        .foregroundColor(viewMode == .auditStream ? .white : ColorTheme.secondaryGray)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(Color.white.opacity(0.06))
                .cornerRadius(5)
                
                // Active Running Task Banner
                if state.isRunningTask {
                    HStack(spacing: 5) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(state.currentTaskName)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.warningYellow)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                // Header Actions (Like VS Code: New / Restart / Clear / Interrupt / Pop Out)
                HStack(spacing: 6) {
                    // Interrupt active CLI tool (^C)
                    Button(action: {
                        pty.sendCtrlC()
                    }) {
                        Text("^C")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.10))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Send Ctrl+C (Interrupt)")
                    
                    // Clear Terminal Screen
                    Button(action: {
                        if viewMode == .interactiveTerminal {
                            pty.write(string: "\u{000C}") // Form Feed (Ctrl+L)
                        } else {
                            state.clearLogs()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.secondaryGray)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Output")
                    
                    // Restart Session
                    Button(action: {
                        pty.restart(workingDir: StudioProcessRunner.shared.workspacePath)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.secondaryGray)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Restart zsh Session")
                    
                    // Pop out into macOS Terminal.app
                    Button(action: {
                        openExternalTerminal()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Terminal.app ↗")
                        }
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open in native macOS Terminal.app")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.50))
            
            Divider().opacity(0.20)
            
            // MARK: - Body (Interactive Terminal or Audit Stream)
            if viewMode == .interactiveTerminal {
                NativeTerminalWebView(pty: pty, workingDir: StudioProcessRunner.shared.workspacePath)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ConsoleStreamView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ColorTheme.terminalBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
        .onAppear {
            if !pty.isRunning {
                pty.startSession(workingDir: StudioProcessRunner.shared.workspacePath)
            }
        }
    }
    
    private func openExternalTerminal(command: String? = nil) {
        let ws = StudioProcessRunner.shared.workspacePath
        let home = NSHomeDirectory()
        let pathExport = "export PATH=\"\(home)/.gemini/antigravity-cli/bin:\(home)/.local/bin:\(home)/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\""
        var script = "tell application \"Terminal\" to do script \"\(pathExport) && cd '\(ws)'"
        if let cmd = command, !cmd.isEmpty {
            script += " && \(cmd)"
        }
        script += "\"\ntell application \"Terminal\" to activate"
        
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            appleScript.executeAndReturnError(&err)
        }
    }
}
