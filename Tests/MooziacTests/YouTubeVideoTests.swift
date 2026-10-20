import XCTest
@testable import Mooziac

final class YouTubeVideoTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "MooziacYouTube_preferredQuality")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "MooziacYouTube_preferredQuality")
        super.tearDown()
    }

    // MARK: - Video Quality Enum Tests

    func testVideoQualityEnumValuesAndLabels() {
        XCTAssertEqual(VideoQuality.auto.rawValue, "auto")
        XCTAssertEqual(VideoQuality.uhd2160.rawValue, "hd2160")
        XCTAssertEqual(VideoQuality.qhd1440.rawValue, "hd1440")
        XCTAssertEqual(VideoQuality.fhd1080.rawValue, "hd1080")
        XCTAssertEqual(VideoQuality.hd720.rawValue, "hd720")
        XCTAssertEqual(VideoQuality.large.rawValue, "large")
        XCTAssertEqual(VideoQuality.medium.rawValue, "medium")
        XCTAssertEqual(VideoQuality.small.rawValue, "small")
        XCTAssertEqual(VideoQuality.tiny.rawValue, "tiny")

        XCTAssertEqual(VideoQuality.uhd2160.displayName, "4K (2160p)")
        XCTAssertEqual(VideoQuality.qhd1440.displayName, "1440p (2K)")
        XCTAssertEqual(VideoQuality.fhd1080.displayName, "1080p (Full HD)")
        XCTAssertEqual(VideoQuality.hd720.displayName, "720p (HD)")
        XCTAssertEqual(VideoQuality.large.displayName, "480p")
        XCTAssertEqual(VideoQuality.medium.displayName, "360p")
        XCTAssertEqual(VideoQuality.small.displayName, "240p")
        XCTAssertEqual(VideoQuality.tiny.displayName, "144p")
        XCTAssertEqual(VideoQuality.auto.displayName, "Auto")

        XCTAssertEqual(VideoQuality.uhd2160.shortLabel, "4K")
        XCTAssertEqual(VideoQuality.qhd1440.shortLabel, "2K")
        XCTAssertEqual(VideoQuality.fhd1080.shortLabel, "1080p")
        XCTAssertEqual(VideoQuality.hd720.shortLabel, "720p")
        XCTAssertEqual(VideoQuality.auto.shortLabel, "Auto")

        XCTAssertTrue(VideoQuality.uhd2160.is4K)
        XCTAssertFalse(VideoQuality.fhd1080.is4K)
        XCTAssertFalse(VideoQuality.qhd1440.is4K)
        XCTAssertFalse(VideoQuality.hd720.is4K)
        XCTAssertFalse(VideoQuality.auto.is4K)
    }

    func testVideoQualityCodable() throws {
        let original = VideoQuality.uhd2160
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoQuality.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Quality Manager Tests

    func testYouTubeQualityManagerDefaultPreference() {
        UserDefaults.standard.removeObject(forKey: "MooziacYouTube_preferredQuality")
        // Verify default is 1080p Full HD for cool thermals
        XCTAssertEqual(YouTubeQualityManager.shared.preferredQuality, .fhd1080)

        // Setting a different preferred quality persists to UserDefaults
        YouTubeQualityManager.shared.preferredQuality = .uhd2160
        XCTAssertEqual(YouTubeQualityManager.shared.preferredQuality, .uhd2160)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "MooziacYouTube_preferredQuality"), "hd2160")

        YouTubeQualityManager.shared.preferredQuality = .fhd1080
        XCTAssertEqual(YouTubeQualityManager.shared.preferredQuality, .fhd1080)
    }

    func testYouTubeQualityManagerWebUpdates() {
        YouTubeQualityManager.shared.updateFromWeb(
            current: "hd1080",
            available: ["hd2160", "hd1440", "hd1080", "hd720", "large", "medium"]
        )

        XCTAssertEqual(YouTubeQualityManager.shared.currentQuality, .fhd1080)
        XCTAssertTrue(YouTubeQualityManager.shared.is4KAvailable)
        XCTAssertFalse(YouTubeQualityManager.shared.is4KActive)
        XCTAssertEqual(YouTubeQualityManager.shared.availableQualities.count, 6)

        // Switch to 4K
        YouTubeQualityManager.shared.updateFromWeb(
            current: "hd2160",
            available: ["hd2160", "hd1080"]
        )
        XCTAssertEqual(YouTubeQualityManager.shared.currentQuality, .uhd2160)
        XCTAssertTrue(YouTubeQualityManager.shared.is4KActive)

        // Unknown quality string defaults to .auto
        YouTubeQualityManager.shared.updateFromWeb(
            current: "unsupported_resolution",
            available: ["custom_format"]
        )
        XCTAssertEqual(YouTubeQualityManager.shared.currentQuality, .auto)
        XCTAssertFalse(YouTubeQualityManager.shared.is4KAvailable)
        XCTAssertFalse(YouTubeQualityManager.shared.is4KActive)
    }

    // MARK: - Video Playback State Tests

    func testVideoPlaybackStateInitialValues() {
        let state = VideoPlaybackState()
        XCTAssertEqual(state.title, "")
        XCTAssertEqual(state.channel, "")
        XCTAssertEqual(state.currentTime, 0.0)
        XCTAssertEqual(state.duration, 0.0)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isMuted)
        XCTAssertEqual(state.volume, 1.0)
        XCTAssertEqual(state.playbackRate, 1.0)
        XCTAssertEqual(state.currentQuality, .auto)
        XCTAssertEqual(state.progress, 0.0)
        XCTAssertEqual(state.formattedCurrentTime, "0:00")
        XCTAssertEqual(state.formattedDuration, "0:00")
        XCTAssertEqual(state.formattedPlaybackSpeed, "1.0×")
    }

    func testVideoPlaybackStateProgressCalculation() {
        var state = VideoPlaybackState()
        state.duration = 200.0

        state.currentTime = 50.0
        XCTAssertEqual(state.progress, 0.25, accuracy: 0.001)

        state.currentTime = 200.0
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.001)

        // Clamping bounds
        state.currentTime = 250.0
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.001)

        state.currentTime = -10.0
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.001)

        // Zero duration guard
        state.duration = 0.0
        state.currentTime = 50.0
        XCTAssertEqual(state.progress, 0.0)
    }

    func testVideoPlaybackStateTimeFormatting() {
        var state = VideoPlaybackState()

        state.currentTime = 45.0
        XCTAssertEqual(state.formattedCurrentTime, "0:45")

        state.currentTime = 125.0
        XCTAssertEqual(state.formattedCurrentTime, "2:05")

        state.currentTime = 3665.0
        XCTAssertEqual(state.formattedCurrentTime, "1:01:05")

        state.currentTime = -5.0
        XCTAssertEqual(state.formattedCurrentTime, "0:00")

        state.duration = 180.0
        XCTAssertEqual(state.formattedDuration, "3:00")

        state.duration = 7322.0
        XCTAssertEqual(state.formattedDuration, "2:02:02")
    }

    func testVideoPlaybackStateSpeedFormatting() {
        var state = VideoPlaybackState()

        state.playbackRate = 1.0
        XCTAssertEqual(state.formattedPlaybackSpeed, "1.0×")

        state.playbackRate = 1.25
        XCTAssertEqual(state.formattedPlaybackSpeed, "1.25×")

        state.playbackRate = 2.0
        XCTAssertEqual(state.formattedPlaybackSpeed, "2.00×")

        state.playbackRate = 0.75
        XCTAssertEqual(state.formattedPlaybackSpeed, "0.75×")
    }

    // MARK: - Player Theme Tests

    func testPlayerTheme() {
        XCTAssertEqual(PlayerTheme.liquidFluid.id, "liquid")
        XCTAssertEqual(PlayerTheme.liquidFluid.displayName, "Liquid Transparent Vibrancy")
        XCTAssertEqual(PlayerTheme.liquidFluid.systemSymbolName, "drop.fill")
    }

    // MARK: - YouTube Settings Tests

    func testYouTubeSettingsDefaultsAndNotifications() {
        let settings = YouTubeSettings.shared

        let expAdBlock = expectation(forNotification: YouTubeSettings.adBlockDidChangeNotification, object: nil)
        let initialAdBlock = settings.isAdBlockEnabled
        settings.isAdBlockEnabled = !initialAdBlock
        wait(for: [expAdBlock], timeout: 1.0)
        settings.isAdBlockEnabled = initialAdBlock

        let expSponsor = expectation(forNotification: YouTubeSettings.sponsorBlockDidChangeNotification, object: nil)
        let initialSponsor = settings.isSponsorBlockEnabled
        settings.isSponsorBlockEnabled = !initialSponsor
        wait(for: [expSponsor], timeout: 1.0)
        settings.isSponsorBlockEnabled = initialSponsor

        let expDistraction = expectation(forNotification: YouTubeSettings.distractionFreeDidChangeNotification, object: nil)
        let initialDistraction = settings.isDistractionFreeEnabled
        settings.isDistractionFreeEnabled = !initialDistraction
        wait(for: [expDistraction], timeout: 1.0)
        settings.isDistractionFreeEnabled = initialDistraction
    }
}
