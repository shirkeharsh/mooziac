import SwiftUI

public struct ShipPipelineView: View {
    @ObservedObject var state: StudioState
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Banner
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🚀 One-Click Universal Pipeline")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Full-stack automation: compiles Universal 2 binary, builds styled DMG, deploys website, and drafts GitHub release.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    runCompletePipeline()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("Ship Everything")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [ColorTheme.accentOrange, Color(red: 0.9, green: 0.2, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: ColorTheme.accentOrange.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(state.isRunningTask)
            }
            
            // Pipeline Stage Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(state.pipelineSteps) { step in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: step.status).opacity(0.2))
                                .frame(width: 28, height: 28)
                            
                            if step.status == .running {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: iconForStatus(step.status))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(circleColor(for: step.status))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(statusText(for: step.status))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTheme.panelDark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(step.status == .running ? ColorTheme.accentOrange : ColorTheme.panelBorder, lineWidth: 1)
                            )
                    )
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func runCompletePipeline() {
        state.isRunningTask = true
        state.currentTaskName = "Running Full Ship Pipeline..."
        state.appendLog("==================================================", .info)
        state.appendLog("  🚀 STARTING MOOZIAC FULL-STACK SHIP PIPELINE   ", .info)
        state.appendLog("==================================================", .info)
        
        // Reset steps
        for i in 0..<state.pipelineSteps.count {
            state.pipelineSteps[i].status = .pending
        }
        
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)\" && ./build_app.sh --no-launch"
        
        state.pipelineSteps[0].status = .running
        state.pipelineSteps[1].status = .running
        
        StudioProcessRunner.shared.executeCommand(cmd) { output, type in
            state.appendLog(output, type: type)
            if output.contains("Compiling release binaries") {
                state.pipelineSteps[0].status = .completed
                state.pipelineSteps[1].status = .running
            } else if output.contains("Code signing") {
                state.pipelineSteps[1].status = .completed
                state.pipelineSteps[2].status = .running
            } else if output.contains("Packaging Mooziac.dmg") {
                state.pipelineSteps[2].status = .completed
                state.pipelineSteps[3].status = .running
            }
        } onComplete: { success, code in
            state.isRunningTask = false
            if success {
                for i in 0..<4 {
                    state.pipelineSteps[i].status = .completed
                }
                state.appendLog("✅ Build & DMG Packaging phase completed successfully!", .success)
                state.refreshAllTelemetry()
            } else {
                state.pipelineSteps[1].status = .failed
                state.appendLog("❌ Ship pipeline failed at compile phase.", .error)
            }
        }
    }
    
    private func circleColor(for status: PipelineStep.StepStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .running: return ColorTheme.accentOrange
        case .completed: return ColorTheme.accentGreen
        case .failed: return ColorTheme.accentRed
        }
    }
    
    private func iconForStatus(_ status: PipelineStep.StepStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        }
    }
    
    private func statusText(for status: PipelineStep.StepStatus) -> String {
        switch status {
        case .pending: return "Queued"
        case .running: return "In Progress..."
        case .completed: return "Passed"
        case .failed: return "Failed"
        }
    }
}
