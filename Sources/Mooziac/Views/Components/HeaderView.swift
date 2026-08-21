import AppKit

protocol HeaderViewDelegate: AnyObject {
    func headerViewDidTapBack()
    func headerViewDidTapForward()
    func headerViewDidTapReload()
    func headerViewDidTapHome()
    func headerViewDidTapAccount()
    func headerViewDidTapPlayerOnly()
    func headerViewDidTapQuit()
}

class HeaderView: NSView {
    weak var delegate: HeaderViewDelegate?
    
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let reloadButton = NSButton()
    private let homeButton = NSButton()
    private let accountButton = NSButton()
    private let playerOnlyButton = NSButton()
    private let quitButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "Mooziac")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged(_:)), name: NetworkMonitor.statusChangedNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 0.98).cgColor
        
        setupIconButton(backButton, systemName: "chevron.left", toolTip: "Back", action: #selector(backTapped))
        setupIconButton(forwardButton, systemName: "chevron.right", toolTip: "Forward", action: #selector(forwardTapped))
        setupIconButton(reloadButton, systemName: "arrow.clockwise", toolTip: "Reload", action: #selector(reloadTapped))
        setupIconButton(homeButton, systemName: "house", toolTip: "YouTube Music Home", action: #selector(homeTapped))
        setupIconButton(accountButton, systemName: "person.circle.fill", toolTip: "Sign In / Switch Account (Web)", action: #selector(accountTapped))
        setupIconButton(playerOnlyButton, systemName: "arrow.down.right.and.arrow.up.left", toolTip: "Switch to Player View", action: #selector(playerOnlyTapped))
        setupIconButton(quitButton, systemName: "xmark.circle.fill", toolTip: "Quit App", action: #selector(quitTapped))
        
        accountButton.contentTintColor = NSColor.systemGray
        playerOnlyButton.contentTintColor = NSColor.white
        quitButton.contentTintColor = NSColor.systemRed
        
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let leftStack = NSStackView(views: [backButton, forwardButton, reloadButton, homeButton, accountButton])
        leftStack.orientation = .horizontal
        leftStack.spacing = 6
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        
        let rightStack = NSStackView(views: [playerOnlyButton, quitButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 8
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(leftStack)
        addSubview(titleLabel)
        addSubview(rightStack)
        
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupIconButton(_ button: NSButton, systemName: String, toolTip: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: toolTip)?.withSymbolConfiguration(config) {
            button.image = image
        } else {
            button.title = toolTip
        }
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.toolTip = toolTip
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    @objc private func backTapped() { delegate?.headerViewDidTapBack() }
    @objc private func forwardTapped() { delegate?.headerViewDidTapForward() }
    @objc private func reloadTapped() { delegate?.headerViewDidTapReload() }
    @objc private func homeTapped() { delegate?.headerViewDidTapHome() }
    @objc private func accountTapped() { delegate?.headerViewDidTapAccount() }
    @objc private func playerOnlyTapped() { delegate?.headerViewDidTapPlayerOnly() }
    @objc private func quitTapped() { delegate?.headerViewDidTapQuit() }
    
    @objc private func networkStatusChanged(_ note: Notification) {
        let isReachable = note.userInfo?["isReachable"] as? Bool ?? true
        DispatchQueue.main.async { [weak self] in
            if isReachable {
                self?.titleLabel.stringValue = "Mooziac"
                self?.titleLabel.textColor = NSColor.white
            } else {
                self?.titleLabel.stringValue = "⚡ Mooziac (Offline)"
                self?.titleLabel.textColor = NSColor(red: 1.0, green: 0.60, blue: 0.30, alpha: 1.0)
            }
        }
    }
}
