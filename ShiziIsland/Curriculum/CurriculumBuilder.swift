import Foundation
import Combine

struct StageCurriculum: Identifiable, Hashable {
    var stage: Int
    var islands: [IslandCurriculum]
    var id: Int { stage }
    var playableCount: Int { islands.reduce(0) { $0 + $1.characters.count } }
}

struct IslandCurriculum: Identifiable, Hashable {
    var stage: Int
    var index: Int
    var characters: [HanziEntry]
    var lessons: [LessonCurriculum]
    var id: String { "s\(stage)-i\(index)" }
    var number: Int { index + 1 }
}

struct LessonCurriculum: Identifiable, Hashable {
    var stage: Int
    var islandIndex: Int
    var index: Int
    /// 测验课复习这一岛上的字，不再引入新字。
    var isCheckpoint: Bool
    /// 普通课是本课新字。书写、描红、笔顺不在这一版，以后可以沿这个数组接入。
    var characters: [HanziEntry]

    var id: String {
        isCheckpoint ? "s\(stage)-i\(islandIndex)-quiz" : "s\(stage)-i\(islandIndex)-l\(index)"
    }

    var number: Int { index + 1 }
}

enum StageInfo {
    static func name(_ stage: Int) -> String {
        switch stage {
        case 1: return "启蒙"
        case 2: return "基础"
        case 3: return "进阶"
        default: return "拓展"
        }
    }

    static func detail(_ stage: Int) -> String {
        switch stage {
        case 1: return "从最熟的字开始"
        case 2: return "把认得的字走稳"
        case 3: return "字多起来也好认"
        default: return "再去更远的小岛"
        }
    }
}

enum CurriculumBuilder {
    /// 每个阶段按 id 排序后，每 50 个可学字一座岛，不足 50 的留在该阶段最后一座岛。
    /// 每座岛每 5 个字一课，最后一课可以更短，再加一课小岛测验。
    /// hidden 的字不进入任何岛。
    static func build(entries: [HanziEntry]) -> (stages: [StageCurriculum], playable: [HanziEntry]) {
        var stages: [StageCurriculum] = []
        var playable: [HanziEntry] = []
        for stage in 1...4 {
            let chars = entries
                .filter { !$0.hidden && $0.stage == stage }
                .sorted { $0.id < $1.id }
            playable.append(contentsOf: chars)
            var islands: [IslandCurriculum] = []
            var offset = 0
            var islandIndex = 0
            while offset < chars.count {
                let end = min(offset + 50, chars.count)
                let chunk = Array(chars[offset..<end])
                offset = end
                var lessons: [LessonCurriculum] = []
                var lessonIndex = 0
                var lo = 0
                while lo < chunk.count {
                    let hi = min(lo + 5, chunk.count)
                    lessons.append(
                        LessonCurriculum(
                            stage: stage,
                            islandIndex: islandIndex,
                            index: lessonIndex,
                            isCheckpoint: false,
                            characters: Array(chunk[lo..<hi])
                        )
                    )
                    lo = hi
                    lessonIndex += 1
                }
                lessons.append(
                    LessonCurriculum(
                        stage: stage,
                        islandIndex: islandIndex,
                        index: lessonIndex,
                        isCheckpoint: true,
                        characters: chunk
                    )
                )
                islands.append(
                    IslandCurriculum(
                        stage: stage,
                        index: islandIndex,
                        characters: chunk,
                        lessons: lessons
                    )
                )
                islandIndex += 1
            }
            stages.append(StageCurriculum(stage: stage, islands: islands))
        }
        return (stages, playable)
    }
}

@MainActor
final class CorpusStore: ObservableObject {
    @Published private(set) var stages: [StageCurriculum] = []
    @Published private(set) var loadError: String?
    private(set) var playable: [HanziEntry] = []
    private var byID: [Int: HanziEntry] = [:]
    private var lessonsByID: [String: LessonCurriculum] = [:]
    private var islandsByKey: [String: IslandCurriculum] = [:]

    var playableCount: Int { playable.count }

    init() {
        load()
    }

    func entry(id: Int) -> HanziEntry? {
        byID[id]
    }

    func stage(_ stage: Int) -> StageCurriculum? {
        stages.first { $0.stage == stage }
    }

    func island(stage: Int, index: Int) -> IslandCurriculum? {
        islandsByKey["s\(stage)-i\(index)"]
    }

    func island(id: String) -> IslandCurriculum? {
        islandsByKey[id]
    }

    func lesson(id: String) -> LessonCurriculum? {
        lessonsByID[id]
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json") else {
            loadError = "字表没有放进应用里"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([HanziEntry].self, from: data)
            let built = CurriculumBuilder.build(entries: entries)
            stages = built.stages
            playable = built.playable
            var ids: [Int: HanziEntry] = [:]
            for entry in built.playable {
                ids[entry.id] = entry
            }
            byID = ids
            var lessons: [String: LessonCurriculum] = [:]
            var islands: [String: IslandCurriculum] = [:]
            for stage in built.stages {
                for island in stage.islands {
                    islands[island.id] = island
                    for lesson in island.lessons {
                        lessons[lesson.id] = lesson
                    }
                }
            }
            lessonsByID = lessons
            islandsByKey = islands
            loadError = nil
        } catch {
            loadError = "字表读不出来"
        }
    }
}
