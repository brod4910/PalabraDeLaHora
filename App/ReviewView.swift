import SwiftUI

struct ReviewView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case seen = "Seen", favorites = "Favorites", all = "All"
        var id: String { rawValue }
    }

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var speaker: Speaker
    @State private var filter: Filter = .seen
    @State private var query = ""
    @State private var practicing = false

    private var words: [Word] {
        let base: [Word]
        switch filter {
        case .seen: base = LearningProgress.seenWords()
        case .favorites: base = WordBank.all.filter { favorites.contains($0) }
        case .all: base = WordBank.all.sorted {
            ($0.level, $0.spanish.lowercased()) < ($1.level, $1.spanish.lowercased())
        }
        }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.spanish.localizedCaseInsensitiveContains(query) || $0.english.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    if words.isEmpty {
                        ContentUnavailableView(
                            filter == .favorites ? "No favorites yet" : "Nothing here yet",
                            systemImage: filter == .favorites ? "star" : "text.book.closed",
                            description: Text(filter == .favorites ? "Tap the ☆ on any word to save it." : "New words show up here as they appear.")
                        )
                    }
                    ForEach(words) { word in
                        NavigationLink {
                            ScrollView { WordCardView(word: word).padding() }
                                .background(Color(.systemGroupedBackground))
                                .navigationTitle(word.spanish)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            WordRow(word: word, isFavorite: favorites.contains(word)) {
                                speaker.speak(word.spanish)
                            }
                        }
                    }
                } footer: {
                    if filter == .seen, !words.isEmpty {
                        Text("\(words.count) of \(WordBank.all.count) cards seen so far.")
                    }
                }
            }
            .navigationTitle("Review")
            .searchable(text: $query, prompt: "Search Spanish or English")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        practicing = true
                    } label: {
                        Label("Practice", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .disabled(words.count < 2)
                }
            }
            .fullScreenCover(isPresented: $practicing) {
                PracticeView(words: words.shuffled())
            }
        }
    }
}

private struct WordRow: View {
    let word: Word
    let isFavorite: Bool
    let play: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(word.spanish).font(.headline)
                    if isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.sun) }
                    if LearningProgress.record(for: word.id).isMastered {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                    }
                }
                Text(word.english).font(.subheadline).foregroundStyle(.secondary)
                Text(word.level.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.coral)
            }
            Spacer()
            Button(action: play) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.coral)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Pronounce \(word.spanish)")
        }
    }
}

/// Flashcards: see the Spanish, guess, tap to reveal.
struct PracticeView: View {
    let words: [Word]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var speaker: Speaker
    @State private var index = 0
    @State private var revealed = false
    @State private var known = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if index < words.count {
                    let word = words[index]
                    ProgressView(value: Double(index), total: Double(words.count))
                    Spacer()
                    VStack(spacing: 12) {
                        Text(word.spanish)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Button { speaker.speak(word.spanish) } label: {
                            Label(word.phonetic, systemImage: "speaker.wave.2.fill")
                        }
                        if revealed {
                            VStack(spacing: 6) {
                                Text(word.english).font(.title2.weight(.semibold))
                                Text(word.example).italic()
                                Text(word.exampleTranslation).foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .onTapGesture { withAnimation { revealed = true } }
                    Spacer()
                    if revealed {
                        HStack(spacing: 12) {
                            Button { advance(knewIt: false) } label: {
                                Text("Still learning").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            Button { advance(knewIt: true) } label: {
                                Text("Got it ✓").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .controlSize(.large)
                    } else {
                        Button { withAnimation { revealed = true } } label: {
                            Text("Show meaning").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                } else {
                    Spacer()
                    Text("¡Muy bien! 🎉").font(.largeTitle.bold())
                    Text("You knew \(known) of \(words.count).").font(.title3)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func advance(knewIt: Bool) {
        if knewIt { known += 1 }
        withAnimation {
            revealed = false
            index += 1
        }
    }
}
