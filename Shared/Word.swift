import Foundation

/// Learning tier, roughly mapped to CEFR.
enum Level: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case novice, beginner, intermediate, fluent

    var id: String { rawValue }
    var rank: Int { Self.allCases.firstIndex(of: self)! }
    static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }

    var label: String {
        switch self {
        case .novice: "Novice"
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .fluent: "Fluent"
        }
    }

    var cefr: String {
        switch self {
        case .novice: "A1"
        case .beginner: "A2"
        case .intermediate: "B1"
        case .fluent: "B2–C1"
        }
    }

    var summary: String {
        switch self {
        case .novice: "Greetings, core verbs, everyday nouns — the words you hear constantly."
        case .beginner: "Daily routines, plans, shopping, feelings, asking for things."
        case .intermediate: "Opinions, connectors, reflexive verbs, Mexican slang."
        case .fluent: "False friends, idioms, subjunctive & conditional structures."
        }
    }
}

/// Single vocabulary word vs. a ready-to-use everyday phrase.
enum Kind: String, Codable, Sendable {
    case word, phrase
}

/// What the rotation should focus on.
enum Focus: String, CaseIterable, Identifiable, Sendable {
    case everything, phrases, vocabulary

    var id: String { rawValue }
    var label: String {
        switch self {
        case .everything: "Words + phrases"
        case .phrases: "Everyday phrases"
        case .vocabulary: "Vocabulary only"
        }
    }
}

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
    let level: Level
    let kind: Kind

    static let sample = Word(
        id: "querer",
        spanish: "querer",
        english: "to want / to love",
        partOfSpeech: "verb",
        phonetic: "keh-REHR",
        example: "Quiero un café, por favor.",
        exampleTranslation: "I want a coffee, please.",
        pattern: "Quiero + noun  ·  Quiero + infinitive",
        tip: "“Te quiero” is the warm, everyday way to say I love you.",
        level: .novice,
        kind: .word
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

    /// The cards in rotation for the given settings.
    ///
    /// "Everyday phrases" always includes phrases from every level up to the chosen one, because
    /// each level only has a few dozen phrases and the easier ones are the most useful anyway.
    static func deck(level: Level, includeEarlier: Bool, focus: Focus) -> [Word] {
        let levelOK: (Word) -> Bool = { w in
            (includeEarlier || focus == .phrases) ? w.level <= level : w.level == level
        }
        let kindOK: (Word) -> Bool = { w in
            switch focus {
            case .everything: true
            case .phrases: w.kind == .phrase
            case .vocabulary: w.kind == .word
            }
        }
        let deck = all.filter { levelOK($0) && kindOK($0) }
        return deck.isEmpty ? all : deck
    }

    static var currentDeck: [Word] {
        deck(level: AppSettings.level, includeEarlier: AppSettings.includeEarlierLevels, focus: AppSettings.focus)
    }
}
