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
            var cachedIsLiked = false, cachedShuffle = false, cachedRepeat = false;
            var cachedAudioDiag = { itag: "", codecs: "", bitrate: "" };
            var lastAudioDiagCheck = 0;
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

            var lastTrackEndedPostTime = 0;
            function notifyTrackEnded(source) {
                var now = Date.now();
                if (now - lastTrackEndedPostTime < 2500) return;

                var video = document.querySelector('video');
                var curTime = (video && video.currentTime) || 0;
                var dur = (video && video.duration) || 0;

                if (isAdShowing()) {
                    return;
                }

                // Natural check: If track duration is substantial, don't report completion unless near end
                if (dur > 20.0 && curTime < (dur - 3.0)) {
                    return;
                }

                lastTrackEndedPostTime = now;

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
                    return;
                }

                window.__mooziacAutoplayPending = true;
                if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                    window.__mooziacAudioOutput.prepare();
                }
                try {
                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                        event: 'videoEnded',
                        videoId: cachedVideoId || "",
                        currentTime: curTime,
                        duration: dur,
                        isAd: false,
                        source: source || 'unknown'
                    });
                } catch(e) {}
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
                    
                    if (video && duration > 5.0 && currentTime >= (duration - 0.85) && (!isPlaying || video.paused || video.ended)) {
                        notifyTrackEnded('timeNearEnd');
                    }

                    var now = Date.now();
                    if (!force && !isPlaying && lastIsPlaying === false && Math.abs(currentTime - lastTime) < 0.1) {
                        return;
                    }
                    var minInterval = window.mooziacPanelVisible ? 1000 : 2500;
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

                    // Ultra-light Background Path: When panel is hidden in menu bar and song is unchanged,
                    // post cached state with zero DOM queries to keep background CPU under 0.2%
                    if (!force && !window.mooziacPanelVisible && cachedTitle && cachedVideoId) {
                        var fastVid = cachedVideoId;
                        try {
                            var pFast = document.getElementById('movie_player');
                            if (pFast && typeof pFast.getVideoData === 'function') {
                                var vd = pFast.getVideoData();
                                if (vd && vd.video_id) fastVid = vd.video_id;
                            }
                        } catch(e) {}

                        if (fastVid === cachedVideoId && !(currentTime < 2.0 && prevTime > 5.0)) {
                            window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                                isAd: false,
                                title: cachedTitle,
                                artist: cachedArtist,
                                album: cachedAlbum,
                                artworkUrl: cachedArtwork,
                                isPlaying: isPlaying,
                                currentTime: currentTime,
                                duration: duration,
                                playbackRate: playbackRate,
                                pageUrl: window.location.href,
                                videoId: cachedVideoId,
                                trackID: cachedVideoId,
                                isLiked: cachedIsLiked,
                                isShuffle: cachedShuffle,
                                isRepeat: cachedRepeat,
                                audioItag: "",
                                audioCodecs: "",
                                audioBitrate: ""
                            });
                            return;
                        }
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
                        cachedArtwork = "";
                        cachedAudioDiag = { itag: "", codecs: "", bitrate: "" };
                        lastAudioDiagCheck = 0;
                        enforceSongMode();
                        optimizePlaybackStreams();
                    } else {
                        if (resolvedTitle) cachedTitle = resolvedTitle;
                        if (resolvedArtist) cachedArtist = resolvedArtist;
                        if (resolvedAlbum) cachedAlbum = resolvedAlbum;
                        if (resolvedVideoId) cachedVideoId = resolvedVideoId;
                    }

                    // Only trust liveMediaArtwork if mediaSession metadata matches the current track
                    var mediaSessionMatches = liveMediaTitle && cachedTitle &&
                        (liveMediaTitle.toLowerCase() === cachedTitle.toLowerCase() ||
                         cachedTitle.toLowerCase().indexOf(liveMediaTitle.toLowerCase()) !== -1 ||
                         liveMediaTitle.toLowerCase().indexOf(cachedTitle.toLowerCase()) !== -1);

                    if (mediaSessionMatches && liveMediaArtwork && liveMediaArtwork.indexOf('data:') !== 0) {
                        cachedArtwork = liveMediaArtwork;
                    } else if (!cachedArtwork || cachedArtwork.indexOf('data:') === 0 || isNewTrack) {
                        var artElem = document.querySelector('ytmusic-player-bar .image') ||
                                      document.querySelector('ytmusic-player-bar img#img') ||
                                      document.querySelector('ytmusic-player-bar #thumbnail img') ||
                                      document.querySelector('ytmusic-player-bar .thumbnail-image_wrapper img') ||
                                      document.querySelector('ytmusic-player-bar img') ||
                                      document.querySelector('img.ytmusic-player-bar');
                        if (artElem && artElem.src && artElem.src.indexOf('data:') !== 0 && !isNewTrack) {
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
                                var likeBtn = likeRenderer.querySelector('#button-shape-like button, .like-button, [aria-label*="Liked Songs" i], [aria-label*="Undo like" i]');
                                if (!likeBtn) {
                                    var btns = likeRenderer.querySelectorAll('button, tp-yt-paper-icon-button, yt-icon-button');
                                    for (var bi = 0; bi < btns.length; bi++) {
                                        var bLabel = (btns[bi].getAttribute('aria-label') || btns[bi].getAttribute('title') || '').toLowerCase();
                                        if (!bLabel.includes('dislike') && (bLabel.includes('like') || bLabel.includes('undo') || bLabel.includes('remove') || bLabel.includes('thumbs up'))) {
                                            likeBtn = btns[bi];
                                            break;
                                        }
                                    }
                                }
                                if (likeBtn) {
                                    var ariaPressed = likeBtn.getAttribute('aria-pressed') === 'true' || likeBtn.getAttribute('aria-checked') === 'true' || likeBtn.classList.contains('active');
                                    var label = (likeBtn.getAttribute('aria-label') || likeBtn.getAttribute('title') || '').toLowerCase();
                                    if (ariaPressed || label.includes('undo like') || label.includes('remove from your liked') || label.includes('remove from liked')) {
                                        currentIsLiked = true;
                                    }
                                }
                            }
                        }
                    } catch(e) {}
                    
                    cachedIsLiked = currentIsLiked;
                    cachedShuffle = false;
                    cachedRepeat = false;
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
                    
                    if (cachedArtwork && window.mooziacPanelVisible) {
                        syncSongArtwork(cachedArtwork);
                    }
                    
                    var audioDiag = cachedAudioDiag;
                    if (window.mooziacPanelVisible && (!cachedAudioDiag.itag || (now - lastAudioDiagCheck > 5000))) {
                        lastAudioDiagCheck = now;
                        try {
                            var diagPlayer = document.querySelector('ytmusic-player')?.playerApi || document.getElementById('movie_player') || (window.yt && window.yt.player);
                            if (diagPlayer && typeof diagPlayer.getStatsForNerds === 'function') {
                                var stats = diagPlayer.getStatsForNerds() || {};
                                var diagItag = String(stats.audioItag || stats.itag || stats.afmt || "");
                                var diagCodecs = String(stats.codecs || stats.audioCodec || stats.audioCodecs || "");
                                var diagBitrate = String(stats.audioBitrate || stats.bitrate || "");
                                if (diagItag || diagCodecs || diagBitrate) {
                                    cachedAudioDiag = { itag: diagItag, codecs: diagCodecs, bitrate: diagBitrate };
                                    audioDiag = cachedAudioDiag;
                                }
                            }
                        } catch(e) {}
                    }
                    
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
                            notifyTrackEnded('domEnded');
                        });
                        if (video.readyState >= 3) {
                            recoverAutoplayIfNeeded();
                        }
                        optimizePlaybackStreams();
                        enforceSongMode();
                    }
                }

                // Hook YouTube Player API state changes (0 = ENDED)
                try {
                    var playerApi = document.getElementById('movie_player') || (document.querySelector('ytmusic-player') && document.querySelector('ytmusic-player').playerApi);
                    if (playerApi && typeof playerApi.addEventListener === 'function' && !playerApi.__mooziacEndedHooked) {
                        playerApi.__mooziacEndedHooked = true;
                        playerApi.addEventListener('onStateChange', function(state) {
                            if (state === 0) {
                                notifyTrackEnded('playerStateEnded');
                            }
                        });
                    }
                } catch(e) {}
            }
            
            var adMutedByBypass = false;
            var isBypassing = false;
            function bypassAdsAndPopups() {
                if (isBypassing) return;
                isBypassing = true;
                try {
                    var mp = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                    var video = document.querySelector('#movie_player video') || document.querySelector('video');
                    if (!video) return;

                    var isAd = !!(mp && mp.classList && (
                        mp.classList.contains('ad-showing') ||
                        mp.classList.contains('ad-interrupting')
                    ));

                    if (isAd) {
                        adMutedByBypass = true;
                        video.muted = true;

                        var skipBtns = document.querySelectorAll(
                            '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, ' +
                            '.ytp-ad-skip-button-container button, button.ytp-ad-skip-button-modern, ' +
                            'button.ytp-skip-ad-button, button.ytp-ad-skip-button, button[aria-label*="Skip" i]'
                        );
                        for (var i = 0; i < skipBtns.length; i++) {
                            try { skipBtns[i].click(); } catch(e) {}
                        }
                        var closeBtns = document.querySelectorAll('.ytp-ad-overlay-close-button');
                        for (var c = 0; c < closeBtns.length; c++) {
                            try { closeBtns[c].click(); } catch(e) {}
                        }
                    } else if (adMutedByBypass) {
                        adMutedByBypass = false;
                        video.muted = false;
                    }
                } catch(e) {} finally {
                    isBypassing = false;
                }
            }

            function dismissPromoDialogs() {
                try {
                    var dismissBtns = document.querySelectorAll(
                        'ytmusic-mealbar-promo-renderer #dismiss-button button, ' +
                        'ytmusic-mealbar-promo-renderer tp-yt-paper-button, ' +
                        'ytmusic-banner-promo-renderer #dismiss-button button, ' +
                        'ytmusic-dialog #dismiss-button button, ' +
                        'ytmusic-you-there-renderer #button, ' +
                        '.ytmusic-you-there-renderer button, ' +
                        '.ytmusic-you-there-renderer tp-yt-paper-button, ' +
                        'tp-yt-paper-dialog #dismiss-button, ' +
                        'ytmusic-player-bar-promo-renderer #dismiss-button button'
                    );
                    for (var d = 0; d < dismissBtns.length; d++) {
                        try { dismissBtns[d].click(); } catch(e) {}
                    }
                } catch(e) {}
            }
            
            bindVideoEvents();

            try {
                var playerNode = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (playerNode && window.MutationObserver) {
                    var adObserver = new MutationObserver(function() {
                        bypassAdsAndPopups();
                    });
                    adObserver.observe(playerNode, { attributes: true, attributeFilter: ['class'] });
                }
            } catch(e) {}

            setInterval(function() {
                bindVideoEvents();
            }, 4000);
            setInterval(bypassAdsAndPopups, 250);
            setInterval(dismissPromoDialogs, 3500);
        })();
        """
        
        let script = WKUserScript(source: observerJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(script)
    }

    private func handleTrackEnded(dict: [String: Any]) {
        let isAd = (dict["isAd"] as? Bool) ?? false
        if isAd { return }

        let now = CACurrentMediaTime()
        guard now - lastTrackEndedTriggerTime > 3.0 else { return }

        // Natural guard: If track changed less than 5 seconds ago, ignore premature ends
        guard now - lastTrackChangeTime > 5.0 else { return }

        // If duration is known and currentTime is significantly before the end, ignore
        let currentTime = (dict["currentTime"] as? Double) ?? currentState.currentTime
        let duration = (dict["duration"] as? Double) ?? currentState.duration
        if duration > 20.0 && currentTime < (duration - 4.0) {
            Log.playback.debug("Ignoring premature track completion: currentTime=\(currentTime), duration=\(duration)")
            return
        }

        lastTrackEndedTriggerTime = now

        if repeatMode == .one {
            seek(to: 0.0)
            play()
            return
        }

        // Only advance Mooziac playlist if an active context exists
        if PlaylistManager.shared.hasActiveContext {
            if PlaylistManager.shared.playNextTrackInPlaylist() {
                return
            }
        }

        // When in online mode without active Mooziac playlist context:
        // Let YouTube Music naturally advance its own Up Next recommendation queue.
        Log.playback.debug("No active playlist context — letting YouTube Music naturally play next suggestion")
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
            Log.web.debug("Selector fallback used — feature: \(feature), tier: \(tier)")
            return
        }

        // Handle track ended event from WebKit
        if let event = dict["event"] as? String, event == "videoEnded" {
            handleTrackEnded(dict: dict)
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

        // Auto-advance fallback: only if playing an active Mooziac playlist context, past startup (>5s), and audio paused near the end of the track (within 1.25s)
        let now = CACurrentMediaTime()
        if !isAd && !isPlaying && duration > 5.0 && currentTime >= (duration - 1.25) && (now - lastTrackChangeTime > 5.0) && PlaylistManager.shared.hasActiveContext {
            handleTrackEnded(dict: dict)
        }

        if isAd {
            // An ad is playing: update time and play status so background keepalive runs,
            // but keep the current track metadata and do NOT notify trackChanged or fetch lyrics.
            var adState = currentState
            adState.isPlaying = isPlaying
            adState.currentTime = currentTime
            adState.duration = duration
            adState.playbackRate = playbackRate
            adState.hostTimestamp = now
            adState.isAd = true
            currentState = adState
            domHealthMonitor.recordSuccessfulUpdate()
            return
        }

        // Mutual exclusivity: If in offline mode and WebKit starts playing, immediately pause offline audio
        if engineMode == .offline {
            if isPlaying && !title.isEmpty && title != "Not Playing" {
                Log.playback.info("WebKit started playing '\(title)' while offline player was active. Pausing offline player and switching to online mode")
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
            lastTrackChangeTime = now

            // Natural divergence: If user actively navigated to a track outside current playlist context, release context so YouTube suggestions take over
            if let ctx = PlaylistManager.shared.activeContext {
                let inContext = ctx.items.contains { item in
                    item.id == msgTrackID ||
                    item.refID == msgTrackID ||
                    (!videoId.isEmpty && (item.ytVideoId == videoId || item.refID == videoId)) ||
                    (!title.isEmpty && item.title.localizedCaseInsensitiveCompare(title) == .orderedSame)
                }
                if !inContext {
                    Log.playback.info("Divergence detected: '\(title)' is outside active playlist '\(ctx.playlistID)'. Releasing playlist context to follow YouTube suggestions.")
                    PlaylistManager.shared.clearActiveContext()
                }
            }
        } else if !msgTrackID.isEmpty && msgTrackID != currentVideoId {
            if title.isEmpty || title == "Not Playing" {
                return
            }
        }
        
        let jsReportedLiked = (dict["isLiked"] as? Bool) ?? false
        var resolvedVid = videoId
        if resolvedVid.isEmpty {
            resolvedVid = DownloadManager.extractVideoID(from: pageUrl) ?? DownloadManager.extractVideoID(from: msgTrackID) ?? ""
        }
        let isLocallyLiked = !resolvedVid.isEmpty && LikedSongsManager.shared.isLiked(videoId: resolvedVid)

        var effectiveLiked = jsReportedLiked || isLocallyLiked
        let isWithinUserToggleLock = (now - lastUserLikeToggleTime < 2.0) && (resolvedVid == lastUserToggledVideoId || (!resolvedVid.isEmpty && lastUserToggledVideoId.isEmpty))

        if isWithinUserToggleLock {
            effectiveLiked = lastUserDesiredLiked
        } else if engineMode == .online {
            if !LikedSongsManager.shared.isSignedIn {
                effectiveLiked = isLocallyLiked
            } else {
                // When signed in:
                // 1. If song is liked on YouTube Music, ensure it exists in Mooziac's local Liked Songs table
                if !resolvedVid.isEmpty {
                    if jsReportedLiked {
                        if !isLocallyLiked {
                            LikedSongsManager.shared.recordOnlineLikeToggle(
                                desiredLiked: true,
                                videoId: resolvedVid,
                                title: title,
                                artist: artist,
                                album: album,
                                artworkUrl: artworkUrl,
                                duration: duration
                            )
                        }
                    } else if !trackChanged && currentState.isLiked && !jsReportedLiked && (now - lastUserLikeToggleTime > 5.0) {
                        // 2. Edge-trigger: user unliked the song directly in the YouTube Music web interface
                        LikedSongsManager.shared.recordOnlineLikeToggle(
                            desiredLiked: false,
                            videoId: resolvedVid,
                            title: title,
                            artist: artist,
                            album: album,
                            artworkUrl: artworkUrl,
                            duration: duration
                        )
                        effectiveLiked = false
                    }
                }
            }
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
        domHealthMonitor.recordSuccessfulUpdate()
        
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
            } else if !artworkUrl.isEmpty && UserDefaults.standard.string(forKey: "YTM_lastArtwork") != artworkUrl {
                UserDefaults.standard.set(artworkUrl, forKey: "YTM_lastArtwork")
            }
            
            if trackChanged {
                // Reset time for new track start
                UserDefaults.standard.set(0.0, forKey: "YTM_lastTime")
                
                // Trigger native macOS track change notification
                notificationManager.notifyTrackChange(title: title, artist: artist, artworkUrl: artworkUrl)
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
