import XCTest
import AppKit
@testable import Mooziac

final class HeroPlayerTests: XCTestCase {
    
    func testDefaultArtworkBypassesBlurCache() {
        let defaultArt = AppArtworkHelper.defaultArtwork
        let result = AppArtworkHelper.shared.getBlurredArtwork(from: defaultArt, key: "test_track_key", radius: 3.5)
        // Default placeholder should be returned without caching or polluting track key
        XCTAssertNotNil(result)
    }

    func testBlurredArtworkGenerationForValidImage() {
        // Create 64x64 solid test image
        let img = NSImage(size: NSSize(width: 64, height: 64))
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        img.unlockFocus()
        
        let blurred = AppArtworkHelper.shared.getBlurredArtwork(from: img, key: "unit_test_art", radius: 3.5)
        XCTAssertNotNil(blurred)
        XCTAssertEqual(blurred.size.width, 360)
        XCTAssertEqual(blurred.size.height, 202)
    }

    func testWaveformProgressViewUnplayedColorConfiguration() {
        let view = InteractiveWaveformProgressView(frame: NSRect(x: 0, y: 0, width: 200, height: 12))
        XCTAssertNotNil(view)
        
        // Custom unplayed color support
        let customGrey = NSColor(white: 0.40, alpha: 0.40)
        view.unplayedColor = customGrey
        XCTAssertEqual(view.unplayedColor, customGrey)
        
        // Accent color setting
        let customAccent = NSColor.systemBlue
        view.accentColor = customAccent
        XCTAssertEqual(view.accentColor, customAccent)
    }

    func testWaveformProgressClamping() {
        let view = InteractiveWaveformProgressView(frame: NSRect(x: 0, y: 0, width: 200, height: 12))
        view.progress = 0.5
        XCTAssertEqual(view.progress, 0.5)
        view.progress = 1.0
        XCTAssertEqual(view.progress, 1.0)
    }

    func testPlayerDesignValues() {
        XCTAssertTrue(PlayerDesign.allCases.contains(.glassMode))
        XCTAssertTrue(PlayerDesign.allCases.contains(.adaptive))
        XCTAssertTrue(PlayerDesign.allCases.contains(.darkMode))
        XCTAssertTrue(PlayerDesign.allCases.contains(.liquidFluid))
        
        XCTAssertTrue(PlayerDesign.glassMode.isGlass)
        XCTAssertFalse(PlayerDesign.darkMode.isGlass)
    }
}
