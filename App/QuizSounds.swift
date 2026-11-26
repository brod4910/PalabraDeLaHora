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
        // Same session as the voice, so a chime never cuts the voice off.
        AudioSessionManager.shared.activate(AudioSessionManager.playback)
        if players[sound] == nil, let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.volume = 0.6
            player?.prepareToPlay()
            players[sound] = player
        }
        players[sound]?.currentTime = 0
        players[sound]?.play()
        if !Speaker.shared.isSpeaking {             // the voice switches it off itself when it's done
            AudioSessionManager.shared.deactivateSoon(after: 2)
        }
    }
}
