import SwiftUI

public struct NavigationSidebar: View {
    @ObservedObject var state: StudioState
    
    public init(state: StudioState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Branding Header with New Custom Studio Aesthetic
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.25, blue: 0.95), Color(red: 0.15, green: 0.75, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("❯_")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mooziac Studio")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(state.playerTelemetry.isRunning ? ColorTheme.accentGreen : Color.gray)
                            .frame(width: 6, height: 6)
                        
                        Text(state.playerTelemetry.isRunning ? "Player PID: \(state.playerTelemetry.pid)" : "Player Idle")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            
            Divider().opacity(0.3)
            
            // Navigation Links
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(StudioTab.allCases) { tab in
                        Button(action: {
                            state.selectedTab = tab
                        }) {
                            HStack(spacing: 9) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 13))
                                    .foregroundColor(state.selectedTab == tab ? tab.badgeColor : .secondary)
                                    .frame(width: 18)
                                
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: state.selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(state.selectedTab == tab ? .white : .secondary)
                                
                                Spacer()
                                
                                if tab == .terminal && state.isRunningTask {
                                    Circle()
                                        .fill(ColorTheme.accentOrange)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(state.selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            // Server & Brain Quick Badges in Sidebar Footer
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(state.vpsTelemetry.isReachable ? ColorTheme.accentGreen : ColorTheme.accentRed)
                            .frame(width: 6, height: 6)
                        Text("VPS: \(state.vpsTelemetry.latencyMs)ms")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Dev Studio")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.accentTeal)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 200)
        .background(ColorTheme.backgroundDark)
    }
}
