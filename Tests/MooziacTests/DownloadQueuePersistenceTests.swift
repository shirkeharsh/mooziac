import XCTest
@testable import Mooziac

final class DownloadQueuePersistenceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        DownloadQueuePersistence.clear()
    }
    
    override func tearDown() {
        DownloadQueuePersistence.clear()
        super.tearDown()
    }
    
    func testSaveAndLoadQueue() {
        let job1 = PersistedDownloadJob(
            taskID: "task_1",
            ytVideoId: "vid_1234567",
            title: "Test Song 1",
            artist: "Test Artist 1",
            artworkUrl: "https://example.com/art1.jpg",
            queuedAt: Date()
        )
        
        let job2 = PersistedDownloadJob(
            taskID: "task_2",
            ytVideoId: "vid_7654321",
            title: "Test Song 2",
            artist: "Test Artist 2",
            artworkUrl: "https://example.com/art2.jpg",
            queuedAt: Date()
        )
        
        DownloadQueuePersistence.save([job1, job2])
        
        let loaded = DownloadQueuePersistence.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].taskID, "task_1")
        XCTAssertEqual(loaded[0].title, "Test Song 1")
        XCTAssertEqual(loaded[1].taskID, "task_2")
        XCTAssertEqual(loaded[1].ytVideoId, "vid_7654321")
    }
    
    func testClearQueue() {
        let job = PersistedDownloadJob(
            taskID: "task_clear",
            ytVideoId: "vid_clear",
            title: "Clear Song",
            artist: "Clear Artist",
            artworkUrl: "",
            queuedAt: Date()
        )
        
        DownloadQueuePersistence.save([job])
        XCTAssertEqual(DownloadQueuePersistence.load().count, 1)
        
        DownloadQueuePersistence.clear()
        XCTAssertTrue(DownloadQueuePersistence.load().isEmpty)
    }
}
