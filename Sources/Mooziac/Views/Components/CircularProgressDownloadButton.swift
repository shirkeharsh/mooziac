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
        trackLayer.strokeColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        trackLayer.lineWidth = 1.8
        trackLayer.lineCap = .round
        trackLayer.isHidden = true
        layer?.addSublayer(trackLayer)

        progressLayer.fillColor = nil
        progressLayer.strokeColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        progressLayer.lineWidth = 2.0
        progressLayer.lineCap = .round
        progressLayer.strokeStart = 0.0
        progressLayer.strokeEnd = 0.0
        progressLayer.isHidden = true
        layer?.addSublayer(progressLayer)

        centerSquareLayer.cornerRadius = 1.2
        centerSquareLayer.masksToBounds = true
        centerSquareLayer.backgroundColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
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
            case .adaptive, .native:
                return NSColor(white: 0.80, alpha: 1.0)
            case .darkMode:
                return NSColor(white: 0.85, alpha: 1.0)
            }
        }

        private func isDarkTheme() -> Bool {
            switch PlayerDesign.current {
            case .darkMode: return true
            case .glassMode: return false
            case .adaptive, .native:
                return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        }

    func updateVisuals() {
        let isLight = (PlayerDesign.current == .glassMode)
        let accentColor = isLight ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        let trackColor = isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : NSColor(white: 1.0, alpha: 0.20).cgColor

        trackLayer.strokeColor = trackColor
        progressLayer.strokeColor = accentColor.cgColor
        centerSquareLayer.backgroundColor = accentColor.cgColor

        switch downloadState {
        case .idleDownload:
            trackLayer.isHidden = true
            progressLayer.isHidden = true
            centerSquareLayer.isHidden = true
            centerSquareLayer.removeAnimation(forKey: "queuedPulse")
            isEnabled = true

            let dlConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Download Song")?.withSymbolConfiguration(dlConfig)
            contentTintColor = idleIconColor()
            toolTip = "Download to Offline Library"

        case .queued:
            trackLayer.isHidden = false
            progressLayer.isHidden = true
            progressLayer.strokeEnd = 0.0
            centerSquareLayer.isHidden = false
            isEnabled = true
            image = nil
            toolTip = "Waiting in download queue... — click to cancel"

            if centerSquareLayer.animation(forKey: "queuedPulse") == nil {
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 0.35
                pulse.toValue = 1.0
                pulse.duration = 0.8
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                centerSquareLayer.add(pulse, forKey: "queuedPulse")
            }

        case .downloading(let progress, let eta):
            trackLayer.isHidden = false
            progressLayer.isHidden = false
            centerSquareLayer.isHidden = false
            centerSquareLayer.removeAnimation(forKey: "queuedPulse")
            centerSquareLayer.opacity = 1.0
            isEnabled = true
            image = nil

            let pct = max(0.04, min(progress, 1.0))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = CGFloat(pct)
            CATransaction.commit()

            let pctInt = Int(pct * 100)
            toolTip = "Downloading (\(pctInt)%\(eta.isEmpty ? "" : " • ETA \(eta)")) — click to cancel"

        case .completed:
            trackLayer.isHidden = true
            progressLayer.isHidden = true
            centerSquareLayer.isHidden = true
            centerSquareLayer.removeAnimation(forKey: "queuedPulse")
            isEnabled = true

            let doneConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
            image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Downloaded")?.withSymbolConfiguration(doneConfig)
            contentTintColor = isDarkTheme() ? NSColor(white: 1.0, alpha: 1.0) : NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
            toolTip = "Downloaded (Available Offline)"

        case .unavailable:
            trackLayer.isHidden = true
            progressLayer.isHidden = true
            centerSquareLayer.isHidden = true
            centerSquareLayer.removeAnimation(forKey: "queuedPulse")
            isEnabled = false

            let unavailConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Unavailable")?.withSymbolConfiguration(unavailConfig)
            contentTintColor = NSColor.gray.withAlphaComponent(0.4)
            toolTip = "Song Unavailable"
        }
    }
}
