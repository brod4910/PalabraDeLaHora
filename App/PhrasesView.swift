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
struct EverydayPhrasesSection: View {
    let word: Word

    @StateObject private var live = LiveGenerator()
    @State private var phrases: [Phrase] = []
    @State private var showAll = false
    @State private var hasKey = APIKeyStore.hasKey

    private let initiallyShown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Everyday phrases", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.coral)

            if phrases.isEmpty {
                Text(hasKey ? "No phrases yet — tap below to write one."
                            : "No phrases yet. Run tools/generate_phrases.py, or add an API key in Settings to write them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(showAll ? phrases : Array(phrases.prefix(initiallyShown))) { phrase in
                PhraseRow(phrase: phrase)
                if phrase.id != (showAll ? phrases : Array(phrases.prefix(initiallyShown))).last?.id {
                    Divider()
                }
            }

            if phrases.count > initiallyShown {
                Button(showAll ? "Show fewer" : "Show all \(phrases.count) phrases") {
                    withAnimation { showAll.toggle() }
                }
                .font(.subheadline.weight(.semibold))
            }

            if hasKey {
                Button {
                    Task {
                        if let phrase = await live.newPhrase(for: word) {
                            withAnimation { phrases.append(phrase); showAll = true }
                        }
                    }
                } label: {
                    HStack {
                        if live.isWorking { ProgressView().controlSize(.small) }
                        Label(live.isWorking ? "Writing a phrase…" : "Show me another",
                              systemImage: "sparkles")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.coral)
                .disabled(live.isWorking)
                .padding(.top, 4)

                if let error = live.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            phrases = word.allPhrases
            hasKey = APIKeyStore.hasKey
        }
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
