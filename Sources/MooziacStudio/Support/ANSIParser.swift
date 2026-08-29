import SwiftUI

public struct ConsoleLogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let text: String
    public let type: LogType
    
    public enum LogType: Equatable {
        case standard
        case success
        case warning
        case error
        case command
        case info
    }
    
    public init(text: String, type: LogType = .standard) {
        self.timestamp = Date()
        self.text = text
        self.type = type
    }
}

public enum ANSIParser {
    public static func parse(_ raw: String) -> (cleanText: String, type: ConsoleLogEntry.LogType) {
        let ansiRegex = try? NSRegularExpression(pattern: "\\x1B\\[[0-9;]*[a-zA-Z]", options: [])
        let range = NSRange(location: 0, length: raw.utf16.count)
        let clean = ansiRegex?.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: "") ?? raw
        
        let trimmed = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("❌") || trimmed.contains("Error:") || trimmed.contains("FAILED") || trimmed.contains("fatal:") {
            return (clean, .error)
        } else if trimmed.contains("✅") || trimmed.contains("SUCCESS") || trimmed.contains("succeeded") {
            return (clean, .success)
        } else if trimmed.contains("⚠️") || trimmed.contains("Warning:") || trimmed.contains("WARN") {
            return (clean, .warning)
        } else if trimmed.hasPrefix("$ ") || trimmed.hasPrefix("==>") || trimmed.contains("Running:") {
            return (clean, .command)
        } else if trimmed.contains("🚀") || trimmed.contains("📦") || trimmed.contains("🌐") || trimmed.contains("🔨") {
            return (clean, .info)
        }
        
        return (clean, .standard)
    }
}
