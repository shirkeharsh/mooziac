import AppKit
import WebKit

public class YouTubeWebView: WKWebView {
    public static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    public static var isolatedDataStore: WKWebsiteDataStore {
        if #available(macOS 14.0, *) {
            let youtubeStoreUUID = UUID(uuidString: "9A4C6262-63BE-4D88-8DF6-17C17B9D79F1")!
            return WKWebsiteDataStore(forIdentifier: youtubeStoreUUID)
        } else {
            return WKWebsiteDataStore.default()
        }
    }

    // Codec optimization: On systems without dedicated hardware AV1 decode (Intel & Apple M1/M2),
    // intercept MediaSource.isTypeSupported to report false for AV1 (av01), ensuring YouTube
    // serves 100% hardware-accelerated VP9 (and H.264) streams via Apple VideoToolbox.
    public static let codecOptimizerScript = WKUserScript(
        source: """
        (function() {
            try {
                if (window.MediaSource && typeof window.MediaSource.isTypeSupported === 'function') {
                    var origIsTypeSupported = window.MediaSource.isTypeSupported.bind(window.MediaSource);
                    window.MediaSource.isTypeSupported = function(mimeType) {
                        if (typeof mimeType === 'string' && (mimeType.indexOf('av01') !== -1 || mimeType.indexOf('av1') !== -1)) {
                            return false;
                        }
                        return origIsTypeSupported(mimeType);
                    };
                }
                if (window.HTMLMediaElement && window.HTMLMediaElement.prototype.canPlayType) {
                    var origCanPlay = window.HTMLMediaElement.prototype.canPlayType;
                    window.HTMLMediaElement.prototype.canPlayType = function(type) {
                        if (typeof type === 'string' && (type.indexOf('av01') !== -1 || type.indexOf('av1') !== -1)) {
                            return '';
                        }
                        return origCanPlay.apply(this, arguments);
                    };
                }
            } catch(e) {}
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )

    // Fullscreen shield: ensures native Fullscreen API readiness without overriding page visibility
    public static let fullscreenShieldScript = WKUserScript(
        source: """
        (function() {
            try {
                Object.defineProperty(Document.prototype, 'fullscreenEnabled', { get: function() { return true; }, configurable: true });
                Object.defineProperty(Document.prototype, 'webkitFullscreenEnabled', { get: function() { return true; }, configurable: true });
            } catch(e) {}
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    /// Installs every script the YouTube page needs, in one place.
    /// Used when the web view is first created AND by MainVideoWindowController.reconfigureAndReload().
    public static func installUserScripts(into ucc: WKUserContentController) {
        ucc.addUserScript(codecOptimizerScript)
        if AppSettings.shared.isAdBlockEnabled {
            YouTubeAdBlocker.configure(userContentController: ucc)
        }
        if AppSettings.shared.isSponsorBlockEnabled {
            YouTubeSponsorBlock.configure(userContentController: ucc)
        }
        YouTubeHighlightManager.configure(userContentController: ucc)
        ucc.addUserScript(YouTubeQualityManager.qualityControlScript)
        ucc.addUserScript(YouTubeUIScript.uiStyleScript)
        ucc.addUserScript(YouTubeUIScript.uiControllerScript)
        ucc.addUserScript(YouTubePlayerBridge.observerScript)
        ucc.addUserScript(fullscreenShieldScript)
    }

    public static func createConfiguration(bridge: YouTubePlayerBridge) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = isolatedDataStore

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = false

        let wkPrefs = config.preferences
        if #available(macOS 12.3, *) {
            wkPrefs.isElementFullscreenEnabled = true
        }
        wkPrefs.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        wkPrefs.setValue(true, forKey: "developerExtrasEnabled")
        wkPrefs.setValue(true, forKey: "acceleratedCompositingEnabled")
        wkPrefs.setValue(true, forKey: "canvasUsesAcceleratedDrawing")
        wkPrefs.setValue(true, forKey: "acceleratedDrawingEnabled")
        wkPrefs.setValue(true, forKey: "webGLEnabled")

        if #available(macOS 14.0, *) {
            config.preferences.inactiveSchedulingPolicy = .throttle
        }
        if #available(macOS 15.4, *) {
            config.webExtensionController = WebExtensionManager.shared.webExtensionController
        }

        // All page scripts are installed through one shared function so that the first
        // load and a later reconfigure (ad blocker / SponsorBlock toggle) always match.
        installUserScripts(into: config.userContentController)
        config.userContentController.add(bridge, name: YouTubePlayerBridge.handlerName)

        return config
    }

    public init(frame: NSRect, bridge: YouTubePlayerBridge) {
        let config = YouTubeWebView.createConfiguration(bridge: bridge)
        super.init(frame: frame, configuration: config)
        self.customUserAgent = YouTubeWebView.desktopUserAgent
        self.wantsLayer = true
        self.setValue(true, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            self.underPageBackgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        }

        if #available(macOS 15.4, *) {
            WebExtensionManager.shared.attachWebView(self)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func applyThemeUnderPage(_ theme: PlayerTheme = .liquidFluid, ambientColor: NSColor? = nil) {
        if #available(macOS 12.0, *) {
            self.underPageBackgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        }
    }

    public func loadYouTubeHome() {
        if let url = URL(string: "https://www.youtube.com") {
            load(URLRequest(url: url))
        }
    }
}
