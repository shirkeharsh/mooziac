import AppKit

public final class RatingPromptWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = RatingPromptWindowController()
    
    private let windowWidth: CGFloat = 360
    private let windowHeight: CGFloat = 380
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Mooziac"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .floating
        window.center()
        
        super.init(window: window)
        window.delegate = self
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 1. Frosted Glass Background
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 24
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        
        // 2. Mooziac App Icon
        let iconSize: CGFloat = 60
        let iconView = NSImageView(frame: NSRect(x: (windowWidth - iconSize) / 2, y: windowHeight - 88, width: iconSize, height: iconSize))
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: iconPath) {
            iconView.image = img
        } else if let appIcon = NSImage(named: NSImage.applicationIconName) {
            iconView.image = appIcon
        } else {
            let cfg = NSImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
            iconView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        }
        iconView.wantsLayer = true
        iconView.layer?.shadowColor = NSColor.black.cgColor
        iconView.layer?.shadowOpacity = 0.40
        iconView.layer?.shadowRadius = 10
        iconView.layer?.shadowOffset = CGSize(width: 0, height: -3)
        visualEffect.addSubview(iconView)
        
        // 3. Title
        let titleLabel = NSTextField(labelWithString: "Enjoying Mooziac?")
        titleLabel.font = NSFont.systemFont(ofSize: 16.5, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: windowHeight - 118, width: windowWidth - 40, height: 22)
        visualEffect.addSubview(titleLabel)
        
        // 4. Subtitle
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Mooziac is free & open-source. If you're loving the tunes, here are ways to support the journey!")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 24, y: windowHeight - 158, width: windowWidth - 48, height: 32)
        visualEffect.addSubview(subtitleLabel)
        
        // ==========================================
        // BENTO GRID CARDS
        // ==========================================
        
        // Bento Box 1: Star on GitHub (Top Left)
        let bentoStar = NSView(frame: NSRect(x: 20, y: 120, width: 155, height: 88))
        bentoStar.wantsLayer = true
        bentoStar.layer?.cornerRadius = 15
        bentoStar.layer?.backgroundColor = NSColor(red: 0.12, green: 0.6, blue: 1.0, alpha: 0.15).cgColor
        bentoStar.layer?.borderWidth = 1.0
        bentoStar.layer?.borderColor = NSColor(red: 0.25, green: 0.75, blue: 1.0, alpha: 0.38).cgColor
        
        let starIcon = NSImageView(frame: NSRect(x: 14, y: 50, width: 22, height: 22))
        let starCfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        starIcon.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)?.withSymbolConfiguration(starCfg)
        starIcon.contentTintColor = NSColor(red: 0.25, green: 0.82, blue: 1.0, alpha: 1.0)
        bentoStar.addSubview(starIcon)
        
        let starTitle = NSTextField(labelWithString: "Star on GitHub")
        starTitle.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        starTitle.textColor = .labelColor
        starTitle.frame = NSRect(x: 14, y: 27, width: 130, height: 18)
        bentoStar.addSubview(starTitle)
        
        let starSub = NSTextField(labelWithString: "Free & 1-click")
        starSub.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        starSub.textColor = .secondaryLabelColor
        starSub.frame = NSRect(x: 14, y: 10, width: 130, height: 15)
        bentoStar.addSubview(starSub)
        
        let starClick = NSButton(frame: bentoStar.bounds)
        starClick.title = ""
        starClick.isTransparent = true
        starClick.target = self
        starClick.action = #selector(handleStarClicked)
        bentoStar.addSubview(starClick)
        visualEffect.addSubview(bentoStar)
        
        // Bento Box 2: Buy Me a Coffee (Top Right)
        let bentoCoffee = NSView(frame: NSRect(x: 185, y: 120, width: 155, height: 88))
        bentoCoffee.wantsLayer = true
        bentoCoffee.layer?.cornerRadius = 15
        bentoCoffee.layer?.backgroundColor = NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.13).cgColor
        bentoCoffee.layer?.borderWidth = 1.0
        bentoCoffee.layer?.borderColor = NSColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 0.38).cgColor
        
        let coffeeIcon = NSImageView(frame: NSRect(x: 14, y: 50, width: 22, height: 22))
        let coffeeCfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        coffeeIcon.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?.withSymbolConfiguration(coffeeCfg)
        coffeeIcon.contentTintColor = NSColor(red: 1.0, green: 0.76, blue: 0.22, alpha: 1.0)
        bentoCoffee.addSubview(coffeeIcon)
        
        let coffeeTitle = NSTextField(labelWithString: "Buy a Coffee")
        coffeeTitle.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        coffeeTitle.textColor = .labelColor
        coffeeTitle.frame = NSRect(x: 14, y: 27, width: 130, height: 18)
        bentoCoffee.addSubview(coffeeTitle)
        
        let coffeeSub = NSTextField(labelWithString: "Fuel development")
        coffeeSub.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        coffeeSub.textColor = .secondaryLabelColor
        coffeeSub.frame = NSRect(x: 14, y: 10, width: 130, height: 15)
        bentoCoffee.addSubview(coffeeSub)
        
        let coffeeClick = NSButton(frame: bentoCoffee.bounds)
        coffeeClick.title = ""
        coffeeClick.isTransparent = true
        coffeeClick.target = self
        coffeeClick.action = #selector(handleCoffeeClicked)
        bentoCoffee.addSubview(coffeeClick)
        visualEffect.addSubview(bentoCoffee)
        
        // Bento Box 3: Write Us / Support (Bottom Full Width)
        let bentoSupport = NSView(frame: NSRect(x: 20, y: 44, width: windowWidth - 40, height: 66))
        bentoSupport.wantsLayer = true
        bentoSupport.layer?.cornerRadius = 15
        bentoSupport.layer?.backgroundColor = NSColor(red: 0.35, green: 0.85, blue: 0.55, alpha: 0.13).cgColor
        bentoSupport.layer?.borderWidth = 1.0
        bentoSupport.layer?.borderColor = NSColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 0.35).cgColor
        
        let supportIcon = NSImageView(frame: NSRect(x: 16, y: 22, width: 22, height: 22))
        let supportCfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        supportIcon.image = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)?.withSymbolConfiguration(supportCfg)
        supportIcon.contentTintColor = NSColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0)
        bentoSupport.addSubview(supportIcon)
        
        let supportTitle = NSTextField(labelWithString: "Write Us (Help & Feedback)")
        supportTitle.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        supportTitle.textColor = .labelColor
        supportTitle.frame = NSRect(x: 48, y: 33, width: 240, height: 18)
        bentoSupport.addSubview(supportTitle)
        
        let supportSub = NSTextField(labelWithString: "Have an idea, request, or bug? Visit support.")
        supportSub.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        supportSub.textColor = .secondaryLabelColor
        supportSub.frame = NSRect(x: 48, y: 15, width: 260, height: 15)
        bentoSupport.addSubview(supportSub)
        
        let supportClick = NSButton(frame: bentoSupport.bounds)
        supportClick.title = ""
        supportClick.isTransparent = true
        supportClick.target = self
        supportClick.action = #selector(handleSupportClicked)
        bentoSupport.addSubview(supportClick)
        visualEffect.addSubview(bentoSupport)
        
        // 6. Maybe Later Footer Button (Local only)
        let laterBtn = NSButton(frame: NSRect(x: (windowWidth - 120) / 2, y: 12, width: 120, height: 22))
        laterBtn.title = "Maybe Later"
        laterBtn.bezelStyle = .inline
        laterBtn.isBordered = false
        laterBtn.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        laterBtn.contentTintColor = NSColor.tertiaryLabelColor
        laterBtn.target = self
        laterBtn.action = #selector(handleMaybeLaterClicked)
        visualEffect.addSubview(laterBtn)
        
        window.contentView = visualEffect
    }
    
    // MARK: - Action Handlers
    
    private func reportPromptClick(event: String) {
        guard let url = URL(string: "https://mooziac.pages.dev/api/track?event=\(event)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        request.httpShouldHandleCookies = false
        URLSession.shared.dataTask(with: request).resume()
    }
    
    @objc private func handleStarClicked() {
        reportPromptClick(event: "star")
        if let url = URL(string: "https://github.com/shirkeharsh/mooziac?ref=app_prompt") {
            NSWorkspace.shared.open(url)
        }
        RatingPromptManager.shared.markInteracted()
    }
    
    @objc private func handleCoffeeClicked() {
        reportPromptClick(event: "coffee")
        if let url = URL(string: "https://buymeacoffee.com/shirkeharsh?ref=app_prompt") {
            NSWorkspace.shared.open(url)
        }
        RatingPromptManager.shared.markInteracted()
    }
    
    @objc private func handleSupportClicked() {
        reportPromptClick(event: "support")
        if let url = URL(string: "https://mooziac.pages.dev/support.html?ref=app_prompt") {
            NSWorkspace.shared.open(url)
        }
        RatingPromptManager.shared.markInteracted()
    }
    
    @objc private func handleMaybeLaterClicked() {
        RatingPromptManager.shared.snooze()
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        if !RatingPromptManager.shared.hasInteracted {
            RatingPromptManager.shared.snooze()
        }
    }
}
