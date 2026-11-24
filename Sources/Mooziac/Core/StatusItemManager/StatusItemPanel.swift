import AppKit

final class StatusItemPanel: NSPanel {
    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.contentViewController = contentViewController
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        guard let screen = self.screen ?? NSScreen.main else {
            super.setFrameOrigin(newOrigin)
            return
        }
        let scale = screen.backingScaleFactor
        if scale > 0 {
            let snappedX = round(newOrigin.x * scale) / scale
            let snappedY = round(newOrigin.y * scale) / scale
            super.setFrameOrigin(NSPoint(x: snappedX, y: snappedY))
        } else {
            super.setFrameOrigin(newOrigin)
        }
    }
}
