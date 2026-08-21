import AppKit
import SwiftUI

@MainActor
final class LaunchAnimationController {
    public static let shared = LaunchAnimationController()

    private let timeline = LaunchAnimationTimeline()
    private let sound = ClickSound()

    private var panel: NSPanel?
    private var model: LaunchOverlayModel?
    private var task: Task<Void, Never>?

    var isPlaying: Bool { task != nil }

    func play(completion: @escaping () -> Void = {}) {
        guard !isPlaying else { return }
        guard let screen = NSScreen.main else {
            completion()
            return
        }

        let model = LaunchOverlayModel()
        
        // Calculate exact target status bar button position dynamically
        if let center = StatusItemManager.shared?.statusButtonCenterInScreen {
            let targetX = center.x - (screen.frame.width / 2.0)
            let targetY = -(center.y - (screen.frame.height / 2.0))
            model.targetOffsetX = targetX
            model.targetOffsetY = targetY
        } else {
            // Default top-right menu bar area
            model.targetOffsetX = screen.frame.width * 0.35
            model.targetOffsetY = -(screen.frame.height / 2.0 - 18.0)
        }

        let panel = makePanel(on: screen, model: model)
        self.model = model
        self.panel = panel

        panel.orderFrontRegardless()

        task = Task { [timeline] in
            await run(timeline, model: model, screen: screen)
            finish()
            completion()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        finish()
    }

    private func computeStatusItemTarget(on screen: NSScreen) -> (x: Double, y: Double) {
        if let center = StatusItemManager.shared?.statusButtonCenterInScreen, center.x > 0, center.y > 0 {
            let targetX = center.x - (screen.frame.width / 2.0)
            let targetY = -(center.y - (screen.frame.height / 2.0))
            return (targetX, targetY)
        }
        
        for window in NSApplication.shared.windows {
            let className = String(describing: type(of: window))
            if className.contains("Status") || className.contains("StatusBar") {
                let frame = window.frame
                if frame.minY >= screen.frame.height - 60 && frame.midX > 0 {
                    let targetX = frame.midX - (screen.frame.width / 2.0)
                    let targetY = -(frame.midY - (screen.frame.height / 2.0))
                    return (targetX, targetY)
                }
            }
        }
        
        let fallbackX = (screen.frame.width * 0.38)
        let fallbackY = -(screen.frame.height / 2.0 - 14.0)
        return (fallbackX, fallbackY)
    }

    private func run(_ timeline: LaunchAnimationTimeline, model: LaunchOverlayModel, screen: NSScreen) async {
        // Phase 1: Fade In & Center Breath Pulse (0.0s - 0.30s)
        withAnimation(.easeOut(duration: 0.30)) {
            model.opacity = 1.0
            model.logoOpacity = 1.0
            model.logoScale = 1.0
            model.edgeGlowOpacity = 0.45
        }
        
        guard await sleep(0.30) else { return }
        
        // Gentle breath pulse in the center
        withAnimation(.easeInOut(duration: 0.22)) {
            model.logoScale = 1.08
        }
        
        guard await sleep(0.22) else { return }
        
        // Calculate exact target status bar button position dynamically (guaranteed laid out after 0.52s!)
        let target = computeStatusItemTarget(on: screen)
        model.targetOffsetX = target.x
        model.targetOffsetY = target.y
        
        // Phase 2: Dynamic Flight & Shrink Upward to EXACT Status Bar Icon Position!
        sound.play()
        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
            model.logoOffsetX = target.x // Glides dynamically to exact status item X!
            model.logoOffsetY = target.y // Glides dynamically to exact status item Y!
            model.logoScale = 0.075     // Shrinks down from 380px to 28px!
            model.edgeGlowOpacity = 0.0 // Dissolves edge glow during flight
        }
        
        guard await sleep(0.52) else { return }
        
        // Phase 3: Magical Swoosh Sparkle Burst at Status Bar Level (1.04s - 1.40s)
        StatusItemManager.shared?.playLaunchPopAnimation()
        withAnimation(.easeOut(duration: 0.28)) {
            model.sparkleScale = 2.4
            model.sparkleOpacity = 0.95
            model.logoOpacity = 0.0
        }
        
        withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
            model.sparkleOpacity = 0.0
            model.opacity = 0.0
        }
        
        _ = await sleep(0.35)
    }

    private func sleep(_ duration: TimeInterval) async -> Bool {
        guard duration > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    private func finish() {
        sound.stop()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        model = nil
        task = nil
    }

    private func makePanel(on screen: NSScreen, model: LaunchOverlayModel) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: LaunchOverlayView(model: model))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.setFrame(screen.frame, display: false)
        return panel
    }
}
