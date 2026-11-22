import AppKit

/// Shows "what plays next" in the menu bar overlay (the same spot as the live lyrics).
/// - Automatically a few seconds before the current song ends.
/// - On demand from the menu bar menu ("What's Up Next?").
final class UpNextAlertManager {
    static let shared = UpNextAlertManager()

    private struct NextSong {
        let title: String
        let artist: String
        let isAutoplay: Bool
    }

    private let enabledKey = "Mooziac_isUpNextAlertEnabled"
    private let leadSeconds: Double = 12.0
    private let autoAlertDuration: TimeInterval = 4.5
    private let manualAlertDuration: TimeInterval = 3.5

    private var timer: Timer?
    private var currentSongKey: String = ""
    private var hasAlertedForCurrentSong = false
    private var isFetching = false

    /// On by default.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Automatic alert

    private func tick() {
        guard isEnabled else { return }
        let state = NowPlayingManager.shared.currentState
        guard state.isPlaying, !state.isAd,
              !state.title.isEmpty, state.title != "Not Playing",
              state.duration > 20 else { return }

        let key = "\(state.trackID)|\(state.title)|\(state.artist)"
        if key != currentSongKey {
            currentSongKey = key
            hasAlertedForCurrentSong = false
        }
        guard !hasAlertedForCurrentSong else { return }

        let remaining = state.duration - state.getAccurateTime()
        let lead = min(leadSeconds, state.duration * 0.3)
        guard remaining <= lead, remaining > 1.0 else { return }
        hasAlertedForCurrentSong = true

        // Repeat Song: the next song is the same one, so there is nothing to announce.
        let isRepeatingSong: Bool = {
            if NowPlayingManager.shared.engineMode == .offline {
                return NativeAudioPlayer.shared.repeatMode == .one
            }
            return state.repeatMode == .one
        }()
        guard !isRepeatingSong else { return }

        findNextSong { [weak self] next in
            guard let self = self, let next = next else { return }
            // The song may have changed while we were looking it up.
            let nowState = NowPlayingManager.shared.currentState
            guard "\(nowState.trackID)|\(nowState.title)|\(nowState.artist)" == key else { return }
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                text: self.alertText(for: next),
                duration: self.autoAlertDuration
            )
        }
    }

    // MARK: - On-demand alert

    func showNow() {
        findNextSong { [weak self] next in
            guard let self = self else { return }
            let text = next.map { self.alertText(for: $0) } ?? "Nothing queued next"
            CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(
                text: text,
                duration: self.manualAlertDuration
            )
        }
    }

    // MARK: - Finding the next song

    private func findNextSong(completion: @escaping (NextSong?) -> Void) {
        if NowPlayingManager.shared.engineMode == .offline {
            let player = NativeAudioPlayer.shared
            let list = player.isShuffleActive ? player.shuffledQueue : player.currentQueue
            let nextIndex = player.currentIndex + 1
            if player.currentIndex >= 0, nextIndex < list.count {
                let track = list[nextIndex]
                completion(NextSong(title: track.title, artist: track.artist, isAutoplay: false))
            } else {
                completion(nil)
            }
            return
        }

        guard !isFetching else { return }
        isFetching = true
        NowPlayingManager.shared.fetchUpNextSnapshot { [weak self] snapshot in
            self?.isFetching = false
            let items = snapshot.items
            var currentIndex = items.firstIndex(where: { $0.isSelected })
            if currentIndex == nil {
                let playing = NowPlayingManager.shared.currentState.title.lowercased()
                if !playing.isEmpty {
                    currentIndex = items.firstIndex(where: { $0.title.lowercased() == playing })
                }
            }
            if let currentPos = currentIndex {
                if currentPos + 1 < items.count {
                    let item = items[currentPos + 1]
                    completion(NextSong(title: item.title, artist: item.artist, isAutoplay: false))
                    return
                }
                // The playing song is the last one queued: YouTube Music's autoplay takes over.
                if let suggestion = snapshot.automixItems.first {
                    completion(NextSong(title: suggestion.title, artist: suggestion.artist, isAutoplay: true))
                    return
                }
            }
            completion(nil)
        }
    }

    // MARK: - Text

    private func alertText(for next: NextSong) -> String {
        let title = shorten(next.title, to: 22)
        let artist = shorten(next.artist, to: 14)
        let prefix = next.isAutoplay ? "📻 Autoplay: " : "⏭ Up next: "
        if artist.isEmpty || artist == "Unknown Artist" {
            return "\(prefix)\(title)"
        }
        return "\(prefix)\(title) • \(artist)"
    }

    private func shorten(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)) + "…"
    }
}

// MARK: - Menu bar menu action

extension StatusItemManager {
    @objc func showWhatsUpNextFromMenu() {
        UpNextAlertManager.shared.showNow()
    }
}
