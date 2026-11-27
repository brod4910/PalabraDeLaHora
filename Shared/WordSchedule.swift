import Foundation

/// Deterministic word rotation.
///
/// Time is cut into slots of `cadence.interval`, aligned to the local clock (hourly slots start on
/// the hour, daily slots at local midnight). Each pass through the word list ("cycle") uses its own
/// seeded shuffle, so every word appears once per cycle and the order changes between cycles.
///
/// Because the word for any moment can be computed, the widget can pre-build a full day of timeline
/// entries and flip exactly on the hour without spending its refresh budget, and the app and
/// notifications always agree with the widget.
///
/// "Next word" skips ahead by adding `offset` to the clock slot: the clock keeps ticking from the new
/// position, so skipping never causes repeats and everything downstream stays in sync.
///
/// Quiet hours pause the rotation: slots that start in a quiet hour don't count, so the evening's
/// word stays up overnight and the next one appears when quiet time ends.
struct WordSchedule: Sendable {
    let words: [Word]
    let cadence: Cadence
    let seed: UInt64
    let startDate: Date
    var offset: Int = 0
    /// Local hours (0–23) when the rotation is paused. Empty = never (always empty for daily words).
    var quietHours: Set<Int> = []

    static var current: WordSchedule {
        AppSettings.migratePauseIfNeeded()
        return WordSchedule(words: WordBank.currentDeck, cadence: AppSettings.cadence,
                            seed: AppSettings.seed, startDate: AppSettings.startDate,
                            offset: AppSettings.skipOffset, quietHours: AppSettings.pausedHours)
    }

    /// Position in the word sequence at `date` (clock slot + skips).
    func position(at date: Date) -> Int { slot(for: date) + offset }

    // MARK: Slots

    private var slotsPerDay: Int { max(1, 24 / cadence.hours) }

    /// Which slots of a day count (their start hour isn't quiet). All of them when nothing is quiet.
    private var activeSlotsInDay: [Int] {
        let all = Array(0..<slotsPerDay)
        guard !quietHours.isEmpty, cadence != .daily else { return all }
        let active = all.filter { !quietHours.contains(($0 * cadence.hours) % 24) }
        return active.isEmpty ? all : active
    }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int { a >= 0 ? a / b : -((-a + b - 1) / b) }

    /// Clock slot, counting only active (non-quiet) slots. During quiet hours it's still the last
    /// active slot, so the word doesn't change.
    func slot(for date: Date) -> Int {
        let raw = rawSlot(for: date)
        let active = activeSlotsInDay
        guard active.count < slotsPerDay else { return raw }
        let day = Self.floorDiv(raw, slotsPerDay)
        let inDay = raw - day * slotsPerDay
        return day * active.count + active.filter { $0 <= inDay }.count - 1
    }

    /// When an (active-counting) slot starts.
    func startOfSlot(_ slot: Int) -> Date {
        let active = activeSlotsInDay
        guard active.count < slotsPerDay else { return startOfRawSlot(slot) }
        let day = Self.floorDiv(slot, active.count)
        return startOfRawSlot(day * slotsPerDay + active[slot - day * active.count])
    }

    private func rawSlot(for date: Date) -> Int {
        let local = date.timeIntervalSince1970 + TimeInterval(TimeZone.current.secondsFromGMT(for: date))
        return Int(floor(local / cadence.interval))
    }

    private func startOfRawSlot(_ slot: Int) -> Date {
        // Wall-clock seconds → absolute time. Solve t + offset(t) = local with two fixed-point
        // steps, which is exact except inside a DST gap (where it lands an hour off, harmlessly).
        let local = TimeInterval(slot) * cadence.interval
        let tz = TimeZone.current
        let t0 = local - TimeInterval(tz.secondsFromGMT(for: Date(timeIntervalSince1970: local)))
        let t1 = local - TimeInterval(tz.secondsFromGMT(for: Date(timeIntervalSince1970: t0)))
        return Date(timeIntervalSince1970: t1)
    }

    func nextChange(after date: Date) -> Date {
        var next = startOfSlot(slot(for: date) + 1)
        // Guard against DST edge cases producing a non-advancing date.
        if next <= date { next = date.addingTimeInterval(cadence.interval) }
        return next
    }

    // MARK: Words

    func word(forSlot slot: Int) -> Word {
        let n = words.count
        guard n > 1 else { return words.first ?? .sample }
        let cycle = slot >= 0 ? slot / n : (slot - n + 1) / n
        let position = ((slot % n) + n) % n
        return order(forCycle: cycle)[position]
    }

    /// Word at a sequence position (see `position(at:)`).
    func word(atPosition p: Int) -> Word { word(forSlot: p) }

    func word(at date: Date) -> Word { word(atPosition: position(at: date)) }

    /// Upcoming changes after `date` (not including the current word). Includes skips.
    func upcoming(after date: Date, count: Int) -> [UpcomingWord] {
        var result: [UpcomingWord] = []
        var s = slot(for: date)
        for _ in 0..<count {
            s += 1
            result.append(UpcomingWord(date: startOfSlot(s), word: word(atPosition: s + offset)))
        }
        return result
    }

    // MARK: Shuffle

    private func order(forCycle cycle: Int) -> [Word] {
        var rng = SplitMix64(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 0x9E37_79B9_7F4A_7C15)
        var a = words
        // Hand-rolled Fisher–Yates: Array.shuffle(using:) isn't guaranteed stable across Swift releases,
        // and the app and widget must always agree.
        if a.count > 1 {
            for i in stride(from: a.count - 1, to: 0, by: -1) {
                let j = Int(rng.next() % UInt64(i + 1))
                a.swapAt(i, j)
            }
        }
        return a
    }
}

struct UpcomingWord: Hashable, Sendable {
    let date: Date
    let word: Word
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
