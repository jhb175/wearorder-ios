import XCTest
@testable import 衣橱存储

@MainActor
final class ClosetOrganizationSnapshotTests: XCTestCase {
    func testEmptyClosetCreatesFirstItemTask() {
        let snapshot = ClosetOrganizationSnapshot.make(items: [], outfits: [])

        XCTAssertEqual(snapshot.itemCount, 0)
        XCTAssertEqual(snapshot.coverageText, "0/8")
        XCTAssertEqual(snapshot.tasks.map(\.kind), [.addClothing])
    }

    func testSnapshotTracksCoverageAndActionableTasks() {
        let top = makeItem(name: "白衬衫", category: "上装", imageData: Data([1]), styleTagsText: "通勤")
        let bottom = makeItem(name: "牛仔裤", category: "下装", imageData: nil, styleTagsText: "")
        let bag = makeItem(name: "托特包", category: "包袋", imageData: nil, styleTagsText: "休闲", isFavorite: true)
        let outfit = OOTDOutfit(title: "通勤", notes: "", topItem: top, bottomItem: bottom)

        let snapshot = ClosetOrganizationSnapshot.make(
            items: [top, bottom, bag],
            outfits: [outfit]
        )

        XCTAssertEqual(snapshot.itemCount, 3)
        XCTAssertEqual(snapshot.coveredCategoryCount, 3)
        XCTAssertEqual(snapshot.missingCoreCategories, ["鞋履"])
        XCTAssertEqual(snapshot.unusedItemCount, 1)
        XCTAssertEqual(snapshot.missingImageCount, 2)
        XCTAssertEqual(snapshot.detailGapCount, 2)
        XCTAssertEqual(snapshot.favoriteCount, 1)
        XCTAssertTrue(snapshot.tasks.map(\.kind).contains(.showNeedsDetails))
        XCTAssertTrue(snapshot.tasks.map(\.kind).contains(.showUnused))
    }

    private func makeItem(
        name: String,
        category: String,
        imageData: Data?,
        styleTagsText: String,
        isFavorite: Bool = false
    ) -> WardrobeItem {
        WardrobeItem(
            name: name,
            category: category,
            colorName: "奶油白",
            season: "四季",
            imageSymbol: "shirt.fill",
            imageData: imageData,
            styleTagsText: styleTagsText,
            brand: "基础品牌",
            size: "M",
            isFavorite: isFavorite,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
