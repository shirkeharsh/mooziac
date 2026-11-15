import XCTest
@testable import Mooziac

final class RatingPromptManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "mzc_has_interacted_prompt")
        UserDefaults.standard.removeObject(forKey: "mzc_prompt_snooze_until")
        UserDefaults.standard.removeObject(forKey: "mzc_prompt_shown_count")
        UserDefaults.standard.removeObject(forKey: "mzc_app_launch_count")
        UserDefaults.standard.removeObject(forKey: "mzc_songs_completed_count")
        UserDefaults.standard.removeObject(forKey: "mzc_first_launch_date")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "mzc_has_interacted_prompt")
        UserDefaults.standard.removeObject(forKey: "mzc_prompt_snooze_until")
        UserDefaults.standard.removeObject(forKey: "mzc_prompt_shown_count")
        UserDefaults.standard.removeObject(forKey: "mzc_app_launch_count")
        UserDefaults.standard.removeObject(forKey: "mzc_songs_completed_count")
        UserDefaults.standard.removeObject(forKey: "mzc_first_launch_date")
        super.tearDown()
    }
    
    func testInitialStateDoesNotPrompt() {
        let manager = RatingPromptManager.shared
        XCTAssertFalse(manager.hasInteracted)
        XCTAssertEqual(manager.promptShownCount, 0)
    }
    
    func testSnoozeSetsDate() {
        let manager = RatingPromptManager.shared
        manager.snooze()
        let snoozeDate = UserDefaults.standard.double(forKey: "mzc_prompt_snooze_until")
        XCTAssertGreaterThan(snoozeDate, Date().timeIntervalSince1970)
    }
    
    func testMarkInteracted() {
        let manager = RatingPromptManager.shared
        manager.markInteracted()
        XCTAssertTrue(manager.hasInteracted)
        XCTAssertFalse(manager.shouldShowPrompt())
    }
    
    func testIncrementSongCompletion() {
        let initial = UserDefaults.standard.integer(forKey: "mzc_songs_completed_count")
        RatingPromptManager.shared.recordSongCompleted()
        let updated = UserDefaults.standard.integer(forKey: "mzc_songs_completed_count")
        XCTAssertEqual(updated, initial + 1)
    }
}
