import Foundation

/// Phrases written on the phone with "Show me another", plus starred phrases. Stored in the App
/// Group so the widget's phrase of the hour can include them.
enum LivePhraseStore {
    private static var defaults: UserDefaults { AppSettings.defaults }
    private static let livePhrasesKey = "livePhrases"
    private static let favoritesKey = "favoritePhrases"

    /// word id → phrases written on this phone.
    private static var all: [String: [Phrase]] {
        get {
            guard let data = defaults.data(forKey: livePhrasesKey),
                  let decoded = try? JSONDecoder().decode([String: [Phrase]].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: livePhrasesKey) }
        }
    }

    static func phrases(for wordID: String) -> [Phrase] { all[wordID] ?? [] }

    static func add(_ phrase: Phrase, to wordID: String) {
        var map = all
        map[wordID, default: []].append(phrase)
        all = map
    }

    static func remove(_ phraseID: String, from wordID: String) {
        var map = all
        map[wordID]?.removeAll { $0.id == phraseID }
        all = map
    }

    // MARK: Favorites

    static var favorites: Set<String> {
        get { Set(defaults.stringArray(forKey: favoritesKey) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: favoritesKey) }
    }

    static func toggleFavorite(_ id: String) {
        var f = favorites
        if f.contains(id) { f.remove(id) } else { f.insert(id) }
        favorites = f
    }
}
