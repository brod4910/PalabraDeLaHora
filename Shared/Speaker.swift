import AVFoundation

/// Spanish speech. Plays the pre-recorded clips (`RecordedVoice`, from tools/generate_audio.py)
/// when every line has one, otherwise the on-device voice (works offline, nothing to ship).
///
/// Tip: Settings › Accessibility › Spoken Content › Voices › Spanish lets you download an
/// "Enhanced" or "Premium" voice; `bestVoice` picks the highest quality one installed.
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    static let shared = Speaker()

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var lastUtterance: AVSpeechUtterance?

    // Recorded clips: the one playing and the ones still to play (url, speed, pause after).
    private var player: AVAudioPlayer?
    private var clipQueue: [(url: URL, rate: Float, pause: TimeInterval)] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak one or more lines in order. `slow` uses ~60% of normal speed.
    func speak(_ lines: [String], slow: Bool = false) {
        activateAudioSession()
        resumeContinuation()
        stopAll()

        // A recording for every line: words slow = the syllable-by-syllable clip; sentences slow =
        // the normal clip at 75% speed (pitch kept).
        if RecordedVoice.isEnabled {
            var plan: [(url: URL, rate: Float, pause: TimeInterval)] = []
            for line in lines {
                if slow, let url = RecordedVoice.url(for: line, slow: true) {
                    plan.append((url, 1.0, 0.6))
                } else if let url = RecordedVoice.url(for: line) {
                    plan.append((url, slow ? 0.75 : Self.recordingRate, slow ? 0.6 : 0.45))
                } else {
                    plan = []; break
                }
            }
            if !plan.isEmpty {
                play(plan)
                return
            }
        }

        let voice = Self.bestVoice(for: AppSettings.voice.rawValue)
        let normalRate = AVSpeechUtteranceDefaultSpeechRate * Float(AppSettings.speechRate)
        // Slow is a fixed, clearly slower rate (not relative to the user's speed setting)…
        let slowRate = AVSpeechUtteranceMinimumSpeechRate
            + (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * 0.35
        let rate = max(AVSpeechUtteranceMinimumSpeechRate, min(slow ? slowRate : normalRate, AVSpeechUtteranceMaximumSpeechRate))

        // …but `rate` alone is ignored by some voices / iOS builds, so slow mode also inserts real
        // pauses: syllables for a word ("que · rer … querer"), word by word for a sentence.
        var utterances: [AVSpeechUtterance] = []
        for (i, line) in lines.enumerated() {
            let isLast = i == lines.count - 1
            if slow {
                if let u = AVSpeechUtterance(ssmlRepresentation: SlowSpeech.ssml(for: line)) {
                    u.postUtteranceDelay = isLast ? 0 : 0.6
                    utterances.append(u)
                } else {
                    // SSML unavailable: one utterance per chunk, with pauses between.
                    let chunks = SlowSpeech.chunks(for: line)
                    for (j, chunk) in chunks.enumerated() {
                        let u = AVSpeechUtterance(string: chunk.text)
                        let isFinalChunk = j == chunks.count - 1
                        u.postUtteranceDelay = isFinalChunk ? (isLast ? 0 : 0.6) : chunk.pause
                        utterances.append(u)
                    }
                }
            } else {
                let u = AVSpeechUtterance(string: line)
                u.postUtteranceDelay = isLast ? 0 : 0.45
                utterances.append(u)
            }
        }
        for u in utterances {
            u.voice = voice
            u.rate = rate
            synthesizer.speak(u)
        }
        lastUtterance = utterances.last
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

    /// One piece of a mixed-language prompt, e.g. English "How do you say" + Spanish answer.
    struct Part {
        let text: String
        /// BCP-47 language; nil = the learner's chosen Spanish voice.
        var language: String? = nil
        var pause: TimeInterval = 0.25

        static func english(_ text: String, pause: TimeInterval = 0.25) -> Part { Part(text: text, language: "en-US", pause: pause) }
        static func spanish(_ text: String, pause: TimeInterval = 0.25) -> Part { Part(text: text, language: nil, pause: pause) }
    }

    /// Speaks the parts in order (each in its own voice) and returns when done or stopped.
    func say(_ parts: [Part]) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.activateAudioSession()
                self.resumeContinuation()
                self.stopAll()
                // All Spanish and all recorded (key forms' "Play all"): play the clips.
                if RecordedVoice.isEnabled, parts.allSatisfy({ $0.language == nil }) {
                    let plan = parts.compactMap { p in RecordedVoice.url(for: p.text).map { (url: $0, rate: Self.recordingRate, pause: p.pause) } }
                    if plan.count == parts.count, !plan.isEmpty {
                        self.play(plan)
                        self.finishContinuation = c
                        return
                    }
                }
                var last: AVSpeechUtterance?
                for part in parts where !part.text.isEmpty {
                    let u = AVSpeechUtterance(string: part.text)
                    let language = part.language ?? AppSettings.voice.rawValue
                    u.voice = Self.bestVoice(for: language)
                    let multiplier = part.language == nil ? Float(AppSettings.speechRate) : 1.0
                    u.rate = AVSpeechUtteranceDefaultSpeechRate * multiplier
                    u.postUtteranceDelay = part.pause
                    self.synthesizer.speak(u)
                    last = u
                }
                guard let last else { c.resume(); return }
                self.lastUtterance = last
                self.finishContinuation = c
            }
        }
    }

    func stop() {
        stopAll()
        DispatchQueue.main.async { self.isSpeaking = false }
        resumeContinuation()
    }

    /// The learner's speed setting (0.9 = normal) applied to recordings, kept within what
    /// sounds natural.
    private static var recordingRate: Float {
        Float(min(max(AppSettings.speechRate / 0.9, 0.7), 1.3))
    }

    // MARK: Recorded clips

    private func play(_ plan: [(url: URL, rate: Float, pause: TimeInterval)]) {
        clipQueue = plan
        playNext()
    }

    private func playNext() {
        guard !clipQueue.isEmpty else { finishPlayback(); return }
        let next = clipQueue.removeFirst()
        guard let p = try? AVAudioPlayer(contentsOf: next.url) else { playNext(); return }
        p.delegate = self
        p.enableRate = next.rate != 1
        p.rate = next.rate
        p.prepareToPlay()
        player = p
        pauseAfterCurrent = next.pause
        p.play()
        DispatchQueue.main.async { self.isSpeaking = true }
    }

    private var pauseAfterCurrent: TimeInterval = 0

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard p === self.player else { return }
            if self.clipQueue.isEmpty {
                self.finishPlayback()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.pauseAfterCurrent) { [weak self] in
                    guard let self, self.player === p else { return }      // stopped or replaced meanwhile
                    self.playNext()
                }
            }
        }
    }

    private func finishPlayback() {
        player = nil
        isSpeaking = false
        deactivateAudioSession()
        resumeContinuation()
    }

    /// Stops both the recording and the synthesizer without reporting the end (a new line follows).
    private func stopAll() {
        clipQueue = []
        player?.stop()
        player = nil
        lastUtterance = nil              // so the synthesizer's cancel callback is ignored
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
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
