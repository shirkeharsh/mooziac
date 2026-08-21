import AppKit
import WebKit
import AVFoundation

public final class AppVolumeManager {
    public static let shared = AppVolumeManager()

    public var isAppVolumeOnly: Bool {
        get {
            UserDefaults.standard.object(forKey: "Mooziac_IsAppVolumeOnly") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Mooziac_IsAppVolumeOnly")
            if newValue {
                applyMediaVolume(mediaVolume)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Separate App Sound: ON")
            } else {
                resetPlayerVolumeToMax()
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "System Sound: ON")
            }
        }
    }

    public var mediaVolume: Float {
        get {
            if let v = UserDefaults.standard.object(forKey: "Mooziac_MediaVolume") as? Float {
                return max(0.0, min(1.0, v))
            }
            return 1.0
        }
        set {
            let clamped = max(0.0, min(1.0, newValue))
            UserDefaults.standard.set(clamped, forKey: "Mooziac_MediaVolume")
            applyMediaVolume(clamped)
        }
    }

    private init() {}

    public func getEffectiveVolume() -> Float {
        if isAppVolumeOnly {
            return mediaVolume
        } else {
            return VolumeController.shared.getVolume()
        }
    }

    public func setEffectiveVolume(_ vol: Float) {
        let clamped = max(0.0, min(1.0, vol))
        if isAppVolumeOnly {
            self.mediaVolume = clamped
            let percent = Int(round(clamped * 100))
            DispatchQueue.main.async {
                CenteredMenuBarLyricsWindowController.shared.showVolumeOverlay(volumePercent: percent, isAppOnly: true)
            }
        } else {
            VolumeController.shared.setVolume(clamped)
            let percent = Int(round(clamped * 100))
            DispatchQueue.main.async {
                CenteredMenuBarLyricsWindowController.shared.showVolumeOverlay(volumePercent: percent, isAppOnly: false)
            }
        }
    }

    public func applyMediaVolume(_ vol: Float) {
        // 1. Native Offline Audio (AVPlayer)
        NativeAudioPlayer.shared.setVolume(vol)

        // 2. Online Audio (WebKit video & HTML5 / #movie_player)
        let js = """
        (function() {
            var v = document.querySelector('video');
            if (v) { v.volume = \(vol); }
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(\(Int(vol * 100)));
                }
            } catch(e) {}
        })();
        """
        NowPlayingManager.shared.evaluateJS(js)
    }

    public func resetPlayerVolumeToMax() {
        NativeAudioPlayer.shared.setVolume(1.0)
        let js = """
        (function() {
            var v = document.querySelector('video');
            if (v) { v.volume = 1.0; }
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(100);
                }
            } catch(e) {}
        })();
        """
        NowPlayingManager.shared.evaluateJS(js)
    }
}
