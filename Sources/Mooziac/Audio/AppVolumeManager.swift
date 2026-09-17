import AppKit
import WebKit
import AVFoundation

public final class AppVolumeManager {
    public static let shared = AppVolumeManager()

    public var isLoudnessNormalizationEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "Mooziac_LoudnessNormalizationEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Mooziac_LoudnessNormalizationEnabled")
            updateTrackLoudness(loudnessDb: currentTrackLoudnessDb)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: newValue ? "Loudness Leveling: ON" : "Loudness Leveling: OFF")
        }
    }

    public private(set) var currentLoudnessAttenuation: Float = 1.0
    public private(set) var currentTrackLoudnessDb: Double? = nil

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

    public func updateTrackLoudness(loudnessDb: Double?) {
        self.currentTrackLoudnessDb = loudnessDb
        guard isLoudnessNormalizationEnabled, let lDb = loudnessDb else {
            self.currentLoudnessAttenuation = 1.0
            reapplyCurrentVolume()
            return
        }

        // Loudness target: -7.0 LUFS (matches YouTube Music web target rather than video site -14.0)
        // Perceptual LUFS = loudnessDb - 14.0
        // Gain = TARGET_LUFS - perceptualLUFS
        let targetLUFS = -7.0
        let perceptualLUFS = lDb - 14.0
        let gainDb = targetLUFS - perceptualLUFS
        if gainDb < -0.05 {
            let clampedGainDb = max(-24.0, gainDb)
            self.currentLoudnessAttenuation = Float(pow(10.0, clampedGainDb / 20.0))
        } else {
            self.currentLoudnessAttenuation = 1.0
        }
        reapplyCurrentVolume()
    }

    public func reapplyCurrentVolume() {
        if isAppVolumeOnly {
            applyMediaVolume(mediaVolume)
        } else {
            resetPlayerVolumeToMax()
        }
    }

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
        let baseVol = max(0.0, min(1.0, vol))
        let effectiveVol = isLoudnessNormalizationEnabled ? max(0.0, min(1.0, baseVol * currentLoudnessAttenuation)) : baseVol

        // 1. Native Offline Audio (AVPlayer)
        NativeAudioPlayer.shared.setVolume(effectiveVol)

        // 2. Online Audio (WebKit video & HTML5 / #movie_player)
        let js = """
        (function() {
            var v = document.querySelector('video');
            if (v) { v.volume = \(effectiveVol); }
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(\(Int(round(effectiveVol * 100))));
                }
            } catch(e) {}
        })();
        """
        NowPlayingManager.shared.evaluateJS(js)
    }

    public func resetPlayerVolumeToMax() {
        let effectiveVol: Float = isLoudnessNormalizationEnabled ? currentLoudnessAttenuation : 1.0
        NativeAudioPlayer.shared.setVolume(effectiveVol)
        let js = """
        (function() {
            var v = document.querySelector('video');
            if (v) { v.volume = \(effectiveVol); }
            try {
                var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(\(Int(round(effectiveVol * 100))));
                }
            } catch(e) {}
        })();
        """
        NowPlayingManager.shared.evaluateJS(js)
    }
}
