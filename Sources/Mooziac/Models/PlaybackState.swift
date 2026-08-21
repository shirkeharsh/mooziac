import Foundation
import QuartzCore

struct PlaybackState {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artworkUrl: String = ""
    var isPlaying: Bool = false
    var currentTime: Double = 0.0
    var duration: Double = 0.0
    var pageUrl: String = ""
    var videoId: String = ""
    var trackID: String = ""
    var hostTimestamp: Double = 0.0 // CACurrentMediaTime when reported
    var playbackRate: Double = 1.0
    var isLiked: Bool = false
    var isShuffleOn: Bool = false
    var isRepeatOn: Bool = false
    var repeatMode: RepeatMode = .off
    var engineMode: PlaybackEngineMode = .online
    
    // Sub-millisecond exact audio time extrapolator
    func getAccurateTime() -> Double {
        guard isPlaying && hostTimestamp > 0 else { return currentTime }
        let delta = CACurrentMediaTime() - hostTimestamp
        return max(0, currentTime + (delta * playbackRate))
    }
}