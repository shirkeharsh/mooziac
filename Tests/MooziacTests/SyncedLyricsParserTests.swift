import XCTest
@testable import Mooziac

final class SyncedLyricsParserTests: XCTestCase {
    
    func testStandardTimestampParsing() {
        let lrc = """
        [00:01.00]First line
        [00:05.50]Second line with more words
        [00:10.00]Third line
        """
        
        let lines = SyncedLyricsParser.parse(lrcText: lrc)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].timestamp, 1.0, accuracy: 0.01)
        XCTAssertEqual(lines[0].text, "First line")
        XCTAssertEqual(lines[1].timestamp, 5.5, accuracy: 0.01)
        XCTAssertEqual(lines[1].text, "Second line with more words")
        XCTAssertEqual(lines[2].timestamp, 10.0, accuracy: 0.01)
    }
    
    func testWordSegmentationAndWeights() {
        let lrc = "[00:00.00]Hello world"
        let lines = SyncedLyricsParser.parse(lrcText: lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].words.count, 2)
        XCTAssertEqual(lines[0].words[0].text, "Hello")
        XCTAssertEqual(lines[0].words[1].text, "world")
        XCTAssertGreaterThan(lines[0].words[1].endTime, lines[0].words[0].startTime)
    }
    
    func testMetadataTagsIgnored() {
        let lrc = """
        [ti:Test Title]
        [ar:Test Artist]
        [al:Test Album]
        [00:02.00]Actual lyric line
        """
        
        let lines = SyncedLyricsParser.parse(lrcText: lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Actual lyric line")
    }
    
    func testEmptyInput() {
        let lines = SyncedLyricsParser.parse(lrcText: "")
        XCTAssertTrue(lines.isEmpty)
        
        let whitespaceOnly = SyncedLyricsParser.parse(lrcText: "   \n\n\t  ")
        XCTAssertTrue(whitespaceOnly.isEmpty)
    }
    
    func testOutOfOrderTimestampsAndColonDelimiter() {
        let lrc = """
        [00:10:50]Second lyric
        [00:02.10]First lyric
        """
        let lines = SyncedLyricsParser.parse(lrcText: lrc)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First lyric")
        XCTAssertEqual(lines[0].timestamp, 2.10, accuracy: 0.01)
        XCTAssertEqual(lines[1].text, "Second lyric")
        XCTAssertEqual(lines[1].timestamp, 10.50, accuracy: 0.01)
    }
}
