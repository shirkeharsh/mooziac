import AppKit

extension DynamicIslandPlayerView {
    @objc func showGestureMappingSubView() {
        if let mainStack = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("MainSettingsStack") }) {
            mainStack.isHidden = true
        }
        if let subView = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("PlaylistSubView") }) {
            subView.isHidden = true
        }
        if let gestureSubView = settingsContainerView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("GestureMappingSubView") }) {
            gestureSubView.isHidden = false
        }
        settingsHeaderLabel.isHidden = true
        refreshGestureMappingRows()
        updateSettingsThemeHighlight()
    }

    func setupGestureMappingSubView() {
        let subView = NSView()
        subView.translatesAutoresizingMaskIntoConstraints = false
        subView.wantsLayer = true
        subView.layer?.masksToBounds = false
        subView.isHidden = true
        subView.identifier = NSUserInterfaceItemIdentifier("GestureMappingSubView")

        // Section label
        let sectionLabel = NSTextField(labelWithString: "GESTURE MAPPING")
        sectionLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        sectionLabel.textColor = currentSettingsTone().primaryText
        sectionLabel.isEditable = false
        sectionLabel.isSelectable = false
        sectionLabel.refusesFirstResponder = true
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        gestureMappingSectionLabel = sectionLabel

        // Back button
        let backButton = NSButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        let backConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        backButton.image = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Back")?.withSymbolConfiguration(backConfig)
        backButton.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(showMainSettingsView)
        backButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        gestureMappingBackButton = backButton

        // Reset all button
        let resetButton = NSButton()
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.title = "Reset All to Defaults"
        resetButton.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        resetButton.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        resetButton.isBordered = false
        resetButton.wantsLayer = true
        resetButton.layer?.cornerRadius = 5
        resetButton.layer?.borderWidth = 1.0
        resetButton.layer?.borderColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        resetButton.layer?.backgroundColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 0.12).cgColor
        resetButton.target = self
        resetButton.action = #selector(resetAllGestureMappings)
        resetButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
        resetButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        gestureMappingResetButton = resetButton

        // Header stack
        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerStack = NSStackView(views: [backButton, sectionLabel, headerSpacer, resetButton])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Scroll view for gesture rows
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        gestureMappingScrollView = scrollView

        let clipView = NSClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let docView = NSView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = docView

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        gestureMappingStackView = stackView

        docView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: docView.topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -4),
            stackView.bottomAnchor.constraint(equalTo: docView.bottomAnchor, constant: -4),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -8)
        ])

        // Add to subView
        subView.addSubview(headerStack)
        subView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: subView.topAnchor, constant: 4),
            headerStack.leadingAnchor.constraint(equalTo: subView.leadingAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: subView.trailingAnchor, constant: -8),
            headerStack.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: subView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: subView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: subView.bottomAnchor, constant: -4)
        ])

        settingsContainerView.addSubview(subView)

        NSLayoutConstraint.activate([
            subView.topAnchor.constraint(equalTo: settingsContainerView.topAnchor, constant: 4),
            subView.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 4),
            subView.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -4),
            subView.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: -4)
        ])
    }

    func refreshGestureMappingRows() {
        guard let stackView = gestureMappingStackView else { return }

        // Remove existing rows
        for row in gestureMappingRows {
            row.removeFromSuperview()
        }
        gestureMappingRows.removeAll()

        // Create new rows for each gesture type
        for gestureType in GestureType.allCases {
            let currentAction = GestureMappingManager.shared.getAction(for: gestureType)
            let row = GestureMappingRowView(
                gestureType: gestureType,
                currentAction: currentAction,
                onActionChanged: { [weak self] newAction in
                    GestureMappingManager.shared.setAction(newAction, for: gestureType)
                    self?.refreshGestureMappingRows()
                },
                onResetToDefault: { [weak self] in
                    let defaultAction = gestureType.defaultAction
                    GestureMappingManager.shared.setAction(defaultAction, for: gestureType)
                    self?.refreshGestureMappingRows()
                }
            )
            gestureMappingRows.append(row)
            stackView.addArrangedSubview(row)
        }
    }

    @objc func resetAllGestureMappings() {
        GestureMappingManager.shared.resetToDefaults()
        refreshGestureMappingRows()
    }

}
