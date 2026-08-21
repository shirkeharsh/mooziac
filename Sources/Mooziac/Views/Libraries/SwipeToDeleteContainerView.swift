import AppKit
import QuartzCore

// MARK: - Global Swipe Action Coordinator
/// Coordinates swipe actions so only one row can be open at a time,
/// and automatically dismisses open swipe states on scrolling or outside interaction.
public final class SwipeActionCoordinator {
    public static let shared = SwipeActionCoordinator()

    private weak var activeSwipeView: SwipeToDeleteContainerView?

    private init() {
        // Close swiped rows when any scroll view starts scrolling
        NotificationCenter.default.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeAll()
        }

        NotificationCenter.default.addObserver(
            forName: NSScrollView.willStartLiveScrollNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeAll()
        }
    }

    public func registerOpen(_ view: SwipeToDeleteContainerView) {
        if let active = activeSwipeView, active !== view {
            active.close(animated: true)
        }
        activeSwipeView = view
    }

    public func unregisterOpen(_ view: SwipeToDeleteContainerView) {
        if activeSwipeView === view {
            activeSwipeView = nil
        }
    }

    public func closeAll(except view: SwipeToDeleteContainerView? = nil) {
        if let active = activeSwipeView, active !== view {
            active.close(animated: true)
            activeSwipeView = nil
        }
    }
}

// MARK: - Interactive Content Card View (Handles Mouse Drag & Click Responder Chain)
public class SwipeContentCardView: NSView {
    public weak var container: SwipeToDeleteContainerView?

    private var initialMouseLocation: NSPoint = .zero
    private var initialOffset: CGFloat = 0.0
    private var isMouseDragging = false
    private var dragThresholdPassed = false

    public override var isFlipped: Bool { return true }

    private func isInteractiveButton(_ view: NSView?) -> Bool {
        guard let view = view else { return false }
        if view is NSButton || view is ReactiveIconButton {
            return true
        }
        // Check superview in case click hit button's subview (e.g. image view inside button)
        if let parent = view.superview, parent is NSButton || parent is ReactiveIconButton {
            return true
        }
        return false
    }

    public override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let hitView = hitTest(localPoint)

        // If clicking a dedicated child button (like Options or Like), let the button handle it
        if isInteractiveButton(hitView) {
            if let container = container, container.isSwipedOpen {
                container.close(animated: true)
                return
            }
            super.mouseDown(with: event)
            return
        }

        guard let container = container else {
            super.mouseDown(with: event)
            return
        }

        initialMouseLocation = event.locationInWindow
        initialOffset = container.currentOffset
        isMouseDragging = false
        dragThresholdPassed = false

        // If already open, intercept click so mouseUp snaps it closed
        if container.isSwipedOpen {
            return
        }

        // Do not call super.mouseDown so NSTableView doesn't swallow mouseDragged
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let container = container else {
            super.mouseDragged(with: event)
            return
        }

        let deltaX = event.locationInWindow.x - initialMouseLocation.x
        let deltaY = event.locationInWindow.y - initialMouseLocation.y

        if !isMouseDragging {
            // Check if user initiated horizontal drag
            if abs(deltaX) >= 3.0 && abs(deltaX) > (abs(deltaY) * 0.7) {
                isMouseDragging = true
                dragThresholdPassed = true
                SwipeActionCoordinator.shared.closeAll(except: container)
                container.beginDragging()
            } else if abs(deltaY) > 6.0 {
                // Predominantly vertical drag -> forward to table view for scrolling
                super.mouseDragged(with: event)
                return
            }
        }

        if isMouseDragging {
            let rawOffset = initialOffset + deltaX
            container.handleDragOffset(rawOffset)
        } else {
            super.mouseDragged(with: event)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        guard let container = container else {
            super.mouseUp(with: event)
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        let hitView = hitTest(localPoint)

        if isInteractiveButton(hitView) && !isMouseDragging && !container.isSwipedOpen {
            super.mouseUp(with: event)
            return
        }

        if isMouseDragging {
            isMouseDragging = false
            container.endDragging()
        } else if container.isSwipedOpen {
            // Clicking open row closes it with smooth fade away
            container.close(animated: true)
        } else if !dragThresholdPassed {
            // Normal click without dragging
            container.onRowClicked?()
        }
    }
}

// MARK: - Swipe To Delete & Play Container View
/// A native Apple-style slide action container view.
/// Wraps any row content view, supporting:
/// - Left Swipe: Sleek Apple-style Delete action button (54pt width) with crisp white SF Symbol trash icon
/// - Right Swipe: Apple-style Play action (vibrant green with play.fill icon). If playlist is empty, shakes the card with haptic feedback!
/// - Smooth fade-in during swipe and graceful fade-away on release / dismiss
/// - Direct mouse click-and-drag horizontal swipe with spring physics & rubber-banding
/// - Trackpad 2-finger horizontal swipe and click-and-drag panning
/// - Full-swipe actions with elastic scale animation
/// - Single-open coordination across all lists
/// - Click-outside / click-to-close behavior
public class SwipeToDeleteContainerView: NSView, NSGestureRecognizerDelegate {

    // Callbacks
    public var onDelete: (() -> Void)?
    public var onRowClicked: (() -> Void)?
    /// Returns true if play succeeded, false if empty/failed (triggers shakeCard)
    public var onRightSwipePlay: (() -> Bool)?

    public var deleteButtonTitle: String = "Delete" {
        didSet {
            actionButton.toolTip = deleteButtonTitle
        }
    }

    // Compact Apple-standard action dimensions
    public var actionWidth: CGFloat = 54.0
    public var fullSwipeRatio: CGFloat = 0.50

    // Content container (this view slides horizontally)
    public let contentCardView = SwipeContentCardView()

    // Trailing (Delete) Action View (revealed on the right side)
    private let actionContainerView = NSView()
    private let actionButton = NSButton()
    private let trashIconView = NSImageView()

    // Leading (Play) Action View (revealed on the left side)
    private let leadingActionContainerView = NSView()
    private let playIconView = NSImageView()

    // Constraints for sliding contentCardView
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var actionLeadingConstraint: NSLayoutConstraint?
    private var leadingActionTrailingConstraint: NSLayoutConstraint?

    // Gesture State
    public private(set) var currentOffset: CGFloat = 0.0
    public private(set) var isSwipedOpen: Bool = false
    private var isTrackpadDragging: Bool = false
    private var startTrackpadOffset: CGFloat = 0.0

    // Tracking Area for Hover Effects
    private var trackingArea: NSTrackingArea?

    public override var isFlipped: Bool { return true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        SwipeActionCoordinator.shared.unregisterOpen(self)
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        // 1. Trailing Action Container (Vivid Apple Red #EB3338 for Delete)
        actionContainerView.translatesAutoresizingMaskIntoConstraints = false
        actionContainerView.wantsLayer = true
        actionContainerView.layer?.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0).cgColor
        actionContainerView.layer?.cornerRadius = 8
        actionContainerView.layer?.masksToBounds = true
        actionContainerView.alphaValue = 0.0 // Initially invisible when closed
        addSubview(actionContainerView)

        // Trash Icon (Crisp, centered SF Symbol trash.fill)
        trashIconView.translatesAutoresizingMaskIntoConstraints = false
        trashIconView.wantsLayer = true
        let trashConfig = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        trashIconView.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Delete")?.withSymbolConfiguration(trashConfig)
        trashIconView.contentTintColor = NSColor.white
        trashIconView.alphaValue = 0.0
        actionContainerView.addSubview(trashIconView)

        // Action Overlay Button (Interactive Delete Click)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isBordered = false
        actionButton.title = ""
        actionButton.target = self
        actionButton.action = #selector(handleDeleteButtonTapped)
        actionButton.wantsLayer = true
        actionButton.layer?.backgroundColor = NSColor.clear.cgColor
        actionButton.toolTip = deleteButtonTitle
        actionContainerView.addSubview(actionButton)

        // 2. Leading Action Container (Vivid Apple Green #34C759 for Play)
        leadingActionContainerView.translatesAutoresizingMaskIntoConstraints = false
        leadingActionContainerView.wantsLayer = true
        leadingActionContainerView.layer?.backgroundColor = NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0).cgColor
        leadingActionContainerView.layer?.cornerRadius = 8
        leadingActionContainerView.layer?.masksToBounds = true
        leadingActionContainerView.alphaValue = 0.0
        addSubview(leadingActionContainerView)

        // Play Icon (Crisp, centered SF Symbol play.fill)
        playIconView.translatesAutoresizingMaskIntoConstraints = false
        playIconView.wantsLayer = true
        let playConfig = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .bold)
        playIconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(playConfig)
        playIconView.contentTintColor = NSColor.white
        playIconView.alphaValue = 0.0
        leadingActionContainerView.addSubview(playIconView)

        // 3. Sliding Content Card View
        contentCardView.container = self
        contentCardView.translatesAutoresizingMaskIntoConstraints = false
        contentCardView.wantsLayer = true
        contentCardView.layer?.cornerRadius = 8
        contentCardView.layer?.masksToBounds = true
        addSubview(contentCardView)

        // Layout Constraints
        let cLead = contentCardView.leadingAnchor.constraint(equalTo: leadingAnchor)
        let cTrail = contentCardView.trailingAnchor.constraint(equalTo: trailingAnchor)
        contentLeadingConstraint = cLead
        contentTrailingConstraint = cTrail

        let aLead = actionContainerView.leadingAnchor.constraint(equalTo: trailingAnchor)
        actionLeadingConstraint = aLead

        let lTrail = leadingActionContainerView.trailingAnchor.constraint(equalTo: leadingAnchor)
        leadingActionTrailingConstraint = lTrail

        NSLayoutConstraint.activate([
            // Content View covers full container
            contentCardView.topAnchor.constraint(equalTo: topAnchor),
            contentCardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cLead,
            cTrail,

            // Trailing Action Container pinned to trailing edge
            actionContainerView.topAnchor.constraint(equalTo: topAnchor),
            actionContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            actionContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            aLead,

            // Trash Icon centered in actionContainerView
            trashIconView.centerXAnchor.constraint(equalTo: actionContainerView.centerXAnchor),
            trashIconView.centerYAnchor.constraint(equalTo: actionContainerView.centerYAnchor),
            trashIconView.widthAnchor.constraint(equalToConstant: 18),
            trashIconView.heightAnchor.constraint(equalToConstant: 18),

            // Delete button fills actionContainerView
            actionButton.topAnchor.constraint(equalTo: actionContainerView.topAnchor),
            actionButton.leadingAnchor.constraint(equalTo: actionContainerView.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: actionContainerView.trailingAnchor),
            actionButton.bottomAnchor.constraint(equalTo: actionContainerView.bottomAnchor),

            // Leading Action Container pinned to leading edge
            leadingActionContainerView.topAnchor.constraint(equalTo: topAnchor),
            leadingActionContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            leadingActionContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lTrail,

            // Play Icon centered in leadingActionContainerView
            playIconView.centerXAnchor.constraint(equalTo: leadingActionContainerView.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: leadingActionContainerView.centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 18),
            playIconView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    // MARK: - Drag State Management
    public func beginDragging() {
        SwipeActionCoordinator.shared.closeAll(except: self)
    }

    public func handleDragOffset(_ rawOffset: CGFloat) {
        if rawOffset > 0 {
            if onRightSwipePlay != nil {
                currentOffset = rawOffset
            } else {
                // Rubber-banding when right swipe is not configured
                currentOffset = rawOffset * 0.18
            }
        } else {
            // Sliding left
            currentOffset = rawOffset
        }

        updateOffset(animated: false)
        updateActionAppearanceForOffset(currentOffset)
    }

    public func endDragging() {
        if currentOffset < 0 {
            // Left Swipe (Delete)
            let dragDistance = -currentOffset
            let fullThreshold = bounds.width * fullSwipeRatio

            if dragDistance >= fullThreshold {
                performFullSwipeDelete()
            } else if dragDistance >= (actionWidth * 0.40) {
                open(animated: true)
            } else {
                close(animated: true)
            }
        } else if currentOffset > 0 {
            // Right Swipe (Play)
            let dragDistance = currentOffset
            let triggerThreshold = min(actionWidth * 0.70, bounds.width * 0.35)

            if dragDistance >= triggerThreshold, let playHandler = onRightSwipePlay {
                // Execute play action
                let playSuccess = playHandler()
                close(animated: true)
                if !playSuccess {
                    shakeCard()
                } else {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            } else {
                close(animated: true)
            }
        }
    }

    // MARK: - Trackpad Two-Finger Swipe Handling (scrollWheel)
    public override func scrollWheel(with event: NSEvent) {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        // If predominantly vertical scroll, pass to table view
        if abs(deltaY) > abs(deltaX) && !isTrackpadDragging && !isSwipedOpen {
            super.scrollWheel(with: event)
            return
        }

        switch event.phase {
        case .began, .mayBegin:
            if abs(deltaX) > abs(deltaY) {
                SwipeActionCoordinator.shared.closeAll(except: self)
                startTrackpadOffset = currentOffset
                isTrackpadDragging = true
            } else {
                super.scrollWheel(with: event)
                return
            }

        case .changed:
            if isTrackpadDragging || abs(deltaX) > 1.5 {
                isTrackpadDragging = true
                let adjustedDelta = event.isDirectionInvertedFromDevice ? deltaX : -deltaX
                let newOffset = currentOffset - (adjustedDelta * 0.85)

                if newOffset > 0 {
                    if onRightSwipePlay != nil {
                        currentOffset = newOffset
                    } else {
                        currentOffset = newOffset * 0.18
                    }
                } else {
                    currentOffset = newOffset
                }

                updateOffset(animated: false)
                updateActionAppearanceForOffset(currentOffset)
            }

        case .ended, .cancelled:
            if isTrackpadDragging {
                isTrackpadDragging = false
                endDragging()
            } else {
                super.scrollWheel(with: event)
            }

        default:
            if event.momentumPhase == .began || event.momentumPhase == .changed {
                if !isTrackpadDragging {
                    super.scrollWheel(with: event)
                }
            } else {
                super.scrollWheel(with: event)
            }
        }
    }

    // MARK: - Open / Close Actions
    public func open(animated: Bool = true) {
        currentOffset = -actionWidth
        isSwipedOpen = true
        SwipeActionCoordinator.shared.registerOpen(self)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                self.actionContainerView.animator().alphaValue = 1.0
                self.trashIconView.animator().alphaValue = 1.0
                self.updateOffset(animated: true)
            }
        } else {
            actionContainerView.alphaValue = 1.0
            trashIconView.alphaValue = 1.0
            updateOffset(animated: false)
        }

        updateActionAppearanceForOffset(currentOffset)
    }

    public func close(animated: Bool = true) {
        currentOffset = 0
        isSwipedOpen = false
        SwipeActionCoordinator.shared.unregisterOpen(self)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                self.actionContainerView.animator().alphaValue = 0.0
                self.trashIconView.animator().alphaValue = 0.0
                self.trashIconView.layer?.transform = CATransform3DIdentity
                self.leadingActionContainerView.animator().alphaValue = 0.0
                self.playIconView.animator().alphaValue = 0.0
                self.playIconView.layer?.transform = CATransform3DIdentity
                self.updateOffset(animated: true)
            }
        } else {
            actionContainerView.alphaValue = 0.0
            trashIconView.alphaValue = 0.0
            trashIconView.layer?.transform = CATransform3DIdentity
            leadingActionContainerView.alphaValue = 0.0
            playIconView.alphaValue = 0.0
            playIconView.layer?.transform = CATransform3DIdentity
            updateOffset(animated: false)
        }
    }

    private func updateOffset(animated: Bool) {
        contentLeadingConstraint?.constant = currentOffset
        contentTrailingConstraint?.constant = currentOffset

        if currentOffset <= 0 {
            let actionW = max(actionWidth, -currentOffset)
            actionLeadingConstraint?.constant = -actionW
            leadingActionTrailingConstraint?.constant = 0
        } else {
            let leadW = max(actionWidth, currentOffset)
            leadingActionTrailingConstraint?.constant = leadW
            actionLeadingConstraint?.constant = 0
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                self.layoutSubtreeIfNeeded()
            }
        } else {
            self.layoutSubtreeIfNeeded()
        }
    }

    private func updateActionAppearanceForOffset(_ offset: CGFloat) {
        if offset < 0 {
            // Left Swipe (Delete)
            let distance = -offset
            let isPastFullSwipe = distance >= (bounds.width * fullSwipeRatio)
            let revealProgress = max(0.0, min(1.0, distance / max(1.0, actionWidth * 0.75)))

            actionContainerView.alphaValue = revealProgress
            trashIconView.alphaValue = revealProgress
            leadingActionContainerView.alphaValue = 0.0
            playIconView.alphaValue = 0.0

            if isPastFullSwipe {
                trashIconView.contentTintColor = NSColor.white
                actionContainerView.layer?.backgroundColor = NSColor(red: 0.82, green: 0.12, blue: 0.15, alpha: 1.0).cgColor
                trashIconView.layer?.transform = CATransform3DMakeScale(1.22, 1.22, 1.0)
            } else {
                trashIconView.contentTintColor = NSColor.white
                actionContainerView.layer?.backgroundColor = NSColor(red: 0.92, green: 0.20, blue: 0.22, alpha: 1.0).cgColor
                trashIconView.layer?.transform = CATransform3DIdentity
            }
        } else if offset > 0 {
            // Right Swipe (Play)
            let distance = offset
            let isPastFullSwipe = distance >= (bounds.width * fullSwipeRatio)
            let revealProgress = max(0.0, min(1.0, distance / max(1.0, actionWidth * 0.75)))

            leadingActionContainerView.alphaValue = revealProgress
            playIconView.alphaValue = revealProgress
            actionContainerView.alphaValue = 0.0
            trashIconView.alphaValue = 0.0

            if isPastFullSwipe {
                playIconView.layer?.transform = CATransform3DMakeScale(1.22, 1.22, 1.0)
            } else {
                playIconView.layer?.transform = CATransform3DIdentity
            }
        } else {
            actionContainerView.alphaValue = 0.0
            trashIconView.alphaValue = 0.0
            leadingActionContainerView.alphaValue = 0.0
            playIconView.alphaValue = 0.0
        }
    }

    // MARK: - Delete Triggers
    @objc private func handleDeleteButtonTapped() {
        performDeleteAnimationAndAction()
    }

    private func performFullSwipeDelete() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        currentOffset = -bounds.width - 24
        updateOffset(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }
            self.close(animated: false)
            self.onDelete?()
        }
    }

    public func performDeleteAnimationAndAction() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        currentOffset = -bounds.width - 24
        updateOffset(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }
            self.close(animated: false)
            self.onDelete?()
        }
    }

    // MARK: - Shake Animation (Apple-Style Error Feedback)
    public func shakeCard() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.duration = 0.38
        shake.values = [0, -14, 12, -10, 8, -4, 2, 0]
        shake.keyTimes = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 1.0]
        contentCardView.layer?.add(shake, forKey: "shake")
    }
}
