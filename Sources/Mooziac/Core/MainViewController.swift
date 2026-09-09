import AppKit
import WebKit

final class PassthroughBrowserContainerView: NSView {
    var isHitTestingEnabled: Bool = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isHitTestingEnabled else { return nil }
        return super.hitTest(point)
    }
}

class MainViewController: NSViewController, DynamicIslandPlayerViewDelegate, HeaderViewDelegate, OfflineLibraryViewDelegate, PlaylistLibraryViewDelegate {
    let headerView = HeaderView()
    let webViewContainer = YTMWebViewContainer()
    let dynamicIslandPlayer = DynamicIslandPlayerView()
    let offlineLibraryView = OfflineLibraryView()
    let playlistLibraryView = PlaylistLibraryView()
    private let browserContainerView = PassthroughBrowserContainerView()
    
    var onChangeSize: ((CGFloat, CGFloat) -> Void)?
    var onResetPosition: (() -> Void)?
    public var isBrowserMode: Bool = false
    public var isOfflineLibraryMode: Bool = false
    public var isPlaylistLibraryMode: Bool = false
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        setBrowserVisible(false)
        setOfflineLibraryVisible(false)
        setPlaylistLibraryVisible(false)
        
        // Start Global Shortcuts Monitor
        GlobalHotKeyManager.shared.startMonitoring()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        dynamicIslandPlayer.translatesAutoresizingMaskIntoConstraints = false
        dynamicIslandPlayer.delegate = self

        offlineLibraryView.translatesAutoresizingMaskIntoConstraints = false
        offlineLibraryView.delegate = self
        offlineLibraryView.isHidden = true

        playlistLibraryView.translatesAutoresizingMaskIntoConstraints = false
        playlistLibraryView.delegate = self
        playlistLibraryView.isHidden = true
        
        browserContainerView.translatesAutoresizingMaskIntoConstraints = false
        browserContainerView.wantsLayer = true
        browserContainerView.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.98).cgColor
        browserContainerView.layer?.cornerRadius = 20.0
        browserContainerView.layer?.masksToBounds = true
        browserContainerView.layer?.borderWidth = 1.0
        browserContainerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        browserContainerView.alphaValue = 0.001
        browserContainerView.isHidden = false
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.delegate = self
        headerView.isHidden = true // Hide headerView in player mode to prevent hit-testing overlap with player buttons!
        
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        
        browserContainerView.addSubview(headerView)
        browserContainerView.addSubview(webViewContainer)
        
        view.addSubview(browserContainerView)
        view.addSubview(offlineLibraryView)
        view.addSubview(playlistLibraryView)
        view.addSubview(dynamicIslandPlayer)
        
        NSLayoutConstraint.activate([
            browserContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            browserContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            browserContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browserContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            headerView.topAnchor.constraint(equalTo: browserContainerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: browserContainerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: browserContainerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 36),
            
            webViewContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: browserContainerView.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: browserContainerView.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: browserContainerView.trailingAnchor),
            
            offlineLibraryView.topAnchor.constraint(equalTo: view.topAnchor),
            offlineLibraryView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            offlineLibraryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineLibraryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            playlistLibraryView.topAnchor.constraint(equalTo: view.topAnchor),
            playlistLibraryView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playlistLibraryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playlistLibraryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            dynamicIslandPlayer.topAnchor.constraint(equalTo: view.topAnchor),
            dynamicIslandPlayer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dynamicIslandPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dynamicIslandPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupObservers() {
        NowPlayingManager.shared.addObserver { [weak self] state in
            self?.dynamicIslandPlayer.updateState(state)
        }
    }
    
    func setBrowserVisible(_ visible: Bool) {
        isBrowserMode = visible
        browserContainerView.isHitTestingEnabled = visible
        dynamicIslandPlayer.collapseSettings()
        if visible {
            if isOfflineLibraryMode {
                setOfflineLibraryVisible(false)
            }
            if isPlaylistLibraryMode {
                setPlaylistLibraryVisible(false)
            }
            headerView.isHidden = false
            browserContainerView.isHidden = false
            browserContainerView.alphaValue = 1.0
            dynamicIslandPlayer.isHidden = true
            offlineLibraryView.isHidden = true
            playlistLibraryView.isHidden = true
            onChangeSize?(360, 650)
            webViewContainer.selectSongTab()
        } else {
            headerView.isHidden = true // Hide headerView in player mode!
            browserContainerView.alphaValue = 0.001
            browserContainerView.isHidden = false
            if !isOfflineLibraryMode && !isPlaylistLibraryMode {
                dynamicIslandPlayer.isHidden = false
                onChangeSize?(360, 120)
            }
            if let currentUrl = webViewContainer.webView.url?.absoluteString, !currentUrl.contains("music.youtube.com") {
                webViewContainer.loadMusicHome()
            }
        }
    }

    func setOfflineLibraryVisible(_ visible: Bool) {
        isOfflineLibraryMode = visible
        dynamicIslandPlayer.collapseSettings()
        if visible {
            if isBrowserMode {
                setBrowserVisible(false)
            }
            if isPlaylistLibraryMode {
                setPlaylistLibraryVisible(false)
            }
            dynamicIslandPlayer.isHidden = true
            browserContainerView.isHidden = true
            offlineLibraryView.isHidden = false
            offlineLibraryView.alphaValue = 1.0
            playlistLibraryView.isHidden = true
            offlineLibraryView.refreshLibrary()
            onChangeSize?(380, 420)
        } else {
            offlineLibraryView.isHidden = true
            if !isBrowserMode && !isPlaylistLibraryMode {
                dynamicIslandPlayer.isHidden = false
                browserContainerView.isHidden = false
                onChangeSize?(360, 120)
            }
        }
    }

    func setPlaylistLibraryVisible(_ visible: Bool) {
        isPlaylistLibraryMode = visible
        dynamicIslandPlayer.collapseSettings()
        if visible {
            if isBrowserMode {
                setBrowserVisible(false)
            }
            if isOfflineLibraryMode {
                setOfflineLibraryVisible(false)
            }
            dynamicIslandPlayer.isHidden = true
            browserContainerView.isHidden = true
            offlineLibraryView.isHidden = true
            playlistLibraryView.isHidden = false
            playlistLibraryView.alphaValue = 1.0
            playlistLibraryView.refresh()
            onChangeSize?(380, 420)
        } else {
            playlistLibraryView.isHidden = true
            if !isBrowserMode && !isOfflineLibraryMode {
                dynamicIslandPlayer.isHidden = false
                browserContainerView.isHidden = false
                onChangeSize?(360, 120)
            }
        }
    }
    
    // MARK: - DynamicIslandPlayerViewDelegate
    func dynamicIslandDidSearch(query: String) {
        playSearchQuery(query)
    }

    public func playSearchQuery(_ query: String) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return }

        // Mood change / search: explicitly release any active playlist context
        PlaylistManager.shared.clearActiveContext()

        // 1. Offline Mode Search & Local Fallback
        if NowPlayingManager.shared.engineMode == .offline || !NetworkMonitor.shared.isReachable {
            if let result = findBestLocalTrack(for: cleanQuery) {
                NowPlayingManager.shared.playOfflineTrack(result.best, in: result.matches)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "▶ Playing: \"\(result.best.title)\"")
                setBrowserVisible(false)
                setOfflineLibraryVisible(false)
                return
            } else if !NetworkMonitor.shared.isReachable {
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "⚠️ Offline: No local song matches \"\(cleanQuery)\"")
                return
            }
        }

        // 2. Online Mode Search
        NowPlayingManager.shared.switchToOnlineMode()
        setBrowserVisible(false)
        setOfflineLibraryVisible(false)

        Log.playback.debug("Searching and auto-playing '\(cleanQuery)'")
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "🔍 Searching: \"\(cleanQuery)\"")

        // Fast Path: Resolve exact top matching song via InnerTube API without webView reload
        YTMClient.shared.searchTopTrack(query: cleanQuery) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let track):
                    Log.playback.info("Direct search resolved track '\(track.title)' by '\(track.artist)' (videoId: \(track.videoId))")
                    let displayTitle = track.artist.isEmpty ? track.title : "\(track.title) - \(track.artist)"
                    CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "▶ Playing: \"\(displayTitle)\"")
                    self.webViewContainer.navigateToVideo(videoId: track.videoId)
                case .failure(let error):
                    Log.playback.warning("InnerTube search fallback to webView search page: \(error.localizedDescription)")
                    self.performWebViewSearchFallback(query: cleanQuery)
                }
            }
        }
    }

    private func performWebViewSearchFallback(query: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.youtube.com/search?q=\(encoded)") else { return }

        webViewContainer.webView.load(URLRequest(url: url))
        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "🔍 Playing: \"\(query)\"")

        // Evaluate safe autoplay script after page has had time to load
        for delay in [1.2, 2.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.webViewContainer.webView.evaluateJavaScript(Self.safeSearchAutoPlayJS, completionHandler: nil)
            }
        }
    }

    public static let safeSearchAutoPlayJS = """
    (function() {
        var href = window.location.href;
        if (href.indexOf('music.youtube.com') === -1 || href.indexOf('search?q=') === -1) {
            return;
        }

        function triggerClick(element) {
            if (!element) return false;
            try {
                element.scrollIntoView({ behavior: 'instant', block: 'center' });
                var opts = { bubbles: true, cancelable: true, view: window };
                element.dispatchEvent(new MouseEvent('mousedown', opts));
                element.dispatchEvent(new MouseEvent('mouseup', opts));
                element.dispatchEvent(new MouseEvent('click', opts));
                if (typeof element.click === 'function') { element.click(); }
                return true;
            } catch(e) {
                try { element.click(); return true; } catch(err) { return false; }
            }
        }

        function ensurePlaying() {
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.playVideo === 'function') {
                    var state = typeof player.getPlayerState === 'function' ? player.getPlayerState() : -1;
                    if (state !== 1 && state !== 3) {
                        player.playVideo();
                    }
                }
            } catch(e) {}

            try {
                var video = document.querySelector('video');
                if (video && video.paused && !video.ended && video.readyState >= 1) {
                    video.play().catch(function(){});
                }
            } catch(e) {}

            try {
                var playBtn = document.querySelector('ytmusic-player-bar #play-pause-button[aria-label="Play"]') ||
                              document.querySelector('#play-pause-button[title="Play"]');
                if (playBtn) {
                    triggerClick(playBtn);
                }
            } catch(e) {}
        }

        var clickedTrack = false;

        function findAndPlayTopTrack() {
            if (window.location.href.indexOf('search?q=') === -1) return false;

            var searchContainer = document.querySelector('ytmusic-tab-renderer[page-type="MUSIC_PAGE_TYPE_SEARCH"]') ||
                                  document.querySelector('ytmusic-section-list-renderer') ||
                                  document.querySelector('ytmusic-search-page');
            if (!searchContainer) return false;

            if (!clickedTrack) {
                // Priority 1: Top Result Card ONLY if it is a Song or Video (not artist radio/shuffle)
                var topCard = searchContainer.querySelector('ytmusic-card-shelf-renderer');
                if (topCard) {
                    var subEl = topCard.querySelector('.subtitle') || topCard.querySelector('#subtitle');
                    var subText = subEl ? (subEl.textContent || '') : '';
                    var isArtist = subText.toLowerCase().indexOf('artist') !== -1;
                    var isPodcast = subText.toLowerCase().indexOf('episode') !== -1 || subText.toLowerCase().indexOf('podcast') !== -1;

                    if (!isArtist && !isPodcast) {
                        var topCardBtn = topCard.querySelector('ytmusic-play-button-renderer #button') ||
                                         topCard.querySelector('ytmusic-play-button-renderer') ||
                                         topCard.querySelector('#play-button');
                        if (topCardBtn && triggerClick(topCardBtn)) {
                            clickedTrack = true;
                            setTimeout(ensurePlaying, 350);
                            return true;
                        }
                    }

                    // For artist cards, check if the card contains individual top songs
                    var cardSong = topCard.querySelector('ytmusic-responsive-list-item-renderer ytmusic-play-button-renderer #button') ||
                                   topCard.querySelector('ytmusic-responsive-list-item-renderer a.yt-simple-endpoint');
                    if (cardSong && triggerClick(cardSong)) {
                        clickedTrack = true;
                        setTimeout(ensurePlaying, 350);
                        return true;
                    }
                }

                // Priority 2: First Song in Songs shelf
                var songRows = searchContainer.querySelectorAll('ytmusic-responsive-list-item-renderer');
                for (var i = 0; i < songRows.length; i++) {
                    var row = songRows[i];
                    var btn = row.querySelector('ytmusic-play-button-renderer #button') ||
                              row.querySelector('ytmusic-play-button-renderer') ||
                              row.querySelector('.play-button') ||
                              row.querySelector('#play-button');
                    if (btn && triggerClick(btn)) {
                        clickedTrack = true;
                        setTimeout(ensurePlaying, 350);
                        return true;
                    }
                    var link = row.querySelector('a.yt-simple-endpoint') || row.querySelector('.title a');
                    if (link && triggerClick(link)) {
                        clickedTrack = true;
                        setTimeout(ensurePlaying, 350);
                        return true;
                    }
                }
            } else {
                ensurePlaying();
            }

            return false;
        }

        var attempts = 0;
        var timer = setInterval(function() {
            attempts++;
            if (findAndPlayTopTrack() || attempts > 25) {
                clearInterval(timer);
            }
        }, 250);
    })();
    """

    private func findBestLocalTrack(for query: String) -> (best: LocalTrack, matches: [LocalTrack])? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else { return nil }

        let tracks = LocalLibraryManager.shared.allTracks
        guard !tracks.isEmpty else { return nil }

        var scored: [(track: LocalTrack, score: Int)] = []
        let queryWords = cleanQuery.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        for track in tracks {
            let tTitle = track.title.lowercased()
            let tArtist = track.artist.lowercased()
            let tAlbum = track.album.lowercased()

            var score = 0
            if tTitle == cleanQuery {
                score += 1000
            } else if tTitle.hasPrefix(cleanQuery) {
                score += 500
            } else if tTitle.contains(cleanQuery) {
                score += 300
            }

            if "\(tArtist) \(tTitle)".contains(cleanQuery) || "\(tTitle) \(tArtist)".contains(cleanQuery) {
                score += 400
            }

            for word in queryWords {
                if tTitle.contains(word) { score += 50 }
                if tArtist.contains(word) { score += 30 }
                if tAlbum.contains(word) { score += 10 }
            }

            if score > 0 {
                scored.append((track, score))
            }
        }

        scored.sort { $0.score > $1.score }
        if let top = scored.first {
            return (best: top.track, matches: scored.map { $0.track })
        }
        return nil
    }
    
    func dynamicIslandDidTapPlayPause() {
        NowPlayingManager.shared.togglePlayPause()
    }
    
    func dynamicIslandDidTapNext() {
        NowPlayingManager.shared.nextTrack()
    }
    
    func dynamicIslandDidTapPrevious() {
        NowPlayingManager.shared.previousTrack()
    }

    func dynamicIslandDidTapShuffle() {
        NowPlayingManager.shared.toggleShuffle()
    }

    func dynamicIslandDidTapRepeat() {
        NowPlayingManager.shared.toggleRepeat()
    }
    
    func dynamicIslandDidToggleExpanded(expanded: Bool) {
        if expanded {
            onChangeSize?(360, 480)
        } else {
            onChangeSize?(360, 120)
        }
    }
    
    func dynamicIslandDidSeek(to seconds: Double) {
        NowPlayingManager.shared.seek(to: seconds)
    }
    
    func dynamicIslandDidTapWebBrowser() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if StatusItemManager.shared?.isDraggedFromDock == true {
                StatusItemManager.shared?.dockBackToMenuBar()
            }
            self.setBrowserVisible(!self.isBrowserMode)
        }
    }

    func dynamicIslandDidTapOfflineLibrary() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let willShow = !self.isPlaylistLibraryMode
            self.setPlaylistLibraryVisible(willShow)
            if willShow {
                self.playlistLibraryView.refresh()
            }
        }
    }
    
    func dynamicIslandDidTapResetPosition() {
        StatusItemManager.shared?.dockBackToMenuBar()
        onResetPosition?()
    }

    func dynamicIslandDidTapPlaylistLibrary(playlistID: String?) {
        setPlaylistLibraryVisible(true)
        if let id = playlistID {
            playlistLibraryView.openPlaylist(id: id)
        } else {
            playlistLibraryView.openPlaylists()
        }
    }

    // MARK: - OfflineLibraryViewDelegate
    func offlineLibraryDidSelectTrack(_ track: LocalTrack, in queue: [LocalTrack]) {
        NowPlayingManager.shared.playOfflineTrack(track, in: queue)
        setOfflineLibraryVisible(false)
    }

    func offlineLibraryDidRequestClose() {
        setOfflineLibraryVisible(false)
    }

    func offlineLibraryDidRequestImport() {
        // Handled directly inside OfflineLibraryView
    }
    
    // MARK: - PlaylistLibraryViewDelegate
    func playlistLibraryDidRequestClose() {
        setPlaylistLibraryVisible(false)
    }

    func playlistLibraryDidPlayOnline(videoId: String) {
        NowPlayingManager.shared.switchToOnlineMode()
        setPlaylistLibraryVisible(false)
        PlaylistManager.shared.playOnlineVideo(videoId: videoId)
    }
    
    // MARK: - HeaderViewDelegate
    func headerViewDidTapBack() {
        if webViewContainer.webView.canGoBack { webViewContainer.webView.goBack() }
    }
    
    func headerViewDidTapForward() {
        if webViewContainer.webView.canGoForward { webViewContainer.webView.goForward() }
    }
    
    func headerViewDidTapReload() {
        webViewContainer.reloadPlayerEngine()
    }
    
    func headerViewDidTapHome() {
        webViewContainer.loadMusicHome()
    }
    
    func headerViewDidTapAccount() {
        setBrowserVisible(true)
        webViewContainer.loadGoogleLogin()
    }
    
    func headerViewDidTapPlayerOnly() {
        setBrowserVisible(false)
    }
    
    func headerViewDidTapQuit() {
        let alert = NSAlert()
        alert.messageText = "Quit Mooziac?"
        alert.informativeText = "Are you sure you want to quit Mooziac?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func spotifyPlayerDidTapLogin() {
        setBrowserVisible(true)
        webViewContainer.loadGoogleLogin()
    }
}
