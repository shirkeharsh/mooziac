import Foundation
import WebKit

public protocol YouTubePlayerBridgeDelegate: AnyObject {
    func bridgeDidUpdatePlaybackState(_ state: VideoPlaybackState)
    func bridgeDidChangeEditableFocus(isEditable: Bool)
}

public final class YouTubePlayerBridge: NSObject, WKScriptMessageHandler {
    public weak var delegate: YouTubePlayerBridgeDelegate?

    public static let handlerName = "youtubeBridge"

    /// The observer script injected into YouTube pages
    public static let observerScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacObserverInjected) return;
            window.__mooziacObserverInjected = true;

            function isEditable(el) {
                if (!el) return false;
                if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable === true) return true;
                if (el.closest && el.closest('input, textarea, select, [contenteditable="true"]')) return true;
                if (el.shadowRoot && el.shadowRoot.activeElement) {
                    return isEditable(el.shadowRoot.activeElement);
                }
                return false;
            }

            function postBridge(msg) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtubeBridge) {
                        window.webkit.messageHandlers.youtubeBridge.postMessage(msg);
                    }
                } catch(e) {}
            }

            // Capture unhandled page errors for logging
            window.addEventListener('error', function(e) {
                if (e.target && e.target.tagName === 'VIDEO') {
                    var video = e.target;
                    var err = video.error;
                    postBridge({
                        event: 'videoMediaError',
                        code: err ? err.code : 0,
                        message: err ? err.message : 'Unknown video element error'
                    });
                } else if (e.message) {
                    postBridge({
                        event: 'consoleError',
                        message: e.message
                    });
                }
            }, true);

            var hookAttempts = 0;
            var hookTimer = setInterval(function() {
                var p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.addEventListener === 'function' && !p.__mooziacErrorHooked) {
                    p.__mooziacErrorHooked = true;
                    p.addEventListener('onError', function(code) {
                        postBridge({
                            event: 'youtubePlayerError',
                            code: code
                        });
                    });
                    clearInterval(hookTimer);
                }
                hookAttempts++;
                if (hookAttempts > 30) clearInterval(hookTimer);
            }, 1000);

            document.addEventListener('focusin', function(e) {
                if (isEditable(e.target)) {
                    postBridge({ event: 'focusChanged', isEditable: true });
                }
            }, true);

            document.addEventListener('focusout', function(e) {
                setTimeout(function() {
                    postBridge({ event: 'focusChanged', isEditable: isEditable(document.activeElement) });
                }, 0);
            }, true);

            document.addEventListener('click', function(e) {
                var targetIsEditable = isEditable(e.target);
                if (!targetIsEditable) {
                    var active = document.activeElement;
                    if (active && isEditable(active) && active !== e.target) {
                        try { active.blur(); } catch(err) {}
                    }
                }
                setTimeout(function() {
                    postBridge({ event: 'focusChanged', isEditable: isEditable(document.activeElement) });
                }, 30);
            }, true);

            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' || e.keyCode === 27) {
                    var active = document.activeElement;
                    if (active && isEditable(active)) {
                        try { active.blur(); } catch(err) {}
                        postBridge({ event: 'focusChanged', isEditable: false });
                    }
                }
            }, true);

            window.addEventListener('yt-navigate-finish', function() {
                postBridge({ event: 'focusChanged', isEditable: false });
            });

            function getPlayer() {
                return document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            }

            var lastReportTime = 0;
            var lastState = {};
            window.__mooziacTargetSpeed = window.__mooziacTargetSpeed || 1.0;

            function pollPlayerState() {
                var player = getPlayer();
                var video = document.querySelector('video');
                if (!video) return;

                var isPlaying = !video.paused && !video.ended && video.readyState >= 2;
                var currentTime = video.currentTime || 0;
                var duration = video.duration || 0;
                var volume = video.volume;
                var isMuted = video.muted;
                var playbackRate = video.playbackRate || 1.0;
                if (player && typeof player.getPlaybackRate === 'function') {
                    try { playbackRate = player.getPlaybackRate(); } catch(e) {}
                }

                // If user selected a custom target speed, keep it synced if YouTube desynced
                var isAd = false;
                if (player && player.classList) {
                    if (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting')) {
                        isAd = true;
                    }
                }

                if (!isAd && window.__mooziacTargetSpeed && Math.abs(playbackRate - window.__mooziacTargetSpeed) > 0.02) {
                    if (player && typeof player.setPlaybackRate === 'function') {
                        try { player.setPlaybackRate(window.__mooziacTargetSpeed); } catch(e) {}
                    }
                }

                var title = "";
                var channel = "";
                var videoId = "";
                if (player && typeof player.getVideoData === 'function') {
                    try {
                        var vdata = player.getVideoData();
                        if (vdata) {
                            title = vdata.title || "";
                            channel = vdata.author || "";
                            videoId = vdata.video_id || "";
                            if (vdata.isAd) isAd = true;
                        }
                    } catch(e) {}
                }

                if (!title) {
                    var titleEl = document.querySelector('h1.ytd-watch-metadata yt-formatted-string') ||
                                  document.querySelector('h1.title yt-formatted-string') ||
                                  document.querySelector('#title h1');
                    if (titleEl) title = (titleEl.textContent || "").trim();
                }

                var quality = "auto";
                var availableQualities = [];
                if (player) {
                    try {
                        if (typeof player.getPlaybackQuality === 'function') {
                            quality = player.getPlaybackQuality();
                        }
                        if (typeof player.getAvailableQualityLevels === 'function') {
                            availableQualities = player.getAvailableQualityLevels();
                        }
                    } catch(e) {}
                }

                var isPiP = document.pictureInPictureElement !== null || video.webkitPresentationMode === 'picture-in-picture';
                var isFullscreen = document.fullscreenElement !== null || (player && player.classList.contains('ytp-fullscreen'));

                var now = Date.now();
                var timeDelta = Math.abs(currentTime - (lastState.currentTime || 0));
                var stateChanged = (isPlaying !== lastState.isPlaying) ||
                                   (isAd !== lastState.isAd) ||
                                   (title !== lastState.title) ||
                                   (quality !== lastState.quality) ||
                                   (isMuted !== lastState.isMuted) ||
                                   (timeDelta >= 0.5) ||
                                   (now - lastReportTime > 1000);

                if (stateChanged) {
                    lastReportTime = now;
                    lastState = {
                        isPlaying: isPlaying,
                        currentTime: currentTime,
                        duration: duration,
                        title: title,
                        channel: channel,
                        videoId: videoId,
                        quality: quality,
                        availableQualities: availableQualities,
                        isAd: isAd,
                        volume: volume,
                        isMuted: isMuted,
                        playbackRate: playbackRate,
                        isPiP: isPiP,
                        isFullscreen: isFullscreen
                    };

                    postBridge({
                        event: 'playbackState',
                        isPlaying: isPlaying,
                        currentTime: currentTime,
                        duration: duration,
                        title: title,
                        channel: channel,
                        videoId: videoId,
                        quality: quality,
                        availableQualities: availableQualities,
                        isAd: isAd,
                        volume: volume,
                        isMuted: isMuted,
                        playbackRate: playbackRate,
                        isPiP: isPiP,
                        isFullscreen: isFullscreen
                    });
                }
            }

            // Event-driven state reporting. No 250ms timer: media events fire only when something
            // happens (timeupdate ~4x/s while playing, nothing while paused or idle).
            var lastPollRun = 0;
            function throttledPoll() {
                var now = Date.now();
                if (now - lastPollRun < 200) return;
                lastPollRun = now;
                pollPlayerState();
            }
            ['play','playing','pause','timeupdate','ratechange','volumechange','ended','loadedmetadata','seeked','durationchange'].forEach(function(evt) {
                document.addEventListener(evt, throttledPoll, true);
            });
            document.addEventListener('fullscreenchange', throttledPoll, true);
            document.addEventListener('enterpictureinpicture', throttledPoll, true);
            document.addEventListener('leavepictureinpicture', throttledPoll, true);
            window.addEventListener('yt-navigate-finish', function() { setTimeout(throttledPoll, 300); });
            // Slow safety net for things that change without a media event (title, quality list, ad state)
            setInterval(pollPlayerState, 2000);

            // Background playback guard: if the main player is playing but is NOT visible
            // (hidden watch page, no miniplayer), it is audio leaking in the background.
            // Pause it so it can never keep playing invisibly.
            var invisibleSince = 0;
            function backgroundGuard() {
                var player = document.getElementById('movie_player');
                if (!player) { invisibleSince = 0; return; }
                var video = player.querySelector('video');
                if (!video || video.paused || video.ended) { invisibleSince = 0; return; }

                var rects = player.getClientRects();
                var visible = rects.length > 0 && rects[0].width > 1 && rects[0].height > 1;
                if (visible || document.fullscreenElement) { invisibleSince = 0; return; }

                var now = Date.now();
                if (!invisibleSince) { invisibleSince = now; return; }
                if (now - invisibleSince > 900) {
                    invisibleSince = 0;
                    window.__mooziacUserPaused = true;
                    try { video.pause(); } catch(e) {}
                    if (typeof player.pauseVideo === 'function') { try { player.pauseVideo(); } catch(e) {} }
                }
            }
            // Event-driven guard: it can only matter while something is playing, and a playing video
            // fires timeupdate, so no timer is needed. Throttled to once per second (it reads layout).
            var lastGuardRun = 0;
            function throttledGuard() {
                var now = Date.now();
                if (now - lastGuardRun < 1000) return;
                lastGuardRun = now;
                backgroundGuard();
            }
            document.addEventListener('timeupdate', throttledGuard, true);
            document.addEventListener('playing', throttledGuard, true);
            window.addEventListener('yt-navigate-finish', function() { setTimeout(throttledGuard, 1500); });
            window.addEventListener('popstate', function() { setTimeout(throttledGuard, 1500); });
            window.addEventListener('yt-navigate-finish', function() { invisibleSince = 0; });
            // Starting a new navigation (new video chosen) clears any earlier manual pause
            window.addEventListener('yt-navigate-start', function() { window.__mooziacUserPaused = false; });

            // HTML5 Fullscreen API polyfill: bridges YouTube's player fullscreen triggers directly to native macOS window fullscreen
            try {
                Object.defineProperty(document, 'fullscreenEnabled', {
                    get: function() { return true; },
                    configurable: true
                });
                Object.defineProperty(document, 'webkitFullscreenEnabled', {
                    get: function() { return true; },
                    configurable: true
                });
                Object.defineProperty(document, 'fullscreenElement', {
                    get: function() {
                        return window.__mooziacIsFullscreen ? (document.getElementById('movie_player') || document.querySelector('video') || document.body) : null;
                    },
                    configurable: true
                });
                Object.defineProperty(document, 'webkitFullscreenElement', {
                    get: function() {
                        return window.__mooziacIsFullscreen ? (document.getElementById('movie_player') || document.querySelector('video') || document.body) : null;
                    },
                    configurable: true
                });
            } catch(e) {}

            Element.prototype.requestFullscreen = function() {
                postBridge({ event: 'toggleFullscreen', wantsFullscreen: true });
                return Promise.resolve();
            };
            Element.prototype.webkitRequestFullscreen = function() {
                postBridge({ event: 'toggleFullscreen', wantsFullscreen: true });
                return Promise.resolve();
            };
            document.exitFullscreen = function() {
                postBridge({ event: 'toggleFullscreen', wantsFullscreen: false });
                return Promise.resolve();
            };
            document.webkitExitFullscreen = function() {
                postBridge({ event: 'toggleFullscreen', wantsFullscreen: false });
                return Promise.resolve();
            };

            // Catch native player fullscreen button clicks directly
            document.addEventListener('click', function(e) {
                var btn = e.target && e.target.closest && e.target.closest('.ytp-fullscreen-button');
                if (btn) {
                    postBridge({ event: 'toggleFullscreen' });
                }
            }, true);

            window.__mooziacSetFullscreenState = function(isFullscreen) {
                window.__mooziacIsFullscreen = !!isFullscreen;
                var html = document.documentElement;
                var body = document.body;
                var player = getPlayer();

                if (isFullscreen) {
                    if (html) html.classList.add('mooziac-fullscreen');
                    if (body) body.classList.add('mooziac-fullscreen');
                    if (player) player.classList.add('ytp-fullscreen');
                } else {
                    if (html) html.classList.remove('mooziac-fullscreen');
                    if (body) body.classList.remove('mooziac-fullscreen');
                    if (player) player.classList.remove('ytp-fullscreen');
                }

                try {
                    var evt = new Event('fullscreenchange', { bubbles: true, cancelable: false });
                    document.dispatchEvent(evt);
                    var wevt = new Event('webkitfullscreenchange', { bubbles: true, cancelable: false });
                    document.dispatchEvent(wevt);
                } catch(e) {}

                window.dispatchEvent(new Event('resize'));
            };

            // Public controller API callable from Swift
            window.__mooziacPlayer = {
                play: function() {
                    window.__mooziacUserPaused = false;
                    var v = document.querySelector('#movie_player video') || document.querySelector('video');
                    var p = getPlayer();
                    if (v) { try { v.play(); } catch(e) {} }
                    if (p && typeof p.playVideo === 'function') { try { p.playVideo(); } catch(e) {} }
                },
                pause: function() {
                    window.__mooziacUserPaused = true;
                    var v = document.querySelector('#movie_player video') || document.querySelector('video');
                    var p = getPlayer();
                    if (v) { try { v.pause(); } catch(e) {} }
                    if (p && typeof p.pauseVideo === 'function') { try { p.pauseVideo(); } catch(e) {} }
                },
                // The ONE place that toggles playback. Every path (Space key, K key, menu,
                // media keys, trackpad gesture) ends up here, and a global debounce makes
                // sure two near-simultaneous triggers can never cancel each other out.
                togglePlayPause: function() {
                    var now = Date.now();
                    if (window.__mooziacLastToggle && now - window.__mooziacLastToggle < 150) return;
                    window.__mooziacLastToggle = now;

                    var video = document.querySelector('#movie_player video') || document.querySelector('video');
                    var p = getPlayer();
                    if (!video && !p) return;

                    var isPaused = video ? video.paused : false;
                    if (p && typeof p.getPlayerState === 'function') {
                        try {
                            var st = p.getPlayerState();
                            isPaused = (st !== 1 && st !== 3);
                        } catch(e) {}
                    }

                    if (isPaused) {
                        window.__mooziacUserPaused = false;
                        if (video) { try { video.play(); } catch(e) {} }
                        if (p && typeof p.playVideo === 'function') { try { p.playVideo(); } catch(e) {} }
                    } else {
                        window.__mooziacUserPaused = true;
                        if (video) { try { video.pause(); } catch(e) {} }
                        if (p && typeof p.pauseVideo === 'function') { try { p.pauseVideo(); } catch(e) {} }
                    }
                },
                seekTo: function(sec) {
                    var p = getPlayer();
                    if (p && typeof p.seekTo === 'function') p.seekTo(sec, true);
                    else { var v = document.querySelector('video'); if (v) v.currentTime = sec; }
                },
                seekBy: function(delta) {
                    var v = document.querySelector('video');
                    if (v) {
                        var target = Math.max(0, Math.min(v.duration || 999999, v.currentTime + delta));
                        var p = getPlayer();
                        if (p && typeof p.seekTo === 'function') p.seekTo(target, true);
                        else v.currentTime = target;
                    }
                },
                setVolume: function(vol) {
                    var v = document.querySelector('video');
                    if (v) v.volume = Math.max(0, Math.min(1, vol));
                    var p = getPlayer();
                    if (p && typeof p.setVolume === 'function') p.setVolume(Math.round(vol * 100));
                },
                toggleMute: function() {
                    var v = document.querySelector('video');
                    if (v) v.muted = !v.muted;
                    var p = getPlayer();
                    if (p) {
                        if (typeof p.isMuted === 'function' && p.isMuted()) {
                            if (typeof p.unMute === 'function') p.unMute();
                        } else if (typeof p.mute === 'function') {
                            p.mute();
                        }
                    }
                },
                togglePiP: function() {
                    var v = document.querySelector('#movie_player video') || document.querySelector('.html5-video-player video') || document.querySelector('video');
                    if (v && v.webkitSetPresentationMode) {
                        try {
                            var currentMode = v.webkitPresentationMode;
                            v.webkitSetPresentationMode(currentMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture');
                            return;
                        } catch(e) {}
                    }
                    if (document.pictureInPictureElement) {
                        try { document.exitPictureInPicture(); return; } catch(e) {}
                    }
                    var miniBtn = document.querySelector('.ytp-miniplayer-button');
                    if (miniBtn) {
                        miniBtn.click();
                        return;
                    }
                    if (v && v.requestPictureInPicture) {
                        v.requestPictureInPicture().catch(function() {});
                    }
                },
                toggleTheater: function() {
                    var btn = document.querySelector('.ytp-size-button');
                    if (btn) btn.click();
                },
                toggleFullscreen: function() {
                    postBridge({ event: 'toggleFullscreen' });
                },
                nextVideo: function() {
                    var btn = document.querySelector('.ytp-next-button');
                    if (btn) btn.click();
                },
                prevVideo: function() {
                    var btn = document.querySelector('.ytp-prev-button');
                    if (btn) btn.click();
                },
                setPlaybackRate: function(rate) {
                    window.__mooziacTargetSpeed = rate;
                    var p = getPlayer();
                    if (p && typeof p.setPlaybackRate === 'function') {
                        try { p.setPlaybackRate(rate); } catch(e) {}
                    }
                    var v = document.querySelector('#movie_player video') || document.querySelector('video');
                    if (v) {
                        try { v.playbackRate = rate; } catch(e) {}
                    }
                },
                toggleSubtitles: function() {
                    var p = getPlayer();
                    if (p && typeof p.toggleSubtitles === 'function') {
                        try { p.toggleSubtitles(); return; } catch(e) {}
                    }
                    var ccBtn = document.querySelector('.ytp-subtitles-button');
                    if (ccBtn) {
                        ccBtn.click();
                    }
                }
            };

            window.addEventListener('yt-navigate-finish', function() {
                if (window.__mooziacTargetSpeed && window.__mooziacTargetSpeed !== 1.0) {
                    setTimeout(function() {
                        var p = getPlayer();
                        if (p && typeof p.setPlaybackRate === 'function') {
                            try { p.setPlaybackRate(window.__mooziacTargetSpeed); } catch(e) {}
                        }
                    }, 400);
                }
            });
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.handlerName,
              let dict = message.body as? [String: Any],
              let event = dict["event"] as? String else { return }

        if event == "consoleError" {
            let msg = dict["message"] as? String ?? ""
            Log.web.error("YouTube JS Error: \(msg, privacy: .public)")
            return
        }

        if event == "videoMediaError" {
            let code = dict["code"] as? Int ?? 0
            let msg = dict["message"] as? String ?? ""
            Log.web.error("HTML5 Video Media Error: code \(code), \(msg, privacy: .public)")
            return
        }

        if event == "youtubePlayerError" {
            let code = dict["code"] as? Int ?? 0
            Log.web.error("YouTube Player Error code: \(code)")
            return
        }

        if event == "focusChanged" {
            let isEditable = dict["isEditable"] as? Bool ?? false
            delegate?.bridgeDidChangeEditableFocus(isEditable: isEditable)
            return
        }

        if event == "performWindowDrag" {
            DispatchQueue.main.async {
                if let window = NSApp.keyWindow ?? NSApp.mainWindow,
                   let currentEvent = NSApp.currentEvent {
                    window.performDrag(with: currentEvent)
                }
            }
            return
        }

        if event == "toggleFullscreen" {
            let wantsFullscreen = dict["wantsFullscreen"] as? Bool
            DispatchQueue.main.async {
                MainVideoWindowController.shared.handleBridgeFullscreenRequest(wantsFullscreen: wantsFullscreen)
            }
            return
        }

        if event == "enterFullscreen" {
            DispatchQueue.main.async {
                MainVideoWindowController.shared.handleBridgeFullscreenRequest(wantsFullscreen: true)
            }
            return
        }

        if event == "exitFullscreen" {
            DispatchQueue.main.async {
                MainVideoWindowController.shared.handleBridgeFullscreenRequest(wantsFullscreen: false)
            }
            return
        }

        if event == "sponsorSkipped" {
            let displayName = dict["displayName"] as? String ?? "Sponsor"
            DispatchQueue.main.async {
                FloatingHUDWindowController.shared.showCustomTextOverlay(text: "Skipped \(displayName)")
            }
            return
        }

        if event == "bestPartFound" {
            let time = dict["time"] as? Double ?? 0.0
            let formatted = dict["formattedTime"] as? String ?? ""
            DispatchQueue.main.async {
                MainVideoWindowController.shared.updateBestPart(time: time, formattedTime: formatted)
            }
            return
        }

        if event == "bestPartReset" {
            DispatchQueue.main.async {
                MainVideoWindowController.shared.resetBestPart()
            }
            return
        }

        if event == "playbackState" {
            var state = VideoPlaybackState()
            state.isPlaying = dict["isPlaying"] as? Bool ?? false
            state.currentTime = dict["currentTime"] as? Double ?? 0.0
            state.duration = dict["duration"] as? Double ?? 0.0
            state.title = dict["title"] as? String ?? ""
            state.channel = dict["channel"] as? String ?? ""
            state.videoId = dict["videoId"] as? String ?? ""
            state.volume = Float(dict["volume"] as? Double ?? 1.0)
            state.isMuted = dict["isMuted"] as? Bool ?? false
            state.playbackRate = dict["playbackRate"] as? Double ?? 1.0
            state.isAdShowing = dict["isAd"] as? Bool ?? false
            state.isPictureInPicture = dict["isPiP"] as? Bool ?? false
            state.isFullscreen = dict["isFullscreen"] as? Bool ?? false

            let qStr = dict["quality"] as? String ?? "auto"
            state.currentQuality = VideoQuality(rawValue: qStr) ?? .auto

            let availList = dict["availableQualities"] as? [String] ?? []
            state.availableQualities = availList.compactMap { VideoQuality(rawValue: $0) }
            state.is4KAvailable = availList.contains("hd2160")
            state.is4KActive = (state.currentQuality == .uhd2160)

            YouTubeQualityManager.shared.updateFromWeb(current: qStr, available: availList)
            delegate?.bridgeDidUpdatePlaybackState(state)
        }
    }
}
