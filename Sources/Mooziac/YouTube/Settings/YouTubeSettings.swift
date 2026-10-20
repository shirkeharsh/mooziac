import Foundation

public typealias AppSettings = YouTubeSettings

public final class YouTubeSettings {
    public static let shared = YouTubeSettings()

    public static let adBlockDidChangeNotification = Notification.Name("YouTubeSettingsAdBlockDidChangeNotification")
    public static let sponsorBlockDidChangeNotification = Notification.Name("YouTubeSettingsSponsorBlockDidChangeNotification")
    public static let distractionFreeDidChangeNotification = Notification.Name("YouTubeSettingsDistractionFreeDidChangeNotification")
    public static let extensionsDidChangeNotification = Notification.Name("YouTubeSettingsExtensionsDidChangeNotification")
    public static let themeDidChangeNotification = Notification.Name("YouTubeSettingsThemeDidChangeNotification")

    private enum Keys {
        static let isAdBlockEnabled = "app.mooziac.youtube.settings.adBlockEnabled"
        static let isSponsorBlockEnabled = "app.mooziac.youtube.settings.sponsorBlockEnabled"
        static let isDistractionFreeEnabled = "app.mooziac.youtube.settings.distractionFreeEnabled"
        static let defaultPlaybackSpeed = "app.mooziac.youtube.settings.defaultPlaybackSpeed"
        static let playerTheme = "app.mooziac.youtube.settings.playerTheme"
        static let hasUserExplicitlySetAdBlock = "app.mooziac.youtube.settings.hasUserExplicitlySetAdBlock"
    }

    private let defaults = UserDefaults.standard

    private init() {
        // Register default values
        defaults.register(defaults: [
            Keys.isAdBlockEnabled: true,
            Keys.isSponsorBlockEnabled: true,
            Keys.isDistractionFreeEnabled: false,
            Keys.defaultPlaybackSpeed: 1.0,
            Keys.playerTheme: PlayerTheme.liquidFluid.rawValue,
            Keys.hasUserExplicitlySetAdBlock: false
        ])
    }

    public var currentTheme: PlayerTheme {
        get {
            let saved = defaults.string(forKey: Keys.playerTheme) ?? PlayerTheme.liquidFluid.rawValue
            return PlayerTheme(rawValue: saved) ?? .liquidFluid
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.playerTheme)
            NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: newValue)
        }
    }

    public var hasUserExplicitlySetAdBlock: Bool {
        get { defaults.bool(forKey: Keys.hasUserExplicitlySetAdBlock) }
        set { defaults.set(newValue, forKey: Keys.hasUserExplicitlySetAdBlock) }
    }

    public var isAdBlockEnabled: Bool {
        get { defaults.bool(forKey: Keys.isAdBlockEnabled) }
        set {
            hasUserExplicitlySetAdBlock = true
            defaults.set(newValue, forKey: Keys.isAdBlockEnabled)
            NotificationCenter.default.post(name: Self.adBlockDidChangeNotification, object: newValue)
        }
    }

    public var isSponsorBlockEnabled: Bool {
        get { defaults.bool(forKey: Keys.isSponsorBlockEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.isSponsorBlockEnabled)
            NotificationCenter.default.post(name: Self.sponsorBlockDidChangeNotification, object: newValue)
        }
    }

    public var isDistractionFreeEnabled: Bool {
        get { defaults.bool(forKey: Keys.isDistractionFreeEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.isDistractionFreeEnabled)
            NotificationCenter.default.post(name: Self.distractionFreeDidChangeNotification, object: newValue)
        }
    }

    public var defaultPlaybackSpeed: Double {
        get {
            let val = defaults.double(forKey: Keys.defaultPlaybackSpeed)
            return val > 0 ? val : 1.0
        }
        set {
            defaults.set(newValue, forKey: Keys.defaultPlaybackSpeed)
        }
    }

    /// When user signs in, if they haven't explicitly manually forced ad-blocking, default to OFF
    public func applySignedInDefaultsIfNeeded() {
        guard !hasUserExplicitlySetAdBlock else { return }
        defaults.set(false, forKey: Keys.isAdBlockEnabled)
        defaults.set(false, forKey: Keys.isSponsorBlockEnabled)
        NotificationCenter.default.post(name: Self.adBlockDidChangeNotification, object: false)
        NotificationCenter.default.post(name: Self.sponsorBlockDidChangeNotification, object: false)
    }
}
