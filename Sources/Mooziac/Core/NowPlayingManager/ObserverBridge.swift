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
                    
                    if (!force && !isPlaying && lastIsPlaying === false && Math.abs(currentTime - lastTime) < 0.1) {
                        return;
                    }
                    lastIsPlaying = isPlaying;
                    lastTime = currentTime;
                    
                    var currentMetaTitle = "", currentMetaArtist = "";
                    if (navigator.mediaSession && navigator.mediaSession.metadata) {
                        currentMetaTitle = navigator.mediaSession.metadata.title || "";
                        currentMetaArtist = navigator.mediaSession.metadata.artist || "";
                    }
                    
                    var isNewTrack = (currentMetaTitle && (currentMetaTitle !== cachedTitle || currentMetaArtist !== cachedArtist)) ||
                                     (currentTime < 2.0 && lastTime > 5.0);
                    if (isNewTrack) {
                        enforceSongMode();
                    }
                    
                    var now = Date.now();
                    if (force || isNewTrack || (now - lastMetaCheck > 3000) || !cachedTitle) {
                        lastMetaCheck = now;
                        
                        if (navigator.mediaSession && navigator.mediaSession.metadata) {
                            var meta = navigator.mediaSession.metadata;
                            cachedTitle = meta.title || "";
                            cachedArtist = meta.artist || "";
                            cachedAlbum = meta.album || "";
                            if (meta.artwork && meta.artwork.length > 0) {
                                cachedArtwork = meta.artwork[meta.artwork.length - 1].src || "";
                            }
                        }
                        
                        if (!cachedTitle) {
                            var titleElem = document.querySelector('ytmusic-player-bar .title') || document.querySelector('.ytmusic-player-bar.title');
                            if (titleElem) cachedTitle = titleElem.innerText || titleElem.textContent;
                        }
                        
                        if (!cachedArtist) {
                            var artistElem = document.querySelector('ytmusic-player-bar .byline') || document.querySelector('.ytmusic-player-bar.byline');
                            if (artistElem) cachedArtist = artistElem.innerText || artistElem.textContent;
                        }
                        
                        if (!cachedArtwork || cachedArtwork.indexOf('data:') === 0) {
                            var artElem = document.querySelector('ytmusic-player-bar .image') ||
                                          document.querySelector('ytmusic-player-bar img#img') ||
                                          document.querySelector('ytmusic-player-bar #thumbnail img') ||
                                          document.querySelector('ytmusic-player-bar .thumbnail-image_wrapper img') ||
                                          document.querySelector('ytmusic-player-bar img') ||
                                          document.querySelector('img.ytmusic-player-bar');
                            if (artElem && artElem.src && artElem.src.indexOf('data:') !== 0) {
                                cachedArtwork = artElem.src;
                            }
                        }
                        
                        var pageUrl = window.location.href;
                        cachedVideoId = "";
                        try {
                            var player = document.querySelector('#movie_player');
                            if (player && typeof player.getVideoData === 'function') {
                                var data = player.getVideoData();
                                if (data && data.video_id) cachedVideoId = data.video_id;
                            }
                        } catch(e) {}
                        if (!cachedVideoId) {
                            try {
                                var match = pageUrl.match(/[?&]v=([^&]+)/);
                                if (match && match[1]) cachedVideoId = match[1];
                            } catch(e) {}
                        }

                        if ((!cachedArtwork || cachedArtwork.indexOf('data:') === 0) && cachedVideoId) {
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
                    
                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({
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
                        isRepeat: cachedRepeat
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

            function enforceHighAudioQuality() {
                try {
                    var player = document.querySelector('ytmusic-player')?.playerApi || document.getElementById('movie_player');
                    if (player) {
                        if (typeof player.setAudioQuality === 'function') {
                            player.setAudioQuality('AUDIO_QUALITY_HIGH');
                        }
                        if (typeof player.setOption === 'function') {
                            player.setOption('audio', 'quality', 'AUDIO_QUALITY_HIGH');
                            player.setOption('audio', 'audioQuality', 'AUDIO_QUALITY_HIGH');
                        }
                    }
                } catch(e) {}
            }

            function enforceSongMode() {
                try {
                    var toggle = document.querySelector('ytmusic-av-toggle');
                    if (!toggle) return;
                    var mode = toggle.getAttribute('playback-mode') || '';
                    if (mode !== 'OMV_PREFERRED') return;
                    var vid = "";
                    try {
                        var player = document.querySelector('#movie_player');
                        if (player && typeof player.getVideoData === 'function') {
                            var d = player.getVideoData();
                            if (d && d.video_id) vid = d.video_id;
                        }
                    } catch(e) {}
                    if (!vid) {
                        var m = window.location.href.match(/[?&]v=([^&]+)/);
                        if (m && m[1]) vid = m[1];
                    }
                    if (!vid) vid = cachedTitle || "";
                    if (!vid) return;
                    if (vid === lastSongModeAttemptID) return;
                    var songBtn = toggle.querySelector('button.song-button');
                    if (songBtn) {
                        lastSongModeAttemptID = vid;
                        songBtn.click();
                    }
                } catch(e) {}
            }

            function bindVideoEvents() {
                var video = document.querySelector('video');
                if (video) {
                    if (!video.ytmBound) {
                        video.ytmBound = true;
                        ['play', 'playing', 'pause', 'ended', 'ratechange', 'seeked', 'loadedmetadata', 'canplay'].forEach(function(evt) {
                            video.addEventListener(evt, function() {
                                enforceHighAudioQuality();
                                enforceSongMode();
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
                                try {
                                    window.webkit.messageHandlers.nowPlayingHandler.postMessage({
                                        event: 'videoEnded',
                                        videoId: cachedVideoId || ""
                                    });
                                } catch(e) {}
                            }
                        });
                        enforceHighAudioQuality();
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
            }, 3000);
            setInterval(bypassAdsAndPopups, 1000);
            setInterval(function() {
                var v = document.querySelector('video');
                if (v && !v.paused && !v.ended) {
                    updateNowPlaying(false);
                }
            }, 1000);
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
            if repeatMode == .one {
                seek(to: 0.0)
                play()
                return
            }
            if PlaylistManager.shared.hasActiveContext {
                if PlaylistManager.shared.playNextTrackInPlaylist() {
                    return
                }
            }
            return
        }

        let isPlaying = (dict["isPlaying"] as? Bool) ?? false
        let title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

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
        
        let trackChanged = (!title.isEmpty && title != "Not Playing" && msgTrackID != currentVideoId)
        
        if trackChanged {
            currentVideoId = msgTrackID
            currentTime = 0.0
            lastTrackChangeTime = CACurrentMediaTime()
        } else if !msgTrackID.isEmpty && msgTrackID != currentVideoId {
            // Reject stale updates from previous track
            return
        }
        
        let jsReportedLiked = (dict["isLiked"] as? Bool) ?? false

        var effectiveLiked = jsReportedLiked
        if engineMode == .online, !LikedSongsManager.shared.isSignedIn, !videoId.isEmpty {
            effectiveLiked = LikedSongsManager.shared.isLiked(videoId: videoId)
        }
        
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
            isRepeatOn: isRepeatOn
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
