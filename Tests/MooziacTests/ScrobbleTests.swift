import XCTest
@testable import Mooziac

final class ScrobbleTests: XCTestCase {

    func testLastFMSignatureMatchesKnownVector() {
        // md5("api_keyxxxxmethodauth.getSessiontokenyyyy" + "zzzz")
        let params = ["method": "auth.getSession", "token": "yyyy", "api_key": "xxxx", "format": "json"]
        XCTAssertEqual(LastFMService.signature(for: params, secret: "zzzz"),
                       "d3be358e96cb2926e940514f19db6adf")
    }

    func testRequiredListenTime() {
        XCTAssertNil(ScrobbleRules.requiredListenTime(duration: 0))
        XCTAssertNil(ScrobbleRules.requiredListenTime(duration: 29))
        XCTAssertEqual(ScrobbleRules.requiredListenTime(duration: 30)!, 15, accuracy: 0.01)
        XCTAssertEqual(ScrobbleRules.requiredListenTime(duration: 200)!, 100, accuracy: 0.01)
        XCTAssertEqual(ScrobbleRules.requiredListenTime(duration: 900)!, 240, accuracy: 0.01)
    }

    func testTitleCleaning() {
        let r = ScrobbleRules.cleanedMetadata(title: "Starboy (Official Music Video) ft. Daft Punk", artist: "The Weeknd - Topic")
        XCTAssertEqual(r?.title, "Starboy")
        XCTAssertEqual(r?.artist, "The Weeknd")
    }

    func testEmptyMetadataIsRejected() {
        XCTAssertNil(ScrobbleRules.cleanedMetadata(title: "", artist: "Someone"))
        XCTAssertNil(ScrobbleRules.cleanedMetadata(title: "Song", artist: "  "))
    }
}
