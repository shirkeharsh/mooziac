import Foundation

struct PersistedDownloadJob: Codable {
    let taskID: String
    let ytVideoId: String
    let title: String
    let artist: String
    let artworkUrl: String
    let queuedAt: Date
}

enum DownloadQueuePersistence {
    private static var fileURL: URL {
        FileManager.default
            .urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent("Mooziac", isDirectory: true)
            .appendingPathComponent("pending_downloads.json")
    }

    static func save(_ jobs: [PersistedDownloadJob]) {
        let dir = fileURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.download.error("Failed to persist download queue: \(error.localizedDescription)")
        }
    }

    static func load() -> [PersistedDownloadJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([PersistedDownloadJob].self, from: data)
        } catch {
            Log.download.error("Failed to load persisted download queue: \(error.localizedDescription)")
            return []
        }
    }

    static func clear() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            Log.download.error("Failed to clear persisted download queue: \(error.localizedDescription)")
        }
    }
}