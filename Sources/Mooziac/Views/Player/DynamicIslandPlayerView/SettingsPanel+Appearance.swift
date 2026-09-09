import AppKit

extension DynamicIslandPlayerView {
    func currentThemeDisplayName() -> String {
        switch PlayerDesign.current {
        case .adaptive: return "Live dynamic artwork backdrop"
        case .darkMode: return "Deep pitch-black dark contrast"
        case .glassMode: return "Translucent frosted glass panel"
        case .liquidFluid: return "Watery pure transparent liquid glass"
        }
    }

    func makeThemeFeatureRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: "Player Themes")?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: "Player Themes")
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: currentThemeDisplayName())
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true
        self.themeDescLabel = descLbl

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)
        featureRowContainers.append(row)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        themeToggle.totalSteps = 4
        let currentThemeStep: Int
        switch PlayerDesign.current {
        case .adaptive: currentThemeStep = 0
        case .darkMode: currentThemeStep = 1
        case .glassMode: currentThemeStep = 2
        case .liquidFluid: currentThemeStep = 3
        }
        themeToggle.stepIndex = currentThemeStep
        themeToggle.onStep = { [weak self] step in
            switch step {
            case 0:
                PlayerDesign.current = .adaptive
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Adaptive")
            case 1:
                PlayerDesign.current = .darkMode
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: OLED Dark")
            case 2:
                PlayerDesign.current = .glassMode
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Crystal Glass")
            case 3:
                PlayerDesign.current = .liquidFluid
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Watery Transparent")
            default:
                break
            }
            self?.applyTheme()
            self?.themeDescLabel?.stringValue = self?.currentThemeDisplayName() ?? ""
            self?.updateSettingsThemeHighlight()
        }
        themeToggle.translatesAutoresizingMaskIntoConstraints = false
        themeToggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        themeToggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, themeToggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        themeToggle.setContentHuggingPriority(.required, for: .horizontal)
        themeToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    @objc func themeCycleTapped() {
        switch PlayerDesign.current {
        case .adaptive:
            PlayerDesign.current = .darkMode
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: OLED Dark")
        case .darkMode:
            PlayerDesign.current = .glassMode
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Crystal Glass")
        case .glassMode:
            PlayerDesign.current = .liquidFluid
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Watery Transparent")
        case .liquidFluid:
            PlayerDesign.current = .adaptive
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Theme: Adaptive")
        }
        applyTheme()
        themeDescLabel?.stringValue = currentThemeDisplayName()
        updateSettingsThemeHighlight()
    }

    func makeProgressStyleFeatureRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Timeline Track")?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: "Timeline Track")
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: ProgressStyle.current.displayName)
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true
        self.progressDescLabel = descLbl

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)
        featureRowContainers.append(row)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        let allStyles = ProgressStyle.allCases
        progressToggle.totalSteps = allStyles.count
        let currentProgressStep = allStyles.firstIndex(of: ProgressStyle.current) ?? 0
        progressToggle.stepIndex = currentProgressStep
        progressToggle.onStep = { [weak self] step in
            guard step >= 0 && step < allStyles.count else { return }
            let next = allStyles[step]
            ProgressStyle.current = next
            self?.progressDescLabel?.stringValue = next.displayName
            self?.waveformProgressView.needsDisplay = true
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Progress Bar: \(next.displayName)")
        }
        progressToggle.translatesAutoresizingMaskIntoConstraints = false
        progressToggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        progressToggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, progressToggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        progressToggle.setContentHuggingPriority(.required, for: .horizontal)
        progressToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    @objc func progressStyleCycleTapped() {
        let all = ProgressStyle.allCases
        let current = ProgressStyle.current
        guard let idx = all.firstIndex(of: current) else { return }
        let next = all[(idx + 1) % all.count]
        ProgressStyle.current = next
        progressDescLabel?.stringValue = next.displayName
        waveformProgressView.needsDisplay = true
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Progress Bar: \(next.displayName)")
    }

    func makeFeatureRow(icon: String, title: String, description: String, isOn: Bool, toggle: NativeCapsuleToggleView, onToggle: @escaping (Bool) -> Void) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title)?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: title)
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: description)
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)
        featureRowContainers.append(row)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        toggle.isOn = isOn
        toggle.onToggle = onToggle
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.widthAnchor.constraint(equalToConstant: 32).isActive = true
        toggle.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [iconImg, textStack, toggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    func makeNavigationButton(icon: String, title: String, description: String, action: Selector) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = NSImageView()
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title)?.withSymbolConfiguration(config) {
            iconImg.image = img
        }
        iconImg.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        iconImg.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = NSTextField(labelWithString: title)
        titleLbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLbl.textColor = NSColor(white: 0.92, alpha: 1.0)
        titleLbl.isEditable = false
        titleLbl.isSelectable = false
        titleLbl.refusesFirstResponder = true

        let descLbl = NSTextField(labelWithString: description)
        descLbl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        descLbl.textColor = NSColor(white: 0.6, alpha: 1.0)
        descLbl.isEditable = false
        descLbl.isSelectable = false
        descLbl.refusesFirstResponder = true

        featureIconViews.append(iconImg)
        featureTitleLabels.append(titleLbl)
        featureDescLabels.append(descLbl)

        let textStack = NSStackView(views: [titleLbl, descLbl])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.setContentCompressionResistancePriority(.required, for: .vertical)
        descLbl.setContentCompressionResistancePriority(.required, for: .vertical)

        let chevronImg = NSImageView()
        chevronImg.translatesAutoresizingMaskIntoConstraints = false
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        chevronImg.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")?.withSymbolConfiguration(chevronConfig)
        chevronImg.contentTintColor = NSColor(white: 0.5, alpha: 1.0)
        chevronImg.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chevronImg.heightAnchor.constraint(equalToConstant: 12).isActive = true
        featureChevronViews.append(chevronImg)

        let rowStack = NSStackView(views: [iconImg, textStack, chevronImg])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 35),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        rowStack.setHuggingPriority(.init(251), for: .horizontal)
        chevronImg.setContentHuggingPriority(.required, for: .horizontal)
        chevronImg.setContentCompressionResistancePriority(.required, for: .horizontal)

        let clickGesture = NSClickGestureRecognizer(target: self, action: action)
        row.addGestureRecognizer(clickGesture)
        return row
    }


    func currentSettingsTone() -> SettingsTone {
        switch PlayerDesign.current {
        case .darkMode, .adaptive:
            return .dark
        case .glassMode:
            return .light
        case .liquidFluid:
            return SystemAppearanceHelper.isDarkSystemAppearance ? .dark : .light
        }
    }

    func updateSettingsThemeHighlight() {
        let tone = currentSettingsTone()
        settingsHeaderLabel.textColor = tone.primaryText
        playlistSectionLabel.textColor = tone.primaryText
        featuresSectionLabel.textColor = tone.secondaryText
        settingsDivider.layer?.backgroundColor = tone.dividerColor.cgColor

        themeDescLabel?.stringValue = currentThemeDisplayName()
        progressDescLabel?.stringValue = ProgressStyle.current.displayName

        themeToggle.updateVisuals()
        progressToggle.updateVisuals()
        masterGesturesToggle.updateVisuals()
        appVolumeToggle.updateVisuals()
        lyricsToggle.updateVisuals()
        discordToggle.updateVisuals()

        let currentThemeStep: Int
        switch PlayerDesign.current {
        case .adaptive: currentThemeStep = 0
        case .darkMode: currentThemeStep = 1
        case .glassMode: currentThemeStep = 2
        case .liquidFluid: currentThemeStep = 3
        }
        themeToggle.stepIndex = currentThemeStep
        let allStyles = ProgressStyle.allCases
        progressToggle.stepIndex = allStyles.firstIndex(of: ProgressStyle.current) ?? 0

        let isGlass = (PlayerDesign.current == .glassMode || (PlayerDesign.current == .liquidFluid && !SystemAppearanceHelper.isDarkSystemAppearance))
        for row in featureRowContainers {
            if isGlass {
                row.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.03).cgColor
                row.layer?.borderColor = NSColor(white: 0.0, alpha: 0.06).cgColor
                row.layer?.borderWidth = 0.5
            } else {
                row.layer?.backgroundColor = NSColor.clear.cgColor
                row.layer?.borderWidth = 0
            }
        }

        for icon in featureIconViews {
            icon.contentTintColor = tone.iconColor
        }
        for title in featureTitleLabels {
            title.textColor = tone.primaryText
        }
        for desc in featureDescLabels {
            desc.textColor = tone.secondaryText
        }
        for chevron in featureChevronViews {
            chevron.contentTintColor = tone.secondaryText.withAlphaComponent(0.7)
        }

        settingsVersionLabel?.textColor = tone.secondaryText.withAlphaComponent(0.6)

        playlistSearchField?.applyPlaylistContainerStyle(tone: tone)
        playlistSearchField?.layer?.shadowOpacity = (tone == .light) ? 0.04 : 0.22

        librarySectionHeaderLabel.textColor = tone.secondaryText

        libraryNavContainer.layer?.borderWidth = 0
        libraryNavContainer.layer?.backgroundColor = NSColor.clear.cgColor

        let isDark = (PlayerDesign.current == .darkMode || tone == .dark)
        let cyan: NSColor
        if isGlass {
            cyan = NSColor.lightThemeSelector
        } else if isDark {
            cyan = NSColor.darkThemeSelector
        } else {
            cyan = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        }
        for btn in libraryNavButtons {
            btn.refresh(tone: tone, isGlass: isGlass, cyan: cyan)
        }
        playlistDetailCreateButton.contentTintColor = isPlaylistCreateOpen ? cyan : tone.iconColor

        if let footerBtn = playlistCreateFooterButton {
            footerBtn.contentTintColor = cyan
            footerBtn.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
            footerBtn.layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.08 : 0.12).cgColor
        }

        downloadsPlayAllButton.contentTintColor = cyan
        downloadsShuffleButton.contentTintColor = cyan

        likedPlayAllButton.contentTintColor = cyan
        likedShuffleButton.contentTintColor = cyan

        historyPlayAllButton.contentTintColor = cyan
        historyShuffleButton.contentTintColor = cyan

        playlistDetailBackButton.contentTintColor = cyan
        playlistDetailPlayAllButton.contentTintColor = cyan
        playlistDetailShuffleButton.contentTintColor = cyan
        playlistDetailDownloadAllButton.contentTintColor = cyan
        playlistDetailRenameButton.contentTintColor = cyan
        playlistDetailAddButton.contentTintColor = cyan

        playlistSearchToggleButton.contentTintColor = isPlaylistSearchActive ? cyan : tone.iconColor
        playlistBulkDeleteButton.contentTintColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        playlistSelectionDoneButton.contentTintColor = cyan
        playlistSelectionDoneButton.layer?.borderColor = cyan.withAlphaComponent(0.35).cgColor
        playlistSelectionDoneButton.layer?.backgroundColor = cyan.withAlphaComponent(isGlass ? 0.08 : 0.14).cgColor

        inlineCreateTextField.textColor = tone.primaryText
        inlineCreateContainer.layer?.borderColor = tone.dividerColor.cgColor
        inlineCreateContainer.layer?.backgroundColor = (tone == .light ? NSColor(white: 0.0, alpha: 0.04) : NSColor(white: 1.0, alpha: 0.06)).cgColor

        gestureMappingSectionLabel?.textColor = tone.primaryText
        gestureMappingBackButton?.contentTintColor = cyan
        for rowView in gestureMappingRows {
            rowView.updateAppearance(tone: tone)
        }
    }
}

