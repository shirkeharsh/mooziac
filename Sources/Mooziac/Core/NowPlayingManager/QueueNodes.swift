import Foundation

extension NowPlayingManager {
    /// JavaScript helper shared by every queue script.
    /// YouTube Music keeps the queue in the page even when its panel is not on screen
    /// (the compact player hides it), so we must not require the items to be visible.
    /// It picks the queue that is on screen if there is one, otherwise the biggest one.
    static let queueNodesHelperJS = """
    function mooziacQueueNodes() {
        function vis(n) {
            return !!n && document.body.contains(n) && (n.offsetWidth > 0 || n.offsetHeight > 0 || n.offsetParent !== null);
        }
        var all = Array.from(document.querySelectorAll('ytmusic-player-queue-item'));
        var groups = [];
        all.forEach(function(n) {
            var root = n.closest('ytmusic-player-queue') || document;
            var g = null;
            for (var i = 0; i < groups.length; i++) {
                if (groups[i].root === root) { g = groups[i]; break; }
            }
            if (!g) { g = { root: root, items: [] }; groups.push(g); }
            g.items.push(n);
        });
        var best = null;
        groups.forEach(function(g) {
            g.visible = g.items.filter(vis);
            g.score = g.visible.length * 1000 + g.items.length;
            if (!best || g.score > best.score) best = g;
        });
        if (!best) return [];
        return best.visible.length ? best.visible : best.items;
    }
    """

    /// Plays one song of the on-page queue by tapping its row the way a real click would.
    /// The video id is used to find the right row, so it still works if the list moved since it was read.
    func playQueueTarget(index: Int, videoId: String) {
        let safeID = String(videoId.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") })
        let js = """
        (function() {
            window.__mooziacAutoplayPending = true;
            window.__mooziacPlaybackSuppressed = false;
            window.__mooziacBlockAutoplay = false;
            window.__mooziacAutoplayAttempts = 0;
            if (window.__mooziacAudioOutput && typeof window.__mooziacAudioOutput.prepare === 'function') {
                window.__mooziacAudioOutput.prepare();
            }
            \(NowPlayingManager.queueNodesHelperJS)
            try {
                var wantedId = '\(safeID)';
                var idx = \(index);
                var nodes = mooziacQueueNodes();

                function extractVid(n) {
                    if (!n) return '';
                    try {
                        var dd = n.data ? (n.data.playlistPanelVideoRenderer || n.data) : null;
                        if (!dd && n.__data) dd = n.__data.data ? (n.__data.data.playlistPanelVideoRenderer || n.__data.data) : n.__data;
                        if (dd) {
                            if (dd.videoId) return dd.videoId;
                            if (dd.navigationEndpoint && dd.navigationEndpoint.watchEndpoint && dd.navigationEndpoint.watchEndpoint.videoId) {
                                return dd.navigationEndpoint.watchEndpoint.videoId;
                            }
                        }
                        var vid = n.getAttribute('video-id') || n.getAttribute('data-video-id') || n.getAttribute('data-id');
                        if (vid) return vid;
                        var a = n.querySelector('a[href*="v="]');
                        if (a) {
                            var m = a.getAttribute('href').match(/[?&]v=([A-Za-z0-9_-]{11})/);
                            if (m) return m[1];
                        }
                        var tm = (n.innerHTML || '').match(/\\/vi\\/([A-Za-z0-9_-]{11})\\//);
                        if (tm) return tm[1];
                    } catch(e) {}
                    return '';
                }

                function simulateClick(el) {
                    if (!el) return false;
                    var targets = [
                        el.querySelector('ytmusic-play-button-renderer #button'),
                        el.querySelector('ytmusic-play-button-renderer button'),
                        el.querySelector('ytmusic-play-button-renderer'),
                        el.querySelector('#play-button'),
                        el.querySelector('.play-button'),
                        el.querySelector('button'),
                        el.querySelector('tp-yt-paper-icon-button'),
                        el.querySelector('paper-icon-button'),
                        el.querySelector('.song-title'),
                        el.querySelector('.title'),
                        el.querySelector('a'),
                        el
                    ];
                    var clicked = false;
                    for (var i = 0; i < targets.length; i++) {
                        var t = targets[i];
                        if (t) {
                            try {
                                var opts = { bubbles: true, cancelable: true, composed: true, view: window };
                                t.dispatchEvent(new MouseEvent('mousedown', opts));
                                t.dispatchEvent(new MouseEvent('mouseup', opts));
                                t.dispatchEvent(new MouseEvent('click', opts));
                                if (typeof t.click === 'function') t.click();
                                clicked = true;
                            } catch(e) {}
                        }
                    }
                    if (typeof el.click === 'function') {
                        try { el.click(); clicked = true; } catch(e) {}
                    }
                    return clicked;
                }

                var target = null;
                if (wantedId) {
                    if (idx >= 0 && idx < nodes.length && extractVid(nodes[idx]) === wantedId) {
                        target = nodes[idx];
                    } else {
                        for (var i = 0; i < nodes.length; i++) {
                            if (extractVid(nodes[i]) === wantedId) { target = nodes[i]; break; }
                        }
                    }
                }
                if (!target && idx >= 0 && idx < nodes.length) target = nodes[idx];

                if (target) {
                    simulateClick(target);
                    return 'clicked';
                }

                if (wantedId) {
                    var app = document.querySelector('ytmusic-app');
                    if (app && typeof app.resolveCommand === 'function') {
                        app.resolveCommand({ watchEndpoint: { videoId: wantedId } });
                        return 'resolveCommand';
                    }
                }

                return 'no-target';
            } catch (e) {
                return 'error';
            }
        })();
        """
        evaluateJS(js)
    }
}
