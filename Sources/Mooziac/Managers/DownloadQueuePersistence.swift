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

        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        guard let data = try? JSONEncoder().encode(jobs)
        else { return }

        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> [PersistedDownloadJob] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let jobs =
                try? JSONDecoder().decode(
                    [PersistedDownloadJob].self,
                    from: data
                )
        else {
            return []
        }

        return jobs
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}