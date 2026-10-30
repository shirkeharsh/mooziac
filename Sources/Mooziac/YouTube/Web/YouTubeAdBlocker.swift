import Foundation
import WebKit

public enum YouTubeAdBlocker {
    public static let ruleListIdentifier = "MooziacYouTubeAdBlockRules"

    /// Injected CSS to hide banner ads, companion cards, promo banners, overlay ads, and anti-adblock / interruption popups
    public static let adHidingCssScript = WKUserScript(
        source: """
        (function() {
            var css = `
                .video-ads,
                .ytp-ad-module,
                .ytp-ad-player-overlay,
                .ytp-ad-player-overlay-layout,
                #player-ads,
                ytd-promoted-sparkles-web-renderer,
                ytd-promoted-video-renderer,
                ytd-action-companion-ad-renderer,
                ytd-banner-promo-renderer,
                ytd-ad-slot-renderer,
                ytd-in-feed-ad-layout-renderer,
                #masthead-ad,
                /* Comprehensive YouTube interruption & anti-adblock popups/toasts */
                yt-notification-action-renderer,
                ytd-notification-action-renderer,
                tp-yt-paper-toast[data-mooziac-hidden],
                tp-yt-paper-dialog[data-mooziac-hidden],
                ytd-enforcement-message-view-model,
                yt-mealbar-promo-renderer,
                ytd-mealbar-promo-renderer,
                ytd-popup-container yt-notification-action-renderer,
                yt-toast,
                ytd-toast,
                [data-mooziac-hidden],
                tp-yt-iron-overlay-backdrop,
                iron-overlay-backdrop,
                .toast-button.style-scope.yt-notification-action-renderer,
                .paper-toast-open.yt-notification-action-renderer {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                    height: 0 !important;
                    min-height: 0 !important;
                    max-height: 0 !important;
                    width: 0 !important;
                    overflow: hidden !important;
                    position: absolute !important;
                    left: -9999px !important;
                }
            `;
            var style = document.createElement('style');
            style.type = 'text/css';
            style.id = 'mooziac-ad-hiding-styles';
            style.appendChild(document.createTextNode(css));
            (document.head || document.documentElement).appendChild(style);
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    /// Safe ad skipper & interruption dialog auto-dismiss:
    /// - Leaves JavaScript prototypes 100% pristine and un-tampered (so YouTube's iframe checks never detect an ad blocker).
    /// - Mutes audio and fast-forwards ads at 16x speed so they complete in ~200ms naturally.
    /// - Clicks YouTube's native skip buttons instantly.
    /// - Automatically dismisses any "Experiencing interruptions" dialog and resumes playback.
    /// - Never forcibly seeks currentTime, eliminating buffer starvation and repeated interruption popups.
    public static let instantSkipperScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacSkipperInjected) return;
            window.__mooziacSkipperInjected = true;

            function triggerClick(btn) {
                if (!btn) return false;
                try {
                    btn.click();
                    var ev = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
                    btn.dispatchEvent(ev);
                    return true;
                } catch(e) { return false; }
            }

            var wasAdPlaying = false;
            var mutedBeforeAd = false;

            function handleAds() {
                var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                var video = document.querySelector('video');
                if (!player || !video) return;

                var isAd = false;
                if (player.classList) {
                    if (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting')) {
                        isAd = true;
                    }
                }

                if (!isAd && typeof player.getVideoData === 'function') {
                    try {
                        var vdata = player.getVideoData();
                        if (vdata && vdata.isAd) isAd = true;
                    } catch(e) {}
                }

                if (isAd) {
                    if (!wasAdPlaying) { mutedBeforeAd = video.muted; }
                    wasAdPlaying = true;
                    // Instantly mute ad audio so user never hears ad blip
                    video.muted = true;

                    // Play ad at accelerated speed (8x) so it finishes in ~300ms naturally without decoder buffer starvation
                    video.playbackRate = 8.0;

                    // 1. Invoke native YouTube player skip method if available
                    if (typeof player.skipAd === 'function') {
                        try { player.skipAd(); } catch(e) {}
                    }

                    // 2. Click any skip button immediately
                    var skipSelectors = [
                        '.ytp-ad-skip-button-modern',
                        '.ytp-skip-ad-button',
                        '.ytp-ad-skip-button',
                        '.ytp-ad-skip-button-slot button',
                        '.ytp-ad-overlay-close-button',
                        '.ytp-ad-survey-close-button',
                        'button[class*="skip"]'
                    ];

                    for (var i = 0; i < skipSelectors.length; i++) {
                        var btns = player.querySelectorAll(skipSelectors[i]);
                        for (var j = 0; j < btns.length; j++) {
                            triggerClick(btns[j]);
                        }
                    }
                } else if (wasAdPlaying) {
                    // Ad concluded: cleanly restore user target speed, audio and playback
                    wasAdPlaying = false;
                    var targetSpeed = window.__mooziacTargetSpeed || 1.0;
                    if (typeof player.setPlaybackRate === 'function') {
                        try { player.setPlaybackRate(targetSpeed); } catch(e) {}
                    }
                    video.playbackRate = targetSpeed;
                    video.muted = mutedBeforeAd;
                    if (video.paused && !window.__mooziacUserPaused) {
                        video.play().catch(function() {});
                    }
                }
            }

            // 1. Attach MutationObserver directly to #movie_player
            function attachPlayerObserver() {
                var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (!player || player.__mooziacSkipperObserved) return;
                player.__mooziacSkipperObserved = true;

                var observer = new MutationObserver(function(mutations) {
                    for (var i = 0; i < mutations.length; i++) {
                        if (mutations[i].attributeName === 'class') {
                            handleAds();
                            break;
                        }
                    }
                });
                observer.observe(player, { attributes: true, attributeFilter: ['class'] });
            }

            // Look for player on load
            var checkCount = 0;
            var findTimer = setInterval(function() {
                var p = document.getElementById('movie_player');
                if (p) {
                    attachPlayerObserver();
                    clearInterval(findTimer);
                }
                checkCount++;
                if (checkCount > 50) clearInterval(findTimer);
            }, 200);

            // Hook SPA navigation to re-check player and ensure playback starts cleanly
            var lastNavTime = Date.now();
            window.addEventListener('yt-navigate-finish', function() {
                lastNavTime = Date.now();
                attachPlayerObserver();
                handleAds();
                var cleanupBackdrops = function() {
                    var backdrops = document.querySelectorAll('tp-yt-iron-overlay-backdrop, iron-overlay-backdrop');
                    for (var b = 0; b < backdrops.length; b++) {
                        backdrops[b].remove();
                    }
                };
                cleanupBackdrops();
                setTimeout(function() {
                    cleanupBackdrops();
                    // Only auto-start on a real watch page, never when leaving it (that revived
                    // the hidden player and caused background audio) and never after a user pause.
                    if (window.location.pathname.indexOf('/watch') !== 0 || window.__mooziacUserPaused) return;
                    var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                    if (player && typeof player.playVideo === 'function') {
                        player.playVideo();
                    }
                    var v = document.querySelector('#movie_player video') || document.querySelector('video');
                    if (v && v.paused) {
                        v.play().catch(function() {});
                    }
                }, 250);
                setTimeout(function() {
                    cleanupBackdrops();
                    // Only auto-start on a real watch page, never when leaving it (that revived
                    // the hidden player and caused background audio) and never after a user pause.
                    if (window.location.pathname.indexOf('/watch') !== 0 || window.__mooziacUserPaused) return;
                    var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                    if (player && typeof player.playVideo === 'function') {
                        player.playVideo();
                    }
                    var v = document.querySelector('#movie_player video') || document.querySelector('video');
                    if (v && v.paused) {
                        v.play().catch(function() {});
                    }
                }, 750);
            });

            // 2. Clear and permanently suppress any "Experiencing interruptions" dialogs and anti-adblock modals
            function dismissInterruption(node) {
                if (!node || node.nodeType !== 1) return;
                var text = (node.textContent || '').toLowerCase();
                var isInterruption = text.includes('interruption') ||
                                     text.includes('interruptions') ||
                                     text.includes('ad blocker') ||
                                     text.includes('ad blockers') ||
                                     text.includes('find out why') ||
                                     (node.tagName && (node.tagName.toLowerCase() === 'yt-notification-action-renderer' || node.tagName.toLowerCase() === 'ytd-notification-action-renderer'));

                if (isInterruption) {
                    node.style.setProperty('display', 'none', 'important');
                    node.style.setProperty('visibility', 'hidden', 'important');
                    try {
                        if (typeof node.close === 'function') node.close();
                        var dismissBtn = node.querySelector('button, [aria-label*="dismiss" i], tp-yt-paper-button, #dismiss-button');
                        if (dismissBtn) dismissBtn.click();
                        node.remove();
                    } catch(e) {}

                    var backdrops = document.querySelectorAll('tp-yt-iron-overlay-backdrop, iron-overlay-backdrop');
                    for (var b = 0; b < backdrops.length; b++) {
                        backdrops[b].remove();
                    }

                    var v = document.querySelector('video');
                    if (v && v.paused && !window.__mooziacUserPaused) {
                        v.play().catch(function() {});
                    }
                }
            }

            // Targeted popup / interruption observer:
            // Interruption dialogs, toasts and modals are inserted either as direct children of
            // <ytd-popup-container> or directly into document.body. They are never children of
            // video cards or grid items. Observing specific containers with shallow childList: true
            // completely eliminates thousands of redundant DOM node inspections and closest()
            // tree traversals during infinite scrolling.
            var POPUP_TAGS = {
                'TP-YT-PAPER-TOAST': 1,
                'TP-YT-PAPER-DIALOG': 1,
                'YT-NOTIFICATION-ACTION-RENDERER': 1,
                'YTD-NOTIFICATION-ACTION-RENDERER': 1,
                'YTD-ENFORCEMENT-MESSAGE-VIEW-MODEL': 1,
                'YT-MEALBAR-PROMO-RENDERER': 1,
                'YTD-MEALBAR-PROMO-RENDERER': 1,
                'YT-TOAST': 1,
                'YTD-TOAST': 1,
                'TP-YT-IRON-OVERLAY-BACKDROP': 1,
                'IRON-OVERLAY-BACKDROP': 1
            };

            function isInterruptionNode(node) {
                if (!node || node.nodeType !== 1) return false;
                var tag = node.tagName;
                if (POPUP_TAGS[tag]) return true;
                if (node.getAttribute) {
                    var role = node.getAttribute('role');
                    if (role === 'dialog' || role === 'alert') return true;
                }
                return false;
            }

            function processPopupCandidate(node) {
                if (!isInterruptionNode(node)) return;
                dismissInterruption(node);
            }

            function attachPopupObserver() {
                var popupContainer = document.querySelector('ytd-popup-container');
                if (popupContainer && !popupContainer.__mooziacObserved) {
                    popupContainer.__mooziacObserved = true;
                    var containerObserver = new MutationObserver(function(mutations) {
                        for (var i = 0; i < mutations.length; i++) {
                            var added = mutations[i].addedNodes;
                            for (var j = 0; j < added.length; j++) {
                                processPopupCandidate(added[j]);
                            }
                        }
                    });
                    containerObserver.observe(popupContainer, { childList: true });
                }

                // Shallow observer on document.body for top-level modals and ytd-popup-container insertion
                if (document.body && !document.body.__mooziacObserved) {
                    document.body.__mooziacObserved = true;
                    var bodyObserver = new MutationObserver(function(mutations) {
                        for (var i = 0; i < mutations.length; i++) {
                            var added = mutations[i].addedNodes;
                            for (var j = 0; j < added.length; j++) {
                                var el = added[j];
                                if (!el || el.nodeType !== 1) continue;
                                if (el.tagName === 'YTD-POPUP-CONTAINER') {
                                    attachPopupObserver();
                                } else if (isInterruptionNode(el)) {
                                    processPopupCandidate(el);
                                }
                            }
                        }
                    });
                    bodyObserver.observe(document.body, { childList: true });
                }
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', attachPopupObserver);
            } else {
                attachPopupObserver();
            }

            // Lightweight periodic safety net: checks popup container and body only (never deep grid subtrees)
            setInterval(function() {
                var container = document.querySelector('ytd-popup-container');
                if (container) {
                    for (var i = 0; i < container.children.length; i++) {
                        processPopupCandidate(container.children[i]);
                    }
                }
                var backdrops = document.querySelectorAll('tp-yt-iron-overlay-backdrop, iron-overlay-backdrop');
                for (var b = 0; b < backdrops.length; b++) {
                    backdrops[b].remove();
                }
            }, 3000);
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    public static func precompileRules() {
        // Handled cleanly via uBlock Origin Lite WebExtension
    }

    public static func configure(userContentController: WKUserContentController) {
        guard AppSettings.shared.isAdBlockEnabled else {
            Log.adblock.info("AdBlocker is disabled by user settings")
            return
        }

        userContentController.addUserScript(adHidingCssScript)
        userContentController.addUserScript(instantSkipperScript)
    }
}
