import Foundation

public struct VideoPlaybackState: Equatable {
    public var title: String = ""
    public var channel: String = ""
    public var videoId: String = ""
    public var currentTime: Double = 0.0
    public var duration: Double = 0.0
    public var isPlaying: Bool = false
    public var isMuted: Bool = false
    public var volume: Float = 1.0
    public var playbackRate: Double = 1.0
    public var currentQuality: VideoQuality = .auto
    public var availableQualities: [VideoQuality] = []
    public var is4KAvailable: Bool = false
    public var is4KActive: Bool = false
    public var isAdShowing: Bool = false
    public var isPictureInPicture: Bool = false
    public var isFullscreen: Bool = false
    public var isTheaterMode: Bool = false

    public init() {}

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return max(0.0, min(1.0, currentTime / duration))
    }

    public var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    public var formattedPlaybackSpeed: String {
        playbackRate == 1.0 ? "1.0×" : String(format: "%.2f×", playbackRate)
    }

    public var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
