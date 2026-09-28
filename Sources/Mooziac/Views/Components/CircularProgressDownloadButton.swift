import AppKit
import QuartzCore

final class CircularProgressDownloadButton: ReactiveIconButton {
    enum State: Equatable {
        case idleDownload
        case queued
        case downloading(progress: Double, eta: String)
        case completed
        case unavailable
    }

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let centerSquareLayer = CALayer()

    private var currentVisualProgress: CGFloat = 0.0
    private var isSpinningQueued: Bool = false
    private var isCompletingAnimation: Bool = false

    var downloadState: State = .idleDownload {
        didSet {
            updateVisuals()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    override var intrinsicContentSize: NSSize {
        if let image = image {
            return image.size
        }
        return NSSize(width: 15, height: 15)
    }

    private func setupLayers() {
        wantsLayer = true

        trackLayer.fillColor = nil
        trackLayer.lineWidth = 1.8
        trackLayer.lineCap = .round
        trackLayer.isHidden = true
        layer?.addSublayer(trackLayer)

        progressLayer.fillColor = nil
        progressLayer.lineWidth = 2.0
        progressLayer.lineCap = .round
        progressLayer.strokeStart = 0.0
        progressLayer.strokeEnd = 0.0
        progressLayer.isHidden = true
        layer?.addSublayer(progressLayer)

        centerSquareLayer.cornerRadius = 1.2
        centerSquareLayer.masksToBounds = true
        centerSquareLayer.isHidden = true
        layer?.addSublayer(centerSquareLayer)

        updateVisuals()
    }

    override func layout() {
        super.layout()
        updatePath()
    }

    private func updatePath() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(2, min(bounds.width, bounds.height) / 2.0 - 2.0)
        let startAngle = -CGFloat.pi / 2.0
        let endAngle = startAngle + 2.0 * CGFloat.pi

        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

        trackLayer.path = path
        progressLayer.path = path

        let squareSize: CGFloat = 4.0
        centerSquareLayer.frame = CGRect(
            x: bounds.midX - squareSize / 2.0,
            y: bounds.midY - squareSize / 2.0,
            width: squareSize,
            height: squareSize
        )
    }

    private func idleIconColor() -> NSColor {
        switch PlayerDesign.current {
        case .glassMode:
            return NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0)
        case .liquidFluid:
            return SystemAppearanceHelper.isDarkSystemAppearance ? NSColor(white: 0.80, alpha: 1.0) : NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1.0)
        case .adaptive:
            return NSColor(white: 0.80, alpha: 1.0)
        case .darkMode:
            return NSColor(white: 0.85, alpha: 1.0)
        }
    }

    private func isDarkTheme() -> Bool {
        switch PlayerDesign.current {
        case .darkMode: return true
        case .liquidFluid: return SystemAppearanceHelper.isDarkSystemAppearance
        case .glassMode: return false
        case .adaptive:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    func updateVisuals() {
        let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        let accentColor = isLight ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        let trackColor = isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : NSColor(white: 1.0, alpha: 0.20).cgColor

        trackLayer.strokeColor = trackColor
        progressLayer.strokeColor = accentColor.cgColor
        centerSquareLayer.backgroundColor = accentColor.cgColor

        switch downloadState {
        case .idleDownload:
            isCompletingAnimation = false
            isSpinningQueued = false
            currentVisualProgress = 0.0
            trackLayer.isHidden = true
            progressLayer.isHidden = true
            centerSquareLayer.isHidden = true
            trackLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()
            progressLayer.transform = CATransform3DIdentity
            centerSquareLayer.removeAllAnimations()
            centerSquareLayer.transform = CATransform3DIdentity
            isEnabled = true

            let dlConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Download Song")?.withSymbolConfiguration(dlConfig)
            contentTintColor = idleIconColor()
            toolTip = "Download to Offline Library"

        case .queued:
            guard !isCompletingAnimation else { return }
            image = nil
            isEnabled = true
            trackLayer.isHidden = false
            progressLayer.isHidden = false
            centerSquareLayer.isHidden = false
            centerSquareLayer.opacity = 1.0
            centerSquareLayer.transform = CATransform3DIdentity
            toolTip = "Waiting in download queue... — click to cancel"

            if !isSpinningQueued {
                isSpinningQueued = true
                currentVisualProgress = 0.0

                // GPU-accelerated lightweight orbiting arc while waiting in queue
                progressLayer.strokeStart = 0.0
                progressLayer.strokeEnd = 0.25

                let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
                rotate.fromValue = 0.0
                rotate.toValue = 2.0 * CGFloat.pi
                rotate.duration = 1.15
                rotate.repeatCount = .infinity
                rotate.isRemovedOnCompletion = false
                progressLayer.add(rotate, forKey: "orbitQueued")
            }

        case .downloading(let progress, let eta):
            guard !isCompletingAnimation else { return }
            image = nil
            isEnabled = true
            trackLayer.isHidden = false
            progressLayer.isHidden = false
            centerSquareLayer.isHidden = false
            centerSquareLayer.opacity = 1.0
            centerSquareLayer.transform = CATransform3DIdentity

            if isSpinningQueued {
                isSpinningQueued = false
                progressLayer.removeAnimation(forKey: "orbitQueued")
                progressLayer.transform = CATransform3DIdentity
                progressLayer.strokeStart = 0.0
                progressLayer.strokeEnd = 0.05
                currentVisualProgress = 0.05
            }

            let targetPct = CGFloat(max(0.05, min(progress, 1.0)))
            let previousPct = currentVisualProgress

            if targetPct > previousPct {
                // Smooth GPU-accelerated interpolation across frames
                let anim = CABasicAnimation(keyPath: "strokeEnd")
                anim.fromValue = previousPct
                anim.toValue = targetPct
                anim.duration = max(0.20, min(0.42, Double(targetPct - previousPct) * 1.1))
                anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                anim.fillMode = .forwards
                anim.isRemovedOnCompletion = true
                progressLayer.add(anim, forKey: "strokeEndAnim")
                progressLayer.strokeEnd = targetPct
                currentVisualProgress = targetPct
            }

            let pctInt = Int(targetPct * 100)
            toolTip = "Downloading (\(pctInt)%\(eta.isEmpty ? "" : " • ETA \(eta)")) — click to cancel"

        case .completed:
            isEnabled = true
            toolTip = "Downloaded (Available Offline)"

            // If we were actively downloading, run the completing circle sweep animation
            if !progressLayer.isHidden && currentVisualProgress > 0 && currentVisualProgress < 1.0 && !isCompletingAnimation {
                isCompletingAnimation = true
                isSpinningQueued = false
                progressLayer.removeAnimation(forKey: "orbitQueued")
                progressLayer.transform = CATransform3DIdentity

                CATransaction.begin()
                CATransaction.setAnimationDuration(0.24)
                CATransaction.setCompletionBlock { [weak self] in
                    guard let self = self else { return }
                    self.isCompletingAnimation = false
                    self.finalizeCompletedState(animated: true)
                }

                // 1. Smoothly close the circle completely
                let sweep = CABasicAnimation(keyPath: "strokeEnd")
                sweep.fromValue = currentVisualProgress
                sweep.toValue = 1.0
                sweep.duration = 0.24
                sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                sweep.fillMode = .forwards
                sweep.isRemovedOnCompletion = false
                progressLayer.add(sweep, forKey: "completeSweep")
                progressLayer.strokeEnd = 1.0
                currentVisualProgress = 1.0

                // 2. Shrink the cancel square in the center
                let shrink = CABasicAnimation(keyPath: "transform.scale")
                shrink.fromValue = 1.0
                shrink.toValue = 0.0
                shrink.duration = 0.18
                shrink.fillMode = .forwards
                shrink.isRemovedOnCompletion = false
                centerSquareLayer.add(shrink, forKey: "shrinkSquare")

                CATransaction.commit()
            } else if !isCompletingAnimation {
                finalizeCompletedState(animated: false)
            }

        case .unavailable:
            isCompletingAnimation = false
            isSpinningQueued = false
            currentVisualProgress = 0.0
            trackLayer.isHidden = true
            progressLayer.isHidden = true
            centerSquareLayer.isHidden = true
            trackLayer.removeAllAnimations()
            progressLayer.removeAllAnimations()
            progressLayer.transform = CATransform3DIdentity
            centerSquareLayer.removeAllAnimations()
            centerSquareLayer.transform = CATransform3DIdentity
            isEnabled = false

            let unavailConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Unavailable")?.withSymbolConfiguration(unavailConfig)
            contentTintColor = NSColor.gray.withAlphaComponent(0.4)
            toolTip = "Song Unavailable"
        }
    }

    private func finalizeCompletedState(animated: Bool) {
        // Complete GPU layer cleanup and shutdown
        trackLayer.isHidden = true
        progressLayer.isHidden = true
        centerSquareLayer.isHidden = true
        trackLayer.removeAllAnimations()
        progressLayer.removeAllAnimations()
        progressLayer.transform = CATransform3DIdentity
        centerSquareLayer.removeAllAnimations()
        centerSquareLayer.transform = CATransform3DIdentity
        currentVisualProgress = 0.0
        isSpinningQueued = false

        let doneConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Downloaded")?.withSymbolConfiguration(doneConfig)
        contentTintColor = isDarkTheme() ? NSColor(white: 1.0, alpha: 1.0) : NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)

        if animated {
            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = 0.72
            spring.toValue = 1.0
            spring.damping = 13.0
            spring.stiffness = 260.0
            spring.duration = 0.32
            layer?.add(spring, forKey: "checkSpringPop")
        }
    }
}
