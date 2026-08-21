import Foundation

struct URLFilter {
    static func containsLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        
        // 1. Direct URL schemes and prefixes
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") || lower.hasPrefix("ftp://") {
            return true
        }
        
        // 2. Popular music and video domain patterns
        if lower.contains("youtube.com/") || lower.contains("youtu.be/") || lower.contains("music.youtube.com/") || lower.contains("spotify.com/") || lower.contains("apple.com/") {
            return true
        }
        
        // 3. Robust NSDataDetector link detection
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let matches = detector.matches(in: trimmed, options: [], range: range)
            for match in matches {
                if match.resultType == .link {
                    if let url = match.url, url.scheme != nil || lower.contains(".com") || lower.contains(".org") || lower.contains(".net") || lower.contains(".io") || lower.contains(".be") || lower.contains(".co") {
                        return true
                    }
                }
            }
        }
        
        return false
    }
}
