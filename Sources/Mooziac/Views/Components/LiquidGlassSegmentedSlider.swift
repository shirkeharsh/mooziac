import AppKit

/// Semantic light/dark tone for the adaptive Settings & Options panel and its controls.
enum SettingsTone {
    case dark
    case light

    var usesDarkThreshold: Bool { self == .light }

    // MARK: Adaptive palette

    var primaryText: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.95, alpha: 1.0)
        case .light: return NSColor(srgbRed: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
        }
    }

    var secondaryText: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.60, alpha: 1.0)
        case .light: return NSColor(srgbRed: 0.11, green: 0.11, blue: 0.11, alpha: 0.56)
        }
    }

    var iconColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.88, alpha: 1.0)
        case .light: return NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.72)
        }
    }

    var dividerColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 1.0, alpha: 0.14)
        case .light: return NSColor(white: 0.0, alpha: 0.14)
        }
    }

    var sliderTrackBackground: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.12, alpha: 0.65)
        case .light: return NSColor(white: 0.88, alpha: 0.65)
        }
    }

    var sliderTrackBorder: NSColor {
        switch self {
        case .dark: return NSColor(white: 1.0, alpha: 0.14)
        case .light: return NSColor(white: 0.0, alpha: 0.12)
        }
    }

    var systemAppearance: NSAppearance? {
        switch self {
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        }
    }
}

/// A liquid-glass segmented control with a sliding translucent glass thumb,
/// smooth spring animations, and full native theme adaptability.
final class LiquidSegmentedControl: NSView {

    struct Segment {
        let icon: String?
        let title: String

        init(icon: String? = nil, title: String) {
            self.icon = icon
            self.title = title
        }
    }

    var onSelect: ((Int) -> Void)?
    private(set) var selectedIndex: Int = 0

    var tone: SettingsTone = .dark {
        didSet {
            applyTone()
        }
    }

    private let segments: [Segment]
    private static let horizontalPad: CGFloat = 3
    private static let thumbInset: CGFloat = 3

    private let thumbView = NSVisualEffectView()
    private let thumbHighlight = CAGradientLayer()
    private var labelContainers: [NSView] = []
    private var labelIconViews: [NSImageView] = []
    private var labelTitleFields: [NSTextField] = []

    convenience init() {
        self.init(segments: [
            Segment(icon: "sun.max.fill", title: "Light"),
            Segment(icon: "circle.lefthalf.filled", title: "System"),
            Segment(icon: "moon.fill", title: "Dark")
        ], defaultIndex: 1)
    }

    init(segments: [Segment], defaultIndex: Int = 0) {
        self.segments = segments
        self.selectedIndex = max(0, min(segments.count - 1, defaultIndex))
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        self.segments = []
        super.init(coder: coder)
        setupUI()
    }

    override var isFlipped: Bool { true }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = false
        layer?.borderWidth = 1.0

        // Movable glass thumb
        thumbView.material = .hudWindow
        thumbView.blendingMode = .withinWindow
        thumbView.state = .active
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 6
        thumbView.layer?.borderWidth = 1.0

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 3.0
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        thumbView.shadow = shadow

        addSubview(thumbView)

        // Specular highlight gradient
        thumbHighlight.locations = [0.0, 0.7]
        thumbHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        thumbHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        thumbView.layer?.addSublayer(thumbHighlight)

        // Labels
        for segment in segments {
            let container = PassThroughView()
            var views: [NSView] = []

            let iconView = NSImageView()
            if let icon = segment.icon {
                let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
                if let image = NSImage(systemSymbolName: icon, accessibilityDescription: segment.title)?.withSymbolConfiguration(config) {
                    iconView.image = image
                }
                iconView.translatesAutoresizingMaskIntoConstraints = false
                iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
                iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true
                views.append(iconView)
            }

            let label = NSTextField(labelWithString: segment.title)
            label.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
            label.isEditable = false
            label.isSelectable = false
            label.refusesFirstResponder = true
            label.alignment = .center
            views.append(label)

            let stack = NSStackView(views: views)
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            labelContainers.append(container)
            labelIconViews.append(iconView)
            labelTitleFields.append(label)
            addSubview(container)
        }

        applyTone()
    }

    func applyTone() {
        let dark = (tone == .dark)
        layer?.backgroundColor = tone.sliderTrackBackground.cgColor
        layer?.borderColor = tone.sliderTrackBorder.cgColor

        thumbView.appearance = tone.systemAppearance
        thumbView.layer?.borderColor = (dark
            ? NSColor.white.withAlphaComponent(0.28)
            : NSColor.black.withAlphaComponent(0.20)).cgColor

        thumbHighlight.colors = [
            (dark
                ? NSColor.white.withAlphaComponent(0.35)
                : NSColor.white.withAlphaComponent(0.60)).cgColor,
            NSColor.white.withAlphaComponent(0.05).cgColor
        ]

        updateLabelColors()
        needsDisplay = true
    }

    private func updateLabelColors() {
        let selectedColor = (PlayerDesign.current == .glassMode)
            ? NSColor.lightThemeSelector
            : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        let unselectedColor = tone.secondaryText

        for (i, field) in labelTitleFields.enumerated() {
            field.textColor = (i == selectedIndex) ? selectedColor : unselectedColor
        }
        for (i, icon) in labelIconViews.enumerated() {
            icon.contentTintColor = (i == selectedIndex) ? selectedColor : unselectedColor
        }
    }

    private func thumbWidth() -> CGFloat {
        guard !segments.isEmpty else { return 0 }
        let totalW = bounds.width - Self.horizontalPad * 2
        return max(1, totalW / CGFloat(segments.count))
    }

    private func thumbHeight() -> CGFloat {
        return max(1, bounds.height - Self.thumbInset * 2)
    }

    private func xFor(index: Int) -> CGFloat {
        let w = thumbWidth()
        return Self.horizontalPad + CGFloat(index) * w
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        placeThumb(animated: false)
        placeLabels()
        upkeepThumbVisuals()
    }

    private func placeThumb(animated: Bool) {
        let w = thumbWidth()
        let h = thumbHeight()
        let x = xFor(index: selectedIndex)
        let targetRect = NSRect(x: x, y: Self.thumbInset, width: w, height: h)
        thumbView.layer?.cornerRadius = h / 2
        thumbHighlight.frame = thumbView.bounds
        thumbHighlight.cornerRadius = h / 2
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                thumbView.animator().frame = targetRect
            }
        } else {
            thumbView.frame = targetRect
        }
    }

    private func placeLabels() {
        guard !segments.isEmpty else { return }
        let segWidth = bounds.width / CGFloat(segments.count)
        for (i, view) in labelContainers.enumerated() {
            view.frame = NSRect(x: segWidth * CGFloat(i), y: 0, width: segWidth, height: bounds.height)
        }
    }

    private func upkeepThumbVisuals() {
        thumbHighlight.frame = thumbView.bounds
        thumbHighlight.cornerRadius = thumbView.bounds.height / 2
    }

    func setSelectedIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < segments.count else { return }
        selectedIndex = index
        placeThumb(animated: animated)
        updateLabelColors()
    }

    override func mouseDown(with event: NSEvent) {
        guard !segments.isEmpty else { return }
        let location = convert(event.locationInWindow, from: nil)
        let segWidth = max(1, bounds.width / CGFloat(segments.count))
        var index = Int(location.x / segWidth)
        index = max(0, min(segments.count - 1, index))
        guard index != selectedIndex else { return }
        selectedIndex = index
        placeThumb(animated: true)
        updateLabelColors()
        onSelect?(index)
    }
}

private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

typealias LiquidGlassSegmentedSlider = LiquidSegmentedControl
