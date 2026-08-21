import AppKit

public final class OfflineOverlayView: NSView {
    public var onRetry: (() -> Void)?
    
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "No Internet Connection")
    private let subtitleLabel = NSTextField(labelWithString: "Mooziac is offline. Check your network connection to stream music.")
    private let statusLabel = NSTextField(labelWithString: "⚡ Waiting for network connection...")
    private let retryButton = NSButton()
    private let spinner = NSProgressIndicator()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.96).cgColor
        
        let config = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        if let img = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "Offline")?.withSymbolConfiguration(config) {
            iconImageView.image = img
        }
        iconImageView.contentTintColor = NSColor(red: 1.0, green: 0.35, blue: 0.40, alpha: 1.0)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.70, alpha: 1.0)
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.cell?.wraps = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = NSColor(red: 1.0, green: 0.75, blue: 0.30, alpha: 1.0)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        retryButton.title = "Retry Connection"
        retryButton.bezelStyle = .rounded
        retryButton.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        retryButton.target = self
        retryButton.action = #selector(retryTapped)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView(views: [iconImageView, titleLabel, subtitleLabel, statusLabel, retryButton, spinner])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            retryButton.heightAnchor.constraint(equalToConstant: 28),
            spinner.widthAnchor.constraint(equalToConstant: 20),
            spinner.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    @objc private func retryTapped() {
        spinner.isHidden = false
        spinner.startAnimation(nil)
        retryButton.isEnabled = false
        statusLabel.stringValue = "Checking connection..."
        onRetry?()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.spinner.stopAnimation(nil)
            self.spinner.isHidden = true
            self.retryButton.isEnabled = true
            if !NetworkMonitor.shared.isReachable {
                self.statusLabel.stringValue = "⚡ Still offline. Please check Wi-Fi / Ethernet."
                self.statusLabel.textColor = NSColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 1.0)
            } else {
                self.statusLabel.stringValue = "🟢 Reconnected!"
                self.statusLabel.textColor = NSColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1.0)
            }
        }
    }
    
    public func updateNetworkState(isReachable: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isReachable {
                self.statusLabel.stringValue = "🟢 Connection restored! Reloading..."
                self.statusLabel.textColor = NSColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1.0)
            } else {
                self.statusLabel.stringValue = "⚡ Offline - Connect to Wi-Fi or Ethernet"
                self.statusLabel.textColor = NSColor(red: 1.0, green: 0.75, blue: 0.30, alpha: 1.0)
            }
        }
    }
}
