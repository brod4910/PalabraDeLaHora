import SwiftUI

// MARK: - Model

enum QuizMode: String, CaseIterable, Identifiable {
    case written, verbal
    var id: String { rawValue }
    var label: String { self == .written ? "Written" : "Verbal" }
    var summary: String {
        switch self {
        case .written: "Read and answer: multiple choice, fill in the blank, and typing the Spanish."
        case .verbal: "Eyes-free: the app asks out loud and you answer out loud. Say it in Spanish, say what it means, and repeat after me."
        }
    }
}

struct QuizQuestion: Identifiable {
    enum Style {
        // Written
        case meaning      // Spanish → pick English
        case reverse      // English → pick Spanish
        case fillBlank    // sentence with a gap → pick Spanish
        case typeIt       // English → type Spanish
        // Verbal
        case sayIt            // hear English → say Spanish
        case whatDoesItMean   // hear Spanish → say English
        case repeatAfterMe    // hear the example sentence → repeat it

        var isVerbal: Bool { [.sayIt, .whatDoesItMean, .repeatAfterMe].contains(self) }
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
        case .fillBlank: "Fill in the blank."
        case .typeIt: "Type it in Spanish."
        case .sayIt: "Say it in Spanish."
        case .whatDoesItMean: "Say what it means in English."
        case .repeatAfterMe: "Repeat after me."
        }
    }
}

/// One quiz run: the questions plus the mode, so "quiz me again" keeps the same mode.
struct QuizRun: Identifiable {
    let id = UUID()
    let mode: QuizMode
    let questions: [QuizQuestion]
}

enum QuizBuilder {
    static let minimumWords = 4

    /// A fresh, shuffled quiz every time. Weaker words are more likely to be picked: candidates are
    /// the weakest 2× `count` (with random jitter), and a random `count` of those are used. Question
    /// styles and answer order are re-rolled on every run too.
    static func make(from words: [Word], mode: QuizMode, count: Int = 10) -> [QuizQuestion] {
        guard !words.isEmpty, count > 0 else { return [] }
        let candidates = words
            .map { ($0, LearningProgress.record(for: $0.id).priority + Double.random(in: 0...0.35)) }
            .sorted { $0.1 < $1.1 }
            .prefix(count * 2)
            .map(\.0)
        return candidates.shuffled().prefix(count).map { question(for: $0, mode: mode) }
    }

    private static func question(for word: Word, mode: QuizMode) -> QuizQuestion {
        var styles: [QuizQuestion.Style]
        switch mode {
        case .written:
            styles = [.meaning, .reverse, .typeIt]
            if blanked(word) != nil { styles += [.fillBlank, .fillBlank] }
        case .verbal:
            styles = [.sayIt, .sayIt, .whatDoesItMean, .repeatAfterMe]
        }
        let style = styles.randomElement()!

        switch style {
        case .meaning:
            return QuizQuestion(word: word, style: style, prompt: word.spanish,
                                options: options(word, \.english), answer: word.english)
        case .reverse:
            return QuizQuestion(word: word, style: style, prompt: word.english,
                                options: options(word, \.spanish), answer: word.spanish)
        case .fillBlank:
            return QuizQuestion(word: word, style: style, prompt: blanked(word)!,
                                options: options(word, \.spanish), answer: word.spanish)
        case .typeIt, .sayIt:
            return QuizQuestion(word: word, style: style, prompt: word.english, options: [], answer: word.spanish)
        case .whatDoesItMean:
            return QuizQuestion(word: word, style: style, prompt: word.spanish, options: [], answer: word.english)
        case .repeatAfterMe:
            return QuizQuestion(word: word, style: style, prompt: word.example, options: [], answer: word.example)
        }
    }

    /// The example sentence with the word blanked out, when the word appears as-is.
    static func blanked(_ word: Word) -> String? {
        guard word.spanish.count > 2,
              let range = word.example.range(of: word.spanish, options: [.caseInsensitive]) else { return nil }
        return word.example.replacingCharacters(in: range, with: "_____")
    }

    private static func options(_ word: Word, _ field: KeyPath<Word, String>) -> [String] {
        (distractors(for: word, by: field) + [word[keyPath: field]]).shuffled()
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

    /// English as it should be read aloud: "to want / to love" → "to want, or to love".
    static func spokenEnglish(_ s: String) -> String {
        s.replacingOccurrences(of: " / ", with: ", or ")
            .replacingOccurrences(of: "(", with: ", ")
            .replacingOccurrences(of: ")", with: "")
    }
}

// MARK: - Home

struct QuizHomeView: View {
    @AppStorage("quizMode", store: AppSettings.defaults) private var modeRaw = QuizMode.written.rawValue
    @AppStorage("quizHandsFree", store: AppSettings.defaults) private var handsFree = true

    @State private var run: QuizRun?
    @State private var refresh = UUID()
    @State private var permissionDenied = false

    private var mode: QuizMode { QuizMode(rawValue: modeRaw) ?? .written }

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

                        Picker("Mode", selection: $modeRaw) {
                            ForEach(QuizMode.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)

                        Text(mode.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if mode == .verbal {
                            Toggle("Hands-free (moves on by itself)", isOn: $handsFree)
                                .font(.subheadline)
                        }

                        Button {
                            Task { await start(with: seen) }
                        } label: {
                            Label("Start a \(mode.label.lowercased()) quiz",
                                  systemImage: mode == .verbal ? "mic.fill" : "pencil")
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
                                    Text(word.allMeanings).font(.subheadline).foregroundStyle(.secondary)
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
            .fullScreenCover(item: $run, onDismiss: { refresh = UUID() }) { run in
                QuizSessionView(run: run, handsFree: handsFree)
            }
            .alert("Microphone access needed", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Verbal quizzes need the microphone and speech recognition. Turn them on for Palabra in Settings.")
            }
            .onAppear { LearningProgress.catchUp(); refresh = UUID() }
        }
    }

    private func start(with seen: [Word]) async {
        if mode == .verbal {
            guard await SpeechListener.requestPermissions() else { permissionDenied = true; return }
        }
        run = QuizRun(mode: mode, questions: QuizBuilder.make(from: seen, mode: mode))
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
    let handsFree: Bool

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var speaker: Speaker
    @StateObject private var listener = SpeechListener()

    @State private var mode: QuizMode
    @State private var questions: [QuizQuestion]
    @State private var index = 0
    /// Result of the current question; can still change (e.g. "I said it right") until Next.
    @State private var pending: Bool?
    @State private var score = 0
    @State private var missed: [Word] = []
    @State private var reviewingMissed = false

    init(run: QuizRun, handsFree: Bool) {
        self.handsFree = handsFree
        _mode = State(initialValue: run.mode)
        _questions = State(initialValue: run.questions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if index < questions.count {
                    let q = questions[index]
                    VStack(spacing: 16) {
                        ProgressView(value: Double(index), total: Double(questions.count))
                        if q.style.isVerbal {
                            VerbalQuestionView(question: q, handsFree: handsFree, listener: listener,
                                               onResult: { pending = $0 }, onNext: next)
                        } else {
                            WrittenQuestionView(question: q, onResult: { pending = $0 }, onNext: next)
                        }
                    }
                    .id(q.id) // fresh state for every question
                } else {
                    results
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(index < questions.count ? "Question \(index + 1) of \(questions.count)" : "Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        listener.stopNow()
                        speaker.stop()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $reviewingMissed) {
                MissedReviewView(words: missed)
            }
        }
    }

    private func next() {
        guard index < questions.count else { return }
        let word = questions[index].word
        let correct = pending ?? false
        LearningProgress.recordAnswer(id: word.id, correct: correct)
        if correct { score += 1 } else if !missed.contains(word) { missed.append(word) }
        pending = nil
        withAnimation { index += 1 }
    }

    /// Starts a new, freshly shuffled run in the same mode.
    private func restart(with words: [Word]) {
        questions = QuizBuilder.make(from: words, mode: mode, count: min(words.count, 10))
        index = 0
        score = 0
        missed = []
        pending = nil
    }

    private var results: some View {
        let total = questions.count
        return ScrollView {
            VStack(spacing: 16) {
                Text(score == total ? "¡Perfecto! 🎉" : score * 10 >= total * 7 ? "¡Muy bien! 👏" : "¡Sigue así! 💪")
                    .font(.largeTitle.bold())
                    .padding(.top, 24)
                Text("\(score) of \(total) correct").font(.title3)

                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Missed").font(.headline)
                        ForEach(missed) { w in
                            HStack {
                                Text(w.spanish).bold()
                                Text("— \(w.allMeanings)").foregroundStyle(.secondary).lineLimit(1)
                                Spacer()
                                Button { speaker.speak(w.spanish) } label: { Image(systemName: "speaker.wave.2.fill") }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        reviewingMissed = true
                    } label: {
                        Label("Review missed words", systemImage: "rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        restart(with: missed)
                    } label: {
                        Label("Quiz me on the missed words", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button {
                    restart(with: LearningProgress.seenWords())
                } label: {
                    Label("New shuffled quiz", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Done") { dismiss() }
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Written questions

private struct WrittenQuestionView: View {
    let question: QuizQuestion
    let onResult: (Bool) -> Void
    let onNext: () -> Void

    @EnvironmentObject private var speaker: Speaker
    @State private var chosen: String?
    @State private var typed = ""
    @State private var typedResult: AnswerMatcher.TypedResult?
    @FocusState private var fieldFocused: Bool

    private var answered: Bool { chosen != nil || typedResult != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(question.instruction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(question.style == .fillBlank ? .title2.weight(.medium) : .system(size: 34, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if question.style == .typeIt {
                    typingArea
                } else {
                    choices
                }

                if answered {
                    explanation
                    Button(action: onNext) {
                        Text("Next").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var choices: some View {
        VStack(spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    let correct = option == question.answer
                    withAnimation { chosen = option }
                    onResult(correct)
                    UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
                } label: {
                    HStack {
                        Text(option).multilineTextAlignment(.leading)
                        Spacer()
                        if chosen != nil, option == question.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if chosen == option {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: option), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(chosen != nil)
            }
        }
    }

    private var typingArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Escribe en español…", text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3)
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .focused($fieldFocused)
                .disabled(typedResult != nil)
                .onSubmit(check)
                .onAppear { fieldFocused = true }

            if let typedResult {
                Label(feedback(typedResult), systemImage: typedResult.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(typedResult.isCorrect ? .green : .red)
                    .font(.headline)
            } else {
                // Accent keys, since most English keyboards hide them behind a long-press.
                HStack(spacing: 6) {
                    ForEach(["á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡"], id: \.self) { ch in
                        Button(ch) { typed.append(ch) }
                            .font(.title3)
                            .frame(minWidth: 32, minHeight: 36)
                            .background(Color(.tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .buttonStyle(.plain)
                    }
                }
                Button("Check", action: check)
                    .buttonStyle(.borderedProminent)
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func check() {
        guard typedResult == nil, !typed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let result = AnswerMatcher.checkTyped(typed, target: question.answer)
        withAnimation { typedResult = result }
        onResult(result.isCorrect)
        UINotificationFeedbackGenerator().notificationOccurred(result.isCorrect ? .success : .error)
    }

    private func feedback(_ r: AnswerMatcher.TypedResult) -> String {
        switch r {
        case .exact: "¡Correcto!"
        case .missingAccents: "Correct — watch the accents: \(question.answer)"
        case .typo: "Close enough — it's spelled \(question.answer)"
        case .wrong: "The answer is \(question.answer)"
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(question.word.spanish) — \(question.word.allMeanings)").font(.headline)
                Spacer()
                Button { speaker.speak([question.word.spanish, question.word.example]) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
            Text(question.word.example).italic()
            Text(question.word.exampleTranslation).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity)
    }

    private func background(for option: String) -> Color {
        guard let chosen else { return Color(.secondarySystemGroupedBackground) }
        if option == question.answer { return .green.opacity(0.18) }
        if option == chosen { return .red.opacity(0.18) }
        return Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Verbal questions

/// Fully spoken question: the prompt is read aloud, the answer is heard through the mic, feedback
/// is spoken, and in hands-free mode it moves on by itself.
private struct VerbalQuestionView: View {
    let question: QuizQuestion
    let handsFree: Bool
    @ObservedObject var listener: SpeechListener
    let onResult: (Bool) -> Void
    let onNext: () -> Void

    @EnvironmentObject private var speaker: Speaker

    enum Phase { case asking, listening, correct, wrong }
    @State private var phase: Phase = .asking
    @State private var heard = ""
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 22) {
            Text(question.instruction)
                .font(.title3.weight(.semibold))

            Button {
                if phase == .listening { listener.stopNow() }
            } label: {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 170, height: 170)
                        .scaleEffect(phase == .listening ? 1.08 : 1)
                        .animation(phase == .listening ? .easeInOut(duration: 0.8).repeatForever() : .default, value: phase)
                    Image(systemName: icon)
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(phase == .listening ? "Stop listening" : statusText)

            Text(statusText).font(.headline).foregroundStyle(.secondary)

            let shown = phase == .listening ? listener.transcript : heard
            if !shown.isEmpty {
                Text("“\(shown)”")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }

            if phase == .correct || phase == .wrong {
                VStack(spacing: 4) {
                    Text(question.word.spanish).font(.title2.bold())
                    Text(question.word.allMeanings).foregroundStyle(.secondary)
                    if question.style == .repeatAfterMe {
                        Text(question.word.example).italic().multilineTextAlignment(.center).padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                if phase == .wrong {
                    // Speech recognition isn't perfect — let her overrule it.
                    Button {
                        onResult(true)
                        onNext()
                    } label: {
                        Label("I said it right", systemImage: "hand.thumbsup.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Button {
                        listener.stopNow()
                        speaker.stop()
                        attempt += 1
                    } label: { Label("Ask again", systemImage: "arrow.counterclockwise") }
                    Spacer()
                    if (phase == .correct || phase == .wrong) && !handsFree {
                        Button("Next", action: onNext).buttonStyle(.borderedProminent)
                    } else {
                        Button("Skip") {
                            listener.stopNow()
                            speaker.stop()
                            onResult(false)
                            onNext()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: attempt) { await run() }
        .onDisappear {
            listener.stopNow()
            speaker.stop()
        }
    }

    // MARK: Flow

    private func run() async {
        phase = .asking
        heard = ""
        await speaker.say(promptParts)
        guard !Task.isCancelled else { return }

        var text = ""
        for tryNumber in 0..<2 {
            phase = .listening
            text = await listener.listen(language: answerLanguage, hints: [question.answer])
            guard !Task.isCancelled else { return }
            if !text.isEmpty || tryNumber == 1 { break }
            await speaker.say([.english("I didn't catch that. Try again.")])
            guard !Task.isCancelled else { return }
        }

        heard = text
        let correct = grade(text)
        phase = correct ? .correct : .wrong
        onResult(correct)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)

        await speaker.say(feedbackParts(correct))
        guard handsFree, !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(correct ? 0.6 : 2.0))
        guard !Task.isCancelled else { return }
        onNext()
    }

    private var answerLanguage: String {
        question.style == .whatDoesItMean ? "en-US" : AppSettings.voice.rawValue
    }

    private func grade(_ text: String) -> Bool {
        switch question.style {
        case .sayIt: AnswerMatcher.matchesSpanish(spoken: text, target: question.word.spanish)
        case .whatDoesItMean: AnswerMatcher.matchesEnglish(spoken: text, english: question.word.allMeanings.replacingOccurrences(of: " · ", with: " / "))
        case .repeatAfterMe: AnswerMatcher.overlap(spoken: text, sentence: question.word.example) >= 0.7
        default: false
        }
    }

    private var promptParts: [Speaker.Part] {
        switch question.style {
        case .sayIt:
            [.english("How do you say: \(QuizBuilder.spokenEnglish(question.word.english))?")]
        case .whatDoesItMean:
            [.english("What does this mean?", pause: 0.4), .spanish(question.word.spanish)]
        case .repeatAfterMe:
            [.english("Repeat after me.", pause: 0.4), .spanish(question.word.example)]
        default:
            []
        }
    }

    private func feedbackParts(_ correct: Bool) -> [Speaker.Part] {
        if correct { return [.spanish("¡Correcto!")] }
        switch question.style {
        case .sayIt:
            return [.english("The answer is", pause: 0.2), .spanish(question.word.spanish)]
        case .whatDoesItMean:
            return [.english("It means: \(QuizBuilder.spokenEnglish(question.word.allMeanings.replacingOccurrences(of: " · ", with: " / ")))")]
        case .repeatAfterMe:
            return [.english("Listen once more.", pause: 0.3), .spanish(question.word.example)]
        default:
            return []
        }
    }

    private var icon: String {
        switch phase {
        case .asking: "speaker.wave.3.fill"
        case .listening: "mic.fill"
        case .correct: "checkmark"
        case .wrong: "xmark"
        }
    }

    private var color: Color {
        switch phase {
        case .asking: Theme.magenta
        case .listening: Theme.coral
        case .correct: .green
        case .wrong: .red
        }
    }

    private var statusText: String {
        switch phase {
        case .asking: "Listen…"
        case .listening: "Your turn — speak now (tap to finish)"
        case .correct: "¡Correcto!"
        case .wrong: "Not quite"
        }
    }
}

// MARK: - Review missed

/// Swipe through the full study cards (with audio) for every missed word.
struct MissedReviewView: View {
    let words: [Word]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(words) { word in
                    ScrollView { WordCardView(word: word).padding() }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review missed words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
