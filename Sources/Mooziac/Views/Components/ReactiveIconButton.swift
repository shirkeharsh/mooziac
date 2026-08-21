import AppKit
import QuartzCore

class ReactiveIconButton: NSButton {
    var hoverScale: CGFloat = 1.18
    var representedObject: Any?
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
        bezelStyle = .inline
        isBordered = false
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        fixAnchorPoint()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        fixAnchorPoint()
    }
    
    private func fixAnchorPoint() {
        guard let layer = self.layer else { return }
        if layer.anchorPoint != CGPoint(x: 0.5, y: 0.5) {
            let bounds = layer.bounds
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: frame.origin.x + bounds.width / 2.0, y: frame.origin.y + bounds.height / 2.0)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        animateHover(isHovered: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        animateHover(isHovered: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            self.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
        }
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.layer?.transform = CATransform3DMakeScale(self.hoverScale, self.hoverScale, 1.0)
        }
    }
    
    private func animateHover(isHovered: Bool) {
        let scale: CGFloat = isHovered ? hoverScale : 1.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.layer?.transform = CATransform3DMakeScale(scale, scale, 1.0)
            self.layer?.opacity = isHovered ? 1.0 : 0.88
        }
    }
    
    func animatePop() {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.70
        spring.toValue = 1.0
        spring.initialVelocity = 18.0
        spring.mass = 0.4
        spring.stiffness = 320
        spring.damping = 12
        spring.duration = spring.settlingDuration
        layer?.add(spring, forKey: "pop")
    }
    
    func animateBounce(direction: CGFloat) {
        let animGroup = CAAnimationGroup()
        animGroup.duration = 0.25
        
        let positionAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        positionAnim.values = [0, direction * 5.0, 0]
        positionAnim.keyTimes = [0, 0.5, 1.0]
        
        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnim.values = [1.0, 0.80, 1.15, 1.0]
        scaleAnim.keyTimes = [0, 0.3, 0.7, 1.0]
        
        animGroup.animations = [positionAnim, scaleAnim]
        layer?.add(animGroup, forKey: "bounce")
    }
    
    func animateHeartPop() {
        let keyframe = CAKeyframeAnimation(keyPath: "transform.scale")
        keyframe.values = [1.0, 1.48, 0.85, 1.1, 1.0]
        keyframe.keyTimes = [0, 0.35, 0.6, 0.8, 1.0]
        keyframe.duration = 0.35
        keyframe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(keyframe, forKey: "heartPop")
    }
    
    func animateSpinPop() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2.0
        rotation.duration = 0.4
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.30, 0.85, 1.0]
        scale.keyTimes = [0, 0.4, 0.7, 1.0]
        scale.duration = 0.4
        
        let group = CAAnimationGroup()
        group.animations = [rotation, scale]
        group.duration = 0.4
        layer?.add(group, forKey: "spinPop")
    }

    // MARK: - Refined Download Micro-Animations
    func startDownloadAnimation() {
        stopDownloadAnimation()
        
        // 1. Smooth downward flowing arrow motion
        let translate = CAKeyframeAnimation(keyPath: "transform.translation.y")
        translate.values = [0, 2.5, -1.0, 0]
        translate.keyTimes = [0, 0.45, 0.75, 1.0]
        translate.duration = 0.85
        translate.repeatCount = .infinity
        translate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 2. Gentle breathing scale
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 0.90, 1.06, 1.0]
        scale.keyTimes = [0, 0.45, 0.75, 1.0]
        scale.duration = 0.85
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 3. Subtle opacity pulse
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.60, 1.0]
        opacity.keyTimes = [0, 0.5, 1.0]
        opacity.duration = 0.85
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let group = CAAnimationGroup()
        group.animations = [translate, scale, opacity]
        group.duration = 0.85
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        layer?.add(group, forKey: "downloadingFlow")
        
        // Vibrant cyan-blue accent tint during download
        self.contentTintColor = NSColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 0.95)
    }

    func stopDownloadAnimation() {
        layer?.removeAnimation(forKey: "downloadingFlow")
        layer?.opacity = 1.0
        layer?.transform = CATransform3DIdentity
    }

    func animateDownloadSuccess() {
        stopDownloadAnimation()
        
        // Smooth transition to checkmark
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        if let check = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Saved")?.withSymbolConfiguration(config) {
            self.image = check
        }
        self.contentTintColor = NSColor(red: 0.20, green: 0.88, blue: 0.45, alpha: 1.0)
        
        // Spring bounce pop
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.65
        spring.toValue = 1.0
        spring.initialVelocity = 14.0
        spring.mass = 0.35
        spring.stiffness = 300
        spring.damping = 11
        spring.duration = spring.settlingDuration
        layer?.add(spring, forKey: "successPop")

        // Smooth revert after 1.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.layer?.opacity = 0.0
            }, completionHandler: {
                let normalConfig = NSImage.SymbolConfiguration(pointSize: 12.0, weight: .semibold)
                self.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Download")?.withSymbolConfiguration(normalConfig)
                self.contentTintColor = (PlayerDesign.current == .glassMode) ? NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0) : NSColor(white: 0.85, alpha: 1.0)
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.20
                    self.layer?.opacity = 1.0
                }
            })
        }
    }

    func animateDownloadError() {
        stopDownloadAnimation()
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -3.5, 3.5, -2.0, 2.0, -1.0, 1.0, 0]
        shake.duration = 0.32
        shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(shake, forKey: "errorShake")

        self.contentTintColor = NSColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 0.95)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.contentTintColor = (PlayerDesign.current == .glassMode) ? NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0) : NSColor(white: 0.85, alpha: 1.0)
        }
    }
}
