import SwiftData
import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeInlineImageMigratorTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([WardrobeItem.self, OOTDOutfit.self, OutfitPlan.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func testMigrateSkipsItemsAlreadyOnFileStore() {
        let item = makeItem(imageData: Data([0x01]), imageFileName: "existing.jpg")

        let result = WardrobeInlineImageMigrator.migrate(items: [item]) { _ in
            XCTFail("should not migrate items already backed by a file")
        }

        XCTAssertEqual(result, WardrobeInlineImageMigrationResult(
            scannedItemCount: 0, migratedItemCount: 0, failedItemCount: 0
        ))
        XCTAssertNotNil(item.imageData)
        XCTAssertEqual(item.imageFileName, "existing.jpg")
    }

    func testMigrateSkipsItemsWithoutInlineData() {
        let item = makeItem(imageData: nil, imageFileName: nil)

        let result = WardrobeInlineImageMigrator.migrate(items: [item]) { _ in
            XCTFail("should not migrate items with no inline data")
        }

        XCTAssertEqual(result, WardrobeInlineImageMigrationResult(
            scannedItemCount: 0, migratedItemCount: 0, failedItemCount: 0
        ))
    }

    func testMigrateAppliesClosureToInlineOnlyItems() {
        let stale = makeItem(imageData: Data([0xAB]), imageFileName: nil)
        let mixed = makeItem(imageData: Data([0xCD]), imageFileName: "already.jpg")
        let absent = makeItem(imageData: nil, imageFileName: nil)

        var visited: [UUID] = []
        let result = WardrobeInlineImageMigrator.migrate(items: [stale, mixed, absent]) { item in
            visited.append(item.id)
            // Simulate the file-store side effect without touching disk.
            item.imageFileName = "\(item.id.uuidString)-display.jpg"
            item.thumbnailFileName = "\(item.id.uuidString)-thumb.jpg"
            item.imageData = nil
            item.thumbnailData = nil
        }

        XCTAssertEqual(visited, [stale.id])
        XCTAssertEqual(result.scannedItemCount, 1)
        XCTAssertEqual(result.migratedItemCount, 1)
        XCTAssertEqual(result.failedItemCount, 0)
        XCTAssertNil(stale.imageData)
        XCTAssertEqual(stale.imageFileName, "\(stale.id.uuidString)-display.jpg")
    }

    func testMigrateContinuesAfterIndividualFailure() {
        let firstFail = makeItem(imageData: Data([0x01]), imageFileName: nil)
        let secondOk = makeItem(imageData: Data([0x02]), imageFileName: nil)

        let result = WardrobeInlineImageMigrator.migrate(items: [firstFail, secondOk]) { item in
            if item.id == firstFail.id {
                throw NSError(domain: "test", code: 1)
            }
            item.imageFileName = "ok.jpg"
            item.imageData = nil
        }

        XCTAssertEqual(result.scannedItemCount, 2)
        XCTAssertEqual(result.migratedItemCount, 1)
        XCTAssertEqual(result.failedItemCount, 1)
        XCTAssertFalse(result.isFullySuccessful)
        XCTAssertNotNil(firstFail.imageData, "failed item should keep its inline data for next attempt")
        XCTAssertNil(secondOk.imageData)
    }

    func testResultFlags() {
        let success = WardrobeInlineImageMigrationResult(
            scannedItemCount: 2, migratedItemCount: 2, failedItemCount: 0
        )
        XCTAssertTrue(success.hasMigratedAnything)
        XCTAssertTrue(success.isFullySuccessful)

        let nothing = WardrobeInlineImageMigrationResult(
            scannedItemCount: 0, migratedItemCount: 0, failedItemCount: 0
        )
        XCTAssertFalse(nothing.hasMigratedAnything)
        XCTAssertTrue(nothing.isFullySuccessful)

        let partial = WardrobeInlineImageMigrationResult(
            scannedItemCount: 3, migratedItemCount: 2, failedItemCount: 1
        )
        XCTAssertTrue(partial.hasMigratedAnything)
        XCTAssertFalse(partial.isFullySuccessful)
    }

    // MARK: - Helpers

    private func makeItem(
        imageData: Data?,
        imageFileName: String?
    ) -> WardrobeItem {
        let context = container.mainContext
        let item = WardrobeItem(
            name: "测试单品",
            category: "上装",
            colorName: "白色",
            season: "四季",
            imageSymbol: "tshirt.fill",
            imageData: imageData,
            thumbnailData: imageData,
            imageFileName: imageFileName,
            thumbnailFileName: imageFileName.map { _ in "thumb.jpg" }
        )
        context.insert(item)
        return item
    }
}
