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

    @State private var confirmReshuffle = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("New word", selection: $cadenceRaw) {
                        ForEach(Cadence.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                } header: {
                    Text("Cadence")
                } footer: {
                    Text("The widget, notifications and the Hoy tab all switch to the next word on this schedule.")
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
                    Button("Reshuffle word order", role: .destructive) { confirmReshuffle = true }
                } footer: {
                    Text("Starts a new random order and clears the “Seen” list.")
                }

                Section("About") {
                    LabeledContent("Words", value: "\(WordBank.all.count)")
                    LabeledContent("Learning since", value: AppSettings.startDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reshuffle the word order?", isPresented: $confirmReshuffle, titleVisibility: .visible) {
                Button("Reshuffle", role: .destructive) {
                    AppSettings.reshuffle()
                    scheduleChanged()
                }
            }
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
        WidgetCenter.shared.reloadAllTimelines()
        Task { await NotificationScheduler.reschedule() }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
