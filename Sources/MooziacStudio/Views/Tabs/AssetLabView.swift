import SwiftUI
import AppKit

public struct AssetLabView: View {
    @ObservedObject var state: StudioState
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🎨 Visual Asset & Reel Studio")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Audit marketing assets, Retina DMG background graphics, icon bundles, and web OpenGraph previews.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    openResourcesFolder()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                        Text("Reveal Resources/")
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
            
            // Asset Checklist Grid
            HStack(spacing: 12) {
                AssetCard(
                    name: "AppIcon.icns",
                    detail: "16x16 -> 1024x1024 Retina",
                    icon: "app.dashed",
                    color: ColorTheme.accentOrange,
                    exists: checkAsset("Resources/AppIcon.icns")
                )
                
                AssetCard(
                    name: "dmg_background.png",
                    detail: "660x400 Custom Canvas",
                    icon: "photo",
                    color: ColorTheme.accentBlue,
                    exists: checkAsset("Resources/dmg_background.png")
                )
                
                AssetCard(
                    name: "MenuBarIcon@2x.png",
                    detail: "Template Status Bar Icon",
                    icon: "menubar.rectangle",
                    color: ColorTheme.accentPurple,
                    exists: checkAsset("Resources/MenuBarIcon@2x.png")
                )
                
                AssetCard(
                    name: "OG Banner (Web)",
                    detail: "1200x630 Social Card",
                    icon: "globe.americas.fill",
                    color: ColorTheme.accentGreen,
                    exists: checkAsset("www/assets/og-image.jpg")
                )
            }
            
            // Asset Generation Card
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("RETINA DMG BACKGROUND GENERATOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("Renders pixel-perfect macOS Ventura/Sonoma styled installer graphic with drag-to-Applications arrow.")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        renderArtwork()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "paintpalette.fill")
                            Text("Re-render Background")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(ColorTheme.accentRed)
                        .foregroundColor(.white)
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
    
    private func checkAsset(_ relPath: String) -> Bool {
        let ws = StudioProcessRunner.shared.workspacePath
        return FileManager.default.fileExists(atPath: "\(ws)/\(relPath)")
    }
    
    private func renderArtwork() {
        state.isRunningTask = true
        state.currentTaskName = "Rendering DMG Background Artwork..."
        let ws = StudioProcessRunner.shared.workspacePath
        let cmd = "cd \"\(ws)\" && swift scripts/generate_dmg_background.swift"
        
        StudioProcessRunner.shared.executeCommand(cmd) { text, type in
            state.appendLog(text, type: type)
        } onComplete: { success, code in
            state.isRunningTask = false
        }
    }
    
    private func openResourcesFolder() {
        let ws = StudioProcessRunner.shared.workspacePath
        let res = "\(ws)/Resources"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: res)
    }
}

public struct AssetCard: View {
    let name: String
    let detail: String
    let icon: String
    let color: Color
    let exists: Bool
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                
                Spacer()
                
                Image(systemName: exists ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(exists ? ColorTheme.accentGreen : ColorTheme.accentOrange)
                    .font(.system(size: 11))
            }
            
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.panelDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.panelBorder, lineWidth: 1)
                )
        )
    }
}
