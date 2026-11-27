import Foundation

/// What the learner has seen and how they've done in quizzes. Stored in the App Group so the
/// widget can note words whose turn passed while the app was closed (they go on the missed list).
enum LearningProgress {
    private static var defaults: UserDefaults { AppSettings.defaults }

    // MARK: Seen words

    /// word id → first time it was shown (seconds since 1970).
    static var seen: [String: Double] {
        get { defaults.dictionary(forKey: AppSettings.Key.seen) as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: AppSettings.Key.seen) }
    }

    /// Words whose turn came and went while she wasn't looking, oldest first (capped), so the Today
    /// tab can offer to catch up. A word counts as seen only when it's actually shown (`markSeen`).
    static var missed: [String] {
        get { defaults.stringArray(forKey: AppSettings.Key.missed) ?? [] }
        set { defaults.set(Array(newValue.suffix(maxMissed)), forKey: AppSettings.Key.missed) }
    }
    static let maxMissed = 40

    /// Moves the cursor up to now: every word that came up since the last call and isn't seen yet
    /// goes on the missed list. The current word is not marked seen here; the Today screen does that
    /// when it shows it. Called by the app (on launch / skip) and by the widget.
    static func catchUp(now: Date = .now) {
        let schedule = WordSchedule.current
        let current = schedule.position(at: now)
        let signature = AppSettings.deckSignature

        guard let cursor = defaults.dictionary(forKey: AppSettings.Key.seenCursor),
              cursor["sig"] as? String == signature,
              let last = cursor["pos"] as? Int else {
            defaults.set(["sig": signature, "pos": current], forKey: AppSettings.Key.seenCursor)
            return
        }
        if last < current {
            let seenNow = seen
            var list = missed
            // Never walk back more than the missed list can hold.
            for p in max(last, current - maxMissed)..<current {
                let id = schedule.word(atPosition: p).id
                if seenNow[id] == nil, !list.contains(id) { list.append(id) }
            }
            missed = list
        }
        defaults.set(["sig": signature, "pos": current], forKey: AppSettings.Key.seenCursor)
    }

    /// She has looked at this word (Today screen, catch-up, a card she opened).
    static func markSeen(_ word: Word, at date: Date = .now) {
        var map = seen
        if map[word.id] == nil {
            map[word.id] = date.timeIntervalSince1970
            seen = map
        }
        if missed.contains(word.id) {
            missed.removeAll { $0 == word.id }
        }
    }

    static func missedWords() -> [Word] {
        missed.compactMap { WordBank.word(id: $0) }
    }

    /// "Skip these": they stay unseen (they'll come round again), the list is cleared.
    static func dismissMissed() {
        missed = []
    }

    /// Seen words, most recent first.
    static func seenWords() -> [Word] {
        seen.sorted { $0.value > $1.value }.compactMap { WordBank.word(id: $0.key) }
    }

    static func resetSeen() {
        defaults.removeObject(forKey: AppSettings.Key.seen)
        defaults.removeObject(forKey: AppSettings.Key.seenCursor)
        defaults.removeObject(forKey: AppSettings.Key.missed)
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
