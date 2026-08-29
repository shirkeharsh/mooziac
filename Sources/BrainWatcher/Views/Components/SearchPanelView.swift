import SwiftUI

public struct SearchPanelView: View {
    @ObservedObject var state: BrainState
    
    public init(state: BrainState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    
                    TextField("Search symbols, files, audio engine, docs...", text: $state.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .onSubmit {
                            state.performSearch()
                        }
                    
                    if !state.searchQuery.isEmpty {
                        Button(action: {
                            state.searchQuery = ""
                            state.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                
                Button(action: {
                    state.performSearch()
                }) {
                    if state.isSearching {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 24, height: 24)
                    } else {
                        Text("Search")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if !state.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.searchResults) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.category.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(3)
                                    
                                    Text("<\(item.doc_type)>")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if let file = item.file_path {
                                        Text(URL(fileURLWithPath: file).lastPathComponent)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            )
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }
}
