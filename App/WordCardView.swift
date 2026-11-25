import SwiftUI

/// Full study card: word, pronunciation, meaning, example, sentence pattern, tip.
struct WordCardView: View {
    let word: Word
    var autoplay = false

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var speaker: Speaker

    private var hasExtraMeanings: Bool { !word.extraMeanings.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero

            // Meaning 1 (the main one): its sentence, key forms and how to use it.
            section(title: hasExtraMeanings ? "1 · \(word.english)" : "In a sentence",
                    systemImage: hasExtraMeanings ? "1.circle.fill" : "text.quote") {
                exampleBlock(word.example, word.exampleTranslation, word: word.exampleWord, note: word.exampleNote)
            }
            formsSection(word.formRows, title: "Key forms")
            if word.formRows.isEmpty && word.neverChangesForm {
                section(title: "Key forms", systemImage: "tablecells") {
                    Text("**\(word.spanish)** never changes — same form for masculine, feminine, singular and plural.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !word.patternRows.isEmpty {
                section(title: "How to use it", systemImage: "puzzlepiece.extension.fill") {
                    PatternView(rows: word.patternRows)
                }
            }

            // Other meanings, each with its own example (and key forms when they differ).
            ForEach(Array(word.extraMeanings.enumerated()), id: \.offset) { i, meaning in
                section(title: "\(i + 2) · \(meaning.english)", systemImage: "\(i + 2).circle.fill") {
                    if let pos = meaning.partOfSpeech {
                        Text(pos).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    if let example = meaning.example {
                        exampleBlock(example, meaning.exampleTranslation ?? "",
                                     word: meaning.exampleWord, note: meaning.exampleNote)
                    }
                    if !meaning.formRows.isEmpty {
                        Divider().padding(.vertical, 4)
                        PatternView(rows: meaning.formRows, onSpeak: { row in
                            if let text = row.spokenText { speaker.speak(text) }
                        })
                    }
                }
            }

            if let tip = word.tip {
                section(title: "Tip", systemImage: "lightbulb.fill") {
                    Text(tip)
                }
            }
        }
        .onAppear {
            if autoplay { speaker.speak([word.spanish, word.example]) }
        }
    }

    private func exampleBlock(_ example: String, _ translation: String,
                              word highlight: String? = nil, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(highlighted(example, word: highlight, color: Theme.coral))
                .font(.title3.weight(.medium))
                .fontDesign(.serif)
                .italic()
            Text(translation)
                .foregroundStyle(.secondary)
            if let note {
                ExampleNoteView(note: note)
                    .padding(.top, 2)
            }
            HStack {
                PlayButton(title: "Play", systemImage: "play.fill") { speaker.speak(example) }
                PlayButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(example, slow: true) }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func formsSection(_ rows: [PatternRow], title: String) -> some View {
        if !rows.isEmpty {
            let spoken = rows.compactMap(\.spokenText)
            let playAll: (() -> Void)? = spoken.isEmpty ? nil : {
                Task { await speaker.say(spoken.map { Speaker.Part.spanish($0, pause: 0.5) }) }
            }
            section(title: title, systemImage: "tablecells", playAll: playAll) {
                PatternView(rows: rows, onSpeak: { row in
                    if let text = row.spokenText { speaker.speak(text) }
                })
                Text("Tap a form to hear it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(word.level.label) · \(word.partOfSpeech)".uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                Spacer()
                Button {
                    favorites.toggle(word)
                } label: {
                    Image(systemName: favorites.contains(word) ? "star.fill" : "star")
                        .font(.title3)
                }
                .accessibilityLabel(favorites.contains(word) ? "Remove from favorites" : "Add to favorites")
            }
            Text(word.spanish)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(word.phonetic)
                .font(.title3.monospaced())
                .opacity(0.9)
            if hasExtraMeanings {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(([word.english] + word.extraMeanings.map(\.english)).enumerated()), id: \.offset) { i, english in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.heavy))
                                .frame(width: 18, height: 18)
                                .background(.white.opacity(0.25), in: Circle())
                            Text(english)
                                .font(i == 0 ? .title3.weight(.semibold) : .body.weight(.medium))
                        }
                    }
                }
            } else {
                Text(word.english)
                    .font(.title3.weight(.semibold))
            }
            HStack {
                PlayButton(title: "Hear it", systemImage: "speaker.wave.2.fill", prominent: true) {
                    speaker.speak(word.spanish)
                }
                PlayButton(title: "Slow", systemImage: "tortoise.fill", prominent: true) {
                    speaker.speak(word.spanish, slow: true)
                }
            }
            .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.magenta.opacity(0.25), radius: 16, y: 8)
    }

    private func section<Content: View>(title: String, systemImage: String,
                                        playAll: (() -> Void)? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.coral)
                Spacer()
                if let playAll {
                    Button(action: playAll) {
                        Label("Play all", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(Theme.coral)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PlayButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(prominent ? AnyShapeStyle(Color.white.opacity(0.22)) : AnyShapeStyle(Theme.coral.opacity(0.12)),
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.coral))
    }
}

#Preview {
    ScrollView { WordCardView(word: .sample).padding() }
        .environmentObject(FavoritesStore())
        .environmentObject(Speaker.shared)
}
