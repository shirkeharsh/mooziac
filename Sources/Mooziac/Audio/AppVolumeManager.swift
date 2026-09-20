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
            updateTrackLoudness(trackID: currentTrackID, loudnessDb: currentTrackLoudnessDb, smooth: true)
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: newValue ? "Loudness Leveling: ON" : "Loudness Leveling: OFF")
        }
    }

    public private(set) var currentLoudnessAttenuation: Float = 1.0
    public private(set) var currentTrackLoudnessDb: Double? = nil
    public private(set) var currentTrackID: String? = nil

    private var loudnessCache: [String: Double] = [:]

    public var isAppVolumeOnly: Bool {
        get {
            UserDefaults.standard.object(forKey: "Mooziac_IsAppVolumeOnly") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Mooziac_IsAppVolumeOnly")
            if newValue {
                applyMediaVolume(mediaVolume, smooth: false)
                CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: "Separate App Sound: ON")
            } else {
                resetPlayerVolumeToMax(smooth: false)
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
            applyMediaVolume(clamped, smooth: false)
        }
    }

    private init() {}

    public func getCachedTrackLoudness(id: String) -> Double? {
        guard !id.isEmpty else { return nil }
        return loudnessCache[id]
    }

    public func cacheTrackLoudness(id: String, loudnessDb: Double) {
        guard !id.isEmpty else { return }
        loudnessCache[id] = loudnessDb
    }

    public func prefetchTrackLoudness(videoId: String) {
        guard !videoId.isEmpty, loudnessCache[videoId] == nil else { return }
        YTMClient.shared.fetchDirectStreamURL(videoId: videoId) { [weak self] result in
            if case .success(let stream) = result, let lDb = stream.loudnessDb {
                DispatchQueue.main.async {
                    self?.cacheTrackLoudness(id: videoId, loudnessDb: lDb)
                }
            }
        }
    }

    public func updateTrackLoudness(trackID: String? = nil, loudnessDb: Double?, smooth: Bool = false) {
        if let tid = trackID, !tid.isEmpty {
            self.currentTrackID = tid
            if let lDb = loudnessDb {
                loudnessCache[tid] = lDb
            }
        }

        let resolvedLoudnessDb: Double? = {
            if let lDb = loudnessDb { return lDb }
            if let tid = trackID, !tid.isEmpty { return loudnessCache[tid] }
            return nil
        }()

        self.currentTrackLoudnessDb = resolvedLoudnessDb

        guard isLoudnessNormalizationEnabled else {
            self.currentLoudnessAttenuation = 1.0
            reapplyCurrentVolume(smooth: smooth)
            return
        }

        guard let lDb = resolvedLoudnessDb else {
            // If loudness is not yet known for a new track, maintain current attenuation
            // rather than jumping to 100% and blasting the listener.
            return
        }

        // Target: -14 LUFS (Industry standard streaming target used by YouTube Music, Spotify, etc.)
        // YouTube's `loudnessDb` is the relative offset from target (negative = louder than -14 LUFS).
        // If track is louder than target (e.g. -4.5 dB), reduce volume by 4.5 dB.
        // If track is at or quieter than target (>= -0.2 dB), keep at unity gain (1.0) to prevent clipping distortion.
        if lDb < -0.2 {
            let clampedDb = max(-14.0, min(0.0, lDb))
            self.currentLoudnessAttenuation = Float(pow(10.0, clampedDb / 20.0))
        } else {
            self.currentLoudnessAttenuation = 1.0
        }
        reapplyCurrentVolume(smooth: smooth)
    }

    public func reapplyCurrentVolume(smooth: Bool = false) {
        if isAppVolumeOnly {
            applyMediaVolume(mediaVolume, smooth: smooth)
        } else {
            resetPlayerVolumeToMax(smooth: smooth)
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

    public func applyMediaVolume(_ vol: Float, smooth: Bool = false) {
        let baseVol = max(0.0, min(1.0, vol))
        let effectiveVol = isLoudnessNormalizationEnabled ? max(0.0, min(1.0, baseVol * currentLoudnessAttenuation)) : baseVol

        // 1. Native Offline Audio (AVPlayer)
        NativeAudioPlayer.shared.setVolume(effectiveVol)

        // 2. Online Audio (WebKit video & HTML5 / #movie_player)
        applyWebVolume(effectiveVol, smooth: smooth)
    }

    public func resetPlayerVolumeToMax(smooth: Bool = false) {
        let effectiveVol: Float = isLoudnessNormalizationEnabled ? currentLoudnessAttenuation : 1.0
        NativeAudioPlayer.shared.setVolume(effectiveVol)
        applyWebVolume(effectiveVol, smooth: smooth)
    }

    private func applyWebVolume(_ effectiveVol: Float, smooth: Bool) {
        if smooth {
            let js = """
            (function() {
                var v = document.querySelector('video');
                if (!v) return;
                var startVol = v.volume;
                var targetVol = \(effectiveVol);
                if (Math.abs(startVol - targetVol) < 0.01) {
                    v.volume = targetVol;
                    return;
                }
                var startTime = performance.now();
                var duration = 250;
                function ramp(now) {
                    var elapsed = now - startTime;
                    var progress = Math.min(1.0, elapsed / duration);
                    var ease = 0.5 - 0.5 * Math.cos(Math.PI * progress);
                    v.volume = Math.max(0.0, Math.min(1.0, startVol + (targetVol - startVol) * ease));
                    if (progress < 1.0) {
                        requestAnimationFrame(ramp);
                    } else {
                        v.volume = targetVol;
                        try {
                            var p = document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
                            if (p && typeof p.setVolume === 'function') {
                                p.setVolume(Math.round(targetVol * 100));
                            }
                        } catch(e) {}
                    }
                }
                requestAnimationFrame(ramp);
            })();
            """
            NowPlayingManager.shared.evaluateJS(js)
        } else {
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
}
