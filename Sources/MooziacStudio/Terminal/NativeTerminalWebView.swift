import SwiftUI
import AppKit
import WebKit

public struct NativeTerminalWebView: NSViewRepresentable {
    @ObservedObject var pty: NativePTYSession
    var workingDir: String
    
    public init(pty: NativePTYSession = .shared, workingDir: String) {
        self.pty = pty
        self.workingDir = workingDir
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "terminalInput")
        contentController.add(context.coordinator, name: "terminalResize")
        contentController.add(context.coordinator, name: "terminalReady")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        
        // Load embedded terminal HTML
        let html = TerminalHTMLBuilder.buildHTML()
        webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: workingDir))
        
        // Hook up PTY stream output to webView
        pty.onDataReceived = { [weak webView] data in
            let b64 = data.base64EncodedString()
            DispatchQueue.main.async {
                webView?.evaluateJavaScript("if (window.writeTerminalBase64) { window.writeTerminalBase64('\(b64)'); }") { _, _ in }
            }
        }
        
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        // If directory changed, restart or notify
        if pty.activeDirectory != workingDir {
            pty.startSession(workingDir: workingDir)
        }
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: NativeTerminalWebView
        weak var webView: WKWebView?
        
        init(_ parent: NativeTerminalWebView) {
            self.parent = parent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "terminalInput", let str = message.body as? String {
                parent.pty.write(string: str)
            } else if message.name == "terminalResize", let dict = message.body as? [String: Any] {
                let cols = Int32(dict["cols"] as? Int ?? 80)
                let rows = Int32(dict["rows"] as? Int ?? 24)
                parent.pty.resize(cols: cols, rows: rows)
            } else if message.name == "terminalReady", let dict = message.body as? [String: Any] {
                let cols = Int32(dict["cols"] as? Int ?? 90)
                let rows = Int32(dict["rows"] as? Int ?? 28)
                if !parent.pty.isRunning {
                    parent.pty.startSession(workingDir: parent.workingDir, initialCols: cols, initialRows: rows)
                } else {
                    parent.pty.resize(cols: cols, rows: rows)
                }
            }
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                webView.evaluateJavaScript("if (window.focusTerminal) { window.focusTerminal(); }") { _, _ in }
            }
        }
    }
}
