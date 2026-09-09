import XCTest
@testable import Mooziac

final class URLFilterTests: XCTestCase {
    
    func testHTTPAndHTTPSLinks() {
        XCTAssertTrue(URLFilter.containsLink("https://music.youtube.com"))
        XCTAssertTrue(URLFilter.containsLink("http://example.com/stream"))
        XCTAssertTrue(URLFilter.containsLink("Check this out: https://spotify.com"))
    }
    
    func testMusicDomains() {
        XCTAssertTrue(URLFilter.containsLink("youtube.com/watch?v=123"))
        XCTAssertTrue(URLFilter.containsLink("music.youtube.com/playlist?list=456"))
        XCTAssertTrue(URLFilter.containsLink("youtu.be/abc123xyz"))
    }
    
    func testPlainTextWithoutLinks() {
        XCTAssertFalse(URLFilter.containsLink("Hello world!"))
        XCTAssertFalse(URLFilter.containsLink("Just a simple search query"))
        XCTAssertFalse(URLFilter.containsLink("The Weeknd - Blinding Lights"))
        XCTAssertFalse(URLFilter.containsLink(""))
        XCTAssertFalse(URLFilter.containsLink("   \n\t "))
    }
}
