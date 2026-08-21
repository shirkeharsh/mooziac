import AppKit
import CoreAudio
import AudioToolbox

// MARK: - Native CoreAudio Volume Manager (Apple Silicon Multi-Channel Aligned)
final class VolumeController {
    static let shared = VolumeController()

    private var lastKnownVolume: Float {
        get {
            if let saved = UserDefaults.standard.object(forKey: "YTM_lastKnownSystemVolume") as? Float {
                return max(0.0, min(1.0, saved))
            }
            return 0.3
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "YTM_lastKnownSystemVolume")
        }
    }

    init() {
        _ = getVolume()
    }

    private func defaultOutputDevice() -> AudioObjectID {
        var defaultOutputDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )
        return status == noErr ? defaultOutputDeviceID : kAudioObjectUnknown
    }

    func getVolume() -> Float {
        let deviceID = defaultOutputDevice()
        if deviceID != kAudioObjectUnknown {
            var volume: Float32 = 0.0
            var propertySize = UInt32(MemoryLayout<Float32>.size)

            // 1. Try Virtual Main Volume ('vmvo' = 0x766d766f) Output Scope
            var address = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(0x766d766f),
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &volume) == noErr {
                let v = max(0.0, min(1.0, volume))
                lastKnownVolume = v
                return v
            }

            // 2. Try kAudioDevicePropertyVolumeScalar on Element 0 (Main)
            address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &volume) == noErr {
                let v = max(0.0, min(1.0, volume))
                lastKnownVolume = v
                return v
            }

            // 3. Try kAudioDevicePropertyVolumeScalar on Channel 1 (Left) or Channel 2 (Right)
            for channel: UInt32 in [1, 2] {
                address.mElement = channel
                if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &volume) == noErr {
                    let v = max(0.0, min(1.0, volume))
                    lastKnownVolume = v
                    return v
                }
            }

            // 4. Try Virtual Main Volume ('vmvo') Global Scope
            address = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(0x766d766f),
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &volume) == noErr {
                let v = max(0.0, min(1.0, volume))
                lastKnownVolume = v
                return v
            }
        }

        return lastKnownVolume
    }

    func setVolume(_ volume: Float) {
        let deviceID = defaultOutputDevice()
        guard deviceID != kAudioObjectUnknown else { return }

        var newVolume = max(0.0, min(1.0, volume))
        lastKnownVolume = newVolume
        let propertySize = UInt32(MemoryLayout<Float32>.size)

        // 1. Try Virtual Main Volume ('vmvo' = 0x766d766f)
        var virtualAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(0x766d766f),
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(deviceID, &virtualAddress, 0, nil, propertySize, &newVolume)

        // 2. Try per-channel scalar volume
        for channel: UInt32 in [0, 1, 2] {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            _ = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &newVolume)
        }

        // Unmute if muted and raising volume
        var isMuted: UInt32 = 0
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &isMuted)
        if isMuted != 0 && newVolume > 0 {
            isMuted = 0
            _ = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, muteSize, &isMuted)
        }
    }
}

// MARK: - Multitouch Frame Parser (Volume Swipe, Right 2 Taps Next, Right 3 Taps Back, Left 2 Taps Play/Pause)
private typealias MTContactFrameCallback = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32
) -> Int32

private typealias MTDeviceCreateList = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterContactFrameCallback = @convention(c) (UnsafeMutableRawPointer, MTContactFrameCallback) -> Void
private typealias MTDeviceStart = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
private typealias MTDeviceStop = @convention(c) (UnsafeMutableRawPointer) -> Void
private typealias MTDeviceGetSensorSurfaceDimensions = @convention(c) (
    UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>
) -> Int32

final class EdgeVolumeEngine {
    static let shared = EdgeVolumeEngine()

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_v3_isEdgeEngineEnabled") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "YTM_v3_isEdgeEngineEnabled")
            isRightEdgeVolumeEnabled = newValue
            isRightCornerTapsEnabled = newValue
            isLeftCornerTapsEnabled = newValue
            if !newValue { stop() } else { start() }
        }
    }

    var isRightEdgeVolumeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_v3_isRightEdgeVolumeEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "YTM_v3_isRightEdgeVolumeEnabled") }
    }

    var isRightCornerTapsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_v3_isRightCornerTapsEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "YTM_v3_isRightCornerTapsEnabled") }
    }

    var isLeftCornerTapsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "YTM_v3_isLeftCornerTapsEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "YTM_v3_isLeftCornerTapsEnabled") }
    }

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [UnsafeMutableRawPointer] = []
    private var retainedCFDevices: [AnyObject] = []
    private var pendingRestartWorkItem: DispatchWorkItem?
    private var trackpadWidthMm: Double = 157.8
    private var trackpadHeightMm: Double = 97.8

    // Volume gesture state
    private var isSwiping = false
    private var isVolumeDragActive = false
    private var activeTouchID: Int32 = -1
    private var startY: Double = 0
    private var startVolume: Float = 0.5
    private var autoReconnectTimer: Timer?

    // Bottom-Right Corner Tap state (2 Taps = Next, 3 Taps = Previous)
    private var rightTapCount: Int = 0
    private var rightTapTimer: Timer?
    private var isPotentialRightTap = false

    // Bottom-Left Corner Tap state (2 Taps = Stop / Play / Pause)
    private var leftTapCount: Int = 0
    private var leftTapTimer: Timer?
    private var isPotentialLeftTap = false

    private var tapStartTime: TimeInterval = 0
    private var tapStartY: Double = 0

    private enum Layout {
        static let stride = 96
        static let identifier = 16
        static let state = 20
        static let normalisedX = 32
        static let normalisedY = 36
    }

    private var createListFunc: MTDeviceCreateList?
    private var registerCallbackFunc: MTRegisterContactFrameCallback?
    private var deviceStartFunc: MTDeviceStart?
    private var deviceStopFunc: MTDeviceStop?
    private var getDimensionsFunc: MTDeviceGetSensorSurfaceDimensions?

    init() {
        loadFramework()
        setupLockWakeObservers()
    }

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        frameworkHandle = dlopen(path, RTLD_LAZY)
        guard let handle = frameworkHandle else { return }

        if let sym = dlsym(handle, "MTDeviceCreateList") {
            createListFunc = unsafeBitCast(sym, to: MTDeviceCreateList.self)
        }
        if let sym = dlsym(handle, "MTRegisterContactFrameCallback") ?? dlsym(handle, "MTRegisterContactObserver") {
            registerCallbackFunc = unsafeBitCast(sym, to: MTRegisterContactFrameCallback.self)
        }
        if let sym = dlsym(handle, "MTDeviceStart") {
            deviceStartFunc = unsafeBitCast(sym, to: MTDeviceStart.self)
        }
        if let sym = dlsym(handle, "MTDeviceStop") {
            deviceStopFunc = unsafeBitCast(sym, to: MTDeviceStop.self)
        }
        if let sym = dlsym(handle, "MTDeviceGetSensorSurfaceDimensions") {
            getDimensionsFunc = unsafeBitCast(sym, to: MTDeviceGetSensorSurfaceDimensions.self)
        }
    }

    private func setupLockWakeObservers() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.restart()
        }

        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
        wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restart()
        }

        let timer = Timer(timeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isEnabled && self.devices.isEmpty {
                self.start()
            }
        }
        timer.tolerance = 5.0
        RunLoop.main.add(timer, forMode: .common)
        autoReconnectTimer = timer
    }

    func restart() {
        pendingRestartWorkItem?.cancel()
        stop()
        let workItem = DispatchWorkItem { [weak self] in
            self?.start()
        }
        pendingRestartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func start() {
        stop()
        guard isEnabled else { return }

        guard let createList = createListFunc,
              let registerCallback = registerCallbackFunc,
              let deviceStart = deviceStartFunc,
              let unmanagedList = createList() else { return }

        let cfDevices = unmanagedList.takeRetainedValue() as [AnyObject]
        guard !cfDevices.isEmpty else { return }
        retainedCFDevices = cfDevices
        activeEngineBox.set(self)

        for dev in cfDevices {
            let ptr = UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(dev).toOpaque())
            devices.append(ptr)

            if let getDimensions = getDimensionsFunc {
                var w: Int32 = 0, h: Int32 = 0
                if getDimensions(ptr, &w, &h) == 0 && h > 0 {
                    trackpadWidthMm = Double(w) / 100.0
                    trackpadHeightMm = Double(h) / 100.0
                }
            }

            registerCallback(ptr, globalMultitouchCallbackRelay)
            deviceStart(ptr, 0)
        }
    }

    func stop() {
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        if let deviceStop = deviceStopFunc {
            for dev in devices {
                deviceStop(dev)
            }
        }
        devices.removeAll()
        retainedCFDevices.removeAll()
        isSwiping = false
        isVolumeDragActive = false
    }

    private func handleRightTapCompleted() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rightTapTimer?.invalidate()
            self.rightTapTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                let count = self.rightTapCount
                self.rightTapCount = 0

                if count == 2 {
                    GestureMappingManager.shared.executeAction(for: .bottomRightDoubleTap)
                } else if count >= 3 {
                    GestureMappingManager.shared.executeAction(for: .bottomRightTripleTap)
                }
            }
        }
    }

    private func handleLeftTapCompleted() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.leftTapTimer?.invalidate()
            self.leftTapTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                let count = self.leftTapCount
                self.leftTapCount = 0

                if count == 2 {
                    GestureMappingManager.shared.executeAction(for: .bottomLeftDoubleTap)
                } else if count >= 3 {
                    GestureMappingManager.shared.executeAction(for: .bottomLeftTripleTap)
                }
            }
        }
    }

    fileprivate func handleTouches(rawPtr: UnsafeMutableRawPointer?, count: Int32) {
        guard isEnabled else { return }
        guard isRightEdgeVolumeEnabled || isRightCornerTapsEnabled || isLeftCornerTapsEnabled else { return }

        guard let rawPtr = rawPtr, count > 0 else {
            if !isPotentialRightTap && !isPotentialLeftTap && !isSwiping {
                return
            }
            let now = CACurrentMediaTime()
            if isPotentialRightTap {
                let duration = now - tapStartTime
                if duration <= 0.35 {
                    rightTapCount += 1
                    handleRightTapCompleted()
                }
                isPotentialRightTap = false
            }
            if isPotentialLeftTap {
                let duration = now - tapStartTime
                if duration <= 0.35 {
                    leftTapCount += 1
                    handleLeftTapCompleted()
                }
                isPotentialLeftTap = false
            }
            if isSwiping {
                isSwiping = false
                isVolumeDragActive = false
            }
            return
        }

        let now = CACurrentMediaTime()

        var foundActiveTouch = false

        for i in 0..<Int(count) {
            let base = i * Layout.stride
            let state = rawPtr.loadUnaligned(fromByteOffset: base + Layout.state, as: Int32.self)
            guard (2...5).contains(state) else { continue }

            let touchID = rawPtr.loadUnaligned(fromByteOffset: base + Layout.identifier, as: Int32.self)
            let x = Double(rawPtr.loadUnaligned(fromByteOffset: base + Layout.normalisedX, as: Float.self))
            let y = Double(rawPtr.loadUnaligned(fromByteOffset: base + Layout.normalisedY, as: Float.self))

            // Right Edge Boundary Check (Tighter edge zone: within 2.5mm or x >= 0.982)
            let distanceFromRightMm = (1.0 - x) * trackpadWidthMm
            let isRightEdge = distanceFromRightMm <= 2.5 || x >= 0.982

            // TOP 30% Right Edge (y >= 0.70) for Volume
            let isTopRight30Edge = isRightEdge && y >= 0.70

            // PHYSICAL BOTTOM-RIGHT CORNER (y <= 0.15) for Next / Previous Taps
            let isBottomRightCorner = isRightEdge && y <= 0.15

            // PHYSICAL BOTTOM-LEFT CORNER (x <= 0.005, y <= 0.15) for Play / Pause 2 Taps
            let distanceFromLeftMm = x * trackpadWidthMm
            let isBottomLeftCorner = (distanceFromLeftMm <= 2.5 || x <= 0.005) && y <= 0.15

            if isBottomRightCorner && !isSwiping && isRightCornerTapsEnabled {
                if !isPotentialRightTap {
                    isPotentialRightTap = true
                    tapStartTime = now
                    tapStartY = y
                } else if abs(y - tapStartY) > 0.05 {
                    isPotentialRightTap = false
                }
            }

            if isBottomLeftCorner && !isSwiping && isLeftCornerTapsEnabled {
                if !isPotentialLeftTap {
                    isPotentialLeftTap = true
                    tapStartTime = now
                    tapStartY = y
                } else if abs(y - tapStartY) > 0.05 {
                    isPotentialLeftTap = false
                }
            }

            if !isSwiping {
                if isTopRight30Edge && isRightEdgeVolumeEnabled {
                    isSwiping = true
                    activeTouchID = touchID
                    startY = y
                    startVolume = AppVolumeManager.shared.getEffectiveVolume()
                    isVolumeDragActive = false
                    foundActiveTouch = true
                    break
                }
            } else {
                if touchID == activeTouchID {
                    foundActiveTouch = true
                    let dy = y - startY
                    let travelMm = dy * trackpadHeightMm

                    // Drag threshold: Require at least 3.0mm vertical movement before activating volume change
                    if !isVolumeDragActive {
                        if abs(travelMm) >= 3.0 {
                            isVolumeDragActive = true
                            startY = y // Re-anchor startY to avoid sudden jump when threshold passed
                            startVolume = AppVolumeManager.shared.getEffectiveVolume()
                        }
                    }

                    if isVolumeDragActive {
                        let activeTravelMm = (y - startY) * trackpadHeightMm
                        let fullRangeMm: Double = 160.0 // Smooth natural scale (160mm for full 0-100% range)

                        let change = max(-0.25, min(0.25, Float(activeTravelMm / fullRangeMm)))
                        let newVol = max(0.0, min(1.0, startVolume + change))

                        AppVolumeManager.shared.setEffectiveVolume(newVol)
                    }
                    break
                }
            }
        }

        if isSwiping && !foundActiveTouch {
            isSwiping = false
            isVolumeDragActive = false
        }
    }
}

private final class ActiveEngineBox {
    private let lock = NSLock()
    private weak var engine: EdgeVolumeEngine?

    func set(_ engine: EdgeVolumeEngine) {
        lock.lock()
        defer { lock.unlock() }
        self.engine = engine
    }

    var current: EdgeVolumeEngine? {
        lock.lock()
        defer { lock.unlock() }
        return engine
    }
}

private let activeEngineBox = ActiveEngineBox()

private let globalMultitouchCallbackRelay: MTContactFrameCallback = { device, touches, count, timestamp, frame in
    activeEngineBox.current?.handleTouches(rawPtr: touches, count: count)
    return 0
}
