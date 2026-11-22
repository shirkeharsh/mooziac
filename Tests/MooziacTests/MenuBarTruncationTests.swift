import XCTest
@testable import Mooziac

final class MenuBarTruncationTests: XCTestCase {
    
    func testShortTitlesAreNotTruncated() {
        XCTAssertEqual(CenteredMenuBarLyricsWindowController.truncateTitle("Short Song"), "Short Song")
        XCTAssertEqual(CenteredMenuBarLyricsWindowController.truncateTitle("Exactly 30 Characters Long Song"), "Exactly 30 Characters Long Song")
        XCTAssertEqual(CenteredMenuBarLyricsWindowController.truncateTitle(""), "")
    }
    
    func testLongTitlesAreTruncatedWithEllipsis() {
        let longTitle = "This is a very long YouTube song title that takes up way too much space"
        let truncated = CenteredMenuBarLyricsWindowController.truncateTitle(longTitle)
        XCTAssertTrue(truncated.hasSuffix("..."))
        XCTAssertEqual(truncated.count, 30) // 27 chars + "..."
        XCTAssertEqual(truncated, "This is a very long YouTube...")
    }
    
    func testTrailingWhitespaceTrimmingBeforeEllipsis() {
        // 27th character followed by space
        let titleWithSpaceAtCutoff = "123456789012345678901234567 901234567890"
        let truncated = CenteredMenuBarLyricsWindowController.truncateTitle(titleWithSpaceAtCutoff)
        XCTAssertEqual(truncated, "123456789012345678901234567...")
    }

    func testCustomMaxLength() {
        let title = "Hello World From Mooziac"
        XCTAssertEqual(CenteredMenuBarLyricsWindowController.truncateTitle(title, maxLength: 10), "Hello W...")
    }
}
