import Foundation
import Security

/// The Anthropic API key, stored in this iPhone's Keychain (never in the app bundle or iCloud).
enum APIKeyStore {
    private static let service = "palabra.anthropic"
    private static let account = "api-key"

    static var key: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasKey: Bool { key != nil }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8),
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum LiveModel: String, CaseIterable, Identifiable {
    case haiku = "claude-haiku-5-5"
    case sonnet = "claude-sonnet-5-5"

    var id: String { rawValue }
    var label: String { self == .haiku ? "Claude Haiku 5.5 (fast, cheapest)" : "Claude Sonnet 5.5 (best quality)" }
}

/// Writes one new everyday phrase for a word on demand ("Show me another").
@MainActor
final class LiveGenerator: ObservableObject {
    @Published private(set) var isWorking = false
    @Published var lastError: String?

    enum Failure: LocalizedError {
        case noKey, badResponse, http(Int, String), unusable(String)
        var errorDescription: String? {
            switch self {
            case .noKey: "Add your Anthropic API key in Settings › AI phrases."
            case .badResponse: "The reply couldn't be read. Try again."
            case .http(let code, let body): "Anthropic API error \(code). \(body)"
            case .unusable(let why): "That phrase didn't pass the checks (\(why)). Try again."
            }
        }
    }

    /// Generates, checks and saves a phrase. Returns it, or nil on failure (see `lastError`).
    func newPhrase(for word: Word) async -> Phrase? {
        guard let key = APIKeyStore.key else { lastError = Failure.noKey.errorDescription; return nil }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            // One retry if the first phrase fails the on-device checks.
            for attempt in 0..<2 {
                let raw = try await request(word: word, key: key)
                switch check(raw, for: word) {
                case .success(let phrase):
                    LivePhraseStore.add(phrase, to: word.id)
                    return phrase
                case .failure(let error) where attempt == 1:
                    throw error
                case .failure:
                    continue
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }

    // MARK: Request

    private struct Raw: Decodable {
        let es: String
        let en: String
        let situation: String?
        let form: String?
        let note: String?
        let meaning: Int?
    }

    private func request(word: Word, key: String) async throws -> Raw {
        let meanings = ([word.english] + word.extraMeanings.map(\.english))
            .enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "; ")
        let existing = word.allPhrases.map(\.es) + [word.example]
        let used = Set(word.allPhrases.compactMap(\.situation))
        let fresh = Situation.allCases.map(\.rawValue).filter { !used.contains($0) }
        let variety: String = switch AppSettings.voice {
        case .mexico: "Mexican Spanish (tú; ustedes for plural you)"
        case .spain: "Spain Spanish (tú; vosotros)"
        case .unitedStates: "neutral Latin American Spanish (tú; ustedes)"
        }
        let prompt = """
        Spanish variety: \(variety)
        Word: \(word.spanish) (\(word.partOfSpeech)). Level: \(word.level.rawValue). Meanings: \(meanings).
        Key forms: \((word.forms ?? "").replacingOccurrences(of: "\n", with: "; "))

        Write ONE new everyday phrase (3–9 words) that people really say, using this word (any form).
        Prefer one of these situations: \((fresh.isEmpty ? Situation.allCases.map(\.rawValue) : fresh).joined(separator: ", ")).
        It must be different from these: \(existing.joined(separator: " | "))
        For novice/beginner: present tense, infinitive or a simple tú command; only very common words.
        No names, brands, or sensitive content.
        "form": the exact form of the word as written in the phrase. "note": if form isn't the dictionary
        form, a beginner explanation under 20 words like "**quitaste** = *quitar* → past tense for **you** (tú)", else "".
        Return only JSON: {"es": "...", "en": "...", "situation": "...", "form": "...", "note": "...", "meaning": 0}
        """
        let body: [String: Any] = [
            "model": (UserDefaults.standard.string(forKey: "liveModel") ?? LiveModel.haiku.rawValue),
            "max_tokens": 300,
            "system": "You write natural everyday spoken Spanish for an adult beginner. Return only JSON.",
            "messages": [["role": "user", "content": prompt]],
        ]
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? ""
            throw Failure.http(status, message)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { throw Failure.badResponse }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
              let raw = try? JSONDecoder().decode(Raw.self, from: Data(text[start...end].utf8)) else {
            throw Failure.badResponse
        }
        return raw
    }

    // MARK: On-device checks

    private func check(_ raw: Raw, for word: Word) -> Result<Phrase, Failure> {
        let es = raw.es.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = raw.en.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = AnswerMatcher.normalize(es).split(separator: " ")
        guard !es.isEmpty, !en.isEmpty else { return .failure(.unusable("empty")) }
        guard (2...12).contains(tokens.count) else { return .failure(.unusable("length")) }
        let existing = Set((word.allPhrases.map(\.es) + [word.example]).map(AnswerMatcher.normalize))
        guard !existing.contains(AnswerMatcher.normalize(es)) else { return .failure(.unusable("duplicate")) }

        // The word (or one of its forms) must really be in the phrase.
        let form = (raw.form ?? "").trimmingCharacters(in: .whitespaces)
        let normalizedForm = AnswerMatcher.normalize(form)
        let containsForm = !normalizedForm.isEmpty && " \(AnswerMatcher.normalize(es)) ".contains(" \(normalizedForm) ")
        let lemma = AnswerMatcher.normalize(word.spanish)
        let knownForms = Set(([word.spanish] + word.formRows.flatMap { $0.value.components(separatedBy: " / ") })
            .map(AnswerMatcher.normalize))
        let stem = String(lemma.prefix(max(3, lemma.count - 3)))
        let related = knownForms.contains(normalizedForm) || normalizedForm.hasPrefix(stem)
            || knownForms.contains { !$0.isEmpty && normalizedForm.hasPrefix($0) }
        if word.kind == .phrase || word.spanish.contains(" ") {
            guard AnswerMatcher.normalize(es).contains(lemma) else { return .failure(.unusable("phrase missing")) }
        } else {
            guard containsForm, related else { return .failure(.unusable("word missing")) }
        }

        let situation = raw.situation.flatMap(Situation.init(rawValue:))?.rawValue ?? Situation.everyday.rawValue
        let note = (raw.note ?? "").isEmpty ? nil : raw.note
        return .success(Phrase(id: "live-" + UUID().uuidString.prefix(8).lowercased(), es: es, en: en,
                               situation: situation, form: form.isEmpty ? nil : form, note: note,
                               source: "live", meaning: raw.meaning))
    }
}
