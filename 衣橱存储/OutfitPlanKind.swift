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
}
