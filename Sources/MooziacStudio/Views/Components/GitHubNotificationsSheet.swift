import SwiftUI
import AppKit

public struct GitHubNotificationsSheet: View {
    @ObservedObject var gh: GitHubRepositoryManager = .shared
    @ObservedObject var theme: StudioThemeManager = .shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (Theme-Aware)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.currentTheme == .mooziac ? ColorTheme.accentPurple.opacity(0.3) : Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.currentTheme == .mooziac ? ColorTheme.accentPink : .white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("GitHub Pulse & Issues")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            if let url = URL(string: gh.stats.repoURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("shirkeharsh/mooziac ↗")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(ColorTheme.secondaryGray)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Live issue triage, AI symbol locator & direct release pipeline")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.secondaryGray)
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: {
                    gh.refreshAll()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Refresh GitHub Data")
                
                // Close Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.secondaryGray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.panelDark)
            
            Divider().opacity(0.20)
            
            // MARK: - 5 Symmetrical Equal-Size Metric Cards (Downloads, Stars, Forks, Issues, Watchers)
            HStack(spacing: 8) {
                MetricCard(
                    icon: "arrow.down.circle.fill",
                    iconColor: ColorTheme.statusGreen,
                    label: "DOWNLOADS",
                    value: "\(gh.stats.totalDownloadsCount)"
                )
                
                MetricCard(
                    icon: "star.fill",
                    iconColor: ColorTheme.goldStar,
                    label: "STARS",
                    value: "\(gh.stats.starsCount)"
                )
                
                MetricCard(
                    icon: "tuningfork",
                    iconColor: ColorTheme.accentTeal,
                    label: "FORKS",
                    value: "\(gh.stats.forksCount)"
                )
                
                MetricCard(
                    icon: "exclamationmark.circle.fill",
                    iconColor: gh.stats.openIssuesCount > 0 ? ColorTheme.warningYellow : ColorTheme.statusGreen,
                    label: "ISSUES",
                    value: "\(gh.stats.openIssuesCount)"
                )
                
                MetricCard(
                    icon: "eye.fill",
                    iconColor: ColorTheme.accentPurple,
                    label: "WATCHERS",
                    value: "\(gh.stats.watchersCount)"
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // MARK: - Actions & Tab Strip
            HStack(spacing: 10) {
                // Tab Segment
                Picker("", selection: $selectedTab) {
                    Text("Issues (\(gh.issues.count))").tag(0)
                    Text("Work List (\(StudioState.shared.todoItems.filter { !$0.isDone }.count))").tag(1)
                    Text("Commits (\(gh.recentCommits.count))").tag(2)
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "\(gh.stats.repoURL)/issues/new") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Issue")
                    }
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            
            Divider().opacity(0.18)
            
            // MARK: - Tab Content
            ScrollView {
                VStack(spacing: 10) {
                    if selectedTab == 0 {
                        // Issues List
                        if gh.issues.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(ColorTheme.statusGreen)
                                    .padding(.top, 24)
                                Text("No Open Issues")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Repository is clean with zero active reports.")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorTheme.secondaryGray)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(gh.issues) { issue in
                                IssueCardRow(issue: issue)
                            }
                        }
                    } else if selectedTab == 1 {
                        // Studio Work List & TODOs
                        VStack(spacing: 6) {
                            ForEach(StudioState.shared.todoItems) { todo in
                                TodoCardRow(todo: todo)
                            }
                        }
                    } else {
                        // Commits List
                        ForEach(gh.recentCommits) { commit in
                            CommitCardRow(commit: commit)
                        }
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 660, height: 500)
        .background(StudioThemeBackground())
        .onAppear {
            gh.refreshAll()
            StudioState.shared.refreshBrainAndTodos()
        }
    }
}

// MARK: - Symmetrical Equal-Size Metric Card (Theme-Aware)
struct MetricCard: View {
    @ObservedObject var theme: StudioThemeManager = .shared
    let icon: String
    var iconColor: Color = .white
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(iconColor)
                
                Text(value)
                    .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(ColorTheme.secondaryGray)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(theme.panelDark)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
    }
}

// MARK: - Issue Card Row with AI Suggestor, Direct Commenting & Actions
struct IssueCardRow: View {
    let issue: GitHubIssueItem
    @ObservedObject var state: StudioState = .shared
    @ObservedObject var gh: GitHubRepositoryManager = .shared
    
    @State private var isReplying: Bool = false
    @State private var replyCommentText: String = ""
    @State private var isPosting: Bool = false
    @State private var feedbackMsg: String = ""
    
    var body: some View {
        let (suggestedFiles, _) = BrainBridge.shared.getAIKeywordsAndFiles(title: issue.title)
        
        VStack(alignment: .leading, spacing: 8) {
            // 1. Issue Header
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(issue.state == "open" ? ColorTheme.warningYellow : Color(white: 0.40))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("#\(issue.number)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorTheme.warningYellow)
                        
                        Text(issue.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 6) {
                        Text("reported by \(issue.author) • \(issue.createdAt)")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.secondaryGray)
                        
                        if issue.commentsCount > 0 {
                            HStack(spacing: 2.5) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 8.5))
                                Text("\(issue.commentsCount)")
                                    .font(.system(size: 9.5, design: .monospaced))
                            }
                            .foregroundColor(ColorTheme.accentTeal)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: issue.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.secondaryGray)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Open Issue on GitHub")
            }
            
            // 2. AI Codebase Suggestor (Clickable File Chips)
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5))
                    .foregroundColor(ColorTheme.accentPurple)
                
                Text("AI Match:")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.accentPurple)
                
                ForEach(suggestedFiles, id: \.self) { file in
                    let fileName = URL(fileURLWithPath: file).lastPathComponent
                    Button(action: {
                        let fullPath = "\(StudioProcessRunner.shared.workspacePath)/\(file)"
                        let url = URL(fileURLWithPath: fullPath)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 8))
                            Text(fileName)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(ColorTheme.accentPurple.opacity(0.20))
                        .foregroundColor(ColorTheme.accentPurple)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ColorTheme.accentPurple.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Reveal \(file) in Finder / Editor")
                }
            }
            
            // 3. Action Toolbar (Add to Brain, Add to TODO, Quick Reply)
            HStack(spacing: 8) {
                // Add to Brain
                Button(action: {
                    state.addIssueToBrain(issue: issue)
                    feedbackMsg = "Saved to Brain!"
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                        Text("Add to Brain")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                // Add to TODO
                Button(action: {
                    state.addIssueToTodo(issue: issue)
                    feedbackMsg = "Added to Work List!"
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                        Text("Add to TODO")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(ColorTheme.accentGreen.opacity(0.20))
                    .foregroundColor(ColorTheme.statusGreen)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                // Quick Reply Toggle
                Button(action: {
                    isReplying.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                        Text(isReplying ? "Cancel" : "Comment")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(isReplying ? Color.white.opacity(0.18) : ColorTheme.accentBlue.opacity(0.20))
                    .foregroundColor(ColorTheme.accentBlue)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                if !feedbackMsg.isEmpty {
                    Text(feedbackMsg)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(ColorTheme.statusGreen)
                        .transition(.opacity)
                }
                
                Spacer()
            }
            
            // 4. In-App Comment & Reply Input (Post to GitHub without browser)
            if isReplying {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Write a reply to @\(issue.author) directly on GitHub...", text: $replyCommentText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.black.opacity(0.40))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        
                        Button(action: {
                            let body = replyCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !body.isEmpty else { return }
                            isPosting = true
                            gh.postIssueComment(issueNumber: issue.number, body: body) { success, err in
                                isPosting = false
                                if success {
                                    replyCommentText = ""
                                    isReplying = false
                                    feedbackMsg = "Comment posted on GitHub!"
                                    state.appendLog("💬 [GitHub] Posted comment to Issue #\(issue.number)", .success)
                                } else {
                                    feedbackMsg = "Error: \(err)"
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isPosting {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text("Post")
                            }
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ColorTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPosting || replyCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.25))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(ColorTheme.panelDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
    }
}

// MARK: - Todo Card Row (Interactive Task List)
struct TodoCardRow: View {
    let todo: StudioTodoItem
    @ObservedObject var state: StudioState = .shared
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                state.toggleTodoItem(id: todo.id)
            }) {
                Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(todo.isDone ? ColorTheme.statusGreen : ColorTheme.secondaryGray)
            }
            .buttonStyle(.plain)
            
            Text(todo.title)
                .font(.system(size: 11, weight: todo.isDone ? .regular : .medium))
                .strikethrough(todo.isDone, color: ColorTheme.secondaryGray)
                .foregroundColor(todo.isDone ? ColorTheme.secondaryGray : .white)
                .lineLimit(2)
            
            Spacer()
            
            Text(todo.category)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .foregroundColor(ColorTheme.secondaryGray)
                .cornerRadius(3)
        }
        .padding(9)
        .background(ColorTheme.panelDark)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
    }
}

// MARK: - Commit Card Row (Monochrome)
struct CommitCardRow: View {
    let commit: GitHubCommitItem
    
    var body: some View {
        HStack(spacing: 10) {
            Text(commit.id)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .foregroundColor(.white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(commit.author) • \(commit.date)")
                    .font(.system(size: 9.5))
                    .foregroundColor(ColorTheme.secondaryGray)
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: commit.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.secondaryGray)
            }
            .buttonStyle(.plain)
            .help("View Commit on GitHub")
        }
        .padding(8)
        .background(ColorTheme.panelDark)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorTheme.panelBorder, lineWidth: 1)
        )
    }
}
