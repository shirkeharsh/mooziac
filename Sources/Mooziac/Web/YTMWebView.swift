import Foundation
import WebKit
import AppKit

class YTMWebViewContainer: NSView, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    let webView: WKWebView
    private let progressView = NSProgressIndicator()
    private let offlineOverlay = OfflineOverlayView()
    private var hasRestoredInitialPosition = false
    
    private var shouldRestoreSavedTime = false
    public var autoPlayOnHomeLoad = false
    
    // MARK: - WebContent crash recovery state
    private var isRecoveringFromTermination = false
    private var recoveryVideoId = ""
    private var recoveryTime: Double = 0
    private var recoveryResumePlayback = false
    private var recoveryWatchdog: DispatchWorkItem?
    
    override init(frame frameRect: NSRect) {
        URLCache.shared.memoryCapacity = 512 * 1024
        URLCache.shared.diskCapacity = 2 * 1024 * 1024
        
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = true
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        config.preferences.setValue(false, forKey: "developerExtrasEnabled")
        
        // Minimal CSS injection: collapse video elements out of layout completely (audio plays uninterrupted),
        // hide cinematic background layers and video clutter, and format native song artwork.
        // CSS is JSON-encoded below so the injected JS string literal is always valid.
        let cssString = """
        #song-video, #player-video, .html5-video-player, video {
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
            width: 1px !important;
            height: 1px !important;
            opacity: 0.0001 !important;
            pointer-events: none !important;
            overflow: hidden !important;
            z-index: -1 !important;
        }
        #cinematics, .background-gradient, #background-gradient,
        paper-ripple, #cinematics-container, ytm-cinematics, .ytmusic-browse-response[background-gradient],
        .ytp-ce-element, .ytp-cards-teaser, .ytp-chrome-top, .ytp-gradient-top,
        .ytp-gradient-bottom, .annotation, .ytp-pause-overlay {
            display: none !important;
            visibility: hidden !important;
        }
        * {
            backdrop-filter: none !important;
        }
        #song-image, .song-image {
            display: flex !important;
            visibility: visible !important;
            opacity: 1 !important;
            width: 100% !important;
            height: 100% !important;
            align-items: center !important;
            justify-content: center !important;
            position: relative !important;
        }
        #song-image #img, #song-image img, .song-image img {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            margin: auto !important;
            max-width: 100% !important;
            max-height: 100% !important;
            object-fit: contain !important;
            border-radius: 8px !important;
        }
        """
        // JSON-encode the CSS so the injected JS string literal is always valid
        // (multi-line CSS embedded directly would break the script).
        let cssJSON: String
        if let data = try? JSONEncoder().encode(cssString),
           let str = String(data: data, encoding: .utf8) {
            cssJSON = str
        } else {
            cssJSON = "\"\""
        }
        let cssScript = WKUserScript(
            source: """
            var style = document.createElement('style');
            style.innerHTML = \(cssJSON);
            (document.head || document.documentElement).appendChild(style);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(cssScript)
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.customUserAgent = YTMWebViewContainer.userAgent
        
        super.init(frame: frameRect)
        
        config.websiteDataStore.httpCookieStore.add(self)
        
        let blockRules = """
        [
            { "trigger": { "url-filter": ".*google-analytics\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*doubleclick\\\\.net.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googletagmanager\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googleadservices\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googlesyndication\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googletagservices\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*mobileads\\\\.google\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*adsafeprotected\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*scorecardresearch\\\\.com.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*quantserve\\\\.com.*" }, "action": { "type": "block" } }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "YTMBlockRules", encodedContentRuleList: blockRules) { [weak self] ruleList, error in
            if let ruleList = ruleList {
                self?.webView.configuration.userContentController.add(ruleList)
            }
        }
        
        setupViews()
        setupWebView()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("YTM_reloadWebView"), object: nil, queue: .main) { [weak self] _ in
            self?.reloadPlayerEngine()
        }
        
        NotificationCenter.default.addObserver(forName: NetworkMonitor.statusChangedNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let isReachable = note.userInfo?["isReachable"] as? Bool ?? true
            self.offlineOverlay.updateNetworkState(isReachable: isReachable)
            if !isReachable {
                self.showOfflineOverlay()
            }
        }
        
        NotificationCenter.default.addObserver(forName: NetworkMonitor.reconnectedNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            print("[YTMWebView] Reconnected to network, auto-reloading webview...")
            self.hideOfflineOverlay()
            self.reloadPlayerEngine()
        }
    }
    
    deinit {
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
    }
    
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        LikedSongsManager.shared.refreshSignInStatus()
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let hasAuth = cookies.contains { cookie in
                (cookie.name == "SAPISID" || cookie.name == "__Secure-3PAPISID" || cookie.name == "__Secure-1PAPISID") &&
                (cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com"))
            }
            if hasAuth {
                DispatchQueue.main.async {
                    if let urlStr = self.webView.url?.absoluteString,
                       (urlStr.contains("accounts.google.com") || urlStr.contains("myaccount.google.com")) {
                        print("[YTMWebView] Auth cookies detected while on Google accounts; redirecting to music site")
                        self.loadMusicHome()
                    }
                }
            }
        }
    }
    
    public func loadMusicHome(autoPlayRandom: Bool = false) {
        self.autoPlayOnHomeLoad = autoPlayRandom
        if let defaultUrl = URL(string: "https://music.youtube.com/") {
            print("[YTMWebView] Navigating to music site: \(defaultUrl.absoluteString)")
            webView.load(URLRequest(url: defaultUrl))
        }
    }
    
    public func reloadPlayerEngine(forceHome: Bool = false) {
        NowPlayingManager.shared.switchToOnlineMode()
        let currentUrl = webView.url?.absoluteString ?? ""
        if forceHome || !currentUrl.contains("music.youtube.com") {
            loadMusicHome()
        } else {
            webView.reload()
        }
    }
    
    public func playRandomTrackOnMusicSite() {
        let js = """
        (function() {
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

            function findAndPlayRandom() {
                var playBtns = Array.from(document.querySelectorAll(
                    'ytmusic-responsive-list-item-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-two-row-item-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-card-shelf-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-shelf-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-item-section-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-carousel-shelf-basic-header-renderer ytmusic-play-button-renderer #button, ' +
                    'ytmusic-play-button-renderer #button, ' +
                    'ytmusic-play-button-renderer, ' +
                    '.play-button'
                )).filter(function(el) {
                    return (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });

                if (playBtns.length > 0) {
                    var idx = Math.floor(Math.random() * playBtns.length);
                    if (triggerClick(playBtns[idx])) return true;
                }

                var links = Array.from(document.querySelectorAll(
                    'ytmusic-responsive-list-item-renderer a.yt-simple-endpoint, ' +
                    'ytmusic-two-row-item-renderer a.yt-simple-endpoint, ' +
                    'a[href*="watch?v="]'
                )).filter(function(el) {
                    return (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });

                if (links.length > 0) {
                    var lIdx = Math.floor(Math.random() * links.length);
                    if (triggerClick(links[lIdx])) return true;
                }

                return false;
            }

            var attempts = 0;
            var timer = setInterval(function() {
                attempts++;
                if (findAndPlayRandom() || attempts > 20) {
                    clearInterval(timer);
                }
            }, 250);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.style = .bar
        progressView.isIndeterminate = false
        progressView.isHidden = true
        
        offlineOverlay.translatesAutoresizingMaskIntoConstraints = false
        offlineOverlay.isHidden = true
        offlineOverlay.onRetry = { [weak self] in
            self?.webView.reload()
        }
        
        addSubview(webView)
        addSubview(offlineOverlay)
        addSubview(progressView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            offlineOverlay.topAnchor.constraint(equalTo: topAnchor),
            offlineOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            offlineOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            offlineOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
    
    private var videoToRestoreOnLaunch = ""
    
    private func setupWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.underPageBackgroundColor = .clear
        
        NowPlayingManager.shared.attach(to: webView)
        
        var targetVideoId = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
        var targetUrlStr: String? = nil
        
        if let savedUrlStr = UserDefaults.standard.string(forKey: "YTM_lastUrl"),
           !savedUrlStr.isEmpty,
           savedUrlStr.contains("music.youtube.com") && savedUrlStr.contains("watch?v=") {
            targetUrlStr = savedUrlStr
            if targetVideoId.isEmpty, let match = savedUrlStr.components(separatedBy: "v=").last?.components(separatedBy: "&").first {
                targetVideoId = match
            }
        } else if !targetVideoId.isEmpty {
            targetUrlStr = "https://music.youtube.com/watch?v=\(targetVideoId)&list=RDAMVM\(targetVideoId)"
        }
        self.videoToRestoreOnLaunch = targetVideoId
        
        if let finalUrlStr = targetUrlStr, let url = URL(string: finalUrlStr) {
            print("[YTMWebView] Restoring last playing session track: \(url.absoluteString)")
            shouldRestoreSavedTime = true
            webView.load(URLRequest(url: url))
        } else if let defaultUrl = URL(string: "https://music.youtube.com/") {
            shouldRestoreSavedTime = false
            UserDefaults.standard.set(0.0, forKey: "YTM_lastTime")
            webView.load(URLRequest(url: defaultUrl))
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        progressView.doubleValue = 0.2
    }
    
    public func selectSongTab() {
        let js = """
        (function() {
            var attempts = 0;
            function ensureSongMode() {
                attempts++;
                try {
                    var toggle = document.querySelector('ytmusic-av-toggle');
                    if (!toggle) return false;
                    var mode = toggle.getAttribute('playback-mode') || '';
                    if (mode === 'OMV_PREFERRED') {
                        var songBtn = toggle.querySelector('button.song-button');
                        if (songBtn) { songBtn.click(); return true; }
                    }
                    return false;
                } catch(e) {
                    return false;
                }
            }
            
            if (!ensureSongMode() || attempts < 4) {
                var timer = setInterval(function() {
                    if (ensureSongMode() || attempts > 5) {
                        clearInterval(timer);
                    }
                }, 200);
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.doubleValue = 1.0
        LikedSongsManager.shared.refreshSignInStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.progressView.isHidden = true
        }
        hideOfflineOverlay()
        
        let currentUrl = webView.url?.absoluteString ?? ""
        if currentUrl.contains("myaccount.google.com") ||
           currentUrl.contains("accounts.google.com/ManageAccount") ||
           (currentUrl.contains("accounts.google.com") && !currentUrl.contains("ServiceLogin") && !currentUrl.contains("signin") && !currentUrl.contains("v3/signin")) {
            print("[YTMWebView] Google auth completed or landed on account page; redirecting to music site")
            loadMusicHome()
            return
        }
        
        selectSongTab()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.selectSongTab()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.selectSongTab()
        }
        
        if autoPlayOnHomeLoad && currentUrl.contains("music.youtube.com") {
            autoPlayOnHomeLoad = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.playRandomTrackOnMusicSite()
            }
        }
        
        if currentUrl.contains("search?q=") {
            let autoPlayJS = """
            (function() {
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
                    if (!clickedTrack) {
                        var topCardBtn = document.querySelector('ytmusic-card-shelf-renderer ytmusic-play-button-renderer #button') ||
                                         document.querySelector('ytmusic-card-shelf-renderer ytmusic-play-button-renderer') ||
                                         document.querySelector('ytmusic-card-shelf-renderer #play-button');
                        if (topCardBtn && triggerClick(topCardBtn)) {
                            clickedTrack = true;
                            ensurePlaying();
                            return true;
                        }

                        var songRows = document.querySelectorAll('ytmusic-responsive-list-item-renderer');
                        for (var i = 0; i < songRows.length; i++) {
                            var row = songRows[i];
                            var btn = row.querySelector('ytmusic-play-button-renderer #button') ||
                                      row.querySelector('ytmusic-play-button-renderer') ||
                                      row.querySelector('.play-button') ||
                                      row.querySelector('#play-button');
                            if (btn && triggerClick(btn)) {
                                clickedTrack = true;
                                ensurePlaying();
                                return true;
                            }
                            var link = row.querySelector('a.yt-simple-endpoint') || row.querySelector('.title a');
                            if (link && triggerClick(link)) {
                                clickedTrack = true;
                                ensurePlaying();
                                return true;
                            }
                        }

                        var anyPlayBtn = document.querySelector('ytmusic-play-button-renderer #button') ||
                                         document.querySelector('ytmusic-play-button-renderer');
                        if (anyPlayBtn && triggerClick(anyPlayBtn)) {
                            clickedTrack = true;
                            ensurePlaying();
                            return true;
                        }
                    } else {
                        ensurePlaying();
                    }

                    return false;
                }

                var attempts = 0;
                var timer = setInterval(function() {
                    attempts++;
                    findAndPlayTopTrack();
                    ensurePlaying();
                    if (attempts > 30) {
                        clearInterval(timer);
                    }
                }, 250);
            })();
            """
            webView.evaluateJavaScript(autoPlayJS, completionHandler: nil)
        }
        
        if !hasRestoredInitialPosition {
            hasRestoredInitialPosition = true
            if shouldRestoreSavedTime {
                shouldRestoreSavedTime = false
                let savedTime = UserDefaults.standard.double(forKey: "YTM_lastTime")
                let vid = videoToRestoreOnLaunch
                webView.evaluateJavaScript(buildRestorePlaybackJS(videoId: vid, targetTime: savedTime, resume: false), completionHandler: nil)
            }
        }
        
        if isRecoveringFromTermination {
            let vid = recoveryVideoId
            let time = recoveryTime
            let resume = recoveryResumePlayback
            isRecoveringFromTermination = false
            recoveryWatchdog?.cancel()
            recoveryWatchdog = nil
            print("[YTMWebView] Recovery: WebView reloaded; re-applying last known track (video=\(vid)) at time \(time)s (resumePlayback=\(resume))")
            NowPlayingManager.shared.markTerminationRecoveryComplete()
            webView.evaluateJavaScript(buildRestorePlaybackJS(videoId: vid, targetTime: time, resume: resume), completionHandler: nil)
            print("[YTMWebView] Recovery complete: player restored to normal working state")
        }
    }
    
    // Reuses the existing launch-time restore mechanism (cue/seek to last known
    // position and enforce playback state). `resume` keeps the original cold-start
    // behavior (pause) while allowing crash recovery to resume an active session.
    private func buildRestorePlaybackJS(videoId: String, targetTime: Double, resume: Bool) -> String {
        let resumeFlag = resume ? "true" : "false"
        return """
        (function() {
            var targetVideoId = "\(videoId)";
            var targetTime = \(targetTime);
            var resumePlayback = \(resumeFlag);
            var attempts = 0;
            function enforceSong() {
                try {
                    var toggle = document.querySelector('ytmusic-av-toggle');
                    if (!toggle) return;
                    var mode = toggle.getAttribute('playback-mode') || '';
                    if (mode === 'OMV_PREFERRED') {
                        var songBtn = toggle.querySelector('button.song-button');
                        if (songBtn) songBtn.click();
                    }
                } catch(e) {}
            }
            var timer = setInterval(function() {
                attempts++;
                try {
                    var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                    if (player) {
                        if (typeof player.cueVideoById === 'function' && targetVideoId) {
                            var currentVid = (typeof player.getVideoData === 'function' && player.getVideoData()) ? player.getVideoData().video_id : '';
                            if (currentVid !== targetVideoId) {
                                player.cueVideoById(targetVideoId, targetTime);
                                if (resumePlayback) { if (typeof player.playVideo === 'function') { player.playVideo(); } }
                                else { if (typeof player.pauseVideo === 'function') { player.pauseVideo(); } }
                                enforceSong();
                                clearInterval(timer);
                                return;
                            }
                        }
                        if (typeof player.seekTo === 'function') {
                            if (targetTime > 2.0) {
                                player.seekTo(targetTime, true);
                            }
                            if (resumePlayback) { if (typeof player.playVideo === 'function') { player.playVideo(); } }
                            else { if (typeof player.pauseVideo === 'function') { player.pauseVideo(); } }
                            enforceSong();
                            clearInterval(timer);
                            return;
                        }
                    }
                    var video = document.querySelector('video');
                    if (video && video.readyState >= 1) {
                        if (targetTime > 2.0) {
                            video.currentTime = targetTime;
                        }
                        if (resumePlayback) { if (video.paused) video.play(); }
                        else { video.pause(); }
                        enforceSong();
                        clearInterval(timer);
                    }
                } catch(e) {}
                
                if (attempts > 20) {
                    clearInterval(timer);
                }
            }, 250);
        })();
        """
    }
    
    // MARK: - WebContent process crash recovery
    
    // Called by WebKit when the WebContent process dies (e.g. kill -9 / OOM).
    // Recreates the WebView content, reuses the existing session/restoration
    // mechanisms (WKWebsiteDataStore.default() cookies + UserDefaults) and
    // re-applies the last known track/position so playback can continue.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("[YTMWebView] ⚠️ WebContent process terminated - starting crash recovery")
        
        guard !isRecoveringFromTermination else {
            print("[YTMWebView] Recovery already in flight; ignoring duplicate termination callback")
            return
        }
        isRecoveringFromTermination = true
        
        // Snapshot the last known playback state using existing restoration defaults.
        recoveryVideoId = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
        recoveryTime = UserDefaults.standard.double(forKey: "YTM_lastTime")
        recoveryResumePlayback = NowPlayingManager.shared.currentState.isPlaying
        print("[YTMWebView] Recovery snapshot: video=\(recoveryVideoId) time=\(recoveryTime)s wasPlaying=\(recoveryResumePlayback)")
        
        // Drop stale callbacks from the dying process and re-wire the message
        // bridge so only the freshly restored WebContent can drive player state.
        NowPlayingManager.shared.handleWebContentTermination()
        
        // Restore the WebView: prefer the last saved watch page (authenticated
        // session survives because cookies live in WKWebsiteDataStore.default()),
        // falling back to the currently committed page, then the YTM root.
        var targetUrlStr = UserDefaults.standard.string(forKey: "YTM_lastUrl") ?? ""

        if !recoveryVideoId.isEmpty {
            targetUrlStr =
                "https://music.youtube.com/watch?v=\(recoveryVideoId)&t=\(max(0, Int(recoveryTime)))"
        } else if !targetUrlStr.contains("music.youtube.com") {
            targetUrlStr =
                webView.url?.absoluteString ??
                "https://music.youtube.com/"
        }
        hideOfflineOverlay()
        
        if let url = URL(string: targetUrlStr) {
            print("[YTMWebView] WebView restoration: reloading \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        } else {
            print("[YTMWebView] WebView restoration: reloading current page")
            webView.reload()
        }
        
        startRecoveryWatchdog()
    }
    
    // If the restored page never finishes loading (e.g. offline), release the
    // recovery state so the app resumes normal handling of player updates.
    private func startRecoveryWatchdog() {
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.isRecoveringFromTermination else { return }
            print("[YTMWebView] ⚠️ WebContent recovery did not complete within watchdog window (page may be offline)")
            self.isRecoveringFromTermination = false
            self.recoveryWatchdog = nil
            NowPlayingManager.shared.markTerminationRecoveryComplete()
        }
        recoveryWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 45.0, execute: watchdog)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        handleNavigationFailure(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        handleNavigationFailure(error)
    }
    
    private func handleNavigationFailure(_ error: Error) {
        let nsError = error as NSError
        print("[YTMWebView] Navigation failed: \(error.localizedDescription) (code: \(nsError.code))")
        
        if isRecoveringFromTermination {
            print("[YTMWebView] ⚠️ WebContent recovery failed during navigation: \(error.localizedDescription)")
        }
        
        if nsError.code == NSURLErrorCancelled { return }
        
        if !NetworkMonitor.shared.isReachable ||
           (nsError.domain == NSURLErrorDomain && [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorDataNotAllowed
           ].contains(nsError.code)) {
            showOfflineOverlay()
        }
    }
    
    private func showOfflineOverlay() {
        offlineOverlay.updateNetworkState(isReachable: NetworkMonitor.shared.isReachable)
        offlineOverlay.isHidden = false
    }
    
    private func hideOfflineOverlay() {
        offlineOverlay.isHidden = true
    }
    
    // MARK: - Player-page parking
    // Keeps the WebView parked on a lean watch page while in player mode so the
    // heavy home/search browse DOM isn't held in the WebContent process.
    public func parkOnPlayerPage() {
        if let currentURL = webView.url?.absoluteString, currentURL.contains("watch?v=") {
            return
        }
        var watchUrlStr = UserDefaults.standard.string(forKey: "YTM_lastUrl") ?? ""
        if watchUrlStr.isEmpty, let videoId = UserDefaults.standard.string(forKey: "YTM_lastVideoId"), !videoId.isEmpty {
            watchUrlStr = "https://music.youtube.com/watch?v=\(videoId)"
        }
        if !watchUrlStr.isEmpty, watchUrlStr.contains("watch?v="),
           let url = URL(string: watchUrlStr) {
            if webView.url == url { return }
            print("[YTMWebView] Parking player on watch page: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
            return
        }
        if let currentURL = webView.url?.absoluteString, !currentURL.contains("music.youtube.com") {
            loadMusicHome()
        }
    }

    public func loadGoogleLogin() {
        NowPlayingManager.shared.flushSessionState(keepCookies: true)
        let urlString = "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F"
        guard let url = URL(string: urlString) else { return }
        webView.customUserAgent = YTMWebViewContainer.userAgent
        var request = URLRequest(url: url)
        request.setValue(YTMWebViewContainer.userAgent, forHTTPHeaderField: "User-Agent")
        webView.load(request)
    }

    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // MARK: - WKUIDelegate & Navigation Policy for Single-Window Google Auth
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }
        
        if let url = navigationAction.request.url {
            let urlString = url.absoluteString
            if urlString.contains("myaccount.google.com") || urlString.contains("accounts.google.com/ManageAccount") {
                decisionHandler(.cancel)
                loadMusicHome()
                return
            }
        }
        
        decisionHandler(.allow)
    }
}
