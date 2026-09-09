import XCTest
@testable import Mooziac

final class DownloadManagerURLTests: XCTestCase {
    
    func testRawVideoID() {
        let id = "dQw4w9WgXcQ"
        XCTAssertEqual(DownloadManager.extractVideoID(from: id), "dQw4w9WgXcQ")
    }
    
    func testRawVideoIDWithWhitespace() {
        let id = "  dQw4w9WgXcQ \n"
        XCTAssertEqual(DownloadManager.extractVideoID(from: id), "dQw4w9WgXcQ")
    }
    
    func testStandardYouTubeWatchURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        XCTAssertEqual(DownloadManager.extractVideoID(from: url), "dQw4w9WgXcQ")
    }
    
    func testYouTubeMusicURLWithExtraParams() {
        let url = "https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RDAMVMdQw4w9WgXcQ"
        XCTAssertEqual(DownloadManager.extractVideoID(from: url), "dQw4w9WgXcQ")
    }
    
    func testShortYouTuBeURL() {
        let url = "https://youtu.be/dQw4w9WgXcQ"
        XCTAssertEqual(DownloadManager.extractVideoID(from: url), "dQw4w9WgXcQ")
    }
    
    func testEmbedURL() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ"
        XCTAssertEqual(DownloadManager.extractVideoID(from: url), "dQw4w9WgXcQ")
    }
    
    func testInvalidURLs() {
        XCTAssertNil(DownloadManager.extractVideoID(from: ""))
        XCTAssertNil(DownloadManager.extractVideoID(from: "   "))
        XCTAssertNil(DownloadManager.extractVideoID(from: "https://google.com"))
        XCTAssertNil(DownloadManager.extractVideoID(from: "https://youtube.com/feed/subscriptions"))
    }
}
