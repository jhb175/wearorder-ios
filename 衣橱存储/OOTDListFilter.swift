import Foundation

enum OOTDListFilter: CaseIterable {
    case all
    case today
    case planned
    case unplanned
    case incomplete

    var title: String {
        switch self {
        case .all:
            "全部"
        case .today:
            "今日"
        case .planned:
            "已排期"
        case .unplanned:
            "未排期"
        case .incomplete:
            "缺失"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "square.grid.2x2"
        case .today:
            "sun.max"
        case .planned:
            "calendar.badge.checkmark"
        case .unplanned:
            "calendar.badge.plus"
        case .incomplete:
            "exclamationmark.triangle"
        }
    }
}
