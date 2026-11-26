import SwiftUI

// MARK: - One phrase

struct PhraseRow: View {
    let phrase: Phrase
    var wordLabel: String? = nil

    @EnvironmentObject private var speaker: Speaker
    @State private var isFavorite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(phrase.contextLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.coral.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.coral)
                if phrase.source == "live" {
                    Text("NEW")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                if let wordLabel {
                    Text(wordLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if phrase.source != "example" {        // the card's own examples are starred with the card
                    Button {
                        LivePhraseStore.toggleFavorite(phrase.id)
                        isFavorite.toggle()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? Theme.sun : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                }
            }
            Text(highlighted(phrase.es, word: phrase.form, color: Theme.coral))
                .font(.body.weight(.medium))
            Text(phrase.en)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let note = phrase.note {
                ExampleNoteView(note: note)
            }
            HStack(spacing: 14) {
                Button { speaker.speak(phrase.es) } label: { Label("Play", systemImage: "play.fill") }
                Button { speaker.speak(phrase.es, slow: true) } label: { Label("Slow", systemImage: "tortoise.fill") }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Theme.coral)
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .onAppear { isFavorite = LivePhraseStore.favorites.contains(phrase.id) }
    }
}

// MARK: - On the study card

/// "Everyday phrases" on a card, with "Show me another" when an API key is set.
/// One sentence at a time: the card's example, its other meanings' examples, then everyday
/// phrases. "Next" goes through them; "Show me another" writes a new one (with an API key).
struct ExamplesPanel: View {
    let word: Word

    @EnvironmentObject private var speaker: Speaker
    @StateObject private var live = LiveGenerator()
    @State private var items: [Phrase] = []
    @State private var index = 0
    @State private var hasKey = APIKeyStore.hasKey

    private var meanings: [String] { [word.english] + word.extraMeanings.map(\.english) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Examples", systemImage: "text.quote")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.coral)
                Spacer()
                if items.count > 1 {
                    Text("\(index + 1) of \(items.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if items.indices.contains(index) {
                let item = items[index]
                if meanings.count > 1 {
                    let m = min(item.meaning ?? 0, meanings.count - 1)
                    Text("Meaning \(m + 1) · \(meanings[m])")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                PhraseRow(phrase: item)
                    .id(item.id)
                    .transition(.opacity)
                if let m = item.meaning, m > 0, word.extraMeanings.indices.contains(m - 1),
                   !word.extraMeanings[m - 1].formRows.isEmpty {
                    PatternView(rows: word.extraMeanings[m - 1].formRows, onSpeak: { row in
                        if let text = row.spokenText { speaker.speak(text) }
                    })
                }
            }

            HStack(spacing: 10) {
                if index > 0 {
                    Button {
                        withAnimation(.snappy) { index -= 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                }
                if index + 1 < items.count {
                    Button {
                        withAnimation(.snappy) { index += 1 }
                    } label: {
                        Label("Next example", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if hasKey {
                    Button {
                        Task {
                            if let phrase = await live.newPhrase(for: word) {
                                withAnimation(.snappy) { items.append(phrase); index = items.count - 1 }
                            }
                        }
                    } label: {
                        HStack {
                            if live.isWorking { ProgressView().controlSize(.small) }
                            Label(live.isWorking ? "Writing one…" : "Show me another", systemImage: "sparkles")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(live.isWorking)
                }
            }
            .tint(Theme.coral)
            .controlSize(.regular)

            if let error = live.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            items = Self.examples(for: word)
            index = 0
            hasKey = APIKeyStore.hasKey
        }
    }

    /// The card's own example first, then one example per other meaning, then everyday phrases.
    static func examples(for word: Word) -> [Phrase] {
        var out = [Phrase(id: "example-\(word.id)", es: word.example, en: word.exampleTranslation, situation: nil,
                          form: word.exampleWord, note: word.exampleNote, source: "example", meaning: 0)]
        for (i, m) in word.extraMeanings.enumerated() {
            if let ex = m.example {
                out.append(Phrase(id: "example-\(word.id)-\(i + 1)", es: ex, en: m.exampleTranslation ?? "",
                                  situation: nil, form: m.exampleWord, note: m.exampleNote, source: "example",
                                  meaning: i + 1))
            }
        }
        let seen = Set(out.map { $0.es.lowercased() })
        out += word.allPhrases.filter { !seen.contains($0.es.lowercased()) }
        return out
    }
}

// MARK: - Phrasebook tab

/// Every phrase from the words she has seen, by word or by situation.
struct PhrasebookView: View {
    enum Grouping: String, CaseIterable, Identifiable {
        case word = "By word", situation = "By situation"
        var id: String { rawValue }
    }

    @State private var grouping: Grouping = .situation
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var refresh = UUID()

    private struct Entry: Identifiable, Hashable {
        let phrase: Phrase
        let word: Word
        var id: String { "\(word.id)|\(phrase.id)" }
    }

    private struct WordGroup: Identifiable {
        let word: Word
        var entries: [Entry]
        var id: String { word.id }
    }

    private struct SituationGroup: Identifiable {
        let label: String
        let entries: [Entry]
        var id: String { label }
    }

    private var entries: [Entry] {
        let favorites = LivePhraseStore.favorites
        var out: [Entry] = []
        for word in LearningProgress.seenWords() {
            var phrases = word.allPhrases
            // A phrase card (e.g. "no te preocupes") is itself an everyday phrase.
            if word.kind == .phrase {
                phrases.insert(Phrase(id: "card-\(word.id)", es: word.spanish, en: word.english, situation: nil,
                                      form: nil, note: nil, source: "curated", meaning: 0), at: 0)
            }
            for p in phrases {
                if favoritesOnly && !favorites.contains(p.id) { continue }
                if !query.isEmpty,
                   !(p.es.localizedCaseInsensitiveContains(query) || p.en.localizedCaseInsensitiveContains(query)
                     || word.spanish.localizedCaseInsensitiveContains(query)) { continue }
                out.append(Entry(phrase: p, word: word))
            }
        }
        return out
    }

    var body: some View {
        let all = entries
        NavigationStack {
            List {
                Section {
                    Picker("Group", selection: $grouping) {
                        ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if all.isEmpty {
                    ContentUnavailableView(
                        favoritesOnly ? "No starred phrases" : "No phrases yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(favoritesOnly ? "Tap ☆ on a phrase to keep it here."
                                                        : "Phrases from every word you've seen collect here."))
                }

                switch grouping {
                case .word:
                    ForEach(groupedByWord(all)) { group in
                        let word = group.word
                        Section {
                            ForEach(group.entries) { PhraseRow(phrase: $0.phrase) }
                        } header: {
                            NavigationLink {
                                ScrollView { WordCardView(word: word).padding() }
                                    .background(Color(.systemGroupedBackground))
                                    .navigationTitle(word.spanish)
                                    .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                HStack {
                                    Text(word.spanish).font(.headline).textCase(nil)
                                    Text(word.allMeanings).font(.subheadline).textCase(nil).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                case .situation:
                    ForEach(groupedBySituation(all)) { group in
                        Section(group.label) {
                            ForEach(group.entries) { PhraseRow(phrase: $0.phrase, wordLabel: $0.word.spanish) }
                        }
                    }
                }
            }
            .id(refresh)
            .navigationTitle("Phrasebook")
            .searchable(text: $query, prompt: "Search phrases")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        favoritesOnly.toggle()
                    } label: {
                        Image(systemName: favoritesOnly ? "star.fill" : "star")
                    }
                    .accessibilityLabel(favoritesOnly ? "Show all phrases" : "Show starred phrases")
                }
            }
            .onAppear {
                LearningProgress.catchUp()
                refresh = UUID()
            }
        }
    }

    private func groupedByWord(_ entries: [Entry]) -> [WordGroup] {
        var groups: [WordGroup] = []
        var index: [String: Int] = [:]
        for e in entries {
            if let i = index[e.word.id] {
                groups[i].entries.append(e)
            } else {
                index[e.word.id] = groups.count
                groups.append(WordGroup(word: e.word, entries: [e]))
            }
        }
        return groups
    }

    private func groupedBySituation(_ entries: [Entry]) -> [SituationGroup] {
        var map: [String: [Entry]] = [:]
        for e in entries { map[e.phrase.contextLabel, default: []].append(e) }
        // Situations in their natural order, then real sentences.
        let order = Situation.allCases.map { "\($0.emoji) \($0.label)" } + ["📖 Real sentence"]
        return map
            .sorted { a, b in (order.firstIndex(of: a.key) ?? 99, a.key) < (order.firstIndex(of: b.key) ?? 99, b.key) }
            .map { SituationGroup(label: $0.key, entries: $0.value) }
    }
}
