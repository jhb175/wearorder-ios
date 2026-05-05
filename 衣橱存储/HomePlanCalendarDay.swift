import Foundation

struct HomePlanCalendarDay: Identifiable {
    let date: Date
    let planCount: Int
    let isToday: Bool

    var id: Date { date }

    var weekdayText: String {
        date.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "zh_Hans_CN")))
    }

    var dayText: String {
        date.formatted(.dateTime.day().locale(Locale(identifier: "zh_Hans_CN")))
    }

    var accessibilityLabel: String {
        let dateText = date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_Hans_CN")))
        if planCount == 0 {
            return "\(dateText)，没有 OOTD 计划"
        }
        return "\(dateText)，\(planCount) 条 OOTD 计划"
    }
}
