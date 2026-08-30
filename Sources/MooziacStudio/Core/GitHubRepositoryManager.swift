import Foundation
import AppKit

public struct GitHubRepoStats: Equatable, Codable {
    public var starsCount: Int = 9
    public var forksCount: Int = 2
    public var openIssuesCount: Int = 1
    public var watchersCount: Int = 9
    public var totalDownloadsCount: Int = 14
    public var lastPushedDate: String = "2026-08-29"
    public var defaultBranch: String = "main"
    public var repoURL: String = "https://github.com/shirkeharsh/mooziac"
    
    public init(starsCount: Int = 9, forksCount: Int = 2, openIssuesCount: Int = 1, watchersCount: Int = 9, totalDownloadsCount: Int = 14, lastPushedDate: String = "2026-08-29", defaultBranch: String = "main", repoURL: String = "https://github.com/shirkeharsh/mooziac") {
        self.starsCount = starsCount
        self.forksCount = forksCount
        self.openIssuesCount = openIssuesCount
        self.watchersCount = watchersCount
        self.totalDownloadsCount = totalDownloadsCount
        self.lastPushedDate = lastPushedDate
        self.defaultBranch = defaultBranch
        self.repoURL = repoURL
    }
}

public struct GitHubIssueItem: Identifiable, Equatable, Codable {
    public let id: Int
    public let number: Int
    public let title: String
    public let author: String
    public let state: String
    public let labels: [String]
    public let createdAt: String
    public let commentsCount: Int
    public let htmlUrl: String
    public let isPullRequest: Bool
    
    public init(id: Int, number: Int, title: String, author: String, state: String, labels: [String], createdAt: String, commentsCount: Int, htmlUrl: String, isPullRequest: Bool) {
        self.id = id
        self.number = number
        self.title = title
        self.author = author
        self.state = state
        self.labels = labels
        self.createdAt = createdAt
        self.commentsCount = commentsCount
        self.htmlUrl = htmlUrl
        self.isPullRequest = isPullRequest
    }
}

public struct GitHubCommitItem: Identifiable, Equatable, Codable {
    public let id: String
    public let message: String
    public let author: String
    public let date: String
    public let url: String
    
    public init(id: String, message: String, author: String, date: String, url: String) {
        self.id = id
        self.message = message
        self.author = author
        self.date = date
        self.url = url
    }
}

public final class GitHubRepositoryManager: ObservableObject {
    public static let shared = GitHubRepositoryManager()
    
    public let owner = "shirkeharsh"
    public let repo = "mooziac"
    
    @Published public var stats: GitHubRepoStats = GitHubRepoStats()
    @Published public var issues: [GitHubIssueItem] = [
        GitHubIssueItem(
            id: 5283506433,
            number: 1,
            title: "On screen rendering problem…",
            author: "bledu",
            state: "open",
            labels: [],
            createdAt: "2026-08-29",
            commentsCount: 1,
            htmlUrl: "https://github.com/shirkeharsh/mooziac/issues/1",
            isPullRequest: false
        )
    ]
    @Published public var recentCommits: [GitHubCommitItem] = []
    @Published public var isLoading: Bool = false
    @Published public var lastUpdated: Date = Date()
    
    private let queue = DispatchQueue(label: "app.mooziac.studio.github", qos: .userInitiated)
    private let cacheKeyStats = "mooziac_studio_gh_stats"
    private var syncTimer: Timer?
    
    public init() {
        loadCachedData()
        refreshAll()
        startAutoSyncTimer()
    }
    
    private func startAutoSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.syncTimer?.invalidate()
            self?.syncTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
                self?.refreshAll()
            }
        }
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: cacheKeyStats),
           let cached = try? JSONDecoder().decode(GitHubRepoStats.self, from: data),
           cached.starsCount > 0 {
            self.stats = cached
        }
    }
    
    private func saveCachedData(_ stats: GitHubRepoStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: cacheKeyStats)
        }
    }
    
    public func refreshAll() {
        DispatchQueue.main.async { self.isLoading = true }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Try fast authenticated gh CLI first
            let ghStats = self.fetchStatsViaGhCLI()
            let ghIssues = self.fetchIssuesViaGhCLI()
            let ghCommits = self.fetchCommitsViaGhCLI()
            
            if let ghStats = ghStats, ghStats.starsCount > 0 {
                DispatchQueue.main.async {
                    self.stats = ghStats
                    self.saveCachedData(ghStats)
                    if !ghIssues.isEmpty { self.issues = ghIssues }
                    if !ghCommits.isEmpty { self.recentCommits = ghCommits }
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
                return
            }
            
            // Step 2: Fallback to URLSession
            let group = DispatchGroup()
            var fetchedStats = self.stats
            var fetchedIssues: [GitHubIssueItem] = self.issues
            var fetchedCommits: [GitHubCommitItem] = self.recentCommits
            
            group.enter()
            self.fetchRepoInfoREST { stats in
                if let stats = stats, stats.starsCount > 0 {
                    fetchedStats = stats
                }
                group.leave()
            }
            
            group.enter()
            self.fetchIssuesREST { items in
                if !items.isEmpty {
                    fetchedIssues = items
                }
                group.leave()
            }
            
            group.enter()
            self.fetchCommitsREST { commits in
                if !commits.isEmpty {
                    fetchedCommits = commits
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                // Ensure stats never drop to zero
                if fetchedStats.starsCount == 0 && self.stats.starsCount > 0 {
                    fetchedStats.starsCount = self.stats.starsCount
                }
                self.stats = fetchedStats
                self.saveCachedData(fetchedStats)
                self.issues = fetchedIssues
                self.recentCommits = fetchedCommits
                self.isLoading = false
                self.lastUpdated = Date()
            }
        }
    }
    
    // MARK: - Method 1: Local Authenticated gh CLI
    private func fetchStatsViaGhCLI() -> GitHubRepoStats? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(owner)/\(repo)"]
        
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin"
        process.environment = env
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stars = json["stargazers_count"] as? Int else { return nil }
            
            var s = GitHubRepoStats()
            s.starsCount = stars
            s.forksCount = json["forks_count"] as? Int ?? self.stats.forksCount
            s.openIssuesCount = json["open_issues_count"] as? Int ?? self.stats.openIssuesCount
            s.watchersCount = json["watchers_count"] as? Int ?? self.stats.watchersCount
            s.totalDownloadsCount = self.fetchDownloadsViaGhCLI()
            if s.totalDownloadsCount == 0 && self.stats.totalDownloadsCount > 0 {
                s.totalDownloadsCount = self.stats.totalDownloadsCount
            }
            s.defaultBranch = json["default_branch"] as? String ?? "main"
            s.repoURL = json["html_url"] as? String ?? "https://github.com/\(self.owner)/\(self.repo)"
            if let pushedStr = json["pushed_at"] as? String {
                s.lastPushedDate = String(pushedStr.prefix(10))
            }
            return s
        } catch {
            return nil
        }
    }
    
    private func fetchDownloadsViaGhCLI() -> Int {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(owner)/\(repo)/releases"]
        
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin"
        process.environment = env
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parseReleasesDownloadCount(data: data)
        } catch {
            return 0
        }
    }
    
    private func parseReleasesDownloadCount(data: Data) -> Int {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return 0
        }
        var total = 0
        for rel in arr {
            if let assets = rel["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let count = asset["download_count"] as? Int {
                        total += count
                    }
                }
            }
        }
        return total
    }
    
    public func postIssueComment(issueNumber: Int, body: String, completion: @escaping (Bool, String) -> Void) {
        let process = Process()
        let pipeOut = Pipe()
        let pipeErr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "comment", "\(issueNumber)", "--repo", "\(owner)/\(repo)", "--body", body]
        
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin"
        process.environment = env
        process.standardOutput = pipeOut
        process.standardError = pipeErr
        
        queue.async {
            do {
                try process.run()
                process.waitUntilExit()
                let success = process.terminationStatus == 0
                let errData = pipeErr.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if success {
                        self.refreshAll()
                    }
                    completion(success, errMsg)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    private func fetchIssuesViaGhCLI() -> [GitHubIssueItem] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(owner)/\(repo)/issues?state=all&per_page=15"]
        
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin"
        process.environment = env
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parseIssuesJSON(data: data)
        } catch {
            return []
        }
    }
    
    private func fetchCommitsViaGhCLI() -> [GitHubCommitItem] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(owner)/\(repo)/commits?per_page=8"]
        
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:/usr/bin:/bin"
        process.environment = env
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parseCommitsJSON(data: data)
        } catch {
            return []
        }
    }
    
    // MARK: - Method 2: REST Fallback
    private func fetchRepoInfoREST(completion: @escaping (GitHubRepoStats?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stars = json["stargazers_count"] as? Int,
                  let self = self else {
                completion(nil)
                return
            }
            
            var s = GitHubRepoStats()
            s.starsCount = stars
            s.forksCount = json["forks_count"] as? Int ?? self.stats.forksCount
            s.openIssuesCount = json["open_issues_count"] as? Int ?? self.stats.openIssuesCount
            s.watchersCount = json["watchers_count"] as? Int ?? self.stats.watchersCount
            s.defaultBranch = json["default_branch"] as? String ?? "main"
            s.repoURL = json["html_url"] as? String ?? "https://github.com/\(self.owner)/\(self.repo)"
            if let pushedStr = json["pushed_at"] as? String {
                s.lastPushedDate = String(pushedStr.prefix(10))
            }
            
            // Also fetch release downloads via REST
            self.fetchReleasesDownloadsREST { downloads in
                s.totalDownloadsCount = downloads > 0 ? downloads : self.stats.totalDownloadsCount
                completion(s)
            }
        }.resume()
    }
    
    private func fetchReleasesDownloadsREST(completion: @escaping (Int) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases") else {
            completion(0)
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data, let self = self else {
                completion(0)
                return
            }
            completion(self.parseReleasesDownloadCount(data: data))
        }.resume()
    }
    
    private func fetchIssuesREST(completion: @escaping ([GitHubIssueItem]) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues?state=all&per_page=10") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data, let self = self else {
                completion([])
                return
            }
            completion(self.parseIssuesJSON(data: data))
        }.resume()
    }
    
    private func fetchCommitsREST(completion: @escaping ([GitHubCommitItem]) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=6") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data, let self = self else {
                completion([])
                return
            }
            completion(self.parseCommitsJSON(data: data))
        }.resume()
    }
    
    // MARK: - Parsers
    private func parseIssuesJSON(data: Data) -> [GitHubIssueItem] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var list: [GitHubIssueItem] = []
        for item in arr {
            guard let id = item["id"] as? Int,
                  let num = item["number"] as? Int,
                  let title = item["title"] as? String else { continue }
            
            let state = item["state"] as? String ?? "open"
            let userDict = item["user"] as? [String: Any]
            let author = userDict?["login"] as? String ?? "user"
            let comments = item["comments"] as? Int ?? 0
            let htmlUrl = item["html_url"] as? String ?? ""
            let isPR = item["pull_request"] != nil
            
            var labelNames: [String] = []
            if let labelsArr = item["labels"] as? [[String: Any]] {
                for l in labelsArr {
                    if let name = l["name"] as? String {
                        labelNames.append(name)
                    }
                }
            }
            
            var createdStr = ""
            if let rawDate = item["created_at"] as? String {
                createdStr = String(rawDate.prefix(10))
            }
            
            list.append(GitHubIssueItem(
                id: id,
                number: num,
                title: title,
                author: author,
                state: state,
                labels: labelNames,
                createdAt: createdStr,
                commentsCount: comments,
                htmlUrl: htmlUrl,
                isPullRequest: isPR
            ))
        }
        return list
    }
    
    private func parseCommitsJSON(data: Data) -> [GitHubCommitItem] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var list: [GitHubCommitItem] = []
        for item in arr {
            guard let sha = item["sha"] as? String else { continue }
            let shortSha = String(sha.prefix(7))
            let commitObj = item["commit"] as? [String: Any]
            let message = (commitObj?["message"] as? String ?? "").components(separatedBy: .newlines).first ?? "Commit"
            let authorObj = commitObj?["author"] as? [String: Any]
            let author = authorObj?["name"] as? String ?? "harsh"
            let rawDate = authorObj?["date"] as? String ?? ""
            let date = String(rawDate.prefix(10))
            let htmlUrl = item["html_url"] as? String ?? ""
            
            list.append(GitHubCommitItem(
                id: shortSha,
                message: message,
                author: author,
                date: date,
                url: htmlUrl
            ))
        }
        return list
    }
}
