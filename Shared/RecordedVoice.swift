import Foundation

/// Pre-recorded clips (tools/generate_audio.py --export → App/Audio/), looked up by text.
///
/// `Speaker` plays a clip when every line it's asked to say has one, and falls back to the
/// on-device voice otherwise (words that weren't recorded, live AI phrases, English prompts).
enum RecordedVoice {
    private struct Index: Decodable {
        let voice: String
        let clips: [String: String]
    }

    /// The folder lives in the app bundle. The widget's play button runs in the app process
    /// (AudioPlaybackIntent), but an extension can also read its containing app's bundle.
    private static let folder: URL? = {
        let appBundle = Bundle.main.bundleURL.pathExtension == "appex"
            ? Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
            : Bundle.main
        return appBundle?.url(forResource: "Audio", withExtension: nil)
    }()

    private static let index: Index? = {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent("index.json")) else { return nil }
        return try? JSONDecoder().decode(Index.self, from: data)
    }()

    /// Whether any recordings were bundled with this build.
    static var isAvailable: Bool { !(index?.clips.isEmpty ?? true) }

    /// The voice the clips were recorded with (e.g. "Paloma").
    static var voiceName: String? { index?.voice }

    /// Recordings are used when bundled and the learner hasn't switched them off in Settings.
    static var isEnabled: Bool { isAvailable && AppSettings.useRecordedVoice }

    /// Same rule as lookup_key() in tools/generate_audio.py: lowercase, letters and digits only,
    /// single spaces. "¿Cómo estás?" and "cómo estás" find the same clip.
    static func key(_ text: String) -> String {
        let lowered = text.precomposedStringWithCanonicalMapping.lowercased()
        let cleaned = String(lowered.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The clip for `text`. Slow asks for the syllable-by-syllable recording, which exists for
    /// words (and phrase cards); sentences have none, so Speaker plays them slower instead.
    static func url(for text: String, slow: Bool = false) -> URL? {
        guard let folder, let clips = index?.clips else { return nil }
        let k = key(text)
        guard let file = clips[slow ? "slow|" + k : k] else { return nil }
        return folder.appendingPathComponent(file)
    }
}
