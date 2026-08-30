import Foundation
import AppKit

public struct StudioVersionInfo: Equatable {
    public var projectVersion: String = "1.0.4"
    public var projectBuild: String = "4"
    public var installedAppVersion: String = "1.0.4"
    public var installedAppBuild: String = "4"
    public var latestGitTag: String = "v1.0.3"
    public var latestGitHubReleaseTag: String = "v1.0.4"
    public var latestGitHubReleaseName: String = "Mooziac 1.0.4"
    public var latestGitHubReleaseDate: String = ""
    public var latestGitHubReleaseURL: String = "https://github.com/shirkeharsh/mooziac/releases"
    public var computedNextVersion: String = "1.0.5"
    public var computedNextTag: String = "v1.0.5"
    public var isFetching: Bool = false
    public var lastFetched: Date = Date()
    
    public init() {}
}

public final class StudioVersionManager {
    public static let shared = StudioVersionManager()
    
    public var repositoryOwner: String = "shirkeharsh"
    public var repositoryName: String = "mooziac"
    
    private let queue = DispatchQueue(label: "app.mooziac.studio.version", qos: .userInitiated)
    
    public init() {}
    
    public func fetchAllVersionInfo(workspacePath: String, completion: @escaping (StudioVersionInfo) -> Void) {
        queue.async {
            var info = StudioVersionInfo()
            info.isFetching = true
            
            // 1. Fetch Project Version from build_app.sh
            let (projVer, projBuild) = self.parseProjectVersion(workspacePath: workspacePath)
            info.projectVersion = projVer
            info.projectBuild = projBuild
            
            // 2. Fetch Installed App Version from ~/Applications/Mooziac.app or /Applications/Mooziac.app
            let (instVer, instBuild) = self.readInstalledAppVersion()
            info.installedAppVersion = instVer
            info.installedAppBuild = instBuild
            
            // 3. Fetch latest Git tag via git
            let gitTag = self.readLatestGitTag(workspacePath: workspacePath)
            if !gitTag.isEmpty {
                info.latestGitTag = gitTag
            }
            
            // 4. Compute next semantic version from highest detected version
            let baseVer = self.highestVersion(between: [projVer, instVer, gitTag.replacingOccurrences(of: "v", with: "")])
            info.computedNextVersion = self.bumpPatchVersion(baseVer)
            info.computedNextTag = "v\(info.computedNextVersion)"
            
            // 5. Fetch live GitHub Release API
            self.fetchGitHubLatestRelease { ghTag, ghName, ghDate, ghURL in
                if let ghTag = ghTag, !ghTag.isEmpty {
                    info.latestGitHubReleaseTag = ghTag
                    info.latestGitHubReleaseName = ghName ?? "Mooziac \(ghTag)"
                    info.latestGitHubReleaseDate = ghDate ?? ""
                    info.latestGitHubReleaseURL = ghURL ?? "https://github.com/\(self.repositoryOwner)/\(self.repositoryName)/releases"
                    
                    let newBase = self.highestVersion(between: [baseVer, ghTag.replacingOccurrences(of: "v", with: "")])
                    info.computedNextVersion = self.bumpPatchVersion(newBase)
                    info.computedNextTag = "v\(info.computedNextVersion)"
                }
                
                info.isFetching = false
                info.lastFetched = Date()
                
                DispatchQueue.main.async {
                    completion(info)
                }
            }
        }
    }
    
    private func parseProjectVersion(workspacePath: String) -> (version: String, build: String) {
        let scriptPath = "\(workspacePath)/build_app.sh"
        guard let content = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            return ("1.0.4", "4")
        }
        
        var version = "1.0.4"
        var build = "4"
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "APP_VERSION=") {
                let val = trimmed.replacingOccurrences(of: "APP_VERSION=", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"';"))
                if !val.isEmpty { version = val }
            } else if trimmed.starts(with: "APP_BUILD=") {
                let val = trimmed.replacingOccurrences(of: "APP_BUILD=", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"';"))
                if !val.isEmpty { build = val }
            }
        }
        
        return (version, build)
    }
    
    private func readInstalledAppVersion() -> (version: String, build: String) {
        let home = NSHomeDirectory()
        let candidatePaths = [
            "\(home)/Applications/Mooziac.app/Contents/Info.plist",
            "/Applications/Mooziac.app/Contents/Info.plist"
        ]
        
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
                let ver = dict["CFBundleShortVersionString"] as? String ?? ""
                let bld = dict["CFBundleVersion"] as? String ?? ""
                if !ver.isEmpty {
                    return (ver, bld.isEmpty ? "1" : bld)
                }
            }
        }
        
        return ("1.0.4", "4")
    }
    
    private func readLatestGitTag(workspacePath: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["tag", "--sort=-v:refname"]
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let tags = str.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return tags.first ?? "v1.0.3"
            }
        } catch {
            return "v1.0.3"
        }
        return "v1.0.3"
    }
    
    private func fetchGitHubLatestRelease(completion: @escaping (String?, String?, String?, String?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest") else {
            completion(nil, nil, nil, nil)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("MooziacStudio-VersionFetcher", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil, nil, nil, nil)
                return
            }
            
            let tagName = json["tag_name"] as? String
            let releaseName = json["name"] as? String
            let htmlURL = json["html_url"] as? String
            var publishedDate: String? = nil
            
            if let dateStr = json["published_at"] as? String {
                publishedDate = String(dateStr.prefix(10))
            }
            
            completion(tagName, releaseName, publishedDate, htmlURL)
        }.resume()
    }
    
    private func highestVersion(between versions: [String]) -> String {
        let clean = versions.map { $0.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return clean.max(by: { compareSemVer($0, $1) == .orderedAscending }) ?? "1.0.4"
    }
    
    private func compareSemVer(_ v1: String, _ v2: String) -> ComparisonResult {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(p1.count, p2.count) {
            let num1 = i < p1.count ? p1[i] : 0
            let num2 = i < p2.count ? p2[i] : 0
            if num1 < num2 { return .orderedAscending }
            if num1 > num2 { return .orderedDescending }
        }
        return .orderedSame
    }
    
    public func bumpAndApplyVersion(workspacePath: String) -> (newVersion: String, newBuild: String, tag: String) {
        let (currentVer, currentBuild) = parseProjectVersion(workspacePath: workspacePath)
        let nextVer = bumpPatchVersion(currentVer)
        let nextBuildInt = (Int(currentBuild) ?? 4) + 1
        let nextBuild = "\(nextBuildInt)"
        
        let scriptPath = "\(workspacePath)/build_app.sh"
        if let content = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
            var updated = content
            if let verRegex = try? NSRegularExpression(pattern: #"APP_VERSION="[^"]+""#) {
                updated = verRegex.stringByReplacingMatches(
                    in: updated,
                    range: NSRange(location: 0, length: updated.utf16.count),
                    withTemplate: "APP_VERSION=\"\(nextVer)\""
                )
            }
            if let buildRegex = try? NSRegularExpression(pattern: #"APP_BUILD="[^"]+""#) {
                updated = buildRegex.stringByReplacingMatches(
                    in: updated,
                    range: NSRange(location: 0, length: updated.utf16.count),
                    withTemplate: "APP_BUILD=\"\(nextBuild)\""
                )
            }
            try? updated.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        }
        
        return (nextVer, nextBuild, "v\(nextVer)")
    }
    
    public func getNextBumpPreview(workspacePath: String) -> (nextVer: String, nextBuild: String, tag: String) {
        let (currentVer, currentBuild) = parseProjectVersion(workspacePath: workspacePath)
        let nextVer = bumpPatchVersion(currentVer)
        let nextBuildInt = (Int(currentBuild) ?? 4) + 1
        return (nextVer, "\(nextBuildInt)", "v\(nextVer)")
    }
    
    private func bumpPatchVersion(_ ver: String) -> String {
        let parts = ver.split(separator: ".").compactMap { Int($0) }
        if parts.count >= 3 {
            return "\(parts[0]).\(parts[1]).\(parts[2] + 1)"
        } else if parts.count == 2 {
            return "\(parts[0]).\(parts[1]).1"
        } else if parts.count == 1 {
            return "\(parts[0]).0.1"
        }
        return "1.0.5"
    }
}
