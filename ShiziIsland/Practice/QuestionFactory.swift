import Foundation

enum QuestionKind: String, Equatable {
    case pickPinyin
    case listenPickChar
    case pickCharFromPinyin
    case match

    var title: String {
        switch self {
        case .pickPinyin: return "看字选拼音"
        case .listenPickChar: return "听音选字"
        case .pickCharFromPinyin: return "看拼音选字"
        case .match: return "配对"
        }
    }

    var instruction: String {
        switch self {
        case .pickPinyin: return "这个字读什么"
        case .listenPickChar: return "听一听，选出这个字"
        case .pickCharFromPinyin: return "哪个字读作"
        case .match: return "把字和拼音配成一对"
        }
    }
}

struct PracticeQuestion: Identifiable, Equatable {
    let id: UUID
    var kind: QuestionKind
    var prompt: HanziEntry?
    var choices: [HanziEntry]
    var pairs: [HanziEntry]
    var isReview: Bool

    var gradedEntries: [HanziEntry] {
        if kind == .match { return pairs }
        if let prompt { return [prompt] }
        return []
    }
}

@MainActor
enum QuestionFactory {
    static func makeSession(
        lesson: LessonCurriculum,
        corpus: CorpusStore,
        progress: ProgressStore
    ) -> [PracticeQuestion] {
        let island = corpus.island(stage: lesson.stage, index: lesson.islandIndex)
        let exclude = Set(lesson.characters.map(\.id))
        let dueLimit = lesson.isCheckpoint ? 2 : 4
        let due = progress.dueEntries(in: corpus, excluding: exclude, limit: dueLimit)
        var questions = reviewQuestions(due, corpus: corpus, island: island)
        let target = lesson.isCheckpoint ? 12 : practiceCount(lesson.characters.count)
        questions.append(contentsOf: practiceQuestions(
            characters: lesson.characters,
            target: target,
            corpus: corpus,
            island: island,
            isReview: false,
            coverAll: !lesson.isCheckpoint
        ))
        return questions.filter(isValid)
    }

    /// 今日复习：每个到期的字一道题，够三个字再加一道配对。
    static func makeReviewSession(characters: [HanziEntry], corpus: CorpusStore) -> [PracticeQuestion] {
        guard !characters.isEmpty else { return [] }
        var questions = reviewQuestions(characters, corpus: corpus, island: nil)
        if characters.count >= 3, let match = makeMatch(from: characters, isReview: true) {
            questions.append(match)
        }
        return questions.filter(isValid)
    }

    static func practiceCount(_ count: Int) -> Int {
        guard count > 0 else { return 8 }
        return min(12, max(8, count * 2))
    }

    private static func reviewQuestions(
        _ due: [HanziEntry],
        corpus: CorpusStore,
        island: IslandCurriculum?
    ) -> [PracticeQuestion] {
        let kinds: [QuestionKind] = [.listenPickChar, .pickPinyin, .pickCharFromPinyin, .pickPinyin]
        var questions: [PracticeQuestion] = []
        for (index, entry) in due.enumerated() {
            let kind = kinds[index % kinds.count]
            if let question = makeMCQ(kind: kind, target: entry, corpus: corpus, island: island, isReview: true) {
                questions.append(question)
            }
        }
        return questions
    }

    private static func practiceQuestions(
        characters: [HanziEntry],
        target: Int,
        corpus: CorpusStore,
        island: IslandCurriculum?,
        isReview: Bool,
        coverAll: Bool
    ) -> [PracticeQuestion] {
        guard !characters.isEmpty, target > 0 else { return [] }
        let cycle: [QuestionKind] = [
            .pickPinyin, .listenPickChar, .pickCharFromPinyin,
            .pickPinyin, .listenPickChar, .match,
            .pickCharFromPinyin, .listenPickChar, .pickPinyin,
            .match, .pickCharFromPinyin, .listenPickChar
        ]
        var plan: [QuestionKind] = []
        while plan.count < target {
            plan.append(cycle[plan.count % cycle.count])
        }
        let ordered = characters.shuffled()
        var questions: [PracticeQuestion] = []
        var covered = Set<Int>()
        var cursor = 0

        func nextTarget() -> HanziEntry {
            let entry = ordered[cursor % ordered.count]
            cursor += 1
            return entry
        }

        for kind in plan {
            if kind == .match, let match = makeMatch(from: ordered, isReview: isReview) {
                questions.append(match)
                for entry in match.pairs { covered.insert(entry.id) }
                continue
            }
            let use: QuestionKind = kind == .match ? .pickPinyin : kind
            let targetEntry = nextTarget()
            if let question = makeMCQ(kind: use, target: targetEntry, corpus: corpus, island: island, isReview: isReview) {
                questions.append(question)
                if let id = question.prompt?.id { covered.insert(id) }
            }
        }

        if coverAll {
            for entry in ordered where !covered.contains(entry.id) {
                let question = makeMCQ(kind: .pickPinyin, target: entry, corpus: corpus, island: island, isReview: isReview)
                    ?? makeMCQ(kind: .listenPickChar, target: entry, corpus: corpus, island: island, isReview: isReview)
                if let question {
                    questions.append(question)
                }
            }
        }
        return questions
    }

    private static func makeMCQ(
        kind: QuestionKind,
        target: HanziEntry,
        corpus: CorpusStore,
        island: IslandCurriculum?,
        isReview: Bool
    ) -> PracticeQuestion? {
        guard kind != .match else { return nil }
        let pool = candidates(for: target, corpus: corpus, island: island)
        let prefer: (HanziEntry) -> Bool = { other in
            if kind == .pickPinyin { return similarSound(target, other) }
            return similarSound(target, other) || similarLook(target, other)
        }
        let label: (HanziEntry) -> String = { entry in
            kind == .pickPinyin ? entry.pinyin : entry.char
        }
        let distractors = pick(target: target, pool: pool, prefer: prefer, label: label, count: 3)
        guard distractors.count == 3 else { return nil }
        var choices = distractors + [target]
        choices.shuffle()
        return PracticeQuestion(
            id: UUID(),
            kind: kind,
            prompt: target,
            choices: choices,
            pairs: [],
            isReview: isReview
        )
    }

    private static func makeMatch(from characters: [HanziEntry], isReview: Bool) -> PracticeQuestion? {
        var unique: [HanziEntry] = []
        var pinyins = Set<String>()
        var glyphs = Set<String>()
        for entry in characters.shuffled() {
            if entry.pinyin.isEmpty || entry.char.isEmpty { continue }
            if !pinyins.insert(entry.pinyin).inserted { continue }
            if !glyphs.insert(entry.char).inserted { continue }
            unique.append(entry)
        }
        guard unique.count >= 3 else { return nil }
        let size = (unique.count >= 4 && Bool.random()) ? 4 : 3
        let pairs = Array(unique.prefix(size))
        guard pairs.count >= 3 else { return nil }
        return PracticeQuestion(id: UUID(), kind: .match, prompt: nil, choices: [], pairs: pairs, isReview: isReview)
    }

    private static func candidates(
        for target: HanziEntry,
        corpus: CorpusStore,
        island: IslandCurriculum?
    ) -> [HanziEntry] {
        var seen: Set<Int> = [target.id]
        var ordered: [HanziEntry] = []
        func add(_ items: [HanziEntry]) {
            for item in items where !item.hidden && seen.insert(item.id).inserted {
                ordered.append(item)
            }
        }
        if let island {
            add(island.characters)
        }
        add(corpus.playable.filter { $0.stage == target.stage && abs($0.id - target.id) <= 40 })
        add(corpus.playable.filter { $0.stage == target.stage })
        add(corpus.playable)
        return ordered
    }

    private static func pick(
        target: HanziEntry,
        pool: [HanziEntry],
        prefer: (HanziEntry) -> Bool,
        label: (HanziEntry) -> String,
        count: Int
    ) -> [HanziEntry] {
        var result: [HanziEntry] = []
        var labels: Set<String> = [label(target)]
        let preferred = pool.filter { prefer($0) && $0.char != target.char && !labels.contains(label($0)) }.shuffled()
        let others = pool.filter { !prefer($0) && $0.char != target.char && !labels.contains(label($0)) }.shuffled()
        for item in preferred + others {
            let text = label(item)
            if labels.contains(text) || item.char == target.char { continue }
            labels.insert(text)
            result.append(item)
            if result.count == count { break }
        }
        return result
    }

    private static func isValid(_ question: PracticeQuestion) -> Bool {
        switch question.kind {
        case .match:
            guard (3...4).contains(question.pairs.count) else { return false }
            guard question.pairs.allSatisfy({ !$0.hidden && !$0.pinyin.isEmpty }) else { return false }
            return Set(question.pairs.map(\.pinyin)).count == question.pairs.count
                && Set(question.pairs.map(\.char)).count == question.pairs.count
        default:
            guard let prompt = question.prompt, !prompt.hidden, question.choices.count == 4 else { return false }
            guard question.choices.contains(where: { $0.id == prompt.id }) else { return false }
            guard question.choices.allSatisfy({ !$0.hidden }) else { return false }
            let labels = question.choices.map { question.kind == .pickPinyin ? $0.pinyin : $0.char }
            return Set(labels).count == 4
        }
    }

    static func syllable(of pinyin: String) -> String {
        let map: [Character: Character] = [
            "ā": "a", "á": "a", "ǎ": "a", "à": "a",
            "ē": "e", "é": "e", "ě": "e", "è": "e",
            "ī": "i", "í": "i", "ǐ": "i", "ì": "i",
            "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
            "ū": "u", "ú": "u", "ǔ": "u", "ù": "u",
            "ǖ": "ü", "ǘ": "ü", "ǚ": "ü", "ǜ": "ü",
            "ń": "n", "ň": "n", "ǹ": "n",
            "ḿ": "m"
        ]
        var output = ""
        for character in pinyin.lowercased() {
            if character == " " || character == "'" { continue }
            output.append(map[character] ?? character)
        }
        return output
    }

    static func similarSound(_ lhs: HanziEntry, _ rhs: HanziEntry) -> Bool {
        if lhs.pinyin == rhs.pinyin { return false }
        let left = syllable(of: lhs.pinyin)
        let right = syllable(of: rhs.pinyin)
        if left.isEmpty || right.isEmpty { return false }
        if left == right { return true }
        if abs(left.count - right.count) > 1 { return false }
        return editDistance(left, right) == 1
    }

    static func similarLook(_ lhs: HanziEntry, _ rhs: HanziEntry) -> Bool {
        abs(lhs.strokes - rhs.strokes) <= 1
    }

    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                let insert = current[j - 1] + 1
                let delete = previous[j] + 1
                let replace = previous[j - 1] + cost
                current.append(min(insert, delete, replace))
            }
            previous = current
        }
        return previous[b.count]
    }
}
