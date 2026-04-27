import Foundation

struct PlannerReminderSummary: Equatable {
    let planCount: Int
    let enabledReminderCount: Int
    let invalidReminderCount: Int
    let conflictingPlanCount: Int
    let unlinkedPlanCount: Int

    var statusTitle: String {
        if invalidReminderCount > 0 {
            return "有失效提醒"
        }
        if conflictingPlanCount > 0 {
            return "存在同日多排"
        }
        return "提醒状态正常"
    }

    var statusMessage: String {
        if invalidReminderCount > 0 {
            return "\(invalidReminderCount) 条计划的提醒时间为空或已过去，可以一键关闭。"
        }
        if conflictingPlanCount > 0 {
            return "\(conflictingPlanCount) 条计划与同日其他安排重叠，出门前建议确认。"
        }
        return "已开启提醒 \(enabledReminderCount) 条，计划冲突处于可控状态。"
    }

    static func make(plans: [OutfitPlan], now: Date = .now) -> PlannerReminderSummary {
        let invalidReminderCount = plans.filter { plan in
            guard plan.reminderEnabled else { return false }
            guard let reminderDate = plan.reminderDate else { return true }
            return reminderDate <= now
        }
        .count

        let conflictingPlanCount = plans.filter { plan in
            plans.filter { Calendar.current.isDate($0.date, inSameDayAs: plan.date) }.count > 1
        }
        .count

        return PlannerReminderSummary(
            planCount: plans.count,
            enabledReminderCount: plans.filter(\.reminderEnabled).count,
            invalidReminderCount: invalidReminderCount,
            conflictingPlanCount: conflictingPlanCount,
            unlinkedPlanCount: plans.filter { $0.linkedOutfit == nil }.count
        )
    }
}
