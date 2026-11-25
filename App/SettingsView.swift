import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject private var speaker: Speaker

    @AppStorage(AppSettings.Key.cadence, store: AppSettings.defaults) private var cadenceRaw = Cadence.hourly.rawValue
    @AppStorage(AppSettings.Key.voice, store: AppSettings.defaults) private var voiceRaw = SpanishVoice.mexico.rawValue
    @AppStorage(AppSettings.Key.speechRate, store: AppSettings.defaults) private var speechRate = 0.9
    @AppStorage(AppSettings.Key.notificationsEnabled, store: AppSettings.defaults) private var notificationsOn = false
    @AppStorage(AppSettings.Key.quietStart, store: AppSettings.defaults) private var quietStart = 21
    @AppStorage(AppSettings.Key.quietEnd, store: AppSettings.defaults) private var quietEnd = 8

    @AppStorage(AppSettings.Key.level, store: AppSettings.defaults) private var levelRaw = Level.novice.rawValue
    @AppStorage(AppSettings.Key.includeEarlierLevels, store: AppSettings.defaults) private var includeEarlier = false
    @AppStorage(AppSettings.Key.focus, store: AppSettings.defaults) private var focusRaw = Focus.everything.rawValue
    @AppStorage(AppSettings.Key.quizzesEnabled, store: AppSettings.defaults) private var quizzesEnabled = true

    @State private var confirmReshuffle = false
    @State private var confirmResetQuiz = false

    private var level: Level { Level(rawValue: levelRaw) ?? .novice }
    private var deckCount: Int {
        WordBank.deck(level: level, includeEarlier: includeEarlier, focus: Focus(rawValue: focusRaw) ?? .everything).count
    }
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Level", selection: $levelRaw) {
                        ForEach(Level.allCases) { Text("\($0.label) (\($0.cefr))").tag($0.rawValue) }
                    }
                    Text(level.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Focus", selection: $focusRaw) {
                        ForEach(Focus.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    Toggle("Mix in earlier levels", isOn: $includeEarlier)
                        .disabled(level == .novice || focusRaw == Focus.phrases.rawValue)
                } header: {
                    Text("What to learn")
                } footer: {
                    Text("\(deckCount) cards in rotation. “Everyday phrases” is ready-to-say spoken Spanish and always includes phrases from easier levels.")
                }

                Section {
                    Picker("New word", selection: $cadenceRaw) {
                        ForEach(Cadence.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                } header: {
                    Text("Cadence")
                } footer: {
                    Text("The widget, notifications and the Hoy tab all switch to the next word on this schedule. Want more? Tap “Learn the next word now” on the Hoy tab any time.")
                }

                Section("Pronunciation") {
                    Picker("Accent", selection: $voiceRaw) {
                        ForEach(SpanishVoice.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    VStack(alignment: .leading) {
                        Text("Speed")
                        HStack {
                            Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                            Slider(value: $speechRate, in: 0.5...1.2, step: 0.05)
                            Image(systemName: "hare.fill").foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        speaker.speak("Hola, mi amor. ¿Cómo estás hoy?")
                    } label: {
                        Label("Test voice", systemImage: "speaker.wave.2.fill")
                    }
                    if !Speaker.hasHighQualityVoice(for: voiceRaw) {
                        Text("For a more natural voice, download an Enhanced Spanish voice in Settings › Accessibility › Spoken Content › Voices › Spanish.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Notify me with each new word", isOn: $notificationsOn)
                    if notificationsOn {
                        Picker("Quiet from", selection: $quietStart) {
                            ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                        }
                        Picker("Until", selection: $quietEnd) {
                            ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationsDenied {
                        Text("Notifications are turned off for Palabra in the Settings app.")
                            .foregroundStyle(.red)
                    } else {
                        Text("No notifications during quiet hours. The widget keeps updating either way.")
                    }
                }

                Section {
                    Toggle("Quizzes", isOn: $quizzesEnabled)
                    Button("Reset quiz progress", role: .destructive) { confirmResetQuiz = true }
                } header: {
                    Text("Quizzes")
                } footer: {
                    Text("Optional quizzes use only words you've already seen, and ask the ones you miss more often.")
                }

                Section {
                    Button("Reshuffle word order", role: .destructive) { confirmReshuffle = true }
                } footer: {
                    Text("Starts a new random order and clears the “Seen” list.")
                }

                Section("About") {
                    LabeledContent("Cards in the app", value: "\(WordBank.all.count)")
                    LabeledContent("Seen so far", value: "\(LearningProgress.seen.count)")
                    LabeledContent("Learning since", value: AppSettings.startDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reshuffle the word order?", isPresented: $confirmReshuffle, titleVisibility: .visible) {
                Button("Reshuffle", role: .destructive) {
                    AppSettings.reshuffle()
                    LearningProgress.resetSeen()
                    scheduleChanged()
                }
            }
            .confirmationDialog("Reset all quiz progress?", isPresented: $confirmResetQuiz, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { LearningProgress.resetQuizStats() }
            }
            .onChange(of: levelRaw) { scheduleChanged() }
            .onChange(of: focusRaw) { scheduleChanged() }
            .onChange(of: includeEarlier) { scheduleChanged() }
            .onChange(of: cadenceRaw) { scheduleChanged() }
            .onChange(of: quietStart) { Task { await NotificationScheduler.reschedule() } }
            .onChange(of: quietEnd) { Task { await NotificationScheduler.reschedule() } }
            .onChange(of: notificationsOn) { _, on in
                Task {
                    if on {
                        let granted = await NotificationScheduler.requestAuthorization()
                        notificationsDenied = !granted
                        if !granted { notificationsOn = false }
                    }
                    await NotificationScheduler.reschedule()
                }
            }
        }
    }

    private func scheduleChanged() {
        LearningProgress.catchUp()
        Rotation.didChange()
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
