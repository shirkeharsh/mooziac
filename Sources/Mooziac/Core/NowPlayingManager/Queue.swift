import AppKit
import WebKit
import MediaPlayer

extension NowPlayingManager {
    public func fetchQueue(completion: @escaping ([QueueItemInfo]) -> Void) {
        let js = """
        (function() {
            function extractVideoId(node) {
                if (!node) return '';
                try {
                    var vid = node.getAttribute('video-id') || node.getAttribute('data-video-id') || node.getAttribute('data-id');
                    if (vid) return vid;
                    var a = node.querySelector('a[href*="v="]');
                    if (a) {
                        var m = a.getAttribute('href').match(/[?&]v=([A-Za-z0-9_-]{11})/);
                        if (m) return m[1];
                    }
                    var rli = node.querySelector('ytmusic-responsive-list-item-renderer');
                    if (rli) {
                        var rid = rli.getAttribute('data-id') || rli.getAttribute('data-video-id');
                        if (rid) return rid;
                    }
                    var ipr = node.querySelector('ytmusic-inline-playback-renderer');
                    if (ipr) {
                        var pvid = ipr.getAttribute('playback-video-id') || ipr.getAttribute('data-video-id');
                        if (pvid) return pvid;
                    }
                } catch(e) {}
                return '';
            }
            try {
                var res = [];
                var rawItems = [];
                
                // Priority 1: Query primary queue contents container
                var primaryContainer = document.querySelector('ytmusic-player-queue #contents') ||
                                       document.querySelector('#queue #contents') ||
                                       document.querySelector('ytmusic-player-queue');
                if (primaryContainer) {
                    rawItems = Array.from(primaryContainer.querySelectorAll('ytmusic-player-queue-item'));
                }
                if (!rawItems || rawItems.length === 0) {
                    rawItems = Array.from(document.querySelectorAll('ytmusic-player-queue-item'));
                }

                if (rawItems && rawItems.length > 0) {
                    var idx = 0;
                    var seenTitleArtist = {};
                    
                    for (var i = 0; i < rawItems.length; i++) {
                        var item = rawItems[i];
                        if (!document.body.contains(item)) continue;
                        
                        // Ignore hidden template duplicate nodes
                        var rect = item.getBoundingClientRect();
                        if (rect.width === 0 && rect.height === 0 && item.offsetParent === null) continue;
                        
                        var t = item.querySelector('.song-title, .title, [class*="title"]');
                        var a = item.querySelector('.byline, .artist, [class*="byline"]');
                        var sel = item.hasAttribute('selected') || item.classList.contains('selected') || item.getAttribute('play-button-state') === 'playing';
                        
                        if (t && t.textContent.trim()) {
                            var titleVal = t.textContent.trim();
                            var artistVal = a ? a.textContent.trim() : '';
                            var itemKey = titleVal.toLowerCase() + '___' + artistVal.toLowerCase();
                            
                            // Prevent duplicate entries across multiple DOM templates
                            if (seenTitleArtist[itemKey]) continue;
                            seenTitleArtist[itemKey] = true;
                            
                            // Include all tracks including selected (current playing) song
                            res.push({
                                index: idx,
                                title: titleVal,
                                artist: artistVal,
                                isSelected: !!sel,
                                videoId: extractVideoId(item)
                            });
                            idx++;
                        }
                    }
                }
                
                // Priority 2: Fallback to Polymer Data Model array if DOM nodes were empty
                if (res.length === 0) {
                    var q = document.querySelector('ytmusic-player-queue');
                    if (q) {
                        var queueObj = q.queue || q.playerQueue || (q.data && q.data.queue);
                        var raw = (queueObj && Array.isArray(queueObj.items)) ? queueObj.items : null;
                        if (raw && raw.length > 0) {
                            var seenObj = {};
                            for (var j = 0; j < raw.length; j++) {
                                var data = raw[j].playlistPanelVideoRenderer || raw[j];
                                var titleText = '';
                                if (data.title) {
                                    if (data.title.runs && data.title.runs.length > 0) titleText = data.title.runs[0].text;
                                    else if (data.title.simpleText) titleText = data.title.simpleText;
                                }
                                var artistText = '';
                                if (data.longBylineText && data.longBylineText.runs && data.longBylineText.runs.length > 0) {
                                    artistText = data.longBylineText.runs[0].text;
                                } else if (data.shortBylineText && data.shortBylineText.runs && data.shortBylineText.runs.length > 0) {
                                    artistText = data.shortBylineText.runs[0].text;
                                }
                                var selected = !!data.selected;
                                if (titleText) {
                                    var oKey = titleText.toLowerCase() + '___' + artistText.toLowerCase();
                                    if (seenObj[oKey]) continue;
                                    seenObj[oKey] = true;
                                    
                                    res.push({
                                        index: j,
                                        title: titleText,
                                        artist: artistText,
                                        isSelected: selected,
                                        videoId: data.videoId || ''
                                    });
                                }
                            }
                        }
                    }
                }
                
                // Priority 3: Fallback to Player API
                if (res.length === 0) {
                    var playerBar = document.querySelector('ytmusic-player-bar');
                    var api = (playerBar && playerBar.playerApi) || document.querySelector('#movie_player');
                    if (api && typeof api.getPlaylist === 'function') {
                        var list = api.getPlaylist();
                        var curIdx = typeof api.getPlaylistIndex === 'function' ? api.getPlaylistIndex() : 0;
                        var currentData = typeof api.getVideoData === 'function' ? api.getVideoData() : null;
                        if (list && Array.isArray(list) && list.length > 0) {
                            for (var k = 0; k < list.length; k++) {
                                var isCurrent = (k === curIdx);
                                var itemTitle = (isCurrent && currentData && currentData.title) ? currentData.title : ('Track ' + (k + 1));
                                var itemAuthor = (isCurrent && currentData && currentData.author) ? currentData.author : '';
                                res.push({
                                    index: k,
                                    title: itemTitle,
                                    artist: itemAuthor,
                                    isSelected: isCurrent,
                                    videoId: (list[k] && String(list[k]).match(/^[A-Za-z0-9_-]{11}$/)) ? list[k] : ''
                                });
                            }
                        }
                    }
                }

                // If queue has 1 or 0 items, trigger YouTube Music Radio mix / Automix to populate Up Next autoplay tracks!
                if (res.length <= 1) {
                    try {
                        var autoToggle = document.querySelector('ytmusic-player-queue #automix-toggle tp-yt-paper-toggle-button') ||
                                         document.querySelector('ytmusic-player-queue tp-yt-paper-toggle-button') ||
                                         document.querySelector('#automix-toggle') ||
                                         document.querySelector('tp-yt-paper-toggle-button[aria-label*="Autoplay"]');
                        if (autoToggle && (!autoToggle.checked && !autoToggle.hasAttribute('checked') && autoToggle.getAttribute('aria-pressed') !== 'true')) {
                            autoToggle.click();
                        }
                        
                        var radioBtn = document.querySelector('ytmusic-player-bar .radio-button') ||
                                       document.querySelector('button[aria-label*="Radio"]') ||
                                       document.querySelector('button[aria-label*="Start radio"]') ||
                                       document.querySelector('ytmusic-player-queue #automix-contents button') ||
                                       document.querySelector('ytmusic-automix-preview-video-renderer button');
                        if (radioBtn) radioBtn.click();
                    } catch(e) {}
                }

                return res;
            } catch(e) { return []; }
        })();
        """
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else {
                completion([])
                return
            }
            mainVC.webViewContainer.webView.evaluateJavaScript(js) { result, _ in
                guard let array = result as? [[String: Any]] else {
                    completion([])
                    return
                }
                let items = array.compactMap { dict -> QueueItemInfo? in
                    guard let idx = dict["index"] as? Int,
                          let title = dict["title"] as? String else { return nil }
                    let artist = (dict["artist"] as? String) ?? ""
                    let isSelected = (dict["isSelected"] as? Bool) ?? false
                    let videoId = (dict["videoId"] as? String) ?? ""
                    return QueueItemInfo(index: idx, title: title, artist: artist, isSelected: isSelected, videoId: videoId)
                }
                completion(items)
            }
        }
    }
    
    public func fetchUpNextSnapshot(completion: @escaping (UpNextSnapshot) -> Void) {
        let js = """
        (function() {
            function visible(node) {
                if (!node || !document.body.contains(node)) return false;
                return (node.offsetWidth > 0 || node.offsetHeight > 0 || node.offsetParent !== null);
            }
            function extractText(node, selectors) {
                for (var s = 0; s < selectors.length; s++) {
                    var el = node.querySelector(selectors[s]);
                    if (el && el.textContent && el.textContent.trim()) return el.textContent.trim();
                }
                return '';
            }
            function extractThumb(node) {
                try {
                    var img = node.querySelector('ytmusic-thumbnail-renderer img') ||
                              node.querySelector('#thumbnail img') ||
                              node.querySelector('.thumbnail img') ||
                              node.querySelector('img');
                    if (img) return (img.currentSrc || img.src || '');
                } catch(e) {}
                return '';
            }
            function extractDuration(node) {
                var dt = node.querySelector('.duration, #duration, [class*="duration"], [class*="time"], ytmusic-thumbnail-renderer[has-duration] .badge, yt-time-display');
                if (dt && dt.textContent && dt.textContent.trim()) {
                    var t = dt.textContent.trim();
                    var m = t.match(/\\d{1,3}:\\d{2}(?::\\d{2})?/g);
                    if (m && m.length > 0) return m[m.length - 1];
                    return t;
                }
                return '';
            }
            function extractVideoId(node) {
                if (!node) return '';
                try {
                    var vid = node.getAttribute('video-id') || node.getAttribute('data-video-id') || node.getAttribute('data-id');
                    if (vid) return vid;
                    var a = node.querySelector('a[href*="v="]');
                    if (a) {
                        var m = a.getAttribute('href').match(/[?&]v=([A-Za-z0-9_-]{11})/);
                        if (m) return m[1];
                    }
                    var rli = node.querySelector('ytmusic-responsive-list-item-renderer');
                    if (rli) {
                        var rid = rli.getAttribute('data-id') || rli.getAttribute('data-video-id');
                        if (rid) return rid;
                    }
                    var ipr = node.querySelector('ytmusic-inline-playback-renderer');
                    if (ipr) {
                        var pvid = ipr.getAttribute('playback-video-id') || ipr.getAttribute('data-video-id');
                        if (pvid) return pvid;
                    }
                } catch(e) {}
                return '';
            }
            var res = [];
            try {
                var rawItems = [];
                var primaryContainer = document.querySelector('ytmusic-player-queue #contents') ||
                                       document.querySelector('#queue #contents') ||
                                       document.querySelector('ytmusic-player-queue');
                if (primaryContainer) {
                    rawItems = Array.from(primaryContainer.querySelectorAll('ytmusic-player-queue-item'));
                }
                if (!rawItems || rawItems.length === 0) {
                    rawItems = Array.from(document.querySelectorAll('ytmusic-player-queue-item'));
                }

                var idx = 0;
                for (var i = 0; i < rawItems.length; i++) {
                    var item = rawItems[i];
                    if (!visible(item)) continue;
                    var t = item.querySelector('.song-title, .title, [class*="title"]');
                    var a = item.querySelector('.byline, .artist, [class*="byline"]');
                    if (!t) continue;
                    var titleVal = t.textContent.trim();
                    if (!titleVal) continue;
                    var artistVal = a ? a.textContent.trim() : '';
                    var sel = item.hasAttribute('selected') || item.classList.contains('selected') || item.getAttribute('play-button-state') === 'playing';
                    res.push({ index: idx, title: titleVal, artist: artistVal, isSelected: !!sel, artworkUrl: extractThumb(item), duration: extractDuration(item), videoId: extractVideoId(item) });
                    idx++;
                }

                if (res.length === 0) {
                    var q = document.querySelector('ytmusic-player-queue');
                    if (q) {
                        var queueObj = q.queue || q.playerQueue || (q.data && q.data.queue);
                        var raw = (queueObj && Array.isArray(queueObj.items)) ? queueObj.items : null;
                        var seenObj = {};
                        var jIdx = 0;
                        if (raw) {
                            for (var j = 0; j < raw.length; j++) {
                                var data = raw[j].playlistPanelVideoRenderer || raw[j];
                                var titleText = '';
                                if (data.title) {
                                    if (data.title.runs && data.title.runs.length > 0) titleText = data.title.runs[0].text;
                                    else if (data.title.simpleText) titleText = data.title.simpleText;
                                }
                                var artistText = '';
                                if (data.longBylineText && data.longBylineText.runs && data.longBylineText.runs.length > 0) {
                                    artistText = data.longBylineText.runs[0].text;
                                } else if (data.shortBylineText && data.shortBylineText.runs && data.shortBylineText.runs.length > 0) {
                                    artistText = data.shortBylineText.runs[0].text;
                                }
                                var artUrl = '';
                                try {
                                    if (data.thumbnail && data.thumbnail.thumbnails && data.thumbnail.thumbnails.length > 0) {
                                        artUrl = data.thumbnail.thumbnails[data.thumbnail.thumbnails.length - 1].url || '';
                                    }
                                } catch(e) {}
                                var durText = '';
                                try {
                                    if (data.lengthText) {
                                        if (data.lengthText.simpleText) durText = data.lengthText.simpleText;
                                        else if (data.lengthText.runs && data.lengthText.runs.length > 0) durText = data.lengthText.runs[0].text;
                                    }
                                    if (!durText && data.lengthSeconds) {
                                        var secs = Number(data.lengthSeconds);
                                        durText = Math.floor(secs / 60) + ':' + (secs % 60 < 10 ? '0' : '') + (secs % 60);
                                    }
                                } catch(e) {}
                                if (titleText) {
                                    res.push({ index: jIdx, title: titleText, artist: artistText, isSelected: !!data.selected, artworkUrl: artUrl, duration: durText, videoId: data.videoId || '' });
                                    jIdx++;
                                }
                            }
                        }
                    }
                }
            } catch(e) {}

            var currentTitle = '';
            var currentArtist = '';
            for (var m = 0; m < res.length; m++) {
                if (res[m].isSelected) {
                    if (!currentTitle) currentTitle = res[m].title;
                    if (!currentArtist) currentArtist = res[m].artist;
                    break;
                }
            }

            var autoplayEnabled = false;
            try {
                var autoToggle = document.querySelector('ytmusic-player-queue #automix-toggle tp-yt-paper-toggle-button') ||
                                 document.querySelector('ytmusic-player-queue tp-yt-paper-toggle-button') ||
                                 document.querySelector('#automix-toggle') ||
                                 document.querySelector('tp-yt-paper-toggle-button[aria-label*="Autoplay"]');
                if (autoToggle) {
                    autoplayEnabled = !!(autoToggle.checked || autoToggle.hasAttribute('checked') || autoToggle.getAttribute('aria-pressed') === 'true');
                }
            } catch(e) {}

            var automix = [];
            try {
                var amNodes = Array.from(document.querySelectorAll('ytmusic-automix-preview-video-renderer'));
                var amIdx = 0;
                var seenAuto = {};
                for (var n = 0; n < amNodes.length; n++) {
                    var node = amNodes[n];
                    if (!visible(node)) continue;
                    var amTitle = extractText(node, ['.title', '.song-title', 'yt-formatted-string.title', '[class*="title"]']);
                    var amArtist = extractText(node, ['.byline', '.artist', 'yt-formatted-string.byline', '[class*="byline"]']);
                    if (!amTitle) continue;
                    var amKey = amTitle.toLowerCase() + '___' + amArtist.toLowerCase();
                    if (seenAuto[amKey]) continue;
                    seenAuto[amKey] = true;
                    automix.push({ index: amIdx, title: amTitle, artist: amArtist });
                    amIdx++;
                }
            } catch(e) {}

            var contextTitle = '';
            try {
                var ctxCandidates = [
                    'ytmusic-player-queue #header .metadata .title yt-formatted-string',
                    'ytmusic-player-queue #header .metadata .title',
                    'ytmusic-player-queue #header .metadata .byline',
                    'ytmusic-player-queue #header #menu .title',
                    'ytmusic-player-queue #header yt-formatted-string',
                    'ytmusic-player-queue #editorial-header yt-formatted-string'
                ];
                for (var c = 0; c < ctxCandidates.length && !contextTitle; c++) {
                    var el = document.querySelector(ctxCandidates[c]);
                    if (el && el.textContent && el.textContent.trim()) contextTitle = el.textContent.trim();
                }
            } catch(e) {}

            return {
                items: res,
                automix: automix,
                autoplayEnabled: autoplayEnabled,
                contextTitle: contextTitle,
                currentTitle: currentTitle,
                currentArtist: currentArtist
            };
        })();
        """
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else {
                completion(UpNextSnapshot())
                return
            }
            mainVC.webViewContainer.webView.evaluateJavaScript(js) { result, _ in
                guard let dict = result as? [String: Any] else {
                    completion(UpNextSnapshot())
                    return
                }
                let itemsArray = (dict["items"] as? [[String: Any]]) ?? []
                let items = itemsArray.compactMap { d -> QueueItemInfo? in
                    guard let idx = d["index"] as? Int,
                          let title = d["title"] as? String else { return nil }
                    let artist = (d["artist"] as? String) ?? ""
                    let isSelected = (d["isSelected"] as? Bool) ?? false
                    let artworkUrl = (d["artworkUrl"] as? String) ?? ""
                    let duration = (d["duration"] as? String) ?? ""
                    let videoId = (d["videoId"] as? String) ?? ""
                    return QueueItemInfo(index: idx, title: title, artist: artist, isSelected: isSelected, artworkUrl: artworkUrl, duration: duration, videoId: videoId)
                }
                let automixArray = (dict["automix"] as? [[String: Any]]) ?? []
                let automix = automixArray.compactMap { d -> AutomixItemInfo? in
                    guard let idx = d["index"] as? Int,
                          let title = d["title"] as? String else { return nil }
                    let artist = (d["artist"] as? String) ?? ""
                    return AutomixItemInfo(index: idx, title: title, artist: artist)
                }
                let snapshot = UpNextSnapshot(
                    contextTitle: (dict["contextTitle"] as? String) ?? "",
                    autoplayEnabled: (dict["autoplayEnabled"] as? Bool) ?? false,
                    items: items,
                    automixItems: automix,
                    currentTitle: (dict["currentTitle"] as? String) ?? "",
                    currentArtist: (dict["currentArtist"] as? String) ?? ""
                )
                completion(snapshot)
            }
        }
    }
    
    public func playAutomixItem(at index: Int) {
        let js = """
        (function() {
            try {
                var targetIdx = \(index);
                var nodes = Array.from(document.querySelectorAll('ytmusic-automix-preview-video-renderer')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                if (nodes && nodes.length > targetIdx) {
                    var node = nodes[targetIdx];
                    var targets = [
                        node.querySelector('#thumbnail'),
                        node.querySelector('.thumbnail'),
                        node.querySelector('a'),
                        node.querySelector('button'),
                        node.querySelector('ytmusic-play-button-renderer'),
                        node
                    ];
                    for (var i = 0; i < targets.length; i++) {
                        var t = targets[i];
                        if (!t) continue;
                        try {
                            var opts = { bubbles: true, cancelable: true, view: window };
                            t.dispatchEvent(new MouseEvent('mousedown', opts));
                            t.dispatchEvent(new MouseEvent('mouseup', opts));
                            t.dispatchEvent(new MouseEvent('click', opts));
                            if (typeof t.click === 'function') t.click();
                            break;
                        } catch(e) {}
                    }
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
    public func playQueueItem(at index: Int) {
        let js = """
        (function() {
            try {
                var targetIdx = \(index);
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

                var container = document.querySelector('ytmusic-player-queue #contents') || document.querySelector('#queue #contents') || document;
                var rawItems = Array.from(container.querySelectorAll('ytmusic-player-queue-item')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                
                if (rawItems && rawItems.length > targetIdx) {
                    simulateClick(rawItems[targetIdx]);
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
    public func removeQueueItem(at index: Int) {
        let js = """
        (function() {
            try {
                var targetIdx = \(index);
                var container = document.querySelector('ytmusic-player-queue #contents') || document.querySelector('#queue #contents') || document;
                var rawItems = Array.from(container.querySelectorAll('ytmusic-player-queue-item')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                
                if (rawItems && rawItems.length > targetIdx) {
                    var targetItem = rawItems[targetIdx];
                    var removeBtn = targetItem.querySelector('button[aria-label*="Remove"], .remove-button, [icon*="close"], [aria-label*="Delete"], tp-yt-paper-icon-button#button[aria-label*="Remove"]');
                    if (removeBtn) {
                        removeBtn.click();
                    } else {
                        targetItem.remove();
                        var q = document.querySelector('ytmusic-player-queue');
                        if (q) {
                            var queueObj = q.queue || q.playerQueue || q;
                            if (queueObj && Array.isArray(queueObj.items) && queueObj.items.length > targetIdx) {
                                queueObj.items.splice(targetIdx, 1);
                                if (typeof q.notifyPath === 'function') q.notifyPath('queue.items');
                            }
                        }
                    }
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
    public func playNextQueueItem(from fromIndex: Int) {
        // Find current playing index or default to 0
        fetchQueue { [weak self] items in
            guard let self = self else { return }
            let currentIndex = items.firstIndex(where: { $0.isSelected }) ?? 0
            let targetIndex = min(items.count - 1, currentIndex + 1)
            if fromIndex != targetIndex && fromIndex >= 0 && fromIndex < items.count {
                self.moveQueueItem(from: fromIndex, to: targetIndex)
            }
        }
    }
    
    public func triggerAutoplayRadio() {
        let js = """
        (function() {
            try {
                var autoToggle = document.querySelector('ytmusic-player-queue #automix-toggle tp-yt-paper-toggle-button') ||
                                 document.querySelector('ytmusic-player-queue tp-yt-paper-toggle-button') ||
                                 document.querySelector('#automix-toggle') ||
                                 document.querySelector('tp-yt-paper-toggle-button[aria-label*="Autoplay"]');
                if (autoToggle && (!autoToggle.checked && !autoToggle.hasAttribute('checked') && autoToggle.getAttribute('aria-pressed') !== 'true')) {
                    autoToggle.click();
                }
                
                var radioBtn = document.querySelector('ytmusic-player-bar .radio-button') ||
                               document.querySelector('button[aria-label*="Radio"]') ||
                               document.querySelector('button[aria-label*="Start radio"]') ||
                               document.querySelector('ytmusic-player-queue #automix-contents button') ||
                               document.querySelector('ytmusic-automix-preview-video-renderer button');
                if (radioBtn) radioBtn.click();
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
    public func moveQueueItem(from fromIndex: Int, to toIndex: Int) {
        let js = """
        (function() {
            try {
                var fromIdx = \(fromIndex);
                var toIdx = \(toIndex);
                if (fromIdx === toIdx || fromIdx < 0 || toIdx < 0) return;

                var container = document.querySelector('ytmusic-player-queue #contents') || document.querySelector('#queue #contents') || document;
                var items = Array.from(container.querySelectorAll('ytmusic-player-queue-item')).filter(function(el) {
                    return document.body.contains(el) && (el.offsetWidth > 0 || el.offsetHeight > 0 || el.offsetParent !== null);
                });
                if (items && items.length > fromIdx && items.length > toIdx) {
                    var movedNode = items[fromIdx];
                    var targetNode = items[toIdx];
                    if (movedNode && targetNode && movedNode !== targetNode) {
                        var parent = movedNode.parentNode;
                        if (parent) {
                            if (fromIdx < toIdx) {
                                parent.insertBefore(movedNode, targetNode.nextSibling);
                            } else {
                                parent.insertBefore(movedNode, targetNode);
                            }
                        }
                    }
                }

                var q = document.querySelector('ytmusic-player-queue');
                if (q) {
                    var queueObj = q.queue || q.playerQueue || q;
                    if (queueObj && Array.isArray(queueObj.items) && queueObj.items.length > fromIdx) {
                        var movedItem = queueObj.items.splice(fromIdx, 1)[0];
                        if (movedItem) {
                            queueObj.items.splice(toIdx, 0, movedItem);
                        }
                    }
                    if (typeof q.notifyPath === 'function') {
                        q.notifyPath('queue.items');
                    }
                }
            } catch(e) {}
        })();
        """
        evaluateJS(js)
    }
    
}
