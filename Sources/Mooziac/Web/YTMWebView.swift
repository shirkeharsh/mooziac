import Foundation
import WebKit
import AppKit

// MARK: - WebPlaybackAudioOutput
/// Keeps WebKit's audio output open across short music playback transitions.
/// When macOS detects that audio playback has paused and the window is occluded/hidden,
/// WebKit revokes the foreground assertion and freezes/suspends the WebContent process (App Nap).
/// This silent 0-gain AudioContext node guarantees WebKit continuously reports active audible media
/// during the 100-300ms gap when songs advance or switch.
enum WebPlaybackAudioOutput {
    static let script = """
    (() => {
        if (window.__mooziacAudioOutput) return;
        let output = null;
        let releaseTimer = null;

        function clearReleaseTimer() {
            if (releaseTimer !== null) clearTimeout(releaseTimer);
            releaseTimer = null;
        }

        function stop() {
            clearReleaseTimer();
            const previous = output;
            output = null;
            if (!previous) return;
            try { previous.source.stop(); } catch (_) {}
            try { previous.source.disconnect(); } catch (_) {}
            try { previous.gain.disconnect(); } catch (_) {}
            try { previous.context.close().catch(() => {}); } catch (_) {}
        }

        function start() {
            const video = document.querySelector('video');
            if (window.__mooziacPlaybackSuppressed || window.__mooziacBlockAutoplay
                || (video && video.webkitCurrentPlaybackTargetIsWireless)) {
                stop();
                return;
            }
            clearReleaseTimer();
            try {
                if (!output) {
                    const context = new AudioContext();
                    output = { context, source: null, gain: null };
                    const source = context.createOscillator();
                    output.source = source;
                    const gain = context.createGain();
                    output.gain = gain;
                    // No media is routed through this graph. Zero gain keeps the
                    // output active without altering DRM playback or its volume.
                    gain.gain.value = 0;
                    source.connect(gain);
                    gain.connect(context.destination);
                    source.start();
                }
                const pending = output;
                pending.context.resume().catch(() => {
                    if (output === pending) stop();
                });
            } catch (_) {
                stop();
            }
        }

        function releaseAfterTransition() {
            if (!output || releaseTimer !== null) return;
            // A failed load or the end of the queue must not leave silent output
            // running indefinitely. Normal transitions finish well within this.
            releaseTimer = setTimeout(stop, 5000);
        }

        function prepare() {
            start();
            releaseAfterTransition();
        }

        function observe(event, handler) {
            document.addEventListener(event, event => {
                const video = event.target;
                if (video && video.tagName === 'VIDEO'
                    && video === document.querySelector('video')) handler(video);
            }, true);
        }

        observe('play', prepare);
        observe('playing', start);
        observe('loadstart', () => {
            if (window.__mooziacAutoplayPending) prepare();
        });
        observe('pause', video => {
            if (!window.__mooziacPlaybackSuppressed && !window.__mooziacBlockAutoplay
                && (video.ended || window.__mooziacAutoplayPending)) {
                releaseAfterTransition();
            } else {
                stop();
            }
        });
        observe('ended', releaseAfterTransition);
        observe('emptied', releaseAfterTransition);
        observe('error', stop);
        observe('webkitcurrentplaybacktargetiswirelesschanged', video => {
            if (video.webkitCurrentPlaybackTargetIsWireless) stop();
            else if (!video.paused) start();
        });
        let currentVideo = document.querySelector('video');
        const mediaObserver = new MutationObserver(() => {
            const video = document.querySelector('video');
            if (video === currentVideo) return;
            currentVideo = video;
            if (video && !video.paused && !video.ended && video.readyState >= 3) start();
            else releaseAfterTransition();
        });
        const targetNode = document.querySelector('ytmusic-player') || document.getElementById('player') || document.body;
        if (targetNode) {
            mediaObserver.observe(targetNode, { childList: true });
        }
        window.addEventListener('pagehide', () => {
            mediaObserver.disconnect();
            stop();
        });
        window.__mooziacAudioOutput = { prepare, stop };
        if (window.__mooziacAutoplayPending) prepare();
    })();
    """

    static let stopScript = "window.__mooziacAudioOutput?.stop();"
    static let prepareScript = "window.__mooziacAudioOutput?.prepare();"
}

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
        
        if #available(macOS 14.0, *) {
            config.preferences.inactiveSchedulingPolicy = .throttle
        }
        config.preferences.setValue(false, forKey: "developerExtrasEnabled")
        
        // YouTube Ad Shield Bootstrap Script (atDocumentStart, mainFrameOnly):
        // Uses a Function.prototype.toString mask to remain undetected by YouTube's anti-adblock,
        // and prunes ad placements in-place from ytInitialPlayerResponse, Response.prototype.json,
        // and JSON.parse across SPA track transitions.
        let adShieldScript = WKUserScript(
            source: """
            (function() {
                'use strict';
                try {
                    var _toString = Function.prototype.toString;
                    var _masks = new WeakMap();
                    function mask(hooked, original) { try { _masks.set(hooked, original); } catch(e) {} return hooked; }
                    var patchedToString = function toString() {
                        var orig = _masks.get(this);
                        return _toString.call(orig !== undefined ? orig : this);
                    };
                    mask(patchedToString, _toString);
                    try {
                        Object.defineProperty(Function.prototype, 'toString', {
                            value: patchedToString, writable: true, configurable: true
                        });
                    } catch(e) { Function.prototype.toString = patchedToString; }

                    var AD_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams', 'adPlacementConfig'];
                    function pruneObject(o) {
                        if (!o || typeof o !== 'object') return o;
                        if (Array.isArray(o)) {
                            if (o.length <= 10) {
                                for (var j = 0; j < o.length; j++) {
                                    if (o[j] && typeof o[j] === 'object' && o[j].playerResponse) {
                                        pruneObject(o[j].playerResponse);
                                    }
                                }
                            }
                            return o;
                        }
                        for (var i = 0; i < AD_KEYS.length; i++) {
                            if (AD_KEYS[i] in o) { try { delete o[AD_KEYS[i]]; } catch(e) { o[AD_KEYS[i]] = undefined; } }
                        }
                        if (o.playerResponse && typeof o.playerResponse === 'object') { pruneObject(o.playerResponse); }
                        return o;
                    }

                    var _ipr;
                    try {
                        Object.defineProperty(window, 'ytInitialPlayerResponse', {
                            get: function() { return _ipr; },
                            set: function(v) { _ipr = pruneObject(v); },
                            configurable: true
                        });
                    } catch(e) {}

                    if (window.Response && Response.prototype && Response.prototype.json) {
                        var _origJson = Response.prototype.json;
                        var patchedJson = function json() {
                            return _origJson.apply(this, arguments).then(function(data) {
                                return pruneObject(data);
                            });
                        };
                        mask(patchedJson, _origJson);
                        try {
                            Object.defineProperty(Response.prototype, 'json', {
                                value: patchedJson, writable: true, configurable: true
                            });
                        } catch(e) { Response.prototype.json = patchedJson; }
                    }

                    if (typeof JSON !== 'undefined' && JSON.parse) {
                        var _origParse = JSON.parse;
                        var patchedParse = function parse(text, reviver) {
                            var res = _origParse.apply(this, arguments);
                            if (res && typeof res === 'object') {
                                pruneObject(res);
                            }
                            return res;
                        };
                        mask(patchedParse, _origParse);
                        try {
                            Object.defineProperty(JSON, 'parse', {
                                value: patchedParse, writable: true, configurable: true
                            });
                        } catch(e) { JSON.parse = patchedParse; }
                    }
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(adShieldScript)

        // Page Visibility Shield: Prevents YouTube Music from pausing when the menu bar window is dismissed
        let pageVisibilityShieldScript = WKUserScript(
            source: """
            (function() {
                try {
                    if (window.location && window.location.hostname.indexOf('music.youtube.com') !== -1) {
                        // Override standard Page Visibility API properties to always report visible
                        Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: true });
                        Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
                        Object.defineProperty(document, 'webkitHidden', { get: function() { return false; }, configurable: true });
                        Object.defineProperty(document, 'webkitVisibilityState', { get: function() { return 'visible'; }, configurable: true });
                        
                        // Prevent visibilitychange and blur events from triggering player pause handlers
                        var blockEvent = function(e) {
                            e.stopImmediatePropagation();
                            e.stopPropagation();
                        };
                        window.addEventListener('visibilitychange', blockEvent, true);
                        document.addEventListener('visibilitychange', blockEvent, true);
                        window.addEventListener('webkitvisibilitychange', blockEvent, true);
                        document.addEventListener('webkitvisibilitychange', blockEvent, true);
                    }
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(pageVisibilityShieldScript)
        
        // Pre-boot High Audio Quality Bootstrap Script (atDocumentStart, mainFrameOnly for OAuth safety)
        let audioBootstrapScript = WKUserScript(
            source: """
            (function() {
                try {
                    if (window.location && window.location.hostname.indexOf('music.youtube.com') !== -1) {
                        localStorage.setItem('mooziacPlaybackAudioQuality', 'high');
                        localStorage.setItem('ytmusic_audio_quality', 'AUDIO_QUALITY_HIGH');
                        window.__mooziacAudioQuality = 'AUDIO_QUALITY_HIGH';
                    }
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(audioBootstrapScript)

        // MediaSession Remote Command Shield: Prevents web scripts from stealing native macOS media keys
        let mediaSessionShieldScript = WKUserScript(
            source: """
            (function() {
                try {
                    var ms = navigator.mediaSession;
                    if (ms && !ms.__mooziacWrapped) {
                        var orig = ms.setActionHandler.bind(ms);
                        ms.setActionHandler = function(type, handler) {
                            if (type === 'seekforward' || type === 'seekbackward') {
                                return orig(type, null);
                            }
                            return orig(type, handler);
                        };
                        ms.__mooziacWrapped = true;
                    }
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(mediaSessionShieldScript)

        // WebPlaybackAudioOutput: Keeps WebKit audio graph active across short track transitions
        let audioOutputScript = WKUserScript(
            source: WebPlaybackAudioOutput.script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(audioOutputScript)

        // Stealth sizing: Positioned offscreen at -9999px with standard 640x360 dimensions so YouTube
        // never triggers adaptive bitrate emergency downgrades or buffer throttling.
        let cssString = """
        #song-video, #player-video, .html5-video-player, video {
            position: fixed !important;
            left: -9999px !important;
            top: -9999px !important;
            width: 640px !important;
            height: 360px !important;
            opacity: 0.0001 !important;
            pointer-events: none !important;
            visibility: visible !important;
            z-index: -999 !important;
        }
        #cinematics, .background-gradient, #background-gradient,
        paper-ripple, #cinematics-container, ytm-cinematics, .ytmusic-browse-response[background-gradient],
        .ytp-ce-element, .ytp-cards-teaser, .ytp-chrome-top, .ytp-gradient-top,
        .ytp-gradient-bottom, .annotation, .ytp-pause-overlay,
        ytmusic-mealbar-promo-renderer, ytmusic-player-bar-promo-renderer,
        ytmusic-banner-promo-renderer, #player-ads {
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
        do {
            let data = try JSONEncoder().encode(cssString)
            cssJSON = String(data: data, encoding: .utf8) ?? "\"\""
        } catch {
            Log.web.error("Failed to encode custom CSS string: \(error.localizedDescription)")
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
            { "trigger": { "url-filter": ".*google-analytics\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*doubleclick\\\\.net.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googletagmanager\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googleadservices\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googlesyndication\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*googletagservices\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*mobileads\\\\.google\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*adsafeprotected\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*scorecardresearch\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*quantserve\\\\.com.*", "unless-domain": ["*accounts.google.com", "*myaccount.google.com"] }, "action": { "type": "block" } }
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
            Log.web.info("Reconnected to network, auto-reloading webview")
            self.hideOfflineOverlay()
            self.reloadPlayerEngine()
        }
    }
    
    deinit {
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
    }
    
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        LikedSongsManager.shared.refreshSignInStatus()
    }
    
    public func loadMusicHome(autoPlayRandom: Bool = false) {
        self.autoPlayOnHomeLoad = autoPlayRandom
        if let defaultUrl = URL(string: "https://music.youtube.com/") {
            Log.web.info("Navigating to music site: \(defaultUrl.absoluteString)")
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
            Log.web.info("Restoring last playing session track: \(url.absoluteString)")
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
            try {
                // Dismiss any promo / upsell dialogs that pause playback
                var dismissBtns = document.querySelectorAll(
                    'ytmusic-mealbar-promo-renderer #dismiss-button button, ' +
                    'ytmusic-dialog #dismiss-button button, ' +
                    'ytmusic-you-there-renderer #button, ' +
                    'tp-yt-paper-dialog #dismiss-button'
                );
                for (var i = 0; i < dismissBtns.length; i++) {
                    if (dismissBtns[i]) dismissBtns[i].click();
                }
            } catch(e) {}
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
            Log.web.info("Google auth completed or landed on account page; redirecting to music site")
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
            webView.evaluateJavaScript(MainViewController.safeSearchAutoPlayJS, completionHandler: nil)
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
            Log.web.info("Recovery: WebView reloaded; re-applying last known track (video=\(vid)) at time \(time)s (resumePlayback=\(resume))")
            NowPlayingManager.shared.markTerminationRecoveryComplete()
            webView.evaluateJavaScript(buildRestorePlaybackJS(videoId: vid, targetTime: time, resume: resume), completionHandler: nil)
            Log.web.info("Recovery complete: player restored to normal working state")
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
            if (resumePlayback) {
                window.__mooziacAutoplayPending = true;
                window.__mooziacPlaybackSuppressed = false;
                window.__mooziacBlockAutoplay = false;
                if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                    window.__mooziacAudioOutput.prepare();
                }
            } else {
                window.__mooziacAutoplayPending = false;
                window.__mooziacPlaybackSuppressed = true;
                window.__mooziacBlockAutoplay = true;
                if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.stop === 'function') {
                    window.__mooziacAudioOutput.stop();
                }
            }
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
        Log.web.error("WebContent process terminated - starting crash recovery")
        
        guard !isRecoveringFromTermination else {
            Log.web.debug("Recovery already in flight; ignoring duplicate termination callback")
            return
        }
        isRecoveringFromTermination = true
        
        // Snapshot the last known playback state using existing restoration defaults.
        recoveryVideoId = UserDefaults.standard.string(forKey: "YTM_lastVideoId") ?? ""
        recoveryTime = UserDefaults.standard.double(forKey: "YTM_lastTime")
        recoveryResumePlayback = NowPlayingManager.shared.currentState.isPlaying
        Log.web.debug("Recovery snapshot: video=\(self.recoveryVideoId) time=\(self.recoveryTime)s wasPlaying=\(self.recoveryResumePlayback)")
        
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
            Log.web.debug("WebView restoration: reloading \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        } else {
            Log.web.debug("WebView restoration: reloading current page")
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
            Log.web.error("WebContent recovery did not complete within watchdog window")
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
        Log.web.error("Navigation failed: \(error.localizedDescription) (code: \(nsError.code))")
        
        if isRecoveringFromTermination {
            Log.web.error("WebContent recovery failed during navigation: \(error.localizedDescription)")
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
            Log.web.debug("Parking player on watch page: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
            return
        }
        if let currentURL = webView.url?.absoluteString, !currentURL.contains("music.youtube.com") {
            loadMusicHome()
        }
    }

    // MARK: - Instant Router Navigation (app.resolveCommand) with Watchdog & Generation Counter
    private var navigationGeneration: UInt64 = 0
    private var routerWatchdogItem: DispatchWorkItem?

    public func navigateToVideo(videoId: String) {
        guard !videoId.isEmpty else { return }
        navigationGeneration &+= 1
        let currentGeneration = navigationGeneration
        
        routerWatchdogItem?.cancel()
        routerWatchdogItem = nil

        let escapedVideoId = videoId.replacingOccurrences(of: "'", with: "\\'")
        let routerJS = """
        (function() {
            var videoId = '\(escapedVideoId)';
            var gen = \(currentGeneration);
            window.__mooziacNavigationGeneration = gen;
            window.__mooziacAutoplayPending = true;
            window.__mooziacPlaybackSuppressed = false;
            window.__mooziacBlockAutoplay = false;
            window.__mooziacAutoplayAttempts = 0;
            if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                window.__mooziacAudioOutput.prepare();
            }

            // Priority 1: YouTube Music native Polymer router (Instant 0ms track switch, zero page reload)
            try {
                var app = document.querySelector('ytmusic-app');
                if (app && typeof app.resolveCommand === 'function') {
                    app.resolveCommand({ watchEndpoint: { videoId: videoId } });
                    setTimeout(function() {
                        try {
                            var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                            if (p && typeof p.playVideo === 'function') p.playVideo();
                            var v = document.querySelector('video');
                            if (v && v.paused) v.play().catch(function(){});
                        } catch(e) {}
                    }, 100);
                    return { success: true, method: 'resolveCommand' };
                }
            } catch(e) {}

            // Priority 2: HTML5 Player API loadVideoById
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.loadVideoById === 'function') {
                    p.loadVideoById(videoId);
                    if (typeof p.playVideo === 'function') p.playVideo();
                    return { success: true, method: 'loadVideoById' };
                }
            } catch(e) {}

            return { success: false, method: 'none' };
        })();
        """

        webView.evaluateJavaScript(routerJS) { [weak self] result, error in
            guard let self = self else { return }
            guard self.navigationGeneration == currentGeneration else { return }

            let dict = result as? [String: Any]
            let success = (dict?["success"] as? Bool) == true

            if !success {
                // If in-page routing was not available, immediately fall back
                self.fallbackLoadVideo(videoId: videoId, generation: currentGeneration)
                return
            }

            // In-page routing was dispatched. Arm 1800ms watchdog to verify that the track actually loaded:
            let watchdog = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard self.navigationGeneration == currentGeneration else { return }
                self.verifyVideoSwitch(videoId: videoId, generation: currentGeneration)
            }
            self.routerWatchdogItem = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: watchdog)
        }
    }

    private func verifyVideoSwitch(videoId: String, generation: UInt64) {
        guard navigationGeneration == generation else { return }
        let checkJS = """
        (function() {
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.getVideoData === 'function') {
                    var data = p.getVideoData();
                    if (data && (data.video_id === '\(videoId)' || data.videoId === '\(videoId)')) {
                        return true;
                    }
                }
                var m = window.location.href.match(/[?&]v=([^&]+)/);
                if (m && m[1] === '\(videoId)') {
                    return true;
                }
            } catch(e) {}
            return false;
        })();
        """
        webView.evaluateJavaScript(checkJS) { [weak self] result, _ in
            guard let self = self else { return }
            guard self.navigationGeneration == generation else { return }
            if (result as? Bool) != true {
                Log.web.error("Router navigation watchdog expired for \(videoId). Executing safe URL fallback")
                self.fallbackLoadVideo(videoId: videoId, generation: generation)
            } else {
                let playJS = """
                (function() {
                    try {
                        var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                        if (p && typeof p.getPlayerState === 'function') {
                            var st = p.getPlayerState();
                            if (st === 2 || st === 5 || st === -1) {
                                if (typeof p.playVideo === 'function') p.playVideo();
                            }
                        }
                        var v = document.querySelector('video');
                        if (v && v.paused) v.play().catch(function(){});
                    } catch(e) {}
                })();
                """
                self.webView.evaluateJavaScript(playJS, completionHandler: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.selectSongTab()
                }
            }
        }
    }

    private func fallbackLoadVideo(videoId: String, generation: UInt64) {
        guard navigationGeneration == generation else { return }
        let targetUrlStr = "https://music.youtube.com/watch?v=\(videoId)&list=RDAMVM\(videoId)"
        guard let url = URL(string: targetUrlStr) else { return }
        
        let replaceJS = "window.location.replace('\(targetUrlStr)');"
        webView.evaluateJavaScript(replaceJS) { [weak self] _, error in
            guard let self = self else { return }
            guard self.navigationGeneration == generation else { return }
            if error != nil {
                self.webView.load(URLRequest(url: url))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.selectSongTab()
            }
        }
    }

    // MARK: - Infinite Flow (Never-Ending Autoplay)
    public func triggerInfiniteFlow(seededFrom videoId: String = "") {
        navigationGeneration &+= 1
        let currentGeneration = navigationGeneration

        routerWatchdogItem?.cancel()
        routerWatchdogItem = nil

        let escapedVideoId = videoId.replacingOccurrences(of: "'", with: "\\'")
        let infiniteFlowJS = """
        (function() {
            var seedVid = '\(escapedVideoId)';
            var gen = \(currentGeneration);
            window.__mooziacNavigationGeneration = gen;
            window.__mooziacAutoplayPending = true;
            window.__mooziacPlaybackSuppressed = false;
            window.__mooziacBlockAutoplay = false;
            window.__mooziacAutoplayAttempts = 0;
            if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                window.__mooziacAudioOutput.prepare();
            }

            // Priority 1: If player bar Next button is active and has queued items, click it for 0ms transition
            try {
                var nextBtn = document.querySelector('ytmusic-player-bar .next-button') ||
                              document.querySelector('.next-button') ||
                              document.querySelector('tp-yt-paper-icon-button.next-button');
                if (nextBtn && !nextBtn.hasAttribute('disabled') && nextBtn.getAttribute('aria-disabled') !== 'true') {
                    nextBtn.click();
                    return { success: true, method: 'nextButton' };
                }
            } catch(e) {}

            // Priority 2: HTML5 player nextVideo()
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.nextVideo === 'function') {
                    p.nextVideo();
                    return { success: true, method: 'playerNext' };
                }
            } catch(e) {}

            // Fallback seed extraction from player data or current URL if not provided
            if (!seedVid) {
                try {
                    var pl = document.querySelector('#movie_player') || document.querySelector('ytmusic-player')?.playerApi;
                    if (pl && typeof pl.getVideoData === 'function') {
                        var vd = pl.getVideoData();
                        if (vd && vd.video_id) seedVid = vd.video_id;
                    }
                } catch(e) {}
                if (!seedVid) {
                    try {
                        var m = window.location.href.match(/[?&]v=([^&]+)/);
                        if (m && m[1]) seedVid = m[1];
                    } catch(e) {}
                }
            }

            // Priority 3: Dispatch native radio resolveCommand seeded from the last track
            try {
                var app = document.querySelector('ytmusic-app');
                if (app && typeof app.resolveCommand === 'function' && seedVid) {
                    app.resolveCommand({
                        watchEndpoint: {
                            videoId: seedVid,
                            playlistId: 'RDAMVM' + seedVid,
                            params: 'wAEB'
                        }
                    });
                    setTimeout(function() {
                        try {
                            var pl = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                            if (pl && typeof pl.nextVideo === 'function') {
                                pl.nextVideo();
                            }
                            if (pl && typeof pl.playVideo === 'function') {
                                pl.playVideo();
                            }
                        } catch(err) {}
                    }, 250);
                    return { success: true, method: 'resolveRadio' };
                }
            } catch(e) {}

            // Priority 4: Direct URL replacement with radio list
            if (seedVid) {
                window.location.replace('https://music.youtube.com/watch?v=' + encodeURIComponent(seedVid) + '&list=RDAMVM' + encodeURIComponent(seedVid));
                return { success: true, method: 'urlRadio' };
            }

            return { success: false, method: 'none' };
        })();
        """

        webView.evaluateJavaScript(infiniteFlowJS) { [weak self] result, error in
            guard let self = self else { return }
            guard self.navigationGeneration == currentGeneration else { return }
            let dict = result as? [String: Any]
            let method = dict?["method"] as? String ?? "unknown"
            Log.web.debug("Infinite Flow dispatched with method: \(method)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.selectSongTab()
            }
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

    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

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
            if urlString.contains("accounts.google.com/ManageAccount") {
                decisionHandler(.cancel)
                loadMusicHome()
                return
            }
        }
        
        decisionHandler(.allow)
    }
}
