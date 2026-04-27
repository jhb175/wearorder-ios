import SwiftData
import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeBackupManagerTests: XCTestCase {
    func testRestoreRoundTripKeepsRelationshipsAndImageData() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let top = makeItem(
            id: "11111111-1111-1111-1111-111111111111",
            name: "白色短袖",
            category: "上装",
            season: "春夏",
            imageData: Data([1, 2, 3]),
            brand: "Daily Tee",
            size: "M",
            purchasePrice: 89,
            purchaseDate: exportedAt,
            purchaseChannel: "品牌官网",
            careNotes: "冷水反面洗"
        )
        let bottom = makeItem(
            id: "22222222-2222-2222-2222-222222222222",
            name: "浅蓝牛仔裤",
            category: "下装",
            colorName: "浅蓝",
            season: "春夏"
        )
        let outfit = OOTDOutfit(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "热天小雨搭配",
            notes: "雨天但气温很高，不应该排除夏季单品。",
            createdAt: exportedAt,
            updatedAt: exportedAt,
            isToday: true,
            topItem: top,
            bottomItem: bottom
        )
        let plan = OutfitPlan(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            date: exportedAt.addingTimeInterval(86_400),
            title: "明天通勤",
            occasion: "通勤",
            notes: "恢复后要继续关联 OOTD。",
            outfitSummary: outfit.summaryText,
            reminderEnabled: false,
            createdAt: exportedAt,
            updatedAt: exportedAt,
            linkedOutfit: outfit
        )

        let backupData = try WardrobeBackupManager.exportData(
            items: [top, bottom],
            outfits: [outfit],
            plans: [plan],
            exportedAt: exportedAt
        )
        let container = try makeContainer()
        let context = container.mainContext

        let summary = try WardrobeBackupManager.restore(
            from: backupData,
            into: context,
            existingItems: [],
            existingOutfits: [],
            existingPlans: []
        )

        XCTAssertEqual(summary.insertedItems, 2)
        XCTAssertEqual(summary.insertedOutfits, 1)
        XCTAssertEqual(summary.insertedPlans, 1)
        XCTAssertEqual(summary.plansForNotificationSync.map(\.id), [plan.id])

        let restoredItems = try context.fetch(FetchDescriptor<WardrobeItem>())
        let restoredOutfits = try context.fetch(FetchDescriptor<OOTDOutfit>())
        let restoredPlans = try context.fetch(FetchDescriptor<OutfitPlan>())
        let restoredTop = try XCTUnwrap(restoredItems.first { $0.id == top.id })
        let restoredOutfit = try XCTUnwrap(restoredOutfits.first)
        let restoredPlan = try XCTUnwrap(restoredPlans.first)

        XCTAssertEqual(restoredItems.count, 2)
        XCTAssertEqual(restoredTop.imageData, Data([1, 2, 3]))
        XCTAssertEqual(restoredTop.trimmedBrand, "Daily Tee")
        XCTAssertEqual(restoredTop.trimmedSize, "M")
        XCTAssertEqual(restoredTop.purchasePrice, 89)
        XCTAssertEqual(restoredTop.purchaseDate, exportedAt)
        XCTAssertEqual(restoredTop.trimmedPurchaseChannel, "品牌官网")
        XCTAssertEqual(restoredTop.trimmedCareNotes, "冷水反面洗")
        XCTAssertEqual(restoredOutfit.topItem?.id, top.id)
        XCTAssertEqual(restoredOutfit.bottomItem?.id, bottom.id)
        XCTAssertTrue(restoredOutfit.isToday)
        XCTAssertEqual(restoredPlan.linkedOutfit?.id, outfit.id)
        XCTAssertEqual(restoredPlan.outfitSummary, "白色短袖 + 浅蓝牛仔裤")
    }

    func testRestoreUpdatesExistingRecordsByIdentifier() throws {
        let itemID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let existingItem = WardrobeItem(
            id: itemID,
            name: "旧名称",
            category: "上装",
            colorName: "灰色",
            season: "四季",
            imageSymbol: "shirt.fill"
        )
        let incomingItem = WardrobeItem(
            id: itemID,
            name: "更新后的衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "春秋",
            imageSymbol: "tshirt.fill",
            styleTagsText: "通勤, 简洁",
            notes: "来自备份",
            brand: "Updated Brand",
            size: "L",
            purchasePrice: 299,
            purchaseDate: Date(timeIntervalSince1970: 1_800_000_000),
            purchaseChannel: "线下门店",
            careNotes: "悬挂晾干",
            isFavorite: true
        )

        let container = try makeContainer()
        let context = container.mainContext
        context.insert(existingItem)

        let backupData = try WardrobeBackupManager.exportData(
            items: [incomingItem],
            outfits: [],
            plans: []
        )
        let summary = try WardrobeBackupManager.restore(
            from: backupData,
            into: context,
            existingItems: [existingItem],
            existingOutfits: [],
            existingPlans: []
        )

        XCTAssertEqual(summary.insertedItems, 0)
        XCTAssertEqual(summary.updatedItems, 1)
        XCTAssertEqual(existingItem.name, "更新后的衬衫")
        XCTAssertEqual(existingItem.colorName, "奶油白")
        XCTAssertTrue(existingItem.isFavorite)
        XCTAssertEqual(existingItem.styleTags, ["通勤", "简洁"])
        XCTAssertEqual(existingItem.trimmedBrand, "Updated Brand")
        XCTAssertEqual(existingItem.trimmedSize, "L")
        XCTAssertEqual(existingItem.purchasePrice, 299)
        XCTAssertEqual(existingItem.trimmedPurchaseChannel, "线下门店")
        XCTAssertEqual(existingItem.trimmedCareNotes, "悬挂晾干")
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WardrobeItem.self,
            OutfitPlan.self,
            OOTDOutfit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeItem(
        id: String,
        name: String,
        category: String,
        colorName: String = "奶油白",
        season: String,
        imageData: Data? = nil,
        brand: String = "Sample Brand",
        size: String = "M",
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseChannel: String = "",
        careNotes: String = ""
    ) -> WardrobeItem {
        WardrobeItem(
            id: UUID(uuidString: id)!,
            name: name,
            category: category,
            colorName: colorName,
            season: season,
            imageSymbol: "tshirt.fill",
            imageData: imageData,
            styleTagsText: "休闲, 舒适",
            brand: brand,
            size: size,
            purchasePrice: purchasePrice,
            purchaseDate: purchaseDate,
            purchaseChannel: purchaseChannel,
            careNotes: careNotes,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
