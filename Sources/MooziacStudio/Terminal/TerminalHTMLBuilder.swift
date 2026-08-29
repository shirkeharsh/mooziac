import Foundation

public enum TerminalHTMLBuilder {
    public static func buildHTML() -> String {
        let terminalDir = findTerminalResourceDir()
        
        var jsContent = ""
        var cssContent = ""
        var fitContent = ""
        
        if let dir = terminalDir {
            let jsPath = "\(dir)/xterm.js"
            let cssPath = "\(dir)/xterm.css"
            let fitPath = "\(dir)/xterm-addon-fit.js"
            
            if let js = try? String(contentsOf: URL(fileURLWithPath: jsPath), encoding: .utf8) {
                jsContent = js
            }
            if let css = try? String(contentsOf: URL(fileURLWithPath: cssPath), encoding: .utf8) {
                cssContent = css
            }
            if let fit = try? String(contentsOf: URL(fileURLWithPath: fitPath), encoding: .utf8) {
                fitContent = fit
            }
        }
        
        let styleTag: String
        let jsTag: String
        let fitTag: String
        
        if !cssContent.isEmpty {
            styleTag = "<style>\(cssContent)</style>"
        } else {
            styleTag = "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css\">"
        }
        
        if !jsContent.isEmpty {
            jsTag = "<script>\(jsContent)</script>"
        } else {
            jsTag = "<script src=\"https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js\"></script>"
        }
        
        if !fitContent.isEmpty {
            fitTag = "<script>\(fitContent)</script>"
        } else {
            fitTag = "<script src=\"https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js\"></script>"
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(styleTag)
            <style>
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                }
                html, body {
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background-color: #07080d;
                    margin: 0;
                    padding: 0;
                    user-select: text;
                    -webkit-user-select: text;
                }
                #terminal-wrapper {
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    padding: 4px 6px;
                    overflow: hidden;
                    background-color: #07080d;
                }
                #terminal-container {
                    width: 100%;
                    height: 100%;
                    position: relative;
                    overflow: hidden;
                }
                .xterm {
                    padding: 0 !important;
                    height: 100%;
                    width: 100%;
                }
                .xterm .xterm-viewport {
                    overflow-y: auto !important;
                    background-color: #07080d !important;
                }
                .xterm .xterm-screen {
                    background-color: #07080d !important;
                }
                /* Sleek Terminal Scrollbar */
                .xterm .xterm-viewport::-webkit-scrollbar {
                    width: 6px;
                }
                .xterm .xterm-viewport::-webkit-scrollbar-thumb {
                    background: rgba(255, 255, 255, 0.15);
                    border-radius: 3px;
                }
                .xterm .xterm-viewport::-webkit-scrollbar-thumb:hover {
                    background: rgba(255, 255, 255, 0.35);
                }
                .xterm .xterm-viewport::-webkit-scrollbar-track {
                    background: transparent;
                }
            </style>
        </head>
        <body>
            <div id="terminal-wrapper">
                <div id="terminal-container"></div>
            </div>
            \(jsTag)
            \(fitTag)
            <script>
                let currentFontSize = 12.0;

                const term = new Terminal({
                    theme: {
                        background: '#07080d',
                        foreground: '#e2e8f0',
                        cursor: '#38ef7d',
                        cursorAccent: '#07080d',
                        selectionBackground: '#334155',
                        selectionInactiveBackground: '#1e293b',
                        black: '#1a1d26',
                        red: '#f43f5e',
                        green: '#10b981',
                        yellow: '#f59e0b',
                        blue: '#3b82f6',
                        magenta: '#a855f7',
                        cyan: '#06b6d4',
                        white: '#f1f5f9',
                        brightBlack: '#64748b',
                        brightRed: '#fb7185',
                        brightGreen: '#34d399',
                        brightYellow: '#fbbf24',
                        brightBlue: '#60a5fa',
                        brightMagenta: '#c084fc',
                        brightCyan: '#22d3ee',
                        brightWhite: '#ffffff'
                    },
                    fontFamily: 'ui-monospace, "SF Mono", Menlo, Monaco, Consolas, monospace',
                    fontSize: currentFontSize,
                    lineHeight: 1.2,
                    letterSpacing: 0,
                    cursorBlink: true,
                    cursorStyle: 'block',
                    allowTransparency: true,
                    scrollback: 10000,
                    convertEol: false,
                    windowsMode: false,
                    smoothScrollDuration: 0,
                    tabStopWidth: 8
                });

                const fitAddon = new FitAddon.FitAddon();
                term.loadAddon(fitAddon);

                const container = document.getElementById('terminal-container');
                term.open(container);

                function safeFit() {
                    if (container.clientWidth > 40 && container.clientHeight > 30) {
                        try {
                            fitAddon.fit();
                            if (term.cols >= 15 && term.rows >= 3) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.terminalResize) {
                                    window.webkit.messageHandlers.terminalResize.postMessage({ cols: term.cols, rows: term.rows });
                                }
                            }
                        } catch (e) {
                            console.warn("fit error:", e);
                        }
                    }
                }

                term.onData(data => {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.terminalInput) {
                        window.webkit.messageHandlers.terminalInput.postMessage(data);
                    }
                });

                term.onResize(size => {
                    if (size.cols >= 15 && size.rows >= 3) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.terminalResize) {
                            window.webkit.messageHandlers.terminalResize.postMessage({ cols: size.cols, rows: size.rows });
                        }
                    }
                });

                // Use ResizeObserver for instant responsive resize in any window dimension
                let resizeFrame = null;
                const resizeObserver = new ResizeObserver(() => {
                    if (resizeFrame) cancelAnimationFrame(resizeFrame);
                    resizeFrame = requestAnimationFrame(() => {
                        safeFit();
                    });
                });
                resizeObserver.observe(container);

                window.addEventListener('resize', () => {
                    safeFit();
                });

                window.fitTerminal = function() {
                    safeFit();
                    return { cols: term.cols, rows: term.rows };
                };

                window.setFontSize = function(size) {
                    currentFontSize = Math.max(9, Math.min(24, size));
                    term.options.fontSize = currentFontSize;
                    safeFit();
                };

                window.zoomIn = function() {
                    window.setFontSize(currentFontSize + 1);
                };

                window.zoomOut = function() {
                    window.setFontSize(currentFontSize - 1);
                };

                window.resetZoom = function() {
                    window.setFontSize(12.0);
                };

                window.writeTerminalBase64 = function(base64Data) {
                    try {
                        const binStr = atob(base64Data);
                        const len = binStr.length;
                        const bytes = new Uint8Array(len);
                        for (let i = 0; i < len; i++) {
                            bytes[i] = binStr.charCodeAt(i);
                        }
                        term.write(bytes);
                    } catch (e) {
                        console.error("writeTerminalBase64 error:", e);
                    }
                };

                window.clearTerminal = function() {
                    term.clear();
                };

                window.focusTerminal = function() {
                    term.focus();
                };

                // Initial load fit
                document.addEventListener('DOMContentLoaded', () => {
                    setTimeout(() => {
                        safeFit();
                        term.focus();
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.terminalReady) {
                            window.webkit.messageHandlers.terminalReady.postMessage({ cols: term.cols, rows: term.rows });
                        }
                    }, 60);
                });

                setTimeout(() => {
                    safeFit();
                    term.focus();
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.terminalReady) {
                        window.webkit.messageHandlers.terminalReady.postMessage({ cols: term.cols, rows: term.rows });
                    }
                }, 100);
            </script>
        </body>
        </html>
        """
    }
    
    private static func findTerminalResourceDir() -> String? {
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/Terminal" },
            "/Users/harshshirke/local/projects/Mooziac/mp3kal/Resources/Terminal",
            "/Users/harshshirke/local/projects/Mooziac/mp3kal/dist/MooziacStudio.app/Contents/Resources/Terminal"
        ].compactMap { $0 }
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: "\(path)/xterm.js") {
                return path
            }
        }
        return nil
    }
}
