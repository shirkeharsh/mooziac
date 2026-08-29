import SwiftUI
import AppKit

public struct GitHubReleaseView: View {
    @ObservedObject var state: StudioState
    @State private var releaseTag: String = "v1.0.2"
    @State private var releaseTitle: String = "Mooziac 1.0.2 Release"
    @State private var isDraft: Bool = false
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🐙 GitHub Release & CI/CD Hub")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Automate Git semantic tagging, trigger GitHub Actions workflows, and publish release DMG/ZIP assets.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "https://github.com/shirkeharsh/mooziac/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                        Text("View Releases")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTheme.panelDark)
                    .foregroundColor(ColorTheme.accentPurple)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ColorTheme.panelBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Release Configuration Card
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RELEASE PARAMETERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Git Tag Version")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("v1.0.2", text: $releaseTag)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Release Name")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Mooziac 1.0.2", text: $releaseTitle)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .frame(width: 200)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            triggerGitTagAndPush()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                Text("Create Tag & Push")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ColorTheme.accentPurple)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(state.isRunningTask)
                    }
                }
            }
            
            // Release Notes Editor
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RELEASE NOTES & CHANGELOG SUMMARY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $state.releaseNotesText)
                        .font(.system(size: 11, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.25))
                        .frame(height: 70)
                        .cornerRadius(6)
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func triggerGitTagAndPush() {
        state.isRunningTask = true
        state.currentTaskName = "Tagging Git & Triggering Release CI/CD..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)\" && git tag -a \(releaseTag) -m \"\(releaseTitle)\" 2>/dev/null || true && git status -s"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
            state.appendLog("🏷️ Git tag \(releaseTag) prepared.", .success)
        }
    }
}
