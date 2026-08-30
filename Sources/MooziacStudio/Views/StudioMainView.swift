import SwiftUI
import AppKit

// MARK: - Mooziac Studio Main View (Ultra-Clean, Perfectly Aligned, VS Code Terminal)
public struct StudioMainView: View {
    @ObservedObject var state: StudioState = .shared
    @ObservedObject var gh: GitHubRepositoryManager = .shared
    @ObservedObject var theme: StudioThemeManager = .shared
    
    @State private var releaseTag: String = "v1.0.5"
    @State private var releaseTitle: String = "Mooziac 1.0.5 Release"
    @State private var showGitHubSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Global Top Command Bar (Large, Crisp & Modern Redesign)
            HStack(spacing: 12) {
                // Left: Branding & Version Badge
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(theme.currentTheme == .mooziac ? Color.white.opacity(0.16) : Color(white: 0.14))
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(theme.currentTheme == .mooziac ? ColorTheme.accentPink.opacity(0.5) : Color.white.opacity(0.22), lineWidth: 1)
                            )
                        
                        Text("❯_")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(theme.currentTheme == .mooziac ? ColorTheme.accentPink : .white)
                    }
                    
                    Text("Mooziac Studio")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("v\(state.versionInfo.projectVersion)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.14))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Right: HUD Telemetry Pills (Bigger, High Contrast & Tactile)
                HStack(spacing: 8) {
                    // Watcher Toggle
                    Button(action: {
                        state.toggleWatcher()
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(state.isWatcherActive ? ColorTheme.statusGreen : Color(white: 0.40))
                                .frame(width: 7, height: 7)
                                .shadow(color: state.isWatcherActive ? ColorTheme.statusGreen.opacity(0.7) : Color.clear, radius: 4)
                            
                            Text(state.isWatcherActive ? "Watcher ON" : "Watcher OFF")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(state.isWatcherActive ? .white : ColorTheme.secondaryGray)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(state.isWatcherActive ? Color.white.opacity(0.12) : theme.panelDark)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(state.isWatcherActive ? Color.white.opacity(0.30) : theme.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle FSEvents Workspace File Watcher")
                    
                    // Website Latency Status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(state.vpsTelemetry.isReachable ? ColorTheme.statusGreen : ColorTheme.accentRed)
                            .frame(width: 7, height: 7)
                            .shadow(color: state.vpsTelemetry.isReachable ? ColorTheme.statusGreen.opacity(0.7) : Color.clear, radius: 4)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.accentTeal)
                        
                        Text(state.vpsTelemetry.isReachable ? "\(state.vpsTelemetry.latencyMs)ms" : "Down")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(state.vpsTelemetry.isReachable ? .white : ColorTheme.accentRed)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(theme.panelDark)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(theme.panelBorder, lineWidth: 1)
                    )
                    
                    // GitHub & Ecosystem Live Pulse (Downloads, Stars, Forks, Issues)
                    Button(action: {
                        showGitHubSheet = true
                    }) {
                        HStack(spacing: 9) {
                            // Downloads
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ColorTheme.statusGreen)
                                Text("\(gh.stats.totalDownloadsCount)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("dl")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(ColorTheme.secondaryGray)
                            }
                            
                            Divider().frame(height: 12).opacity(0.3)
                            
                            // Stars
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(ColorTheme.goldStar)
                                Text("\(gh.stats.starsCount)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            Divider().frame(height: 12).opacity(0.3)
                            
                            // Forks
                            HStack(spacing: 4) {
                                Image(systemName: "tuningfork")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(ColorTheme.accentTeal)
                                Text("\(gh.stats.forksCount)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            Divider().frame(height: 12).opacity(0.3)
                            
                            // Issues
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(gh.stats.openIssuesCount > 0 ? ColorTheme.warningYellow : ColorTheme.statusGreen)
                                Text("\(gh.stats.openIssuesCount)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(gh.stats.openIssuesCount > 0 ? ColorTheme.warningYellow : ColorTheme.statusGreen)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.panelDark)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open Live GitHub Pulse, Downloads & Issues Breakdown")
                    
                    // Theme Switcher (Dark vs Mooziac Website Theme)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.toggleTheme()
                        }
                    }) {
                        HStack(spacing: 5) {
                            if theme.currentTheme == .mooziac {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(ColorTheme.accentPink)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(ColorTheme.secondaryGray)
                            }
                            
                            Text(theme.currentTheme.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(theme.panelDark)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.currentTheme == .mooziac ? ColorTheme.accentPurple.opacity(0.6) : theme.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Theme (Dark vs Mooziac Website Theme)")
                    
                    // Dist Folder
                    Button(action: {
                        state.revealDistInFinder()
                    }) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.goldStar)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(theme.panelDark)
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(theme.panelBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Reveal dist/ in Finder")
                    
                    // Refresh
                    Button(action: {
                        state.refreshVersionInfo()
                        state.refreshAllTelemetry()
                        gh.refreshAll()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorTheme.accentTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(theme.panelDark)
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(theme.panelBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Refresh All Status & Telemetry")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.topBarBackground)
            
            Divider().opacity(0.25)
            
            // MARK: - Main Body (3 Action Cards + VS Code Integrated Terminal)
            VStack(spacing: 8) {
                // Top Action Deck (3 Uniform Equal-Size Cards)
                HStack(spacing: 8) {
                    // Card 1: Build Pipeline
                    ActionCardContainer(
                        title: "BUILD PIPELINE",
                        icon: "hammer.fill",
                        iconColor: ColorTheme.accentBlue,
                        badgeText: "UNIVERSAL"
                    ) {
                        VStack(spacing: 5) {
                            Button(action: {
                                let ws = StudioProcessRunner.shared.workspacePath
                                runCommandInTerminal(cmd: "cd \"\(ws)\" && ./build_app.sh --no-launch", taskName: "Building Universal 2 DMG...")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "cpu")
                                    Text("Build Universal DMG")
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                let ws = StudioProcessRunner.shared.workspacePath
                                runCommandInTerminal(cmd: "cd \"\(ws)\" && ./build_app.sh", taskName: "Fast Dev Build & Run...")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                    Text("Fast Dev Build & Run")
                                }
                                .font(.system(size: 9.5, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer(minLength: 0)
                            
                            HStack {
                                Text("v\(state.versionInfo.projectVersion) (Build \(state.versionInfo.projectBuild))")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.secondaryGray)
                                Spacer()
                                Text("dist/Mooziac.dmg")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.dimGray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Card 2: Website Deploy
                    ActionCardContainer(
                        title: "WEBSITE DEPLOY",
                        icon: "globe",
                        iconColor: ColorTheme.accentTeal,
                        badgeText: "VPS NGINX"
                    ) {
                        VStack(spacing: 5) {
                            Button(action: {
                                let ws = StudioProcessRunner.shared.workspacePath
                                runCommandInTerminal(cmd: "cd \"\(ws)/www\" && ./push.sh", taskName: "Deploying Website to VPS...")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Deploy Website (push.sh)")
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                state.openWebsiteInBrowser()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Open mooziac.threeten.site")
                                }
                                .font(.system(size: 9.5, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer(minLength: 0)
                            
                            HStack {
                                Text("Host: 13.234.245.199")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.secondaryGray)
                                Spacer()
                                Text("mooziac.pem")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.dimGray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Card 3: Ship & Release
                    ActionCardContainer(
                        title: "SHIP & RELEASE",
                        icon: "bolt.fill",
                        iconColor: ColorTheme.accentOrange,
                        badgeText: "AUTO BUMP"
                    ) {
                        VStack(spacing: 5) {
                            Button(action: {
                                let ws = StudioProcessRunner.shared.workspacePath
                                let (newVer, newBuild, newTag) = StudioVersionManager.shared.bumpAndApplyVersion(workspacePath: ws)
                                let cmd = "cd \"\(ws)\" && (git add -A && git commit -m \"Release \(newTag) (Build \(newBuild))\" || true) && git push origin HEAD && (git tag -d \(newTag) 2>/dev/null || true) && git tag -a \(newTag) -m \"Mooziac \(newVer) Release\" && git push origin \(newTag) && git status -s"
                                runCommandInTerminal(cmd: cmd, taskName: "Shipping \(newTag)...")
                                state.refreshVersionInfo()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                    Text("Push Release (\(state.versionInfo.computedNextTag))")
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            HStack(spacing: 4) {
                                Text("Tag:")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(ColorTheme.secondaryGray)
                                
                                TextField("v1.0.5", text: $releaseTag)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .frame(height: 24)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                
                                Button(action: {
                                    let ws = StudioProcessRunner.shared.workspacePath
                                    let cleanTag = releaseTag.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let cleanTitle = releaseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !cleanTag.isEmpty else { return }
                                    let cmd = "cd \"\(ws)\" && git push origin HEAD && (git tag -d \(cleanTag) 2>/dev/null || true) && git tag -a \(cleanTag) -m \"\(cleanTitle)\" && git push origin \(cleanTag) && git status -s"
                                    runCommandInTerminal(cmd: cmd, taskName: "Pushing \(cleanTag)...")
                                    state.refreshVersionInfo()
                                }) {
                                    Text("Custom")
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .frame(height: 24)
                                        .background(Color.white.opacity(0.10))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer(minLength: 0)
                            
                            HStack {
                                Text("Current: v\(state.versionInfo.projectVersion)")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(ColorTheme.secondaryGray)
                                Spacer()
                                Text("GH: \(state.versionInfo.latestGitHubReleaseTag)")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 124)
                
                // Bottom: VS Code-Style Terminal
                NativeTerminalView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 480)
        .background(StudioThemeBackground())
        .sheet(isPresented: $showGitHubSheet) {
            GitHubNotificationsSheet()
        }
        .onAppear {
            if !state.versionInfo.computedNextTag.isEmpty {
                releaseTag = state.versionInfo.computedNextTag
                releaseTitle = "Mooziac \(state.versionInfo.computedNextVersion) Release"
            }
        }
    }
    
    private func runCommandInTerminal(cmd: String, taskName: String) {
        state.isRunningTask = true
        state.currentTaskName = taskName
        state.appendLog("❯ [Mooziac] $ \(cmd)", .command)
        
        let pty = NativePTYSession.shared
        if !pty.isRunning {
            pty.startSession(workingDir: StudioProcessRunner.shared.workspacePath)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pty.sendCommand(cmd)
            }
        } else {
            pty.sendCommand(cmd)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            state.refreshVersionInfo()
            state.refreshAllTelemetry()
        }
    }
}

// MARK: - Action Card Container (Theme-Aware with Micro-Accents)
struct ActionCardContainer<Content: View>: View {
    @ObservedObject var theme: StudioThemeManager = .shared
    let title: String
    let icon: String
    var iconColor: Color = .white
    let badgeText: String
    let content: Content
    
    init(title: String, icon: String, iconColor: Color = .white, badgeText: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.badgeText = badgeText
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(iconColor)
                    
                    Text(title)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(badgeText)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(ColorTheme.secondaryGray)
                    .cornerRadius(3)
            }
            
            Divider().opacity(0.15)
            
            content
        }
        .padding(8)
        .background(theme.panelDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
    }
}
