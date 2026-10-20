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
            config.preferences.inactiveSchedulingPolicy = .none
        }
        if #available(macOS 15.4, *) {
            config.webExtensionController = WebExtensionManager.shared.webExtensionController
        }

        // Configure ad blocker scripts & content rules
        YouTubeAdBlocker.configure(userContentController: config.userContentController)

        // Configure SponsorBlock auto-skipping
        YouTubeSponsorBlock.configure(userContentController: config.userContentController)

        // Configure highlight & best part detection
        YouTubeHighlightManager.configure(userContentController: config.userContentController)

        // Configure quality management script
        config.userContentController.addUserScript(YouTubeQualityManager.qualityControlScript)

        // Configure custom UI scripts (Buttons beside search/mic, masthead drag, and cinema mode)
        config.userContentController.addUserScript(YouTubeUIScript.uiStyleScript)
        config.userContentController.addUserScript(YouTubeUIScript.uiControllerScript)

        // Configure player state observer bridge
        config.userContentController.addUserScript(YouTubePlayerBridge.observerScript)
        config.userContentController.add(bridge, name: YouTubePlayerBridge.handlerName)

        // Visibility & Fullscreen shield: ensures smooth playback and early Fullscreen API readiness
        let visibilityShield = WKUserScript(
            source: """
            (function() {
                try {
                    Object.defineProperty(Document.prototype, 'hidden', { get: function() { return false; }, configurable: true });
                    Object.defineProperty(Document.prototype, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
                    Object.defineProperty(Document.prototype, 'webkitHidden', { get: function() { return false; }, configurable: true });
                    Object.defineProperty(Document.prototype, 'webkitVisibilityState', { get: function() { return 'visible'; }, configurable: true });
                    Object.defineProperty(Document.prototype, 'fullscreenEnabled', { get: function() { return true; }, configurable: true });
                    Object.defineProperty(Document.prototype, 'webkitFullscreenEnabled', { get: function() { return true; }, configurable: true });
                } catch(e) {}
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(visibilityShield)

        return config
    }

    public init(frame: NSRect, bridge: YouTubePlayerBridge) {
        let config = YouTubeWebView.createConfiguration(bridge: bridge)
        super.init(frame: frame, configuration: config)
        self.customUserAgent = YouTubeWebView.desktopUserAgent
        self.wantsLayer = true
        self.layer?.drawsAsynchronously = true
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
