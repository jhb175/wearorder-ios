import XCTest
@testable import 衣橱存储

@MainActor
final class AIOutfitValidatorTests: XCTestCase {

    // MARK: - Happy path

    func testValidateAcceptsTopAndBottomFromCandidatePool() throws {
        let top = makeItem(name: "白衬衫", category: "上装")
        let bottom = makeItem(name: "黑色长裤", category: "下装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top, bottom]
        )

        let resolved = try AIOutfitValidator.validate(
            title: "  通勤简洁  ",
            reason: "  上下经典配色，简洁通勤。  ",
            slotIDs: [
                "top": top.id.uuidString,
                "bottom": bottom.id.uuidString
            ],
            context: context
        )

        XCTAssertEqual(resolved.title, "通勤简洁")
        XCTAssertEqual(resolved.reason, "上下经典配色，简洁通勤。")
        XCTAssertEqual(resolved.topItem?.id, top.id)
        XCTAssertEqual(resolved.bottomItem?.id, bottom.id)
        XCTAssertNil(resolved.shoesItem)
    }

    func testValidateAcceptsOnlyBottomWhenTopEmpty() throws {
        // 连衣裙 (one-piece) is a bottom-slot candidate per the model.
        // The validator must accept an outfit that fills only the bottom
        // slot — outfits anchored on a one-piece dress are valid.
        let dress = makeItem(name: "连衣裙", category: "连衣裙")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [dress]
        )

        let resolved = try AIOutfitValidator.validate(
            title: "夏日连衣裙",
            reason: "一件式简洁。",
            slotIDs: [
                "top": nil,
                "bottom": dress.id.uuidString
            ],
            context: context
        )
        XCTAssertNil(resolved.topItem)
        XCTAssertEqual(resolved.bottomItem?.id, dress.id)
    }

    // MARK: - Hallucinated IDs

    func testValidateRejectsUnknownIDs() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top]
        )

        let bogus = UUID().uuidString
        XCTAssertThrowsError(
            try AIOutfitValidator.validate(
                title: "x",
                reason: "y",
                slotIDs: ["top": bogus],
                context: context
            )
        ) { error in
            guard case AIOutfitValidator.ValidationError.unknownItemID(let slot, _) = error else {
                return XCTFail("expected unknownItemID, got \(error)")
            }
            XCTAssertEqual(slot, "top")
        }
    }

    func testValidateRejectsNonUUIDStrings() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top]
        )

        XCTAssertThrowsError(
            try AIOutfitValidator.validate(
                title: "x",
                reason: "y",
                slotIDs: ["top": "not-a-uuid"],
                context: context
            )
        )
    }

    // MARK: - Slot mismatch

    func testValidateRejectsSlotCategoryMismatch() {
        let shoes = makeItem(name: "白鞋", category: "鞋履")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [shoes]
        )

        // Model invents: "put the shoes ID into the top slot."
        XCTAssertThrowsError(
            try AIOutfitValidator.validate(
                title: "x",
                reason: "y",
                slotIDs: [
                    "top": shoes.id.uuidString,
                    "shoes": shoes.id.uuidString
                ],
                context: context
            )
        ) { error in
            guard case AIOutfitValidator.ValidationError.slotCategoryMismatch(let slot, _) = error else {
                return XCTFail("expected slotCategoryMismatch, got \(error)")
            }
            XCTAssertEqual(slot, "top")
        }
    }

    // MARK: - Empty outfit

    func testValidateRejectsOutfitWithNeitherTopNorBottom() {
        let shoes = makeItem(name: "白鞋", category: "鞋履")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [shoes]
        )

        XCTAssertThrowsError(
            try AIOutfitValidator.validate(
                title: "x",
                reason: "y",
                slotIDs: ["shoes": shoes.id.uuidString],
                context: context
            )
        ) { error in
            guard case AIOutfitValidator.ValidationError.missingRequiredSlot = error else {
                return XCTFail("expected missingRequiredSlot, got \(error)")
            }
        }
    }

    func testValidateRejectsEntirelyEmptyOutput() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let context = AIWardrobeContextBuilder.build(
            userPrompt: "",
            weather: nil,
            items: [top]
        )

        XCTAssertThrowsError(
            try AIOutfitValidator.validate(
                title: "x",
                reason: "y",
                slotIDs: [:],
                context: context
            )
        )
    }

    // MARK: - Helper

    private func makeItem(name: String, category: String) -> WardrobeItem {
        WardrobeItem(
            id: UUID(),
            name: name,
            category: category,
            colorName: "白色",
            season: "四季",
            imageSymbol: "tshirt.fill",
            styleTagsText: "通勤"
        )
    }
}
