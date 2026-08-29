import SwiftUI

public struct BrainDashboardView: View {
    @ObservedObject var state: BrainState = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // 1. Header Bar
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(state.isSyncing ? Color.orange.opacity(0.2) : (state.isWatching ? Color.green.opacity(0.2) : Color.gray.opacity(0.2)))
                        .frame(width: 36, height: 36)
                    
                    if state.isSyncing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("🧠")
                            .font(.system(size: 18))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Mooziac Brain")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        
                        Circle()
                            .fill(state.isSyncing ? Color.orange : (state.isWatching ? Color.green : Color.gray))
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(state.statusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Auto-Sync Toggle
                Toggle("", isOn: $state.isWatching)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help(state.isWatching ? "Real-Time Auto-Sync is ON" : "Real-Time Auto-Sync is PAUSED")
            }
            .padding(.bottom, 2)
            
            // 2. Metric Grid
            HStack(spacing: 8) {
                StatCard(
                    title: "Indexed Files",
                    value: "\(state.totalFiles)",
                    icon: "doc.text.fill",
                    color: .blue
                )
                StatCard(
                    title: "Symbols & AST",
                    value: "\(state.totalSymbols)",
                    icon: "curlybraces",
                    color: .purple
                )
                StatCard(
                    title: "Concept Maps",
                    value: "\(state.totalConcepts)",
                    icon: "network",
                    color: .green
                )
                StatCard(
                    title: "Token Savings",
                    value: "99.6%",
                    icon: "bolt.shield.fill",
                    color: .orange
                )
            }
            
            Divider()
                .opacity(0.3)
            
            // 3. Quick Search Bar
            SearchPanelView(state: state)
            
            // 4. Live Activity Stream (Updates from Agy, OpenCode, Developer)
            ActivityFeedView(state: state)
            
            Divider()
                .opacity(0.3)
            
            // 5. Action Buttons Footer
            HStack(spacing: 8) {
                Button(action: {
                    state.triggerIncrementalSync()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(state.isSyncing)
                
                Button(action: {
                    state.triggerDeepRebuild()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Rebuild")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(state.isSyncing)
                
                Button(action: {
                    openBrainMarkdown()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                        Text("brain.md")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    openBrainFolder()
                }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Reveal .mooziac-brain in Finder")
            }
        }
        .padding(14)
        .frame(width: 440)
        .background(
            VisualEffectBackground()
                .ignoresSafeArea()
        )
    }
    
    private func openBrainMarkdown() {
        let path = URL(fileURLWithPath: BrainProcessRunner.shared.workspacePath)
            .appendingPathComponent(".mooziac-brain/brain.md")
        NSWorkspace.shared.open(path)
    }
    
    private func openBrainFolder() {
        let path = URL(fileURLWithPath: BrainProcessRunner.shared.workspacePath)
            .appendingPathComponent(".mooziac-brain")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }
}

public struct VisualEffectBackground: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
