import AppIntents

/// Speaks a word (and optionally its example sentence).
///
/// Used by the 🔊 buttons on the interactive widget. It conforms to `AudioPlaybackIntent`, and this
/// file is compiled into BOTH the app and the widget extension, so the system can run it in the app
/// process in the background (the app declares the `audio` background mode) — no app launch needed.
struct SpeakWordIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Pronounce Spanish Word"
    static var description = IntentDescription("Speaks the Spanish word of the hour and its example sentence.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Word ID")
    var wordID: String

    @Parameter(title: "Include Example Sentence", default: true)
    var includeSentence: Bool

    init() {}

    init(wordID: String, includeSentence: Bool) {
        self.wordID = wordID
        self.includeSentence = includeSentence
    }

    func perform() async throws -> some IntentResult {
        guard let word = WordBank.word(id: wordID) else { return .result() }
        var lines = [word.spanish]
        if includeSentence { lines.append(word.example) }
        await Speaker.shared.speakAndWait(lines)
        return .result()
    }
}
