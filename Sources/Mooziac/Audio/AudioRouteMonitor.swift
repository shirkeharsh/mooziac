import AppKit
import CoreAudio

final class AudioRouteMonitor {
    static let shared = AudioRouteMonitor()
    
    var isAutoPauseOnDisconnectEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_isAutoPauseOnDisconnectEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "YTM_isAutoPauseOnDisconnectEnabled") }
    }
    
    private var lastOutputDeviceID: AudioObjectID = kAudioObjectUnknown
    private var isMonitoring = false
    private var isSleeping = false
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        lastOutputDeviceID = getCurrentOutputDeviceID()
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioOutputDeviceChangedCallback,
            selfPtr
        )
        
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(handleScreenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(handleScreenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(handleScreenLocked), name: NSWorkspace.willSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(handleScreenUnlocked), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioOutputDeviceChangedCallback,
            selfPtr
        )
        
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func handleScreenLocked() {
        isSleeping = true
    }
    
    @objc private func handleScreenUnlocked() {
        isSleeping = false
    }
    
    fileprivate func handleDeviceChanged() {
        guard !isSleeping else { return }
        let newDeviceID = getCurrentOutputDeviceID()
        if lastOutputDeviceID != kAudioObjectUnknown && newDeviceID != lastOutputDeviceID {
            if isAutoPauseOnDisconnectEnabled {
                DispatchQueue.main.async {
                    if NowPlayingManager.shared.currentState.isPlaying {
                        NowPlayingManager.shared.pause()
                        CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Audio Device Changed (Paused)")
                    }
                }
            }
        }
        lastOutputDeviceID = newDeviceID
    }
    
    private func getCurrentOutputDeviceID() -> AudioObjectID {
        var defaultOutputDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )
        return defaultOutputDeviceID
    }
}

private func audioOutputDeviceChangedCallback(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }
    let monitor = Unmanaged<AudioRouteMonitor>.fromOpaque(clientData).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.handleDeviceChanged()
    }
    return noErr
}
