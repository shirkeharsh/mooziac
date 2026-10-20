import Foundation
import os

public enum Log {
    private static let subsystem = "app.mooziac.mac"

    public static let general = Logger(subsystem: subsystem, category: "General")
    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let playback = Logger(subsystem: subsystem, category: "Playback")
    public static let player = Logger(subsystem: subsystem, category: "Player")
    public static let sync = Logger(subsystem: subsystem, category: "Sync")
    public static let download = Logger(subsystem: subsystem, category: "Download")
    public static let database = Logger(subsystem: subsystem, category: "Database")
    public static let web = Logger(subsystem: subsystem, category: "Web")
    public static let audio = Logger(subsystem: subsystem, category: "Audio")
    public static let gestures = Logger(subsystem: subsystem, category: "Gestures")
    public static let quality = Logger(subsystem: subsystem, category: "Quality")
    public static let adblock = Logger(subsystem: subsystem, category: "AdBlock")
}
