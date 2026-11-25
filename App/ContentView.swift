import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage(AppSettings.Key.quizzesEnabled, store: AppSettings.defaults) private var quizzesEnabled = true

    var body: some View {
        TabView(selection: $router.tab) {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
                .tag(AppRouter.Tab.today)
            ReviewView()
                .tabItem { Label("Review", systemImage: "rectangle.stack.fill") }
                .tag(AppRouter.Tab.review)
            if quizzesEnabled {
                QuizHomeView()
                    .tabItem { Label("Quiz", systemImage: "checkmark.seal.fill") }
                    .tag(AppRouter.Tab.quiz)
            }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .sheet(item: $router.presentedWord) { word in
            NavigationStack {
                ScrollView { WordCardView(word: word, autoplay: router.autoplay).padding() }
                    .navigationTitle(word.spanish)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { router.presentedWord = nil }
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }
}

/// Changes to the rotation that the widget and notifications must follow.
enum Rotation {
    /// "Next word": move the whole schedule forward by one. The widget, notifications and
    /// "Coming up" all shift together, and the clock carries on from the new position.
    @MainActor
    static func skipAhead() {
        LearningProgress.catchUp()
        AppSettings.skipOffset += 1
        LearningProgress.catchUp()
        didChange()
    }

    static func didChange() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await NotificationScheduler.reschedule() }
    }
}

struct TodayView: View {
    @EnvironmentObject private var speaker: Speaker

    // Observed so the view refreshes when the rotation changes.
    @AppStorage(AppSettings.Key.skipOffset, store: AppSettings.defaults) private var skipOffset = 0
    @AppStorage(AppSettings.Key.level, store: AppSettings.defaults) private var levelRaw = Level.novice.rawValue
    @AppStorage(AppSettings.Key.focus, store: AppSettings.defaults) private var focusRaw = Focus.everything.rawValue
    @AppStorage(AppSettings.Key.includeEarlierLevels, store: AppSettings.defaults) private var includeEarlier = false
    @AppStorage(AppSettings.Key.cadence, store: AppSettings.defaults) private var cadenceRaw = Cadence.hourly.rawValue

    @State private var skippedToday = 0

    var body: some View {
        NavigationStack {
            // Re-evaluates every minute so the card flips when the word changes.
            TimelineView(.everyMinute) { context in
                let schedule = WordSchedule.current
                let word = schedule.word(at: context.date)
                let next = schedule.nextChange(after: context.date)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        WordCardView(word: word)
                            .id(word.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))

                        Button {
                            withAnimation(.snappy) { Rotation.skipAhead() }
                            skippedToday += 1
                        } label: {
                            Label("Learn the next word now", systemImage: "forward.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        if skippedToday > 0 {
                            Text("You've jumped ahead \(skippedToday) \(skippedToday == 1 ? "word" : "words") — the widget and notifications follow along.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        NextUpView(nextChange: next, upcoming: schedule.upcoming(after: context.date, count: 3))
                    }
                    .padding()
                }
            }
            .navigationTitle("Palabra de la hora")
            .background(Color(.systemGroupedBackground))
            .onAppear { LearningProgress.catchUp() }
        }
    }
}

private struct NextUpView: View {
    let nextChange: Date
    let upcoming: [UpcomingWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock")
                Text("Next word ") + Text(nextChange, style: .relative)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Text("Coming up: no peeking at the meaning!")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack {
                ForEach(upcoming, id: \.date) { item in
                    VStack(spacing: 2) {
                        Text(item.word.spanish)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .animation(.snappy, value: upcoming.map(\.word.id))
        }
    }
}
