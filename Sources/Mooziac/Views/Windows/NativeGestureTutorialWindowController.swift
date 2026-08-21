import AppKit
import WebKit

final class NativeGestureTutorialWindowController: NSWindowController {
    static let shared = NativeGestureTutorialWindowController()
    
    private var webView: WKWebView!
    
    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        
        self.init(window: panel)
        setupUI(window: panel)
    }
    
    private func setupUI(window: NSWindow) {
        // DIRECT PITCH BLACK CONTAINER (ZERO GREY BOX / ZERO GREY FROSTED MATERIAL)
        let blackView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 250))
        blackView.wantsLayer = true
        blackView.layer?.backgroundColor = NSColor.black.cgColor
        blackView.layer?.cornerRadius = 16
        blackView.layer?.masksToBounds = true
        blackView.layer?.borderColor = NSColor(white: 0.2, alpha: 0.8).cgColor
        blackView.layer?.borderWidth = 1.0
        
        window.contentView = blackView
        
        // Close Button
        let closeBtn = NSButton(title: "✕", target: self, action: #selector(closeTutorial))
        closeBtn.isBordered = false
        closeBtn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        closeBtn.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        closeBtn.frame = NSRect(x: 330, y: 220, width: 22, height: 22)
        closeBtn.layer?.zPosition = 999
        blackView.addSubview(closeBtn)
        
        // Transparent WKWebView loading exact trackpad.html
        let config = WKWebViewConfiguration()
        
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 360, height: 250), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.black.cgColor
        
        blackView.addSubview(webView, positioned: .below, relativeTo: closeBtn)
        
        loadHtml()
    }
    
    private func loadHtml() {
        guard let bundlePath = Bundle.main.path(forResource: "trackpad", ofType: "html") else { return }
        let url = URL(fileURLWithPath: bundlePath)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    
    func showTutorial() {
        guard let window = window else { return }
        loadHtml()
        
        // STICK TUTORIAL WINDOW AT EXACT SAME POSITION WHERE OUR MAIN PLAYER IS STICKED
        if let manager = StatusItemManager.shared {
            manager.positionCustomWindow(window, width: 360, height: 250)
        } else {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func closeTutorial() {
        window?.orderOut(nil)
    }
}
