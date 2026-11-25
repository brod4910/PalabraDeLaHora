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

/// When you'd say a phrase. Generated phrases pick one of these; real (Tatoeba) sentences have none.
enum Situation: String, CaseIterable, Identifiable, Sendable {
    case home, food, shopping, work, travel, texting, family, friends, couple, feelings, health, plans,
         weather, school, everyday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "At home"
        case .food: "Food & eating out"
        case .shopping: "Shopping"
        case .work: "At work"
        case .travel: "Travel"
        case .texting: "Texting"
        case .family: "Family"
        case .friends: "Friends"
        case .couple: "Couple"
        case .feelings: "Feelings"
        case .health: "Health"
        case .plans: "Making plans"
        case .weather: "Weather"
        case .school: "School"
        case .everyday: "Everyday"
        }
    }

    var emoji: String {
        switch self {
        case .home: "🏠"
        case .food: "🍽️"
        case .shopping: "🛍️"
        case .work: "💼"
        case .travel: "✈️"
        case .texting: "💬"
        case .family: "👨‍👩‍👧"
        case .friends: "🧑‍🤝‍🧑"
        case .couple: "❤️"
        case .feelings: "💭"
        case .health: "🩺"
        case .plans: "📅"
        case .weather: "☀️"
        case .school: "📚"
        case .everyday: "✨"
        }
    }
}

/// An everyday phrase that uses a card's word: AI-written ("ai"), a real sentence ("tatoeba"),
/// or written on the phone with "Show me another" ("live").
struct Phrase: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let es: String
    let en: String
    let situation: String?
    /// The word's form as it appears in `es` (highlighted).
    let form: String?
    /// Beginner note when `form` isn't the dictionary form (Markdown).
    let note: String?
    let source: String?
    /// Which meaning of the word it uses (0 = the main one).
    let meaning: Int?

    /// nil for real sentences, which aren't tagged with a situation.
    var situationInfo: Situation? { situation.flatMap(Situation.init(rawValue:)) }
    var contextLabel: String {
        if let s = situationInfo { return "\(s.emoji) \(s.label)" }
        return source == "tatoeba" ? "📖 Real sentence" : "✨ Everyday"
    }
}

/// An additional meaning of the same word (cuarto = room, also fourth), with its own example.
struct Meaning: Codable, Hashable, Sendable {
    let english: String
    let partOfSpeech: String?
    let example: String?
    let exampleTranslation: String?
    /// Key forms for this meaning when they differ from the main one ("label: value" lines).
    let forms: String?
    /// The word as it appears in `example` (highlighted), and a beginner note when it's a form
    /// she hasn't met yet ("**quitaron** = *quitar* → past tense for they").
    let exampleWord: String?
    let exampleNote: String?
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
    /// How to build a sentence with the word (hand-written cards).
    let pattern: String?
    /// Key forms, one "label: value" per line (yo: tengo / plural: las casas). Shown as a table.
    let forms: String?
    let tip: String?
    let level: Level
    let kind: Kind
    /// "curated" (hand-written) or "dictionary" (generated by tools/import_dictionary.py).
    let source: String?
    /// Other meanings, most common first. The main meaning is `english` / `example` above.
    let otherMeanings: [Meaning]?
    /// The word as it appears in `example` (highlighted) and, when it's a form not obvious to a
    /// beginner, a plain-English note (Markdown) explaining it.
    let exampleWord: String?
    let exampleNote: String?
    /// Everyday phrases bundled in the app (AI-written and real sentences).
    let phrases: [Phrase]?

    /// Bundled phrases plus any written on this phone with "Show me another".
    var allPhrases: [Phrase] { (phrases ?? []) + LivePhraseStore.phrases(for: id) }

    var extraMeanings: [Meaning] { otherMeanings ?? [] }

    /// Every meaning, for one-line display: "room · fourth · quarter".
    var allMeanings: String {
        ([english] + extraMeanings.map(\.english)).joined(separator: " · ")
    }

    static let sample = Word(
        id: "querer",
        spanish: "querer",
        english: "to want / to love",
        partOfSpeech: "verb",
        phonetic: "keh-REHR",
        example: "Quiero un café, por favor.",
        exampleTranslation: "I want a coffee, please.",
        pattern: "Quiero + noun  ·  Quiero + infinitive",
        forms: "yo: quiero\ntú: quieres\nél / ella: quiere\npast (yo): quise",
        tip: "“Te quiero” is the warm, everyday way to say I love you.",
        level: .novice,
        kind: .word,
        source: "curated",
        otherMeanings: [Meaning(english: "to love (someone)", partOfSpeech: nil,
                                example: "Te quiero mucho.", exampleTranslation: "I love you so much.", forms: nil,
                                exampleWord: "quiero", exampleNote: nil)],
        exampleWord: "Quiero",
        exampleNote: nil,
        phrases: [Phrase(id: "sample1", es: "¿Quieres ver una película?", en: "Do you want to watch a movie?",
                         situation: "couple", form: "Quieres", note: nil, source: "ai", meaning: 0)]
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
