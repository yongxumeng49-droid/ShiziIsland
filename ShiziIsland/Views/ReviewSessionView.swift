import SwiftUI

private enum ReviewStep: Identifiable {
    case phrase(HanziEntry)
    case question(PracticeQuestion)

    var id: String {
        switch self {
        case .phrase(let entry):
            return "phrase-\(entry.id)"
        case .question(let question):
            return "question-\(question.id.uuidString)"
        }
    }
}

struct ReviewSessionView: View {
    @EnvironmentObject private var corpus: CorpusStore
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechService()

    @State private var steps: [ReviewStep] = []
    @State private var index = 0
    @State private var correctCount = 0
    @State private var prepared = false
    @State private var finished = false
    @State private var recorded = false

    var body: some View {
        AdaptiveScreen(imageName: "HomeBackground", dim: 0.28, usesHomePair: true) {
        ZStack {
            VStack(spacing: 0) {
                topBar
                content
                    .padding(18)
            }
        }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: prepare)
        .onDisappear { speech.stop() }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 6) {
                Text("今日复习")
                    .font(Theme.ui(18, .bold))
                    .foregroundStyle(Theme.ink)
                FractionBar(fraction: progressFraction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.card.opacity(0.9))
    }

    @ViewBuilder
    private var content: some View {
        if finished {
            done
        } else if steps.isEmpty {
            rest
        } else if steps.indices.contains(index) {
            switch steps[index] {
            case .phrase(let entry):
                phrase(entry)
            case .question(let question):
                QuestionPage(
                    question: question,
                    index: questionNumber,
                    total: questionTotal,
                    speech: speech,
                    onAnswer: { correct in
                        if correct { correctCount += 1 }
                        for entry in question.gradedEntries {
                            progress.grade(id: entry.id, correct: correct)
                        }
                    },
                    onAdvance: advance
                )
                .id(question.id)
                .padding(12)
                .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private func phrase(_ entry: HanziEntry) -> some View {
        VStack(spacing: 16) {
            Text("再认一个字")
                .font(Theme.ui(18, .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(entry.char)
                .font(Theme.glyph(140))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(entry.pinyin)
                .font(Theme.ui(36, .bold))
                .foregroundStyle(Theme.seaDeep)
            MemoryDots(box: progress.memoryBox(for: entry.id))
            if !entry.words.isEmpty {
                HStack(spacing: 10) {
                    ForEach(entry.words, id: \.self) { word in
                        Text(word)
                            .font(Theme.ui(22, .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.sea.opacity(0.12), in: Capsule())
                    }
                }
            }
            if !entry.sentence.isEmpty {
                Text(entry.sentence)
                    .font(Theme.ui(24, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 10) {
                listenButton("听字") { speech.speak(entry.char) }
                if !entry.words.isEmpty {
                    listenButton("听词语") { speech.speak(entry.words.joined(separator: "，")) }
                }
                if !entry.sentence.isEmpty {
                    listenButton("听句子") { speech.speak(entry.sentence) }
                }
            }
            PrimaryButton(title: "认一认") { advance() }
        }
        .padding(22)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear { speech.speak(entry.char) }
    }

    private func listenButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(16, .bold))
                .foregroundStyle(Theme.seaDeep)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.sea.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var rest: some View {
        VStack(spacing: 14) {
            Text("今天还没有要复习的字")
                .font(Theme.ui(28, .bold))
                .foregroundStyle(Theme.ink)
            Text("先去小岛认新字，过一会儿再来")
                .font(Theme.ui(18, .medium))
                .foregroundStyle(Theme.inkSoft)
            PrimaryButton(title: "回到小岛") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var done: some View {
        VStack(spacing: 14) {
            Text("复习好了")
                .font(Theme.ui(34, .bold))
                .foregroundStyle(Theme.ink)
            Text("答对 \(correctCount) / \(questionTotal)")
                .font(Theme.ui(20, .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text("小苗又长了一点")
                .font(Theme.ui(18, .medium))
                .foregroundStyle(Theme.inkSoft)
            PrimaryButton(title: "回到小岛") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var questionTotal: Int {
        steps.filter {
            if case .question = $0 { return true }
            return false
        }.count
    }

    private var questionNumber: Int {
        steps.prefix(index + 1).filter {
            if case .question = $0 { return true }
            return false
        }.count
    }

    private var progressFraction: CGFloat {
        guard !steps.isEmpty else { return finished ? 1 : 0 }
        return CGFloat(index) / CGFloat(steps.count)
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        progress.beginSession()
        let due = progress.dueEntries(in: corpus, excluding: [], limit: 8)
        let questions = QuestionFactory.makeReviewSession(characters: due, corpus: corpus)
        var built: [ReviewStep] = []
        for question in questions {
            if let prompt = question.prompt {
                built.append(.phrase(prompt))
            }
            built.append(.question(question))
        }
        steps = built
        if built.isEmpty {
            finished = false
        }
    }

    private func advance() {
        if index + 1 >= steps.count {
            finish()
        } else {
            index += 1
        }
    }

    private func finish() {
        guard !recorded else { return }
        recorded = true
        finished = true
        if questionTotal > 0 {
            progress.notePractice()
        }
    }
}
