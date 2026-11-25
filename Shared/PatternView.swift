import SwiftUI

/// One line of a card's "How to use it" / "Key forms" section.
struct PatternRow: Hashable {
    let label: String?
    let value: String

    /// What to say aloud, or nil when the row isn't pure Spanish (hand-written patterns mix in
    /// English like "Quiero + noun"). Verb forms are spoken with their pronoun ("yo tengo"),
    /// noun forms already include the article ("las casas"), alternatives get a pause.
    var spokenText: String? {
        guard let label else { return nil }
        let value = self.value.replacingOccurrences(of: " / ", with: ", ")
        switch label {
        case "yo", "tú": return "\(label) \(value)"
        case "él / ella": return "él \(value)"
        case "past (yo)": return "yo \(value)"
        default: return value
        }
    }
}

extension Word {
    /// Dictionary cards store "label: value" lines (yo: tengo, plural: las casas). Hand-written
    /// patterns separate alternatives with "·"; each alternative becomes its own line.
    var patternRows: [PatternRow] {
        guard let pattern, !pattern.isEmpty else { return [] }
        if pattern.contains("\n") {
            return pattern.split(separator: "\n").map { line in
                let line = String(line)
                if let r = line.range(of: ": ") {
                    return PatternRow(label: String(line[..<r.lowerBound]), value: String(line[r.upperBound...]))
                }
                return PatternRow(label: nil, value: line)
            }
        }
        return pattern
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { PatternRow(label: nil, value: $0) }
    }
}

/// Renders pattern rows as a two-column table (labelled rows) or a tidy list (unlabelled rows).
struct PatternView: View {
    let rows: [PatternRow]
    var labelFont: Font = .subheadline
    var valueFont: Font = .body.weight(.semibold)
    var labelStyle: AnyShapeStyle = AnyShapeStyle(.secondary)
    var spacing: CGFloat = 6
    var maxRows: Int = .max
    /// When set, speakable rows get a small 🔊 button.
    var onSpeak: ((PatternRow) -> Void)? = nil

    var body: some View {
        let shown = Array(rows.prefix(maxRows))
        if shown.contains(where: { $0.label != nil }) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: spacing) {
                ForEach(shown, id: \.self) { row in
                    let speakable = onSpeak != nil && row.spokenText != nil
                    // Modifiers go on the cells, not the GridRow, so the columns stay aligned.
                    // Tapping either cell (label or form) plays it.
                    GridRow {
                        Text(row.label ?? "")
                            .font(labelFont)
                            .foregroundStyle(labelStyle)
                            .gridColumnAlignment(.trailing)
                            .contentShape(Rectangle())
                            .onTapGesture { if speakable { onSpeak?(row) } }
                            .accessibilityHidden(true)
                        HStack(spacing: 8) {
                            Text(row.value)
                                .font(valueFont)
                            if speakable {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.coral)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { if speakable { onSpeak?(row) } }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(row.label ?? ""): \(row.value)")
                        .accessibilityAddTraits(speakable ? .isButton : [])
                        .accessibilityHint(speakable ? "Plays the pronunciation" : "")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(shown, id: \.self) { row in
                    if shown.count > 1 {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").font(labelFont).foregroundStyle(labelStyle)
                            Text(row.value).font(valueFont)
                        }
                    } else {
                        Text(row.value).font(valueFont)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 30) {
        PatternView(rows: [
            PatternRow(label: "yo", value: "tengo"),
            PatternRow(label: "tú", value: "tienes"),
            PatternRow(label: "él / ella", value: "tiene"),
            PatternRow(label: "past (yo)", value: "tuve"),
        ])
        PatternView(rows: Word.sample.patternRows)
    }
    .padding()
}
