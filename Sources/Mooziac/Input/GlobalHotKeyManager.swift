import AppKit
import Carbon
import ApplicationServices

public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()
    
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    public func startMonitoring() {
        registerCarbonHotKeys()
        registerNSEventMonitors()
    }
    
    private func registerCarbonHotKeys() {
        guard eventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamName(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr, hotKeyID.signature == OSType(0x4D4F4F5A) else { return noErr } // 'MOOZ'
            
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1: // Play / Pause
                    NowPlayingManager.shared.togglePlayPause()
                case 2: // Next Track
                    NowPlayingManager.shared.nextTrack()
                case 3: // Previous Track
                    NowPlayingManager.shared.previousTrack()
                case 4: // Like Track
                    NowPlayingManager.shared.toggleLike()
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        
        guard status == noErr else { return }
        
        // Register Carbon Hotkeys:
        // ID 1: Ctrl + Option + Space / Cmd + Shift + Space
        var playRef1: EventHotKeyRef?
        RegisterEventHotKey(49, UInt32(controlKey | optionKey), EventHotKeyID(signature: OSType(0x4D4F4F5A), id: 1), GetApplicationEventTarget(), 0, &playRef1)
        hotKeyRefs.append(playRef1)

        var playRef2: EventHotKeyRef?
        RegisterEventHotKey(49, UInt32(cmdKey | shiftKey), EventHotKeyID(signature: OSType(0x4D4F4F5A), id: 1), GetApplicationEventTarget(), 0, &playRef2)
        hotKeyRefs.append(playRef2)
    }
    
    private func registerNSEventMonitors() {
        if AXIsProcessTrusted() && eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
        }
        
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleKeyEvent(event) == true {
                    return nil
                }
                return event
            }
        }
        
        print("[GlobalHotKeyManager] Global shortcuts registered (Control+Option+Space / Cmd+Shift+Space).")
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControlOption = modifierFlags.contains([.control, .option])
        let isCmdShift = modifierFlags.contains([.command, .shift])
        
        guard isControlOption || isCmdShift else { return false }
        
        switch event.keyCode {
        case 49: // Spacebar -> Play / Pause
            DispatchQueue.main.async {
                NowPlayingManager.shared.togglePlayPause()
            }
            return true
        case 124: // Right Arrow -> Next Track
            DispatchQueue.main.async {
                NowPlayingManager.shared.nextTrack()
            }
            return true
        case 123: // Left Arrow -> Previous Track
            DispatchQueue.main.async {
                NowPlayingManager.shared.previousTrack()
            }
            return true
        case 37: // 'L' key -> Like Track
            DispatchQueue.main.async {
                NowPlayingManager.shared.toggleLike()
            }
            return true
        default:
            return false
        }
    }
    
    public func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
