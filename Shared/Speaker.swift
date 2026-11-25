import AVFoundation

/// Spanish text-to-speech using on-device voices (works offline, no audio files to ship).
///
/// Tip: Settings › Accessibility › Spoken Content › Voices › Spanish lets you download an
/// "Enhanced" or "Premium" voice; `bestVoice` picks the highest quality one installed.
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = Speaker()

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var lastUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak one or more lines in order. `slow` uses ~60% of normal speed.
    func speak(_ lines: [String], slow: Bool = false) {
        activateAudioSession()
        resumeContinuation()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        let voice = Self.bestVoice(for: AppSettings.voice.rawValue)
        let rate = AVSpeechUtteranceDefaultSpeechRate * Float(slow ? 0.6 : AppSettings.speechRate)
        for (i, line) in lines.enumerated() {
            let u = AVSpeechUtterance(string: line)
            u.voice = voice
            u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(rate, AVSpeechUtteranceMaximumSpeechRate))
            u.postUtteranceDelay = i < lines.count - 1 ? 0.45 : 0
            synthesizer.speak(u)
            lastUtterance = u
        }
    }

    func speak(_ text: String, slow: Bool = false) { speak([text], slow: slow) }

    /// Speak and return once speech has finished — used by the widget's App Intent so the
    /// process isn't suspended mid-sentence.
    func speakAndWait(_ lines: [String], slow: Bool = false) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.speak(lines, slow: slow)
                self.finishContinuation = c
            }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: "es-ES")
    }

    static func hasHighQualityVoice(for language: String) -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language == language && $0.quality != .default }
    }

    // MARK: Private

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // .playback so it speaks even with the silent switch on; duck other audio instead of stopping it.
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resumeContinuation() {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === lastUtterance else { return }
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.deactivateAudioSession()
            self.resumeContinuation()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Cancels of an older queue (when a new speak() interrupts) must not end the new one.
        guard utterance === lastUtterance else { return }
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.resumeContinuation()
        }
    }
}
