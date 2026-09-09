import Foundation
import os

enum Log {
    static let general = Logger(subsystem: "app.mooziac.mac", category: "General")
    static let playback = Logger(subsystem: "app.mooziac.mac", category: "Playback")
    static let sync = Logger(subsystem: "app.mooziac.mac", category: "Sync")
    static let download = Logger(subsystem: "app.mooziac.mac", category: "Download")
    static let database = Logger(subsystem: "app.mooziac.mac", category: "Database")
    static let web = Logger(subsystem: "app.mooziac.mac", category: "Web")
}
