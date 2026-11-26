import AVFoundation

/// Short quiz sounds (App/Sounds): a chime when she's right, a soft tone when not, and a little
/// fanfare at the end. Off with the "Sounds" switch on the Quiz tab.
enum QuizSound: String {
    case correct, wrong, complete
}

@MainActor
enum QuizSounds {
    private static var players: [QuizSound: AVAudioPlayer] = [:]

    static func play(_ sound: QuizSound) {
        guard AppSettings.quizSoundsEnabled else { return }
        let session = AVAudioSession.sharedInstance()
        // Don't change the category while the voice is playing (it would cut it off).
        if session.category != .playback {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        if players[sound] == nil, let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.volume = 0.6
            player?.prepareToPlay()
            players[sound] = player
        }
        players[sound]?.currentTime = 0
        players[sound]?.play()
    }
}
