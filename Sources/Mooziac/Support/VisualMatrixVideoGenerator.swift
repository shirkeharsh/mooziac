import AppKit
import AVFoundation
import CoreGraphics
import Foundation

public final class VisualMatrixVideoGenerator {
    public static func run(completion: @escaping (URL?) -> Void) {
        print("\n🎬 [Mooziac Video Studio] Starting automated 60 FPS MP4 video render...")
        
        let outputURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Mooziac_Showcase_Demo.mp4")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        let width = 1280
        let height = 720
        let fps: Int32 = 60
        let durationSeconds: Double = 16.0
        let totalFrames = Int(durationSeconds * Double(fps))
        
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            print("❌ Failed to create AVAssetWriter")
            completion(nil)
            return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        guard writer.canAdd(writerInput) else {
            print("❌ Cannot add writer input")
            completion(nil)
            return
        }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Mock Artworks
        let art1 = createMockArtwork(title: "Ghost", colA: NSColor.systemTeal, colB: NSColor.systemIndigo)
        let art2 = createMockArtwork(title: "Blinding Lights", colA: NSColor.systemRed, colB: NSColor.systemOrange)
        let art3 = createMockArtwork(title: "Midnight City", colA: NSColor.systemPurple, colB: NSColor.systemPink)
        let art4 = createMockArtwork(title: "Starboy", colA: NSColor.systemBlue, colB: NSColor.systemCyan)
        
        // Build the player view
        let playerW: CGFloat = 380
        let playerH: CGFloat = 110
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: playerW, height: playerH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        
        let playerView = DynamicIslandPlayerView(frame: NSRect(x: 0, y: 0, width: playerW, height: playerH))
        window.contentView = playerView
        
        for frameIndex in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.002))
            }
            
            let currentTimeSec = Double(frameIndex) / Double(fps)
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)
            
            // Storyboard State Selection:
            let progress: Double
            let isLiked: Bool
            let repeatMode: RepeatMode
            let currentArt: NSImage
            let currentTitle: String
            let currentArtist: String
            let theme: PlayerDesign
            let style: ProgressStyle
            
            if currentTimeSec < 4.0 {
                // Scene 1: Adaptive Ambient Glow (Ghost - Justin Bieber)
                theme = .adaptive
                style = .waveform
                currentArt = art1
                currentTitle = "Ghost"
                currentArtist = "Justin Bieber"
                progress = (currentTimeSec / 4.0) * 0.40
                isLiked = currentTimeSec > 1.8
                repeatMode = .off
            } else if currentTimeSec < 8.0 {
                // Scene 2: OLED Pitch Black (Blinding Lights - The Weeknd)
                let t = currentTimeSec - 4.0
                theme = .darkMode
                style = .neonGlow
                currentArt = art2
                currentTitle = "Blinding Lights"
                currentArtist = "The Weeknd"
                progress = 0.40 + (t / 4.0) * 0.35
                isLiked = true
                repeatMode = .one
            } else if currentTimeSec < 12.0 {
                // Scene 3: Crystal Glass (Midnight City - M83)
                let t = currentTimeSec - 8.0
                theme = .glassMode
                style = .cyberDots
                currentArt = art3
                currentTitle = "Midnight City"
                currentArtist = "M83"
                progress = 0.75 + (t / 4.0) * 0.20
                isLiked = false
                repeatMode = .off
            } else {
                // Scene 4: Apple Control Center Liquid Optical Glass (Starboy - The Weeknd)
                let t = currentTimeSec - 12.0
                theme = .liquidFluid
                style = .waveform
                currentArt = art4
                currentTitle = "Starboy"
                currentArtist = "The Weeknd ft. Daft Punk"
                progress = 0.10 + (t / 4.0) * 0.50
                isLiked = true
                repeatMode = .one
            }
            
            PlayerDesign.current = theme
            ProgressStyle.current = style
            playerView.artworkImageView.image = currentArt
            if let cg = currentArt.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                playerView.updateAmbientGlow(cgImage: cg)
            }
            playerView.titleLabel.stringValue = currentTitle
            playerView.artistLabel.stringValue = currentArtist
            
            let curSec = Int(progress * 225.0)
            let min = curSec / 60
            let sec = curSec % 60
            playerView.timeLabel.stringValue = String(format: "%02d:%02d / 03:45", min, sec)
            
            playerView.waveformProgressView.progress = progress
            playerView.waveformProgressView.isPlaying = true
            playerView.playPauseButton.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)
            
            playerView.isLiked = isLiked
            playerView.likeButton.image = NSImage(systemSymbolName: isLiked ? "heart.fill" : "heart", accessibilityDescription: nil)
            playerView.repeatMode = repeatMode
            
            playerView.applyTheme()
            window.displayIfNeeded()
            playerView.layoutSubtreeIfNeeded()
            
            if let pixelBuffer = createCompositedPixelBuffer(
                playerView: playerView,
                width: width,
                height: height,
                themeName: themeNameFor(theme),
                styleName: styleNameFor(style),
                timeSec: currentTimeSec
            ) {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
            
            if frameIndex % 120 == 0 {
                let pct = Int((Double(frameIndex) / Double(totalFrames)) * 100)
                print("🎥 Rendering frames: \(pct)% (\(frameIndex)/\(totalFrames))")
            }
        }
        
        writerInput.markAsFinished()
        let sema = DispatchSemaphore(value: 0)
        writer.finishWriting {
            sema.signal()
        }
        sema.wait()
        
        print("\n🎉 [Mooziac Video Studio] Render Complete!")
        print("📹 Saved MP4 Video to: \(outputURL.path)\n")
        completion(outputURL)
    }
    
    // MARK: - Pixel Buffer Compositing
    
    private static func createCompositedPixelBuffer(
        playerView: NSView,
        width: Int,
        height: Int,
        themeName: String,
        styleName: String,
        timeSec: Double
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pxData = CVPixelBufferGetBaseAddress(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let ctx = CGContext(
            data: pxData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        
        // 1. Draw Cinematic Dark Studio Backdrop
        drawBackgroundWallpaper(ctx: ctx, width: width, height: height, timeSec: timeSec)
        
        // 2. Render Player View Bitmap
        guard let rep = playerView.bitmapImageRepForCachingDisplay(in: playerView.bounds) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        rep.size = playerView.bounds.size
        playerView.cacheDisplay(in: playerView.bounds, to: rep)
        
        if let cgImage = rep.cgImage {
            let pW = CGFloat(playerView.bounds.width)
            let pH = CGFloat(playerView.bounds.height)
            let pX = (CGFloat(width) - pW) / 2.0
            let pY = (CGFloat(height) - pH) / 2.0
            
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.65).cgColor)
            ctx.draw(cgImage, in: CGRect(x: pX, y: pY, width: pW, height: pH))
            ctx.restoreGState()
        }
        
        // 3. Draw Watermark & Current Theme Overlay
        drawOverlayHUD(ctx: ctx, width: width, height: height, themeName: themeName, styleName: styleName)
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
    
    private static func drawBackgroundWallpaper(ctx: CGContext, width: Int, height: Int, timeSec: Double) {
        let colors = [
            NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor,
            NSColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1.0).cgColor,
            NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
        ] as CFArray
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 0.5, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: height),
                end: CGPoint(x: width, y: 0),
                options: []
            )
        }
        
        let spotX = CGFloat(width) / 2.0
        let spotY = CGFloat(height) / 2.0
        let spotColors = [
            NSColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 0.35).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        if let spotGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: spotColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(
                spotGrad,
                startCenter: CGPoint(x: spotX, y: spotY),
                startRadius: 0,
                endCenter: CGPoint(x: spotX, y: spotY),
                endRadius: 360,
                options: []
            )
        }
    }
    
    private static func drawOverlayHUD(ctx: CGContext, width: Int, height: Int, themeName: String, styleName: String) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor(white: 0.70, alpha: 1.0)
        ]
        
        let titleStr = NSAttributedString(string: "Mooziac for macOS", attributes: titleAttrs)
        let subStr = NSAttributedString(string: "Theme: \(themeName) • Scrubber: \(styleName)", attributes: subAttrs)
        
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        
        titleStr.draw(at: NSPoint(x: 50, y: height - 65))
        subStr.draw(at: NSPoint(x: 50, y: height - 90))
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private static func themeNameFor(_ theme: PlayerDesign) -> String {
        switch theme {
        case .adaptive: return "Adaptive Ambient Glow"
        case .darkMode: return "OLED Pitch Black"
        case .glassMode: return "Pure Crystal Glass"
        case .liquidFluid: return "Apple Control Center Liquid Glass"
        }
    }
    
    private static func styleNameFor(_ style: ProgressStyle) -> String {
        switch style {
        case .waveform: return "Dynamic Waveform"
        case .neonGlow: return "Neon Glow"
        case .cyberDots: return "Cyber Dots"
        case .minimalLine: return "Minimal Line"
        }
    }
    
    private static func createMockArtwork(title: String, colA: NSColor, colB: NSColor) -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let img = NSImage(size: size)
        img.lockFocus()
        let gradient = NSGradient(starting: colA, ending: colB)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: String(title.prefix(1)), attributes: attrs)
        str.draw(in: NSRect(x: 105, y: 95, width: 60, height: 60))
        img.unlockFocus()
        return img
    }
}
