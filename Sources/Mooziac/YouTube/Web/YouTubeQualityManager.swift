import Foundation
import WebKit

public final class YouTubeQualityManager {
    public static let shared = YouTubeQualityManager()

    public private(set) var currentQuality: VideoQuality = .auto
    public private(set) var availableQualities: [VideoQuality] = []
    public private(set) var is4KAvailable: Bool = false
    public private(set) var is4KActive: Bool = false

    public var preferredQuality: VideoQuality {
        get {
            if let saved = UserDefaults.standard.string(forKey: "MooziacYouTube_preferredQuality"),
               let q = VideoQuality(rawValue: saved) {
                return q
            }
            return .auto // Default to auto! Do not force 4K!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MooziacYouTube_preferredQuality")
        }
    }

    private init() {}

    /// Script that monitors and controls YouTube playback quality
    public static let qualityControlScript = WKUserScript(
        source: """
        (function() {
            'use strict';
            if (window.__mooziacQualityInjected) return;
            window.__mooziacQualityInjected = true;

            function getPlayer() {
                return document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            }

            window.__mooziacSetQuality = function(targetQuality) {
                var player = getPlayer();
                if (!player) return false;
                try {
                    if (typeof player.setPlaybackQualityRange === 'function') {
                        player.setPlaybackQualityRange(targetQuality, targetQuality);
                    }
                    if (typeof player.setPlaybackQuality === 'function') {
                        player.setPlaybackQuality(targetQuality);
                    }
                    return true;
                } catch(e) {
                    return false;
                }
            };

            window.__mooziacGetQualityInfo = function() {
                var player = getPlayer();
                if (!player) return null;
                try {
                    var current = (typeof player.getPlaybackQuality === 'function') ? player.getPlaybackQuality() : 'auto';
                    var available = (typeof player.getAvailableQualityLevels === 'function') ? player.getAvailableQualityLevels() : [];
                    return {
                        current: current,
                        available: available,
                        has4K: available.indexOf('hd2160') !== -1
                    };
                } catch(e) {
                    return null;
                }
            };
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    public func setQuality(_ quality: VideoQuality, in webView: WKWebView) {
        preferredQuality = quality
        let qStr = quality.rawValue
        let js = "window.__mooziacSetQuality && window.__mooziacSetQuality('\(qStr)');"
        webView.evaluateJavaScript(js) { [weak self] _, error in
            if error == nil {
                self?.currentQuality = quality
                self?.is4KActive = (quality == .uhd2160)
                Log.quality.info("Requested quality changed to: \(quality.displayName)")
            }
        }
    }

    public func updateFromWeb(current: String, available: [String]) {
        let parsedCurrent = VideoQuality(rawValue: current) ?? .auto
        let parsedAvailable = available.compactMap { VideoQuality(rawValue: $0) }

        self.currentQuality = parsedCurrent
        self.availableQualities = parsedAvailable
        self.is4KAvailable = available.contains("hd2160")
        self.is4KActive = (parsedCurrent == .uhd2160)
    }
}
