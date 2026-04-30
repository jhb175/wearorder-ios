import Foundation
import SwiftData

struct PlanCreationDraft: Identifiable {
    let id = UUID()
    var selectedOutfitID: PersistentIdentifier?
    var planKind: OutfitPlanKind
    var title: String
    var occasion: String
    var locationName: String
    var weatherCityName: String
    var notes: String
    var date: Date
    var reminderEnabled: Bool
    var reminderTime: Date

    static func blank(
        selectedOutfitID: PersistentIdentifier? = nil,
        calendar: Calendar = .current
    ) -> PlanCreationDraft {
        let date = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let reminderTime = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date) ?? date
        return PlanCreationDraft(
            selectedOutfitID: selectedOutfitID,
            planKind: .daily,
            title: "新的穿搭计划",
            occasion: "穿搭安排",
            locationName: "",
            weatherCityName: "",
            notes: "",
            date: date,
            reminderEnabled: true,
            reminderTime: reminderTime
        )
    }

    static func arrangingPreset(
        _ outfit: OOTDOutfit,
        date requestedDate: Date? = nil,
        calendar: Calendar = .current
    ) -> PlanCreationDraft {
        let fallbackDate = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let date = requestedDate ?? fallbackDate
        let reminderTime = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date) ?? date
        let planKind = inferredPlanKind(for: outfit)
        let occasion = inferredOccasion(for: outfit, planKind: planKind)
        let title = outfit.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return PlanCreationDraft(
            selectedOutfitID: outfit.persistentModelID,
            planKind: planKind,
            title: title.isEmpty ? planKind.defaultTitle : title,
            occasion: occasion,
            locationName: "",
            weatherCityName: "",
            notes: "从 OOTD 预设快速安排。",
            date: date,
            reminderEnabled: reminderTime > .now,
            reminderTime: reminderTime
        )
    }

    private static func inferredPlanKind(for outfit: OOTDOutfit) -> OutfitPlanKind {
        let tags = Set(outfit.presetTags)
        if tags.contains(OOTDPresetTag.travel.title) {
            return .trip
        }

        let specialTags: Set<String> = [
            OOTDPresetTag.date.title,
            OOTDPresetTag.formal.title,
            OOTDPresetTag.party.title,
            OOTDPresetTag.ceremony.title
        ]
        if !tags.isDisjoint(with: specialTags) {
            return .specialEvent
        }

        return .daily
    }

    private static func inferredOccasion(for outfit: OOTDOutfit, planKind: OutfitPlanKind) -> String {
        if let firstTag = outfit.presetTags.first {
            return firstTag
        }
        return planKind.defaultOccasion
    }
}

struct PlannerPresetQuickApplySnapshot {
    let totalPresetCount: Int
    let incompletePresetCount: Int
    let schedulableOutfits: [OOTDOutfit]

    static func make(
        outfits: [OOTDOutfit],
        limit: Int = 8
    ) -> PlannerPresetQuickApplySnapshot {
        let sortedOutfits = outfits.sorted { lhs, rhs in
            if lhs.isToday != rhs.isToday {
                return lhs.isToday
            }
            if lhs.createdAt == rhs.createdAt {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.createdAt > rhs.createdAt
        }
        let completeOutfits = sortedOutfits.filter { !$0.isIncomplete }
        return PlannerPresetQuickApplySnapshot(
            totalPresetCount: outfits.count,
            incompletePresetCount: outfits.count - completeOutfits.count,
            schedulableOutfits: Array(completeOutfits.prefix(limit))
        )
    }

    var hasSchedulablePresets: Bool {
        !schedulableOutfits.isEmpty
    }

    var subtitle: String {
        if totalPresetCount == 0 {
            return "先保存 OOTD"
        }
        if schedulableOutfits.isEmpty {
            return "预设待补全"
        }
        if incompletePresetCount > 0 {
            return "\(schedulableOutfits.count) 套可用 · \(incompletePresetCount) 套待补"
        }
        return "\(schedulableOutfits.count) 套可直接安排"
    }
}

enum PlannerQuickTemplate: String, CaseIterable, Identifiable {
    case morningCommute
    case eveningMeetup
    case weekendOuting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningCommute:
            "明早通勤"
        case .eveningMeetup:
            "今晚会面"
        case .weekendOuting:
            "周末出门"
        }
    }

    var symbolName: String {
        switch self {
        case .morningCommute:
            "briefcase"
        case .eveningMeetup:
            "moon.stars"
        case .weekendOuting:
            "figure.walk"
        }
    }

    var summary: String {
        switch self {
        case .morningCommute:
            "明天 08:30 提醒"
        case .eveningMeetup:
            "今天 18:00 提醒"
        case .weekendOuting:
            "周六 10:00 提醒"
        }
    }

    func draft(
        selectedOutfitID: PersistentIdentifier?,
        calendar: Calendar = .current
    ) -> PlanCreationDraft {
        let date = plannedDate(calendar: calendar)
        let reminderTime = calendar.date(
            bySettingHour: reminderHour,
            minute: reminderMinute,
            second: 0,
            of: date
        ) ?? date

        return PlanCreationDraft(
            selectedOutfitID: selectedOutfitID,
            planKind: .daily,
            title: title,
            occasion: occasion,
            locationName: "",
            weatherCityName: "",
            notes: notes,
            date: date,
            reminderEnabled: true,
            reminderTime: reminderTime
        )
    }

    private var occasion: String {
        switch self {
        case .morningCommute:
            "通勤"
        case .eveningMeetup:
            "会面"
        case .weekendOuting:
            "周末"
        }
    }

    private var notes: String {
        switch self {
        case .morningCommute:
            "出门前确认外套、包和鞋履。"
        case .eveningMeetup:
            "保留一点轻松感，避免太正式。"
        case .weekendOuting:
            "适合走路和室外停留，优先舒适。"
        }
    }

    private var reminderHour: Int {
        switch self {
        case .morningCommute:
            8
        case .eveningMeetup:
            18
        case .weekendOuting:
            10
        }
    }

    private var reminderMinute: Int {
        switch self {
        case .morningCommute:
            30
        case .eveningMeetup, .weekendOuting:
            0
        }
    }

    private func plannedDate(calendar: Calendar) -> Date {
        switch self {
        case .morningCommute:
            return calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        case .eveningMeetup:
            let evening = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
            if evening > .now {
                return evening
            }
            return calendar.date(byAdding: .day, value: 1, to: evening) ?? evening
        case .weekendOuting:
            return nextWeekend(calendar: calendar)
        }
    }

    private func nextWeekend(calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let offset = daysUntilSaturday == 0 ? 7 : daysUntilSaturday
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }
}
