import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject private var speaker: Speaker

    @AppStorage(AppSettings.Key.cadence, store: AppSettings.defaults) private var cadenceRaw = Cadence.hourly.rawValue
    @AppStorage(AppSettings.Key.voice, store: AppSettings.defaults) private var voiceRaw = SpanishVoice.mexico.rawValue
    @AppStorage(AppSettings.Key.speechRate, store: AppSettings.defaults) private var speechRate = 0.9
    @AppStorage(AppSettings.Key.useRecordedVoice, store: AppSettings.defaults) private var useRecordedVoice = true
    @AppStorage(AppSettings.Key.notificationsEnabled, store: AppSettings.defaults) private var notificationsOn = false
    @AppStorage(AppSettings.Key.quietStart, store: AppSettings.defaults) private var quietStart = 21
    @AppStorage(AppSettings.Key.quietEnd, store: AppSettings.defaults) private var quietEnd = 8
    @AppStorage(AppSettings.Key.pauseDuringQuiet, store: AppSettings.defaults) private var pauseDuringQuiet = true

    @AppStorage(AppSettings.Key.level, store: AppSettings.defaults) private var levelRaw = Level.novice.rawValue
    @AppStorage(AppSettings.Key.includeEarlierLevels, store: AppSettings.defaults) private var includeEarlier = false
    @AppStorage(AppSettings.Key.focus, store: AppSettings.defaults) private var focusRaw = Focus.everything.rawValue
    @AppStorage(AppSettings.Key.quizzesEnabled, store: AppSettings.defaults) private var quizzesEnabled = true

    @AppStorage(AppSettings.Key.widgetShowsPhrase, store: AppSettings.defaults) private var widgetShowsPhrase = false
    @AppStorage("liveModel") private var liveModel = LiveModel.haiku.rawValue
    @State private var apiKeyInput = ""
    @State private var hasAPIKey = APIKeyStore.hasKey

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
                    if RecordedVoice.isAvailable {
                        Toggle(isOn: $useRecordedVoice) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recorded voice")
                                Text("\(RecordedVoice.voiceName ?? "Natural voice") · anything not recorded uses the iPhone voice")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Picker(RecordedVoice.isEnabled ? "iPhone voice accent" : "Accent", selection: $voiceRaw) {
                        ForEach(SpanishVoice.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    VStack(alignment: .leading) {
                        Text(RecordedVoice.isEnabled ? "iPhone voice speed" : "Speed")
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
                    Picker("Quiet from", selection: $quietStart) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("Until", selection: $quietEnd) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Toggle("Pause words during quiet hours", isOn: $pauseDuringQuiet)
                } header: {
                    Text("Quiet hours")
                } footer: {
                    Text(pauseDuringQuiet
                         ? "No notifications, and the word doesn't change: the evening's word stays up and the next one comes when quiet hours end."
                         : "No notifications. Words keep changing overnight.")
                }

                Section {
                    Toggle("Notify me with each new word", isOn: $notificationsOn)
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationsDenied {
                        Text("Notifications are turned off for Palabra in the Settings app.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("Widget shows a phrase", isOn: $widgetShowsPhrase)
                } header: {
                    Text("Widget")
                } footer: {
                    Text("Phrase of the hour: the medium and large widgets show an everyday phrase with the word instead of its example sentence.")
                }

                Section {
                    if hasAPIKey {
                        LabeledContent("Anthropic API key", value: "Saved on this iPhone")
                        Picker("Model", selection: $liveModel) {
                            ForEach(LiveModel.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        Button("Remove key", role: .destructive) {
                            APIKeyStore.delete()
                            hasAPIKey = false
                        }
                    } else {
                        SecureField("Paste API key (sk-ant-…)", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Save key") {
                            hasAPIKey = APIKeyStore.save(apiKeyInput)
                            apiKeyInput = ""
                        }
                        .disabled(!apiKeyInput.hasPrefix("sk-"))
                    }
                } header: {
                    Text("AI phrases")
                } footer: {
                    Text("Turns on “Show me another” on every card, which writes a fresh everyday phrase with Claude and saves it to the Phrasebook. The key is kept in this iPhone's Keychain only. Each phrase costs a small fraction of a cent with Haiku. Phrases written here aren't reviewed, so they're marked NEW.")
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
                    NavigationLink("Credits & licenses") { CreditsView() }
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
            .onChange(of: widgetShowsPhrase) { WidgetCenter.shared.reloadAllTimelines() }
            .onChange(of: cadenceRaw) { scheduleChanged() }
            .onChange(of: quietStart) { old, _ in quietChanged(AppSettings.quietHourSet(start: old, end: quietEnd), was: pauseDuringQuiet) }
            .onChange(of: quietEnd) { old, _ in quietChanged(AppSettings.quietHourSet(start: quietStart, end: old), was: pauseDuringQuiet) }
            .onChange(of: pauseDuringQuiet) { old, _ in quietChanged(AppSettings.quietHourSet(start: quietStart, end: quietEnd), was: old) }
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

    /// Quiet hours or pausing changed: keep the word she's on, then update the widget and notifications.
    private func quietChanged(_ oldQuiet: Set<Int>, was pausing: Bool) {
        AppSettings.pauseChanged(from: pausing ? oldQuiet : [])
        Rotation.didChange()
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// Attribution for the open data the dictionary cards are built from (tools/import_dictionary.py).
struct CreditsView: View {
    var body: some View {
        List {
            Section {
                Text("Hand-written cards (patterns, tips and examples) were created for Palabra. Dictionary cards are generated from the open data below.")
                    .font(.subheadline)
            }
            Section("Meanings & word forms") {
                Link("Wiktionary, via Wiktextract / kaikki.org (Tatu Ylonen)", destination: URL(string: "https://kaikki.org")!)
                Text("Wiktionary content is available under CC BY-SA.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Example sentences") {
                Link("Tatoeba — tatoeba.org", destination: URL(string: "https://tatoeba.org")!)
                Text("Sentences and translations licensed under CC BY 2.0 FR.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Word frequency & levels") {
                Link("FrequencyWords (OpenSubtitles 2018) — Hermit Dave", destination: URL(string: "https://github.com/hermitdave/FrequencyWords")!)
                Text("Content licensed under CC BY-SA 4.0.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Pronunciation") {
                Text("Audio is spoken by the voices built into iOS. Phonetic spellings are generated from Spanish spelling rules.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Credits")
    }
}
