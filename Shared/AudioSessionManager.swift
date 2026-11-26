import AVFoundation

/// One place that turns the audio session on and off, for the voice, quiz sounds and the mic.
///
/// Switching the session is a blocking system call (Xcode warns when it happens on the main
/// thread), so it's done as rarely as possible: the session is switched on once and left on
/// while audio keeps coming, the category only changes when it's different, and it's switched
/// off on a background queue a moment after the last sound — cancelled if more audio starts.
final class AudioSessionManager: @unchecked Sendable {
    static let shared = AudioSessionManager()

    /// Speech playback: plays with the silent switch on, ducks other audio.
    static let playback: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions) =
        (.playback, .spokenAudio, [.duckOthers])
    /// Listening for her answer (and hearing the reply through the speaker).
    static let listening: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions) =
        (.playAndRecord, .measurement, [.defaultToSpeaker, .duckOthers, .allowBluetooth])

    private let queue = DispatchQueue(label: "palabra.audio-session")
    private var isActive = false
    private var pendingOff: DispatchWorkItem?

    /// Makes sure the session is on with this configuration. Returns false if it couldn't be.
    @discardableResult
    func activate(_ config: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions) = playback) -> Bool {
        queue.sync {
            pendingOff?.cancel()
            pendingOff = nil
            let session = AVAudioSession.sharedInstance()
            do {
                if session.category != config.0 || session.mode != config.1 || session.categoryOptions != config.2 {
                    try session.setCategory(config.0, mode: config.1, options: config.2)
                }
                if !isActive {
                    try session.setActive(true)
                    isActive = true
                }
                return true
            } catch {
                return false
            }
        }
    }

    /// Switches the session off shortly, on a background queue, unless audio starts again first.
    func deactivateSoon(after delay: TimeInterval = 1.5) {
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.isActive = false
        }
        queue.sync {
            pendingOff?.cancel()
            pendingOff = item
        }
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
