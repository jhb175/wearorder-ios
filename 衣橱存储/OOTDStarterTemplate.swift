import Foundation

struct OOTDCreationDraft: Equatable {
    let title: String
    let notes: String
    let marksAsToday: Bool
}

enum OOTDStarterTemplate: String, CaseIterable, Identifiable {
    case commute
    case weekend
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commute:
            "通勤搭配"
        case .weekend:
            "周末轻松搭配"
        case .social:
            "轻社交搭配"
        }
    }

    var summary: String {
        switch self {
        case .commute:
            "适合办公室、会议和日常上班。"
        case .weekend:
            "适合咖啡、散步和低压力出门。"
        case .social:
            "适合约会、聚餐和轻正式场景。"
        }
    }

    var systemImage: String {
        switch self {
        case .commute:
            "briefcase"
        case .weekend:
            "cup.and.saucer"
        case .social:
            "sparkles"
        }
    }

    var draft: OOTDCreationDraft {
        OOTDCreationDraft(
            title: title,
            notes: summary,
            marksAsToday: self == .commute
        )
    }
}
