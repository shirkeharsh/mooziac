import AppKit
import QuartzCore

final class NativeCapsuleToggleView: NSControl {
    var isOn: Bool = false {
        didSet {
            updateVisuals(animated: true)
        }
    }
    var onToggle: ((Bool) -> Void)?
    
    /// When true, renders with native macOS menu bar styling regardless of player theme
    var isMenuContext: Bool = false {
        didSet {
            updateVisuals(animated: false)
        }
    }
    
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
        if isMenuContext {
            let isDarkMenu = SystemAppearanceHelper.isDarkSystemAppearance
            let targetTrackColor: CGColor
            let targetKnobColor: CGColor
            
            if isOn {
                targetTrackColor = NSColor(hex: "E5E5EA").cgColor
                targetKnobColor = NSColor(white: 0.14, alpha: 1.0).cgColor
            } else {
                targetTrackColor = isDarkMenu
                    ? NSColor(white: 1.0, alpha: 0.16).cgColor
                    : NSColor(white: 0.0, alpha: 0.12).cgColor
                targetKnobColor = NSColor.white.cgColor
            }
            
            applyColors(trackColor: targetTrackColor, knobColor: targetKnobColor, knobX: isOn ? 16.0 : 2.0, animated: animated)
            return
        }
        
        let isAdaptive = (PlayerDesign.current == .adaptive)
        let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        
        let targetTrackColor: CGColor
        let targetKnobColor: CGColor
        
        if isAdaptive {
            // Adaptive theme: Signature Electric Cyan/Blue
            targetTrackColor = isOn ? NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor : (isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : NSColor(white: 1.0, alpha: 0.14).cgColor)
            targetKnobColor = NSColor.white.cgColor
        } else {
            // Other themes (OLED Dark Mode, Crystal Glass, Watery Transparent): Native Apple greyish-white
            if isOn {
                targetTrackColor = NSColor(hex: "E2E5EB").cgColor
                targetKnobColor = NSColor(white: 0.12, alpha: 1.0).cgColor
            } else {
                targetTrackColor = isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : NSColor(white: 1.0, alpha: 0.14).cgColor
                targetKnobColor = NSColor.white.cgColor
            }
        }
        
        applyColors(trackColor: targetTrackColor, knobColor: targetKnobColor, knobX: isOn ? 16.0 : 2.0, animated: animated)
    }
    
    private func applyColors(trackColor: CGColor, knobColor: CGColor, knobX: CGFloat, animated: Bool) {
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.18)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            trackLayer.backgroundColor = trackColor
            knobLayer.backgroundColor = knobColor
            knobLayer.frame.origin.x = knobX
            CATransaction.commit()
        } else {
            trackLayer.backgroundColor = trackColor
            knobLayer.backgroundColor = knobColor
            knobLayer.frame.origin.x = knobX
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
    }
}
