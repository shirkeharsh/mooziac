import AppKit

final class GestureMappingRowView: NSView {
    private let gestureType: GestureType
    private let onActionChanged: (GestureAction) -> Void
    private let onResetToDefault: () -> Void

    private let iconView = NSImageView()
    private let titleLabel = NSTextField()
    private let popupButton = NSPopUpButton()
    private let resetButton = NSButton()

    init(gestureType: GestureType, currentAction: GestureAction, onActionChanged: @escaping (GestureAction) -> Void, onResetToDefault: @escaping () -> Void) {
        self.gestureType = gestureType
        self.onActionChanged = onActionChanged
        self.onResetToDefault = onResetToDefault
        super.init(frame: .zero)
        setupUI(currentAction: currentAction)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(currentAction: GestureAction) {
        let isLight = (PlayerDesign.current == .glassMode)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = (isLight ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 0.12, alpha: 0.6)).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = (isLight ? NSColor(white: 0.0, alpha: 0.12) : NSColor(white: 1.0, alpha: 0.14)).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let img = NSImage(systemSymbolName: gestureType.iconName, accessibilityDescription: gestureType.displayName)?.withSymbolConfiguration(iconConfig) {
            iconView.image = img
        }
        iconView.contentTintColor = isLight ? NSColor(white: 0.20, alpha: 1.0) : NSColor(white: 0.85, alpha: 1.0)
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        // Title
        titleLabel.stringValue = gestureType.displayName
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = isLight ? NSColor(srgbRed: 0.11, green: 0.11, blue: 0.11, alpha: 1.0) : NSColor(white: 0.92, alpha: 1.0)
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.refusesFirstResponder = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Popup button
        popupButton.translatesAutoresizingMaskIntoConstraints = false
        popupButton.removeAllItems()
        for action in GestureAction.allCases {
            let item = NSMenuItem(title: action.displayName, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: action.iconName, accessibilityDescription: action.displayName)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
            item.representedObject = action
            popupButton.menu?.addItem(item)
        }
        popupButton.selectItem(withTitle: currentAction.displayName)
        popupButton.target = self
        popupButton.action = #selector(popupChanged(_:))
        popupButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        popupButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Reset button
        let cyan = isLight ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.title = "Reset"
        resetButton.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        resetButton.isBordered = false
        resetButton.contentTintColor = cyan
        resetButton.target = self
        resetButton.action = #selector(resetTapped(_:))
        resetButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        resetButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        resetButton.wantsLayer = true
        resetButton.layer?.cornerRadius = 4
        resetButton.layer?.borderWidth = 1.0
        resetButton.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
        resetButton.layer?.backgroundColor = cyan.withAlphaComponent(isLight ? 0.08 : 0.12).cgColor

        // Layout
        let textStack = NSStackView(views: [titleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = NSStackView(views: [iconView, textStack, popupButton, resetButton])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            rowStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 38),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    @objc private func popupChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let action = selectedItem.representedObject as? GestureAction else { return }
        onActionChanged(action)
    }

    @objc private func resetTapped(_ sender: NSButton) {
        onResetToDefault()
    }

    func updatePopupSelection(_ action: GestureAction) {
        popupButton.selectItem(withTitle: action.displayName)
    }

    func updateAppearance(tone: SettingsTone) {
        let isLight = (tone == .light)
        layer?.backgroundColor = (isLight ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 0.12, alpha: 0.6)).cgColor
        layer?.borderColor = tone.dividerColor.cgColor
        layer?.borderWidth = 1.0
        titleLabel.textColor = tone.primaryText
        iconView.contentTintColor = tone.iconColor
        let cyan = isLight ? NSColor.lightThemeSelector : NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        resetButton.contentTintColor = cyan
        resetButton.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
        resetButton.layer?.backgroundColor = cyan.withAlphaComponent(isLight ? 0.08 : 0.12).cgColor
    }
}