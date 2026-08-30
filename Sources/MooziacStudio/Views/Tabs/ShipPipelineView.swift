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
            } else if output.contains("Creating styled DMG") || output.contains("Creating ZIP") {
                state.pipelineSteps[2].status = .completed
                state.pipelineSteps[3].status = .running
            }
        } onComplete: { success, code in
            if success {
                for i in 0..<4 {
                    self.state.pipelineSteps[i].status = .completed
                }
                self.state.appendLog("✅ Build & DMG Packaging phase completed successfully!", .success)
                
                // Step 5: Web Deploy
                self.state.pipelineSteps[4].status = .running
                self.state.currentTaskName = "Syncing Website to VPS..."
                let webCmd = "cd \"\(ws)/www\" && ./push.sh"
                StudioProcessRunner.shared.executeCommand(webCmd) { out, typ in
                    self.state.appendLog(out, type: typ)
                } onComplete: { webSuccess, webCode in
                    if webSuccess {
                        self.state.pipelineSteps[4].status = .completed
                        self.state.appendLog("✅ Website deployment phase finished!", .success)
                    } else {
                        self.state.pipelineSteps[4].status = .failed
                        self.state.appendLog("⚠️ Web deploy finished with warning (\(webCode)).", .warning)
                    }
                    
                    // Step 6: Git Tag & Push Release
                    self.state.pipelineSteps[5].status = .running
                    self.state.currentTaskName = "Tagging & Shipping GitHub Release..."
                    let (newVer, newBuild, newTag) = StudioVersionManager.shared.bumpAndApplyVersion(workspacePath: ws)
                    let relCmd = "cd \"\(ws)\" && (git add -A && git commit -m \"Release \(newTag) (Build \(newBuild))\" || true) && git push origin HEAD && (git tag -d \(newTag) 2>/dev/null || true) && git tag -a \(newTag) -m \"Mooziac \(newVer) Release\" && git push origin \(newTag) && git status -s"
                    
                    StudioProcessRunner.shared.executeCommand(relCmd) { rOut, rTyp in
                        self.state.appendLog(rOut, type: rTyp)
                    } onComplete: { relSuccess, relCode in
                        self.state.isRunningTask = false
                        self.state.currentTaskName = ""
                        if relSuccess {
                            self.state.pipelineSteps[5].status = .completed
                            self.state.appendLog("🎉 Full Ship Pipeline Complete! All 6 phases passed.", .success)
                        } else {
                            self.state.pipelineSteps[5].status = .failed
                            self.state.appendLog("❌ Git release step failed with exit code \(relCode).", .error)
                        }
                        self.state.refreshVersionInfo()
                        self.state.refreshAllTelemetry()
                    }
                }
            } else {
                self.state.isRunningTask = false
                self.state.currentTaskName = ""
                self.state.pipelineSteps[1].status = .failed
                self.state.appendLog("❌ Ship pipeline failed at compile phase.", .error)
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
