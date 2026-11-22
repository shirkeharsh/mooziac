import AppKit
import QuartzCore

final class ViewOnlyOverlayView: NSView {
    var onClick: (() -> Void)?
    var onMouseMove: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseMove?()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseMove?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Intercept all mouse clicks on the visual stage so it is strictly view-only.
        return self
    }

    override func mouseDown(with event: NSEvent) {
        onMouseMove?()
        // Intercept mouse clicks to collapse hero mode back to compact player
        onClick?()
    }

    override func mouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {
        onMouseMove?()
    }
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
}

public final class HeroLyricsView: NSView {
    public override var isFlipped: Bool { return true }

    private let ambientSpotlightLayer = CAGradientLayer()
    private let contentContainer = NSView()

    private let prevContainer = NSView()
    public let prevLabel = NSTextField(labelWithString: "")

    private let activeContainer = NSView()
    public let currentLabel = NSTextField(labelWithString: "")

    private let nextContainer = NSView()
    public let nextLabel = NSTextField(labelWithString: "")

    private var lines: [LRCLine] = []
    private var lastRenderedIndex: Int = -999
    private var lastRenderedWordIndex: Int = -999
    private var playbackTimer: Timer?
    private var currentAccentColor: NSColor = NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)

    private var activeFont: NSFont = NSFont.systemFont(ofSize: 15.5, weight: .heavy)
    private var secondaryFont: NSFont = NSFont.systemFont(ofSize: 12.0, weight: .medium)

    public var hasLyrics: Bool {
        return !lines.isEmpty
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }

    public override func layout() {
        super.layout()
        ambientSpotlightLayer.frame = bounds
        apply3DTransforms()
        if activeContainer.bounds.width > 0 && activeContainer.bounds.height > 0 {
            activeContainer.layer?.shadowPath = CGPath(roundedRect: activeContainer.bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
        }
    }

    private func apply3DTransforms() {
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 480.0
        contentContainer.layer?.sublayerTransform = perspective

        // Previous line: tilted backward along X, scaled down, translated back
        var prevT = CATransform3DIdentity
        prevT = CATransform3DTranslate(prevT, 0, 0, -26)
        prevT = CATransform3DRotate(prevT, -14.0 * .pi / 180.0, 1, 0, 0)
        prevT = CATransform3DScale(prevT, 0.88, 0.88, 1.0)
        prevContainer.layer?.transform = prevT

        // Active line: elevated forward in 3D with subtle scale
        var activeT = CATransform3DIdentity
        activeT = CATransform3DTranslate(activeT, 0, 0, 22)
        activeT = CATransform3DScale(activeT, 1.03, 1.03, 1.0)
        activeContainer.layer?.transform = activeT

        // Next line: tilted backward along X, scaled down, translated back
        var nextT = CATransform3DIdentity
        nextT = CATransform3DTranslate(nextT, 0, 0, -26)
        nextT = CATransform3DRotate(nextT, 14.0 * .pi / 180.0, 1, 0, 0)
        nextT = CATransform3DScale(nextT, 0.88, 0.88, 1.0)
        nextContainer.layer?.transform = nextT
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Resolve Apple Music style rounded heavy typography
        if let desc = NSFont.systemFont(ofSize: 15.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            activeFont = NSFont(descriptor: desc, size: 15.5) ?? NSFont.systemFont(ofSize: 15.5, weight: .heavy)
        }
        if let desc = NSFont.systemFont(ofSize: 12.0, weight: .medium).fontDescriptor.withDesign(.rounded) {
            secondaryFont = NSFont(descriptor: desc, size: 12.0) ?? NSFont.systemFont(ofSize: 12.0, weight: .medium)
        }

        // 1. Dynamic Radial Ambient Spotlight
        ambientSpotlightLayer.type = .radial
        ambientSpotlightLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientSpotlightLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        updateSpotlightColors()
        layer?.addSublayer(ambientSpotlightLayer)

        // 2. 3D Perspective Container
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(contentContainer)

        // 3. Active Container (Center Glass Capsule with Dynamic Song Glow)
        activeContainer.translatesAutoresizingMaskIntoConstraints = false
        activeContainer.wantsLayer = true
        activeContainer.layer?.cornerRadius = 14
        activeContainer.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        activeContainer.layer?.borderWidth = 0.75
        activeContainer.layer?.masksToBounds = false

        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        currentLabel.font = activeFont
        currentLabel.alignment = .center
        currentLabel.maximumNumberOfLines = 2
        currentLabel.lineBreakMode = .byWordWrapping
        currentLabel.isEditable = false
        currentLabel.isSelectable = false
        currentLabel.drawsBackground = false
        currentLabel.isBezeled = false
        currentLabel.wantsLayer = true
        activeContainer.addSubview(currentLabel)

        // 4. Previous Container & Label (Top Perspective)
        prevContainer.translatesAutoresizingMaskIntoConstraints = false
        prevContainer.wantsLayer = true
        prevContainer.layer?.backgroundColor = NSColor.clear.cgColor

        prevLabel.translatesAutoresizingMaskIntoConstraints = false
        prevLabel.font = secondaryFont
        prevLabel.textColor = NSColor(white: 1.0, alpha: 0.32)
        prevLabel.alignment = .center
        prevLabel.maximumNumberOfLines = 1
        prevLabel.lineBreakMode = .byTruncatingTail
        prevLabel.isEditable = false
        prevLabel.isSelectable = false
        prevLabel.drawsBackground = false
        prevLabel.isBezeled = false
        prevLabel.wantsLayer = true
        prevContainer.addSubview(prevLabel)

        // 5. Next Container & Label (Bottom Perspective)
        nextContainer.translatesAutoresizingMaskIntoConstraints = false
        nextContainer.wantsLayer = true
        nextContainer.layer?.backgroundColor = NSColor.clear.cgColor

        nextLabel.translatesAutoresizingMaskIntoConstraints = false
        nextLabel.font = secondaryFont
        nextLabel.textColor = NSColor(white: 1.0, alpha: 0.32)
        nextLabel.alignment = .center
        nextLabel.maximumNumberOfLines = 1
        nextLabel.lineBreakMode = .byTruncatingTail
        nextLabel.isEditable = false
        nextLabel.isSelectable = false
        nextLabel.drawsBackground = false
        nextLabel.isBezeled = false
        nextLabel.wantsLayer = true
        nextContainer.addSubview(nextLabel)

        contentContainer.addSubview(prevContainer)
        contentContainer.addSubview(activeContainer)
        contentContainer.addSubview(nextContainer)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Active Capsule Centering
            activeContainer.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            activeContainer.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            activeContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainer.leadingAnchor, constant: 14),
            activeContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentContainer.trailingAnchor, constant: -14),
            activeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            currentLabel.topAnchor.constraint(equalTo: activeContainer.topAnchor, constant: 6),
            currentLabel.bottomAnchor.constraint(equalTo: activeContainer.bottomAnchor, constant: -6),
            currentLabel.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor, constant: 14),
            currentLabel.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor, constant: -14),

            // Previous Container Above Active
            prevContainer.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            prevContainer.bottomAnchor.constraint(equalTo: activeContainer.topAnchor, constant: -5),
            prevContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            prevContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            prevContainer.heightAnchor.constraint(equalToConstant: 22),

            prevLabel.topAnchor.constraint(equalTo: prevContainer.topAnchor),
            prevLabel.bottomAnchor.constraint(equalTo: prevContainer.bottomAnchor),
            prevLabel.leadingAnchor.constraint(equalTo: prevContainer.leadingAnchor),
            prevLabel.trailingAnchor.constraint(equalTo: prevContainer.trailingAnchor),

            // Next Container Below Active
            nextContainer.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            nextContainer.topAnchor.constraint(equalTo: activeContainer.bottomAnchor, constant: 5),
            nextContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            nextContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            nextContainer.heightAnchor.constraint(equalToConstant: 22),

            nextLabel.topAnchor.constraint(equalTo: nextContainer.topAnchor),
            nextLabel.bottomAnchor.constraint(equalTo: nextContainer.bottomAnchor),
            nextLabel.leadingAnchor.constraint(equalTo: nextContainer.leadingAnchor),
            nextLabel.trailingAnchor.constraint(equalTo: nextContainer.trailingAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAmbientThemeChanged),
            name: NSNotification.Name("YTM_ambientThemeChanged"),
            object: nil
        )
    }

    @objc private func handleAmbientThemeChanged() {
        if let accent = DynamicIslandPlayerView.sharedAmbientAccentColor {
            updateAccentColor(accent)
        }
    }

    public func updateAccentColor(_ color: NSColor?) {
        let accent = color ?? DynamicIslandPlayerView.sharedAmbientAccentColor ?? NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
        self.currentAccentColor = accent
        updateSpotlightColors()
    }

    private func updateSpotlightColors() {
        let accent = currentAccentColor
        ambientSpotlightLayer.colors = [
            accent.withAlphaComponent(0.25).cgColor,
            accent.withAlphaComponent(0.0).cgColor
        ]
        let borderTint = accent.blended(withFraction: 0.65, of: .white)?.withAlphaComponent(0.28) ?? NSColor(white: 1.0, alpha: 0.20)
        activeContainer.layer?.borderColor = borderTint.cgColor
        activeContainer.layer?.shadowColor = accent.withAlphaComponent(0.45).cgColor
        activeContainer.layer?.shadowRadius = 14
        activeContainer.layer?.shadowOpacity = 0.50
        activeContainer.layer?.shadowOffset = CGSize(width: 0, height: 0)
    }

    public func setLyrics(_ newLines: [LRCLine]) {
        self.lines = newLines
        self.lastRenderedIndex = -999
        self.lastRenderedWordIndex = -999
        if lines.isEmpty {
            clear()
        } else {
            updateTime(NowPlayingManager.shared.currentState.getAccurateTime())
        }
    }

    public func clear() {
        lines = []
        lastRenderedIndex = -999
        lastRenderedWordIndex = -999
        prevLabel.stringValue = ""
        currentLabel.stringValue = ""
        nextLabel.stringValue = ""
        stopTimer()
    }

    public func updateTime(_ currentTime: Double) {
        guard !lines.isEmpty else {
            clear()
            return
        }

        let effectiveTime = currentTime + 0.15
        guard let activeInfo = SyncedLyricsParser.activeLineAndWord(at: currentTime, in: lines, leadOffset: 0.15) else {
            // Before first line or in deep instrumental interlude
            if effectiveTime < lines[0].timestamp {
                renderState(activeIdx: -1, prevText: "", line: nil, nextText: lines.first?.text ?? "", activeWordIdx: -1)
            } else {
                renderState(activeIdx: -2, prevText: "", line: nil, nextText: "", activeWordIdx: -1)
            }
            return
        }

        let lineIdx = activeInfo.lineIndex
        let line = activeInfo.line
        let prevText = lineIdx > 0 ? lines[lineIdx - 1].text : ""
        let nextText = lineIdx + 1 < lines.count ? lines[lineIdx + 1].text : ""

        renderState(activeIdx: lineIdx, prevText: prevText, line: line, nextText: nextText, activeWordIdx: activeInfo.activeWordIndex)
    }

    private func renderState(activeIdx: Int, prevText: String, line: LRCLine?, nextText: String, activeWordIdx: Int) {
        let isNewLine = (activeIdx != lastRenderedIndex)
        let isNewWord = (activeWordIdx != lastRenderedWordIndex)

        if isNewLine {
            let isForward = (activeIdx > lastRenderedIndex) || (lastRenderedIndex == -999)
            lastRenderedIndex = activeIdx
            lastRenderedWordIndex = activeWordIdx

            // 3D Push / Roll Transition on line change
            applyLineTransition(isForward: isForward)

            prevLabel.stringValue = prevText
            nextLabel.stringValue = nextText

            if let activeLine = line {
                currentLabel.attributedStringValue = buildAttributedLyric(line: activeLine, activeWordIndex: activeWordIdx)
            } else {
                currentLabel.attributedStringValue = buildInstrumentalAttributedLyric()
            }
        } else if isNewWord {
            lastRenderedWordIndex = activeWordIdx
            if let activeLine = line {
                currentLabel.attributedStringValue = buildAttributedLyric(line: activeLine, activeWordIndex: activeWordIdx)
            }
        }
    }

    private func applyLineTransition(isForward: Bool) {
        let transition = CATransition()
        transition.duration = 0.32
        transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        transition.type = .push
        transition.subtype = isForward ? .fromTop : .fromBottom

        prevLabel.layer?.add(transition, forKey: "prevLinePush")
        currentLabel.layer?.add(transition, forKey: "currentLinePush")
        nextLabel.layer?.add(transition, forKey: "nextLinePush")

        // 3D Spring Bloom on the active glass capsule
        let bloom = CAKeyframeAnimation(keyPath: "transform.scale")
        bloom.values = [0.95, 1.04, 1.0]
        bloom.keyTimes = [0.0, 0.45, 1.0]
        bloom.duration = 0.32
        bloom.timingFunction = CAMediaTimingFunction(name: .easeOut)
        activeContainer.layer?.add(bloom, forKey: "capsuleBloom")
    }

    private func buildAttributedLyric(line: LRCLine, activeWordIndex: Int) -> NSAttributedString {
        let words = line.words
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        pStyle.lineBreakMode = .byWordWrapping

        guard !words.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: activeFont,
                .foregroundColor: NSColor(white: 1.0, alpha: 0.98),
                .paragraphStyle: pStyle
            ]
            return NSAttributedString(string: line.text, attributes: attrs)
        }

        let attrString = NSMutableAttributedString()
        let accent = currentAccentColor
        let highlightColor = accent.blended(withFraction: 0.55, of: .white) ?? NSColor(white: 1.0, alpha: 1.0)
        let sungColor = NSColor(white: 1.0, alpha: 0.98)
        let upcomingColor = NSColor(white: 1.0, alpha: 0.42)

        let glowShadow = NSShadow()
        glowShadow.shadowColor = accent.withAlphaComponent(0.85)
        glowShadow.shadowBlurRadius = 10
        glowShadow.shadowOffset = CGSize(width: 0, height: 0)

        let subtleShadow = NSShadow()
        subtleShadow.shadowColor = NSColor.black.withAlphaComponent(0.50)
        subtleShadow.shadowBlurRadius = 3
        subtleShadow.shadowOffset = CGSize(width: 0, height: -1)

        for (idx, w) in words.enumerated() {
            let wordStr = (idx == words.count - 1) ? w.text : "\(w.text) "
            var attrs: [NSAttributedString.Key: Any] = [
                .font: activeFont,
                .paragraphStyle: pStyle
            ]

            if idx < activeWordIndex {
                attrs[.foregroundColor] = sungColor
                attrs[.shadow] = subtleShadow
            } else if idx == activeWordIndex {
                attrs[.foregroundColor] = highlightColor
                attrs[.shadow] = glowShadow
            } else {
                attrs[.foregroundColor] = upcomingColor
            }

            attrString.append(NSAttributedString(string: wordStr, attributes: attrs))
        }

        return attrString
    }

    private func buildInstrumentalAttributedLyric() -> NSAttributedString {
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let glowShadow = NSShadow()
        glowShadow.shadowColor = currentAccentColor.withAlphaComponent(0.85)
        glowShadow.shadowBlurRadius = 12
        glowShadow.shadowOffset = CGSize(width: 0, height: 0)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: activeFont,
            .foregroundColor: currentAccentColor.blended(withFraction: 0.5, of: .white) ?? NSColor.white,
            .shadow: glowShadow,
            .paragraphStyle: pStyle
        ]
        return NSAttributedString(string: "♪ ♪ ♪", attributes: attrs)
    }

    private func startSpotlightPulse() {
        if ambientSpotlightLayer.animation(forKey: "spotlightPulse") == nil {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.92
            pulse.toValue = 1.08
            pulse.duration = 2.4
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ambientSpotlightLayer.add(pulse, forKey: "spotlightPulse")
        }
    }

    private func stopSpotlightPulse() {
        ambientSpotlightLayer.removeAnimation(forKey: "spotlightPulse")
    }

    public func startTimer() {
        stopTimer()
        guard hasLyrics else { return }
        startSpotlightPulse()
        playbackTimer = Timer(timeInterval: 0.18, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let state = NowPlayingManager.shared.currentState
            if state.isPlaying {
                self.updateTime(state.getAccurateTime())
            }
        }
        if let t = playbackTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    public func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        stopSpotlightPulse()
    }
}

extension DynamicIslandPlayerView {
    public func updateVisualStageContent(state: PlaybackState? = nil) {
        let current = state ?? NowPlayingManager.shared.currentState
        let isOffline = (NowPlayingManager.shared.engineMode == .offline)
        let hasLiveVideo = !isOffline && current.hasVideo
        var currentArt: NSImage? = (artworkImageView.image !== AppArtworkHelper.defaultArtwork) ? artworkImageView.image : nil
        if currentArt == nil, !current.artworkUrl.isEmpty {
            currentArt = AppArtworkHelper.shared.getMemoryCachedImage(forKey: current.artworkUrl)
        }
        if currentArt == nil, isOffline, let offlineTrack = NativeAudioPlayer.shared.currentTrack {
            currentArt = AppArtworkHelper.shared.getCachedThumbnail(for: offlineTrack)
        }
        let artToBlur = currentArt ?? artworkImageView.image ?? AppArtworkHelper.defaultArtwork
        let trackKey = "\(current.title)_\(current.artist)_\(current.trackID)"
        let blurred = AppArtworkHelper.shared.getBlurredArtwork(from: artToBlur, key: trackKey, radius: 3.5)
        heroAmbientImageView.image = blurred

        // Sync dynamic album accent color to lyrics stage
        let accent = DynamicIslandPlayerView.sharedAmbientAccentColor
        heroLyricsView.updateAccentColor(accent)

        if isHeroArtworkExpanded {
            heroOverlayView.isHidden = false
            if hasLiveVideo {
                heroWebHostView.isHidden = false
                heroLyricsView.isHidden = true
                heroLyricsView.stopTimer()
                artworkImageView.isHidden = true
                heroAmbientImageView.isHidden = true
                delegate?.dynamicIslandDidToggleVisualStage(isActive: true, hostView: heroWebHostView)
            } else {
                heroWebHostView.isHidden = true
                if heroLyricsView.hasLyrics {
                    heroLyricsView.isHidden = false
                    heroLyricsView.updateTime(current.getAccurateTime())
                    if current.isPlaying {
                        heroLyricsView.startTimer()
                    } else {
                        heroLyricsView.stopTimer()
                    }
                    artworkImageView.isHidden = true
                    heroAmbientImageView.isHidden = false
                } else {
                    heroLyricsView.isHidden = true
                    heroLyricsView.stopTimer()
                    artworkImageView.isHidden = false
                    heroAmbientImageView.isHidden = false
                }
            }
        } else {
            heroWebHostView.isHidden = true
            heroOverlayView.isHidden = true
            heroLyricsView.isHidden = true
            heroLyricsView.stopTimer()
            artworkImageView.isHidden = false
            heroAmbientImageView.isHidden = true
        }
    }
}
