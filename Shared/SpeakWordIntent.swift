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

    /// Speak this everyday phrase instead of the example sentence (widget phrase of the hour).
    @Parameter(title: "Phrase ID")
    var phraseID: String?

    init() {}

    init(wordID: String, includeSentence: Bool, phraseID: String? = nil) {
        self.wordID = wordID
        self.includeSentence = includeSentence
        self.phraseID = phraseID
    }

    func perform() async throws -> some IntentResult {
        guard let word = WordBank.word(id: wordID) else { return .result() }
        var lines = [word.spanish]
        if includeSentence {
            if let phraseID, let phrase = word.allPhrases.first(where: { $0.id == phraseID }) {
                lines.append(phrase.es)
            } else {
                lines.append(word.example)
            }
        }
        await Speaker.shared.speakAndWait(lines)
        return .result()
    }
}
