import Foundation

public struct LRCWord {
    public let text: String
    public let startTime: Double
    public let endTime: Double
    public let weight: Double
}

public struct LRCLine {
    public let timestamp: Double // Line start timestamp in seconds
    public let text: String
    public let words: [LRCWord]
    
    public init(timestamp: Double, text: String, nextTimestamp: Double?) {
        self.timestamp = timestamp
        self.text = text
        
        let rawWords = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var computedWords: [LRCWord] = []
        
        if !rawWords.isEmpty {
            let lineEnd = nextTimestamp ?? (timestamp + 4.2)
            let lineDuration = max(0.4, lineEnd - timestamp)
            
            // Calculate acoustic weight per word (vowels in English/Hindi/Marathi take longer to sing)
            var weights: [Double] = []
            for w in rawWords {
                let vowelCount = w.reduce(0) { count, char in
                    let s = String(char).lowercased()
                    let isVowel = "aeiouáéíóúअआईईउऊएऐओऔ".contains(s)
                    return count + (isVowel ? 2 : 1)
                }
                weights.append(Double(max(1, vowelCount)))
            }
            let totalWeight = weights.reduce(0, +)
            
            var currentStart = timestamp
            for (i, w) in rawWords.enumerated() {
                let share = (weights[i] / totalWeight) * lineDuration
                let wEnd = currentStart + share
                computedWords.append(LRCWord(text: w, startTime: currentStart, endTime: wEnd, weight: weights[i]))
                currentStart = wEnd
            }
        }
        
        self.words = computedWords
    }
}

public final class SyncedLyricsParser {
    public static func parse(lrcText: String) -> [LRCLine] {
        var rawEntries: [(Double, String)] = []
        let rawLines = lrcText.components(separatedBy: .newlines)
        
        let pattern = "\\[(\\d+):(\\d+)(?:[\\.:](\\d+))?\\](.*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        for raw in rawLines {
            let nsString = raw as NSString
            let matches = regex?.matches(in: raw, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
            
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let minRange = match.range(at: 1)
                let secRange = match.range(at: 2)
                guard minRange.location != NSNotFound, secRange.location != NSNotFound else { continue }
                
                let minStr = nsString.substring(with: minRange)
                let secStr = nsString.substring(with: secRange)
                
                var msFraction: Double = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let msStr = nsString.substring(with: match.range(at: 3))
                    if let ms = Double(msStr) {
                        if msStr.count == 1 {
                            msFraction = ms / 10.0
                        } else if msStr.count == 3 {
                            msFraction = ms / 1000.0
                        } else {
                            msFraction = ms / 100.0
                        }
                    }
                }
                
                var lyricText = ""
                if match.numberOfRanges >= 5 && match.range(at: 4).location != NSNotFound {
                    lyricText = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                }
                
                if let mins = Double(minStr), let secs = Double(secStr) {
                    let totalSeconds = (mins * 60.0) + secs + msFraction
                    if !lyricText.isEmpty {
                        rawEntries.append((totalSeconds, lyricText))
                    }
                }
            }
        }
        
        rawEntries.sort { $0.0 < $1.0 }
        
        var resultLines: [LRCLine] = []
        for i in 0..<rawEntries.count {
            let entry = rawEntries[i]
            let nextTs = (i + 1 < rawEntries.count) ? rawEntries[i + 1].0 : nil
            resultLines.append(LRCLine(timestamp: entry.0, text: entry.1, nextTimestamp: nextTs))
        }
        
        return resultLines
    }
    
    public static func activeLineAndWord(at currentTime: Double, in lines: [LRCLine], leadOffset: Double = 0.35) -> (line: LRCLine, lineIndex: Int, activeWordIndex: Int, activeWordProgress: Double)? {
        guard !lines.isEmpty else { return nil }
        
        let effectiveTime = currentTime + leadOffset
        
        var foundIndex = -1
        for (i, line) in lines.enumerated() {
            if effectiveTime >= line.timestamp {
                foundIndex = i
            } else {
                break
            }
        }
        
        guard foundIndex >= 0 && foundIndex < lines.count else { return nil }
        let line = lines[foundIndex]
        
        guard !line.words.isEmpty else {
            return (line, foundIndex, 0, 0.0)
        }
        
        var activeWordIdx = line.words.count - 1
        var wordProgress = 1.0
        
        for (wIdx, word) in line.words.enumerated() {
            if effectiveTime >= word.startTime && effectiveTime <= word.endTime {
                activeWordIdx = wIdx
                let wordDur = max(0.05, word.endTime - word.startTime)
                wordProgress = max(0.0, min(1.0, (effectiveTime - word.startTime) / wordDur))
                break
            } else if effectiveTime < word.startTime {
                if wIdx > 0 {
                    activeWordIdx = wIdx - 1
                } else {
                    activeWordIdx = 0
                }
                wordProgress = 0.0
                break
            }
        }
        
        return (line, foundIndex, activeWordIdx, wordProgress)
    }
}
