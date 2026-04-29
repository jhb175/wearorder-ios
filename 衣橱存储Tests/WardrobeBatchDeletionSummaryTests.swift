import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeBatchDeletionSummaryTests: XCTestCase {
    func testSummaryCountsAffectedOutfitsAndPlans() {
        let top = makeItem(index: 1, category: "上装")
        let bottom = makeItem(index: 2, category: "下装")
        let shoes = makeItem(index: 3, category: "鞋履")
        let outfit = OOTDOutfit(title: "通勤", notes: "", topItem: top, bottomItem: bottom, shoesItem: shoes)
        let plan = OutfitPlan(
            date: .now,
            title: "周一通勤",
            occasion: "通勤",
            notes: "",
            outfitSummary: outfit.summaryText,
            reminderEnabled: false,
            linkedOutfit: outfit
        )

        let summary = WardrobeBatchDeletionSummary.make(
            itemsToDelete: [top, shoes],
            outfits: [outfit],
            plans: [plan]
        )

        XCTAssertEqual(summary.itemCount, 2)
        XCTAssertEqual(summary.affectedOutfitCount, 1)
        XCTAssertEqual(summary.affectedPlanCount, 1)
        XCTAssertTrue(summary.alertMessage.contains("1 套 OOTD"))
        XCTAssertTrue(summary.alertMessage.contains("1 条计划"))
    }

    func testSummaryHandlesThreeHundredItemWardrobe() {
        let items = (0..<300).map { index in
            makeItem(index: index, category: index.isMultiple(of: 2) ? "上装" : "下装")
        }
        let outfits = stride(from: 0, to: 60, by: 6).map { index in
            OOTDOutfit(
                title: "搭配 \(index)",
                notes: "",
                topItem: items[index],
                bottomItem: items[index + 1],
                shoesItem: items[index + 2]
            )
        }
        let plans = outfits.prefix(5).enumerated().map { offset, outfit in
            OutfitPlan(
                date: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + offset * 86_400)),
                title: "计划 \(offset)",
                occasion: "测试",
                notes: "",
                outfitSummary: outfit.summaryText,
                reminderEnabled: false,
                linkedOutfit: outfit
            )
        }

        let summary = WardrobeBatchDeletionSummary.make(
            itemsToDelete: Array(items.prefix(30)),
            outfits: outfits,
            plans: plans
        )

        XCTAssertEqual(summary.itemCount, 30)
        XCTAssertEqual(summary.affectedOutfitCount, 5)
        XCTAssertEqual(summary.affectedPlanCount, 5)
        XCTAssertTrue(summary.hasSelection)
    }

    private func makeItem(index: Int, category: String) -> WardrobeItem {
        WardrobeItem(
            name: "单品 \(index)",
            category: category,
            colorName: "浅灰",
            season: "四季",
            imageSymbol: "tshirt.fill",
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + index))
        )
    }
}
