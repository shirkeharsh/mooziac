import AppKit
import Foundation
import AVFoundation

public struct LocalTrack: Identifiable, Equatable {
    public let id: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public let fileURL: URL
    private var _artwork: NSImage?
    public var artwork: NSImage? {
        get {
            if let custom = _artwork { return custom }
            return AppArtworkHelper.shared.getThumbnail(for: self)
        }
        set {
            _artwork = newValue
        }
    }
    public var artworkURL: URL?
    public var lrcURL: URL?
    public var dateAdded: Date
    public var ytVideoId: String?
    public var isLiked: Bool {
        get {
            return LocalLibraryManager.shared.isLiked(trackID: id)
        }
        set {
            if newValue != LocalLibraryManager.shared.isLiked(trackID: id) {
                LocalLibraryManager.shared.toggleLike(for: id)
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String = "",
        duration: Double = 0.0,
        fileURL: URL,
        artwork: NSImage? = nil,
        artworkURL: URL? = nil,
        lrcURL: URL? = nil,
        isLiked: Bool = false,
        dateAdded: Date = Date(),
        ytVideoId: String? = nil
    ) {
        self.id = id
        self.title = title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : title
        self.artist = artist.isEmpty ? "Local Audio" : artist
        self.album = album
        self.duration = duration
        self.fileURL = fileURL
        self._artwork = artwork
        self.artworkURL = artworkURL
        self.lrcURL = lrcURL
        self.dateAdded = dateAdded
        self.ytVideoId = ytVideoId
    }

    public var cleanTitle: String {
        return LyricsManager.cleanSongInfo(title)
    }

    public var cleanArtist: String {
        return LyricsManager.cleanSongInfo(artist)
    }

    public static func == (lhs: LocalTrack, rhs: LocalTrack) -> Bool {
        return lhs.id == rhs.id || lhs.fileURL == rhs.fileURL
    }
}
