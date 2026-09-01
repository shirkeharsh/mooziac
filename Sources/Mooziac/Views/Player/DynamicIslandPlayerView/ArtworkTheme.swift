import AppKit
import QuartzCore
import ImageIO

extension DynamicIslandPlayerView {
    func loadArtwork(urlStr: String) {
        guard let url = URL(string: urlStr) else { return }

        if let cached = AppArtworkHelper.shared.getMemoryCachedImage(forKey: urlStr) {
            applyArtworkAnimation { [weak self] in self?.artworkImageView.image = cached }
            if let cg = cached.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                self.updateAmbientGlow(cgImage: cg)
            }
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
        // Enforce minimum luminance floor so dark album art never produces an unreadable pitch-black card on dark wallpapers
        let r = max(0.06, min(1, converted.redComponent * 0.24))
        let g = max(0.06, min(1, converted.greenComponent * 0.24))
        let b = max(0.08, min(1, converted.blueComponent * 0.26))
        let darkBg = NSColor(srgbRed: r, green: g, blue: b, alpha: 0.96)
        
        let br = max(0.20, min(1, converted.redComponent * 0.85))
        let bg = max(0.20, min(1, converted.greenComponent * 0.85))
        let bb = max(0.25, min(1, converted.blueComponent * 0.85))
        let borderGlow = NSColor(srgbRed: br, green: bg, blue: bb, alpha: 0.45)

        self.lastAmbientBgColor = darkBg.cgColor
        self.lastAmbientBorderColor = borderGlow.cgColor
        self.lastAmbientAccentColor = dominantColor

        DynamicIslandPlayerView.sharedAmbientBgColor = darkBg.cgColor
        DynamicIslandPlayerView.sharedAmbientAccentColor = dominantColor
        NotificationCenter.default.post(name: NSNotification.Name("YTM_ambientThemeChanged"), object: nil)

        if PlayerDesign.current == .adaptive {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                self.containerPill.layer?.backgroundColor = darkBg.cgColor
                self.containerPill.layer?.borderWidth = 1.0
                self.containerPill.layer?.borderColor = borderGlow.cgColor
                self.waveformProgressView.accentColor = dominantColor
            }
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
                cylindricalLensLayer.isHidden = true
                let bg = lastAmbientBgColor ?? NSColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 0.98).cgColor
                let border = lastAmbientBorderColor ?? NSColor(white: 1.0, alpha: 0.20).cgColor
                containerPill.layer?.backgroundColor = bg
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = border
                waveformProgressView.accentColor = lastAmbientAccentColor ?? NSColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1.0)
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                titleLabel.textColor = SystemAppearanceHelper.primaryTextColor(for: .adaptive)
                artistLabel.textColor = SystemAppearanceHelper.secondaryTextColor(for: .adaptive)
                timeLabel.textColor = SystemAppearanceHelper.tertiaryTextColor(for: .adaptive)
                
                let btnTint = SystemAppearanceHelper.controlButtonTint(for: .adaptive)
                playPauseButton.contentTintColor = NSColor.white
                previousButton.contentTintColor = btnTint
                nextButton.contentTintColor = btnTint
                addToPlaylistButton.contentTintColor = btnTint
                repeatButton.contentTintColor = (repeatMode != .off) ? NSColor.white : btnTint
                likeButton.contentTintColor = isLiked ? NSColor.red : btnTint
                searchIconButton.contentTintColor = btnTint
                fullScreenButton.contentTintColor = btnTint
                browserButton.contentTintColor = btnTint
                resetPositionButton.contentTintColor = btnTint


            case .darkMode:
                visualEffectBackdrop.isHidden = true
                glassSheenLayer.isHidden = true
                cylindricalLensLayer.isHidden = true
                containerPill.layer?.backgroundColor = SystemAppearanceHelper.darkModeBackingColor.cgColor
                containerPill.layer?.borderWidth = 1.0
                containerPill.layer?.borderColor = SystemAppearanceHelper.darkModeBorderColor.cgColor
                waveformProgressView.accentColor = NSColor.white
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                titleLabel.textColor = SystemAppearanceHelper.primaryTextColor(for: .darkMode)
                artistLabel.textColor = SystemAppearanceHelper.secondaryTextColor(for: .darkMode)
                timeLabel.textColor = SystemAppearanceHelper.tertiaryTextColor(for: .darkMode)
                
                let darkBtnTint = SystemAppearanceHelper.controlButtonTint(for: .darkMode)
                playPauseButton.contentTintColor = NSColor.white
                previousButton.contentTintColor = darkBtnTint
                nextButton.contentTintColor = darkBtnTint
                addToPlaylistButton.contentTintColor = darkBtnTint
                repeatButton.contentTintColor = (repeatMode != .off) ? NSColor.white : darkBtnTint
                likeButton.contentTintColor = isLiked ? NSColor.red : darkBtnTint
                searchIconButton.contentTintColor = darkBtnTint
                fullScreenButton.contentTintColor = darkBtnTint
                browserButton.contentTintColor = darkBtnTint
                resetPositionButton.contentTintColor = darkBtnTint

            case .glassMode:
                visualEffectBackdrop.isHidden = true
                glassSheenLayer.isHidden = true
                cylindricalLensLayer.isHidden = true
                // Premium Light Mode #EFF2F0 with high-contrast text and crisp perimeter rim
                containerPill.layer?.backgroundColor = NSColor(red: 0.93725, green: 0.94902, blue: 0.94118, alpha: 0.98).cgColor
                containerPill.layer?.borderWidth = 1.2
                containerPill.layer?.borderColor = NSColor(red: 0.70, green: 0.72, blue: 0.71, alpha: 1.0).cgColor
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
                
                let pitchBlack = SystemAppearanceHelper.primaryTextColor(for: .glassMode)
                let deepBlack = SystemAppearanceHelper.secondaryTextColor(for: .glassMode)
                let tertiaryBlack = SystemAppearanceHelper.tertiaryTextColor(for: .glassMode)
                
                waveformProgressView.accentColor = pitchBlack
                
                titleLabel.textColor = pitchBlack
                artistLabel.textColor = deepBlack
                timeLabel.textColor = tertiaryBlack
                
                let glassBtnTint = SystemAppearanceHelper.controlButtonTint(for: .glassMode)
                playPauseButton.contentTintColor = pitchBlack
                previousButton.contentTintColor = glassBtnTint
                nextButton.contentTintColor = glassBtnTint
                addToPlaylistButton.contentTintColor = glassBtnTint
                repeatButton.contentTintColor = (repeatMode != .off) ? pitchBlack : glassBtnTint
                likeButton.contentTintColor = isLiked ? NSColor(red: 0.98, green: 0.25, blue: 0.35, alpha: 1.0) : glassBtnTint
                searchIconButton.contentTintColor = glassBtnTint
                fullScreenButton.contentTintColor = glassBtnTint
                browserButton.contentTintColor = glassBtnTint
                resetPositionButton.contentTintColor = glassBtnTint

            case .liquidFluid:
                // Apple Control Center Optical Liquid Glass: Behind-window blur, 3D meniscus acrylic rim, cylindrical lens flare
                let isDark = SystemAppearanceHelper.isDarkSystemAppearance
                visualEffectBackdrop.isHidden = false
                visualEffectBackdrop.material = isDark ? .hudWindow : .popover
                visualEffectBackdrop.blendingMode = .behindWindow
                visualEffectBackdrop.state = .active
                
                // Convex meniscus rim with top glint & bottom internal bounce reflection
                glassSheenLayer.isHidden = false
                glassSheenLayer.frame = containerPill.bounds
                if isDark {
                    glassSheenLayer.colors = [
                        NSColor(white: 1.0, alpha: 0.65).cgColor,
                        NSColor(white: 1.0, alpha: 0.16).cgColor,
                        NSColor(white: 1.0, alpha: 0.00).cgColor,
                        NSColor(white: 1.0, alpha: 0.28).cgColor
                    ]
                } else {
                    glassSheenLayer.colors = [
                        NSColor(white: 1.0, alpha: 0.85).cgColor,
                        NSColor(white: 1.0, alpha: 0.35).cgColor,
                        NSColor(white: 0.0, alpha: 0.00).cgColor,
                        NSColor(white: 0.0, alpha: 0.08).cgColor
                    ]
                }
                glassSheenLayer.locations = [0.0, 0.14, 0.86, 1.0]

                // Horizontal cylindrical lens refraction flare (the exact horizontal streak in Apple's player)
                cylindricalLensLayer.isHidden = false
                cylindricalLensLayer.frame = containerPill.bounds
                if isDark {
                    cylindricalLensLayer.colors = [
                        NSColor(white: 1.0, alpha: 0.00).cgColor,
                        NSColor(white: 1.0, alpha: 0.12).cgColor,
                        NSColor(white: 1.0, alpha: 0.38).cgColor,
                        NSColor(white: 1.0, alpha: 0.14).cgColor,
                        NSColor(white: 0.0, alpha: 0.12).cgColor,
                        NSColor(white: 1.0, alpha: 0.00).cgColor
                    ]
                } else {
                    cylindricalLensLayer.colors = [
                        NSColor(white: 1.0, alpha: 0.00).cgColor,
                        NSColor(white: 1.0, alpha: 0.20).cgColor,
                        NSColor(white: 1.0, alpha: 0.50).cgColor,
                        NSColor(white: 1.0, alpha: 0.18).cgColor,
                        NSColor(white: 0.0, alpha: 0.04).cgColor,
                        NSColor(white: 1.0, alpha: 0.00).cgColor
                    ]
                }
                cylindricalLensLayer.locations = [0.0, 0.18, 0.36, 0.44, 0.50, 1.0]
                
                liquidFluidMeshLayer.isHidden = true
                stopLiquidFluidAnimation()
                
                // Translucent liquid glass backing plate
                containerPill.layer?.backgroundColor = SystemAppearanceHelper.liquidFluidBackingColor.cgColor
                containerPill.layer?.borderWidth = 1.5
                containerPill.layer?.borderColor = SystemAppearanceHelper.liquidFluidBorderColor.cgColor
                
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                artistLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                
                let primaryColor = SystemAppearanceHelper.primaryTextColor(for: .liquidFluid)
                let secondaryColor = SystemAppearanceHelper.secondaryTextColor(for: .liquidFluid)
                let tertiaryColor = SystemAppearanceHelper.tertiaryTextColor(for: .liquidFluid)
                let fluidBtnTint = SystemAppearanceHelper.controlButtonTint(for: .liquidFluid)
                
                titleLabel.textColor = primaryColor
                artistLabel.textColor = secondaryColor
                timeLabel.textColor = tertiaryColor
                
                waveformProgressView.accentColor = primaryColor
                
                playPauseButton.contentTintColor = primaryColor
                previousButton.contentTintColor = fluidBtnTint
                nextButton.contentTintColor = fluidBtnTint
                addToPlaylistButton.contentTintColor = fluidBtnTint
                repeatButton.contentTintColor = (repeatMode != .off) ? primaryColor : fluidBtnTint
                likeButton.contentTintColor = isLiked ? NSColor(red: 1.0, green: 0.28, blue: 0.38, alpha: 1.0) : fluidBtnTint
                searchIconButton.contentTintColor = fluidBtnTint
                fullScreenButton.contentTintColor = fluidBtnTint
                browserButton.contentTintColor = fluidBtnTint
                resetPositionButton.contentTintColor = fluidBtnTint
            }
        }

        if design != .liquidFluid {
            cylindricalLensLayer.isHidden = true
            liquidFluidMeshLayer.isHidden = true
            stopLiquidFluidAnimation()
        }

        downloadButton.updateVisuals()
        updateDownloadButtonState()
        searchField.applyTheme(design)
        refreshPlaylistsSection()
        updateSettingsThemeHighlight()
        updateBrowserButtonColor()
        updateAddToPlaylistButtonColor()
        updateRepeatButtonColor()
    }

    func setupLiquidFluidLayer() {
        liquidFluidMeshLayer.isHidden = true
    }

    func startLiquidFluidAnimation(palette1: [CGColor]? = nil, palette2: [CGColor]? = nil) {
        // No-op: Pure transparent watery glass uses natural screen optical refraction
    }

    func stopLiquidFluidAnimation() {
        liquidFluidMeshLayer.removeAllAnimations()
    }
}
