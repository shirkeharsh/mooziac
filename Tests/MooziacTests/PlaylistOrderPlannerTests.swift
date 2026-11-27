import XCTest
@testable import Mooziac

final class PlaylistOrderPlannerTests: XCTestCase {

    func testPlannerUsesFreshSnapshotAfterNewTrackIsAdded() {
        let local = [item("b", video: "video-b", order: 0), item("a", video: "video-a", order: 1)]
        let beforeAdd = [track("video-a", set: "set-a")]
        let afterAdd = [track("video-a", set: "set-a"), track("video-b", set: "set-b")]

        XCTAssertNil(PlaylistOrderPlanner.moveActions(localItems: local, remoteTracks: beforeAdd))
        let actions = PlaylistOrderPlanner.moveActions(localItems: local, remoteTracks: afterAdd)
        XCTAssertEqual(actions?.count, 1)
        XCTAssertEqual(actions?.first?["setVideoId"] as? String, "set-b")
        XCTAssertEqual(actions?.first?["movedSetVideoIdSuccessor"] as? String, "set-a")
    }

    func testPlannerKeepsDuplicateVideoRowsDistinctBySetVideoId() {
        let local = [
            item("second", video: "same-video", set: "set-second", order: 0),
            item("first", video: "same-video", set: "set-first", order: 1)
        ]
        let remote = [track("same-video", set: "set-first"), track("same-video", set: "set-second")]

        let actions = PlaylistOrderPlanner.moveActions(localItems: local, remoteTracks: remote)
        XCTAssertEqual(actions?.count, 1)
        XCTAssertEqual(actions?.first?["setVideoId"] as? String, "set-second")
        XCTAssertEqual(actions?.first?["movedSetVideoIdSuccessor"] as? String, "set-first")
    }

    func testPlannerDoesNotReorderWhenRemoteOnlyTrackExists() {
        let local = [item("a", video: "video-a", set: "set-a", order: 0)]
        let remote = [track("video-a", set: "set-a"), track("remote-only", set: "set-remote")]

        XCTAssertNil(PlaylistOrderPlanner.moveActions(localItems: local, remoteTracks: remote))
    }

    private func item(_ id: String, video: String, set: String? = nil, order: Int) -> PlaylistItemRecord {
        PlaylistItemRecord(id: id, playlistID: "playlist", sortOrder: order, refType: "yt", refID: video,
                           ytVideoId: video, ytSetVideoId: set, title: id)
    }

    private func track(_ video: String, set: String) -> YTMClient.Track {
        YTMClient.Track(videoId: video, title: video, artist: "artist", album: "", artworkUrl: "",
                        duration: "1:00", setVideoId: set)
    }
}
