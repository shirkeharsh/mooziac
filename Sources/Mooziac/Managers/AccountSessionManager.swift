import Foundation
import WebKit

/// Manages the single shared Google / YouTube / YouTube Music session across the app.
/// Both `YTMWebViewContainer` and `YouTubeWebView` use `WKWebsiteDataStore.default()`,
/// so signing in once authenticates both Music Player and YouTube Mode.
public final class AccountSessionManager {
    public static let shared = AccountSessionManager()

    private enum Keys {
        static let displayIdentity = "Mooziac_AccountDisplayIdentity"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.removeObject(forKey: "Mooziac_AccountProfiles_v1")
        defaults.removeObject(forKey: "Mooziac_ActiveAccountID_v1")
    }

    public var sharedDataStore: WKWebsiteDataStore {
        .default()
    }

    public var displayIdentity: String? {
        let raw = defaults.string(forKey: Keys.displayIdentity)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }

    public func updateDisplayIdentity(_ identity: String?) {
        let clean = identity?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let clean, !clean.isEmpty else { return }
        if defaults.string(forKey: Keys.displayIdentity) != clean {
            defaults.set(clean, forKey: Keys.displayIdentity)
        }
    }

    public func clearSharedSession(completion: @escaping () -> Void) {
        let store = sharedDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { [weak self] records in
            store.removeData(ofTypes: types, for: records) {
                self?.defaults.removeObject(forKey: Keys.displayIdentity)
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}
