import Foundation

/// One vocabulary card. Loaded from `words.json`, which is bundled into both the app and the widget.
struct Word: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let spanish: String
    let english: String
    let partOfSpeech: String
    /// English-reader-friendly syllables, stressed syllable in CAPS.
    let phonetic: String
    let example: String
    let exampleTranslation: String
    /// How to build a sentence with the word.
    let pattern: String
    let tip: String?

    static let sample = Word(
        id: "querer",
        spanish: "querer",
        english: "to want / to love",
        partOfSpeech: "verb",
        phonetic: "keh-REHR",
        example: "Quiero un café, por favor.",
        exampleTranslation: "I want a coffee, please.",
        pattern: "Quiero + noun  ·  Quiero + infinitive",
        tip: "“Te quiero” is the warm, everyday way to say I love you."
    )
}

enum WordBank {
    static let all: [Word] = {
        guard
            let url = Bundle.main.url(forResource: "words", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let words = try? JSONDecoder().decode([Word].self, from: data),
            !words.isEmpty
        else {
            assertionFailure("words.json is missing from this target's Copy Bundle Resources phase")
            return [Word.sample]
        }
        return words
    }()

    private static let byID: [String: Word] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func word(id: String) -> Word? { byID[id] }
}
