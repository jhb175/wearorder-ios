import XCTest
@testable import 衣橱存储

final class WardrobeImageFileStoreTests: XCTestCase {
    private var rootURL: URL!
    private var store: WardrobeImageFileStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WardrobeImageFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = WardrobeImageFileStore(rootDirectoryURL: rootURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
        store = nil
        rootURL = nil
        try super.tearDownWithError()
    }

    func testStoreImageSetWritesBothFilesAndReturnsExpectedNames() throws {
        let itemID = UUID()
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let thumbnailData = Data([0xCA, 0xFE])

        let files = try store.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: thumbnailData
        )

        XCTAssertEqual(files.imageFileName, "\(itemID.uuidString)-display.jpg")
        XCTAssertEqual(files.thumbnailFileName, "\(itemID.uuidString)-thumb.jpg")
        XCTAssertEqual(store.data(for: files.imageFileName), imageData)
        XCTAssertEqual(store.data(for: files.thumbnailFileName), thumbnailData)
    }

    func testStoreImageSetWithFileNameTagProducesUniqueNames() throws {
        let itemID = UUID()
        let imageData = Data([0x01, 0x02, 0x03])
        let thumbnailData = Data([0xAA])

        let firstSet = try store.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: thumbnailData
        )
        let taggedSet = try store.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: thumbnailData,
            fileNameTag: "v2"
        )

        XCTAssertNotEqual(firstSet.imageFileName, taggedSet.imageFileName)
        XCTAssertTrue(taggedSet.imageFileName.contains("-v2-"))
        XCTAssertTrue(taggedSet.thumbnailFileName.contains("-v2-"))
        XCTAssertNotNil(store.data(for: firstSet.imageFileName))
        XCTAssertNotNil(store.data(for: taggedSet.imageFileName))
    }

    func testStoreImageSetReplacingDifferentlyTaggedFilesDeletesOld() throws {
        let itemID = UUID()
        let imageData = Data([0x10, 0x20, 0x30])
        let thumbnailData = Data([0x99])

        let oldSet = try store.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: thumbnailData,
            fileNameTag: "old"
        )
        let newSet = try store.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: thumbnailData,
            replacing: oldSet,
            fileNameTag: "new"
        )

        XCTAssertNil(store.data(for: oldSet.imageFileName))
        XCTAssertNil(store.data(for: oldSet.thumbnailFileName))
        XCTAssertNotNil(store.data(for: newSet.imageFileName))
        XCTAssertNotNil(store.data(for: newSet.thumbnailFileName))
    }

    func testStoreImageSetReplacingSameNameOverwritesAndKeepsFile() throws {
        let itemID = UUID()
        let firstImage = Data([0x01, 0x02])
        let firstThumb = Data([0xA1])
        let secondImage = Data([0x03, 0x04, 0x05])
        let secondThumb = Data([0xB2])

        let firstSet = try store.storeImageSet(
            itemID: itemID,
            imageData: firstImage,
            thumbnailData: firstThumb
        )
        let secondSet = try store.storeImageSet(
            itemID: itemID,
            imageData: secondImage,
            thumbnailData: secondThumb,
            replacing: firstSet
        )

        XCTAssertEqual(firstSet.imageFileName, secondSet.imageFileName)
        XCTAssertEqual(store.data(for: secondSet.imageFileName), secondImage)
        XCTAssertEqual(store.data(for: secondSet.thumbnailFileName), secondThumb)
    }

    func testRemoveDeletesPersistedFile() throws {
        let itemID = UUID()
        let files = try store.storeImageSet(
            itemID: itemID,
            imageData: Data([0xFE, 0xED]),
            thumbnailData: Data([0xBE, 0xEF])
        )

        store.remove(fileName: files.imageFileName)

        XCTAssertNil(store.data(for: files.imageFileName))
        XCTAssertNotNil(store.data(for: files.thumbnailFileName))
    }

    func testRemoveTreatsEmptyAndNilNamesAsNoOp() {
        store.remove(fileName: nil)
        store.remove(fileName: "")
        XCTAssertTrue(true, "remove should silently ignore missing identifiers")
    }

    func testByteCountMatchesWrittenSize() throws {
        let payload = Data(repeating: 0x42, count: 1024)
        let files = try store.storeImageSet(
            itemID: UUID(),
            imageData: payload,
            thumbnailData: Data([0x01])
        )

        XCTAssertEqual(store.byteCount(for: files.imageFileName), payload.count)
        XCTAssertEqual(store.byteCount(for: files.thumbnailFileName), 1)
    }

    func testUrlAndDataAreNilForMissingNames() {
        XCTAssertNil(store.url(for: nil))
        XCTAssertNil(store.url(for: ""))
        XCTAssertNil(store.data(for: nil))
        XCTAssertNil(store.data(for: "non-existent-file.jpg"))
        XCTAssertNil(store.byteCount(for: "non-existent-file.jpg"))
    }
}
