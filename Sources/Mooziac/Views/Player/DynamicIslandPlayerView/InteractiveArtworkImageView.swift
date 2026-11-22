import AppKit
import QuartzCore

final class InteractiveArtworkImageView: NSImageView {
    var onClick: (() -> Void)?
    var onMouseMove: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        // Album artwork is square, but artwork from some providers is not. Fit
        // the complete image in its bounds instead of silently cropping it.
        layer?.contentsGravity = .resizeAspect
        imageScaling = .scaleProportionallyUpOrDown
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseMove?()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseMove?()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        animateBounce()
        onClick?()
    }

    func animateBounce() {
        guard let layer = self.layer else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1.0, 0.92, 1.05, 1.0]
        anim.keyTimes = [0.0, 0.3, 0.7, 1.0]
        anim.duration = 0.22
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: "artworkBounce")
    }
}
