import Foundation

/// What the learner has seen and how they've done in quizzes. Stored in the App Group so the
/// widget can record words that appear while the app is closed.
enum LearningProgress {
    private static var defaults: UserDefaults { AppSettings.defaults }

    // MARK: Seen words

    /// word id → first time it was shown (seconds since 1970).
    static var seen: [String: Double] {
        get { defaults.dictionary(forKey: AppSettings.Key.seen) as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: AppSettings.Key.seen) }
    }

    /// Records every word that has come up since the last call (clock ticks and skips).
    /// Called by the app when it becomes active / skips, and by the widget on each timeline build.
    static func catchUp(now: Date = .now) {
        let schedule = WordSchedule.current
        let current = schedule.position(at: now)
        let signature = AppSettings.deckSignature

        var start = current
        if let cursor = defaults.dictionary(forKey: AppSettings.Key.seenCursor),
           cursor["sig"] as? String == signature,
           let last = cursor["pos"] as? Int, last < current {
            // Never walk back more than one full pass through the deck.
            start = max(last + 1, current - schedule.words.count + 1)
        }

        var map = seen
        let stamp = now.timeIntervalSince1970
        for p in start...current {
            let id = schedule.word(atPosition: p).id
            if map[id] == nil { map[id] = stamp }
        }
        seen = map
        defaults.set(["sig": signature, "pos": current], forKey: AppSettings.Key.seenCursor)
    }

    /// Seen words, most recent first.
    static func seenWords() -> [Word] {
        seen.sorted { $0.value > $1.value }.compactMap { WordBank.word(id: $0.key) }
    }

    static func resetSeen() {
        defaults.removeObject(forKey: AppSettings.Key.seen)
        defaults.removeObject(forKey: AppSettings.Key.seenCursor)
    }

    // MARK: Quiz stats

    struct Record: Sendable {
        var right = 0
        var wrong = 0
        var lastAsked: Date?

        var attempts: Int { right + wrong }
        var accuracy: Double { attempts == 0 ? 0 : Double(right) / Double(attempts) }
        /// Answered correctly at least 3 times with ≥ 75% accuracy.
        var isMastered: Bool { right >= 3 && accuracy >= 0.75 }
        /// Lower = ask sooner. Unasked words sit in the middle; missed words come first.
        var priority: Double { attempts == 0 ? 0.5 : accuracy + min(Double(attempts), 6) * 0.05 }
    }

    private static var rawStats: [String: [Double]] {
        get { defaults.dictionary(forKey: AppSettings.Key.quizStats) as? [String: [Double]] ?? [:] }
        set { defaults.set(newValue, forKey: AppSettings.Key.quizStats) }
    }

    static func record(for id: String) -> Record {
        guard let a = rawStats[id], a.count == 3 else { return Record() }
        return Record(right: Int(a[0]), wrong: Int(a[1]), lastAsked: a[2] > 0 ? Date(timeIntervalSince1970: a[2]) : nil)
    }

    static func recordAnswer(id: String, correct: Bool, at date: Date = .now) {
        var r = record(for: id)
        if correct { r.right += 1 } else { r.wrong += 1 }
        var all = rawStats
        all[id] = [Double(r.right), Double(r.wrong), date.timeIntervalSince1970]
        rawStats = all
    }

    static func resetQuizStats() {
        defaults.removeObject(forKey: AppSettings.Key.quizStats)
    }
}
