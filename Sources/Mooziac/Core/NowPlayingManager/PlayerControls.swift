import AppKit
import WebKit
import MediaPlayer

// Loads artwork for the system media player from a remote URL, caching the
// result keyed by the track's videoId (stable) so rotating YTM thumbnail
// URLs reuse the same image, and refusing to apply a stale load once the
// track has changed.
private final class NowPlayingArtworkLoader {
    static let shared = NowPlayingArtworkLoader()

    private var inFlight = Set<String>()
    private var currentKey = ""

    func applyArtwork(urlString: String, videoId: String) {
        let key = videoId.isEmpty ? urlString : videoId
        currentKey = key
        if let img = AppArtworkHelper.shared.getMemoryCachedImage(forKey: key) {
            apply(img, key: key)
            return
        }
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil, let img = NSImage(data: data) else {
                self?.inFlight.remove(key)
                return
            }
            DispatchQueue.main.async {
                AppArtworkHelper.shared.setMemoryCachedImage(img, forKey: key)
                self.inFlight.remove(key)
                self.apply(img, key: key)
            }
        }.resume()
    }

    func cancelCurrent() {
        currentKey = ""
    }

    private func apply(_ img: NSImage, key: String) {
        guard currentKey == key else { return }
        let center = MPNowPlayingInfoCenter.default()
        var info = center.nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        center.nowPlayingInfo = info
    }
}

extension NowPlayingManager {
    func updateSystemNowPlayingInfo(_ state: PlaybackState) {
        // When online, WebKit natively manages the single Now Playing session in Control Center.
        // We only use MPNowPlayingInfoCenter for local offline audio playback.
        guard engineMode == .offline else {
            if MPNowPlayingInfoCenter.default().nowPlayingInfo != nil {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
            return
        }

        let center = MPNowPlayingInfoCenter.default()
        var info = center.nowPlayingInfo ?? [:]

        if !state.title.isEmpty { info[MPMediaItemPropertyTitle] = state.title }
        if !state.artist.isEmpty { info[MPMediaItemPropertyArtist] = state.artist }
        if !state.album.isEmpty { info[MPMediaItemPropertyAlbumTitle] = state.album }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.currentTime
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? 1.0 : 0.0

        let trackKey = state.videoId.isEmpty ? state.artworkUrl : state.videoId
        if lastNowPlayingTrackKey != trackKey {
            info.removeValue(forKey: MPMediaItemPropertyArtwork)
            lastNowPlayingTrackKey = trackKey
        }

        center.nowPlayingInfo = info
        center.playbackState = state.isPlaying ? .playing : .paused
    }
    
    // Playback Controls Injection using native #movie_player API or NativeAudioPlayer
    func togglePlayPause() {
        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            if engineMode != .offline {
                engineMode = .offline
            }
            if NativeAudioPlayer.shared.currentTrack == nil {
                NativeAudioPlayer.shared.playLastOrFirstTrack()
                return
            }
            NativeAudioPlayer.shared.togglePlayPause()
            return
        }

        // If network is offline and online player is idle with no track loaded, smoothly play offline library
        if !NetworkMonitor.shared.isReachable && (currentState.title.isEmpty || currentState.title == "Not Playing") && !currentState.isPlaying {
            if !LocalLibraryManager.shared.allTracks.isEmpty {
                engineMode = .offline
                NativeAudioPlayer.shared.playLastOrFirstTrack()
                return
            }
        }

        NativeAudioPlayer.shared.pause()

        if let mainVC = StatusItemManager.shared?.mainViewController {
            let currentUrl = mainVC.webViewContainer.webView.url?.absoluteString ?? ""
            if !currentUrl.contains("music.youtube.com") {
                mainVC.webViewContainer.loadMusicHome(autoPlayRandom: true)
                return
            }
        }

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

            function playRandomFromPage() {
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

            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.getPlayerState === 'function') {
                    var state = player.getPlayerState();
                    if (state === 1) {
                        player.pauseVideo();
                        return;
                    } else if (state === 2 || state === 3 || state === 5) {
                        player.playVideo();
                        return;
                    }
                }
            } catch(e) {}

            var video = document.querySelector('video');
            if (video && video.readyState >= 2 && !isNaN(video.duration) && video.duration > 0) {
                if (video.paused) {
                    video.play().catch(function(){});
                } else {
                    video.pause();
                }
                return;
            }

            var playBtn = document.querySelector('ytmusic-player-bar #play-pause-button') ||
                          document.querySelector('#play-pause-button') ||
                          document.querySelector('.play-pause-button');
            if (playBtn && !playBtn.hasAttribute('disabled') && playBtn.getAttribute('aria-disabled') !== 'true') {
                var titleElem = document.querySelector('ytmusic-player-bar .title') || document.querySelector('.ytmusic-player-bar.title');
                var hasTrack = titleElem && titleElem.textContent && titleElem.textContent.trim().length > 0;
                if (hasTrack) {
                    triggerClick(playBtn);
                    return;
                }
            }

            if (!playRandomFromPage()) {
                var attempts = 0;
                var timer = setInterval(function() {
                    attempts++;
                    if (playRandomFromPage() || attempts > 15) {
                        clearInterval(timer);
                    }
                }, 200);
            }
        })();
        """
        evaluateJS(js)
    }
    
    func pause() {
        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            NativeAudioPlayer.shared.pause()
            return
        }
        let js = """
        (function() {
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.pauseVideo === 'function') {
                    player.pauseVideo();
                    return;
                }
            } catch(e) {}
            var video = document.querySelector('video');
            if (video && !video.paused) {
                video.pause();
            }
        })();
        """
        evaluateJS(js)
    }
    
    func play() {
        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            if engineMode != .offline {
                engineMode = .offline
            }
            if NativeAudioPlayer.shared.currentTrack == nil {
                NativeAudioPlayer.shared.playLastOrFirstTrack()
                return
            }
            NativeAudioPlayer.shared.play()
            return
        }

        NativeAudioPlayer.shared.pause()

        if let mainVC = StatusItemManager.shared?.mainViewController {
            let currentUrl = mainVC.webViewContainer.webView.url?.absoluteString ?? ""
            if !currentUrl.contains("music.youtube.com") {
                mainVC.webViewContainer.loadMusicHome(autoPlayRandom: true)
                return
            }
        }

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

            function playRandomFromPage() {
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

            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.getPlayerState === 'function') {
                    var state = player.getPlayerState();
                    if (state === 2 || state === 3 || state === 5) {
                        player.playVideo();
                        return;
                    } else if (state === 1) {
                        return;
                    }
                }
            } catch(e) {}

            var video = document.querySelector('video');
            if (video && video.readyState >= 2 && !isNaN(video.duration) && video.duration > 0 && video.paused) {
                video.play().catch(function(){});
                return;
            }

            if (!playRandomFromPage()) {
                var attempts = 0;
                var timer = setInterval(function() {
                    attempts++;
                    if (playRandomFromPage() || attempts > 15) {
                        clearInterval(timer);
                    }
                }, 200);
            }
        })();
        """
        evaluateJS(js)
    }
    
    func nextTrack() {
        if PlaylistManager.shared.hasActiveContext {
            if PlaylistManager.shared.playNextTrackInPlaylist() {
                return
            }
        }

        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            if engineMode != .offline {
                engineMode = .offline
            }
            if NativeAudioPlayer.shared.currentTrack == nil {
                NativeAudioPlayer.shared.playLastOrFirstTrack()
                return
            }
            NativeAudioPlayer.shared.nextTrack()
            return
        }
        let js = """
        (function() {
            function simulateClick(el) {
                if (!el) return false;
                var targets = [
                    el.querySelector('button'),
                    el.querySelector('tp-yt-paper-icon-button'),
                    el.querySelector('paper-icon-button'),
                    el.querySelector('ytmusic-play-button-renderer'),
                    el.querySelector('#play-button'),
                    el.querySelector('.play-button'),
                    el
                ];
                for (var i = 0; i < targets.length; i++) {
                    var t = targets[i];
                    if (t) {
                        try {
                            var opts = { bubbles: true, cancelable: true, view: window };
                            t.dispatchEvent(new MouseEvent('mousedown', opts));
                            t.dispatchEvent(new MouseEvent('mouseup', opts));
                            t.dispatchEvent(new MouseEvent('click', opts));
                            if (typeof t.click === 'function') t.click();
                            return true;
                        } catch(e) {}
                    }
                }
                return false;
            }

            // Priority 1: Click YouTube Music's official player bar Next button
            try {
                var nextBtn = document.querySelector('ytmusic-player-bar .next-button') ||
                              document.querySelector('.next-button') ||
                              document.querySelector('#next-button') ||
                              document.querySelector('tp-yt-paper-icon-button.next-button') ||
                              document.querySelector('button[aria-label*="Next"]') ||
                              document.querySelector('[title*="Next"]');
                if (nextBtn && simulateClick(nextBtn)) return;
            } catch(e) {}

            // Priority 2: Click the next item in the DOM queue
            try {
                var queueResult = (typeof mooziacQuery === 'function') ? mooziacQuery(['ytmusic-player-queue #contents', '#queue #contents']) : null;
                var container = queueResult ? queueResult.element : document;
                var items = Array.from(container.querySelectorAll('ytmusic-player-queue-item')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                if (items && items.length > 0) {
                    var currentIdx = items.findIndex(function(el) {
                        return el.hasAttribute('selected') ||
                               el.classList.contains('selected') ||
                               el.getAttribute('play-button-state') === 'playing' ||
                               el.getAttribute('play-button-state') === 'paused';
                    });
                    if (currentIdx !== -1 && currentIdx + 1 < items.length) {
                        if (simulateClick(items[currentIdx + 1])) {
                            if (queueResult && queueResult.tier > 0) {
                                window.webkit.messageHandlers.nowPlayingHandler.postMessage({ selectorFallbackUsed: true, feature: "queue", tier: queueResult.tier });
                            }
                            return;
                        }
                    }
                }
            } catch(e) {}

            // Priority 3: Fallback to HTML5 video player API
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.nextVideo === 'function') {
                    player.nextVideo();
                    return;
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
    func previousTrack() {
        if PlaylistManager.shared.hasActiveContext {
            if PlaylistManager.shared.playPreviousTrackInPlaylist() {
                return
            }
        }

        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            if engineMode != .offline {
                engineMode = .offline
            }
            if NativeAudioPlayer.shared.currentTrack == nil {
                NativeAudioPlayer.shared.playLastOrFirstTrack()
                return
            }
            NativeAudioPlayer.shared.previousTrack()
            return
        }
        let js = """
        (function() {
            function simulateClick(el) {
                if (!el) return false;
                var targets = [
                    el.querySelector('button'),
                    el.querySelector('tp-yt-paper-icon-button'),
                    el.querySelector('paper-icon-button'),
                    el.querySelector('ytmusic-play-button-renderer'),
                    el.querySelector('#play-button'),
                    el.querySelector('.play-button'),
                    el
                ];
                for (var i = 0; i < targets.length; i++) {
                    var t = targets[i];
                    if (t) {
                        try {
                            var opts = { bubbles: true, cancelable: true, view: window };
                            t.dispatchEvent(new MouseEvent('mousedown', opts));
                            t.dispatchEvent(new MouseEvent('mouseup', opts));
                            t.dispatchEvent(new MouseEvent('click', opts));
                            if (typeof t.click === 'function') t.click();
                            return true;
                        } catch(e) {}
                    }
                }
                return false;
            }

            // Priority 1: Click YouTube Music's official player bar Previous button
            try {
                var prevBtn = document.querySelector('ytmusic-player-bar .previous-button') ||
                              document.querySelector('.previous-button') ||
                              document.querySelector('#previous-button') ||
                              document.querySelector('tp-yt-paper-icon-button.previous-button') ||
                              document.querySelector('button[aria-label*="Previous"]') ||
                              document.querySelector('[title*="Previous"]');
                if (prevBtn && simulateClick(prevBtn)) return;
            } catch(e) {}

            // Priority 2: Click the previous item in the DOM queue
            try {
                var queueResult = (typeof mooziacQuery === 'function') ? mooziacQuery(['ytmusic-player-queue #contents', '#queue #contents']) : null;
                var container = queueResult ? queueResult.element : document;
                var items = Array.from(container.querySelectorAll('ytmusic-player-queue-item')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                if (items && items.length > 0) {
                    var currentIdx = items.findIndex(function(el) {
                        return el.hasAttribute('selected') ||
                               el.classList.contains('selected') ||
                               el.getAttribute('play-button-state') === 'playing' ||
                               el.getAttribute('play-button-state') === 'paused';
                    });
                    if (currentIdx > 0) {
                        if (simulateClick(items[currentIdx - 1])) {
                            if (queueResult && queueResult.tier > 0) {
                                window.webkit.messageHandlers.nowPlayingHandler.postMessage({ selectorFallbackUsed: true, feature: "queue", tier: queueResult.tier });
                            }
                            return;
                        }
                    }
                }
            } catch(e) {}

            // Priority 3: Fallback to HTML5 video player API
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.previousVideo === 'function') {
                    player.previousVideo();
                    return;
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }

    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        NativeAudioPlayer.shared.setRepeatMode(mode)

        let jsMode = mode.rawValue
        let js = """
        (function() {
            var targetMode = \(jsMode);
            window.ytmRepeatMode = targetMode;
            
            var v = document.querySelector('video');
            if (v) {
                v.loop = false;
            }
            
            try {
                var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.setLoop === 'function') {
                    player.setLoop(targetMode === 1);
                }
            } catch(e) {}
            
            try {
                var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
                var rBtn = null;
                var rTier = 0;
                if (playerBar && typeof mooziacQuery === 'function') {
                    var rResult = mooziacQuery(['.repeat-button', 'button[aria-label*="Repeat"]', 'button[aria-label*="repeat"]'], playerBar);
                    if (rResult) { rBtn = rResult.element; rTier = rResult.tier; }
                }
                if (!rBtn && playerBar) {
                    rBtn = playerBar.querySelector('.repeat-button') || playerBar.querySelector('button[aria-label*="Repeat"]') || playerBar.querySelector('button[aria-label*="repeat"]');
                }
                if (rBtn) {
                    var getRepeatState = function(btn) {
                        var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                        var pressed = btn.getAttribute('aria-pressed') === 'true' || btn.classList.contains('active');
                        if (label.indexOf('one') !== -1 || label.indexOf('single') !== -1) return 1;
                        if (pressed || (label.length > 0 && label.indexOf('off') === -1)) return 2;
                        return 0;
                    };
                    
                    var currentState = getRepeatState(rBtn);
                    var clickTarget = rBtn.querySelector('button') || rBtn.querySelector('tp-yt-paper-icon-button') || rBtn;
                    
                    if (targetMode === 1 && currentState !== 1) {
                        clickTarget.click();
                        if (rTier > 0) {
                            window.webkit.messageHandlers.nowPlayingHandler.postMessage({ selectorFallbackUsed: true, feature: "repeat", tier: rTier });
                        }
                        setTimeout(function() {
                            if (getRepeatState(rBtn) !== 1) clickTarget.click();
                        }, 120);
                    } else if (targetMode === 0 && currentState !== 0) {
                        clickTarget.click();
                        if (rTier > 0) {
                            window.webkit.messageHandlers.nowPlayingHandler.postMessage({ selectorFallbackUsed: true, feature: "repeat", tier: rTier });
                        }
                        setTimeout(function() {
                            if (getRepeatState(rBtn) !== 0) clickTarget.click();
                        }, 120);
                    }
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }

    public func setShuffleState(_ active: Bool) {
        self.isShuffleActive = active
        if engineMode == .offline {
            NativeAudioPlayer.shared.setShuffleState(active)
            return
        }
        let js = """
        (function() {
            window.ytmShuffleActive = \(active ? "true" : "false");
            try {
                var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
                var sBtn = playerBar ? (playerBar.querySelector('.shuffle-button') || playerBar.querySelector('button[aria-label*="Shuffle"]') || playerBar.querySelector('button[aria-label*="shuffle"]')) : null;
                if (sBtn) {
                    var targets = [sBtn, sBtn.querySelector('button'), sBtn.querySelector('tp-yt-paper-icon-button')];
                    for (var i = 0; i < targets.length; i++) {
                        if (targets[i]) { targets[i].click(); break; }
                    }
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }

    func toggleShuffle() {
        setShuffleState(!isShuffleActive)
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off: setRepeatMode(.one)
        case .one: setRepeatMode(.off)
        }
    }
    
    func fastForward(seconds: Double = 10.0) {
        if engineMode == .offline {
            NativeAudioPlayer.shared.fastForward(seconds: seconds)
            return
        }
        let js = """
        (function() {
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.seekTo === 'function' && typeof player.getCurrentTime === 'function') {
                    var curr = player.getCurrentTime();
                    var dur = player.getDuration() || 0;
                    player.seekTo(Math.min(dur, curr + \(seconds)), true);
                    return;
                }
            } catch(e) {}
            var v = document.querySelector('video');
            if (v) v.currentTime = Math.min(v.duration || 0, v.currentTime + \(seconds));
        })();
        """
        evaluateJS(js)
    }
    
    func rewind(seconds: Double = 10.0) {
        if engineMode == .offline {
            NativeAudioPlayer.shared.rewind(seconds: seconds)
            return
        }
        let js = """
        (function() {
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.seekTo === 'function' && typeof player.getCurrentTime === 'function') {
                    var curr = player.getCurrentTime();
                    player.seekTo(Math.max(0, curr - \(seconds)), true);
                    return;
                }
            } catch(e) {}
            var v = document.querySelector('video');
            if (v) v.currentTime = Math.max(0, v.currentTime - \(seconds));
        })();
        """
        evaluateJS(js)
    }
    
    func seek(to seconds: Double) {
        if engineMode == .offline {
            NativeAudioPlayer.shared.seek(to: seconds)
            return
        }
        let js = """
        (function() {
            try {
                var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.seekTo === 'function') {
                    player.seekTo(\(seconds), true);
                    return;
                }
            } catch(e) {}
            var v = document.querySelector('video');
            if (v) v.currentTime = \(seconds);
        })();
        """
        evaluateJS(js)
    }
    
    func toggleLike() {
        if engineMode == .offline || !NetworkMonitor.shared.isReachable {
            NativeAudioPlayer.shared.toggleLike()
            if let track = NativeAudioPlayer.shared.currentTrack {
                LikedSongsManager.shared.mirrorOfflineLike(trackID: track.id)
            }
            return
        }
        let desiredLiked = !currentState.isLiked
        let videoId = currentState.videoId.isEmpty ? (DownloadManager.extractVideoID(from: currentState.pageUrl) ?? "") : currentState.videoId
        if !videoId.isEmpty {
            LikedSongsManager.shared.recordOnlineLikeToggle(
                desiredLiked: desiredLiked,
                videoId: videoId,
                title: currentState.title,
                artist: currentState.artist,
                album: currentState.album,
                artworkUrl: currentState.artworkUrl,
                duration: currentState.duration
            )
        }
        // Only click YTM's button when signed in, so likes reach the account.
        guard LikedSongsManager.shared.isSignedIn else {
            // Signed out: keep the optimistic heart state consistent in the app.
            currentState.isLiked = desiredLiked
            observers.forEach { $0(currentState) }
            return
        }
        let js = """
        (function() {
            var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
            var likeRenderer = playerBar ? (playerBar.querySelector('ytmusic-like-button-renderer') || playerBar.querySelector('#like-button-renderer')) : null;
            var likeResult = null;
            if (likeRenderer && typeof mooziacQuery === 'function') {
                likeResult = mooziacQuery(['#button-shape-like button, .like-button'], likeRenderer);
            }
            if (!likeResult && likeRenderer) {
                var btns = likeRenderer.querySelectorAll('button');
                for (var i = 0; i < btns.length; i++) {
                    var label = (btns[i].getAttribute('aria-label') || btns[i].getAttribute('title') || '').toLowerCase();
                    if (!label.includes('dislike') && (label.includes('like') || label.includes('thumbs up'))) {
                        likeResult = { element: btns[i], tier: 1 };
                        break;
                    }
                }
            }
            if (!likeResult && typeof mooziacQuery === 'function') {
                likeResult = mooziacQuery([
                    'ytmusic-like-button-renderer button[aria-label*="Like"], #like-button-renderer button[aria-label*="Like"]',
                    'button[aria-label="Like"], button[aria-label*="thumbs up"]'
                ]);
                if (likeResult) {
                    var lbl = (likeResult.element.getAttribute('aria-label') || likeResult.element.getAttribute('title') || '').toLowerCase();
                    if (lbl.includes('dislike')) likeResult = null;
                }
            }
            if (likeResult) {
                likeResult.element.click();
                if (likeResult.tier > 0) {
                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({ selectorFallbackUsed: true, feature: "like", tier: likeResult.tier });
                }
                setTimeout(function() { if (typeof updateNowPlaying === 'function') updateNowPlaying(true); }, 250);
            }
        })();
        """
        evaluateJS(js)
    }
    
    func setEQPreset(_ preset: String) {
        let js = """
        (function() {
            if (!window.ytmAudioContext) {
                var video = document.querySelector('video');
                if (!video) return;
                try {
                    window.ytmAudioContext = new (window.AudioContext || window.webkitAudioContext)();
                    window.ytmSource = window.ytmAudioContext.createMediaElementSource(video);
                    
                    window.ytmLowFilter = window.ytmAudioContext.createBiquadFilter();
                    window.ytmLowFilter.type = 'lowshelf';
                    window.ytmLowFilter.frequency.value = 250;
                    
                    window.ytmMidFilter = window.ytmAudioContext.createBiquadFilter();
                    window.ytmMidFilter.type = 'peaking';
                    window.ytmMidFilter.frequency.value = 1500;
                    window.ytmMidFilter.Q.value = 1.0;
                    
                    window.ytmHighFilter = window.ytmAudioContext.createBiquadFilter();
                    window.ytmHighFilter.type = 'highshelf';
                    window.ytmHighFilter.frequency.value = 4000;
                    
                    window.ytmSource.connect(window.ytmLowFilter);
                    window.ytmLowFilter.connect(window.ytmMidFilter);
                    window.ytmMidFilter.connect(window.ytmHighFilter);
                    window.ytmHighFilter.connect(window.ytmAudioContext.destination);
                } catch(e) {}
            }
            if (window.ytmLowFilter && window.ytmMidFilter && window.ytmHighFilter) {
                var p = '\(preset)'.toLowerCase();
                if (p === 'bass boost') {
                    window.ytmLowFilter.gain.value = 8;
                    window.ytmMidFilter.gain.value = -1;
                    window.ytmHighFilter.gain.value = 2;
                } else if (p === 'vocal booster') {
                    window.ytmLowFilter.gain.value = -2;
                    window.ytmMidFilter.gain.value = 7;
                    window.ytmHighFilter.gain.value = 3;
                } else if (p === 'treble boost') {
                    window.ytmLowFilter.gain.value = -2;
                    window.ytmMidFilter.gain.value = 2;
                    window.ytmHighFilter.gain.value = 8;
                } else if (p === 'pop / edm') {
                    window.ytmLowFilter.gain.value = 5;
                    window.ytmMidFilter.gain.value = -3;
                    window.ytmHighFilter.gain.value = 6;
                } else { // Flat
                    window.ytmLowFilter.gain.value = 0;
                    window.ytmMidFilter.gain.value = 0;
                    window.ytmHighFilter.gain.value = 0;
                }
            }
        })();
        """
        evaluateJS(js)
    }
    
    func adjustVolume(deltaPercent: Double) {
        let js = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                var currentVol = video.volume || 1.0;
                var newVol = Math.max(0.0, Math.min(1.0, currentVol + (\(deltaPercent / 100.0))));
                video.volume = newVol;
            }
        })();
        """
        evaluateJS(js)
    }
}
