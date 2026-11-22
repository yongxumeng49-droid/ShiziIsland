import SwiftUI

struct QuestionPage: View {
    var question: PracticeQuestion
    var index: Int
    var total: Int
    @ObservedObject var speech: SpeechService
    var onAnswer: (Bool) -> Void
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            header
            Group {
                switch question.kind {
                case .match:
                    MatchBoard(pairs: question.pairs, onAnswer: onAnswer, onAdvance: onAdvance)
                default:
                    ChoiceQuestion(question: question, speech: speech, onAnswer: onAnswer, onAdvance: onAdvance)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(question.kind.title)
                .font(Theme.ui(16, .bold))
                .foregroundStyle(Theme.seaDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.sea.opacity(0.12), in: Capsule())
            if question.isReview {
                Text("复习")
                    .font(Theme.ui(16, .bold))
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.coral.opacity(0.14), in: Capsule())
            }
            Spacer()
            Text("\(index) / \(total)")
                .font(Theme.ui(16, .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

struct ChoiceQuestion: View {
    var question: PracticeQuestion
    @ObservedObject var speech: SpeechService
    var onAnswer: (Bool) -> Void
    var onAdvance: () -> Void

    @State private var pickedID: Int?
    @State private var resolved = false
    @State private var correct = false
    @State private var autoAdvance = false
    @State private var tick = 0
    @State private var advanced = false

    private var prompt: HanziEntry? { question.prompt }

    var body: some View {
        GeometryReader { geo in
            let sideBySide = geo.size.width > geo.size.height && geo.size.width > 900
            Group {
                if sideBySide {
                    HStack(spacing: 28) {
                        promptPane
                            .frame(maxWidth: .infinity)
                        answerPane
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 22) {
                        promptPane
                        answerPane
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: question.id) {
            if question.kind == .listenPickChar, let prompt {
                speech.speakCharacter(prompt.char)
            }
        }
        .task(id: tick) {
            guard autoAdvance, tick > 0 else { return }
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            advance()
        }
        .sensoryFeedback(correct ? .success : .warning, trigger: tick)
    }

    private var promptPane: some View {
        VStack(spacing: 16) {
            Text(question.kind.instruction)
                .font(Theme.ui(22, .semibold))
                .foregroundStyle(Theme.inkSoft)
            if question.kind == .listenPickChar {
                Button {
                    if let prompt { speech.speakCharacter(prompt.char) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Theme.card)
                        .frame(width: 140, height: 140)
                        .background(Theme.sea, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("再听一次")
            } else if question.kind == .pickCharFromPinyin, let prompt {
                Text(prompt.pinyin)
                    .font(Theme.ui(72, .bold))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else if let prompt {
                Text(prompt.char)
                    .font(Theme.glyph(168))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.4)
            }
            if resolved {
                feedback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var answerPane: some View {
        VStack(spacing: 14) {
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(question.choices) { choice in
                    AnswerTile(
                        title: question.kind == .pickPinyin ? choice.pinyin : choice.char,
                        glyph: question.kind != .pickPinyin,
                        mark: mark(for: choice)
                    ) {
                        choose(choice)
                    }
                }
            }
            if resolved {
                PrimaryButton(title: correct ? "继续" : "知道了", fill: correct ? Theme.good : Theme.miss) {
                    advance()
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var feedback: some View {
        Text(correct ? "答对啦" : "再记一记，正确答案是 \(correctText)")
            .font(Theme.ui(22, .bold))
            .foregroundStyle(correct ? Theme.good : Theme.miss)
            .multilineTextAlignment(.center)
    }

    private var correctText: String {
        guard let prompt else { return "" }
        return question.kind == .pickPinyin ? prompt.pinyin : prompt.char
    }

    private func mark(for choice: HanziEntry) -> AnswerMark {
        guard resolved, let prompt else {
            return pickedID == choice.id ? .selected : .idle
        }
        if choice.id == prompt.id { return .correct }
        if choice.id == pickedID { return .wrong }
        return .dimmed
    }

    private func choose(_ choice: HanziEntry) {
        guard !resolved, let prompt else { return }
        pickedID = choice.id
        resolved = true
        correct = choice.id == prompt.id
        onAnswer(correct)
        tick += 1
        if correct {
            autoAdvance = true
        }
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        autoAdvance = false
        onAdvance()
    }
}

struct MatchBoard: View {
    var pairs: [HanziEntry]
    var onAnswer: (Bool) -> Void
    var onAdvance: () -> Void

    @State private var left: [HanziEntry]
    @State private var right: [HanziEntry]
    @State private var matched: Set<Int> = []
    @State private var selected: Int?
    @State private var wrongLeft: Int?
    @State private var wrongRight: Int?
    @State private var mistakes = 0
    @State private var finished = false
    @State private var advanced = false
    @State private var reported = false
    @State private var wrongToken = 0

    init(pairs: [HanziEntry], onAnswer: @escaping (Bool) -> Void, onAdvance: @escaping () -> Void) {
        self.pairs = pairs
        self.onAnswer = onAnswer
        self.onAdvance = onAdvance
        var lhs = pairs.shuffled()
        var rhs = pairs.shuffled()
        if lhs.map(\.id) == rhs.map(\.id), rhs.count > 1 {
            rhs.swapAt(0, 1)
        }
        _left = State(initialValue: lhs)
        _right = State(initialValue: rhs)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(finished ? (mistakes == 0 ? "全部配对正确" : "配好了，有的要再记一记") : "先点字，再点拼音")
                .font(Theme.ui(22, .semibold))
                .foregroundStyle(finished ? (mistakes == 0 ? Theme.good : Theme.miss) : Theme.inkSoft)
            HStack(alignment: .top, spacing: 16) {
                column(left, glyph: true)
                column(right, glyph: false)
            }
            .frame(maxWidth: 860)
            if finished {
                PrimaryButton(title: "继续", fill: mistakes == 0 ? Theme.good : Theme.miss) {
                    advance()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: wrongToken) {
            guard wrongToken > 0 else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            wrongLeft = nil
            wrongRight = nil
        }
        .task(id: finished && mistakes == 0) {
            guard finished, mistakes == 0 else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            advance()
        }
        .sensoryFeedback(mistakes == 0 ? .success : .warning, trigger: finished)
    }

    private func column(_ entries: [HanziEntry], glyph: Bool) -> some View {
        VStack(spacing: 12) {
            ForEach(entries) { entry in
                AnswerTile(
                    title: glyph ? entry.char : entry.pinyin,
                    glyph: glyph,
                    mark: mark(entry, glyph: glyph)
                ) {
                    tap(entry, glyph: glyph)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func mark(_ entry: HanziEntry, glyph: Bool) -> AnswerMark {
        if matched.contains(entry.id) { return .correct }
        if glyph && wrongLeft == entry.id { return .wrong }
        if !glyph && wrongRight == entry.id { return .wrong }
        if glyph && selected == entry.id { return .selected }
        return .idle
    }

    private func tap(_ entry: HanziEntry, glyph: Bool) {
        guard !finished, !matched.contains(entry.id) else { return }
        if glyph {
            selected = entry.id
            return
        }
        guard let selected else { return }
        if selected == entry.id {
            matched.insert(entry.id)
            self.selected = nil
            if matched.count == pairs.count {
                finish()
            }
        } else {
            mistakes += 1
            wrongLeft = selected
            wrongRight = entry.id
            self.selected = nil
            wrongToken += 1
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        if !reported {
            reported = true
            onAnswer(mistakes == 0)
        }
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        onAdvance()
    }
}
