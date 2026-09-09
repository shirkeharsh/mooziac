import XCTest
@testable import Mooziac

final class PlaylistReorderTests: XCTestCase {

    func testDatabaseReorderPlaylistItems() {
        guard let testPlaylistID = LocalDatabaseManager.shared.createPlaylist(name: "Reorder Test") else {
            XCTFail("Failed to create playlist")
            return
        }

        let itemA = PlaylistItemRecord(
            id: "item_A",
            playlistID: testPlaylistID,
            sortOrder: 0,
            refType: "yt",
            refID: "vid_A",
            ytVideoId: "vid_A",
            title: "Song A"
        )
        let itemB = PlaylistItemRecord(
            id: "item_B",
            playlistID: testPlaylistID,
            sortOrder: 1,
            refType: "yt",
            refID: "vid_B",
            ytVideoId: "vid_B",
            title: "Song B"
        )
        let itemC = PlaylistItemRecord(
            id: "item_C",
            playlistID: testPlaylistID,
            sortOrder: 2,
            refType: "yt",
            refID: "vid_C",
            ytVideoId: "vid_C",
            title: "Song C"
        )

        LocalDatabaseManager.shared.appendPlaylistItem(itemA)
        LocalDatabaseManager.shared.appendPlaylistItem(itemB)
        LocalDatabaseManager.shared.appendPlaylistItem(itemC)

        let initial = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: testPlaylistID)
        XCTAssertEqual(initial.map { $0.id }, ["item_A", "item_B", "item_C"])

        // Move item_C up to index 1 (between A and B)
        LocalDatabaseManager.shared.reorderPlaylistItems(playlistID: testPlaylistID, orderedItemIDs: ["item_A", "item_C", "item_B"])

        var reordered = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: testPlaylistID)
        XCTAssertEqual(reordered.map { $0.id }, ["item_A", "item_C", "item_B"])

        // Move item_B to top
        LocalDatabaseManager.shared.reorderPlaylistItems(playlistID: testPlaylistID, orderedItemIDs: ["item_B", "item_A", "item_C"])

        reordered = LocalDatabaseManager.shared.fetchPlaylistItems(playlistID: testPlaylistID)
        XCTAssertEqual(reordered.map { $0.id }, ["item_B", "item_A", "item_C"])

        // Cleanup
        LocalDatabaseManager.shared.deletePlaylist(id: testPlaylistID)
    }

    func testActiveContextIndexUpdatedWhenAdjacentSongMoved() {
        let testPlaylistID = "test_active_ctx_fixture"

        let itemA = PlaylistItemRecord(
            id: "ctx_item_A",
            playlistID: testPlaylistID,
            sortOrder: 0,
            refType: "yt",
            refID: "vid_A",
            ytVideoId: "vid_A",
            title: "Track A"
        )
        let itemB = PlaylistItemRecord(
            id: "ctx_item_B",
            playlistID: testPlaylistID,
            sortOrder: 1,
            refType: "yt",
            refID: "vid_B",
            ytVideoId: "vid_B",
            title: "Track B"
        )
        let itemC = PlaylistItemRecord(
            id: "ctx_item_C",
            playlistID: testPlaylistID,
            sortOrder: 2,
            refType: "yt",
            refID: "vid_C",
            ytVideoId: "vid_C",
            title: "Track C"
        )

        let items = [itemA, itemB, itemC]
        let context = PlaylistManager.ActivePlaylistPlaybackContext(
            playlistID: testPlaylistID,
            items: items,
            currentIndex: 1, // Currently playing Track B
            localQueue: [],
            localQueueIndexByItemID: [:]
        )
        PlaylistManager.shared.setActiveContextForTesting(context)

        XCTAssertNotNil(PlaylistManager.shared.activeContext)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 1)

        // Reorder: Move item C up before item B: new order [itemA, itemC, itemB]
        // Track B is now at index 2. The activeContext must smoothly track Track B to index 2.
        PlaylistManager.shared.reorderItems(playlistID: testPlaylistID, orderedItemIDs: ["ctx_item_A", "ctx_item_C", "ctx_item_B"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 2)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[2].id, "ctx_item_B")

        PlaylistManager.shared.clearActiveContext()
    }

    func testActiveContextIndexUpdatedWhenPlayingSongMovedUp() {
        let testPlaylistID = "test_active_ctx_fixture_2"

        let itemA = PlaylistItemRecord(
            id: "ctx_item_A",
            playlistID: testPlaylistID,
            sortOrder: 0,
            refType: "yt",
            refID: "vid_A",
            ytVideoId: "vid_A",
            title: "Track A"
        )
        let itemB = PlaylistItemRecord(
            id: "ctx_item_B",
            playlistID: testPlaylistID,
            sortOrder: 1,
            refType: "yt",
            refID: "vid_B",
            ytVideoId: "vid_B",
            title: "Track B"
        )
        let itemC = PlaylistItemRecord(
            id: "ctx_item_C",
            playlistID: testPlaylistID,
            sortOrder: 2,
            refType: "yt",
            refID: "vid_C",
            ytVideoId: "vid_C",
            title: "Track C"
        )

        let items = [itemA, itemB, itemC]
        let context = PlaylistManager.ActivePlaylistPlaybackContext(
            playlistID: testPlaylistID,
            items: items,
            currentIndex: 1, // Currently playing Track B
            localQueue: [],
            localQueueIndexByItemID: [:]
        )
        PlaylistManager.shared.setActiveContextForTesting(context)

        // Move playing track B up to index 0: new order [itemB, itemA, itemC]
        PlaylistManager.shared.reorderItems(playlistID: testPlaylistID, orderedItemIDs: ["ctx_item_B", "ctx_item_A", "ctx_item_C"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 0)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[0].id, "ctx_item_B")

        PlaylistManager.shared.clearActiveContext()
    }

    func testLikedSongsPlaybackAndReorderAnchor() {
        let r1 = LikedSongRecord(videoId: "v1", title: "Liked 1", artist: "Artist 1")
        let r2 = LikedSongRecord(videoId: "v2", title: "Liked 2", artist: "Artist 2")
        let r3 = LikedSongRecord(videoId: "v3", title: "Liked 3", artist: "Artist 3")

        PlaylistManager.shared.startLikedSongsPlayback(records: [r1, r2, r3], startingAt: "v1", shuffle: false)

        guard let ctx = PlaylistManager.shared.activeContext else {
            XCTFail("activeContext should not be nil")
            return
        }
        XCTAssertEqual(ctx.playlistID, "liked_songs")
        XCTAssertEqual(ctx.currentIndex, 0)
        XCTAssertEqual(PlaylistManager.shared.currentAnchorTrackID, "v1")

        // User drags v3 between v1 and v2: [v1, v3, v2]
        PlaylistManager.shared.reorderItems(playlistID: "liked_songs", orderedItemIDs: ["v1", "v3", "v2"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 0)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[0].id, "v1")
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[1].id, "v3")

        // User drags playing track v1 to bottom: [v3, v2, v1]
        PlaylistManager.shared.reorderItems(playlistID: "liked_songs", orderedItemIDs: ["v3", "v2", "v1"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 2)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[2].id, "v1")

        PlaylistManager.shared.clearActiveContext()
    }

    func testDownloadsPlaybackAndReorderAnchor() {
        let p1 = "/tmp/mooziac_test_d1.mp3"
        let p2 = "/tmp/mooziac_test_d2.mp3"
        let p3 = "/tmp/mooziac_test_d3.mp3"
        FileManager.default.createFile(atPath: p1, contents: Data("test".utf8))
        FileManager.default.createFile(atPath: p2, contents: Data("test".utf8))
        FileManager.default.createFile(atPath: p3, contents: Data("test".utf8))
        defer {
            try? FileManager.default.removeItem(atPath: p1)
            try? FileManager.default.removeItem(atPath: p2)
            try? FileManager.default.removeItem(atPath: p3)
        }

        let t1 = LocalTrack(id: "d1", title: "Download 1", artist: "Artist 1", fileURL: URL(fileURLWithPath: p1))
        let t2 = LocalTrack(id: "d2", title: "Download 2", artist: "Artist 2", fileURL: URL(fileURLWithPath: p2))
        let t3 = LocalTrack(id: "d3", title: "Download 3", artist: "Artist 3", fileURL: URL(fileURLWithPath: p3))

        PlaylistManager.shared.startDownloadsPlayback(tracks: [t1, t2, t3], startingAt: "d1", shuffle: false)

        guard let ctx = PlaylistManager.shared.activeContext else {
            XCTFail("activeContext should not be nil")
            return
        }
        XCTAssertEqual(ctx.playlistID, "downloads")
        XCTAssertEqual(ctx.currentIndex, 0)
        XCTAssertEqual(PlaylistManager.shared.currentAnchorTrackID, "d1")

        // User drags d3 between d1 and d2: [d1, d3, d2]
        PlaylistManager.shared.reorderItems(playlistID: "downloads", orderedItemIDs: ["d1", "d3", "d2"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 0)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[0].id, "d1")
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[1].id, "d3")

        // User drags playing track d1 to position 1: [d3, d1, d2]
        PlaylistManager.shared.reorderItems(playlistID: "downloads", orderedItemIDs: ["d3", "d1", "d2"])

        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 1)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.items[1].id, "d1")

        PlaylistManager.shared.clearActiveContext()
    }
}
