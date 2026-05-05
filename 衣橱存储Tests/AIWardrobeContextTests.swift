import XCTest
@testable import 衣橱存储

@MainActor
final class AIWardrobeContextTests: XCTestCase {

    // MARK: - Slot routing

    func testItemsAreGroupedIntoCorrectSlots() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let bottom = makeItem(name: "牛仔裤", category: "下装")
        let outerwear = makeItem(name: "风衣", category: "外套")
        let shoes = makeItem(name: "白鞋", category: "鞋履")

        let context = AIWardrobeContextBuilder.build(
            userPrompt: "今天去咖啡馆",
            weather: nil,
            items: [top, bottom, outerwear, shoes]
        )

        XCTAssertEqual(context.candidatesBySlot["top"]?.count, 1)
        XCTAssertEqual(context.candidatesBySlot["bottom"]?.count, 1)
        XCTAssertEqual(context.candidatesBySlot["outerwear"]?.count, 1)
        XCTAssertEqual(context.candidatesBySlot["shoes"]?.count, 1)
        XCTAssertEqual(context.candidatesBySlot["top"]?.first?.id, top.id)
    }

    // MARK: - Pre-filter caps

    func testEachSlotIsCappedAtMaxPerSlot() {
        let manyTops = (0..<20).map { idx in
            makeItem(name: "上装\(idx)", category: "上装")
        }

        let context = AIWardrobeContextBuilder.build(
            userPrompt: "随便",
            weather: nil,
            items: manyTops
        )

        let topCount = context.candidatesBySlot["top"]?.count ?? 0
        XCTAssertLessThanOrEqual(topCount, AIWardrobeContextBuilder.maxPerSlot)
    }

    func testTotalCandidatesAreCappedGlobally() {
        // Build a wardrobe with 12 tops + 12 bottoms + 12 shoes + 12 outerwear
        // (raw 48 items). After per-slot cap (8 each = 32) we still exceed
        // maxTotal = 35, so the global trim must engage.
        let raw = (0..<12).flatMap { idx in
            [
                makeItem(name: "上装\(idx)", category: "上装"),
                makeItem(name: "下装\(idx)", category: "下装"),
                makeItem(name: "外套\(idx)", category: "外套"),
                makeItem(name: "鞋\(idx)", category: "鞋履")
            ]
        }

        let context = AIWardrobeContextBuilder.build(
            userPrompt: "出差",
            weather: nil,
            items: raw
        )

        let total = context.candidatesBySlot.values.reduce(0) { $0 + $1.count }
        XCTAssertLessThanOrEqual(total, AIWardrobeContextBuilder.maxTotal + 4)
        // Top/bottom must keep at least 4 even after trimming.
        XCTAssertGreaterThanOrEqual(context.candidatesBySlot["top"]?.count ?? 0, 4)
        XCTAssertGreaterThanOrEqual(context.candidatesBySlot["bottom"]?.count ?? 0, 4)
    }

    // MARK: - Favorite ranking

    func testFavoritedItemsRankAheadOfNonFavorites() {
        let older = makeItem(
            name: "旧款上衣",
            category: "上装",
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let newer = makeItem(
            name: "新款上衣",
            category: "上装",
            createdAt: Date(timeIntervalSince1970: 2_000_000)
        )

        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [newer, older]
        )

        XCTAssertEqual(context.candidatesBySlot["top"]?.first?.id, older.id)
    }

    // MARK: - Prompt composition

    func testPromptContainsUserIntentAndAllSlotHeaders() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let bottom = makeItem(name: "黑色长裤", category: "下装")

        let context = AIWardrobeContextBuilder.build(
            userPrompt: "今天去面试",
            weather: nil,
            items: [top, bottom]
        )

        XCTAssertTrue(context.promptText.contains("今天去面试"))
        XCTAssertTrue(context.promptText.contains("# 上装 top"))
        XCTAssertTrue(context.promptText.contains("# 下装 bottom"))
        XCTAssertTrue(context.promptText.contains(top.id.uuidString.lowercased()))
        XCTAssertTrue(context.promptText.contains(bottom.id.uuidString.lowercased()))
    }

    func testPromptFallsBackWhenUserPromptIsEmpty() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top]
        )
        XCTAssertTrue(context.promptText.contains("今日合适的搭配"))
    }

    // MARK: - Lookup helpers

    func testItemMatchingResolvesByLowercaseUUID() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top]
        )
        XCTAssertEqual(context.item(matching: top.id.uuidString)?.id, top.id)
        XCTAssertEqual(context.item(matching: top.id.uuidString.uppercased())?.id, top.id)
        XCTAssertNil(context.item(matching: "not-a-uuid"))
        XCTAssertNil(context.item(matching: UUID().uuidString))
    }

    func testIsCandidateRejectsCrossSlotItems() {
        let shoes = makeItem(name: "白鞋", category: "鞋履")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [shoes]
        )
        XCTAssertTrue(context.isCandidate(shoes, forSlotKey: "shoes"))
        XCTAssertFalse(context.isCandidate(shoes, forSlotKey: "top"))
    }

    // MARK: - Helper

    private func makeItem(
        name: String,
        category: String,
        isFavorite: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> WardrobeItem {
        WardrobeItem(
            id: UUID(),
            name: name,
            category: category,
            colorName: "白色",
            season: "四季",
            imageSymbol: "tshirt.fill",
            styleTagsText: "通勤, 简洁",
            isFavorite: isFavorite,
            createdAt: createdAt
        )
    }
}
