import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeDataRepairTests: XCTestCase {
    func testPreviewDoesNotMutateModels() {
        let item = WardrobeItem(
            name: "  ",
            category: "未知分类",
            colorName: "  ",
            season: "冬季",
            imageSymbol: " ",
            styleTagsText: "通勤，通勤, 简洁",
            notes: "  需要修剪  "
        )

        let summary = WardrobeDataRepair.preview(items: [item], outfits: [], plans: [])

        XCTAssertTrue(summary.hasChanges)
        XCTAssertEqual(item.name, "  ")
        XCTAssertEqual(item.category, "未知分类")
        XCTAssertEqual(item.styleTagsText, "通勤，通勤, 简洁")
    }

    func testRepairNormalizesRecordsAndResolvesInvalidState() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = WardrobeItem(
            name: "  ",
            category: "未知分类",
            colorName: "  ",
            season: "冬季",
            imageSymbol: " ",
            styleTagsText: "通勤，通勤, 简洁",
            notes: "  需要修剪  ",
            createdAt: now
        )
        item.updatedAt = nil
        item.brand = "  旧品牌  "
        item.size = "  M  "
        item.purchasePrice = -12
        item.purchaseChannel = "  品牌官网  "
        item.careNotes = "  平铺晾干  "

        let top = WardrobeItem(name: "上衣", category: "上装", colorName: "奶油白", season: "四季", imageSymbol: "shirt.fill")
        let bottom = WardrobeItem(name: "长裤", category: "下装", colorName: "炭灰", season: "四季", imageSymbol: "figure.walk")
        let oldToday = OOTDOutfit(
            title: "  ",
            notes: "  旧今日  ",
            createdAt: now,
            updatedAt: now,
            isToday: true,
            topItem: top,
            bottomItem: bottom
        )
        let newToday = OOTDOutfit(
            title: "新今日",
            notes: "",
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60),
            isToday: true,
            topItem: top,
            bottomItem: bottom
        )
        let invalidPlan = OutfitPlan(
            date: now,
            title: "  ",
            occasion: " ",
            notes: "  早会  ",
            outfitSummary: " ",
            reminderEnabled: true,
            reminderDate: now.addingTimeInterval(-60),
            createdAt: now,
            linkedOutfit: newToday
        )
        invalidPlan.updatedAt = nil

        let summary = WardrobeDataRepair.apply(
            items: [item, top, bottom],
            outfits: [oldToday, newToday],
            plans: [invalidPlan],
            now: now
        )

        XCTAssertEqual(summary.normalizedItems, 1)
        XCTAssertEqual(summary.normalizedOutfits, 1)
        XCTAssertEqual(summary.normalizedPlans, 1)
        XCTAssertEqual(summary.disabledInvalidReminders, 1)
        XCTAssertEqual(summary.resolvedTodayDuplicates, 1)

        XCTAssertEqual(item.name, "未命名衣物")
        XCTAssertEqual(item.category, "配饰")
        XCTAssertEqual(item.colorName, "奶油白")
        XCTAssertEqual(item.season, "四季")
        XCTAssertEqual(item.styleTagsText, "通勤, 简洁")
        XCTAssertEqual(item.notes, "需要修剪")
        XCTAssertEqual(item.trimmedBrand, "旧品牌")
        XCTAssertEqual(item.trimmedSize, "M")
        XCTAssertNil(item.purchasePrice)
        XCTAssertEqual(item.trimmedPurchaseChannel, "品牌官网")
        XCTAssertEqual(item.trimmedCareNotes, "平铺晾干")

        XCTAssertEqual(oldToday.title, "未命名搭配")
        XCTAssertEqual(oldToday.notes, "旧今日")
        XCTAssertFalse(oldToday.isToday)
        XCTAssertTrue(newToday.isToday)

        XCTAssertEqual(invalidPlan.title, "未命名计划")
        XCTAssertEqual(invalidPlan.occasion, "穿搭安排")
        XCTAssertEqual(invalidPlan.notes, "早会")
        XCTAssertEqual(invalidPlan.outfitSummary, newToday.summaryText)
        XCTAssertFalse(invalidPlan.reminderEnabled)
        XCTAssertNil(invalidPlan.reminderDate)
    }
}
