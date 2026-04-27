import XCTest
@testable import 衣橱存储

@MainActor
final class ClothingDraftTests: XCTestCase {
    func testDraftParsesOptionalPurchasePrice() {
        var draft = ClothingDraft()

        draft.purchasePriceText = ""
        XCTAssertTrue(draft.isPurchasePriceValid)
        XCTAssertNil(draft.normalizedPurchasePrice)

        draft.purchasePriceText = "129.90"
        XCTAssertTrue(draft.isPurchasePriceValid)
        XCTAssertEqual(draft.normalizedPurchasePrice, 129.90)

        draft.purchasePriceText = "1,299"
        XCTAssertTrue(draft.isPurchasePriceValid)
        XCTAssertEqual(draft.normalizedPurchasePrice, 1299)

        draft.purchasePriceText = "￥1,299.50"
        XCTAssertTrue(draft.isPurchasePriceValid)
        XCTAssertEqual(draft.normalizedPurchasePrice, 1299.50)

        draft.purchasePriceText = "129,90"
        XCTAssertTrue(draft.isPurchasePriceValid)
        XCTAssertEqual(draft.normalizedPurchasePrice, 129.90)

        draft.purchasePriceText = "-1"
        XCTAssertFalse(draft.isPurchasePriceValid)
        XCTAssertNil(draft.normalizedPurchasePrice)
    }

    func testDraftLoadsCommercialFieldsFromItem() {
        let purchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let item = WardrobeItem(
            name: "白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季",
            imageSymbol: "shirt.fill",
            brand: "Daily",
            size: "M",
            purchasePrice: 199,
            purchaseDate: purchaseDate,
            purchaseChannel: "品牌官网",
            careNotes: "低温熨烫"
        )

        let draft = ClothingDraft(item: item)

        XCTAssertEqual(draft.brand, "Daily")
        XCTAssertEqual(draft.size, "M")
        XCTAssertEqual(draft.normalizedPurchasePrice, 199)
        XCTAssertTrue(draft.hasPurchaseDate)
        XCTAssertEqual(draft.purchaseDate, purchaseDate)
        XCTAssertEqual(draft.purchaseChannel, "品牌官网")
        XCTAssertEqual(draft.careNotes, "低温熨烫")
    }
}
