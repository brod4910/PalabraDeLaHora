import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word
    let nextChange: Date
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: .sample, nextChange: .now.addingTimeInterval(3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let schedule = WordSchedule.current
        let now = Date()
        completion(WordEntry(date: now, word: context.isPreview ? .sample : schedule.word(at: now),
                             nextChange: schedule.nextChange(after: now)))
    }

    /// Pre-computes the next 24 word changes. Each entry becomes active exactly at its date, so the
    /// widget flips on the hour without needing a reload. `.atEnd` asks for a new batch afterwards.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let schedule = WordSchedule.current
        let now = Date()
        var entries = [WordEntry(date: now, word: schedule.word(at: now), nextChange: schedule.nextChange(after: now))]
        for item in schedule.upcoming(after: now, count: 24) {
            entries.append(WordEntry(date: item.date, word: item.word,
                                     nextChange: schedule.nextChange(after: item.date)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct PalabraWidget: Widget {
    let kind = "PalabraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            PalabraWidgetView(entry: entry)
        }
        .configurationDisplayName("Palabra de la hora")
        .description("A new Spanish word on your schedule, with an example sentence and pronunciation.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct PalabraWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        content
            .widgetURL(entry.word.deepLink)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.word.spanish) · \(entry.word.english)")
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            CircularView(word: entry.word)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            RectangularView(word: entry.word)
                .containerBackground(for: .widget) { Color.clear }
        case .systemSmall:
            SmallView(word: entry.word)
                .padding(14)
                .containerBackground(for: .widget) { Theme.gradient }
        case .systemLarge, .systemExtraLarge:
            LargeView(entry: entry)
                .padding(18)
                .containerBackground(for: .widget) { Theme.gradient }
        default:
            MediumView(word: entry.word)
                .padding(16)
                .containerBackground(for: .widget) { Theme.gradient }
        }
    }
}

private struct Header: View {
    var body: some View {
        Text("PALABRA DE LA HORA")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.75))
    }
}

private struct SpeakButton: View {
    let word: Word
    var includeSentence = true
    var label: String? = nil

    var body: some View {
        Button(intent: SpeakWordIntent(wordID: word.id, includeSentence: includeSentence)) {
            if let label {
                Label(label, systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.22), in: Capsule())
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.22), in: Circle())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct SmallView: View {
    let word: Word
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Header()
                Spacer(minLength: 0)
                SpeakButton(word: word, includeSentence: false)
            }
            Spacer(minLength: 0)
            Text(word.spanish)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(word.phonetic)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(word.english)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let word: Word
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Header()
                Spacer()
                SpeakButton(word: word)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.spanish)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(word.phonetic)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .opacity(0.85)
                    .lineLimit(1)
            }
            Text("\(word.english) · \(word.partOfSpeech)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .opacity(0.95)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(word.example)
                .font(.system(size: 14, weight: .medium, design: .serif).italic())
                .lineLimit(2).minimumScaleFactor(0.8)
            Text(word.exampleTranslation)
                .font(.system(size: 11, design: .rounded))
                .opacity(0.8)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct LargeView: View {
    let entry: WordEntry
    var word: Word { entry.word }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header()
            VStack(alignment: .leading, spacing: 2) {
                Text(word.spanish)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(word.phonetic)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .opacity(0.85)
                Text("\(word.english) · \(word.partOfSpeech)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }

            Divider().overlay(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 3) {
                Text(word.example)
                    .font(.system(size: 18, weight: .medium, design: .serif).italic())
                Text(word.exampleTranslation)
                    .font(.system(size: 13, design: .rounded))
                    .opacity(0.85)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("HOW TO USE IT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8).opacity(0.75)
                Text(word.pattern)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let tip = word.tip {
                Text("💡 \(tip)")
                    .font(.system(size: 12, design: .rounded))
                    .opacity(0.9)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                SpeakButton(word: word, includeSentence: false, label: "Word")
                SpeakButton(word: word, includeSentence: true, label: "Sentence")
                Spacer()
                Text("Next ") + Text(entry.nextChange, style: .time)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RectangularView: View {
    let word: Word
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(word.spanish)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(word.phonetic)
                .font(.caption2.monospaced())
                .lineLimit(1)
            Text(word.english)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let word: Word
    var body: some View {
        VStack(spacing: 0) {
            Text("ES")
                .font(.system(size: 9, weight: .heavy))
                .opacity(0.7)
            Text(word.spanish)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(4)
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    PalabraWidget()
} timeline: {
    WordEntry(date: .now, word: .sample, nextChange: .now.addingTimeInterval(3600))
}

#Preview(as: .systemLarge) {
    PalabraWidget()
} timeline: {
    WordEntry(date: .now, word: .sample, nextChange: .now.addingTimeInterval(3600))
}
