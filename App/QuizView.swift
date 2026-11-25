import SwiftUI

// MARK: - Model

struct QuizQuestion: Identifiable {
    enum Style {
        case meaning      // Spanish → pick English
        case reverse      // English → pick Spanish
        case listening    // hear it → pick English
        case fillBlank    // sentence with a gap → pick Spanish
    }

    let id = UUID()
    let word: Word
    let style: Style
    let prompt: String
    let options: [String]
    let answer: String

    var instruction: String {
        switch style {
        case .meaning: "What does this mean?"
        case .reverse: "How do you say this in Spanish?"
        case .listening: "Listen. What does it mean?"
        case .fillBlank: "Fill in the blank."
        }
    }
}

enum QuizBuilder {
    static let minimumWords = 4

    /// Builds a quiz from words already seen. The ones missed most (and never asked) come first.
    static func make(from seen: [Word], count: Int = 10) -> [QuizQuestion] {
        guard seen.count >= minimumWords else { return [] }
        let picked = seen
            .map { ($0, LearningProgress.record(for: $0.id).priority + Double.random(in: 0...0.15)) }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map(\.0)
        return picked.shuffled().map(question(for:))
    }

    private static func question(for word: Word) -> QuizQuestion {
        var styles: [QuizQuestion.Style] = [.meaning, .reverse, .listening]
        if blanked(word) != nil { styles += [.fillBlank, .fillBlank] }
        let style = styles.randomElement()!

        switch style {
        case .meaning, .listening:
            let options = (distractors(for: word, by: \.english) + [word.english]).shuffled()
            return QuizQuestion(word: word, style: style,
                                prompt: style == .meaning ? word.spanish : "🔊",
                                options: options, answer: word.english)
        case .reverse:
            let options = (distractors(for: word, by: \.spanish) + [word.spanish]).shuffled()
            return QuizQuestion(word: word, style: .reverse, prompt: word.english, options: options, answer: word.spanish)
        case .fillBlank:
            let options = (distractors(for: word, by: \.spanish) + [word.spanish]).shuffled()
            return QuizQuestion(word: word, style: .fillBlank, prompt: blanked(word)!, options: options, answer: word.spanish)
        }
    }

    /// The example sentence with the word replaced by a blank — only when the word appears as-is
    /// (verbs are usually conjugated in their examples, so those use the other styles).
    static func blanked(_ word: Word) -> String? {
        guard word.spanish.count > 2,
              let range = word.example.range(of: word.spanish, options: [.caseInsensitive]) else { return nil }
        return word.example.replacingCharacters(in: range, with: "_____")
    }

    /// Three distinct wrong answers of the same kind, preferring the same level so they're plausible.
    private static func distractors(for word: Word, by field: KeyPath<Word, String>) -> [String] {
        let pool = WordBank.all.filter {
            $0.id != word.id && $0.kind == word.kind
                && $0.english != word.english && $0.spanish != word.spanish
        }
        let sameLevel = pool.filter { $0.level == word.level }.shuffled()
        let others = pool.filter { $0.level != word.level }.shuffled()
        var result: [String] = []
        for candidate in (sameLevel + others).map({ $0[keyPath: field] }) where !result.contains(candidate) {
            result.append(candidate)
            if result.count == 3 { break }
        }
        return result
    }
}

// MARK: - Home

struct QuizHomeView: View {
    @State private var questions: [QuizQuestion] = []
    @State private var isQuizzing = false
    @State private var refresh = UUID()

    var body: some View {
        let seen = LearningProgress.seenWords()
        let mastered = seen.filter { LearningProgress.record(for: $0.id).isMastered }
        let shaky = seen.filter { let r = LearningProgress.record(for: $0.id); return r.wrong > 0 && !r.isMastered }

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            StatTile(value: seen.count, label: "Seen")
                            StatTile(value: mastered.count, label: "Mastered")
                            StatTile(value: shaky.count, label: "Practice")
                        }
                        Button {
                            questions = QuizBuilder.make(from: seen)
                            isQuizzing = true
                        } label: {
                            Label("Start a 10-question quiz", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(seen.count < QuizBuilder.minimumWords)

                        if seen.count < QuizBuilder.minimumWords {
                            Text("Quizzes unlock after \(QuizBuilder.minimumWords) words. Tap “Learn the next word now” on the Hoy tab to get there faster.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Mixes meaning, reverse, listening and fill-in-the-blank questions. Words you miss come back sooner.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !shaky.isEmpty {
                    Section("Needs practice") {
                        ForEach(shaky) { word in
                            let r = LearningProgress.record(for: word.id)
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(word.spanish).font(.headline)
                                    Text(word.english).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(r.right)/\(r.attempts)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .id(refresh)
            .navigationTitle("Quiz")
            .fullScreenCover(isPresented: $isQuizzing, onDismiss: { refresh = UUID() }) {
                QuizSessionView(questions: questions)
            }
            .onAppear { LearningProgress.catchUp(); refresh = UUID() }
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Session

struct QuizSessionView: View {
    let questions: [QuizQuestion]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var speaker: Speaker
    @State private var index = 0
    @State private var chosen: String?
    @State private var score = 0
    @State private var missed: [Word] = []

    var body: some View {
        NavigationStack {
            Group {
                if index < questions.count {
                    questionView(questions[index])
                } else {
                    results
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(index < questions.count ? "Question \(index + 1) of \(questions.count)" : "Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func questionView(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ProgressView(value: Double(index), total: Double(questions.count))
            Text(q.instruction)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                if q.style == .listening {
                    Button { speaker.speak(q.word.spanish) } label: {
                        Label("Play again", systemImage: "speaker.wave.3.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 90)
                    }
                    .buttonStyle(.bordered)
                    .onAppear { speaker.speak(q.word.spanish) }
                } else {
                    Text(q.prompt)
                        .font(q.style == .fillBlank ? .title2.weight(.medium) : .system(size: 36, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            VStack(spacing: 10) {
                ForEach(q.options, id: \.self) { option in
                    Button { answer(option, for: q) } label: {
                        HStack {
                            Text(option).multilineTextAlignment(.leading)
                            Spacer()
                            if let chosen, option == q.answer {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if chosen == option {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: option, q: q),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(chosen != nil)
                }
            }

            if chosen != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(q.word.spanish) — \(q.word.english)").font(.headline)
                        Spacer()
                        Button { speaker.speak([q.word.spanish, q.word.example]) } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                    }
                    Text(q.word.example).italic()
                    Text(q.word.exampleTranslation).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            if chosen != nil {
                Button {
                    withAnimation { chosen = nil; index += 1 }
                } label: {
                    Text(index + 1 < questions.count ? "Next" : "See results").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var results: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(score == questions.count ? "¡Perfecto! 🎉" : score * 10 >= questions.count * 7 ? "¡Muy bien! 👏" : "¡Sigue así! 💪")
                .font(.largeTitle.bold())
            Text("\(score) of \(questions.count) correct").font(.title3)
            if !missed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review these").font(.headline)
                    ForEach(missed) { w in
                        HStack {
                            Text(w.spanish).bold()
                            Text("— \(w.english)").foregroundStyle(.secondary)
                            Spacer()
                            Button { speaker.speak(w.spanish) } label: { Image(systemName: "speaker.wave.2.fill") }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private func answer(_ option: String, for q: QuizQuestion) {
        let correct = option == q.answer
        withAnimation { chosen = option }
        LearningProgress.recordAnswer(id: q.word.id, correct: correct)
        if correct {
            score += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            missed.append(q.word)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func background(for option: String, q: QuizQuestion) -> Color {
        guard let chosen else { return Color(.secondarySystemGroupedBackground) }
        if option == q.answer { return .green.opacity(0.18) }
        if option == chosen { return .red.opacity(0.18) }
        return Color(.secondarySystemGroupedBackground)
    }
}
