import AppKit
import Foundation
import AVFoundation
import MediaPlayer

public final class NativeAudioPlayer: NSObject {
    public static let shared = NativeAudioPlayer()

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var itemEndObserverToken: Any?

    public private(set) var currentQueue: [LocalTrack] = []
    public private(set) var shuffledQueue: [LocalTrack] = []
    public private(set) var currentIndex: Int = -1
    public private(set) var currentTrack: LocalTrack?
    public private(set) var isPlaying: Bool = false

    public var repeatMode: RepeatMode = .off
    public var isShuffleActive: Bool = false

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        // Ensure player responds cleanly to audio route changes
    }

    // MARK: - Play Track & Queue
    public func play(track: LocalTrack, in queue: [LocalTrack] = []) {
        if !queue.isEmpty {
            self.currentQueue = queue
            if isShuffleActive {
                self.shuffledQueue = queue.shuffled()
            }
        } else if self.currentQueue.isEmpty {
            self.currentQueue = [track]
        }

        let activeList = isShuffleActive ? shuffledQueue : currentQueue
        if let idx = activeList.firstIndex(of: track) {
            self.currentIndex = idx
        } else {
            self.currentIndex = 0
        }

        self.currentTrack = track
        playCurrentTrack()
    }

    public func playNext(track: LocalTrack) {
        if currentQueue.isEmpty {
            play(track: track)
            return
        }

        // Insert immediately after the current playing song
        currentQueue.removeAll(where: { $0.id == track.id })
        let nextIndex = max(0, min(currentQueue.count, currentIndex + 1))
        currentQueue.insert(track, at: nextIndex)

        if isShuffleActive {
            shuffledQueue.removeAll(where: { $0.id == track.id })
            let nextShuffledIndex = max(0, min(shuffledQueue.count, currentIndex + 1))
            shuffledQueue.insert(track, at: nextShuffledIndex)
        }
    }

    public func appendToQueue(track: LocalTrack) {
        if currentQueue.isEmpty {
            play(track: track)
            return
        }
        currentQueue.removeAll(where: { $0.id == track.id })
        currentQueue.append(track)
        if isShuffleActive {
            shuffledQueue.removeAll(where: { $0.id == track.id })
            shuffledQueue.append(track)
        }
    }

    public func updateQueueOrder(newOrder: [LocalTrack]) {
        guard !newOrder.isEmpty else { return }
        self.currentQueue = newOrder
        if let current = currentTrack, let idx = newOrder.firstIndex(of: current) {
            self.currentIndex = idx
        }
        if isShuffleActive {
            var newShuffled = newOrder.filter { $0 != currentTrack }.shuffled()
            if let current = currentTrack {
                let insertIdx = min(currentIndex, newShuffled.count)
                newShuffled.insert(current, at: insertIdx)
            }
            self.shuffledQueue = newShuffled
        }
    }

    public func handleTrackDeleted(trackID: String) {
        currentQueue.removeAll(where: { $0.id == trackID })
        shuffledQueue.removeAll(where: { $0.id == trackID })

        if currentTrack?.id == trackID {
            let wasPlaying = isPlaying
            player?.pause()
            isPlaying = false
            player?.replaceCurrentItem(with: nil)
            currentTrack = nil

            if UserDefaults.standard.string(forKey: "Mooziac_LastPlayedLocalTrackId") == trackID {
                UserDefaults.standard.removeObject(forKey: "Mooziac_LastPlayedLocalTrackId")
                UserDefaults.standard.removeObject(forKey: "Mooziac_LastPlayedLocalTrackTitle")
            }

            let activeList = isShuffleActive ? shuffledQueue : currentQueue
            if !activeList.isEmpty {
                if currentIndex >= activeList.count {
                    currentIndex = 0
                }
                currentTrack = activeList[currentIndex]
                if wasPlaying {
                    playCurrentTrack()
                } else {
                    broadcastPlaybackState(currentTime: 0.0)
                }
            } else {
                currentIndex = -1
                var state = PlaybackState()
                state.title = "Not Playing"
                state.artist = "No Track Selected"
                state.isPlaying = false
                state.currentTime = 0.0
                state.duration = 0.0
                state.playbackRate = 0.0
                state.isShuffleOn = isShuffleActive
                state.isRepeatOn = (repeatMode != .off)
                state.repeatMode = self.repeatMode
                NowPlayingManager.shared.currentState = state
                NowPlayingManager.shared.notifyObservers(state)
                NowPlayingManager.shared.updateSystemNowPlayingInfo(state)
            }
        } else {
            let activeList = isShuffleActive ? shuffledQueue : currentQueue
            if let curr = currentTrack, let idx = activeList.firstIndex(of: curr) {
                currentIndex = idx
            }
        }
    }

    // MARK: - Auto Offline Helpers
    public func primeLastOrFirstTrack() {
        let tracks = LocalLibraryManager.shared.allTracks
        guard !tracks.isEmpty else { return }
        self.currentQueue = tracks
        if isShuffleActive {
            self.shuffledQueue = tracks.shuffled()
        }

        let lastId = UserDefaults.standard.string(forKey: "Mooziac_LastPlayedLocalTrackId")
        let activeList = isShuffleActive ? shuffledQueue : currentQueue
        let targetIndex = activeList.firstIndex(where: { $0.id == lastId }) ?? 0

        self.currentIndex = targetIndex
        self.currentTrack = activeList[targetIndex]
        self.isPlaying = false

        // Broadcast metadata so player UI shows the track immediately only if in offline mode
        if NowPlayingManager.shared.engineMode == .offline {
            broadcastPlaybackState(currentTime: 0.0)
        }
    }

    public func playLastOrFirstTrack() {
        let tracks = LocalLibraryManager.shared.allTracks
        guard !tracks.isEmpty else {
            print("[NativeAudioPlayer] No offline tracks available in library")
            return
        }
        self.currentQueue = tracks
        if isShuffleActive {
            self.shuffledQueue = tracks.shuffled()
        }

        let lastId = UserDefaults.standard.string(forKey: "Mooziac_LastPlayedLocalTrackId")
        let activeList = isShuffleActive ? shuffledQueue : currentQueue
        let targetIndex = activeList.firstIndex(where: { $0.id == lastId }) ?? 0

        self.currentIndex = targetIndex
        self.currentTrack = activeList[targetIndex]
        playCurrentTrack()
    }

    private func playCurrentTrack() {
        guard let track = currentTrack else { return }

        // Persist last played track ID
        UserDefaults.standard.set(track.id, forKey: "Mooziac_LastPlayedLocalTrackId")
        UserDefaults.standard.set(track.title, forKey: "Mooziac_LastPlayedLocalTrackTitle")

        cleanupObservers()

        let playerItem = AVPlayerItem(url: track.fileURL)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        if AppVolumeManager.shared.isAppVolumeOnly {
            player?.volume = AppVolumeManager.shared.mediaVolume
        } else {
            player?.volume = 1.0
        }

        setupTimeObserver()
        setupEndObserver()

        // Ensure WebKit online playback is paused when offline audio begins
        NowPlayingManager.shared.engineMode = .offline
        NowPlayingManager.shared.evaluateJS("""
        (function() {
            try {
                var v = document.querySelector('video');
                if (v) { v.pause(); }
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.pauseVideo === 'function') { p.pauseVideo(); }
            } catch(e) {}
        })();
        """)

        player?.play()
        self.isPlaying = true

        // Log track to Listening History
        HistoryManager.shared.trackDidStartOffline(track)

        // Push state to NowPlayingManager
        broadcastPlaybackState(currentTime: 0.0)
    }

    // MARK: - Playback Controls
    public func play() {
        guard currentTrack != nil else {
            playLastOrFirstTrack()
            return
        }
        NowPlayingManager.shared.engineMode = .offline
        NowPlayingManager.shared.evaluateJS("""
        (function() {
            try {
                var v = document.querySelector('video');
                if (v) { v.pause(); }
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.pauseVideo === 'function') { p.pauseVideo(); }
            } catch(e) {}
        })();
        """)
        player?.play()
        isPlaying = true
        broadcastPlaybackState(currentTime: getCurrentTime())
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        if NowPlayingManager.shared.engineMode == .offline {
            broadcastPlaybackState(currentTime: getCurrentTime())
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func nextTrack() {
        let activeList = isShuffleActive ? shuffledQueue : currentQueue
        guard !activeList.isEmpty else { return }

        if currentIndex + 1 < activeList.count {
            currentIndex += 1
            currentTrack = activeList[currentIndex]
            playCurrentTrack()
        } else if repeatMode == .one {
            seek(to: 0)
            play()
        } else {
            // Loop back to start of playlist
            currentIndex = 0
            currentTrack = activeList[0]
            playCurrentTrack()
        }
    }

    public func previousTrack() {
        let currTime = getCurrentTime()
        if currTime > 3.0 {
            seek(to: 0)
            return
        }

        let activeList = isShuffleActive ? shuffledQueue : currentQueue
        guard !activeList.isEmpty else { return }

        if currentIndex > 0 {
            currentIndex -= 1
            currentTrack = activeList[currentIndex]
            playCurrentTrack()
        } else {
            seek(to: 0)
        }
    }

    public func seek(to seconds: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.broadcastPlaybackState(currentTime: seconds)
        }
    }

    public func fastForward(seconds: Double = 10.0) {
        let curr = getCurrentTime()
        let dur = currentTrack?.duration ?? 0.0
        seek(to: min(dur, curr + seconds))
    }

    public func rewind(seconds: Double = 10.0) {
        let curr = getCurrentTime()
        seek(to: max(0.0, curr - seconds))
    }

    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        broadcastPlaybackState(currentTime: getCurrentTime())
    }

    public func setShuffleState(_ active: Bool) {
        self.isShuffleActive = active
        if active {
            self.shuffledQueue = currentQueue.shuffled()
            if let curr = currentTrack, let idx = shuffledQueue.firstIndex(of: curr) {
                currentIndex = idx
            }
        } else {
            if let curr = currentTrack, let idx = currentQueue.firstIndex(of: curr) {
                currentIndex = idx
            }
        }
        broadcastPlaybackState(currentTime: getCurrentTime())
    }

    public func setVolume(_ volume: Float) {
        player?.volume = max(0.0, min(1.0, volume))
    }

    public func getCurrentTime() -> Double {
        guard let player = player else { return 0.0 }
        let sec = CMTimeGetSeconds(player.currentTime())
        return (sec.isNaN || sec.isInfinite) ? 0.0 : sec
    }

    public func getDuration() -> Double {
        if let dur = currentTrack?.duration, dur > 0 { return dur }
        guard let item = player?.currentItem else { return 0.0 }
        let sec = CMTimeGetSeconds(item.duration)
        return (sec.isNaN || sec.isInfinite) ? 0.0 : sec
    }

    // MARK: - Observers
    private func setupTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isPlaying else { return }
            let sec = CMTimeGetSeconds(time)
            if !sec.isNaN && !sec.isInfinite {
                self.broadcastPlaybackState(currentTime: sec)
            }
        }
    }

    private func setupEndObserver() {
        guard let item = player?.currentItem else { return }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.repeatMode == .one {
                self.seek(to: 0)
                self.play()
            } else {
                self.nextTrack()
            }
        }
    }

    private func cleanupObservers() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    public func toggleLike() {
        guard let track = currentTrack else { return }
        LocalLibraryManager.shared.toggleLike(for: track.id)
    }

    public func updateLikedState(isLiked: Bool) {
        if var track = currentTrack {
            track.isLiked = isLiked
            self.currentTrack = track
            broadcastPlaybackState(currentTime: getCurrentTime())
        }
    }

    // MARK: - Broadcast State to Mooziac UI & System
    public func broadcastPlaybackState(currentTime: Double) {
        guard NowPlayingManager.shared.engineMode == .offline else { return }
        guard let track = currentTrack else { return }
        let dur = getDuration()

        var state = PlaybackState()
        state.title = track.title
        state.artist = track.artist
        state.album = track.album
        state.artworkUrl = track.artworkURL?.absoluteString ?? ""
        state.isPlaying = self.isPlaying
        state.currentTime = currentTime
        state.duration = dur
        state.pageUrl = track.fileURL.absoluteString
        state.videoId = track.id
        state.trackID = track.id
        state.hostTimestamp = CACurrentMediaTime()
        state.playbackRate = isPlaying ? 1.0 : 0.0
        state.isLiked = track.isLiked
        state.isShuffleOn = isShuffleActive
        state.isRepeatOn = (repeatMode != .off)
        state.repeatMode = self.repeatMode

        NowPlayingManager.shared.currentState = state
        NowPlayingManager.shared.notifyObservers(state)
        NowPlayingManager.shared.updateSystemNowPlayingInfo(state)

        // If track has artwork image, set it in MPRemoteCommandCenter
        if let artImg = track.artwork {
            let center = MPNowPlayingInfoCenter.default()
            var info = center.nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artImg.size) { _ in artImg }
            center.nowPlayingInfo = info
        }
    }
}
