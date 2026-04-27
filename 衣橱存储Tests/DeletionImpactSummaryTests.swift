import XCTest
@testable import 衣橱存储

final class DeletionImpactSummaryTests: XCTestCase {
    func testWardrobeItemDeletionExplainsOutfitAndPlanImpact() {
        let summary = DeletionImpactSummary.wardrobeItem(
            itemName: "白衬衫",
            linkedOutfitCount: 2,
            linkedPlanCount: 1
        )

        XCTAssertEqual(summary.headline, "删除影响")
        XCTAssertTrue(summary.message.contains("2 套搭配"))
        XCTAssertTrue(summary.message.contains("1 条计划"))
        XCTAssertTrue(summary.alertMessage.contains("相关 OOTD 会自动清空这件单品的位置"))
        XCTAssertTrue(summary.alertMessage.contains("计划本身会保留"))
    }

    func testOutfitDeletionExplainsPlanUnlinkingAndTodayState() {
        let summary = DeletionImpactSummary.outfit(
            outfitTitle: "今日通勤",
            linkedPlanCount: 3,
            isToday: true
        )

        XCTAssertTrue(summary.message.contains("今日通勤"))
        XCTAssertTrue(summary.alertMessage.contains("衣橱里的单品不会被删除"))
        XCTAssertTrue(summary.alertMessage.contains("3 条计划会保留文字摘要"))
        XCTAssertTrue(summary.alertMessage.contains("首页今日搭配会在删除后变为空状态"))
    }

    func testPlanDeletionExplainsReminderAndKeepsOutfit() {
        let summary = DeletionImpactSummary.plan(
            planTitle: "周一通勤",
            reminderEnabled: true,
            hasLinkedOutfit: true
        )

        XCTAssertTrue(summary.message.contains("周一通勤"))
        XCTAssertTrue(summary.alertMessage.contains("已保存的 OOTD 和衣物不会被删除"))
        XCTAssertTrue(summary.alertMessage.contains("本地提醒会一并移除"))
        XCTAssertTrue(summary.alertMessage.contains("只会解除当前计划和 OOTD 的关联"))
    }
}
