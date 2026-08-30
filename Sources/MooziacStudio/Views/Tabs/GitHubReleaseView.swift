import SwiftUI
import AppKit

public struct GitHubReleaseView: View {
    @ObservedObject var state: StudioState
    @State private var releaseTag: String = "v1.0.5"
    @State private var releaseTitle: String = "Mooziac 1.0.5 Release"
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
                    
                    Text("Live semantic version intelligence, automated Git tagging, and GitHub release deployment.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        state.refreshVersionInfo()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Versions")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTheme.panelDark)
                        .foregroundColor(ColorTheme.accentTeal)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if let url = URL(string: state.versionInfo.latestGitHubReleaseURL) {
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
            }
            
            // Live Version Intelligence Dashboard (4 Status Cards)
            HStack(spacing: 8) {
                StatCard(
                    title: "Project Source",
                    value: "v\(state.versionInfo.projectVersion)",
                    icon: "curlybraces",
                    color: ColorTheme.accentTeal,
                    subtext: "Build \(state.versionInfo.projectBuild) in build_app.sh"
                )
                
                StatCard(
                    title: "Installed App",
                    value: "v\(state.versionInfo.installedAppVersion)",
                    icon: "macbook.and.iphone",
                    color: ColorTheme.accentBlue,
                    subtext: "Build \(state.versionInfo.installedAppBuild) in ~/Applications"
                )
                
                StatCard(
                    title: "Latest Git Tag",
                    value: state.versionInfo.latestGitTag,
                    icon: "tag",
                    color: ColorTheme.accentOrange,
                    subtext: "Local git repository ref"
                )
                
                StatCard(
                    title: "GitHub Live Release",
                    value: state.versionInfo.latestGitHubReleaseTag,
                    icon: "cloud.fill",
                    color: ColorTheme.accentPurple,
                    subtext: state.versionInfo.latestGitHubReleaseDate.isEmpty ? "Live GitHub API" : state.versionInfo.latestGitHubReleaseDate
                )
            }
            
            // Release Configuration Card
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("NEXT RELEASE PARAMETERS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Auto-fill convenience buttons
                        HStack(spacing: 6) {
                            Text("Auto Suggest:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                releaseTag = state.versionInfo.computedNextTag
                                releaseTitle = "Mooziac \(state.versionInfo.computedNextVersion) Release"
                            }) {
                                Text("Next (\(state.versionInfo.computedNextTag))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorTheme.accentPurple.opacity(0.3))
                                    .foregroundColor(ColorTheme.accentPurple)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                releaseTag = "v\(state.versionInfo.projectVersion)"
                                releaseTitle = "Mooziac \(state.versionInfo.projectVersion) Release"
                            }) {
                                Text("Current (v\(state.versionInfo.projectVersion))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Git Tag Version")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("v1.0.5", text: $releaseTag)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Release Name")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Mooziac 1.0.5 Release", text: $releaseTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .frame(width: 220)
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(ColorTheme.accentPurple)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .shadow(color: ColorTheme.accentPurple.opacity(0.4), radius: 6, x: 0, y: 2)
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
                        .frame(height: 65)
                        .cornerRadius(6)
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
        .onAppear {
            if releaseTag == "v1.0.5" && !state.versionInfo.computedNextTag.isEmpty {
                releaseTag = state.versionInfo.computedNextTag
                releaseTitle = "Mooziac \(state.versionInfo.computedNextVersion) Release"
            }
        }
    }
    
    private func triggerGitTagAndPush() {
        state.isRunningTask = true
        state.currentTaskName = "Tagging Git & Triggering Release CI/CD..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cleanTag = releaseTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = releaseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTag.isEmpty else { return }
        
        let cmd = "cd \"\(ws)\" && git push origin HEAD && (git tag -d \(cleanTag) 2>/dev/null || true) && git tag -a \(cleanTag) -m \"\(cleanTitle)\" && git push origin \(cleanTag) && git status -s"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
            if success {
                state.appendLog("🏷️ Git tag \(cleanTag) pushed to GitHub! CI/CD release workflow triggered.", .success)
            } else {
                state.appendLog("❌ Failed to push tag \(cleanTag) (exit code \(code)).", .error)
            }
            state.refreshVersionInfo()
        }
    }
}
