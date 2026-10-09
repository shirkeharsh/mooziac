import Foundation

/// Reads and writes the local-file playlist formats supported by Mooziac.
/// JSON files use a small versioned schema; M3U files use UTF-8 paths and
/// standard `#EXTINF` titles.
public enum PlaylistFileCodec {
    public enum Format: String, CaseIterable {
        case m3u8
        case json

        public var fileExtension: String { rawValue }
    }

    public struct Track: Codable, Equatable {
        public let path: String
        public let title: String
        public let artist: String

        public init(path: String, title: String = "", artist: String = "") {
            self.path = path
            self.title = title
            self.artist = artist
        }
    }

    public struct Document: Codable, Equatable {
        public let version: Int
        public let name: String
        public let tracks: [Track]

        public init(version: Int = 1, name: String, tracks: [Track]) {
            self.version = version
            self.name = name
            self.tracks = tracks
        }
    }

    public struct DecodedDocument: Equatable {
        public let document: Document
        public let skippedEntryCount: Int
    }

    public enum CodecError: LocalizedError, Equatable {
        case unsupportedFormat
        case invalidPlaylist(String)
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Choose an M3U, M3U8, or JSON playlist file."
            case .invalidPlaylist(let reason):
                return "The playlist file is invalid. \(reason)"
            case .unsupportedVersion(let version):
                return "This playlist uses an unsupported JSON format version (\(version))."
            }
        }
    }

    private struct JSONDocument: Codable {
        let version: Int
        let name: String
        let tracks: [Track]
    }

    public static func encode(_ document: Document, as format: Format) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(JSONDocument(version: 1, name: document.name, tracks: document.tracks))
        case .m3u8:
            var lines = ["#EXTM3U", "#PLAYLIST:\(singleLine(document.name))"]
            for track in document.tracks {
                guard !track.path.contains("\n"), !track.path.contains("\r") else {
                    throw CodecError.invalidPlaylist("M3U cannot represent a track path containing a newline.")
                }
                let displayName = track.title.isEmpty ? URL(fileURLWithPath: track.path).lastPathComponent : track.title
                lines.append("#EXTINF:-1,\(singleLine(displayName))")
                lines.append(track.path)
            }
            return (lines.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
        }
    }

    public static func decode(_ data: Data, from fileURL: URL) throws -> DecodedDocument {
        switch fileURL.pathExtension.lowercased() {
        case "json":
            return try decodeJSON(data, relativeTo: fileURL.deletingLastPathComponent())
        case "m3u", "m3u8":
            return try decodeM3U(data, relativeTo: fileURL.deletingLastPathComponent())
        default:
            throw CodecError.unsupportedFormat
        }
    }

    private static func decodeJSON(_ data: Data, relativeTo directory: URL) throws -> DecodedDocument {
        let decoded: JSONDocument
        do {
            decoded = try JSONDecoder().decode(JSONDocument.self, from: data)
        } catch {
            throw CodecError.invalidPlaylist("Check the JSON syntax and required fields.")
        }
        guard decoded.version == 1 else { throw CodecError.unsupportedVersion(decoded.version) }
        guard !decoded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodecError.invalidPlaylist("The playlist name is missing.")
        }
        var tracks: [Track] = []
        var skipped = 0
        for track in decoded.tracks {
            guard let path = localPath(track.path, relativeTo: directory) else {
                skipped += 1
                continue
            }
            tracks.append(Track(path: path, title: track.title, artist: track.artist))
        }
        return DecodedDocument(document: Document(name: decoded.name, tracks: tracks), skippedEntryCount: skipped)
    }

    private static func decodeM3U(_ data: Data, relativeTo directory: URL) throws -> DecodedDocument {
        guard var text = String(data: data, encoding: .utf8) else {
            throw CodecError.invalidPlaylist("M3U playlists must be UTF-8 text.")
        }
        if text.first == "\u{feff}" { text.removeFirst() }

        var name = ""
        var pendingTitle = ""
        var tracks: [Track] = []
        var skipped = 0

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#PLAYLIST:") {
                name = String(trimmed.dropFirst("#PLAYLIST:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if trimmed.hasPrefix("#EXTINF:") {
                if let comma = trimmed.firstIndex(of: ",") {
                    pendingTitle = String(trimmed[trimmed.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    pendingTitle = ""
                }
                continue
            }
            if trimmed.hasPrefix("#") { continue }

            if let path = localPath(line, relativeTo: directory) {
                tracks.append(Track(path: path, title: pendingTitle))
            } else {
                skipped += 1
            }
            pendingTitle = ""
        }

        if name.isEmpty { name = directory.lastPathComponent }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodecError.invalidPlaylist("The playlist name is missing.")
        }
        guard !tracks.isEmpty || skipped > 0 else {
            throw CodecError.invalidPlaylist("No local track entries were found.")
        }
        return DecodedDocument(document: Document(name: name, tracks: tracks), skippedEntryCount: skipped)
    }

    private static func localPath(_ value: String, relativeTo directory: URL) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), let scheme = url.scheme?.lowercased() {
            guard scheme == "file", let fileURL = URL(string: value), fileURL.isFileURL else { return nil }
            return fileURL.standardizedFileURL.path
        }
        let url: URL
        if value.hasPrefix("/") {
            url = URL(fileURLWithPath: value)
        } else {
            url = URL(fileURLWithPath: value, relativeTo: directory)
        }
        return url.standardizedFileURL.path
    }

    private static func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
    }
}
