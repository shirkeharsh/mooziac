import AppKit
import QuartzCore

public final class NativeCapsuleStepToggleView: NSControl {
    public var stepIndex: Int = 0 {
        didSet {
            updateVisuals(animated: true)
        }
    }
    public var totalSteps: Int = 3 {
        didSet {
            updateVisuals(animated: false)
        }
    }
    public var onStep: ((Int) -> Void)?
    
    private let trackLayer = CALayer()
    private let knobLayer = CALayer()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: 32, height: 18))
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        trackLayer.frame = CGRect(x: 0, y: 0, width: 32, height: 18)
        trackLayer.cornerRadius = 9.0
        layer?.addSublayer(trackLayer)
        
        knobLayer.frame = CGRect(x: 2, y: 2, width: 14, height: 14)
        knobLayer.cornerRadius = 7.0
        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.shadowColor = NSColor.black.cgColor
        knobLayer.shadowOpacity = 0.25
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)
        knobLayer.shadowRadius = 1.5
        layer?.addSublayer(knobLayer)
        
        updateVisuals(animated: false)
    }
    
    public func updateVisuals(animated: Bool = true) {
        let isDark = (PlayerDesign.current == .darkMode)
        let isGlass = (PlayerDesign.current == .glassMode)
        let isLiquid = (PlayerDesign.current == .liquidFluid)
        
        let activeColor: CGColor
        if isLiquid {
            activeColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        } else if isDark {
            activeColor = NSColor.darkThemeSelector.cgColor
        } else if isGlass {
            activeColor = NSColor.lightThemeSelector.cgColor
        } else {
            activeColor = NSColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1.0).cgColor
        }
        let targetTrackColor = activeColor
        
        let minX: CGFloat = 2.0
        let maxX: CGFloat = 16.0
        let effectiveSteps = max(1, totalSteps - 1)
        let targetKnobX: CGFloat = minX + (CGFloat(stepIndex) / CGFloat(effectiveSteps)) * (maxX - minX)
        let targetKnobColor = isDark ? NSColor(white: 0.12, alpha: 1.0).cgColor : NSColor.white.cgColor
        
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.18)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            trackLayer.backgroundColor = targetTrackColor
            knobLayer.backgroundColor = targetKnobColor
            knobLayer.frame.origin.x = targetKnobX
            CATransaction.commit()
        } else {
            trackLayer.backgroundColor = targetTrackColor
            knobLayer.backgroundColor = targetKnobColor
            knobLayer.frame.origin.x = targetKnobX
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        let nextIndex = (stepIndex + 1) % max(1, totalSteps)
        stepIndex = nextIndex
        onStep?(stepIndex)
    }
}
