import Foundation

public struct LikedSongRecord {
    public var videoId: String
    public var title: String
    public var artist: String
    public var album: String
    public var artworkUrl: String
    public var duration: Double
    public var dateLiked: Double
    public var synced: Bool
    public var sourceType: String

    public init(videoId: String,
                title: String,
                artist: String = "",
                album: String = "",
                artworkUrl: String = "",
                duration: Double = 0,
                dateLiked: Double = Date().timeIntervalSince1970,
                synced: Bool = false,
                sourceType: String = "ytm") {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.dateLiked = dateLiked
        self.synced = synced
        self.sourceType = sourceType
    }
}