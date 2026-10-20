import AppKit

// MARK: - YouTubeDownloadSheetController

/// Native AppKit sheet controller for downloading YouTube videos and audio at full resolution,
/// styled with clean, compact Apple native colors and mini controls.
@MainActor
public final class YouTubeDownloadSheetController: NSViewController {
    public let videoId: String
    public let videoTitle: String
    public var onDismiss: (() -> Void)?

    // MARK: - UI Elements
    private let visualEffectView = NSVisualEffectView()
    private let headerIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Download Video")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    private let formatScrollView = NSScrollView()
    private let formatStackView = NSStackView()
    private let subtitlesCheckbox = NSButton(checkboxWithTitle: "Include Subtitles (.srt)", target: nil, action: nil)
    private let cancelButton = NSButton()
    private let downloadActionButton = NSButton()

    // Loading View
    private let loadingContainer = NSView()
    private let loadingSpinner = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "Fetching video formats…")

    // Progress View
    private let progressContainer = NSView()
    private let progressIndicator = NSProgressIndicator()
    private let percentLabel = NSTextField(labelWithString: "0%")
    private let speedLabel = NSTextField(labelWithString: "")
    private let destinationLabel = NSTextField(labelWithString: "Saving to ~/Downloads/")
    private let cancelDownloadButton = NSButton()

    // Completed View
    private let completedContainer = NSView()
    private let completedIcon = NSImageView()
    private let completedTitleLabel = NSTextField(labelWithString: "Download Complete")
    private let completedFileLabel = NSTextField(labelWithString: "")
    private let showInFinderButton = NSButton()
    private let doneButton = NSButton()
    private var completedFileURL: URL?

    // Error View
    private let errorContainer = NSView()
    private let errorIcon = NSImageView()
    private let errorMessageLabel = NSTextField(labelWithString: "")
    private let retryButton = NSButton()

    // State
    private var formats: [YouTubeDownloadService.DownloadFormat] = []
    private var selectedFormatIndex: Int = 0
    private var cardViews: [FormatCardContainerView] = []

    public init(videoId: String, videoTitle: String, onDismiss: (() -> Void)? = nil) {
        self.videoId = videoId
        self.videoTitle = videoTitle
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 410))
        setupUI()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        fetchAvailableFormats()
    }

    // MARK: - Setup UI
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true

        // 1. Apple Native Frosted Glass Backing
        visualEffectView.frame = view.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .sheet
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        view.addSubview(visualEffectView)

        let darkOverlay = CALayer()
        darkOverlay.backgroundColor = NSColor(white: 0.10, alpha: 0.94).cgColor
        darkOverlay.frame = view.bounds
        darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        visualEffectView.layer?.addSublayer(darkOverlay)

        let borderLayer = CALayer()
        borderLayer.frame = view.bounds
        borderLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        borderLayer.cornerRadius = 14
        borderLayer.borderWidth = 1.0
        borderLayer.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        view.layer?.addSublayer(borderLayer)

        // 2. Header
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        headerIconView.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Download")?.withSymbolConfiguration(iconConfig)
        headerIconView.contentTintColor = NSColor.labelColor
        headerIconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = "Download Video"
        titleLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let displayTitle = videoTitle.isEmpty ? "YouTube Video (\(videoId))" : videoTitle
        subtitleLabel.stringValue = displayTitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.cell?.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(didTapClose)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerIconView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(closeButton)
        view.addSubview(divider)

        NSLayoutConstraint.activate([
            headerIconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            headerIconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerIconView.widthAnchor.constraint(equalToConstant: 18),
            headerIconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.centerYAnchor.constraint(equalTo: headerIconView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerIconView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            divider.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // 3. Formats Container
        formatScrollView.translatesAutoresizingMaskIntoConstraints = false
        formatScrollView.hasVerticalScroller = true
        formatScrollView.drawsBackground = false
        formatScrollView.borderType = .noBorder

        let clipView = NSClipView()
        clipView.drawsBackground = false
        formatScrollView.contentView = clipView

        formatStackView.orientation = .vertical
        formatStackView.spacing = 5
        formatStackView.alignment = .leading
        formatStackView.translatesAutoresizingMaskIntoConstraints = false

        clipView.documentView = formatStackView

        subtitlesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        subtitlesCheckbox.state = .off
        subtitlesCheckbox.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitlesCheckbox.contentTintColor = NSColor.secondaryLabelColor

        // Mini Bottom Bar Buttons
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.title = "Cancel"
        cancelButton.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        cancelButton.target = self
        cancelButton.action = #selector(didTapClose)

        downloadActionButton.translatesAutoresizingMaskIntoConstraints = false
        downloadActionButton.bezelStyle = .inline
        downloadActionButton.isBordered = false
        downloadActionButton.wantsLayer = true
        downloadActionButton.title = "Download"
        downloadActionButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        downloadActionButton.target = self
        downloadActionButton.action = #selector(didTapStartDownload)
        downloadActionButton.layer?.cornerRadius = 6
        downloadActionButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        downloadActionButton.contentTintColor = .white

        let btnIconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        downloadActionButton.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(btnIconConfig)
        downloadActionButton.imagePosition = .imageLeading

        view.addSubview(formatScrollView)
        view.addSubview(subtitlesCheckbox)
        view.addSubview(cancelButton)
        view.addSubview(downloadActionButton)

        NSLayoutConstraint.activate([
            formatScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            formatScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            formatScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            formatScrollView.bottomAnchor.constraint(equalTo: subtitlesCheckbox.topAnchor, constant: -8),

            formatStackView.widthAnchor.constraint(equalTo: formatScrollView.widthAnchor),

            subtitlesCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            subtitlesCheckbox.bottomAnchor.constraint(equalTo: downloadActionButton.topAnchor, constant: -10),

            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            cancelButton.heightAnchor.constraint(equalToConstant: 28),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            downloadActionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            downloadActionButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            downloadActionButton.heightAnchor.constraint(equalToConstant: 28),
            downloadActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])

        // 4. Loading State View
        setupLoadingView(below: divider)

        // 5. Progress State View
        setupProgressView(below: divider)

        // 6. Completed State View
        setupCompletedView(below: divider)

        // 7. Error State View
        setupErrorView(below: divider)
    }

    private func setupLoadingView(below divider: NSBox) {
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.isHidden = false
        view.addSubview(loadingContainer)

        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .small
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.startAnimation(nil)

        loadingLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        loadingLabel.textColor = NSColor.secondaryLabelColor
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingContainer.addSubview(loadingSpinner)
        loadingContainer.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            loadingContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor, constant: -12),

            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 10),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor)
        ])
    }

    private func setupProgressView(below divider: NSBox) {
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.isHidden = true
        view.addSubview(progressContainer)

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0.0
        progressIndicator.maxValue = 100.0
        progressIndicator.doubleValue = 0.0
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
        percentLabel.textColor = NSColor.labelColor
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        speedLabel.textColor = NSColor.secondaryLabelColor
        speedLabel.translatesAutoresizingMaskIntoConstraints = false

        destinationLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        destinationLabel.textColor = NSColor.tertiaryLabelColor
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false

        cancelDownloadButton.translatesAutoresizingMaskIntoConstraints = false
        cancelDownloadButton.bezelStyle = .rounded
        cancelDownloadButton.title = "Cancel"
        cancelDownloadButton.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        cancelDownloadButton.target = self
        cancelDownloadButton.action = #selector(didTapCancelDownload)

        progressContainer.addSubview(percentLabel)
        progressContainer.addSubview(progressIndicator)
        progressContainer.addSubview(speedLabel)
        progressContainer.addSubview(destinationLabel)
        progressContainer.addSubview(cancelDownloadButton)

        NSLayoutConstraint.activate([
            progressContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            progressContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            percentLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor, constant: -40),

            progressIndicator.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 14),
            progressIndicator.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 36),
            progressIndicator.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -36),

            speedLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 8),
            speedLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),

            destinationLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 4),
            destinationLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),

            cancelDownloadButton.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: -16),
            cancelDownloadButton.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            cancelDownloadButton.widthAnchor.constraint(equalToConstant: 100),
            cancelDownloadButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func setupCompletedView(below divider: NSBox) {
        completedContainer.translatesAutoresizingMaskIntoConstraints = false
        completedContainer.isHidden = true
        view.addSubview(completedContainer)

        let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        completedIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")?.withSymbolConfiguration(config)
        completedIcon.contentTintColor = NSColor.systemGreen
        completedIcon.translatesAutoresizingMaskIntoConstraints = false

        completedTitleLabel.font = NSFont.systemFont(ofSize: 14.5, weight: .bold)
        completedTitleLabel.textColor = NSColor.labelColor
        completedTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        completedFileLabel.font = NSFont.systemFont(ofSize: 11)
        completedFileLabel.textColor = NSColor.secondaryLabelColor
        completedFileLabel.cell?.lineBreakMode = .byTruncatingMiddle
        completedFileLabel.alignment = .center
        completedFileLabel.translatesAutoresizingMaskIntoConstraints = false

        showInFinderButton.translatesAutoresizingMaskIntoConstraints = false
        showInFinderButton.bezelStyle = .inline
        showInFinderButton.isBordered = false
        showInFinderButton.wantsLayer = true
        showInFinderButton.title = "Show in Finder"
        showInFinderButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        showInFinderButton.target = self
        showInFinderButton.action = #selector(didTapShowInFinder)
        showInFinderButton.layer?.cornerRadius = 6
        showInFinderButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        showInFinderButton.contentTintColor = .white

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.bezelStyle = .rounded
        doneButton.title = "Done"
        doneButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        doneButton.target = self
        doneButton.action = #selector(didTapClose)

        completedContainer.addSubview(completedIcon)
        completedContainer.addSubview(completedTitleLabel)
        completedContainer.addSubview(completedFileLabel)
        completedContainer.addSubview(showInFinderButton)
        completedContainer.addSubview(doneButton)

        NSLayoutConstraint.activate([
            completedContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            completedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            completedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            completedContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            completedIcon.centerXAnchor.constraint(equalTo: completedContainer.centerXAnchor),
            completedIcon.centerYAnchor.constraint(equalTo: completedContainer.centerYAnchor, constant: -40),

            completedTitleLabel.topAnchor.constraint(equalTo: completedIcon.bottomAnchor, constant: 12),
            completedTitleLabel.centerXAnchor.constraint(equalTo: completedContainer.centerXAnchor),

            completedFileLabel.topAnchor.constraint(equalTo: completedTitleLabel.bottomAnchor, constant: 3),
            completedFileLabel.leadingAnchor.constraint(equalTo: completedContainer.leadingAnchor, constant: 24),
            completedFileLabel.trailingAnchor.constraint(equalTo: completedContainer.trailingAnchor, constant: -24),

            showInFinderButton.topAnchor.constraint(equalTo: completedFileLabel.bottomAnchor, constant: 18),
            showInFinderButton.centerXAnchor.constraint(equalTo: completedContainer.centerXAnchor, constant: -60),
            showInFinderButton.widthAnchor.constraint(equalToConstant: 114),
            showInFinderButton.heightAnchor.constraint(equalToConstant: 28),

            doneButton.topAnchor.constraint(equalTo: completedFileLabel.bottomAnchor, constant: 18),
            doneButton.centerXAnchor.constraint(equalTo: completedContainer.centerXAnchor, constant: 60),
            doneButton.widthAnchor.constraint(equalToConstant: 80),
            doneButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func setupErrorView(below divider: NSBox) {
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.isHidden = true
        view.addSubview(errorContainer)

        let config = NSImage.SymbolConfiguration(pointSize: 36, weight: .semibold)
        errorIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")?.withSymbolConfiguration(config)
        errorIcon.contentTintColor = NSColor.systemYellow
        errorIcon.translatesAutoresizingMaskIntoConstraints = false

        errorMessageLabel.font = NSFont.systemFont(ofSize: 11.5)
        errorMessageLabel.textColor = NSColor.secondaryLabelColor
        errorMessageLabel.alignment = .center
        errorMessageLabel.translatesAutoresizingMaskIntoConstraints = false

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.bezelStyle = .rounded
        retryButton.title = "Retry"
        retryButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        retryButton.target = self
        retryButton.action = #selector(fetchAvailableFormats)

        errorContainer.addSubview(errorIcon)
        errorContainer.addSubview(errorMessageLabel)
        errorContainer.addSubview(retryButton)

        NSLayoutConstraint.activate([
            errorContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorIcon.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            errorIcon.centerYAnchor.constraint(equalTo: errorContainer.centerYAnchor, constant: -30),

            errorMessageLabel.topAnchor.constraint(equalTo: errorIcon.bottomAnchor, constant: 10),
            errorMessageLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 24),
            errorMessageLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: errorMessageLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 100),
            retryButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    // MARK: - Data Fetching & Population
    @objc private func fetchAvailableFormats() {
        loadingContainer.isHidden = false
        formatScrollView.isHidden = true
        subtitlesCheckbox.isHidden = true
        cancelButton.isHidden = true
        downloadActionButton.isHidden = true
        progressContainer.isHidden = true
        completedContainer.isHidden = true
        errorContainer.isHidden = true

        Task {
            let fetched = await YouTubeDownloadService.shared.fetchFormats(videoId: videoId)
            self.formats = fetched
            self.loadingContainer.isHidden = true

            if fetched.isEmpty {
                self.errorMessageLabel.stringValue = "No download formats available. Ensure yt-dlp is installed:\nbrew install yt-dlp"
                self.errorContainer.isHidden = false
            } else {
                self.populateFormatList(fetched)
                self.formatScrollView.isHidden = false
                self.subtitlesCheckbox.isHidden = false
                self.cancelButton.isHidden = false
                self.downloadActionButton.isHidden = false
            }
        }
    }

    private func populateFormatList(_ formats: [YouTubeDownloadService.DownloadFormat]) {
        for v in formatStackView.arrangedSubviews {
            formatStackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        cardViews.removeAll()

        for (index, format) in formats.enumerated() {
            let card = FormatCardContainerView(format: format, index: index) { [weak self] selectedIndex in
                self?.updateSelection(selectedIndex: selectedIndex)
            }
            formatStackView.addArrangedSubview(card)
            cardViews.append(card)

            card.leadingAnchor.constraint(equalTo: formatStackView.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: formatStackView.trailingAnchor).isActive = true
        }

        updateSelection(selectedIndex: 0)
    }

    private func updateSelection(selectedIndex: Int) {
        self.selectedFormatIndex = selectedIndex
        for (i, card) in cardViews.enumerated() {
            card.setSelected(i == selectedIndex)
        }
        if selectedIndex < formats.count {
            let fmt = formats[selectedIndex]
            if fmt.isAudioOnly {
                downloadActionButton.title = "Download MP3"
            } else if let h = fmt.height, h >= 2160 {
                downloadActionButton.title = "Download 4K Video"
            } else if let h = fmt.height, h >= 1080 {
                downloadActionButton.title = "Download 1080p Video"
            } else if let h = fmt.height, h >= 720 {
                downloadActionButton.title = "Download 720p Video"
            } else {
                downloadActionButton.title = "Download \(fmt.label)"
            }
        }
    }

    // MARK: - Actions
    @objc private func didTapClose() {
        onDismiss?()
    }

    @objc private func didTapCancelDownload() {
        YouTubeDownloadService.shared.cancelDownload()
        fetchAvailableFormats()
    }

    @objc private func didTapShowInFinder() {
        if let fileURL = completedFileURL {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            NSWorkspace.shared.open(YouTubeDownloadService.shared.downloadsDir)
        }
        onDismiss?()
    }

    @objc private func didTapStartDownload() {
        guard selectedFormatIndex < formats.count else { return }
        let format = formats[selectedFormatIndex]
        let withSubtitles = (subtitlesCheckbox.state == .on)

        formatScrollView.isHidden = true
        subtitlesCheckbox.isHidden = true
        cancelButton.isHidden = true
        downloadActionButton.isHidden = true
        progressContainer.isHidden = false

        progressIndicator.doubleValue = 0.0
        percentLabel.stringValue = "0%"
        speedLabel.stringValue = "Initializing…"

        YouTubeDownloadService.shared.download(
            videoId: videoId,
            videoTitle: videoTitle,
            format: format,
            downloadSubtitles: withSubtitles
        ) { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .idle:
                    break
                case .preparing:
                    self.speedLabel.stringValue = "Preparing stream…"
                case let .downloading(progress, speed):
                    let pct = Int(progress * 100)
                    self.progressIndicator.doubleValue = progress * 100
                    self.percentLabel.stringValue = "\(pct)%"
                    self.speedLabel.stringValue = speed.isEmpty ? "Downloading…" : speed
                case let .completed(filename, fileURL):
                    self.completedFileURL = fileURL
                    self.progressContainer.isHidden = true
                    self.completedFileLabel.stringValue = filename
                    self.completedContainer.isHidden = false
                case let .failed(error):
                    self.progressContainer.isHidden = true
                    self.errorMessageLabel.stringValue = error
                    self.errorContainer.isHidden = false
                }
            }
        }
    }
}

// MARK: - FormatCardContainerView
@MainActor
private final class FormatCardContainerView: NSView {
    let format: YouTubeDownloadService.DownloadFormat
    let index: Int
    let onSelect: (Int) -> Void

    private let badgeContainer = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let radioImageView = NSImageView()
    private let clickButton = NSButton()

    private var isSelected: Bool = false

    init(format: YouTubeDownloadService.DownloadFormat, index: Int, onSelect: @escaping (Int) -> Void) {
        self.format = format
        self.index = index
        self.onSelect = onSelect
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.035).cgColor

        // 1. Resolution / Format Badge Pill
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 4

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
        badgeLabel.alignment = .center

        configureBadge()
        badgeContainer.addSubview(badgeLabel)

        // 2. Title & Subtitle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.stringValue = format.label
        titleLabel.cell?.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.cell?.lineBreakMode = .byTruncatingTail

        if format.isAudioOnly {
            subtitleLabel.stringValue = "Audio Stream"
        } else if let h = format.height, h >= 2160 {
            subtitleLabel.stringValue = "Ultra-HD 4K Video"
        } else if let h = format.height, h >= 1080 {
            subtitleLabel.stringValue = "Full HD Video"
        } else {
            subtitleLabel.stringValue = "Standard Video"
        }

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 1
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // 3. Size Label
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        sizeLabel.textColor = NSColor.secondaryLabelColor
        sizeLabel.alignment = .right
        sizeLabel.stringValue = format.sizeLabel

        // 4. Radio / Checkmark Icon
        radioImageView.translatesAutoresizingMaskIntoConstraints = false
        let radioConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        radioImageView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)?.withSymbolConfiguration(radioConfig)
        radioImageView.contentTintColor = NSColor.tertiaryLabelColor

        // 5. Transparent Click Overlay Button
        clickButton.translatesAutoresizingMaskIntoConstraints = false
        clickButton.bezelStyle = .regularSquare
        clickButton.isBordered = false
        clickButton.title = ""
        clickButton.target = self
        clickButton.action = #selector(didClickCard)

        addSubview(badgeContainer)
        addSubview(textStack)
        addSubview(sizeLabel)
        addSubview(radioImageView)
        addSubview(clickButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),

            badgeContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            badgeContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            badgeContainer.heightAnchor.constraint(equalToConstant: 20),

            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 9),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: sizeLabel.leadingAnchor, constant: -8),

            sizeLabel.trailingAnchor.constraint(equalTo: radioImageView.leadingAnchor, constant: -8),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            radioImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            radioImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioImageView.widthAnchor.constraint(equalToConstant: 15),
            radioImageView.heightAnchor.constraint(equalToConstant: 15),

            clickButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clickButton.topAnchor.constraint(equalTo: topAnchor),
            clickButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureBadge() {
        if format.isAudioOnly {
            badgeLabel.stringValue = "MP3"
            badgeLabel.textColor = NSColor.systemPurple
            badgeContainer.layer?.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.15).cgColor
        } else if let h = format.height, h >= 2160 {
            badgeLabel.stringValue = "4K"
            badgeLabel.textColor = NSColor.systemOrange
            badgeContainer.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15).cgColor
        } else if let h = format.height, h >= 1440 {
            badgeLabel.stringValue = "2K"
            badgeLabel.textColor = NSColor.systemOrange
            badgeContainer.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15).cgColor
        } else if let h = format.height, h >= 1080 {
            badgeLabel.stringValue = "1080p"
            badgeLabel.textColor = NSColor.controlAccentColor
            badgeContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        } else if let h = format.height, h >= 720 {
            badgeLabel.stringValue = "720p"
            badgeLabel.textColor = NSColor.controlAccentColor
            badgeContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        } else {
            badgeLabel.stringValue = "SD"
            badgeLabel.textColor = NSColor.secondaryLabelColor
            badgeContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.15).cgColor
        }
    }

    public func setSelected(_ selected: Bool) {
        self.isSelected = selected
        if selected {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor

            let radioConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            radioImageView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Selected")?.withSymbolConfiguration(radioConfig)
            radioImageView.contentTintColor = NSColor.controlAccentColor
            titleLabel.textColor = NSColor.labelColor
        } else {
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.035).cgColor

            let radioConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            radioImageView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Unselected")?.withSymbolConfiguration(radioConfig)
            radioImageView.contentTintColor = NSColor.tertiaryLabelColor
            titleLabel.textColor = NSColor.labelColor
        }
    }

    @objc private func didClickCard() {
        onSelect(index)
    }
}
