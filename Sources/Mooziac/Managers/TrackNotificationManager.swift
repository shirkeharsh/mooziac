import AppKit
import UserNotifications

public class TrackNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var lastNotifiedTrack = ""
    
    public override init() {
        super.init()
        setupNotifications()
    }
    
    public func setupNotifications() {
        guard Bundle.main.bundleURL.pathExtension == "app" && NSClassFromString("XCTestCase") == nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Log.general.debug("Notification permission granted")
            } else if let error = error {
                Log.general.error("Permission error: \(error.localizedDescription)")
            }
        }
    }
    
    public func notifyTrackChange(title: String, artist: String, artworkUrl: String) {
        guard !title.isEmpty, title != "Not Playing" else { return }
        
        let trackKey = "\(title)|\(artist)"
        guard trackKey != lastNotifiedTrack else { return }
        lastNotifiedTrack = trackKey
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = artist
        content.body = "Playing on YouTube Music"
        
        if let url = URL(string: artworkUrl) {
            downloadImage(from: url) { [weak self] localUrl in
                if let localUrl = localUrl {
                    do {
                        let attachment = try UNNotificationAttachment(identifier: "albumArt", url: localUrl, options: nil)
                        content.attachments = [attachment]
                    } catch {
                        Log.general.debug("Could not create notification attachment: \(error.localizedDescription)")
                    }
                }
                self?.postNotification(content: content)
            }
        } else {
            postNotification(content: content)
        }
    }
    
    private func postNotification(content: UNMutableNotificationContent) {
        guard Bundle.main.bundleURL.pathExtension == "app" && NSClassFromString("XCTestCase") == nil else { return }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.general.error("Failed to post notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            let tempDir = FileManager.default.temporaryDirectory
            
            // Clean up previous notification temp files to prevent disk clutter
            do {
                let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                for file in files where file.lastPathComponent.hasPrefix("ytm_art_") {
                    do {
                        try FileManager.default.removeItem(at: file)
                    } catch {
                        Log.general.debug("Failed to remove stale notification art \(file.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            } catch {
                Log.general.debug("Failed to inspect temp directory for notification art cleanup: \(error.localizedDescription)")
            }
            
            let fileUrl = tempDir.appendingPathComponent("ytm_art_" + UUID().uuidString + ".jpg")
            do {
                try data.write(to: fileUrl)
                completion(fileUrl)
            } catch {
                Log.general.warning("Failed to write notification art temp file: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    // Show notification even when app is active
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
