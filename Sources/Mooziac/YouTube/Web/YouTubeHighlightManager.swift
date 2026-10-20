import Foundation
import WebKit

public enum YouTubeHighlightManager {
    public static let highlightScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacHighlightInjected) return;
            window.__mooziacHighlightInjected = true;

            var currentVideoId = '';
            var bestPartTime = null;

            function formatTimestamp(seconds) {
                var s = Math.floor(seconds);
                var m = Math.floor(s / 60);
                var sec = s % 60;
                var secStr = sec < 10 ? '0' + sec : '' + sec;
                if (m >= 60) {
                    var h = Math.floor(m / 60);
                    var min = m % 60;
                    var minStr = min < 10 ? '0' + min : '' + min;
                    return h + ':' + minStr + ':' + secStr;
                }
                return m + ':' + secStr;
            }

            function postBridge(msg) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtubeBridge) {
                        window.webkit.messageHandlers.youtubeBridge.postMessage(msg);
                    }
                } catch(e) {}
            }

            function getVideoId() {
                try {
                    var url = new URL(window.location.href);
                    return url.searchParams.get('v') || '';
                } catch(e) {
                    return '';
                }
            }

            function getPlayer() {
                return document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            }

            function extractHeatmapPeak() {
                try {
                    var player = getPlayer();
                    var pData = (player && typeof player.getPlayerResponse === 'function') ? player.getPlayerResponse() : null;
                    var pr = pData || window.ytInitialPlayerResponse;
                    if (pr && pr.frameworkUpdates && pr.frameworkUpdates.entityBatchUpdate && pr.frameworkUpdates.entityBatchUpdate.mutations) {
                        var mutations = pr.frameworkUpdates.entityBatchUpdate.mutations;
                        for (var i = 0; i < mutations.length; i++) {
                            var payload = mutations[i].payload;
                            if (payload && payload.macroMarkersListEntity && payload.macroMarkersListEntity.markersList) {
                                var markers = payload.macroMarkersListEntity.markersList.markers || [];
                                var maxScore = -1;
                                var peak = null;
                                for (var m = 0; m < markers.length; m++) {
                                    var marker = markers[m];
                                    var score = marker.intensityScoreNormalized || 0;
                                    if (score > maxScore) {
                                        maxScore = score;
                                        peak = (marker.timeRangeStartMillis || 0) / 1000;
                                    }
                                }
                                if (peak !== null && maxScore > 0.1) {
                                    return peak;
                                }
                            }
                        }
                    }
                } catch(e) {}
                return null;
            }

            function checkHighlights(videoId) {
                if (!videoId) {
                    currentVideoId = '';
                    bestPartTime = null;
                    postBridge({ event: 'bestPartReset' });
                    return;
                }

                if (videoId === currentVideoId) return;
                currentVideoId = videoId;
                bestPartTime = null;
                postBridge({ event: 'bestPartReset' });

                // 1. ALWAYS check YouTube's native Most Replayed Heatmap peak first
                var peak = extractHeatmapPeak();
                if (peak !== null && peak > 1.0) {
                    bestPartTime = peak;
                    postBridge({
                        event: 'bestPartFound',
                        time: peak,
                        formattedTime: formatTimestamp(peak),
                        source: 'heatmap'
                    });
                    return;
                }

                // Poll YouTube player response for Heatmap peak
                var attempts = 0;
                var heatmapTimer = setInterval(function() {
                    if (bestPartTime !== null || videoId !== currentVideoId) {
                        clearInterval(heatmapTimer);
                        return;
                    }
                    attempts++;
                    var p = extractHeatmapPeak();
                    if (p !== null && p > 1.0) {
                        bestPartTime = p;
                        clearInterval(heatmapTimer);
                        postBridge({
                            event: 'bestPartFound',
                            time: p,
                            formattedTime: formatTimestamp(p),
                            source: 'heatmap'
                        });
                        return;
                    }
                    if (attempts >= 15) {
                        clearInterval(heatmapTimer);
                        // 2. Fall back to SponsorBlock POI only if no YouTube heatmap exists
                        if (bestPartTime === null) {
                            fetchSponsorBlockPOI(videoId);
                        }
                    }
                }, 300);
            }

            function fetchSponsorBlockPOI(videoId) {
                if (bestPartTime !== null || videoId !== currentVideoId) return;
                var sbUrl = 'https://sponsor.ajay.app/api/skipSegments?videoID=' + encodeURIComponent(videoId) + '&categories=' + encodeURIComponent(JSON.stringify(['poi_highlight']));
                fetch(sbUrl)
                    .then(function(res) { if (res.ok) return res.json(); throw new Error(); })
                    .then(function(data) {
                        if (bestPartTime !== null || videoId !== currentVideoId) return;
                        if (Array.isArray(data) && data.length > 0) {
                            var poi = data.find(function(d) { return d.category === 'poi_highlight'; }) || data[0];
                            if (poi && poi.segment && poi.segment.length > 0) {
                                var t = poi.segment[0];
                                if (t > 1.0) {
                                    bestPartTime = t;
                                    postBridge({
                                        event: 'bestPartFound',
                                        time: t,
                                        formattedTime: formatTimestamp(t),
                                        source: 'poi'
                                    });
                                }
                            }
                        }
                    })
                    .catch(function() {});
            }

            // Monitor video changes via media events instead of a 500ms poll
            document.addEventListener('loadedmetadata', function() {
                var vid = getVideoId();
                if (vid !== currentVideoId) {
                    checkHighlights(vid);
                }
            }, true);

            window.addEventListener('yt-navigate-finish', function() {
                var vid = getVideoId();
                checkHighlights(vid);
            });

            window.addEventListener('popstate', function() {
                var vid = getVideoId();
                checkHighlights(vid);
            });

            var initialVid = getVideoId();
            if (initialVid) {
                checkHighlights(initialVid);
            }
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    public static func configure(userContentController: WKUserContentController) {
        userContentController.addUserScript(highlightScript)
    }
}
