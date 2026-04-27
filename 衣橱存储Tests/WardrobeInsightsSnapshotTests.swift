import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeInsightsSnapshotTests: XCTestCase {
    func testInsightsTrackValueDistributionAndCompletion() {
        let shirt = makeItem(
            name: "白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季",
            brand: "Daily",
            size: "M",
            purchasePrice: 199,
            purchaseChannel: "品牌官网",
            imageData: Data([1]),
            styleTagsText: "通勤"
        )
        let shoes = makeItem(
            name: "运动鞋",
            category: "鞋履",
            colorName: "暖白",
            season: "四季",
            brand: "Walk Lab",
            size: "38",
            purchasePrice: 399,
            purchaseChannel: "线下门店",
            imageData: Data([2]),
            styleTagsText: "舒适"
        )
        let incomplete = makeItem(
            name: "牛仔裤",
            category: "下装",
            colorName: "浅蓝",
            season: "春夏",
            brand: "",
            size: "",
            purchasePrice: nil,
            purchaseChannel: "",
            imageData: nil,
            styleTagsText: ""
        )

        let snapshot = WardrobeInsightsSnapshot.make(items: [shirt, shoes, incomplete])

        XCTAssertEqual(snapshot.itemCount, 3)
        XCTAssertEqual(snapshot.pricedItemCount, 2)
        XCTAssertEqual(snapshot.totalPurchaseValue, 598)
        XCTAssertEqual(snapshot.averagePurchaseValue, 299)
        XCTAssertEqual(snapshot.completeDetailCount, 2)
        XCTAssertEqual(snapshot.topSeasonText, "四季")
        XCTAssertEqual(snapshot.topBrandText, "Daily")
        XCTAssertEqual(Set(snapshot.colorRows.map(\.title)), ["奶油白", "暖白", "浅蓝"])
        XCTAssertEqual(Set(snapshot.brandRows.map(\.title)), ["Daily", "Walk Lab"])
        XCTAssertEqual(Set(snapshot.purchaseChannelRows.map(\.title)), ["品牌官网", "线下门店"])
    }

    private func makeItem(
        name: String,
        category: String,
        colorName: String,
        season: String,
        brand: String,
        size: String,
        purchasePrice: Double?,
        purchaseChannel: String,
        imageData: Data?,
        styleTagsText: String
    ) -> WardrobeItem {
        WardrobeItem(
            name: name,
            category: category,
            colorName: colorName,
            season: season,
            imageSymbol: "shirt.fill",
            imageData: imageData,
            styleTagsText: styleTagsText,
            brand: brand,
            size: size,
            purchasePrice: purchasePrice,
            purchaseChannel: purchaseChannel,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
