import SwiftUI
import AppKit

public struct ActiveTerminalView: View {
    @ObservedObject var state: StudioState
    @ObservedObject var pty: NativePTYSession = .shared
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Top Toolbar - Clean and unified for Mooziac workspace
            HStack(spacing: 8) {
                // Title & Mooziac Workspace Indicator
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(ColorTheme.accentTeal)
                        .font(.system(size: 13))
                    
                    Text("TERMINAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(ColorTheme.accentTeal.opacity(0.8))
                            .font(.system(size: 9))
                        Text("Mooziac")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                // Session Status & Controls
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(pty.isRunning ? ColorTheme.accentGreen : ColorTheme.accentRed)
                            .frame(width: 6, height: 6)
                        
                        Text(pty.isRunning ? "zsh [PID: \(pty.currentPID ?? 0)]" : "Offline")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(pty.isRunning ? ColorTheme.accentGreen : .secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    
                    // Send SIGINT / Ctrl+C
                    Button(action: {
                        pty.sendSignal(SIGINT)
                        pty.write(string: "\u{03}")
                    }) {
                        Text("^C")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ColorTheme.accentOrange.opacity(0.25))
                            .foregroundColor(ColorTheme.accentOrange)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Send Ctrl+C (Interrupt)")
                    
                    // Restart Session
                    Button(action: {
                        pty.startSession(workingDir: state.currentWorkingDirPath)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .help("Restart Shell Session")
                    
                    // Open in macOS Terminal.app
                    Button(action: {
                        openExternalTerminal()
                    }) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .help("Open in macOS Terminal.app")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(ColorTheme.panelDark)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ColorTheme.panelBorder, lineWidth: 1)
            )
            
            // Quick Command Presets Bar
            HStack(spacing: 6) {
                Text("QUICK:")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        presetChip("git status -sb", label: "git status", color: ColorTheme.accentOrange)
                        presetChip("git diff --stat", label: "git diff", color: ColorTheme.accentOrange)
                        presetChip("git log -n 5 --oneline", label: "git log", color: ColorTheme.accentOrange)
                        
                        Divider().frame(height: 10).opacity(0.3)
                        
                        presetChip("swift build", label: "swift build", color: ColorTheme.accentBlue)
                        presetChip("swift test", label: "swift test", color: ColorTheme.accentBlue)
                        presetChip("./build_app.sh", label: "build Mooziac", color: ColorTheme.accentPurple)
                        
                        Divider().frame(height: 10).opacity(0.3)
                        
                        presetChip("ps aux | grep -i mooziac", label: "mooziac ps", color: ColorTheme.accentYellow)
                        presetChip("top -l 1 -n 10", label: "top stats", color: ColorTheme.accentTeal)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ColorTheme.panelDark.opacity(0.6))
            .cornerRadius(5)
            
            // Native Interactive Terminal WebView
            NativeTerminalWebView(pty: pty, workingDir: state.currentWorkingDirPath)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTheme.terminalBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ColorTheme.panelBorder, lineWidth: 1)
                )
        }
        .onAppear {
            if !pty.isRunning {
                pty.startSession(workingDir: state.currentWorkingDirPath)
            }
        }
    }
    
    private func presetChip(_ command: String, label: String, color: Color) -> some View {
        Button(action: {
            pty.sendCommand(command)
        }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(color.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func openExternalTerminal() {
        let dir = state.currentWorkingDirPath
        let script = "tell application \"Terminal\" to do script \"cd \(dir)\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
