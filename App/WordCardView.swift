import SwiftUI

/// Full study card: word, pronunciation, meaning, example, sentence pattern, tip.
struct WordCardView: View {
    let word: Word
    var autoplay = false

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var speaker: Speaker

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero
            section(title: "In a sentence", systemImage: "text.quote") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.example)
                        .font(.title3.weight(.medium))
                        .fontDesign(.serif)
                        .italic()
                    Text(word.exampleTranslation)
                        .foregroundStyle(.secondary)
                    HStack {
                        PlayButton(title: "Play", systemImage: "play.fill") { speaker.speak(word.example) }
                        PlayButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(word.example, slow: true) }
                    }
                    .padding(.top, 4)
                }
            }
            if let pattern = word.pattern {
                section(title: word.source == "dictionary" ? "Key forms" : "How to use it",
                        systemImage: "puzzlepiece.extension.fill") {
                    Text(pattern).font(.body.weight(.semibold))
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
            Text(word.english)
                .font(.title3.weight(.semibold))
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
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.coral)
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
