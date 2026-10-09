import Foundation
import XCTest
@testable import Mooziac

final class PlaylistFileCodecTests: XCTestCase {
    func testJSONRoundTripPreservesUnicodeAndEscapedPaths() throws {
        let document = PlaylistFileCodec.Document(
            name: "Café / 夜",
            tracks: [
                PlaylistFileCodec.Track(path: "/Music/Québec/曲 \"live\".m4a", title: "夜の曲", artist: "Björk"),
                PlaylistFileCodec.Track(path: "/Music/second track.mp3", title: "Second", artist: "Artist")
            ]
        )

        let data = try PlaylistFileCodec.encode(document, as: .json)
        let decoded = try PlaylistFileCodec.decode(data, from: URL(fileURLWithPath: "/tmp/playlist.json"))

        XCTAssertEqual(decoded.document, document)
        XCTAssertEqual(decoded.skippedEntryCount, 0)
    }

    func testJSONResolvesRelativePathsAndSkipsNetworkEntries() throws {
        let json = """
        {
          "version": 1,
          "name": "Road",
          "tracks": [
            { "path": "disc/song.mp3", "title": "Song", "artist": "Artist" },
            { "path": "https://example.com/stream", "title": "Stream", "artist": "Web" }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try PlaylistFileCodec.decode(json, from: URL(fileURLWithPath: "/Users/me/Lists/road.json"))

        XCTAssertEqual(decoded.document.tracks, [
            PlaylistFileCodec.Track(path: "/Users/me/Lists/disc/song.mp3", title: "Song", artist: "Artist")
        ])
        XCTAssertEqual(decoded.skippedEntryCount, 1)
    }

    func testM3U8ReadsBOMCRLFCommentsRelativePathsAndDuplicateEntries() throws {
        let contents = """
        \u{feff}#EXTM3U
        #PLAYLIST:Night Drive
        # comment ignored
        #EXTINF:231,First song
        tracks/first song.flac
        #EXTINF:-1,First song again
        tracks/first song.flac
        https://example.com/stream
        """.replacingOccurrences(of: "\n", with: "\r\n")

        let decoded = try PlaylistFileCodec.decode(
            Data(contents.utf8),
            from: URL(fileURLWithPath: "/Users/me/Lists/night.m3u8")
        )

        XCTAssertEqual(decoded.document.name, "Night Drive")
        XCTAssertEqual(decoded.document.tracks, [
            PlaylistFileCodec.Track(path: "/Users/me/Lists/tracks/first song.flac", title: "First song"),
            PlaylistFileCodec.Track(path: "/Users/me/Lists/tracks/first song.flac", title: "First song again")
        ])
        XCTAssertEqual(decoded.skippedEntryCount, 1)
    }

    func testM3U8ExportIsUTF8AndIncludesPlaylistMetadata() throws {
        let document = PlaylistFileCodec.Document(
            name: "夜 Drive",
            tracks: [PlaylistFileCodec.Track(path: "/Music/夜 song.m4a", title: "Evening, live", artist: "Artist")]
        )

        let data = try PlaylistFileCodec.encode(document, as: .m3u8)
        let contents = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(contents.hasPrefix("#EXTM3U\n#PLAYLIST:夜 Drive\n"))
        XCTAssertTrue(contents.contains("#EXTINF:-1,Evening, live\n/Music/夜 song.m4a\n"))
    }

    func testJSONRejectsMalformedAndUnsupportedVersions() throws {
        let source = URL(fileURLWithPath: "/tmp/playlist.json")
        XCTAssertThrowsError(try PlaylistFileCodec.decode(Data("{".utf8), from: source))

        let unsupported = """
        { "version": 2, "name": "Road", "tracks": [] }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try PlaylistFileCodec.decode(unsupported, from: source)) { error in
            XCTAssertEqual(error as? PlaylistFileCodec.CodecError, .unsupportedVersion(2))
        }
    }

    func testM3U8RejectsInvalidUTF8AndDoesNotExportMultilinePaths() throws {
        XCTAssertThrowsError(try PlaylistFileCodec.decode(Data([0xff, 0xfe]), from: URL(fileURLWithPath: "/tmp/list.m3u8")))

        let document = PlaylistFileCodec.Document(
            name: "Playlist",
            tracks: [PlaylistFileCodec.Track(path: "/Music/first\nsecond.mp3")]
        )
        XCTAssertThrowsError(try PlaylistFileCodec.encode(document, as: .m3u8))
    }
}
