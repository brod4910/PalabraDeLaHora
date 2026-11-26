import Foundation

/// How often a new word appears.
enum Cadence: Int, CaseIterable, Identifiable, Sendable {
    case hourly = 1
    case every2Hours = 2
    case every3Hours = 3
    case every4Hours = 4
    case every6Hours = 6
    case daily = 24

    var id: Int { rawValue }
    var hours: Int { rawValue }
    var interval: TimeInterval { TimeInterval(rawValue * 3600) }

    var label: String {
        switch self {
        case .hourly: "Every hour"
        case .daily: "Once a day"
        default: "Every \(rawValue) hours"
        }
    }
}

/// Spanish voice variant used by the speech synthesizer.
enum SpanishVoice: String, CaseIterable, Identifiable, Sendable {
    case mexico = "es-MX"
    case spain = "es-ES"
    case unitedStates = "es-US"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .mexico: "Mexico 🇲🇽"
        case .spain: "Spain 🇪🇸"
        case .unitedStates: "United States 🇺🇸"
        }
    }
}

/// Settings shared between the app and the widget through the App Group.
///
/// The group ID comes from the `PalabraAppGroup` Info.plist key, which is filled in from the
/// `PALABRA_BUNDLE_ID` build setting — change that one setting and everything follows.
enum AppSettings {
    static let groupID: String =
        Bundle.main.object(forInfoDictionaryKey: "PalabraAppGroup") as? String ?? "group.com.example.palabra"

    static let defaults: UserDefaults = UserDefaults(suiteName: groupID) ?? .standard

    enum Key {
        static let cadence = "cadence"
        static let voice = "voice"
        static let speechRate = "speechRate"
        static let notificationsEnabled = "notificationsEnabled"
        static let quietStart = "quietStart"
        static let quietEnd = "quietEnd"
        static let seed = "seed"
        static let startDate = "startDate"
        static let favorites = "favorites"
        static let level = "level"
        static let includeEarlierLevels = "includeEarlierLevels"
        static let focus = "focus"
        static let skipOffset = "skipOffset"
        static let seen = "seen"
        static let seenCursor = "seenCursor"
        static let quizStats = "quizStats"
        static let quizzesEnabled = "quizzesEnabled"
        static let widgetShowsPhrase = "widgetShowsPhrase"
        static let useRecordedVoice = "useRecordedVoice"
        static let quizSounds = "quizSounds"
    }

    static var level: Level {
        get { Level(rawValue: defaults.string(forKey: Key.level) ?? "") ?? .novice }
        set { defaults.set(newValue.rawValue, forKey: Key.level) }
    }

    static var includeEarlierLevels: Bool {
        get { defaults.bool(forKey: Key.includeEarlierLevels) }
        set { defaults.set(newValue, forKey: Key.includeEarlierLevels) }
    }

    static var focus: Focus {
        get { Focus(rawValue: defaults.string(forKey: Key.focus) ?? "") ?? .everything }
        set { defaults.set(newValue.rawValue, forKey: Key.focus) }
    }

    /// How many words the learner has skipped ahead with "Next word". Added to the clock-based
    /// slot, so the widget, notifications and "Coming up" all move forward together.
    static var skipOffset: Int {
        get { defaults.integer(forKey: Key.skipOffset) }
        set { defaults.set(newValue, forKey: Key.skipOffset) }
    }

    /// Phrase of the hour on the medium/large widget.
    static var widgetShowsPhrase: Bool {
        get { defaults.bool(forKey: Key.widgetShowsPhrase) }
        set { defaults.set(newValue, forKey: Key.widgetShowsPhrase) }
    }

    static var quizzesEnabled: Bool {
        get { defaults.object(forKey: Key.quizzesEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.quizzesEnabled) }
    }

    /// Identifies the current rotation; when it changes, the "seen" catch-up restarts from now.
    static var deckSignature: String {
        "\(level.rawValue)|\(includeEarlierLevels)|\(focus.rawValue)|\(cadence.rawValue)|\(seed)"
    }

    static var cadence: Cadence {
        get { Cadence(rawValue: defaults.integer(forKey: Key.cadence)) ?? .hourly }
        set { defaults.set(newValue.rawValue, forKey: Key.cadence) }
    }

    static var voice: SpanishVoice {
        get { SpanishVoice(rawValue: defaults.string(forKey: Key.voice) ?? "") ?? .mexico }
        set { defaults.set(newValue.rawValue, forKey: Key.voice) }
    }

    /// Multiplier on the system default speech rate (0.5 … 1.2).
    /// Play the bundled recordings (when there are any) instead of the on-device voice. On by default.
    static var useRecordedVoice: Bool {
        get { defaults.object(forKey: Key.useRecordedVoice) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.useRecordedVoice) }
    }

    /// Chime / tone sounds in quizzes. On by default.
    static var quizSoundsEnabled: Bool {
        get { defaults.object(forKey: Key.quizSounds) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.quizSounds) }
    }

    static var speechRate: Double {
        get { let v = defaults.double(forKey: Key.speechRate); return v == 0 ? 0.9 : v }
        set { defaults.set(newValue, forKey: Key.speechRate) }
    }

    static var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    /// Hour (0–23) when quiet time starts. No notifications from quietStart until quietEnd.
    static var quietStart: Int {
        get { defaults.object(forKey: Key.quietStart) as? Int ?? 21 }
        set { defaults.set(newValue, forKey: Key.quietStart) }
    }

    static var quietEnd: Int {
        get { defaults.object(forKey: Key.quietEnd) as? Int ?? 8 }
        set { defaults.set(newValue, forKey: Key.quietEnd) }
    }

    static func isQuiet(hour: Int) -> Bool {
        let s = quietStart, e = quietEnd
        if s == e { return false }
        return s > e ? (hour >= s || hour < e) : (hour >= s && hour < e)
    }

    /// Seed for the word order. Created on first launch; "Reshuffle" in Settings replaces it.
    static var seed: UInt64 {
        if let s = defaults.string(forKey: Key.seed), let v = UInt64(s) { return v }
        let v = UInt64.random(in: 1...UInt64.max)
        defaults.set(String(v), forKey: Key.seed)
        return v
    }

    static func reshuffle() {
        defaults.set(String(UInt64.random(in: 1...UInt64.max)), forKey: Key.seed)
        defaults.set(Date(), forKey: Key.startDate)
        defaults.set(0, forKey: Key.skipOffset)
    }

    /// When learning started — the Review tab lists every word shown since then.
    static var startDate: Date {
        if let d = defaults.object(forKey: Key.startDate) as? Date { return d }
        let now = Date()
        defaults.set(now, forKey: Key.startDate)
        return now
    }

    static var favorites: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.favorites) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.favorites) }
    }
}
