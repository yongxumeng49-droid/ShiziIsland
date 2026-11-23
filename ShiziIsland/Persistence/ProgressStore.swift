import Foundation
import Combine

struct ReviewRecord: Codable, Equatable {
    var box: Int
    var due: TimeInterval
    var introduced: Bool
}

struct SavedProgress: Codable, Equatable {
    var bestStars: [String: Int] = [:]
    var completed: [String: Bool] = [:]
    var reviews: [String: ReviewRecord] = [:]
    var streak: Int = 0
    var lastPracticeDay: String? = nil
    /// 某一天第一次算进每日计划的新字 id。旧进度文件没有这个字段，仍然能读。
    var newCharacterDays: [String: [Int]] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case bestStars, completed, reviews, streak, lastPracticeDay, newCharacterDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestStars = try container.decodeIfPresent([String: Int].self, forKey: .bestStars) ?? [:]
        completed = try container.decodeIfPresent([String: Bool].self, forKey: .completed) ?? [:]
        reviews = try container.decodeIfPresent([String: ReviewRecord].self, forKey: .reviews) ?? [:]
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastPracticeDay = try container.decodeIfPresent(String.self, forKey: .lastPracticeDay)
        newCharacterDays = try container.decodeIfPresent([String: [Int]].self, forKey: .newCharacterDays) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bestStars, forKey: .bestStars)
        try container.encode(completed, forKey: .completed)
        try container.encode(reviews, forKey: .reviews)
        try container.encode(streak, forKey: .streak)
        try container.encodeIfPresent(lastPracticeDay, forKey: .lastPracticeDay)
        try container.encode(newCharacterDays, forKey: .newCharacterDays)
    }
}

enum LessonAccess: Equatable {
    case ready
    case needsPrevious
    case restToday
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var saved = SavedProgress()
    private let fileURL: URL
    /// 同一课里，一个字的盒子最多往上走一格；答错仍会立刻退回。
    private var advancedThisSession: Set<Int> = []

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        load()
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("ShiziIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    func beginSession() {
        advancedThisSession.removeAll()
    }

    func grade(id: Int, correct: Bool, now: Date = .now) {
        let key = String(id)
        var record = saved.reviews[key] ?? ReviewRecord(box: 0, due: now.timeIntervalSince1970, introduced: true)
        record.introduced = true
        if correct {
            if !advancedThisSession.contains(id) {
                record.box = min(7, record.box + 1)
                advancedThisSession.insert(id)
            }
        } else {
            record.box = 1
            advancedThisSession.insert(id)
        }
        if record.box < 1 { record.box = 1 }
        record.due = now.addingTimeInterval(Self.interval(for: record.box)).timeIntervalSince1970
        saved.reviews[key] = record
        persist()
    }

    func dueCount(in corpus: CorpusStore, now: Date = .now) -> Int {
        dueEntries(in: corpus, excluding: [], limit: Int.max, now: now).count
    }

    func memoryBox(for id: Int) -> Int {
        saved.reviews[String(id)]?.box ?? 0
    }

    func notePractice(now: Date = .now) {
        recordPractice(now)
        persist()
    }

    func dueEntries(in corpus: CorpusStore, excluding: Set<Int>, limit: Int, now: Date = .now) -> [HanziEntry] {
        guard limit > 0 else { return [] }
        let nowTS = now.timeIntervalSince1970
        let ranked = saved.reviews.compactMap { key, record -> (Int, ReviewRecord)? in
            guard record.introduced, record.due <= nowTS, let id = Int(key), !excluding.contains(id) else {
                return nil
            }
            return (id, record)
        }
        .sorted { lhs, rhs in
            if lhs.1.box != rhs.1.box { return lhs.1.box < rhs.1.box }
            return lhs.1.due < rhs.1.due
        }
        var result: [HanziEntry] = []
        for (id, _) in ranked {
            guard let entry = corpus.entry(id: id), !entry.hidden else { continue }
            result.append(entry)
            if result.count == limit { break }
        }
        return result
    }

    func complete(lessonID: String, stars: Int, now: Date = .now) {
        let clamped = min(3, max(1, stars))
        if clamped > (saved.bestStars[lessonID] ?? 0) {
            saved.bestStars[lessonID] = clamped
        }
        saved.completed[lessonID] = true
        recordPractice(now)
        persist()
    }

    func isCompleted(_ id: String) -> Bool {
        saved.completed[id] == true
    }

    func stars(for id: String) -> Int {
        saved.bestStars[id] ?? 0
    }

    func islandStars(_ island: IslandCurriculum) -> Int {
        island.lessons.reduce(0) { $0 + stars(for: $1.id) }
    }

    func displayedStreak(now: Date = .now) -> Int {
        guard let last = saved.lastPracticeDay else { return 0 }
        let today = Self.dayKey(now)
        let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        if last == today || last == yesterday { return saved.streak }
        return 0
    }

    func practicedToday(now: Date = .now) -> Bool {
        saved.lastPracticeDay == Self.dayKey(now)
    }

    func learnedCount(in corpus: CorpusStore) -> Int {
        var count = 0
        for stage in corpus.stages {
            for island in stage.islands {
                for lesson in island.lessons where !lesson.isCheckpoint && isCompleted(lesson.id) {
                    count += lesson.characters.count
                }
            }
        }
        return count
    }

    func totalStars() -> Int {
        saved.bestStars.values.reduce(0, +)
    }

    func isStageUnlocked(_ stage: Int, in corpus: CorpusStore) -> Bool {
        guard stage > 1 else { return true }
        guard let previous = corpus.stage(stage - 1) else { return false }
        if previous.islands.isEmpty {
            return isStageUnlocked(stage - 1, in: corpus)
        }
        return previous.islands.allSatisfy { isIslandCompleted($0) }
    }

    func isIslandUnlocked(_ island: IslandCurriculum, in corpus: CorpusStore) -> Bool {
        guard isStageUnlocked(island.stage, in: corpus) else { return false }
        guard island.index > 0 else { return true }
        guard let previous = corpus.island(stage: island.stage, index: island.index - 1) else { return false }
        return isIslandCompleted(previous)
    }

    func isIslandCompleted(_ island: IslandCurriculum) -> Bool {
        !island.lessons.isEmpty && island.lessons.allSatisfy { isCompleted($0.id) }
    }

    func newCharactersToday(now: Date = .now) -> Int {
        saved.newCharacterDays[Self.dayKey(now)]?.count ?? 0
    }

    func remainingNewCharactersToday(limit: Int, now: Date = .now) -> Int {
        max(0, AppSettings.normalizedLimit(limit) - newCharactersToday(now: now))
    }

    /// 这一课里还没算进任何一天、也还没在已完成的课里出现过的字。
    func freshCharacters(in lesson: LessonCurriculum, corpus: CorpusStore) -> [HanziEntry] {
        let known = knownCharacterIDs(in: corpus)
        return lesson.characters.filter { !known.contains($0.id) }
    }

    func access(to lesson: LessonCurriculum, in corpus: CorpusStore, dailyLimit: Int, now: Date = .now) -> LessonAccess {
        guard isLessonUnlocked(lesson, in: corpus) else { return .needsPrevious }
        if lesson.isCheckpoint || isCompleted(lesson.id) { return .ready }
        let todayIDs = saved.newCharacterDays[Self.dayKey(now)] ?? []
        let todaySet = Set(todayIDs)
        if lesson.characters.contains(where: { todaySet.contains($0.id) }) {
            return .ready
        }
        let fresh = freshCharacters(in: lesson, corpus: corpus)
        if fresh.isEmpty { return .ready }
        let limit = AppSettings.normalizedLimit(dailyLimit)
        if todayIDs.count + fresh.count <= limit { return .ready }
        return .restToday
    }

    /// 打开一课新字时记账。已经记过或已经学完的字不会再占今天的名额。
    func recordNewCharactersIfNeeded(_ lesson: LessonCurriculum, in corpus: CorpusStore, now: Date = .now) {
        guard !lesson.isCheckpoint, !isCompleted(lesson.id) else { return }
        let today = Self.dayKey(now)
        var todayIDs = saved.newCharacterDays[today] ?? []
        let known = knownCharacterIDs(in: corpus)
        var changed = false
        for entry in lesson.characters where !known.contains(entry.id) && !todayIDs.contains(entry.id) {
            todayIDs.append(entry.id)
            changed = true
        }
        guard changed else { return }
        var next = saved
        next.newCharacterDays[today] = todayIDs
        saved = next
        persist()
    }

    func isLessonUnlocked(_ lesson: LessonCurriculum, in corpus: CorpusStore) -> Bool {
        guard let island = corpus.island(stage: lesson.stage, index: lesson.islandIndex) else { return false }
        guard isIslandUnlocked(island, in: corpus) else { return false }
        if isCompleted(lesson.id) { return true }
        if lesson.isCheckpoint {
            return island.lessons.filter { !$0.isCheckpoint }.allSatisfy { isCompleted($0.id) }
        }
        if lesson.index == 0 { return true }
        guard let previous = island.lessons.first(where: { !$0.isCheckpoint && $0.index == lesson.index - 1 }) else {
            return false
        }
        return isCompleted(previous.id)
    }

    func completedIslandCount(_ stage: StageCurriculum) -> Int {
        stage.islands.filter { isIslandCompleted($0) }.count
    }

    private func knownCharacterIDs(in corpus: CorpusStore) -> Set<Int> {
        var ids = Set(saved.newCharacterDays.values.flatMap { $0 })
        for stage in corpus.stages {
            for island in stage.islands {
                for lesson in island.lessons where !lesson.isCheckpoint && isCompleted(lesson.id) {
                    for entry in lesson.characters {
                        ids.insert(entry.id)
                    }
                }
            }
        }
        return ids
    }

    private func recordPractice(_ now: Date) {
        let today = Self.dayKey(now)
        if saved.lastPracticeDay == today { return }
        let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        if saved.lastPracticeDay == yesterday {
            saved.streak += 1
        } else {
            saved.streak = 1
        }
        saved.lastPracticeDay = today
    }

    /// 艾宾浩斯式间隔：10 分钟、1 天、2 天、4 天、7 天、15 天、30 天。
    /// 旧进度里的盒子编号仍然可读，不会清空。
    static func interval(for box: Int) -> TimeInterval {
        switch box {
        case 1: return 10 * 60
        case 2: return 1 * 24 * 60 * 60
        case 3: return 2 * 24 * 60 * 60
        case 4: return 4 * 24 * 60 * 60
        case 5: return 7 * 24 * 60 * 60
        case 6: return 15 * 24 * 60 * 60
        default: return 30 * 24 * 60 * 60
        }
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(SavedProgress.self, from: data) else {
            return
        }
        saved = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
