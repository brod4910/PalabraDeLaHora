import Foundation

/// Builds "slow" speech that is slow regardless of whether the voice honours `AVSpeechUtterance.rate`
/// (on some iOS 17 builds and voices, rate changes are ignored).
///
/// - Words / short phrases: syllable by syllable with pauses, then the whole word slowly
///   ("que · rer … querer").
/// - Sentences: word by word with short pauses, at `x-slow` prosody.
enum SlowSpeech {
    /// SSML for one line of slow speech.
    static func ssml(for line: String) -> String {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        let body: String
        if words.count <= 2 {
            // "por favor" → "por · fa · vor … por favor"
            let syllables = words.map { Syllables.split(strippingPunctuation($0)).map(escape).joined(separator: #"<break time="300ms"/>"#) }
            body = syllables.joined(separator: #"<break time="450ms"/>"#)
                + #"<break time="800ms"/>"#
                + escape(line)
        } else {
            body = words.map(escape).joined(separator: #"<break time="220ms"/>"#)
        }
        return #"<speak><prosody rate="x-slow">"# + body + "</prosody></speak>"
    }

    /// Plain-text chunks for the fallback path: one utterance per chunk, with the pause after each.
    static func chunks(for line: String) -> [(text: String, pause: TimeInterval)] {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count <= 2 {
            let syllables = words.flatMap { Syllables.split(strippingPunctuation($0)) }
            return syllables.enumerated().map { ($1, $0 == syllables.count - 1 ? 0.8 : 0.3) } + [(line, 0)]
        }
        return words.map { ($0, 0.22) }
    }

    private static func strippingPunctuation(_ s: String) -> String {
        s.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Rule-based Spanish syllabification (good for the vast majority of everyday words).
///
/// Handles ch/ll/rr, qu/gu before e/i, diphthongs vs. hiatus (strong + strong, or an accented í/ú),
/// inseparable onset clusters (pr, bl, tr, …) and word-final "y" as a vowel.
enum Syllables {
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "á", "é", "í", "ó", "ú", "ü"]
    private static let strong: Set<Character> = ["a", "e", "o", "á", "é", "í", "ó", "ú"]
    private static let clusters: Set<String> = ["pr", "br", "tr", "dr", "cr", "kr", "gr", "fr",
                                                "pl", "bl", "cl", "kl", "gl", "fl"]

    private enum Part { case cons([String]), nucleus(String) }

    static func split(_ word: String) -> [String] {
        let chars = Array(word.lowercased())
        guard !chars.isEmpty else { return [] }

        // 1. Tokenize into consonant units and vowel characters.
        var tokens: [(text: String, vowel: Bool)] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            let after: Character? = i + 2 < chars.count ? chars[i + 2] : nil
            if let n = next, ["ch", "ll", "rr"].contains(String([c, n])) {
                tokens.append((String([c, n]), false)); i += 2; continue
            }
            if c == "q" || c == "g", next == "u", let a = after, "eiéí".contains(a) {
                tokens.append((String([c, "u"]), false)); i += 2; continue
            }
            let finalY = c == "y" && next == nil
            tokens.append((String(c), vowels.contains(c) || finalY))
            i += 1
        }

        // 2. Group into alternating consonant runs and vowel nuclei, splitting hiatus.
        var parts: [Part] = []
        var cons: [String] = []
        var vowelRun: [Character] = []

        func flushVowels() {
            guard let first = vowelRun.first else { return }
            if !cons.isEmpty || parts.isEmpty { parts.append(.cons(cons)) }
            cons = []
            var group = String(first)
            for k in vowelRun.indices.dropFirst() {
                let a = vowelRun[k - 1], b = vowelRun[k]
                if strong.contains(a) && strong.contains(b) {
                    parts.append(.nucleus(group)); parts.append(.cons([]))
                    group = String(b)
                } else {
                    group.append(b)
                }
            }
            parts.append(.nucleus(group))
            vowelRun = []
        }

        for t in tokens {
            if t.vowel {
                vowelRun.append(Character(t.text))
            } else {
                if !vowelRun.isEmpty {
                    flushVowels()
                }
                cons.append(t.text)
            }
        }
        flushVowels()
        if !cons.isEmpty { parts.append(.cons(cons)) }

        // 3. Assign consonants between nuclei.
        var syllables: [String] = []
        var current = ""
        var idx = 0
        if case .cons(let lead) = parts.first { current = lead.joined(); idx = 1 }
        while idx < parts.count {
            guard case .nucleus(let v) = parts[idx] else { idx += 1; continue }
            current += v
            var following: [String] = []
            if idx + 1 < parts.count, case .cons(let c) = parts[idx + 1] { following = c }
            guard idx + 2 < parts.count else {
                syllables.append(current + following.joined())
                current = ""
                break
            }
            let (coda, onset) = divide(following)
            syllables.append(current + coda.joined())
            current = onset.joined()
            idx += 2
        }
        if !current.isEmpty {
            if syllables.isEmpty { syllables.append(current) } else { syllables[syllables.count - 1] += current }
        }
        return syllables.isEmpty ? [word] : syllables
    }

    private static func divide(_ c: [String]) -> (coda: [String], onset: [String]) {
        switch c.count {
        case 0: return ([], [])
        case 1: return ([], c)
        case 2: return clusters.contains(c[0] + c[1]) ? ([], c) : ([c[0]], [c[1]])
        case 3: return clusters.contains(c[1] + c[2]) ? ([c[0]], [c[1], c[2]]) : ([c[0], c[1]], [c[2]])
        default: return (Array(c.dropLast(2)), Array(c.suffix(2)))
        }
    }
}
