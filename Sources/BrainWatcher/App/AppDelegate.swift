import AppKit
import SwiftUI

@main
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPopover()
        
        // Listen to state changes to update the menu bar icon (e.g. pulsing when syncing)
        observeState()
        
        print("🧠 [BrainWatcher] Menu Bar App running in accessory mode.")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        updateStatusItemIcon(isSyncing: false)
        
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 440, height: 560)
        pop.behavior = .transient
        pop.animates = true
        
        let hostingController = NSHostingController(rootView: BrainDashboardView())
        pop.contentViewController = hostingController
        self.popover = pop
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        
        guard let pop = popover, let button = statusItem?.button else { return }
        
        if pop.isShown {
            pop.performClose(sender)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let isWatching = BrainState.shared.isWatching
        let watchTitle = isWatching ? "⏸ Pause Auto-Sync" : "▶️ Resume Auto-Sync"
        menu.addItem(NSMenuItem(title: watchTitle, action: #selector(toggleWatchState), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem(title: "⚡ Trigger Incremental Scan", action: #selector(triggerSyncNow), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "🔄 Deep Rebuild Brain", action: #selector(triggerDeepRebuild), keyEquivalent: "r"))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "📖 Open brain.md", action: #selector(openBrainMd), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "📁 Reveal .mooziac-brain in Finder", action: #selector(revealBrainFolder), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Brain Watcher", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // restore click-to-popover behavior
    }
    
    @objc private func toggleWatchState() {
        BrainState.shared.isWatching.toggle()
    }
    
    @objc private func triggerSyncNow() {
        BrainState.shared.triggerIncrementalSync()
    }
    
    @objc private func triggerDeepRebuild() {
        BrainState.shared.triggerDeepRebuild()
    }
    
    @objc private func openBrainMd() {
        let path = URL(fileURLWithPath: BrainProcessRunner.shared.workspacePath)
            .appendingPathComponent(".mooziac-brain/brain.md")
        NSWorkspace.shared.open(path)
    }
    
    @objc private func revealBrainFolder() {
        let path = URL(fileURLWithPath: BrainProcessRunner.shared.workspacePath)
            .appendingPathComponent(".mooziac-brain")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func observeState() {
        // Monitor sync state for menu bar icon updates
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let isSyncing = BrainState.shared.isSyncing
                self.updateStatusItemIcon(isSyncing: isSyncing)
            }
        }
    }
    
    private func updateStatusItemIcon(isSyncing: Bool) {
        guard let button = statusItem?.button else { return }
        
        if isSyncing {
            button.title = "🧠⚡"
            button.image = nil
        } else {
            if let img = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Mooziac Brain") {
                img.isTemplate = true
                button.image = img
                button.title = ""
            } else {
                button.title = "🧠"
                button.image = nil
            }
        }
    }
}
