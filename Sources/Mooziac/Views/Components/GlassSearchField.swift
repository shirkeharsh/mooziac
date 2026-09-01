import AppKit

final class GlassSearchFieldCell: NSSearchFieldCell {
    override init(textCell aString: String) {
        super.init(textCell: aString)
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        searchButtonCell = nil
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        searchButtonCell = nil
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Suppress default focus ring mask
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let editor = super.setUpFieldEditorAttributes(textObj)
        editor.drawsBackground = false
        editor.backgroundColor = .clear
        if let textView = editor as? NSTextView {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
            let color = isLight ? NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0) : NSColor.white
            textView.insertionPointColor = color
            textView.textColor = color
        }
        return editor
    }
    
    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        guard searchButtonCell != nil else { return .zero }
        let size: CGFloat = 12
        return NSRect(
            x: rect.origin.x + 8.5,
            y: rect.origin.y + floor((rect.height - size) / 2.0),
            width: size,
            height: size
        )
    }
    
    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        let fontHeight: CGFloat = 14.0
        let yOffset = max(0, floor((rect.height - fontHeight) / 2.0))
        let hasCancel = (cancelButtonCell != nil && !stringValue.isEmpty)
        let leftInset: CGFloat = (searchButtonCell != nil) ? 26.0 : 10.0
        let rightInset: CGFloat = hasCancel ? 26.0 : 10.0
        return NSRect(
            x: rect.origin.x + leftInset,
            y: rect.origin.y + yOffset,
            width: max(0, rect.width - leftInset - rightInset),
            height: fontHeight
        )
    }
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return searchTextRect(forBounds: rect)
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return searchTextRect(forBounds: rect)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        textObj.drawsBackground = false
        textObj.backgroundColor = .clear
        if let textView = textObj as? NSTextView {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }
        super.edit(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        textObj.drawsBackground = false
        textObj.backgroundColor = .clear
        if let textView = textObj as? NSTextView {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }
        super.select(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func cancelButtonRect(forBounds rect: NSRect) -> NSRect {
        let size: CGFloat = 12
        return NSRect(
            x: rect.origin.x + rect.width - size - 8.5,
            y: rect.origin.y + floor((rect.height - size) / 2.0),
            width: size,
            height: size
        )
    }
}

public class GlassSearchField: NSSearchField {
    public var onFocusChange: ((_ isFocused: Bool) -> Void)?

    public var customCornerRadius: CGFloat?
    public var customIdleBorderColor: CGColor?
    public var customIdleBgColor: CGColor?
    public var customFocusBorderColor: CGColor?
    public var customFocusBgColor: CGColor?

    public override class var cellClass: AnyClass? {
        get { GlassSearchFieldCell.self }
        set { super.cellClass = newValue }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlassStyle()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassStyle()
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        cell?.drawInterior(withFrame: bounds, in: self)
    }
    
    private func setupGlassStyle() {
        wantsLayer = true
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none // Removes macOS default thick bright blue focus ring
        if let cell = self.cell as? NSSearchFieldCell {
            cell.isBezeled = false
            cell.isBordered = false
            cell.drawsBackground = false
            cell.focusRingType = .none
        }
        font = NSFont.systemFont(ofSize: 11, weight: .medium)
        applyTheme(PlayerDesign.current)
    }

    func applyPlaylistContainerStyle(tone: SettingsTone) {
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        if let cell = self.cell as? NSSearchFieldCell {
            cell.isBezeled = false
            cell.isBordered = false
            cell.drawsBackground = false
            cell.focusRingType = .none
        }
        customCornerRadius = 14.0
        layer?.cornerRadius = 14.0
        layer?.borderWidth = 1.0
        
        let isLight = (tone == .light)
        let idleBorder = isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : tone.dividerColor.cgColor
        let idleBg = isLight ? NSColor.white.cgColor : NSColor(white: 1.0, alpha: 0.06).cgColor
        let focusBorder = isLight ? NSColor.lightThemeSelector.cgColor : NSColor(white: 1.0, alpha: 0.28).cgColor
        let focusBg = isLight ? NSColor.white.cgColor : NSColor(white: 1.0, alpha: 0.10).cgColor
        
        customIdleBorderColor = idleBorder
        customIdleBgColor = idleBg
        customFocusBorderColor = focusBorder
        customFocusBgColor = focusBg
        
        textColor = tone.primaryText
        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: isLight ? NSColor(white: 0.40, alpha: 0.90) : tone.secondaryText,
            .font: NSFont.systemFont(ofSize: 11.0, weight: .medium)
        ]
        placeholderAttributedString = NSAttributedString(string: placeholderString ?? "Search", attributes: placeholderAttrs)
        
        if isFocusedState {
            layer?.borderColor = focusBorder
            layer?.backgroundColor = focusBg
        } else {
            layer?.borderColor = idleBorder
            layer?.backgroundColor = idleBg
        }
    }

    public func applyTheme(_ design: PlayerDesign) {
        if let _ = customIdleBorderColor {
            return
        }
        let isLight = (design == .glassMode || (design == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        if isLight {
            textColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
            layer?.backgroundColor = NSColor.white.cgColor
            layer?.borderColor = NSColor(white: 0.0, alpha: 0.14).cgColor
            layer?.borderWidth = 1.0
            layer?.cornerRadius = customCornerRadius ?? 8.0
            let placeholderAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 0.40, alpha: 0.90),
                .font: NSFont.systemFont(ofSize: 11.0, weight: .medium)
            ]
            placeholderAttributedString = NSAttributedString(string: placeholderString ?? "Search", attributes: placeholderAttrs)
        } else {
            textColor = NSColor.white
            layer?.backgroundColor = NSColor(white: 0.16, alpha: 0.45).cgColor
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
            layer?.borderWidth = 1.0
            layer?.cornerRadius = customCornerRadius ?? 8.0
            let placeholderAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 0.70, alpha: 0.85),
                .font: NSFont.systemFont(ofSize: 11.0, weight: .medium)
            ]
            placeholderAttributedString = NSAttributedString(string: placeholderString ?? "Search", attributes: placeholderAttrs)
        }
    }
    
    public override var placeholderString: String? {
        didSet {
            let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
            let color = isLight ? NSColor(white: 0.40, alpha: 0.90) : NSColor(white: 0.70, alpha: 0.85)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 11.0, weight: .medium)
            ]
            placeholderAttributedString = NSAttributedString(string: placeholderString ?? "Search", attributes: attrs)
        }
    }
    
    private var isFocusedState = false

    public override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok && !isFocusedState {
            isFocusedState = true
            onFocusChange?(true)
            if let editor = currentEditor() as? NSTextView {
                editor.drawsBackground = false
                editor.backgroundColor = .clear
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
                let defaultFocusBorder = isLight ? NSColor.lightThemeSelector.cgColor : NSColor(white: 1.0, alpha: 0.28).cgColor
                let defaultFocusBg = isLight ? NSColor.white.cgColor : NSColor(white: 0.16, alpha: 0.65).cgColor
                layer?.borderColor = customFocusBorderColor ?? defaultFocusBorder
                layer?.backgroundColor = customFocusBgColor ?? defaultFocusBg
                layer?.borderWidth = 1.0
            }
        }
        return ok
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "v":
                if let pastedString = NSPasteboard.general.string(forType: .string) {
                    if URLFilter.containsLink(pastedString) {
                        self.stringValue = ""
                        if let delegate = self.delegate as? DynamicIslandPlayerView {
                            delegate.showToastBanner(message: "⚠️ Links/URLs are not allowed in search", isWarning: true)
                        }
                        return true
                    }
                    if let editor = currentEditor() as? NSTextView {
                        editor.insertText(pastedString, replacementRange: editor.selectedRange())
                        return true
                    }
                }
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "z":
                return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok && isFocusedState {
            isFocusedState = false
            onFocusChange?(false)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                let isLight = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
                let defaultIdleBorder = isLight ? NSColor(white: 0.0, alpha: 0.14).cgColor : NSColor(white: 1.0, alpha: 0.16).cgColor
                let defaultIdleBg = isLight ? NSColor.white.cgColor : NSColor(white: 0.12, alpha: 0.35).cgColor
                layer?.borderColor = customIdleBorderColor ?? defaultIdleBorder
                layer?.backgroundColor = customIdleBgColor ?? defaultIdleBg
                layer?.borderWidth = 1.0
            }
        }
        return ok
    }
}
