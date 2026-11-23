import Combine
import Foundation

/// 设置里的三种声音。录音目录用同一个英文名。
enum StudyVoice: String, CaseIterable, Identifiable {
    case child1
    case child2
    case teacher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .child1: return "童声1"
        case .child2: return "童声2"
        case .teacher: return "老师"
        }
    }

    var detail: String {
        switch self {
        case .child1: return "更高一点，像小孩"
        case .child2: return "另一个小孩的声音"
        case .teacher: return "老师在旁边说话"
        }
    }

    /// 没有配音时，系统普通话的音高。童声抬高，老师保持自然。
    var fallbackPitch: Float {
        switch self {
        case .child1: return 1.34
        case .child2: return 1.16
        case .teacher: return 1.02
        }
    }

    var fallbackRate: Float {
        switch self {
        case .child1: return 0.40
        case .child2: return 0.40
        case .teacher: return 0.46
        }
    }
}

enum DailyNewCharacterPlan: Int, CaseIterable, Identifiable {
    case oneLesson = 5
    case twoLessons = 10

    var id: Int { rawValue }

    var title: String {
        "每天 \(rawValue) 个新字"
    }

    var detail: String {
        switch self {
        case .oneLesson: return "一次新课"
        case .twoLessons: return "两次新课"
        }
    }
}

/// 声音和每日计划存在本机偏好里，不写进 progress.json，避免碰到已有进度。
@MainActor
final class AppSettings: ObservableObject {
    @Published var voice: StudyVoice {
        didSet { defaults.set(voice.rawValue, forKey: Keys.voice) }
    }

    @Published var dailyNewCharacters: Int {
        didSet {
            let clamped = Self.normalizedLimit(dailyNewCharacters)
            if clamped != dailyNewCharacters {
                dailyNewCharacters = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.daily)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.voice), let stored = StudyVoice(rawValue: raw) {
            voice = stored
        } else {
            voice = .child1
        }
        let storedLimit = defaults.object(forKey: Keys.daily) as? Int
        dailyNewCharacters = Self.normalizedLimit(storedLimit ?? DailyNewCharacterPlan.oneLesson.rawValue)
    }

    var dailyPlan: DailyNewCharacterPlan {
        get { dailyNewCharacters == DailyNewCharacterPlan.twoLessons.rawValue ? .twoLessons : .oneLesson }
        set { dailyNewCharacters = newValue.rawValue }
    }

    static func normalizedLimit(_ value: Int) -> Int {
        value == DailyNewCharacterPlan.twoLessons.rawValue
            ? DailyNewCharacterPlan.twoLessons.rawValue
            : DailyNewCharacterPlan.oneLesson.rawValue
    }

    private enum Keys {
        static let voice = "shizi.voice"
        static let daily = "shizi.dailyNewCharacters"
    }
}
