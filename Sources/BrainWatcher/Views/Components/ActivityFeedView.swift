import SwiftUI

public struct ActivityFeedView: View {
    @ObservedObject var state: BrainState
    
    public init(state: BrainState) {
        self.state = state
    }
    
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LIVE ACTIVITY & AGENT LOGS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(state.recentActivity.count) entries")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 4)
            
            if state.recentActivity.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Watching for code modifications...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.recentActivity) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.type.rawValue)
                                    .font(.system(size: 8, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(item.type.color.opacity(0.2))
                                    .foregroundColor(item.type.color)
                                    .cornerRadius(4)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text(item.detail)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Text(timeFormatter.string(from: item.timestamp))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 160)
            }
        }
    }
}
