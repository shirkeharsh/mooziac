import XCTest
@testable import Mooziac

final class YTMClientSearchTests: XCTestCase {

    func testParseTopCardDirectVideo() {
        let json: [String: Any] = [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicCardShelfRenderer": [
                                                    "title": ["runs": [["text": "Shape of You"]]],
                                                    "subtitle": ["runs": [["text": "Video • Ed Sheeran • 6.7B views • 4:24"]]],
                                                    "onTap": [
                                                        "watchEndpoint": ["videoId": "JGwWNGJdvx8"]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let track = YTMClient.parseTopTrack(from: json)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.videoId, "JGwWNGJdvx8")
        XCTAssertEqual(track?.title, "Shape of You")
    }

    func testParseArtistCardWithTopSongs() {
        let json: [String: Any] = [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicCardShelfRenderer": [
                                                    "title": ["runs": [["text": "Queen"]]],
                                                    "subtitle": ["runs": [["text": "Artist • 97.7M monthly audience"]]],
                                                    "buttons": [
                                                        [
                                                            "buttonRenderer": [
                                                                "navigationEndpoint": [
                                                                    "watchEndpoint": [
                                                                        "videoId": "ignored",
                                                                        "playlistId": "RDAObHaAx"
                                                                    ]
                                                                ]
                                                            ]
                                                        ]
                                                    ],
                                                    "contents": [
                                                        [
                                                            "musicResponsiveListItemRenderer": [
                                                                "playlistItemData": ["videoId": "5CLpG1uspBQ"],
                                                                "flexColumns": [
                                                                    [
                                                                        "musicResponsiveListItemFlexColumnRenderer": [
                                                                            "text": ["runs": [["text": "I Want To Break Free"]]]
                                                                        ]
                                                                    ]
                                                                ]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let track = YTMClient.parseTopTrack(from: json)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.videoId, "5CLpG1uspBQ")
        XCTAssertEqual(track?.title, "I Want To Break Free")
    }

    func testParseShelfRenderer() {
        let json: [String: Any] = [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicShelfRenderer": [
                                                    "contents": [
                                                        [
                                                            "musicResponsiveListItemRenderer": [
                                                                "playlistItemData": ["videoId": "BciS5krYL80"],
                                                                "flexColumns": [
                                                                    [
                                                                        "musicResponsiveListItemFlexColumnRenderer": [
                                                                            "text": ["runs": [["text": "Hotel California"]]]
                                                                        ]
                                                                    ],
                                                                    [
                                                                        "musicResponsiveListItemFlexColumnRenderer": [
                                                                            "text": ["runs": [["text": "Eagles • Hotel California"]]]
                                                                        ]
                                                                    ]
                                                                ]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let track = YTMClient.parseTopTrack(from: json)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.videoId, "BciS5krYL80")
        XCTAssertEqual(track?.title, "Hotel California")
        XCTAssertEqual(track?.artist, "Eagles")
    }

    func testSkipPodcastInFavorOfShelfSong() {
        let json: [String: Any] = [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [
                        [
                            "tabRenderer": [
                                "content": [
                                    "sectionListRenderer": [
                                        "contents": [
                                            [
                                                "musicCardShelfRenderer": [
                                                    "title": ["runs": [["text": "Some Talk Show"]]],
                                                    "subtitle": ["runs": [["text": "Episode • 45 min"]]],
                                                    "onTap": [
                                                        "watchEndpoint": ["videoId": "podcast123"]
                                                    ]
                                                ]
                                            ],
                                            [
                                                "musicShelfRenderer": [
                                                    "contents": [
                                                        [
                                                            "musicResponsiveListItemRenderer": [
                                                                "playlistItemData": ["videoId": "song456"],
                                                                "flexColumns": [
                                                                    [
                                                                        "musicResponsiveListItemFlexColumnRenderer": [
                                                                            "text": ["runs": [["text": "Kesariya"]]]
                                                                        ]
                                                                    ],
                                                                    [
                                                                        "musicResponsiveListItemFlexColumnRenderer": [
                                                                            "text": ["runs": [["text": "Arijit Singh • Brahmastra"]]]
                                                                        ]
                                                                    ]
                                                                ]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let track = YTMClient.parseTopTrack(from: json)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.videoId, "song456")
        XCTAssertEqual(track?.title, "Kesariya")
        XCTAssertEqual(track?.artist, "Arijit Singh")
    }

    func testEmptyResponseReturnsNil() {
        let json: [String: Any] = [:]
        let track = YTMClient.parseTopTrack(from: json)
        XCTAssertNil(track)
    }
}
