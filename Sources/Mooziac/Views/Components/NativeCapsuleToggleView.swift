import AppKit
import QuartzCore

final class NativeCapsuleToggleView: NSControl {
    var isOn: Bool = false {
        didSet {
            updateVisuals(animated: true)
        }
    }
    var onToggle: ((Bool) -> Void)?
    
    private let trackLayer = CALayer()
    private let knobLayer = CALayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: 32, height: 18))
        setupUI()
    }
    
    required init?(coder: NSCoder) {
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
        let isNative = (PlayerDesign.current == .native)
        
        let activeColor: CGColor
        if isNative {
            activeColor = NSColor.white.cgColor
        } else if isDark {
            activeColor = NSColor.darkThemeSelector.cgColor
        } else if isGlass {
            activeColor = NSColor.lightThemeSelector.cgColor
        } else {
            activeColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        }
        
        let inactiveTrackColor: CGColor
        if isNative {
            inactiveTrackColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        } else if isGlass {
            inactiveTrackColor = NSColor(white: 0.0, alpha: 0.14).cgColor
        } else {
            inactiveTrackColor = NSColor(white: 0.28, alpha: 1.0).cgColor
        }
        
        let targetTrackColor = isOn ? activeColor : inactiveTrackColor
        let targetKnobX: CGFloat = isOn ? 16.0 : 2.0
        let targetKnobColor: CGColor
        if isOn && (isNative || isDark) {
            targetKnobColor = NSColor(white: 0.12, alpha: 1.0).cgColor
        } else {
            targetKnobColor = NSColor.white.cgColor
        }
        
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
    
    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
    }
}
