import SwiftUI

struct LessonPlayerView: View {
    var lessonID: String
    @Binding var path: [AppRoute]
    @EnvironmentObject private var corpus: CorpusStore
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechService()

    @State private var phase: Phase = .intro
    @State private var introIndex = 0
    @State private var questions: [PracticeQuestion] = []
    @State private var questionIndex = 0
    @State private var correctCount = 0
    @State private var prepared = false
    @State private var recorded = false
    @State private var showLeave = false
    @State private var earnedStars = 1
    @State private var celebrate = false

    private enum Phase {
        case intro
        case cover
        case practice
        case done
        case unavailable
    }

    private var lesson: LessonCurriculum? {
        corpus.lesson(id: lessonID)
    }

    var body: some View {
        AdaptiveScreen(imageName: StageArt.imageName(lesson?.stage ?? 1), dim: 0.3) {
        ZStack {
            VStack(spacing: 0) {
                topBar
                content
            }
        }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: prepare)
        .onDisappear { speech.stop() }
        .alert("先离开吗", isPresented: $showLeave) {
            Button("留下", role: .cancel) {}
            Button("离开", role: .destructive) { dismiss() }
        } message: {
            Text("这次的星星还没拿到")
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: requestClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Theme.ui(18, .bold))
                    .foregroundStyle(Theme.ink)
                FractionBar(fraction: progressFraction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(progressLabel)
                .font(Theme.ui(15, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let lesson {
            switch phase {
            case .intro:
                intro(lesson)
            case .cover:
                cover(lesson)
            case .practice:
                if questions.indices.contains(questionIndex) {
                    QuestionPage(
                        question: questions[questionIndex],
                        index: questionIndex + 1,
                        total: questions.count,
                        speech: speech,
                        onAnswer: handleAnswer,
                        onAdvance: advance
                    )
                    .id(questions[questionIndex].id)
                }
            case .done:
                done(lesson)
            case .unavailable:
                unavailable
            }
        } else {
            unavailable
        }
    }

    private func intro(_ lesson: LessonCurriculum) -> some View {
        let entry = lesson.characters[safe: introIndex]
        return ScrollView {
            VStack(spacing: 18) {
            Text("认识新字")
                .font(Theme.ui(20, .semibold))
                .foregroundStyle(Theme.inkSoft)
            if let entry {
                Text(entry.char)
                    .font(Theme.glyph(200))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(entry.pinyin)
                    .font(Theme.ui(44, .bold))
                    .foregroundStyle(Theme.seaDeep)
                Text("\(entry.strokes) 画")
                    .font(Theme.ui(18, .medium))
                    .foregroundStyle(Theme.inkSoft)
                if !entry.words.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(entry.words, id: \.self) { word in
                            Text(word)
                                .font(Theme.ui(22, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.sea.opacity(0.12), in: Capsule())
                        }
                    }
                    Button("听词语") { speech.speak(entry.words.joined(separator: "，")) }
                        .font(Theme.ui(16, .bold))
                        .foregroundStyle(Theme.seaDeep)
                }
                if !entry.sentence.isEmpty {
                    Text(entry.sentence)
                        .font(Theme.ui(22, .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Button("听句子") { speech.speak(entry.sentence) }
                        .font(Theme.ui(16, .bold))
                        .foregroundStyle(Theme.seaDeep)
                }
                Button {
                    speech.speakCharacter(entry.char)
                } label: {
                    Label("听一听", systemImage: "speaker.wave.2.fill")
                        .font(Theme.ui(22, .bold))
                        .foregroundStyle(Theme.card)
                        .padding(.horizontal, 26)
                        .frame(minHeight: 64)
                        .background(Theme.sea, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("\(introIndex + 1) / \(max(lesson.characters.count, 1))")
                .font(Theme.ui(16, .semibold))
                .foregroundStyle(Theme.inkSoft)
            PrimaryButton(title: introIndex + 1 >= lesson.characters.count ? "开始练习" : "下一个") {
                if introIndex + 1 >= lesson.characters.count {
                    phase = .practice
                } else {
                    introIndex += 1
                    if let next = lesson.characters[safe: introIndex] {
                        speech.speakCharacter(next.char)
                    }
                }
            }
        }
            .padding(24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onAppear {
            if introIndex == 0, let first = lesson.characters.first {
                speech.speakCharacter(first.char)
            }
        }
    }

    private func cover(_ lesson: LessonCurriculum) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "flag.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Theme.coral)
            Text("小岛测验")
                .font(Theme.ui(40, .bold))
                .foregroundStyle(Theme.ink)
            Text("这一岛有 \(lesson.characters.count) 个字，来认一认")
                .font(Theme.ui(20, .medium))
                .foregroundStyle(Theme.inkSoft)
            PrimaryButton(title: "开始测验", fill: Theme.coral) {
                phase = .practice
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func done(_ lesson: LessonCurriculum) -> some View {
        VStack(spacing: 18) {
            Text(lesson.isCheckpoint ? "小岛测验通过" : "这课走完啦")
                .font(Theme.ui(36, .bold))
                .foregroundStyle(Theme.ink)
            StarRow(filled: earnedStars, total: 3, size: 42)
                .scaleEffect(celebrate ? 1 : 0.4)
                .onAppear {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        celebrate = true
                    }
                }
            Text("答对 \(correctCount) / \(questions.count)")
                .font(Theme.ui(20, .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(earnedStars == 3 ? "记得很牢" : "再认一次会更熟")
                .font(Theme.ui(18, .medium))
                .foregroundStyle(Theme.inkSoft)
            if let next = nextLessonID(after: lesson) {
                PrimaryButton(title: "下一课") {
                    if !path.isEmpty {
                        path[path.count - 1] = .lesson(next)
                    }
                }
            }
            PrimaryButton(title: "回到小路", fill: Theme.coral) {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            Text("这课的题目没有准备好")
                .font(Theme.ui(24, .bold))
                .foregroundStyle(Theme.ink)
            PrimaryButton(title: "回到小路") { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        guard let lesson else { return "识字" }
        if lesson.isCheckpoint { return "小岛测验" }
        return "第 \(lesson.number) 课"
    }

    private var progressFraction: CGFloat {
        switch phase {
        case .intro:
            let count = max(lesson?.characters.count ?? 1, 1)
            return CGFloat(introIndex + 1) / CGFloat(count)
        case .cover:
            return 0.08
        case .practice:
            let count = max(questions.count, 1)
            return CGFloat(questionIndex) / CGFloat(count)
        case .done:
            return 1
        case .unavailable:
            return 0
        }
    }

    private var progressLabel: String {
        switch phase {
        case .practice:
            return "\(min(questionIndex + 1, max(questions.count, 1)))/\(max(questions.count, 1))"
        case .done:
            return "完成"
        default:
            return ""
        }
    }

    private func prepare() {
        guard !prepared, let lesson else { return }
        prepared = true
        progress.beginSession()
        questions = QuestionFactory.makeSession(lesson: lesson, corpus: corpus, progress: progress)
        if questions.isEmpty {
            phase = .unavailable
        } else if lesson.isCheckpoint {
            phase = .cover
        } else if lesson.characters.isEmpty {
            phase = .practice
        } else {
            phase = .intro
        }
    }

    private func handleAnswer(_ correct: Bool) {
        if correct { correctCount += 1 }
        guard questions.indices.contains(questionIndex) else { return }
        let entries = questions[questionIndex].gradedEntries
        for entry in entries {
            progress.grade(id: entry.id, correct: correct)
        }
    }

    private func advance() {
        if questionIndex + 1 >= questions.count {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                questionIndex += 1
            }
        }
    }

    private func finish() {
        guard !recorded, let lesson, !questions.isEmpty else {
            phase = .unavailable
            return
        }
        recorded = true
        let ratio = Double(correctCount) / Double(questions.count)
        earnedStars = ratio >= 0.9 ? 3 : (ratio >= 0.7 ? 2 : 1)
        progress.complete(lessonID: lesson.id, stars: earnedStars)
        phase = .done
    }

    private func nextLessonID(after lesson: LessonCurriculum) -> String? {
        guard let island = corpus.island(stage: lesson.stage, index: lesson.islandIndex),
              let index = island.lessons.firstIndex(where: { $0.id == lesson.id }),
              index + 1 < island.lessons.count else {
            return nil
        }
        let next = island.lessons[index + 1]
        return progress.isLessonUnlocked(next, in: corpus) ? next.id : nil
    }

    private func requestClose() {
        if phase == .done || phase == .unavailable {
            dismiss()
        } else {
            showLeave = true
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
