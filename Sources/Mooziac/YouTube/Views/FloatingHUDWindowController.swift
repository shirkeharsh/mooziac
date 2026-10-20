import AppKit
import QuartzCore

public class FloatingHUDWindowController: NSWindowController {
    public static let shared = FloatingHUDWindowController()

    private let containerView = NSView()
    private let textLabel = NSTextField(labelWithString: "")
    private var dismissTimer: Timer?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 28),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false

        super.init(window: window)
        setupUI()
        window.orderOut(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        window.contentView = contentView

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(white: 0.10, alpha: 0.88).cgColor
        containerView.layer?.cornerRadius = 14.0
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor
        containerView.layer?.masksToBounds = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        textLabel.textColor = NSColor(white: 0.98, alpha: 0.98)
        textLabel.alignment = .center
        textLabel.maximumNumberOfLines = 1
        textLabel.usesSingleLineMode = true
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.stringValue = ""

        containerView.addSubview(textLabel)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            textLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            textLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 14),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -14)
        ])
    }

    public func showVolumeOverlay(volumePercent: Int) {
        let text = volumePercent == 0 ? "Muted" : "Volume: \(volumePercent)%"
        showCustomTextOverlay(text: text)
    }

    public func showCustomTextOverlay(text: String, duration: TimeInterval = 1.3) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }

            self.dismissTimer?.invalidate()
            self.textLabel.stringValue = text

            let font = self.textLabel.font ?? NSFont.systemFont(ofSize: 12.5, weight: .semibold)
            let fontAttributes = [NSAttributedString.Key.font: font]
            let textWidth = (text as NSString).size(withAttributes: fontAttributes).width
            let targetWidth = min(max(ceil(textWidth) + 36.0, 150), 320)

            self.reposition(width: targetWidth)

            if !window.isVisible {
                window.alphaValue = 0.0
                window.orderFront(nil)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    window.animator().alphaValue = 1.0
                }
            } else {
                window.animator().alphaValue = 1.0
            }

            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                guard let self = self, let window = self.window else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.25
                    window.animator().alphaValue = 0.0
                }, completionHandler: {
                    window.orderOut(nil)
                })
            }
        }
    }

    private func reposition(width: CGFloat) {
        guard let window = window else { return }
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        guard let screen = targetScreen else { return }

        let screenRect = screen.frame
        let visibleRect = screen.visibleFrame
        let topBarHeight = max(24, screenRect.maxY - visibleRect.maxY)

        let x = screenRect.midX - (width / 2.0)
        let y = screenRect.maxY - topBarHeight - 34

        let newFrame = NSRect(x: x, y: y, width: width, height: 28)
        if window.frame != newFrame {
            window.setFrame(newFrame, display: true)
        }
    }
}
