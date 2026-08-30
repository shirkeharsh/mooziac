import SwiftUI
import AppKit

public struct BuildCenterView: View {
    @ObservedObject var state: StudioState
    @State private var targetArch: String = "Universal 2 (arm64 + x86_64)"
    @State private var cleanBuild: Bool = false
    @State private var launchAfter: Bool = true
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🔨 Build & Packaging Center")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Compile optimized binaries, apply Hardened Runtime codesign, and package DMG installer.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    openDistFolder()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                        Text("Reveal dist/")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTheme.panelDark)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ColorTheme.panelBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Build Controls Grid
            HStack(spacing: 12) {
                // Option Cards
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("COMPILATION TARGETS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("Project:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("v\(state.versionInfo.projectVersion) (Build \(state.versionInfo.projectBuild))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ColorTheme.accentTeal)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                triggerBuild(universal: true)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cpu")
                                    Text("Build Universal 2 DMG")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(ColorTheme.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isRunningTask)
                            
                            Button(action: {
                                triggerBuild(universal: false)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Fast Dev Build & Run")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(ColorTheme.accentOrange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isRunningTask)
                        }
                    }
                }
                
                // Quick Utilities
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("UTILITIES & ASSETS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                generateDmgArtwork()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.artframe")
                                    Text("Gen DMG Artwork")
                                }
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isRunningTask)
                            
                            Button(action: {
                                launchMooziacApp()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Launch Mooziac")
                                }
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Console Stream
            ConsoleStreamView(state: state)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func triggerBuild(universal: Bool) {
        state.isRunningTask = true
        state.currentTaskName = universal ? "Compiling Universal 2 Binary & DMG..." : "Building Dev Release..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = universal ? "cd \"\(ws)\" && ./build_app.sh" : "cd \"\(ws)\" && ./build_app.sh"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
            state.refreshAllTelemetry()
        }
    }
    
    private func generateDmgArtwork() {
        state.isRunningTask = true
        state.currentTaskName = "Generating DMG Background Art..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)\" && swift scripts/generate_dmg_background.swift"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
        }
    }
    
    private func launchMooziacApp() {
        let appPath = "\(NSHomeDirectory())/Applications/Mooziac.app"
        if FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            state.appendLog("🚀 Launched Mooziac.app from \(appPath)", .success)
        } else {
            state.appendLog("⚠️ Mooziac.app not found at \(appPath). Please build first.", .warning)
        }
    }
    
    private func openDistFolder() {
        let ws = StudioProcessRunner.shared.workspacePath
        let dist = "\(ws)/dist"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dist)
    }
}
