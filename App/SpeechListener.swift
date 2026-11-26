import AVFoundation
import Speech

/// Listens for one spoken answer and returns the transcript.
///
/// Stops on its own ~1.3 s after she stops talking (or after `maxDuration`), so verbal quizzes can
/// run hands-free. Uses on-device recognition when the device supports it for that language.
@MainActor
final class SpeechListener: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Never>?
    private var silenceTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// Asks for speech recognition and microphone access. Returns true if both are granted.
    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Listens once. `hints` (e.g. the expected answer) improve recognition of short words.
    func listen(language: String, hints: [String] = [], maxDuration: TimeInterval = 7) async -> String {
        stopNow()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            return ""
        }

        guard AudioSessionManager.shared.activate(AudioSessionManager.listening) else { return "" }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = hints
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            tearDown()
            return ""
        }

        transcript = ""
        isListening = true

        return await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
            continuation = c
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                Task { @MainActor in
                    guard let self else { return }
                    if let text {
                        self.transcript = text
                        self.restartSilenceTimer()
                    }
                    if isFinal || error != nil { self.finish() }
                }
            }
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(maxDuration))
                self?.finish()
            }
        }
    }

    /// Ends listening now and returns whatever was heard so far.
    func stopNow() {
        finish()
    }

    private func restartSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard isListening || continuation != nil else { return }
        let heard = transcript
        tearDown()
        continuation?.resume(returning: heard)
        continuation = nil
    }

    private func tearDown() {
        silenceTask?.cancel(); silenceTask = nil
        timeoutTask?.cancel(); timeoutTask = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
        isListening = false
        AudioSessionManager.shared.deactivateSoon(after: 0.5)
    }
}

/// Lenient answer checking for spoken and typed answers.
enum AnswerMatcher {
    /// Lowercased, accents and punctuation removed, single spaces.
    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Like `normalize` but keeps accents (ñ, á …) for typed answers.
    static func normalizeKeepingAccents(_ s: String) -> String {
        let lowered = s.lowercased()
        let cleaned = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let longest = max(a.count, b.count)
        return longest == 0 ? 1 : 1 - Double(distance(a, b)) / Double(longest)
    }

    /// Did she say the Spanish word/phrase? Accepts it inside a longer answer ("es querer") and
    /// small recognition slips.
    static func matchesSpanish(spoken: String, target: String) -> Bool {
        let s = normalize(spoken), t = normalize(target)
        guard !s.isEmpty, !t.isEmpty else { return false }
        if s == t || " \(s) ".contains(" \(t) ") { return true }
        // Compare against every window of the same number of words.
        let sw = s.split(separator: " ").map(String.init)
        let n = t.split(separator: " ").count
        if sw.count >= n {
            for i in 0...(sw.count - n) where similarity(sw[i..<(i + n)].joined(separator: " "), t) >= 0.8 {
                return true
            }
        }
        return similarity(s, t) >= 0.75
    }

    /// Fraction of the sentence's words she repeated.
    static func overlap(spoken: String, sentence: String) -> Double {
        let said = normalize(spoken).split(separator: " ").map(String.init)
        let target = normalize(sentence).split(separator: " ").map(String.init)
        guard !target.isEmpty else { return 0 }
        let hits = target.filter { w in said.contains { $0 == w || (w.count > 3 && similarity($0, w) >= 0.8) } }
        return Double(hits.count) / Double(target.count)
    }

    /// Acceptable English answers: "to want / to love" → ["want", "love"].
    static func englishAnswers(for english: String) -> [String] {
        english
            .replacingOccurrences(of: "(", with: "/")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: CharacterSet(charactersIn: "/,;"))
            .map { normalize($0) }
            .map { s in
                var s = s
                for prefix in ["to ", "the ", "a ", "an "] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
                return s
            }
            .filter { $0.count > 1 && !["it", "as", "for", "of"].contains($0) }
    }

    static func matchesEnglish(spoken: String, english: String) -> Bool {
        let s = normalize(spoken)
        guard !s.isEmpty else { return false }
        return englishAnswers(for: english).contains { a in
            " \(s) ".contains(" \(a) ") || similarity(s, a) >= 0.8
        }
    }

    enum TypedResult { case exact, missingAccents, typo, wrong
        var isCorrect: Bool { self != .wrong }
    }

    static func checkTyped(_ typed: String, target: String) -> TypedResult {
        let a = normalizeKeepingAccents(typed), b = normalizeKeepingAccents(target)
        guard !a.isEmpty else { return .wrong }
        if a == b { return .exact }
        if normalize(typed) == normalize(target) { return .missingAccents }
        if b.count >= 6, distance(normalize(typed), normalize(target)) <= 1 { return .typo }
        return .wrong
    }
}
