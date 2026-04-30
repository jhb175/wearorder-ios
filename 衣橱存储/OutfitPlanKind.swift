import Foundation

enum OutfitPlanKind: String, CaseIterable, Identifiable, Codable {
    case daily
    case specialEvent
    case trip

    var id: String { rawValue }

    static func normalized(_ rawValue: String?) -> OutfitPlanKind {
        guard let rawValue,
              let kind = OutfitPlanKind(rawValue: rawValue)
        else {
            return .daily
        }
        return kind
    }

    var title: String {
        switch self {
        case .daily:
            return "日常"
        case .specialEvent:
            return "特别日"
        case .trip:
            return "旅行"
        }
    }

    var homeTitle: String {
        switch self {
        case .daily:
            return "未来穿搭"
        case .specialEvent:
            return "特别日穿搭"
        case .trip:
            return "旅行穿搭"
        }
    }

    var listTitle: String {
        switch self {
        case .daily:
            return "日常计划"
        case .specialEvent:
            return "特别日"
        case .trip:
            return "旅行"
        }
    }

    var symbolName: String {
        switch self {
        case .daily:
            return "calendar"
        case .specialEvent:
            return "sparkles"
        case .trip:
            return "airplane.departure"
        }
    }

    var defaultTitle: String {
        switch self {
        case .daily:
            return "新的穿搭计划"
        case .specialEvent:
            return "新的特别日穿搭"
        case .trip:
            return "新的旅行穿搭"
        }
    }

    var defaultOccasion: String {
        switch self {
        case .daily:
            return "穿搭安排"
        case .specialEvent:
            return "特别日"
        case .trip:
            return "旅行"
        }
    }

    var helperText: String {
        switch self {
        case .daily:
            return "适合通勤、上课、周末、约会等常规安排。"
        case .specialEvent:
            return "适合生日、纪念日、婚礼、面试、拍照等重要场合。"
        case .trip:
            return "适合多日出行，后续会接入目的地和未来天气。"
        }
    }

    var locationFieldTitle: String {
        switch self {
        case .daily:
            return "地点"
        case .specialEvent:
            return "活动地点"
        case .trip:
            return "目的地"
        }
    }

    var locationFieldPrompt: String {
        switch self {
        case .daily:
            return "例如：公司 / 学校 / 市区"
        case .specialEvent:
            return "例如：婚礼酒店 / 拍摄地点"
        case .trip:
            return "例如：东京 / 首尔 / 巴黎"
        }
    }

    var locationHelperText: String {
        switch self {
        case .daily:
            return "地点可留空；填写天气城市后，后续可按这一天的真实天气补充建议。"
        case .specialEvent:
            return "特别日建议填写地点和天气城市，方便未来按场景、通勤距离和天气准备。"
        case .trip:
            return "旅行计划建议填写目的地和天气城市，后续会用于未来天气与 AI 行李/穿搭建议。"
        }
    }
}
