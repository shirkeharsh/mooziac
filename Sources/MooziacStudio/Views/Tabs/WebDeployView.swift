import SwiftUI
import AppKit

public struct WebDeployView: View {
    @ObservedObject var state: StudioState
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🌐 Web & VPS Deployment Center")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sync static assets, 3D web player, and SEO metadata to Ubuntu VPS with automated Nginx reload.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "https://mooziac.threeten.site") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                        Text("Open Live Site")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTheme.panelDark)
                    .foregroundColor(ColorTheme.accentBlue)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ColorTheme.panelBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Server Metrics Banner
            HStack(spacing: 10) {
                StatCard(
                    title: "VPS Status",
                    value: state.vpsTelemetry.isReachable ? "ONLINE" : "UNREACHABLE",
                    icon: "server.rack",
                    color: state.vpsTelemetry.isReachable ? ColorTheme.accentGreen : ColorTheme.accentRed,
                    subtext: state.vpsTelemetry.host
                )
                
                StatCard(
                    title: "HTTP Latency",
                    value: "\(state.vpsTelemetry.latencyMs) ms",
                    icon: "waveform.path.ecg",
                    color: ColorTheme.accentBlue,
                    subtext: "HTTP \(state.vpsTelemetry.httpStatusCode)"
                )
                
                StatCard(
                    title: "SSH Key Auth",
                    value: checkKeyStatus() ? "VALID (400)" : "MISSING",
                    icon: "key.fill",
                    color: checkKeyStatus() ? ColorTheme.accentPurple : ColorTheme.accentOrange,
                    subtext: "mooziac.pem"
                )
            }
            
            // Deploy Controls
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ONE-CLICK VPS DEPLOYMENT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("Rsyncs www/ -> /var/www/mooziac/, fixes permissions (chown www-data), and reloads Nginx.")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        triggerWebDeploy()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            Text("Deploy to VPS Now")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ColorTheme.accentGreen)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isRunningTask)
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func checkKeyStatus() -> Bool {
        let ws = StudioProcessRunner.shared.workspacePath
        let key = "\(ws)/www/mooziac.pem"
        return FileManager.default.fileExists(atPath: key)
    }
    
    private func triggerWebDeploy() {
        state.isRunningTask = true
        state.currentTaskName = "Syncing & Deploying to AWS VPS..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)/www\" && ./push.sh"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
            state.refreshAllTelemetry()
        }
    }
}
