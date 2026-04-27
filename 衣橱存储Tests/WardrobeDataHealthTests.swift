import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeDataHealthTests: XCTestCase {
    func testHealthyDataHasNoIssues() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let top = makeItem(id: "11111111-aaaa-aaaa-aaaa-111111111111", name: "白衬衫", category: "上装")
        let bottom = makeItem(id: "22222222-aaaa-aaaa-aaaa-222222222222", name: "西装裤", category: "下装")
        let shoes = makeItem(id: "33333333-aaaa-aaaa-aaaa-333333333333", name: "乐福鞋", category: "鞋履")
        let outfit = OOTDOutfit(
            title: "通勤搭配",
            notes: "",
            createdAt: now,
            isToday: true,
            topItem: top,
            bottomItem: bottom,
            shoesItem: shoes
        )
        let plan = OutfitPlan(
            date: now.addingTimeInterval(86_400),
            title: "明天通勤",
            occasion: "办公室",
            outfitSummary: outfit.summaryText,
            reminderEnabled: true,
            reminderDate: now.addingTimeInterval(3_600),
            linkedOutfit: outfit
        )

        let snapshot = WardrobeDataHealthSnapshot.make(
            items: [top, bottom, shoes],
            outfits: [outfit],
            plans: [plan],
            now: now
        )

        XCTAssertEqual(snapshot.statusTitle, "状态良好")
        XCTAssertTrue(snapshot.issues.isEmpty)
    }

    func testHealthSnapshotFlagsCommercialDataRisks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let duplicateA = makeItem(id: "44444444-aaaa-aaaa-aaaa-444444444444", name: "白衬衫", category: "上装")
        let duplicateB = makeItem(id: "55555555-aaaa-aaaa-aaaa-555555555555", name: "白衬衫", category: "上装", imageData: Data(repeating: 7, count: 1_600_000))
        let incompleteOutfitA = OOTDOutfit(title: "不完整 A", notes: "", createdAt: now, isToday: true, topItem: duplicateA)
        let incompleteOutfitB = OOTDOutfit(title: "不完整 B", notes: "", createdAt: now, isToday: true, topItem: duplicateB)
        let expiredPlan = OutfitPlan(
            date: now,
            title: "旧提醒",
            occasion: "通勤",
            outfitSummary: "",
            reminderEnabled: true,
            reminderDate: now.addingTimeInterval(-60)
        )

        let snapshot = WardrobeDataHealthSnapshot.make(
            items: [duplicateA, duplicateB],
            outfits: [incompleteOutfitA, incompleteOutfitB],
            plans: [expiredPlan],
            now: now
        )
        let issueIDs = Set(snapshot.issues.map(\.id))

        XCTAssertEqual(snapshot.statusTitle, "需要处理")
        XCTAssertTrue(issueIDs.contains("duplicate-item-names"))
        XCTAssertTrue(issueIDs.contains("large-photos"))
        XCTAssertTrue(issueIDs.contains("missing-core-categories"))
        XCTAssertTrue(issueIDs.contains("incomplete-outfits"))
        XCTAssertTrue(issueIDs.contains("multiple-today-outfits"))
        XCTAssertTrue(issueIDs.contains("invalid-reminders"))
        XCTAssertTrue(issueIDs.contains("plans-without-outfit"))
    }

    private func makeItem(
        id: String,
        name: String,
        category: String,
        imageData: Data? = nil
    ) -> WardrobeItem {
        WardrobeItem(
            id: UUID(uuidString: id)!,
            name: name,
            category: category,
            colorName: "奶油白",
            season: "四季",
            imageSymbol: "tshirt.fill",
            imageData: imageData,
            styleTagsText: "通勤, 简洁",
            brand: "基础品牌",
            size: "M",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
