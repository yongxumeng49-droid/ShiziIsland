import Foundation

/// 启蒙第一岛用单独的图。后面的字先用分类图，直到补上更多画。
enum IllustrationCatalog {
    static func assetName(for entry: HanziEntry) -> String {
        if let name = entry.illustration?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if (1...50).contains(entry.id) {
            return String(format: "Hanzi%04d", entry.id)
        }
        return categoryAsset(for: entry.char)
    }

    static func categoryAsset(for character: String) -> String {
        if people.contains(character) { return "IllustrationPeople" }
        if nature.contains(character) { return "IllustrationNature" }
        if home.contains(character) { return "IllustrationHome" }
        if action.contains(character) { return "IllustrationAction" }
        if object.contains(character) { return "IllustrationObject" }
        return "IllustrationStory"
    }

    private static let people = set("爸妈父母爷奶哥姐弟妹友孩童师生医兵王公男女老少谁民叔姨姑舅婆孙娃仔")
    private static let nature = set("山水风雨云雪花草木林田星天地江河海石春夏秋冬鸟鱼虫猫狗虎兔龙叶果阳光空森湖波沙露霜虹")
    private static let home = set("家门窗床桌椅碗饭菜茶房厨院厅灯枕被席锅勺")
    private static let action = set("走跑跳看听说读写吃喝玩笑哭坐站进出回来去想问答唱玩拿放推拉开关睡醒")
    private static let object = set("书笔车船刀伞球衣鞋帽杯纸包盒钟表镜画旗剑弓箭车轮")

    private static func set(_ source: String) -> Set<String> {
        Set(source.map { String($0) })
    }
}
