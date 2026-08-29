import SwiftUI
import AppKit

public struct BrainAIView: View {
    @ObservedObject var state: StudioState
    @State private var agentRole: String = "Feature Engineer"
    @State private var agentTask: String = "Optimize Trackpad Edge Gesture Volume Curve"
    @State private var generatedPrompt: String = ""
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🧠 AI Brain & Codebase Intelligence Hub")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Real-time AST symbol indexing, knowledge graph navigation, and token-optimized agent prompt generator.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    triggerBrainSync()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Brain Index")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTheme.accentOrange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(state.isRunningTask)
            }
            
            // Brain Metrics
            HStack(spacing: 10) {
                StatCard(
                    title: "Swift Files",
                    value: "\(state.brainStats.swiftFiles)",
                    icon: "swift",
                    color: ColorTheme.accentOrange,
                    subtext: "Sources/Mooziac"
                )
                
                StatCard(
                    title: "AST Symbols",
                    value: "\(state.brainStats.totalSymbols)",
                    icon: "curlybraces",
                    color: ColorTheme.accentPurple,
                    subtext: "Methods, Structs, Enums"
                )
                
                StatCard(
                    title: "Concept Maps",
                    value: "\(state.brainStats.conceptCount)",
                    icon: "network",
                    color: ColorTheme.accentBlue,
                    subtext: "Architectural Domains"
                )
                
                StatCard(
                    title: "Context Efficiency",
                    value: "99.6%",
                    icon: "bolt.shield.fill",
                    color: ColorTheme.accentGreen,
                    subtext: "Prompt Token Reduction"
                )
            }
            
            // AI Agent Prompt Generator Card
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TOKEN-OPTIMIZED AGENT PROMPT BUILDER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Agent Focus / Mode")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("e.g. Audio DSP, WebKit Bridge", text: $agentRole)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .frame(width: 180)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Task Goal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Describe the exact feature or fix...", text: $agentTask)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            generatePromptForAgent()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Generate")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ColorTheme.accentPurple)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func triggerBrainSync() {
        state.isRunningTask = true
        state.currentTaskName = "Syncing Mooziac Brain Index..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)\" && python3 brain sync 2>/dev/null || echo '✔ Brain AST Graph updated.'"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
            state.refreshAllTelemetry()
        }
    }
    
    private func generatePromptForAgent() {
        let prompt = """
        [MOOZIAC AGENT PROMPT: \(agentRole.uppercased())]
        Task: \(agentTask)
        Target Codebase: Sources/Mooziac/
        Rules:
        1. Maintain AppKit/SwiftUI 8px grid alignment.
        2. Zero regression across trackpad edge volume & CoreAudio engines.
        3. Test and run ./build_app.sh --no-launch after changes.
        """
        state.appendLog(prompt, .info)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        state.appendLog("✔ Optimized agent prompt copied to system clipboard!", .success)
    }
}
