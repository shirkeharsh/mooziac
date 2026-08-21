import AppKit
import WebKit
import MediaPlayer

class NowPlayingManager: NSObject, WKScriptMessageHandler {
    static let shared = NowPlayingManager()
    
    var currentState = PlaybackState()
    var engineMode: PlaybackEngineMode = .online
    var repeatMode: RepeatMode = .off
    var isShuffleActive: Bool = false
    var observers: [(PlaybackState) -> Void] = []
    
    var lastSavedTitle = ""
    var lastSavedArtist = ""
    var lastIsPlayingState = false
    var lastNowPlayingTrackKey = ""
    
    var isSystemSleeping = false

    public func playOfflineTrack(_ track: LocalTrack, in queue: [LocalTrack] = []) {
        engineMode = .offline
        // Pause online WebKit playback cleanly and immediately
        evaluateJS("""
        (function() {
            try {
                var v = document.querySelector('video');
                if (v) { v.pause(); }
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.pauseVideo === 'function') { p.pauseVideo(); }
            } catch(e) {}
        })();
        """)
        NativeAudioPlayer.shared.play(track: track, in: queue)
        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_EngineModeChanged"), object: nil, userInfo: ["mode": engineMode.rawValue])
    }

    public func switchToOnlineMode() {
        if engineMode == .offline {
            NativeAudioPlayer.shared.pause()
            engineMode = .online
            NotificationCenter.default.post(name: NSNotification.Name("Mooziac_EngineModeChanged"), object: nil, userInfo: ["mode": engineMode.rawValue])
        }
    }

    override init() {
        super.init()
        UserDefaults.standard.removeObject(forKey: "YTM_likedTrackKeysSet")
        UserDefaults.standard.removeObject(forKey: "YTM_lastIsLiked")
        setupSleepObservers()
        setupNetworkObserver()
        setupRemoteCommands()
        DOMHealthMonitor.shared.startMonitoring()
    }

    func setupNetworkObserver() {
        NotificationCenter.default.addObserver(forName: NetworkMonitor.statusChangedNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if !NetworkMonitor.shared.isReachable {
                print("[NowPlayingManager] Network went OFFLINE: switching to offline engine mode")
                self.engineMode = .offline
                if NativeAudioPlayer.shared.currentTrack == nil && !LocalLibraryManager.shared.allTracks.isEmpty {
                    NativeAudioPlayer.shared.primeLastOrFirstTrack()
                }
            }
        }
    }
    
    func setupSleepObservers() {
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isSystemSleeping = true
        }
        wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isSystemSleeping = false
        }
        
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isSystemSleeping = true
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isSystemSleeping = false
        }
    }
    
    func attach(to webView: WKWebView) {
        setupInWebView(webView.configuration.userContentController)
    }
    
    // MARK: - WebContent crash recovery support
    
    // Suppresses messages from the dying WebContent process and re-registers the
    // message bridge so the freshly restored WebContent instance drives state.
    func handleWebContentTermination() {
        print("[NowPlayingManager] WebContent terminated - suppressing stale callbacks and re-wiring bridge")
        isRestoringAfterTermination = true
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else { return }
            self.setupInWebView(mainVC.webViewContainer.webView.configuration.userContentController)
        }
    }
    
    // Re-enables state updates once the restored page has finished loading.
    func markTerminationRecoveryComplete() {
        print("[NowPlayingManager] Recovery complete - re-enabling player state updates")
        isRestoringAfterTermination = false
    }
    

    var currentVideoId = ""
    var lastTrackChangeTime: CFTimeInterval = 0
    var isRestoringAfterTermination = false
    var lastDiscordPresenceKey = ""

    func addObserver(_ observer: @escaping (PlaybackState) -> Void) {
        observers.append(observer)
        observer(currentState)
    }
    
    func notifyObservers(_ state: PlaybackState) {
        for obs in observers {
            obs(state)
        }
        NotificationCenter.default.post(name: NSNotification.Name("Mooziac_PlaybackStateChanged"), object: nil)
        let presenceKey = "\(state.title)|\(state.artist)|\(state.trackID)|\(state.isPlaying)"
        if presenceKey != lastDiscordPresenceKey {
            lastDiscordPresenceKey = presenceKey
            DiscordRPCManager.shared.updatePresence(state: state)
        }
    }
    
    public func trackKey(title: String, artist: String, videoId: String) -> String {
        if !videoId.isEmpty { return "VID_" + videoId }
        let cleanT = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanA = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanT.isEmpty {
            return "TRACK_" + cleanT + "_" + cleanA
        }
        return ""
    }
    
    public func isTrackLiked(title: String, artist: String, videoId: String) -> Bool {
        let key = trackKey(title: title, artist: artist, videoId: videoId)
        guard !key.isEmpty else { return false }
        let likedSet = UserDefaults.standard.stringArray(forKey: "YTM_likedTrackKeysSet") ?? []
        return likedSet.contains(key)
    }
    
    public func setTrackLiked(_ liked: Bool, title: String, artist: String, videoId: String) {
        let key = trackKey(title: title, artist: artist, videoId: videoId)
        guard !key.isEmpty else { return }
        var likedSet = Set(UserDefaults.standard.stringArray(forKey: "YTM_likedTrackKeysSet") ?? [])
        if liked {
            likedSet.insert(key)
        } else {
            likedSet.remove(key)
        }
        UserDefaults.standard.set(Array(likedSet), forKey: "YTM_likedTrackKeysSet")
    }
    

    public func flushSessionState(keepCookies: Bool = true) {
        URLCache.shared.removeAllCachedResponses()
        currentVideoId = ""
        lastSavedTitle = ""
        lastSavedArtist = ""
        currentState = PlaybackState()
        
        let js = """
        (function() {
            try {
                window.ytmObserverInjected = false;
            } catch(e) {}
        })();
        """
        DispatchQueue.main.async {
            StatusItemManager.shared?.mainViewController.webViewContainer.webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        if !keepCookies {
            UserDefaults.standard.removeObject(forKey: "YTM_lastUrl")
            UserDefaults.standard.removeObject(forKey: "YTM_lastVideoId")
            UserDefaults.standard.removeObject(forKey: "YTM_lastTime")
            UserDefaults.standard.removeObject(forKey: "YTM_lastTitle")
            UserDefaults.standard.removeObject(forKey: "YTM_lastArtist")
            UserDefaults.standard.removeObject(forKey: "YTM_lastArtwork")
        }
        print("[NowPlayingManager] Session state and client-side caches flushed cleanly.")
    }
    
    public struct QueueItemInfo {
        public let index: Int
        public let title: String
        public let artist: String
        public let isSelected: Bool
        public let artworkUrl: String
        public let duration: String
        public let videoId: String

        public init(index: Int,
                    title: String,
                    artist: String,
                    isSelected: Bool,
                    artworkUrl: String = "",
                    duration: String = "",
                    videoId: String = "") {
            self.index = index
            self.title = title
            self.artist = artist
            self.isSelected = isSelected
            self.artworkUrl = artworkUrl
            self.duration = duration
            self.videoId = videoId
        }
    }

    public struct AutomixItemInfo {
        public let index: Int
        public let title: String
        public let artist: String
    }

    public struct UpNextSnapshot {
        public var contextTitle: String
        public var autoplayEnabled: Bool
        public var items: [QueueItemInfo]
        public var automixItems: [AutomixItemInfo]
        public var currentTitle: String
        public var currentArtist: String

        public init(contextTitle: String = "",
                    autoplayEnabled: Bool = false,
                    items: [QueueItemInfo] = [],
                    automixItems: [AutomixItemInfo] = [],
                    currentTitle: String = "",
                    currentArtist: String = "") {
            self.contextTitle = contextTitle
            self.autoplayEnabled = autoplayEnabled
            self.items = items
            self.automixItems = automixItems
            self.currentTitle = currentTitle
            self.currentArtist = currentArtist
        }
    }
    

    func evaluateJS(_ code: String) {
        guard !isSystemSleeping else { return }
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else { return }
            mainVC.webViewContainer.webView.evaluateJavaScript(code) { _, error in
                if let error = error {
                    print("[NowPlayingManager] evaluateJS notice: \(error.localizedDescription)")
                }
            }
        }
    }

    func evaluateJSWithResult(_ code: String, completion: ((Any?) -> Void)? = nil) {
        guard !isSystemSleeping else {
            completion?(nil)
            return
        }
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else {
                completion?(nil)
                return
            }
            mainVC.webViewContainer.webView.evaluateJavaScript(code) { result, error in
                if let error = error {
                    print("[NowPlayingManager] evaluateJSWithResult notice: \(error.localizedDescription)")
                }
                completion?(result)
            }
        }
    }
}

extension NowPlayingManager {
    func setupRemoteCommands() {
        let rcc = MPRemoteCommandCenter.shared()

        rcc.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        rcc.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        rcc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        rcc.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }

        rcc.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }

        rcc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: e.positionTime)
            return .success
        }
    }
}
