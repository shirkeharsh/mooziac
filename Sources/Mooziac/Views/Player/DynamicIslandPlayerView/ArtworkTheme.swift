import AppKit
import QuartzCore
import ImageIO

extension DynamicIslandPlayerView {
    func loadArtwork(urlStr: String) {
        guard let url = URL(string: urlStr) else { return }

        if let cached = AppArtworkHelper.shared.getMemoryCachedImage(forKey: urlStr) {
            applyArtworkAnimation { [weak self] in self?.artworkImageView.image = cached }
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let artworkData = data, error == nil else { return }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128
            ]
            guard let source = CGImageSourceCreateWithData(artworkData as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 44, height: 44))

            DispatchQueue.main.async {
                AppArtworkHelper.shared.setMemoryCachedImage(thumbnail, forKey: urlStr)
                self.applyArtworkAnimation { self.artworkImageView.image = thumbnail }
                self.updateAmbientGlow(cgImage: cgImage)
            }
        }.resume()
    }

    func applyArtworkAnimation(_ updates: @escaping () -> Void) {
        let transition = CATransition()
        transition.duration = 0.35
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .fade
        artworkImageView.layer?.add(transition, forKey: "artworkFade")
        updates()
    }

    func ambientDominantColor(from cgImage: CGImage) -> NSColor {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return NSColor.systemBlue }

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return NSColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 1.0)
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        let stepX = max(1, width / 12)
        let stepY = max(1, height / 12)

        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0

                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let sat = maxC > 0 ? (maxC - minC) / maxC : 0

                if sat > 0.15 && maxC > 0.15 {
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }
        }

        guard count > 0 else {
            return NSColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 1.0)
        }

        let avgR = totalR / count
        let avgG = totalG / count
        let avgB = totalB / count
        return NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }

    func updateAmbientGlow(cgImage: CGImage) {
        let dominantColor = ambientDominantColor(from: cgImage)
        let converted = dominantColor.usingColorSpace(.sRGB) ?? dominantColor
        let r = max(0, min(1, converted.redComponent * 0.22))
        let g = max(0, min(1, converted.greenComponent * 0.22))
        let b = max(0, min(1, converted.blueComponent * 0.22))
        let darkBg = NSColor(srgbRed: r, green: g, blue: b, alpha: 0.96)
        
        let br = max(0, min(1, converted.redComponent * 0.85))
        let bg = max(0, min(1, converted.greenComponent * 0.85))
        let bb = max(0, min(1, converted.blueComponent * 0.85))
        let borderGlow = NSColor(srgbRed: br, green: bg, blue: bb, alpha: 0.40)

        self.lastAmbientBgColor = darkBg.cgColor
        self.lastAmbientBorderColor = borderGlow.cgColor
        self.lastAmbientAccentColor = dominantColor

        DynamicIslandPlayerView.sharedAmbientBgColor = darkBg.cgColor
        DynamicIslandPlayerView.sharedAmbientAccentColor = dominantColor
        NotificationCenter.default.post(name: NSNotification.Name("YTM_ambientThemeChanged"), object: nil)

        guard PlayerDesign.current == .adaptive else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.containerPill.layer?.backgroundColor = darkBg.cgColor
            self.containerPill.layer?.borderWidth = 1.0
            self.containerPill.layer?.borderColor = borderGlow.cgColor
            self.waveformProgressView.accentColor = dominantColor
        }
    }
    
    @objc func applyTheme() {
        let design = PlayerDesign.current
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            
            switch design {

            case .adaptive:
                visualEffectBackdrop.isHidden = true
                glassSheenLayer.isHidden = true
                let bg = lastAmbientBgColor ?? NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.98).cgColor
                containerPill.layer?.backgroundColor = bg
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
                waveformProgressView.accentColor = lastAmbientAccentColor ?? NSColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1.0)
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                titleLabel.textColor = NSColor.white
                artistLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
                timeLabel.textColor = NSColor(white: 0.60, alpha: 1.0)
                
                playPauseButton.contentTintColor = NSColor.white
                previousButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                nextButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                addToPlaylistButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                repeatButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                likeButton.contentTintColor = isLiked ? NSColor.red : NSColor(white: 0.80, alpha: 1.0)
                searchIconButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                fullScreenButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                browserButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)
                resetPositionButton.contentTintColor = NSColor(white: 0.80, alpha: 1.0)

            case .native:
                visualEffectBackdrop.isHidden = false
                visualEffectBackdrop.material = .underWindowBackground
                visualEffectBackdrop.blendingMode = .behindWindow
                visualEffectBackdrop.state = .active
                glassSheenLayer.isHidden = false
                glassSheenLayer.frame = containerPill.bounds
                containerPill.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.02).cgColor
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.24).cgColor
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                titleLabel.textColor = NSColor.white
                artistLabel.textColor = NSColor(white: 0.76, alpha: 1.0)
                timeLabel.textColor = NSColor(white: 0.70, alpha: 1.0)
                
                waveformProgressView.accentColor = NSColor.white
                
                playPauseButton.contentTintColor = NSColor.white
                previousButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                nextButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                addToPlaylistButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                repeatButton.contentTintColor = (repeatMode != .off) ? NSColor.white : NSColor(white: 0.88, alpha: 1.0)
                likeButton.contentTintColor = isLiked ? NSColor(red: 1.0, green: 0.28, blue: 0.38, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)
                searchIconButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                fullScreenButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                browserButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
                resetPositionButton.contentTintColor = NSColor(white: 0.88, alpha: 1.0)

            case .darkMode:
                visualEffectBackdrop.isHidden = true
                glassSheenLayer.isHidden = true
                containerPill.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 0.98).cgColor
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor
                waveformProgressView.accentColor = NSColor.white
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                titleLabel.textColor = NSColor.white
                artistLabel.textColor = NSColor(white: 0.60, alpha: 1.0)
                timeLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
                
                playPauseButton.contentTintColor = NSColor.white
                previousButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                nextButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                addToPlaylistButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                repeatButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                likeButton.contentTintColor = isLiked ? NSColor.red : NSColor(white: 0.85, alpha: 1.0)
                searchIconButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                fullScreenButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                browserButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                resetPositionButton.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
                
            case .glassMode:
                visualEffectBackdrop.isHidden = true
                glassSheenLayer.isHidden = true
                // Premium Light Mode #EFF2F0
                containerPill.layer?.backgroundColor = NSColor(red: 0.93725, green: 0.94902, blue: 0.94118, alpha: 0.98).cgColor
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = NSColor(red: 0.80, green: 0.82, blue: 0.81, alpha: 0.85).cgColor
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
                
                let pitchBlack = NSColor.black
                let deepBlack = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
                
                waveformProgressView.accentColor = pitchBlack
                
                titleLabel.textColor = pitchBlack
                artistLabel.textColor = deepBlack
                timeLabel.textColor = deepBlack
                
                playPauseButton.contentTintColor = pitchBlack
                previousButton.contentTintColor = pitchBlack
                nextButton.contentTintColor = pitchBlack
                addToPlaylistButton.contentTintColor = pitchBlack
                repeatButton.contentTintColor = pitchBlack
                likeButton.contentTintColor = isLiked ? NSColor(red: 0.98, green: 0.25, blue: 0.35, alpha: 1.0) : pitchBlack
                searchIconButton.contentTintColor = pitchBlack
                fullScreenButton.contentTintColor = pitchBlack
                browserButton.contentTintColor = pitchBlack
                resetPositionButton.contentTintColor = pitchBlack
            }
        }

        downloadButton.updateVisuals()
        updateDownloadButtonState()
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
        updateBrowserButtonColor()
        updateAddToPlaylistButtonColor()
        updateRepeatButtonColor()
    }
}
