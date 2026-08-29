import SwiftUI

public struct StudioMainView: View {
    @ObservedObject var state: StudioState = .shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Navigation Sidebar
            NavigationSidebar(state: state)
            
            Divider().opacity(0.3)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Header Toolbar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: state.selectedTab.iconName)
                            .foregroundColor(state.selectedTab.badgeColor)
                        Text(state.selectedTab.rawValue)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(state.playerTelemetry.isRunning ? ColorTheme.accentGreen : Color.gray)
                                .frame(width: 7, height: 7)
                            Text(state.playerTelemetry.isRunning ? "PID: \(state.playerTelemetry.pid)" : "Player Off")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 14).opacity(0.4)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(state.vpsTelemetry.isReachable ? ColorTheme.accentGreen : ColorTheme.accentRed)
                                .frame(width: 7, height: 7)
                            Text(state.vpsTelemetry.isReachable ? "\(state.vpsTelemetry.latencyMs)ms" : "VPS Down")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ColorTheme.backgroundDark)
                
                Divider().opacity(0.2)
                
                // Tab Content Switcher
                Group {
                    switch state.selectedTab {
                    case .terminal:
                        ActiveTerminalView(state: state)
                    case .pipeline:
                        ShipPipelineView(state: state)
                    case .build:
                        BuildCenterView(state: state)
                    case .web:
                        WebDeployView(state: state)
                    case .github:
                        GitHubReleaseView(state: state)
                    case .telemetry:
                        TelemetryDBView(state: state)
                    case .brain:
                        BrainAIView(state: state)
                    case .assets:
                        AssetLabView(state: state)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTheme.backgroundDark)
            }
        }
        .frame(minWidth: 890, minHeight: 580)
        .background(ColorTheme.backgroundDark.ignoresSafeArea())
    }
}
