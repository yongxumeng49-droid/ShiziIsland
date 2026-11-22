import AVFoundation
import Combine

@MainActor
final class SpeechService: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var didConfigure = false
    private var voice: AVSpeechSynthesisVoice?
    /// 没有童声时把系统声提高，听起来更像孩子。
    private var pitch: Float = 1.32

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureIfNeeded()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = 0.40
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = 0.04
        synthesizer.speak(utterance)
    }

    func speakCharacter(_ text: String) {
        speak(text)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// 用播放会话，静音开关打开时也能听见字音。
    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
        resolveVoice()
    }

    /// 优先系统里的儿童中文音色。没有就用 zh-CN，并抬高音调。
    private func resolveVoice() {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        let child = voices.first { voice in
            let blob = (voice.name + " " + voice.identifier).lowercased()
            return blob.contains("child") || blob.contains("kid") || blob.contains("young") || voice.name.contains("童")
        }
        if let child {
            voice = child
            pitch = 1.08
        } else {
            voice = voices.first { $0.language == "zh-CN" || $0.language.hasPrefix("zh-Hans") }
                ?? AVSpeechSynthesisVoice(language: "zh-CN")
            pitch = 1.32
        }
    }
}
