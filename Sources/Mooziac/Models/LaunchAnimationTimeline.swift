import Foundation

/// Timeline for the HaptiTrack-style intro animation.
struct LaunchAnimationTimeline: Equatable {
    var fadeIn: TimeInterval = 0.45
    var pulseCount: Int = 2
    var firstPulse: TimeInterval = 0.35
    var pulseInterval: TimeInterval = 0.55
    var pulseRise: TimeInterval = 0.25
    var pulseFall: TimeInterval = 0.35
    var hold: TimeInterval = 0.22
    var fadeOut: TimeInterval = 0.55

    func pulseTime(_ index: Int) -> TimeInterval {
        firstPulse + Double(index) * pulseInterval
    }

    var pulseTimes: [TimeInterval] {
        (0..<max(pulseCount, 0)).map(pulseTime)
    }

    var fadeOutStart: TimeInterval {
        (pulseTimes.last ?? fadeIn) + pulseRise + pulseFall + hold
    }

    var total: TimeInterval { fadeOutStart + fadeOut }
}
