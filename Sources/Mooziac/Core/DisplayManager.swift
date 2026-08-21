import AppKit

/// Centralized display detection, frame persistence, and safe-area boundary manager for Mooziac.
public final class DisplayManager: NSObject {
    public static let shared = DisplayManager()

    public var onDisplayConfigurationChanged: (() -> Void)?

    private override init() {
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleDisplayParametersChange() {
        DispatchQueue.main.async { [weak self] in
            self?.onDisplayConfigurationChanged?()
        }
    }

    /// Returns the unique hardware display ID (CGDirectDisplayID) for a given screen.
    public func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let idNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(idNumber.uint32Value)
    }

    /// Finds an active screen matching the saved display ID, or falls back to the screen containing the origin, or NSScreen.main.
    public func findScreen(forSavedID savedID: CGDirectDisplayID?, fallbackOrigin: CGPoint? = nil) -> NSScreen {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main ?? NSScreen.screens.first! }

        if let savedID = savedID,
           let matched = screens.first(where: { displayID(for: $0) == savedID }) {
            return matched
        }

        if let origin = fallbackOrigin,
           let matched = screens.first(where: { $0.frame.contains(origin) }) {
            return matched
        }

        return NSScreen.main ?? screens.first!
    }

    /// Clamps a target window frame strictly inside a screen's visibleFrame (excluding Dock & Menu Bar) with safe margin.
    public func clampFrameToVisibleBounds(_ frame: NSRect, on screen: NSScreen, margin: CGFloat = 0.0) -> NSRect {
        let visible = screen.visibleFrame
        let width = min(frame.width, visible.width - (margin * 2))
        let height = min(frame.height, visible.height)

        var x = frame.origin.x
        var y = frame.origin.y

        // Horizontal clamp (avoid off-screen & side Dock)
        let minX = visible.minX + margin
        let maxX = visible.maxX - width - margin
        x = max(minX, min(x, maxX))

        // Vertical clamp (allow top edge up to visible.maxY so window can stick flush to menu bar)
        let minY = visible.minY + margin
        let maxY = visible.maxY - height
        y = max(minY, min(y, maxY))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Returns true if display has a top camera notch cutout.
    public func hasNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }

    /// Calculates safe top menu bar boundary accounting for menu bar and notch.
    public func safeTopBoundary(for screen: NSScreen) -> CGFloat {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = max(24, screenFrame.maxY - visibleFrame.maxY)
        return screenFrame.maxY - menuBarHeight
    }
}
