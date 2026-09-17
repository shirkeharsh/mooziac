import XCTest
@testable import Mooziac

final class MooziacTests: XCTestCase {
    func testSanity() {
        XCTAssertTrue(true)
    }

    func testKeyboardSeekModifiers() {
        var capturedOverlay = ""

        // Option + Left Arrow -> Rewind 15s
        let handledOptLeft = KeyboardCommandHandler.handle(keyCode: 123, modifierFlags: .option, isRepeat: false) { text in
            capturedOverlay = text
        }
        XCTAssertTrue(handledOptLeft)
        XCTAssertTrue(capturedOverlay.contains("Rewind 15s"))

        // Option + Right Arrow -> Forward 15s
        let handledOptRight = KeyboardCommandHandler.handle(keyCode: 124, modifierFlags: .option, isRepeat: false) { text in
            capturedOverlay = text
        }
        XCTAssertTrue(handledOptRight)
        XCTAssertTrue(capturedOverlay.contains("Forward 15s"))

        // Shift + Left Arrow -> Rewind 30s
        let handledShiftLeft = KeyboardCommandHandler.handle(keyCode: 123, modifierFlags: .shift, isRepeat: false) { text in
            capturedOverlay = text
        }
        XCTAssertTrue(handledShiftLeft)
        XCTAssertTrue(capturedOverlay.contains("Rewind 30s"))

        // Shift + Right Arrow -> Forward 30s
        let handledShiftRight = KeyboardCommandHandler.handle(keyCode: 124, modifierFlags: .shift, isRepeat: false) { text in
            capturedOverlay = text
        }
        XCTAssertTrue(handledShiftRight)
        XCTAssertTrue(capturedOverlay.contains("Forward 30s"))

        // Command + Arrow -> Passed through (returns false)
        let handledCmd = KeyboardCommandHandler.handle(keyCode: 124, modifierFlags: .command, isRepeat: false) { _ in }
        XCTAssertFalse(handledCmd)

        // Plain Left Arrow -> Standard 4s step
        let handledNormal = KeyboardCommandHandler.handle(keyCode: 123, modifierFlags: [], isRepeat: false) { text in
            capturedOverlay = text
        }
        XCTAssertTrue(handledNormal)
        XCTAssertTrue(capturedOverlay.contains("Rewind 4s"))
    }

    func testGestureSeekActions() {
        XCTAssertTrue(GestureAction.allCases.contains(.seekForward15))
        XCTAssertTrue(GestureAction.allCases.contains(.seekBackward15))
        XCTAssertTrue(GestureAction.allCases.contains(.seekForward30))
        XCTAssertTrue(GestureAction.allCases.contains(.seekBackward30))

        XCTAssertEqual(GestureAction.seekForward15.displayName, "Seek Forward 15s")
        XCTAssertEqual(GestureAction.seekBackward15.displayName, "Seek Backward 15s")
        XCTAssertEqual(GestureAction.seekForward30.displayName, "Seek Forward 30s")
        XCTAssertEqual(GestureAction.seekBackward30.displayName, "Seek Backward 30s")

        XCTAssertEqual(GestureAction.seekForward15.iconName, "goforward.15")
        XCTAssertEqual(GestureAction.seekBackward15.iconName, "gobackward.15")
        XCTAssertEqual(GestureAction.seekForward30.iconName, "goforward.30")
        XCTAssertEqual(GestureAction.seekBackward30.iconName, "gobackward.30")
    }

    func testUpdateActiveContextIndex() {
        let item1 = PlaylistItemRecord(id: "item1", playlistID: "p1", sortOrder: 0, refType: "yt", refID: "v1", ytVideoId: "v1", title: "Song 1")
        let item2 = PlaylistItemRecord(id: "item2", playlistID: "p1", sortOrder: 1, refType: "yt", refID: "v2", ytVideoId: "v2", title: "Song 2")
        let ctx = PlaylistManager.ActivePlaylistPlaybackContext(
            playlistID: "p1",
            items: [item1, item2],
            currentIndex: 0,
            localQueue: [],
            localQueueIndexByItemID: [:]
        )

        PlaylistManager.shared.setActiveContextForTesting(ctx)
        XCTAssertTrue(PlaylistManager.shared.hasActiveContext)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 0)

        PlaylistManager.shared.updateActiveContextIndex(1)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 1)
        XCTAssertEqual(PlaylistManager.shared.currentAnchorTrackID, "item2")

        // Out of bounds update is safely ignored
        PlaylistManager.shared.updateActiveContextIndex(5)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 1)

        PlaylistManager.shared.clearActiveContext()
        XCTAssertFalse(PlaylistManager.shared.hasActiveContext)
    }

    func testAdvancingStateManagement() {
        let item1 = PlaylistItemRecord(id: "item1", playlistID: "p1", sortOrder: 0, refType: "yt", refID: "v1", ytVideoId: "v1", title: "Song 1")
        let item2 = PlaylistItemRecord(id: "item2", playlistID: "p1", sortOrder: 1, refType: "yt", refID: "v2", ytVideoId: "v2", title: "Song 2")
        let ctx = PlaylistManager.ActivePlaylistPlaybackContext(
            playlistID: "p1",
            items: [item1, item2],
            currentIndex: 0,
            localQueue: [],
            localQueueIndexByItemID: [:]
        )

        PlaylistManager.shared.setActiveContextForTesting(ctx)
        XCTAssertFalse(PlaylistManager.shared.isAdvancing)

        PlaylistManager.shared.playTrackAtCurrentContextIndex()
        XCTAssertTrue(PlaylistManager.shared.isAdvancing)

        PlaylistManager.shared.completeAdvancing()
        XCTAssertFalse(PlaylistManager.shared.isAdvancing)

        // Clear active context should also reset advancing state
        PlaylistManager.shared.playTrackAtCurrentContextIndex()
        XCTAssertTrue(PlaylistManager.shared.isAdvancing)
        PlaylistManager.shared.clearActiveContext()
        XCTAssertFalse(PlaylistManager.shared.isAdvancing)
    }

    func testAdvancingTrackTransitionKeepsContext() {
        let item1 = PlaylistItemRecord(id: "item1", playlistID: "p1", sortOrder: 0, refType: "yt", refID: "v1", ytVideoId: "v1", title: "Song 1")
        let item2 = PlaylistItemRecord(id: "item2", playlistID: "p1", sortOrder: 1, refType: "yt", refID: "v2", ytVideoId: "v2", title: "Song 2 (Official Video)")
        let ctx = PlaylistManager.ActivePlaylistPlaybackContext(
            playlistID: "p1",
            items: [item1, item2],
            currentIndex: 0,
            localQueue: [],
            localQueueIndexByItemID: [:]
        )

        PlaylistManager.shared.setActiveContextForTesting(ctx)
        XCTAssertTrue(PlaylistManager.shared.playNextTrackInPlaylist())
        XCTAssertTrue(PlaylistManager.shared.isAdvancing)
        XCTAssertEqual(PlaylistManager.shared.activeContext?.currentIndex, 1)

        // Simulating the track change completion in ObserverBridge
        PlaylistManager.shared.completeAdvancing()
        XCTAssertFalse(PlaylistManager.shared.isAdvancing)
        XCTAssertTrue(PlaylistManager.shared.hasActiveContext)
        XCTAssertEqual(PlaylistManager.shared.currentAnchorTrackID, "item2")

        PlaylistManager.shared.clearActiveContext()
    }
}
