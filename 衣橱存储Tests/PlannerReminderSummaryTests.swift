import XCTest
@testable import 衣橱存储

@MainActor
final class PlannerReminderSummaryTests: XCTestCase {
    func testSummaryFlagsInvalidReminders() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let invalidPlan = OutfitPlan(
            date: now,
            title: "旧提醒",
            occasion: "通勤",
            outfitSummary: "未绑定 OOTD",
            reminderEnabled: true,
            reminderDate: now.addingTimeInterval(-60)
        )
        let futurePlan = OutfitPlan(
            date: now.addingTimeInterval(86_400),
            title: "未来提醒",
            occasion: "通勤",
            outfitSummary: "未绑定 OOTD",
            reminderEnabled: true,
            reminderDate: now.addingTimeInterval(3_600)
        )

        let summary = PlannerReminderSummary.make(plans: [invalidPlan, futurePlan], now: now)

        XCTAssertEqual(summary.enabledReminderCount, 2)
        XCTAssertEqual(summary.invalidReminderCount, 1)
        XCTAssertEqual(summary.statusTitle, "有失效提醒")
    }

    func testSummaryCountsConflictsAndUnlinkedPlans() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let top = WardrobeItem(name: "上衣", category: "上装", colorName: "奶油白", season: "四季", imageSymbol: "shirt.fill")
        let bottom = WardrobeItem(name: "长裤", category: "下装", colorName: "炭灰", season: "四季", imageSymbol: "figure.walk")
        let outfit = OOTDOutfit(title: "通勤", notes: "", topItem: top, bottomItem: bottom)
        let linkedPlan = OutfitPlan(
            date: day,
            title: "早会",
            occasion: "办公室",
            outfitSummary: outfit.summaryText,
            reminderEnabled: false,
            linkedOutfit: outfit
        )
        let unlinkedPlan = OutfitPlan(
            date: day.addingTimeInterval(3_600),
            title: "晚餐",
            occasion: "聚餐",
            outfitSummary: "未绑定 OOTD",
            reminderEnabled: false
        )

        let summary = PlannerReminderSummary.make(plans: [linkedPlan, unlinkedPlan], now: day)

        XCTAssertEqual(summary.conflictingPlanCount, 2)
        XCTAssertEqual(summary.unlinkedPlanCount, 1)
        XCTAssertEqual(summary.statusTitle, "存在同日多排")
    }
}
