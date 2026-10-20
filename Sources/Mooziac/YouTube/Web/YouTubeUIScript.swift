import Foundation
import WebKit

public enum YouTubeUIScript {
    /// Clean, non-intrusive styling matching Kaset: preserves 100% of YouTube's natural player compositing,
    /// ensures popped-out miniplayer is always visible in front, and hides pause overlay suggestions.
    public static let uiStyleScript = WKUserScript(
        source: """
        (function() {
            var css = `
                /* Ambient mode (cinematics): continuous blurred WebGL canvas costs CPU/GPU, so turn it off */
                #cinematics,
                #cinematics-container,
                ytd-cinematic-container-renderer {
                    display: none !important;
                }

                /* Force dedicated GPU hardware-composited layer for HTML5 video (direct-to-display) */
                #movie_player video,
                .html5-main-video {
                    transform: translateZ(0) !important;
                    will-change: transform !important;
                    backface-visibility: hidden !important;
                }

                /* Keep YouTube's own pause overlay cards, endscreen, teasers and suggestions hidden without blocking video clicks */
                .ytp-pause-overlay,
                .ytp-pause-overlay-container,
                .ytp-scroll-min.ytp-pause-overlay,
                .ytp-endscreen-content,
                .ytp-ce-element,
                .ytp-cards-teaser,
                .ytp-expand-pause-overlay,
                .ytp-suggestion-set {
                    display: none !important;
                    pointer-events: none !important;
                }

                /* Ensure popped-out miniplayer is always visible, interactive and in front */
                ytd-miniplayer {
                    z-index: 9999 !important;
                }
                ytd-miniplayer[active] {
                    visibility: visible !important;
                    opacity: 1 !important;
                    display: block !important;
                }

                /* Keep captions cleanly pinned near bottom */
                .caption-window.ytp-caption-window-bottom {
                    bottom: 5% !important;
                }

                /* Mooziac Edge-to-Edge Fullscreen cinematic layout */
                html.mooziac-fullscreen,
                body.mooziac-fullscreen {
                    overflow: hidden !important;
                    background: #000 !important;
                }
                html.mooziac-fullscreen #masthead-container,
                html.mooziac-fullscreen #guide,
                html.mooziac-fullscreen #guide-wrapper,
                html.mooziac-fullscreen ytd-mini-guide-renderer,
                html.mooziac-fullscreen #secondary,
                html.mooziac-fullscreen #below,
                html.mooziac-fullscreen #comments,
                html.mooziac-fullscreen ytd-comments {
                    display: none !important;
                }
                html.mooziac-fullscreen ytd-app {
                    overflow: hidden !important;
                }
                html.mooziac-fullscreen #page-manager {
                    margin: 0 !important;
                    padding: 0 !important;
                    overflow: hidden !important;
                }
                html.mooziac-fullscreen ytd-watch-flexy {
                    padding: 0 !important;
                    margin: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    max-height: 100vh !important;
                }
                html.mooziac-fullscreen #columns,
                html.mooziac-fullscreen #primary,
                html.mooziac-fullscreen #primary-inner {
                    padding: 0 !important;
                    margin: 0 !important;
                    max-width: 100vw !important;
                    width: 100vw !important;
                    height: 100vh !important;
                }
                html.mooziac-fullscreen #player-theater-container,
                html.mooziac-fullscreen #full-bleed-container,
                html.mooziac-fullscreen #player-container-outer,
                html.mooziac-fullscreen #player-container-inner,
                html.mooziac-fullscreen #player-container {
                    width: 100vw !important;
                    height: 100vh !important;
                    max-height: 100vh !important;
                    max-width: 100vw !important;
                    min-height: 100vh !important;
                }
                html.mooziac-fullscreen #movie_player {
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    z-index: 999999 !important;
                }
                html.mooziac-fullscreen .html5-video-container {
                    width: 100vw !important;
                    height: 100vh !important;
                }
                html.mooziac-fullscreen #movie_player video {
                    top: 0 !important;
                    left: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    object-fit: contain !important;
                }
            `;
            var style = document.createElement('style');
            style.type = 'text/css';
            style.id = 'mooziac-ui-styles';
            style.appendChild(document.createTextNode(css));
            (document.head || document.documentElement).appendChild(style);
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    /// Injected JavaScript:
    /// 1. Authoritative Space key handler:
    ///    - Cancels WebKit default Page Down scroll so video never scrolls off into grey void.
    ///    - Uses stopImmediatePropagation() so other listeners don't double-toggle playback.
    ///    - Preserves normal Space typing in search and comment input boxes.
    /// 2. Ensures popped-out miniplayer reliably opens in front when navigating away from /watch.
    public static let uiControllerScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacUIInjected) return;
            window.__mooziacUIInjected = true;

            // Ensure dark mode is active on documentElement
            try {
                document.documentElement.setAttribute('dark', 'true');
            } catch(e) {}

            function isEditable(el) {
                if (!el) return false;
                if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable === true) return true;
                if (el.closest && el.closest('input, textarea, select, [contenteditable="true"]')) return true;
                if (el.shadowRoot && el.shadowRoot.activeElement) {
                    return isEditable(el.shadowRoot.activeElement);
                }
                return false;
            }

            // Space key handler. YouTube toggles playback on Space KEYUP (it uses press-and-hold
            // for 2x speed), so swallowing only keydown made the video pause and then instantly
            // resume. We now own keydown, keypress AND keyup for Space, and ignore key repeat.
            function handleSpace(e) {
                if (!(e.keyCode === 32 || e.key === ' ' || e.code === 'Space')) return;
                if (e.metaKey || e.ctrlKey || e.altKey) return;
                var el = document.activeElement;
                if (isEditable(el)) return; // Typing in search bar or comment box, don't intercept

                // Stop browser Page Down scroll AND YouTube's own Space handler
                e.preventDefault();
                e.stopImmediatePropagation();

                if (e.type === 'keydown' && !e.repeat) {
                    if (window.__mooziacPlayer && typeof window.__mooziacPlayer.togglePlayPause === 'function') {
                        window.__mooziacPlayer.togglePlayPause();
                    }
                }
            }
            window.addEventListener('keydown', handleSpace, true);
            window.addEventListener('keypress', handleSpace, true);
            window.addEventListener('keyup', handleSpace, true);

            // Distraction-Free Focus Mode: hides comments and recommendations rail
            window.__mooziacSetDistractionFree = function(enabled) {
                window.__mooziacDistractionFreeActive = !!enabled;
                var existing = document.getElementById('mooziac-focus-mode-style');
                if (enabled) {
                    if (!existing) {
                        var style = document.createElement('style');
                        style.id = 'mooziac-focus-mode-style';
                        style.type = 'text/css';
                        style.textContent = `
                            #comments,
                            ytd-comments,
                            #related,
                            ytd-watch-next-secondary-results-renderer,
                            #chat,
                            #chat-container,
                            ytd-live-chat-frame {
                                display: none !important;
                            }
                            #primary.ytd-watch-flexy {
                                max-width: 100% !important;
                                margin: 0 auto !important;
                            }
                        `;
                        (document.head || document.documentElement).appendChild(style);
                    }
                } else {
                    if (existing) existing.remove();
                }
            };

            // Check if focus mode should be active
            if (window.__mooziacDistractionFreeActive) {
                window.__mooziacSetDistractionFree(true);
            }

            document.addEventListener('yt-navigate-finish', function() {
                if (window.__mooziacDistractionFreeActive) {
                    window.__mooziacSetDistractionFree(true);
                }
            });

            // Used by the logo click below AND by the native Back button: when a video is playing
            // on /watch, let YouTube's own miniplayer button do the leaving. It opens the miniplayer
            // and navigates away in ONE step, so there is no race and no background audio.
            // Returns true if it took over the navigation.
            window.__mooziacMinimizeToMiniplayer = function() {
                try {
                    if (window.location.pathname.indexOf('/watch') === -1) return false;
                    var player = document.getElementById('movie_player');
                    if (!player) return false;
                    var video = player.querySelector('video');
                    if (!video || video.paused || video.ended) return false;
                    var miniBtn = document.querySelector('.ytp-miniplayer-button');
                    if (!miniBtn) return false;
                    miniBtn.click();
                    return true;
                } catch(e) { return false; }
            };

            // Clicking the YouTube logo / home link while a video plays: go to home WITH the miniplayer
            document.addEventListener('click', function(e) {
                var logo = e.target && e.target.closest && (
                    e.target.closest('#logo') ||
                    e.target.closest('a#logo') ||
                    e.target.closest('ytd-topbar-logo-renderer') ||
                    e.target.closest('a[href="/"]')
                );
                if (logo && window.__mooziacMinimizeToMiniplayer()) {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                }
            }, true);
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )
}
