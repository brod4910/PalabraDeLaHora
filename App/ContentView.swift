import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
                .tag(AppRouter.Tab.today)
            ReviewView()
                .tabItem { Label("Review", systemImage: "rectangle.stack.fill") }
                .tag(AppRouter.Tab.review)
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

struct TodayView: View {
    @EnvironmentObject private var router: AppRouter

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
                        NextUpView(nextChange: next, upcoming: schedule.upcoming(after: context.date, count: 3))
                    }
                    .padding()
                }
            }
            .navigationTitle("Palabra de la hora")
            .background(Color(.systemGroupedBackground))
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
                        Text(item.word.spanish).font(.callout.weight(.semibold))
                        Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}
