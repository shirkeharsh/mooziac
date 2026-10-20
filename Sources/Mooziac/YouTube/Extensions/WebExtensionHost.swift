import AppKit
import Foundation
import WebKit

#if compiler(>=5.9)
@available(macOS 15.4, *)
@MainActor
public final class MooziacWebExtensionHost {
    public let controller: WKWebExtensionController

    public init(controller: WKWebExtensionController) {
        self.controller = controller
    }
}

#if canImport(WebKit)
@available(macOS 15.4, *)
@MainActor
final class MooziacExtensionTab: NSObject, WKWebExtensionTab {
    weak var webView: WKWebView?
    weak var window: MooziacExtensionWindow?
    var pendingNavigationURL: URL?

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
    }

    func window(for _: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        self.window
    }

    func indexInWindow(for _: WKWebExtensionContext) -> Int {
        return 0
    }

    func webView(for _: WKWebExtensionContext) -> WKWebView? {
        self.webView
    }

    func title(for _: WKWebExtensionContext) -> String? {
        self.webView?.title ?? "MooziacTube"
    }

    func url(for _: WKWebExtensionContext) -> URL? {
        self.webView?.url
    }

    func pendingURL(for _: WKWebExtensionContext) -> URL? {
        self.pendingNavigationURL
    }

    func isSelected(for _: WKWebExtensionContext) -> Bool {
        true
    }

    func isLoadingComplete(for _: WKWebExtensionContext) -> Bool {
        self.pendingNavigationURL == nil && self.webView?.isLoading == false
    }

    func size(for _: WKWebExtensionContext) -> CGSize {
        self.webView?.bounds.size ?? .zero
    }
}

@available(macOS 15.4, *)
@MainActor
final class MooziacExtensionWindow: NSObject, WKWebExtensionWindow {
    weak var tab: MooziacExtensionTab?

    func tabs(for _: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        if let tab = tab { return [tab] }
        return []
    }

    func activeTab(for _: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        self.tab
    }

    func windowType(for _: WKWebExtensionContext) -> WKWebExtension.WindowType {
        .normal
    }

    func windowState(for _: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let nsWindow = self.tab?.webView?.window else { return .normal }
        if nsWindow.styleMask.contains(.fullScreen) {
            return .fullscreen
        }
        if nsWindow.isMiniaturized {
            return .minimized
        }
        if nsWindow.isZoomed {
            return .maximized
        }
        return .normal
    }

    func isPrivate(for _: WKWebExtensionContext) -> Bool {
        false
    }

    func screenFrame(for _: WKWebExtensionContext) -> CGRect {
        self.tab?.webView?.window?.screen?.frame ?? NSScreen.main?.frame ?? .null
    }

    func frame(for _: WKWebExtensionContext) -> CGRect {
        self.tab?.webView?.window?.frame ?? .null
    }

    func focus(for _: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        self.tab?.webView?.window?.makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }
}
#endif
#endif
