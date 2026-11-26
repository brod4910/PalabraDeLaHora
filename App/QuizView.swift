import SwiftUI

// MARK: - Model

enum QuizMode: String, CaseIterable, Identifiable {
    case written, verbal          // raw values kept so the saved choice survives the rename
    var id: String { rawValue }
    var label: String { self == .written ? "Multiple choice" : "Listen & speak" }
    var summary: String {
        switch self {
        case .written: "See the Spanish word (tap to hear it) and pick what it means. No typing, no full sentences to translate."
        case .verbal: "Hear a word and pick its meaning, repeat after the voice, or say the Spanish for an English word. Tap the mic when you're ready."
        }
    }
}

struct QuizQuestion: Identifiable {
    enum Style {
        // Multiple choice
        case meaning      // Spanish word (+ hear it, + example) → pick English
        case reverse      // English → pick the Spanish word (only for words she's already got right)
        // Listen & speak
        case listen       // hear the word (not shown) → pick English
        case repeatWord   // see + hear the word → say it
        case sayIt        // see the English → say the Spanish

        var usesMicrophone: Bool { self == .repeatWord || self == .sayIt }
    }

    let id = UUID()
    let word: Word
    let style: Style
    let options: [String]
    let answer: String

    var instruction: String {
        switch style {
        case .meaning: "What does this word mean?"
        case .reverse: "Which word means this?"
        case .listen: "Listen. What does it mean?"
        case .repeatWord: "Listen, then say it."
        case .sayIt: "How do you say this in Spanish?"
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

    /// Easier styles for words she hasn't got right yet; harder ones once she has.
    private static func question(for word: Word, mode: QuizMode) -> QuizQuestion {
        let known = LearningProgress.record(for: word.id).right > 0
        let styles: [QuizQuestion.Style]
        switch mode {
        case .written: styles = known ? [.meaning, .meaning, .reverse] : [.meaning]
        case .verbal: styles = known ? [.listen, .repeatWord, .sayIt, .sayIt] : [.listen, .repeatWord, .repeatWord]
        }
        let style = styles.randomElement()!
        switch style {
        case .meaning, .listen:
            return QuizQuestion(word: word, style: style, options: options(word, \.english), answer: word.english)
        case .reverse:
            return QuizQuestion(word: word, style: style, options: options(word, \.spanish), answer: word.spanish)
        case .repeatWord, .sayIt:
            return QuizQuestion(word: word, style: style, options: [], answer: word.spanish)
        }
    }

    private static func options(_ word: Word, _ field: KeyPath<Word, String>) -> [String] {
        (distractors(for: word, by: field) + [word[keyPath: field]]).shuffled()
    }

    /// Three distinct wrong answers, all from words she has already seen, so every choice is
    /// something she has met (words of the same kind first: words with words, phrases with
    /// phrases). Only if she has seen too few does it fall back to unseen words of her level.
    private static func distractors(for word: Word, by field: KeyPath<Word, String>) -> [String] {
        let usable: (Word) -> Bool = {
            $0.id != word.id && $0.english != word.english && $0.spanish != word.spanish
        }
        let seen = LearningProgress.seenWords().filter(usable).shuffled()
        let seenIDs = Set(seen.map(\.id))
        let fallback = WordBank.all.filter { usable($0) && !seenIDs.contains($0.id) }
            .sorted { ($0.level == word.level ? 0 : 1) < ($1.level == word.level ? 0 : 1) }
        let ordered = seen.filter { $0.kind == word.kind } + seen.filter { $0.kind != word.kind }
            + fallback.filter { $0.kind == word.kind }.shuffled()
        var result: [String] = []
        for candidate in ordered.map({ $0[keyPath: field] }) where !result.contains(candidate) {
            result.append(candidate)
            if result.count == 3 { break }
        }
        return result
    }
}

// MARK: - Home

struct QuizHomeView: View {
    @AppStorage("quizMode", store: AppSettings.defaults) private var modeRaw = QuizMode.written.rawValue
    @AppStorage(AppSettings.Key.quizSounds, store: AppSettings.defaults) private var soundsOn = true

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

                        Toggle("Sounds", isOn: $soundsOn)
                            .font(.subheadline)

                        Button {
                            Task { await start(with: seen) }
                        } label: {
                            Label("Start a quiz",
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
                QuizSessionView(run: run)
            }
            .alert("Microphone access needed", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Listen & speak quizzes need the microphone and speech recognition. Turn them on for Palabra in Settings.")
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

    init(run: QuizRun) {
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
                        if q.style.usesMicrophone {
                            SpeakQuestionView(question: q, listener: listener,
                                              onResult: { pending = $0 }, onNext: next)
                        } else {
                            ChoiceQuestionView(question: q, onResult: { pending = $0 }, onNext: next)
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
                    .onAppear { QuizSounds.play(.complete) }

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

// MARK: - Multiple choice (and "listen" in Listen & speak)

private struct ChoiceQuestionView: View {
    let question: QuizQuestion
    let onResult: (Bool) -> Void
    let onNext: () -> Void

    @EnvironmentObject private var speaker: Speaker
    @State private var chosen: String?

    private var word: Word { question.word }
    private var answered: Bool { chosen != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(question.instruction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                prompt

                // The word in use, above the choices (after answering for listen / reverse,
                // where the sentence would give the answer away).
                if question.style == .meaning || answered {
                    exampleCard
                }

                choices

                if answered {
                    Button(action: onNext) {
                        Text("Next").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .onAppear {
            if question.style == .listen { speaker.speak(word.spanish) }
        }
    }

    @ViewBuilder
    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch question.style {
            case .reverse:
                Text(word.english)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            case .listen where !answered:
                Text("🎧  Tap to hear it again")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            default:
                Text(word.spanish)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text(word.phonetic)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            if question.style != .reverse || answered {
                HStack {
                    QuizAudioButton(title: "Hear it", systemImage: "speaker.wave.2.fill") { speaker.speak(word.spanish) }
                    QuizAudioButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(word.spanish, slow: true) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var choices: some View {
        VStack(spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    let correct = option == question.answer
                    withAnimation { chosen = option }
                    onResult(correct)
                    QuizSounds.play(correct ? .correct : .wrong)
                    UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
                } label: {
                    HStack {
                        Text(option).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                        Spacer()
                        if answered, option == question.answer {
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
                .disabled(answered)
            }
        }
    }

    /// The word in use. Before answering only the Spanish shows (the English would give it away).
    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(answered ? "\(word.spanish) — \(word.allMeanings)" : "In a sentence",
                  systemImage: "text.quote")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.coral)
            Text(highlighted(word.example, word: word.exampleWord, color: Theme.coral))
                .font(.title3.weight(.medium))
                .fontDesign(.serif)
                .italic()
            if answered {
                Text(word.exampleTranslation).foregroundStyle(.secondary)
            }
            HStack {
                QuizAudioButton(title: "Play", systemImage: "play.fill") { speaker.speak(word.example) }
                QuizAudioButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(word.example, slow: true) }
            }
            .padding(.top, 2)
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

private struct QuizAudioButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.coral.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.coral)
    }
}

// MARK: - Speak (Listen & speak)

/// Repeat after me, or say the Spanish for an English word. Everything is on screen; the only
/// voice is the Spanish one (the recorded clips when bundled). She taps the mic when ready.
private struct SpeakQuestionView: View {
    let question: QuizQuestion
    @ObservedObject var listener: SpeechListener
    let onResult: (Bool) -> Void
    let onNext: () -> Void

    @EnvironmentObject private var speaker: Speaker

    enum Phase { case ready, listening, correct, wrong }
    @State private var phase: Phase = .ready
    @State private var heard = ""
    @State private var listenTask: Task<Void, Never>?

    private var word: Word { question.word }
    private var done: Bool { phase == .correct || phase == .wrong }

    var body: some View {
        VStack(spacing: 20) {
            Text(question.instruction)
                .font(.title3.weight(.semibold))

            promptCard

            Button(action: micTapped) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 150, height: 150)
                        .scaleEffect(phase == .listening ? 1.08 : 1)
                        .animation(phase == .listening ? .easeInOut(duration: 0.8).repeatForever() : .default, value: phase)
                    Image(systemName: icon)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .buttonStyle(.plain)
            .disabled(done)
            .accessibilityLabel(statusText)

            Text(statusText).font(.headline).foregroundStyle(.secondary)

            let shown = phase == .listening ? listener.transcript : heard
            if !shown.isEmpty {
                Text("You said: “\(shown)”")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }

            if done {
                answerCard
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                if phase == .wrong {
                    HStack {
                        Button {
                            phase = .ready; heard = ""
                        } label: { Label("Try again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        // Speech recognition isn't perfect — let her overrule it.
                        Button {
                            onResult(true)
                            onNext()
                        } label: { Label("I said it right", systemImage: "hand.thumbsup.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                    }
                }
                if done {
                    Button(action: onNext) { Text("Next").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button("Skip") {
                        stopListening()
                        onResult(false)
                        onNext()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if question.style == .repeatWord { speaker.speak(word.spanish) }
        }
        .onDisappear {
            stopListening()
            speaker.stop()
        }
    }

    @ViewBuilder
    private var promptCard: some View {
        VStack(spacing: 10) {
            if question.style == .repeatWord {
                Text(word.spanish).font(.system(size: 38, weight: .bold, design: .rounded))
                Text(word.phonetic).font(.callout.monospaced()).foregroundStyle(.secondary)
                HStack {
                    QuizAudioButton(title: "Hear it", systemImage: "speaker.wave.2.fill") { speaker.speak(word.spanish) }
                    QuizAudioButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(word.spanish, slow: true) }
                }
            } else {
                Text(word.english).font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var answerCard: some View {
        VStack(spacing: 6) {
            Text(word.spanish).font(.title2.bold())
            Text(word.allMeanings).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                QuizAudioButton(title: "Hear it", systemImage: "speaker.wave.2.fill") { speaker.speak(word.spanish) }
                QuizAudioButton(title: "Slow", systemImage: "tortoise.fill") { speaker.speak(word.spanish, slow: true) }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Flow

    private func micTapped() {
        if phase == .listening {
            listener.stopNow()          // the listen task finishes and grades
            return
        }
        speaker.stop()
        heard = ""
        phase = .listening
        listenTask = Task {
            let text = await listener.listen(language: AppSettings.voice.rawValue, hints: [word.spanish])
            guard !Task.isCancelled else { return }
            heard = text
            if text.isEmpty {
                phase = .ready          // nothing heard: just let her tap again
                return
            }
            let correct = AnswerMatcher.matchesSpanish(spoken: text, target: word.spanish)
            phase = correct ? .correct : .wrong
            onResult(correct)
            QuizSounds.play(correct ? .correct : .wrong)
            UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
            // Hear the right answer in the Spanish voice either way, after the chime.
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            speaker.speak(word.spanish)
        }
    }

    private func stopListening() {
        listenTask?.cancel()
        listener.stopNow()
    }

    private var icon: String {
        switch phase {
        case .ready: "mic.fill"
        case .listening: "waveform"
        case .correct: "checkmark"
        case .wrong: "xmark"
        }
    }

    private var color: Color {
        switch phase {
        case .ready: Theme.magenta
        case .listening: Theme.coral
        case .correct: .green
        case .wrong: .red
        }
    }

    private var statusText: String {
        switch phase {
        case .ready: heard.isEmpty ? "Tap the mic, then speak" : "Didn't catch that — tap and try again"
        case .listening: "Listening… tap when you're done"
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
