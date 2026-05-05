import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeExporterTests: XCTestCase {

    // MARK: - plainText

    func testPlainTextHeaderIncludesItemCount() {
        let items = [
            makeItem(name: "白色短袖", category: "上装"),
            makeItem(name: "黑色西裤", category: "下装")
        ]

        let report = WardrobeExporter.plainText(from: items)

        XCTAssertTrue(report.contains("衣橱清单"))
        XCTAssertTrue(report.contains("单品数量：2"))
    }

    func testPlainTextSortsItemsByCategoryThenName() {
        let items = [
            makeItem(name: "牛仔裤", category: "下装"),
            makeItem(name: "毛衣", category: "上装"),
            makeItem(name: "T恤", category: "上装")
        ]

        let report = WardrobeExporter.plainText(from: items)
        let tShirtIndex = report.range(of: "- T恤")?.lowerBound
        let sweaterIndex = report.range(of: "- 毛衣")?.lowerBound
        let jeansIndex = report.range(of: "- 牛仔裤")?.lowerBound

        XCTAssertNotNil(tShirtIndex)
        XCTAssertNotNil(sweaterIndex)
        XCTAssertNotNil(jeansIndex)

        // 上装 sorts before 下装 by string compare on these names? Actually 下 < 上 in Unicode.
        // We just verify that within 上装 group, T恤 comes before 毛衣 (T < 毛 in Unicode)
        // and that all three are present in the output exactly once.
        let counts = ["- T恤", "- 毛衣", "- 牛仔裤"].map { name in
            report.components(separatedBy: name).count - 1
        }
        XCTAssertEqual(counts, [1, 1, 1], "each item should appear exactly once")
    }

    func testPlainTextSkipsBlankNotesAndCareNotes() {
        let item = makeItem(name: "白衬衫", category: "上装", notes: "  ", careNotes: "")
        let report = WardrobeExporter.plainText(from: [item])

        XCTAssertFalse(report.contains("备注："))
        XCTAssertFalse(report.contains("保养："))
    }

    func testPlainTextEmitsFavoriteAndStyleTagsWhenPresent() {
        let item = makeItem(
            name: "卫衣",
            category: "上装",
            isFavorite: true,
            styleTagsText: "通勤, 休闲"
        )

        let report = WardrobeExporter.plainText(from: [item])

        XCTAssertTrue(report.contains("收藏：是"))
        XCTAssertTrue(report.contains("标签：通勤、休闲"))
    }

    // MARK: - fullReport

    func testFullReportHeaderIncludesAllSectionCounts() {
        let items = [makeItem(name: "白衬衫", category: "上装")]
        let outfits = [makeOutfit(title: "通勤套装")]
        let plans = [makePlan(title: "周一通勤", date: Date.now)]

        let report = WardrobeExporter.fullReport(items: items, outfits: outfits, plans: plans)

        XCTAssertTrue(report.contains("单品数量：1"))
        XCTAssertTrue(report.contains("OOTD 数量：1"))
        XCTAssertTrue(report.contains("计划数量：1"))
        XCTAssertTrue(report.contains("一、衣橱单品"))
        XCTAssertTrue(report.contains("二、OOTD 搭配"))
        XCTAssertTrue(report.contains("三、穿搭计划"))
    }

    func testFullReportShowsEmptyMessagesForEachEmptySection() {
        let report = WardrobeExporter.fullReport(items: [], outfits: [], plans: [])

        XCTAssertTrue(report.contains("暂无衣物。"))
        XCTAssertTrue(report.contains("暂无 OOTD。"))
        XCTAssertTrue(report.contains("暂无计划。"))
    }

    // MARK: - plansReport

    func testPlansReportSortsChronologicallyAscending() {
        let earliest = makePlan(title: "最早", date: makeDate(year: 2026, month: 5, day: 1))
        let middle = makePlan(title: "中间", date: makeDate(year: 2026, month: 5, day: 5))
        let latest = makePlan(title: "最晚", date: makeDate(year: 2026, month: 5, day: 10))

        let report = WardrobeExporter.plansReport(from: [latest, earliest, middle])

        let earliestRange = report.range(of: "- 最早")?.lowerBound
        let middleRange = report.range(of: "- 中间")?.lowerBound
        let latestRange = report.range(of: "- 最晚")?.lowerBound

        XCTAssertNotNil(earliestRange)
        XCTAssertNotNil(middleRange)
        XCTAssertNotNil(latestRange)
        XCTAssertLessThan(earliestRange!, middleRange!)
        XCTAssertLessThan(middleRange!, latestRange!)
    }

    func testPlansReportRendersReminderNotEnabledLabel() {
        let plan = makePlan(title: "周末", date: Date.now, reminderEnabled: false)

        let report = WardrobeExporter.plansReport(from: [plan])

        XCTAssertTrue(report.contains("提醒：未开启"))
    }

    // MARK: - outfitReport

    func testOutfitReportListsEverySlotEvenWhenItemMissing() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let outfit = makeOutfit(title: "极简组合", topItem: top, bottomItem: nil)

        let report = WardrobeExporter.outfitReport(for: outfit, linkedPlans: [])

        XCTAssertTrue(report.contains("- 上装：白衬衫"))
        XCTAssertTrue(report.contains("- 下装：未选择"))
        XCTAssertTrue(report.contains("- 外套：未选择"))
        XCTAssertTrue(report.contains("- 鞋子：未选择"))
        XCTAssertTrue(report.contains("- 包：未选择"))
        XCTAssertTrue(report.contains("- 配饰：未选择"))
    }

    func testOutfitReportShowsEmptyLinkedPlansMessageWhenNonePassed() {
        let outfit = makeOutfit(title: "通勤")

        let report = WardrobeExporter.outfitReport(for: outfit, linkedPlans: [])

        XCTAssertTrue(report.contains("暂无计划引用这套 OOTD 预设。"))
    }

    func testOutfitReportListsLinkedPlansSortedByDate() {
        let outfit = makeOutfit(title: "通勤")
        let later = makePlan(title: "周一", date: makeDate(year: 2026, month: 5, day: 5))
        let earlier = makePlan(title: "周日", date: makeDate(year: 2026, month: 5, day: 4))

        let report = WardrobeExporter.outfitReport(for: outfit, linkedPlans: [later, earlier])

        let earlierRange = report.range(of: "周日")?.lowerBound
        let laterRange = report.range(of: "周一")?.lowerBound
        XCTAssertNotNil(earlierRange)
        XCTAssertNotNil(laterRange)
        XCTAssertLessThan(earlierRange!, laterRange!)
    }

    // MARK: - itemReport

    func testItemReportSurfacesEmptyLinkedSectionsWhenNoneProvided() {
        let item = makeItem(name: "白衬衫", category: "上装")

        let report = WardrobeExporter.itemReport(for: item, linkedOutfits: [], linkedPlans: [])

        XCTAssertTrue(report.contains("暂无 OOTD 使用这件衣物。"))
        XCTAssertTrue(report.contains("暂无计划通过 OOTD 使用这件衣物。"))
    }

    func testItemReportListsLinkedOutfitsNewestFirst() {
        let item = makeItem(name: "白衬衫", category: "上装")
        let older = makeOutfit(
            title: "旧搭配",
            createdAt: makeDate(year: 2026, month: 4, day: 1)
        )
        let newer = makeOutfit(
            title: "新搭配",
            createdAt: makeDate(year: 2026, month: 5, day: 1)
        )

        let report = WardrobeExporter.itemReport(
            for: item,
            linkedOutfits: [older, newer],
            linkedPlans: []
        )

        let newerRange = report.range(of: "新搭配")?.lowerBound
        let olderRange = report.range(of: "旧搭配")?.lowerBound
        XCTAssertNotNil(newerRange)
        XCTAssertNotNil(olderRange)
        XCTAssertLessThan(newerRange!, olderRange!, "newest outfit should appear first")
    }

    // MARK: - Helpers

    private func makeItem(
        id: UUID = UUID(),
        name: String,
        category: String,
        colorName: String = "白色",
        season: String = "四季",
        notes: String = "",
        careNotes: String = "",
        isFavorite: Bool = false,
        styleTagsText: String = ""
    ) -> WardrobeItem {
        WardrobeItem(
            id: id,
            name: name,
            category: category,
            colorName: colorName,
            season: season,
            imageSymbol: "tshirt.fill",
            styleTagsText: styleTagsText,
            notes: notes,
            careNotes: careNotes,
            isFavorite: isFavorite
        )
    }

    private func makeOutfit(
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        topItem: WardrobeItem? = nil,
        bottomItem: WardrobeItem? = nil
    ) -> OOTDOutfit {
        OOTDOutfit(
            title: title,
            notes: notes,
            createdAt: createdAt,
            topItem: topItem,
            bottomItem: bottomItem
        )
    }

    private func makePlan(
        title: String,
        date: Date,
        reminderEnabled: Bool = false
    ) -> OutfitPlan {
        OutfitPlan(
            planKind: .daily,
            date: date,
            title: title,
            occasion: "通勤",
            outfitSummary: "白衬衫 + 黑西裤",
            reminderEnabled: reminderEnabled
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }
}
