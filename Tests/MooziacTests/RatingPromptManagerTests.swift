import XCTest
@testable import Mooziac

final class RatingPromptManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "YTM_rating_hasInteracted")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_lastPromptDate")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_promptShownCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_launchCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_songsCompletedCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_firstLaunchDate")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "YTM_rating_hasInteracted")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_lastPromptDate")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_promptShownCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_launchCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_songsCompletedCount")
        UserDefaults.standard.removeObject(forKey: "YTM_rating_firstLaunchDate")
        super.tearDown()
    }
    
    func testInitialStateDoesNotPrompt() {
        let manager = RatingPromptManager.shared
        XCTAssertFalse(manager.hasInteracted)
        XCTAssertEqual(manager.promptShownCount, 0)
    }
    
    func testSnoozeSetsDate() {
        let manager = RatingPromptManager.shared
        let before = Date().timeIntervalSince1970 - 1.0
        manager.snooze()
        let snoozeDate = manager.lastPromptDate
        XCTAssertGreaterThan(snoozeDate, before)
    }
    
    func testMarkInteracted() {
        let manager = RatingPromptManager.shared
        manager.markInteracted()
        XCTAssertTrue(manager.hasInteracted)
        XCTAssertFalse(manager.isEligibleForPrompt)
        XCTAssertFalse(manager.shouldShowPrompt())
    }
    
    func testIncrementSongCompletion() {
        let initial = UserDefaults.standard.integer(forKey: "YTM_rating_songsCompletedCount")
        RatingPromptManager.shared.recordSongCompleted()
        let updated = UserDefaults.standard.integer(forKey: "YTM_rating_songsCompletedCount")
        XCTAssertEqual(updated, initial + 1)
    }
}
