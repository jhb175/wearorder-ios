import Foundation

enum OOTDPresetSortMode: CaseIterable {
    case recent
    case title
    case plannedCount

    var title: String {
        switch self {
        case .recent:
            "最近更新"
        case .title:
            "名称"
        case .plannedCount:
            "使用次数"
        }
    }

    var systemImage: String {
        switch self {
        case .recent:
            "clock"
        case .title:
            "textformat"
        case .plannedCount:
            "calendar.badge.clock"
        }
    }
}
