import AppKit
import AudioToolbox

/// Plays a system audio click sound matching HaptiTrack's launch flourish click.
public final class ClickSound {
    public init() {}
    
    public func play() {
        // System Sound ID 1104 is the classic macOS navigation / mechanical click sound
        AudioServicesPlaySystemSound(1104)
    }
    
    public func stop() {}
}
