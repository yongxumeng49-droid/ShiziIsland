import AVFoundation
import Combine
import Foundation

/// 可以以后丢进 Resources/Voices/{child1,child2,teacher}/ 的录音。
/// 有文件就播文件，没有就用离线普通话。
enum VoiceClip {
    case preview
    case character(Int)
    case word(id: Int, index: Int)
    case sentence(Int)
    case praise(Int)

    func url(bundle: Bundle, voice: StudyVoice) -> URL? {
        let folder = voice.rawValue
        let subdirectory: String
        let name: String
        switch self {
        case .preview:
            subdirectory = "Voices/\(folder)"
            name = "preview"
        case .character(let id):
            subdirectory = "Voices/\(folder)/char"
            name = String(id)
        case .word(let id, let index):
            subdirectory = "Voices/\(folder)/word"
            name = "\(id)-\(index)"
        case .sentence(let id):
            subdirectory = "Voices/\(folder)/sentence"
            name = String(id)
        case .praise(let index):
            subdirectory = "Voices/\(folder)/praise"
            name = String(index)
        }
        return bundle.url(forResource: name, withExtension: "m4a", subdirectory: subdirectory)
    }
}

@MainActor
enum PlaybackLifetime {
    /// 画面还在就让已经开始的朗读继续；画面消失时只停掉这一次，不误停后来的新朗读。
    static func untilCancelled(stop token: Int, speech: SpeechService) async {
        do {
            while true {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
        } catch {
            speech.stopIfCurrent(token)
        }
    }
}

@MainActor
final class SpeechService: ObservableObject {
    static let praisePhrases = ["真棒！", "对啦！", "太厉害了！", "真聪明！", "做得好！", "完全正确！"]
    /// 认字自动连读时，两遍之间的停顿。
    static let repeatGap: TimeInterval = 0.7

    var voice: StudyVoice = .child1
    var bundle: Bundle

    private let synthesizer = AVSpeechSynthesizer()
    private let relay = SpeechRelay()
    private var player: AVAudioPlayer?
    private var didConfigure = false
    private var generation = 0
    private var playbackTask: Task<Void, Never>?
    private var resumeGate: ResumeGate?
    private var waitToken = 0
    private var praiseCursor = 0

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        synthesizer.delegate = relay
    }

    func playPresentation(_ entry: HanziEntry, repeats: Int, includePhrases: Bool) -> Int {
        begin(presentationSteps(entry, repeats: repeats, includePhrases: includePhrases))
    }

    func replayCharacter(_ entry: HanziEntry) {
        _ = begin([.say(entry.char, .character(entry.id), 0.40)])
    }

    func replayWords(_ entry: HanziEntry) {
        var steps: [Step] = []
        for (index, word) in entry.words.enumerated() {
            if index > 0 { steps.append(.pause(0.4)) }
            steps.append(.say(word, .word(id: entry.id, index: index), 0.42))
        }
        guard !steps.isEmpty else { return }
        _ = begin(steps)
    }

    func replaySentence(_ entry: HanziEntry) {
        let trimmed = entry.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = begin([.say(trimmed, .sentence(entry.id), 0.44)])
    }

    /// 答对才调用。按顺序轮换六句，不在答错时播。
    func speakPraise() {
        let phrases = Self.praisePhrases
        let index = praiseCursor % phrases.count
        praiseCursor += 1
        _ = begin([.say(phrases[index], .praise(index), 0.50)])
    }

    func playPreview(_ voice: StudyVoice) {
        guard let url = VoiceClip.preview.url(bundle: bundle, voice: voice) else { return }
        _ = begin([.file(url)])
    }

    func stop() {
        generation += 1
        playbackTask?.cancel()
        playbackTask = nil
        haltAudio()
    }

    func stopIfCurrent(_ token: Int) {
        guard token == generation else { return }
        stop()
    }

    private enum Step {
        case pause(TimeInterval)
        case say(String, VoiceClip, Float)
        case file(URL)
    }

    private func presentationSteps(_ entry: HanziEntry, repeats: Int, includePhrases: Bool) -> [Step] {
        var steps: [Step] = []
        let times = max(1, repeats)
        for index in 0..<times {
            steps.append(.say(entry.char, .character(entry.id), 0.40))
            if index + 1 < times {
                steps.append(.pause(Self.repeatGap))
            }
        }
        guard includePhrases else { return steps }
        if !entry.words.isEmpty {
            steps.append(.pause(Self.repeatGap))
            for (index, word) in entry.words.enumerated() {
                if index > 0 { steps.append(.pause(0.4)) }
                steps.append(.say(word, .word(id: entry.id, index: index), 0.42))
            }
        }
        let sentence = entry.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty {
            steps.append(.pause(0.6))
            steps.append(.say(sentence, .sentence(entry.id), 0.44))
        }
        return steps
    }

    @discardableResult
    private func begin(_ steps: [Step]) -> Int {
        generation += 1
        let token = generation
        playbackTask?.cancel()
        haltAudio()
        playbackTask = Task { [weak self] in
            await self?.run(steps, token: token)
        }
        return token
    }

    private func run(_ steps: [Step], token: Int) async {
        for step in steps {
            if token != generation || Task.isCancelled { return }
            switch step {
            case .pause(let seconds):
                let finished = await pause(seconds)
                if !finished || token != generation || Task.isCancelled { return }
            case .say(let text, let clip, let rate):
                await say(text, clip: clip, rate: rate)
            case .file(let url):
                await play(url: url)
            }
            if token != generation || Task.isCancelled { return }
        }
    }

    private func pause(_ seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    private func say(_ text: String, clip: VoiceClip, rate: Float) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let url = clip.url(bundle: bundle, voice: voice) {
            await play(url: url)
            return
        }
        await speakFallback(trimmed, rate: rate)
    }

    private func play(url: URL) async {
        configureIfNeeded()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        self.player = player
        player.delegate = relay
        let timeout = max(0.4, player.duration + 0.35)
        await wait(timeout: timeout) {
            player.prepareToPlay()
            return player.play()
        }
    }

    private func speakFallback(_ text: String, rate: Float) async {
        configureIfNeeded()
        let (avVoice, pitch) = resolvedVoice()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = avVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        let timeout = Double(text.count) * 0.55 + 1.8
        await wait(timeout: timeout) {
            self.synthesizer.speak(utterance)
            return true
        }
    }

    private func wait(timeout: TimeInterval, start: () -> Bool) async {
        waitToken += 1
        let token = waitToken
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let gate = ResumeGate(cont)
            resumeGate = gate
            relay.onFinish = { [weak self] in
                Task { @MainActor in
                    guard let self, token == self.waitToken else { return }
                    self.finishWait()
                }
            }
            let started = start()
            if !started {
                finishWait()
                return
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard token == self.waitToken else { return }
                self.finishWait()
            }
        }
    }

    private func finishWait() {
        let gate = resumeGate
        resumeGate = nil
        gate?.resume()
    }

    private func haltAudio() {
        waitToken += 1
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishWait()
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    /// 只用系统里已经装好的中文语音，不联网。
    private func resolvedVoice() -> (AVSpeechSynthesisVoice?, Float) {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        let zh = voices.first { $0.language == "zh-CN" || $0.language.hasPrefix("zh-Hans") }
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        switch voice {
        case .teacher:
            let female = voices.first { candidate in
                let blob = (candidate.name + " " + candidate.identifier).lowercased()
                return blob.contains("female") || blob.contains("tingting") || blob.contains("meijia")
                    || candidate.name.contains("女") || candidate.name.contains("婷")
            }
            return (female ?? zh, voice.fallbackPitch)
        case .child1, .child2:
            let child = voices.first { candidate in
                let blob = (candidate.name + " " + candidate.identifier).lowercased()
                return blob.contains("child") || blob.contains("kid") || blob.contains("young")
                    || candidate.name.contains("童")
            }
            if let child {
                let pitch: Float = voice == .child1 ? 1.10 : 1.04
                return (child, pitch)
            }
            return (zh, voice.fallbackPitch)
        }
    }
}

private final class SpeechRelay: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinish?()
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        let stored = continuation
        continuation = nil
        lock.unlock()
        stored?.resume()
    }
}
