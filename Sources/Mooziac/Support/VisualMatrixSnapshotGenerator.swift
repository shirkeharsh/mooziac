import AppKit
import Foundation

public final class VisualMatrixSnapshotGenerator {
    public static func run() {
        print("\n📸 [Mooziac Snapshot Suite] Starting full visual permutation matrix sweep...")
        
        let outputDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Mooziac_Screenshots")
        
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let mockArtwork1 = createMockArtworkImage(title: "Ghost", subtitle: "Justin Bieber", colorA: NSColor.systemTeal, colorB: NSColor.systemIndigo)
        let mockArtwork2 = createMockArtworkImage(title: "Blinding Lights", subtitle: "The Weeknd", colorA: NSColor.systemRed, colorB: NSColor.systemOrange)
        
        var generatedFiles: [(filename: String, theme: String, style: String, panel: String, appearance: String, path: String)] = []
        
        let themes: [(design: PlayerDesign, name: String)] = [
            (.adaptive, "01_Adaptive_Ambient"),
            (.darkMode, "02_OLED_Dark"),
            (.glassMode, "03_Crystal_Glass"),
            (.liquidFluid, "04_Liquid_Glass")
        ]
        
        let progressStyles: [(style: ProgressStyle, name: String)] = [
            (.waveform, "Waveform"),
            (.neonGlow, "NeonGlow"),
            (.cyberDots, "CyberDots"),
            (.minimalLine, "MinimalLine")
        ]
        
        let appearances: [(appearance: NSAppearance?, name: String)] = [
            (NSAppearance(named: .darkAqua), "Dark_Mode"),
            (NSAppearance(named: .aqua), "Light_Mode")
        ]
        
        var count = 0
        
        for appMode in appearances {
            NSApp.appearance = appMode.appearance
            
            for themeItem in themes {
                PlayerDesign.current = themeItem.design
                
                let themeDir = outputDir.appendingPathComponent("\(themeItem.name)/\(appMode.name)")
                try? FileManager.default.createDirectory(at: themeDir, withIntermediateDirectories: true)
                
                for styleItem in progressStyles {
                    ProgressStyle.current = styleItem.style
                    
                    // 1. Compact Player (Playing)
                    let (compactPlayingView, window1) = createConfiguredPlayerView(
                        theme: themeItem.design,
                        style: styleItem.style,
                        artwork: mockArtwork1,
                        title: "Ghost",
                        artist: "Justin Bieber",
                        progress: 0.68,
                        isPlaying: true,
                        appearance: appMode.appearance
                    )
                    let filename1 = "\(themeItem.name)_\(styleItem.name)_Compact_Playing_\(appMode.name).png"
                    let path1 = themeDir.appendingPathComponent(filename1)
                    if saveViewSnapshot(compactPlayingView, to: path1) {
                        generatedFiles.append((filename1, themeItem.name, styleItem.name, "Compact Playing", appMode.name, path1.path))
                        count += 1
                    }
                    window1.close()
                    
                    // 2. Compact Player (Paused with different art)
                    let (compactPausedView, window2) = createConfiguredPlayerView(
                        theme: themeItem.design,
                        style: styleItem.style,
                        artwork: mockArtwork2,
                        title: "Blinding Lights",
                        artist: "The Weeknd",
                        progress: 0.35,
                        isPlaying: false,
                        appearance: appMode.appearance
                    )
                    let filename2 = "\(themeItem.name)_\(styleItem.name)_Compact_Paused_\(appMode.name).png"
                    let path2 = themeDir.appendingPathComponent(filename2)
                    if saveViewSnapshot(compactPausedView, to: path2) {
                        generatedFiles.append((filename2, themeItem.name, styleItem.name, "Compact Paused", appMode.name, path2.path))
                        count += 1
                    }
                    window2.close()
                }
                
                // 3. Playlists Library Drawer
                let (playlistView, window3) = createPlaylistLibrarySnapshotView(theme: themeItem.design, appearance: appMode.appearance)
                let filename3 = "\(themeItem.name)_Drawer_Playlists_\(appMode.name).png"
                let path3 = themeDir.appendingPathComponent(filename3)
                if saveViewSnapshot(playlistView, to: path3) {
                    generatedFiles.append((filename3, themeItem.name, "All Styles", "Playlist Library", appMode.name, path3.path))
                    count += 1
                }
                window3.close()
                
                // 4. Offline Downloads Drawer
                let (offlineView, window4) = createOfflineLibrarySnapshotView(theme: themeItem.design, appearance: appMode.appearance)
                let filename4 = "\(themeItem.name)_Drawer_Offline_Downloads_\(appMode.name).png"
                let path4 = themeDir.appendingPathComponent(filename4)
                if saveViewSnapshot(offlineView, to: path4) {
                    generatedFiles.append((filename4, themeItem.name, "All Styles", "Offline Library", appMode.name, path4.path))
                    count += 1
                }
                window4.close()
            }
        }
        
        generateInteractiveHTMLGallery(generatedFiles: generatedFiles, outputDir: outputDir)
        
        print("✅ [Mooziac Snapshot Suite] Successfully generated \(count) high-res screenshots!")
        print("📁 Saved to: \(outputDir.path)")
        print("🌐 Interactive HTML Gallery: \(outputDir.appendingPathComponent("gallery.html").path)\n")
    }
    
    // MARK: - View Creation Helpers
    
    private static func createConfiguredPlayerView(
        theme: PlayerDesign,
        style: ProgressStyle,
        artwork: NSImage,
        title: String,
        artist: String,
        progress: Double,
        isPlaying: Bool,
        appearance: NSAppearance?
    ) -> (NSView, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = appearance
        
        let playerView = DynamicIslandPlayerView(frame: NSRect(x: 0, y: 0, width: 360, height: 110))
        playerView.appearance = appearance
        window.contentView = playerView
        
        playerView.artworkImageView.image = artwork
        if let cg = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            playerView.updateAmbientGlow(cgImage: cg)
        }
        
        playerView.titleLabel.stringValue = title
        playerView.artistLabel.stringValue = artist
        playerView.timeLabel.stringValue = "02:18 / 03:45"
        playerView.waveformProgressView.progress = progress
        playerView.waveformProgressView.isPlaying = isPlaying
        playerView.playPauseButton.image = NSImage(systemSymbolName: isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)
        
        playerView.applyTheme()
        window.displayIfNeeded()
        playerView.layoutSubtreeIfNeeded()
        
        return (playerView, window)
    }
    
    private static func createPlaylistLibrarySnapshotView(theme: PlayerDesign, appearance: NSAppearance?) -> (NSView, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = appearance
        
        let playlistView = PlaylistLibraryView(frame: NSRect(x: 0, y: 0, width: 360, height: 380))
        playlistView.appearance = appearance
        window.contentView = playlistView
        
        window.displayIfNeeded()
        playlistView.layoutSubtreeIfNeeded()
        return (playlistView, window)
    }
    
    private static func createOfflineLibrarySnapshotView(theme: PlayerDesign, appearance: NSAppearance?) -> (NSView, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = appearance
        
        let offlineView = OfflineLibraryView(frame: NSRect(x: 0, y: 0, width: 360, height: 380))
        offlineView.appearance = appearance
        window.contentView = offlineView
        
        window.displayIfNeeded()
        offlineView.layoutSubtreeIfNeeded()
        return (offlineView, window)
    }
    
    // MARK: - Snapshot & Bitmap Export
    
    private static func saveViewSnapshot(_ view: NSView, to url: URL) -> Bool {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
    
    private static func createMockArtworkImage(title: String, subtitle: String, colorA: NSColor, colorB: NSColor) -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let img = NSImage(size: size)
        img.lockFocus()
        
        let gradient = NSGradient(starting: colorA, ending: colorB)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: pStyle
        ]
        let str = NSAttributedString(string: String(title.prefix(1)), attributes: attrs)
        str.draw(in: NSRect(x: 0, y: 90, width: 256, height: 60))
        
        img.unlockFocus()
        return img
    }
    
    // MARK: - Interactive HTML Gallery Generator
    
    private static func generateInteractiveHTMLGallery(
        generatedFiles: [(filename: String, theme: String, style: String, panel: String, appearance: String, path: String)],
        outputDir: URL
    ) {
        var cardHTML = ""
        for file in generatedFiles {
            let relativePath = file.path.replacingOccurrences(of: outputDir.path + "/", with: "")
            cardHTML += """
            <div class="card" data-theme="\(file.theme)" data-style="\(file.style)" data-panel="\(file.panel)" data-app="\(file.appearance)">
                <div class="preview-box">
                    <img src="\(relativePath)" alt="\(file.filename)" loading="lazy" onclick="openZoom(this.src, '\(file.filename)')">
                </div>
                <div class="info">
                    <div class="title">\(file.panel)</div>
                    <div class="tags">
                        <span class="tag theme">\(file.theme.replacingOccurrences(of: "_", with: " "))</span>
                        <span class="tag style">\(file.style)</span>
                        <span class="tag app">\(file.appearance)</span>
                    </div>
                </div>
            </div>
            """
        }
        
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>Mooziac UI Visual Matrix Gallery</title>
            <style>
                :root {
                    --bg: #0B0D13;
                    --card-bg: #141721;
                    --text: #F0F3F6;
                    --subtext: #8E9BAE;
                    --accent: #0085FF;
                    --border: rgba(255, 255, 255, 0.12);
                }
                * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; }
                body { background: var(--bg); color: var(--text); padding: 32px; min-height: 100vh; }
                header { margin-bottom: 32px; display: flex; justify-content: space-between; align-items: center; }
                h1 { font-size: 28px; font-weight: 700; background: linear-gradient(135deg, #FFF, #8E9BAE); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
                .subtitle { font-size: 14px; color: var(--subtext); margin-top: 4px; }
                
                .filters { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 28px; background: rgba(255, 255, 255, 0.04); padding: 16px; border-radius: 12px; border: 1px solid var(--border); }
                .filter-btn { background: rgba(255,255,255,0.08); border: 1px solid var(--border); color: var(--text); padding: 6px 14px; border-radius: 20px; font-size: 13px; cursor: pointer; transition: all 0.2s; }
                .filter-btn:hover, .filter-btn.active { background: var(--accent); border-color: var(--accent); color: #FFF; }
                
                .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 24px; }
                .card { background: var(--card-bg); border-radius: 14px; border: 1px solid var(--border); overflow: hidden; display: flex; flex-direction: column; transition: transform 0.2s, box-shadow 0.2s; }
                .card:hover { transform: translateY(-4px); box-shadow: 0 12px 30px rgba(0,0,0,0.5); }
                .preview-box { background: repeating-conic-gradient(#1a1d26 0% 25%, #12141c 0% 50%) 50% / 20px 20px; padding: 24px; display: flex; justify-content: center; align-items: center; min-height: 180px; }
                .preview-box img { max-width: 100%; max-height: 260px; object-fit: contain; cursor: zoom-in; filter: drop-shadow(0 10px 20px rgba(0,0,0,0.6)); border-radius: 18px; }
                .info { padding: 16px; }
                .title { font-size: 15px; font-weight: 600; margin-bottom: 8px; }
                .tags { display: flex; flex-wrap: wrap; gap: 6px; }
                .tag { font-size: 11px; padding: 3px 8px; border-radius: 6px; font-weight: 500; }
                .tag.theme { background: rgba(0, 133, 255, 0.2); color: #4DA8FF; }
                .tag.style { background: rgba(168, 85, 247, 0.2); color: #C084FC; }
                .tag.app { background: rgba(255, 255, 255, 0.1); color: #CBD5E1; }

                /* Zoom Modal */
                .modal { display: none; position: fixed; z-index: 1000; inset: 0; background: rgba(0,0,0,0.85); backdrop-filter: blur(10px); justify-content: center; align-items: center; cursor: zoom-out; }
                .modal img { max-width: 90vw; max-height: 90vh; border-radius: 20px; box-shadow: 0 20px 60px rgba(0,0,0,0.8); }
            </style>
        </head>
        <body>
            <header>
                <div>
                    <h1>Mooziac Visual Regression & Permutation Matrix</h1>
                    <div class="subtitle">Complete visual verification across 4 Themes, 4 Scrubber Styles, Panels & Appearances</div>
                </div>
            </header>

            <div class="filters" id="filters">
                <button class="filter-btn active" onclick="filterGrid('all')">Show All</button>
                <button class="filter-btn" onclick="filterGrid('01_Adaptive_Ambient')">Theme: Adaptive</button>
                <button class="filter-btn" onclick="filterGrid('02_OLED_Dark')">Theme: OLED Dark</button>
                <button class="filter-btn" onclick="filterGrid('03_Crystal_Glass')">Theme: Crystal Glass</button>
                <button class="filter-btn" onclick="filterGrid('04_Liquid_Glass')">Theme: Liquid Glass</button>
            </div>

            <div class="grid" id="grid">
                \(cardHTML)
            </div>

            <div class="modal" id="modal" onclick="this.style.display='none'">
                <img id="modalImg" src="">
            </div>

            <script>
                function filterGrid(theme) {
                    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                    event.target.classList.add('active');
                    document.querySelectorAll('.card').forEach(card => {
                        if (theme === 'all' || card.dataset.theme.includes(theme)) {
                            card.style.display = 'flex';
                        } else {
                            card.style.display = 'none';
                        }
                    });
                }
                function openZoom(src, title) {
                    const m = document.getElementById('modal');
                    const img = document.getElementById('modalImg');
                    img.src = src;
                    m.style.display = 'flex';
                }
            </script>
        </body>
        </html>
        """
        
        try? html.write(to: outputDir.appendingPathComponent("gallery.html"), atomically: true, encoding: .utf8)
    }
}
