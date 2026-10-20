import Foundation
import WebKit

public enum YouTubeSponsorBlock {
    public static let sponsorBlockScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacSponsorBlockInjected) return;
            window.__mooziacSponsorBlockInjected = true;

            const API_ENDPOINT = 'https://sponsor.ajay.app/api/skipSegments';
            const CATEGORIES = JSON.stringify(['sponsor', 'intro', 'outro', 'selfpromo', 'interaction', 'preview']);

            let currentVideoId = '';
            let segments = [];
            let lastSkippedEnd = -1;
            let isFetching = false;

            function getVideoId() {
                try {
                    const url = new URL(window.location.href);
                    return url.searchParams.get('v') || '';
                } catch(e) {
                    return '';
                }
            }

            function fetchSegments(videoId) {
                if (!videoId || videoId === currentVideoId || isFetching) return;
                currentVideoId = videoId;
                segments = [];
                lastSkippedEnd = -1;
                isFetching = true;

                const queryUrl = API_ENDPOINT + '?videoID=' + encodeURIComponent(videoId) + '&categories=' + encodeURIComponent(CATEGORIES);

                fetch(queryUrl)
                    .then(function(res) {
                        if (!res.ok) throw new Error('Status ' + res.status);
                        return res.json();
                    })
                    .then(function(data) {
                        isFetching = false;
                        if (Array.isArray(data)) {
                            segments = data.map(function(item) {
                                return {
                                    start: item.segment[0],
                                    end: item.segment[1],
                                    category: item.category,
                                    UUID: item.UUID
                                };
                            });
                        }
                    })
                    .catch(function(err) {
                        isFetching = false;
                        segments = [];
                    });
            }

            function getCategoryDisplayName(cat) {
                switch(cat) {
                    case 'sponsor': return 'Sponsor';
                    case 'intro': return 'Intro / Intermission';
                    case 'outro': return 'Credits / Outro';
                    case 'selfpromo': return 'Self Promotion';
                    case 'interaction': return 'Subscribe Reminder';
                    case 'preview': return 'Preview';
                    default: return 'Sponsor';
                }
            }

            function checkAndSkip(video) {
                var player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                var isAd = player && player.classList && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'));
                if (isAd) return;

                if (!video || !segments.length || video.paused || video.readyState < 3) return;
                const time = video.currentTime;
                if (time < 0.8 && segments[0] && segments[0].start <= 0.1) return;

                for (let i = 0; i < segments.length; i++) {
                    const seg = segments[i];
                    // If video time is within the segment
                    if (time >= seg.start && time < (seg.end - 0.2)) {
                        if (Math.abs(lastSkippedEnd - seg.end) < 0.5) {
                            continue; // already skipped this exact segment
                        }
                        lastSkippedEnd = seg.end;
                        video.currentTime = seg.end;

                        const catName = getCategoryDisplayName(seg.category);

                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtubeBridge) {
                            window.webkit.messageHandlers.youtubeBridge.postMessage({
                                event: 'sponsorSkipped',
                                category: seg.category,
                                displayName: catName
                            });
                        }
                        break;
                    }
                }
            }

            // Event-driven (no polling timer): the browser fires timeupdate ~4x/second while playing
            // and nothing at all while paused. Media events don't bubble, so listen in capture phase.
            function sbTick() {
                const vid = getVideoId();
                if (vid && vid !== currentVideoId) {
                    fetchSegments(vid);
                }
                const video = document.querySelector('#movie_player video') || document.querySelector('video');
                if (video) {
                    checkAndSkip(video);
                }
            }
            document.addEventListener('timeupdate', sbTick, true);
            document.addEventListener('loadedmetadata', sbTick, true);

            // Listen to SPA navigation
            window.addEventListener('yt-navigate-finish', function() {
                const vid = getVideoId();
                if (vid) {
                    fetchSegments(vid);
                }
            });

            // Initial trigger
            const initialId = getVideoId();
            if (initialId) {
                fetchSegments(initialId);
            }
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    public static func configure(userContentController: WKUserContentController) {
        guard AppSettings.shared.isSponsorBlockEnabled else {
            Log.app.info("SponsorBlock is disabled by user settings")
            return
        }
        userContentController.addUserScript(sponsorBlockScript)
    }
}
