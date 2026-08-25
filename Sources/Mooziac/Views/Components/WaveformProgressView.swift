import AppKit
import QuartzCore

// MARK: - 60+ FPS Interactive Waveform Progress Bar with Hover & Scrubbing Tooltip
class InteractiveWaveformProgressView: NSView {
    var onSeek: ((Double) -> Void)?
    var isUserScrubbing: Bool = false
    
    var progress: Double = 0.0 {
        didSet {
            if !isUserScrubbing {
                if let window = self.window, window.isVisible, !self.isHidden {
                    needsDisplay = true
                }
                updateThumbPosition()
            }
        }
    }
    
    var duration: Double = 0.0
    var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                startWaveAnimation()
            } else {
                stopWaveAnimation()
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window?.isVisible == true && isPlaying && !isHidden {
            startWaveAnimation()
        } else {
            stopWaveAnimation()
        }
    }

    override func viewDidHide() {
        super.viewDidHide()
        stopWaveAnimation()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        if isPlaying {
            startWaveAnimation()
        }
    }
    
    private func updateThumbPosition() {
        let xPos = CGFloat(progress) * bounds.width
        let thumbX = max(0, min(bounds.width - 9, xPos - 4.5))
        let thumbY = (bounds.height - 9) / 2.0
        thumbView.frame = CGRect(x: thumbX, y: thumbY, width: 9, height: 9)
    }
    
    private func startWaveAnimation() {
        stopWaveAnimation()
        guard let window = self.window, window.isVisible, !self.isHidden else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let window = self.window, window.isVisible, !self.isHidden else {
                self.stopWaveAnimation()
                return
            }
            self.wavePhase += 0.3
            self.needsDisplay = true
        }
    }
    
    private func stopWaveAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        if let window = self.window, window.isVisible, !self.isHidden {
            needsDisplay = true
        }
    }
    
    var accentColor: NSColor = NSColor(red: 0.98, green: 0.25, blue: 0.35, alpha: 1.0) {
        didSet { needsDisplay = true }
    }
    
    private var trackingArea: NSTrackingArea?
    private var isHovering: Bool = false
    private var hoverRatio: Double = 0.0
    private var animationTimer: Timer?
    private var wavePhase: Double = 0.0
    
    private let baseHeights: [CGFloat] = [
        0.35, 0.55, 0.80, 0.45, 0.70, 0.95, 0.60, 0.85, 0.40, 0.75,
        0.90, 0.50, 0.80, 0.95, 0.55, 0.85, 0.45, 0.70, 0.90, 0.40,
        0.65, 0.85, 0.55, 0.75, 0.45, 0.70, 0.85, 0.35, 0.60, 0.75,
        0.50, 0.35
    ]
    
    private let thumbView = NSView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        thumbView.wantsLayer = true
        thumbView.layer?.backgroundColor = NSColor.white.cgColor
        thumbView.layer?.cornerRadius = 4.5
        thumbView.layer?.shadowColor = NSColor.black.cgColor
        thumbView.layer?.shadowRadius = 2
        thumbView.layer?.shadowOpacity = 0.4
        thumbView.layer?.shadowOffset = .zero
        thumbView.alphaValue = 0.0
        thumbView.frame = CGRect(x: 0, y: 0, width: 9, height: 9)
        
        addSubview(thumbView)
        NotificationCenter.default.addObserver(self, selector: #selector(progressStyleChanged), name: NSNotification.Name("ProgressStyleDidChange"), object: nil)
        progressStyleChanged()
    }

    @objc private func progressStyleChanged() {
        let style = ProgressStyle.current
        thumbView.isHidden = (style == .neonGlow || style == .cyberDots)
        needsDisplay = true
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        if ProgressStyle.current != .neonGlow && ProgressStyle.current != .cyberDots {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                thumbView.animator().alphaValue = 1.0
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        if !isUserScrubbing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                thumbView.animator().alphaValue = 0.0
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let ratio = max(0.0, min(1.0, Double(location.x / bounds.width)))
        hoverRatio = ratio
        updateThumbPosition()
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    override func mouseDown(with event: NSEvent) {
        isUserScrubbing = true
        updateScrubbing(with: event)
        
        if ProgressStyle.current != .neonGlow && ProgressStyle.current != .cyberDots {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.10
                thumbView.animator().alphaValue = 1.0
            }
        }
        
        guard let window = window else { return }
        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { continue }
            if nextEvent.type == .leftMouseDragged {
                updateScrubbing(with: nextEvent)
            } else if nextEvent.type == .leftMouseUp {
                updateScrubbing(with: nextEvent)
                isUserScrubbing = false
                onSeek?(hoverRatio)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.20
                    if !isHovering {
                        thumbView.animator().alphaValue = 0.0
                    }
                }
                break
            }
        }
    }
    
    private func updateScrubbing(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let ratio = max(0.0, min(1.0, Double(location.x / bounds.width)))
        hoverRatio = ratio
        progress = ratio
        needsDisplay = true
        updateThumbPosition()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let style = ProgressStyle.current
        let activeRatio = isUserScrubbing ? hoverRatio : progress
        
        switch style {
        case .waveform:
            let count = baseHeights.count
            let spacing: CGFloat = 2.0
            let availableW = bounds.width - (CGFloat(count - 1) * spacing)
            let barW = max(2.0, availableW / CGFloat(count))
            let h = bounds.height
            
            for i in 0..<count {
                let baseH = baseHeights[i]
                var dynamicH = baseH
                if isPlaying {
                    let waveOffset = sin(wavePhase + Double(i) * 0.4) * 0.20
                    dynamicH = max(0.20, min(1.0, baseH + CGFloat(waveOffset)))
                }
                
                let barH = max(3.0, h * dynamicH)
                let x = CGFloat(i) * (barW + spacing)
                let y = (h - barH) / 2.0
                
                let rect = CGRect(x: x, y: y, width: barW, height: barH)
                let path = CGPath(roundedRect: rect, cornerWidth: barW / 2.0, cornerHeight: barW / 2.0, transform: nil)
                
                let isBarActive = (Double(x + barW) / Double(bounds.width)) <= activeRatio
                let fillColor = isBarActive ? accentColor : NSColor(white: 1.0, alpha: 0.20)
                
                ctx.setFillColor(fillColor.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            }
            
        case .neonGlow:
            let trackH: CGFloat = 4.5
            let y = (bounds.height - trackH) / 2.0
            
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.16).cgColor)
            let bgRect = CGRect(x: 0, y: y, width: bounds.width, height: trackH)
            let bgPath = CGPath(roundedRect: bgRect, cornerWidth: trackH / 2.0, cornerHeight: trackH / 2.0, transform: nil)
            ctx.addPath(bgPath)
            ctx.fillPath()
            
            if activeRatio > 0 {
                let activeW = max(trackH, bounds.width * CGFloat(activeRatio))
                let activeRect = CGRect(x: 0, y: y, width: activeW, height: trackH)
                let activePath = CGPath(roundedRect: activeRect, cornerWidth: trackH / 2.0, cornerHeight: trackH / 2.0, transform: nil)
                
                ctx.saveGState()
                let neonCyan = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                ctx.setShadow(offset: .zero, blur: 6.0, color: neonCyan.cgColor)
                ctx.setFillColor(neonCyan.cgColor)
                ctx.addPath(activePath)
                ctx.fillPath()
                ctx.restoreGState()
                
                ctx.setFillColor(NSColor.white.cgColor)
                let coreH: CGFloat = 2.5
                let coreY = (bounds.height - coreH) / 2.0
                let coreRect = CGRect(x: 1, y: coreY, width: max(coreH, activeW - 2), height: coreH)
                let corePath = CGPath(roundedRect: coreRect, cornerWidth: coreH / 2.0, cornerHeight: coreH / 2.0, transform: nil)
                ctx.addPath(corePath)
                ctx.fillPath()
                
                let headDiameter: CGFloat = 9.0
                let headX = max(0, min(bounds.width - headDiameter, activeW - (headDiameter / 2.0)))
                let headY = (bounds.height - headDiameter) / 2.0
                let headRect = CGRect(x: headX, y: headY, width: headDiameter, height: headDiameter)
                
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: 8.0, color: neonCyan.cgColor)
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.addEllipse(in: headRect)
                ctx.fillPath()
                ctx.restoreGState()
            }
            
        case .cyberDots:
            let nodeCount = 24
            let spacing = bounds.width / CGFloat(nodeCount)
            let centerY = bounds.height / 2.0
            
            for i in 0..<nodeCount {
                let nodeX = (CGFloat(i) + 0.5) * spacing
                let nodeRatio = Double(i) / Double(nodeCount - 1)
                let isActive = nodeRatio <= activeRatio
                
                var radius: CGFloat = 3.0
                if isActive && isPlaying {
                    let pulse = sin(wavePhase + Double(i) * 0.5) * 0.8
                    radius = max(2.5, min(4.5, 3.0 + CGFloat(pulse)))
                }
                
                let rect = CGRect(x: nodeX - radius, y: centerY - radius, width: radius * 2, height: radius * 2)
                let color = isActive ? accentColor : NSColor(white: 1.0, alpha: 0.25)
                ctx.setFillColor(color.cgColor)
                ctx.addEllipse(in: rect)
                ctx.fillPath()
            }
            
        case .minimalLine:
            let trackH: CGFloat = 2.5
            let y = (bounds.height - trackH) / 2.0
            
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.18).cgColor)
            let bgRect = CGRect(x: 0, y: y, width: bounds.width, height: trackH)
            let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 1.25, cornerHeight: 1.25, transform: nil)
            ctx.addPath(bgPath)
            ctx.fillPath()
            
            if activeRatio > 0 {
                ctx.setFillColor(accentColor.cgColor)
                let activeW = max(2.5, bounds.width * CGFloat(activeRatio))
                let activeRect = CGRect(x: 0, y: y, width: activeW, height: trackH)
                let activePath = CGPath(roundedRect: activeRect, cornerWidth: 1.25, cornerHeight: 1.25, transform: nil)
                ctx.addPath(activePath)
                ctx.fillPath()
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let sec = Int(seconds)
        let mins = sec / 60
        let secs = sec % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
