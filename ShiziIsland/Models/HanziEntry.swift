import Foundation

/// 字表里的一条。id、字、拼音、笔画、阶段、是否隐藏都以 characters.json 为准。
struct HanziEntry: Codable, Identifiable, Hashable {
    let id: Int
    let char: String
    let pinyin: String
    let strokes: Int
    let stage: Int
    let hidden: Bool
    /// 可选。两个适合孩子的词语。
    let words: [String]
    /// 可选。一句短句。
    let sentence: String
    /// 可选。插图资源名。没有就按编号或分类图来。
    let illustration: String?

    enum CodingKeys: String, CodingKey {
        case id, char, pinyin, strokes, stage, hidden, words, sentence, illustration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        char = try container.decode(String.self, forKey: .char)
        pinyin = try container.decode(String.self, forKey: .pinyin)
        strokes = try container.decode(Int.self, forKey: .strokes)
        stage = try container.decode(Int.self, forKey: .stage)
        hidden = try container.decode(Bool.self, forKey: .hidden)
        words = try container.decodeIfPresent([String].self, forKey: .words) ?? []
        sentence = try container.decodeIfPresent(String.self, forKey: .sentence) ?? ""
        illustration = try container.decodeIfPresent(String.self, forKey: .illustration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(char, forKey: .char)
        try container.encode(pinyin, forKey: .pinyin)
        try container.encode(strokes, forKey: .strokes)
        try container.encode(stage, forKey: .stage)
        try container.encode(hidden, forKey: .hidden)
        try container.encode(words, forKey: .words)
        try container.encode(sentence, forKey: .sentence)
        try container.encodeIfPresent(illustration, forKey: .illustration)
    }
}
