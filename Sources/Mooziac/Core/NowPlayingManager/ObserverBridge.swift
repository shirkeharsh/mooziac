import AppKit
import WebKit
import MediaPlayer

extension NowPlayingManager {
    func setupInWebView(_ userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: "nowPlayingHandler")
        userContentController.add(self, name: "nowPlayingHandler")
        
        let observerJS = """
        (function() {
            if (window.ytmObserverInjected) return;
            window.ytmObserverInjected = true;
            
            window.mooziacQuery = function(selectorTiers, root) {
                root = root || document;
                for (var i = 0; i < selectorTiers.length; i++) {
                    try {
                        var el = root.querySelector(selectorTiers[i]);
                        if (el) return { element: el, tier: i };
                    } catch (e) {}
                }
                return null;
            };
            
            var cachedTitle = "", cachedArtist = "", cachedArtwork = "", cachedAlbum = "", cachedVideoId = "";
            var lastMetaCheck = 0;
            var lastSongModeAttemptID = "";
            var lastOptimizedVideoId = "";
            var lastIsPlaying = null;
            var lastTime = 0;
            var lastPostTime = 0;
            
            function adPlayerAPIs() {
                var moviePlayer = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                var musicPlayer = document.querySelector('ytmusic-player');
                var musicAPI = musicPlayer && musicPlayer.playerApi;
                return [moviePlayer, musicAPI].filter(function(api, index, apis) {
                    return api && apis.indexOf(api) === index;
                });
            }

            function isAdShowing() {
                var moviePlayer = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (moviePlayer && moviePlayer.classList && (
                    moviePlayer.classList.contains('ad-showing') ||
                    moviePlayer.classList.contains('ad-interrupting')
                )) {
                    return true;
                }
                var apis = adPlayerAPIs();
                for (var i = 0; i < apis.length; i++) {
                    try {
                        if (typeof apis[i].getPresentingPlayerType === 'function' &&
                            apis[i].getPresentingPlayerType(true) === 2) {
                            return true;
                        }
                    } catch(e) {}
                }
                return false;
            }

            function updateNowPlaying(force) {
                try {
                    var video = document.querySelector('video');
                    var isPlaying = false, currentTime = 0, duration = 0, playbackRate = 1.0;
                    if (video) {
                        isPlaying = !video.paused && !video.ended && video.readyState > 2;
                        currentTime = video.currentTime || 0;
                        duration = video.duration || 0;
                        playbackRate = video.playbackRate || 1.0;
                    }
                    
                    var now = Date.now();
                    if (!force && !isPlaying && lastIsPlaying === false && Math.abs(currentTime - lastTime) < 0.1) {
                        return;
                    }
                    var minInterval = window.mooziacPanelVisible ? 350 : 1000;
                    if (!force && isPlaying && (now - lastPostTime < minInterval)) {
                        return;
                    }
                    var prevTime = lastTime;
                    lastPostTime = now;
                    lastIsPlaying = isPlaying;
                    lastTime = currentTime;
                    
                    var isAd = isAdShowing();
                    if (isAd) {
                        window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                            isAd: true,
                            isPlaying: isPlaying,
                            currentTime: currentTime,
                            duration: duration,
                            playbackRate: playbackRate,
                            title: cachedTitle || "",
                            artist: cachedArtist || "",
                            album: cachedAlbum || "",
                            artworkUrl: cachedArtwork || "",
                            pageUrl: window.location.href,
                            videoId: cachedVideoId || "",
                            trackID: cachedVideoId || "",
                            isLiked: false,
                            isShuffle: false,
                            isRepeat: false,
                            audioItag: "",
                            audioCodecs: "",
                            audioBitrate: ""
                        });
                        return;
                    }

                    // Extract live DOM metadata (authoritative source)
                    var titleElem = document.querySelector('ytmusic-player-bar .title') || document.querySelector('.ytmusic-player-bar.title');
                    var artistElem = document.querySelector('ytmusic-player-bar .byline') || document.querySelector('.ytmusic-player-bar.byline');
                    var liveDomTitle = titleElem ? (titleElem.innerText || titleElem.textContent || '').trim() : '';
                    var liveDomArtist = artistElem ? (artistElem.innerText || artistElem.textContent || '').trim() : '';

                    var livePlayerData = null;
                    try {
                        var playerEl = document.querySelector('#movie_player') || document.querySelector('ytmusic-player')?.playerApi;
                        if (playerEl && typeof playerEl.getVideoData === 'function') {
                            livePlayerData = playerEl.getVideoData();
                        }
                    } catch(e) {}

                    var livePlayerTitle = (livePlayerData && typeof livePlayerData.title === 'string') ? livePlayerData.title.trim() : '';
                    var livePlayerArtist = (livePlayerData && typeof livePlayerData.author === 'string') ? livePlayerData.author.trim() : '';
                    var livePlayerVideoId = (livePlayerData && livePlayerData.video_id) ? livePlayerData.video_id : '';

                    if (!livePlayerVideoId) {
                        try {
                            var match = window.location.href.match(/[?&]v=([^&]+)/);
                            if (match && match[1]) livePlayerVideoId = match[1];
                        } catch(e) {}
                    }

                    var liveMediaTitle = (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.title) ? navigator.mediaSession.metadata.title.trim() : '';
                    var liveMediaArtist = (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.artist) ? navigator.mediaSession.metadata.artist.trim() : '';
                    var liveMediaAlbum = (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.album) ? navigator.mediaSession.metadata.album.trim() : '';
                    var liveMediaArtwork = "";
                    if (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.artwork && navigator.mediaSession.metadata.artwork.length > 0) {
                        liveMediaArtwork = navigator.mediaSession.metadata.artwork[navigator.mediaSession.metadata.artwork.length - 1].src || "";
                    }

                    var resolvedTitle = liveDomTitle || livePlayerTitle || liveMediaTitle || cachedTitle || "";
                    var resolvedArtist = liveDomArtist || livePlayerArtist || liveMediaArtist || cachedArtist || "";
                    var resolvedAlbum = liveMediaAlbum || cachedAlbum || "";
                    var resolvedVideoId = livePlayerVideoId || cachedVideoId || "";

                    var isNewTrack = (resolvedVideoId && resolvedVideoId !== cachedVideoId) ||
                                     (resolvedTitle && resolvedTitle !== cachedTitle) ||
                                     (currentTime < 2.0 && prevTime > 5.0);

                    if (isNewTrack) {
                        cachedTitle = resolvedTitle;
                        cachedArtist = resolvedArtist;
                        cachedAlbum = resolvedAlbum;
                        cachedVideoId = resolvedVideoId;
                        enforceSongMode();
                        optimizePlaybackStreams();
                    } else {
                        if (resolvedTitle) cachedTitle = resolvedTitle;
                        if (resolvedArtist) cachedArtist = resolvedArtist;
                        if (resolvedAlbum) cachedAlbum = resolvedAlbum;
                        if (resolvedVideoId) cachedVideoId = resolvedVideoId;
                    }

                    if (liveMediaArtwork && liveMediaArtwork.indexOf('data:') !== 0) {
                        cachedArtwork = liveMediaArtwork;
                    } else if (!cachedArtwork || cachedArtwork.indexOf('data:') === 0 || isNewTrack) {
                        var artElem = document.querySelector('ytmusic-player-bar .image') ||
                                      document.querySelector('ytmusic-player-bar img#img') ||
                                      document.querySelector('ytmusic-player-bar #thumbnail img') ||
                                      document.querySelector('ytmusic-player-bar .thumbnail-image_wrapper img') ||
                                      document.querySelector('ytmusic-player-bar img') ||
                                      document.querySelector('img.ytmusic-player-bar');
                        if (artElem && artElem.src && artElem.src.indexOf('data:') !== 0) {
                            cachedArtwork = artElem.src;
                        } else if (cachedVideoId) {
                            cachedArtwork = "https://i.ytimg.com/vi/" + cachedVideoId + "/hqdefault.jpg";
                        }
                    }
                    
                    var currentIsLiked = false;
                    try {
                        var playerBar = document.querySelector('ytmusic-player-bar') || document.querySelector('#player-bar');
                        var likeRenderer = playerBar ? (playerBar.querySelector('ytmusic-like-button-renderer') || playerBar.querySelector('#like-button-renderer')) : null;
                        if (likeRenderer) {
                            var status = (likeRenderer.getAttribute('like-status') || '').toUpperCase();
                            if (status === 'LIKE') {
                                currentIsLiked = true;
                            } else if (status === 'DISLIKE' || status === 'INDIFFERENT') {
                                currentIsLiked = false;
                            } else {
                                var likeBtn = likeRenderer.querySelector('#button-shape-like button') ||
                                              likeRenderer.querySelector('button[aria-label*="Remove from your Liked Songs"]') ||
                                              likeRenderer.querySelector('button[aria-label*="Undo like"]');
                                if (likeBtn) {
                                    var ariaPressed = likeBtn.getAttribute('aria-pressed');
                                    var label = (likeBtn.getAttribute('aria-label') || likeBtn.getAttribute('title') || '').toLowerCase();
                                    if (ariaPressed === 'true' || label.includes('undo like') || label.includes('remove from your liked')) {
                                        currentIsLiked = true;
                                    }
                                }
                            }
                        }
                    } catch(e) {}
                    
                    var cachedShuffle = false;
                    var cachedRepeat = false;
                    try {
                        var sBtn = document.querySelector('ytmusic-player-bar .shuffle-button') || document.querySelector('.shuffle-button');
                        if (sBtn) {
                            cachedShuffle = sBtn.getAttribute('aria-pressed') === 'true' || sBtn.classList.contains('active') || sBtn.getAttribute('aria-checked') === 'true';
                        }
                        var rBtn = document.querySelector('ytmusic-player-bar .repeat-button') || document.querySelector('.repeat-button');
                        if (rBtn) {
                            var rPressed = rBtn.getAttribute('aria-pressed') === 'true' || rBtn.classList.contains('active') || rBtn.getAttribute('aria-checked') === 'true';
                            var rLabel = rBtn.getAttribute('aria-label') || '';
                            cachedRepeat = rPressed || (rLabel.length > 0 && rLabel.toLowerCase().indexOf('off') === -1);
                        }
                    } catch(e) {}
                    
                    if (cachedArtwork) {
                        syncSongArtwork(cachedArtwork);
                    }
                    
                    var audioDiag = { itag: "", codecs: "", bitrate: "" };
                    try {
                        var diagPlayer = document.querySelector('ytmusic-player')?.playerApi || document.getElementById('movie_player') || (window.yt && window.yt.player);
                        if (diagPlayer && typeof diagPlayer.getStatsForNerds === 'function') {
                            var stats = diagPlayer.getStatsForNerds() || {};
                            audioDiag.itag = String(stats.audioItag || stats.itag || stats.afmt || "");
                            audioDiag.codecs = String(stats.codecs || stats.audioCodec || stats.audioCodecs || "");
                            audioDiag.bitrate = String(stats.audioBitrate || stats.bitrate || "");
                        }
                    } catch(e) {}
                    
                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                        isAd: false,
                        title: cachedTitle || "",
                        artist: cachedArtist || "",
                        album: cachedAlbum || "",
                        artworkUrl: cachedArtwork || "",
                        isPlaying: isPlaying,
                        currentTime: currentTime,
                        duration: duration,
                        playbackRate: playbackRate,
                        pageUrl: window.location.href,
                        videoId: cachedVideoId || "",
                        trackID: (cachedVideoId && cachedVideoId.length > 0) ? cachedVideoId : ((cachedTitle || "") + "_" + (cachedArtist || "")),
                        isLiked: currentIsLiked,
                        isShuffle: cachedShuffle,
                        isRepeat: cachedRepeat,
                        audioItag: audioDiag.itag,
                        audioCodecs: audioDiag.codecs,
                        audioBitrate: audioDiag.bitrate
                    });
                } catch(e) {}
            }
            
            window.clickYTMElement = function(selectors) {
                for (var s = 0; s < selectors.length; s++) {
                    var el = document.querySelector(selectors[s]);
                    if (el) {
                        var targets = [el, el.querySelector('button'), el.querySelector('paper-icon-button'), el.querySelector('tp-yt-paper-icon-button')];
                        for (var i = 0; i < targets.length; i++) {
                            var t = targets[i];
                            if (t) {
                                try {
                                    var opts = { bubbles: true, cancelable: true, view: window };
                                    t.dispatchEvent(new MouseEvent('mousedown', opts));
                                    t.dispatchEvent(new MouseEvent('mouseup', opts));
                                    t.dispatchEvent(new MouseEvent('click', opts));
                                    if (typeof t.click === 'function') t.click();
                                } catch(e) {}
                            }
                        }
                        return true;
                    }
                }
                return false;
            };

            function optimizePlaybackStreams() {
                try {
                    var vid = cachedVideoId || "";
                    if (!vid) {
                        try {
                            var p = document.querySelector('#movie_player');
                            if (p && typeof p.getVideoData === 'function') {
                                var d = p.getVideoData();
                                if (d && d.video_id) vid = d.video_id;
                            }
                        } catch(e) {}
                    }
                    if (vid && vid === lastOptimizedVideoId) return;
                    if (vid) lastOptimizedVideoId = vid;

                    var players = [];
                    try {
                        var ytmusicPlayer = document.querySelector('ytmusic-player');
                        if (ytmusicPlayer) {
                            if (ytmusicPlayer.playerApi) players.push(ytmusicPlayer.playerApi);
                            players.push(ytmusicPlayer);
                        }
                    } catch(e) {}
                    try {
                        var moviePlayer = document.getElementById('movie_player');
                        if (moviePlayer) players.push(moviePlayer);
                    } catch(e) {}
                    try {
                        if (window.yt && window.yt.player) players.push(window.yt.player);
                    } catch(e) {}

                    players.forEach(function(player) {
                        // 1. Force High Audio Quality (256kbps AAC / 160kbps Opus)
                        if (typeof player.setAudioQuality === 'function') {
                            try { player.setAudioQuality('AUDIO_QUALITY_HIGH'); } catch(e) {}
                        }
                        if (typeof player.setOption === 'function') {
                            var options = [
                                ['audio', 'quality', 'AUDIO_QUALITY_HIGH'],
                                ['audio', 'audioQuality', 'AUDIO_QUALITY_HIGH'],
                                ['player', 'audioQuality', 'AUDIO_QUALITY_HIGH'],
                                ['player', 'audio_quality', 'AUDIO_QUALITY_HIGH'],
                                ['playback', 'audioQuality', 'AUDIO_QUALITY_HIGH'],
                                ['playback', 'audio_quality', 'AUDIO_QUALITY_HIGH']
                            ];
                            options.forEach(function(opt) {
                                try { player.setOption(opt[0], opt[1], opt[2]); } catch(e) {}
                            });
                        }
                        // 2. Smart Resolution Ceiling (360p/480p) to keep background CPU featherlight (<0.5%)
                        // NEVER use 'tiny' (144p) which locks YouTube into 48-64kbps degraded audio!
                        if (typeof player.setPlaybackQualityRange === 'function') {
                            try { player.setPlaybackQualityRange('small', 'medium'); } catch(e) {}
                        }
                    });
                } catch(e) {}
            }

            function syncSongArtwork(artworkUrl) {
                try {
                    if (!artworkUrl) return;
                    var songImgContainer = document.querySelector('ytmusic-player #song-image') ||
                                          document.querySelector('#song-image');
                    if (songImgContainer) {
                        var img = songImgContainer.querySelector('img#img') || songImgContainer.querySelector('img');
                        if (!img) {
                            img = document.createElement('img');
                            img.id = 'img';
                            songImgContainer.appendChild(img);
                        }
                        if (img && img.src !== artworkUrl) {
                            img.onerror = function() {
                                if (cachedVideoId && img.src.indexOf('maxresdefault') !== -1) {
                                    img.src = "https://i.ytimg.com/vi/" + cachedVideoId + "/hqdefault.jpg";
                                }
                            };
                            img.src = artworkUrl;
                        }
                    }
                } catch(e) {}
            }

            function enforceSongMode() {
                try {
                    // Dismiss promotional popups and paywalls that could pause playback
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
            }

            function __mooziacAttemptAutoplayRecovery(video, playBtn) {
                if (!window.__mooziacAutoplayPending) return 'noop';
                if (window.__mooziacPlaybackSuppressed || window.__mooziacBlockAutoplay) return 'suppressed';
                if (!video.paused) {
                    window.__mooziacAutoplayPending = false;
                    window.__mooziacAutoplayAttempts = 0;
                    return 'noop';
                }

                var attempts = window.__mooziacAutoplayAttempts || 0;
                if (attempts >= 6) {
                    return 'exhausted';
                }
                window.__mooziacAutoplayAttempts = attempts + 1;

                function scheduleRetry() {
                    if (typeof setTimeout !== 'function' || window.__mooziacAutoplayRetryScheduled) return;
                    window.__mooziacAutoplayRetryScheduled = true;
                    setTimeout(function() {
                        window.__mooziacAutoplayRetryScheduled = false;
                        var currentVideo = document.querySelector('video');
                        if (!window.__mooziacAutoplayPending || !currentVideo || !currentVideo.paused) return;
                        __mooziacAttemptAutoplayRecovery(currentVideo, null);
                    }, 250);
                }

                if (playBtn) {
                    try {
                        if (typeof playBtn.click === 'function') { playBtn.click(); }
                        else {
                            var opts = { bubbles: true, cancelable: true, view: window };
                            playBtn.dispatchEvent(new MouseEvent('mousedown', opts));
                            playBtn.dispatchEvent(new MouseEvent('mouseup', opts));
                            playBtn.dispatchEvent(new MouseEvent('click', opts));
                        }
                    } catch(e) {}
                    scheduleRetry();
                    return 'clicked';
                }
                try {
                    var playResult = video.play();
                    if (playResult && typeof playResult.catch === 'function') {
                        playResult.catch(function() { scheduleRetry(); });
                    }
                    scheduleRetry();
                    return 'played';
                } catch (e) {
                    scheduleRetry();
                    return 'error';
                }
            }
            window.__mooziacAttemptAutoplayRecovery = __mooziacAttemptAutoplayRecovery;

            function recoverAutoplayIfNeeded() {
                var video = document.querySelector('video');
                if (!video) return;
                if (window.__mooziacPlaybackSuppressed || window.__mooziacBlockAutoplay) {
                    try { video.pause(); } catch (_) {}
                    return;
                }
                var btn = document.querySelector('.play-pause-button.ytmusic-player-bar') ||
                          document.querySelector('ytmusic-player-bar #play-pause-button') ||
                          document.querySelector('#play-pause-button');
                __mooziacAttemptAutoplayRecovery(video, btn);
            }
            window.__mooziacRecoverAutoplayIfNeeded = recoverAutoplayIfNeeded;

            function bindVideoEvents() {
                var video = document.querySelector('video');
                if (video) {
                    if (!video.ytmBound) {
                        video.ytmBound = true;
                        ['play', 'playing', 'ended', 'loadedmetadata'].forEach(function(evt) {
                            video.addEventListener(evt, function() {
                                optimizePlaybackStreams();
                                enforceSongMode();
                                updateNowPlaying(true);
                            });
                        });
                        video.addEventListener('playing', function() {
                            window.__mooziacAutoplayPending = false;
                            window.__mooziacAutoplayAttempts = 0;
                        });
                        video.addEventListener('canplay', function() {
                            recoverAutoplayIfNeeded();
                        });
                        ['pause', 'ratechange', 'seeked'].forEach(function(evt) {
                            video.addEventListener(evt, function() {
                                updateNowPlaying(true);
                            });
                        });
                        video.addEventListener('timeupdate', function() {
                            updateNowPlaying(false);
                        });
                        video.addEventListener('ended', function() {
                            if (window.ytmRepeatMode === 1) {
                                try {
                                    var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                                    if (player && typeof player.seekTo === 'function') {
                                        player.seekTo(0);
                                        if (typeof player.playVideo === 'function') player.playVideo();
                                    } else if (video) {
                                        video.currentTime = 0;
                                        video.play();
                                    }
                                } catch(e) {
                                    if (video) {
                                        video.currentTime = 0;
                                        video.play();
                                    }
                                }
                            } else {
                                window.__mooziacAutoplayPending = true;
                                if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                                    window.__mooziacAudioOutput.prepare();
                                }
                                if (isAdShowing()) {
                                    if (video) {
                                        video.muted = false;
                                        video.playbackRate = 1.0;
                                    }
                                    return;
                                }
                                try {
                                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                                        event: 'videoEnded',
                                        videoId: cachedVideoId || "",
                                        isAd: false
                                    });
                                } catch(e) {}
                            }
                        });
                        if (video.readyState >= 3) {
                            recoverAutoplayIfNeeded();
                        }
                        optimizePlaybackStreams();
                        enforceSongMode();
                    }
                }
            }
            
            function bypassAdsAndPopups() {
                try {
                    var skipBtns = document.querySelectorAll('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, button.ytp-ad-skip-button-self-modern, [class*="skip-button"], .ytp-ad-overlay-close-button');
                    for (var i = 0; i < skipBtns.length; i++) {
                        if (skipBtns[i]) skipBtns[i].click();
                    }
                    var dismissBtns = document.querySelectorAll(
                        'ytmusic-mealbar-promo-renderer #dismiss-button button, ' +
                        'ytmusic-dialog #dismiss-button button, ' +
                        'ytmusic-you-there-renderer #button, ' +
                        'tp-yt-paper-dialog #dismiss-button'
                    );
                    for (var d = 0; d < dismissBtns.length; d++) {
                        if (dismissBtns[d]) dismissBtns[d].click();
                    }
                    var player = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                    if (player && player.classList && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) {
                        var video = document.querySelector('video');
                        if (video) {
                            video.muted = true;
                            if (!isNaN(video.duration) && video.duration > 0) {
                                video.currentTime = video.duration - 0.1;
                            }
                            video.playbackRate = 16.0;
                        }
                    }
                    var dialogBtns = document.querySelectorAll('ytmusic-you-there-renderer button, .ytmusic-you-there-renderer #button, .ytmusic-you-there-renderer tp-yt-paper-button');
                    for (var j = 0; j < dialogBtns.length; j++) {
                        if (dialogBtns[j]) dialogBtns[j].click();
                    }
                } catch(e) {}
            }
            
            bindVideoEvents();
            setInterval(function() {
                bindVideoEvents();
            }, 4000);
            setInterval(bypassAdsAndPopups, 500);
        })();
        """
        
        let script = WKUserScript(source: observerJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(script)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nowPlayingHandler",
              let dict = message.body as? [String: Any] else { return }
        // Drop callbacks received while a terminated WebContent is being restored;
        // stale messages from the dead process must not affect the new instance.
        guard !isRestoringAfterTermination else { return }

        // Log R1 Part A selector-fallback telemetry (observability only).
        if let fallback = dict["selectorFallbackUsed"] as? Bool, fallback,
           let feature = dict["feature"] as? String,
           let tier = dict["tier"] as? Int {
            print("[NowPlayingManager] Selector fallback used — feature: \(feature), tier: \(tier)")
            return
        }

        // Handle playlist track ended event
        if let event = dict["event"] as? String, event == "videoEnded" {
            let isAd = (dict["isAd"] as? Bool) ?? false
            if isAd { return }

            if repeatMode == .one {
                seek(to: 0.0)
                play()
                return
            }
            if PlaylistManager.shared.hasActiveContext {
                if PlaylistManager.shared.playNextTrackInPlaylist() {
                    return
                }
            } else if repeatMode == .off && NetworkMonitor.shared.isReachable && engineMode == .online {
                // Standalone online track ended with Repeat OFF -> trigger Infinite Flow!
                var seed = NowPlayingManager.shared.currentState.videoId
                if seed.isEmpty || seed.contains("_") {
                    seed = (dict["videoId"] as? String) ?? ""
                }
                if seed.isEmpty || seed.contains("_") {
                    seed = currentVideoId
                }
                if !seed.isEmpty && !seed.contains("_") {
                    PlaylistManager.shared.triggerInfiniteFlow(seededFrom: seed)
                    return
                }
            }
            return
        }

        let isAd = (dict["isAd"] as? Bool) ?? false
        let isPlaying = (dict["isPlaying"] as? Bool) ?? false
        let title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = (dict["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let album = (dict["album"] as? String) ?? ""
        let artworkUrl = (dict["artworkUrl"] as? String) ?? ""
        var currentTime = (dict["currentTime"] as? Double) ?? 0.0
        let duration = (dict["duration"] as? Double) ?? 0.0
        let playbackRate = (dict["playbackRate"] as? Double) ?? 1.0
        let pageUrl = (dict["pageUrl"] as? String) ?? ""
        let videoId = (dict["videoId"] as? String) ?? ""
        let msgTrackID = (dict["trackID"] as? String) ?? (!videoId.isEmpty ? videoId : "\(title)_\(artist)")
        let isShuffleOn = (dict["isShuffle"] as? Bool) ?? false
        let isRepeatOn = (dict["isRepeat"] as? Bool) ?? false

        if isAd {
            // An ad is playing: update time and play status so background keepalive runs,
            // but keep the current track metadata and do NOT notify trackChanged or fetch lyrics.
            var adState = currentState
            adState.isPlaying = isPlaying
            adState.currentTime = currentTime
            adState.duration = duration
            adState.playbackRate = playbackRate
            adState.hostTimestamp = CACurrentMediaTime()
            adState.isAd = true
            currentState = adState
            return
        }

        // Mutual exclusivity: If in offline mode and WebKit starts playing, immediately pause offline audio
        if engineMode == .offline {
            if isPlaying && !title.isEmpty && title != "Not Playing" {
                print("[NowPlayingManager] WebKit started playing '\(title)' while offline player was active. Pausing offline player and switching to online mode.")
                NativeAudioPlayer.shared.pause()
                engineMode = .online
                NotificationCenter.default.post(name: NSNotification.Name("Mooziac_EngineModeChanged"), object: nil, userInfo: ["mode": engineMode.rawValue])
            } else {
                // Ignore in-flight pause/idle events from WebKit while playing an offline track
                return
            }
        }

        let trackChanged = (!title.isEmpty && title != "Not Playing" && (msgTrackID != currentVideoId || title != currentState.title))
        
        if trackChanged {
            currentVideoId = msgTrackID
            currentTime = 0.0
            lastTrackChangeTime = CACurrentMediaTime()
        } else if !msgTrackID.isEmpty && msgTrackID != currentVideoId {
            if title.isEmpty || title == "Not Playing" {
                return
            }
        }
        
        let jsReportedLiked = (dict["isLiked"] as? Bool) ?? false

        var effectiveLiked = jsReportedLiked
        if engineMode == .online, !LikedSongsManager.shared.isSignedIn, !videoId.isEmpty {
            effectiveLiked = LikedSongsManager.shared.isLiked(videoId: videoId)
        }
        
        let rawItag = (dict["audioItag"] as? String) ?? ""
        let itag = rawItag.trimmingCharacters(in: .whitespacesAndNewlines)
        let isHighQuality = (itag == "141" || itag == "251")
        let qualityDescription: String
        switch itag {
        case "141":
            qualityDescription = "256 kbps AAC (High Quality)"
        case "251":
            qualityDescription = "160 kbps Opus (High Quality)"
        case "140":
            qualityDescription = "128 kbps AAC (Standard Quality)"
        case "139", "249", "250":
            qualityDescription = "48–64 kbps (Low Quality)"
        default:
            if isPlaying && !itag.isEmpty {
                qualityDescription = "Audio itag \(itag)"
            } else if !currentState.currentAudioQuality.isEmpty && currentState.currentAudioQuality != "Standard Quality" && !trackChanged {
                qualityDescription = currentState.currentAudioQuality
            } else {
                qualityDescription = "Standard Quality"
            }
        }
        let effectiveHQ = isHighQuality || (!trackChanged && currentState.isHighQualityStream && itag.isEmpty)
        let effectiveItag = !itag.isEmpty ? itag : (!trackChanged ? currentState.audioItag : "")

        let newState = PlaybackState(
            title: title,
            artist: artist,
            album: album,
            artworkUrl: artworkUrl,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            pageUrl: pageUrl,
            videoId: videoId,
            trackID: msgTrackID,
            hostTimestamp: CACurrentMediaTime(),
            playbackRate: playbackRate,
            isLiked: effectiveLiked,
            isShuffleOn: isShuffleOn,
            isRepeatOn: isRepeatOn,
            repeatMode: self.repeatMode,
            engineMode: self.engineMode,
            currentAudioQuality: qualityDescription,
            isHighQualityStream: effectiveHQ,
            audioItag: effectiveItag,
            isAd: false
        )
        
        currentState = newState
        DOMHealthMonitor.shared.recordSuccessfulUpdate()
        
        if !title.isEmpty && title != "Not Playing" {
            if trackChanged {
                lastSavedTitle = title
                lastSavedArtist = artist
                UserDefaults.standard.set(title, forKey: "YTM_lastTitle")
                UserDefaults.standard.set(artist, forKey: "YTM_lastArtist")
                UserDefaults.standard.set(artworkUrl, forKey: "YTM_lastArtwork")
                UserDefaults.standard.set(jsReportedLiked, forKey: "YTM_lastIsLiked")
                
                // Construct absolute watch URL whenever videoId is present
                var targetWatchUrl = ""
                if !videoId.isEmpty {
                    targetWatchUrl = "https://music.youtube.com/watch?v=\(videoId)"
                    UserDefaults.standard.set(videoId, forKey: "YTM_lastVideoId")
                    UserDefaults.standard.set(targetWatchUrl, forKey: "YTM_lastUrl")
                } else if !pageUrl.isEmpty && pageUrl.contains("music.youtube.com") && pageUrl.contains("watch?v=") && !pageUrl.contains("search?q=") {
                    targetWatchUrl = pageUrl
                    UserDefaults.standard.set(pageUrl, forKey: "YTM_lastUrl")
                }
            }
            
            if trackChanged {
                // Reset time for new track start
                UserDefaults.standard.set(0.0, forKey: "YTM_lastTime")
                
                // Trigger native macOS track change notification
                TrackNotificationManager.shared.notifyTrackChange(title: title, artist: artist, artworkUrl: artworkUrl)
            } else if isPlaying && currentTime > 1.0 {
                // Throttle time updates to every 5 seconds to minimize disk operations
                if abs(currentTime - UserDefaults.standard.double(forKey: "YTM_lastTime")) >= 5.0 {
                    UserDefaults.standard.set(currentTime, forKey: "YTM_lastTime")
                }
            }

            if isPlaying {
                HistoryManager.shared.trackDidStartOnline(
                    title: title,
                    artist: artist,
                    album: album,
                    artworkUrl: artworkUrl,
                    videoId: videoId,
                    duration: duration
                )
            }
        }
        
        let isPlayingChanged = (lastIsPlayingState != isPlaying)
        lastIsPlayingState = isPlaying
        
        if trackChanged || isPlayingChanged {
            updateSystemNowPlayingInfo(newState)
        }
        notifyObservers(newState)
    }
}
