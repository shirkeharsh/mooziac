import AppKit

final class DOMHealthMonitor {
    static let shared = DOMHealthMonitor()

    private var consecutiveMisses = 0
    private var lastUpdateReceived = Date()
    private let missThreshold = 3
    private let expectedUpdateInterval: TimeInterval = 10.0
    private var monitorTimer: Timer?

    private init() {}

    func startMonitoring() {
        guard monitorTimer == nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.monitorTimer == nil else { return }
            self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.checkExpectedUpdate()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("Mooziac_DOMHealthDegraded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showDegradedWarning()
        }
    }

    func recordSuccessfulUpdate() {
        consecutiveMisses = 0
        lastUpdateReceived = Date()
    }

    func recordMissedUpdate() {
        consecutiveMisses += 1

        if consecutiveMisses >= missThreshold {
            NotificationCenter.default.post(
                name: Notification.Name("Mooziac_DOMHealthDegraded"),
                object: nil,
                userInfo: [
                    "consecutiveMisses": consecutiveMisses
                ]
            )
        }
    }

    private func checkExpectedUpdate() {
        let np = NowPlayingManager.shared
        guard np.engineMode == .online,
              np.currentState.isPlaying,
              !np.isRestoringAfterTermination else { return }

        if Date().timeIntervalSince(lastUpdateReceived) >= expectedUpdateInterval {
            recordMissedUpdate()
        }
    }

    private func showDegradedWarning() {
        DispatchQueue.main.async {
            guard let mainVC = StatusItemManager.shared?.mainViewController else { return }
            mainVC.dynamicIslandPlayer.showToastBanner(
                message: "YouTube Music update detected — some controls may be affected",
                isWarning: true
            )
        }
    }
}