import XCTest
@testable import 衣橱存储

#if canImport(UIKit)
import UIKit
#endif

final class ClothingImageAnalyzerTests: XCTestCase {
    func testClosestPaletteColorNameMapsNeutrals() {
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.03, green: 0.03, blue: 0.04), "曜石黑")
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.34, green: 0.35, blue: 0.37), "炭灰")
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.96, green: 0.95, blue: 0.90), "暖白")
    }

    func testClosestPaletteColorNameMapsHueFamilies() {
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.08, green: 0.20, blue: 0.52), "海军蓝")
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.46, green: 0.62, blue: 0.82), "雾蓝")
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.16, green: 0.36, blue: 0.20), "森林绿")
        XCTAssertEqual(ClothingImageAnalyzer.closestPaletteColorName(red: 0.70, green: 0.42, blue: 0.22), "焦糖棕")
    }

    func testCategorySuggestionMapsVisionLabelsToWardrobeCategories() {
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "running shoe, sneaker", confidence: 0.86)
            ])?.category,
            .sneakers
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "handbag, purse", confidence: 0.74)
            ])?.category,
            .bag
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "blue denim jeans", confidence: 0.68)
            ])?.category,
            .jeans
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "cotton shirt", confidence: 0.62)
            ])?.category,
            .shirt
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "white summer dress", confidence: 0.62)
            ])?.category,
            .dress
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "cocktail dress", confidence: 0.54)
            ])?.category,
            .dress
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "pleated skirt", confidence: 0.62)
            ])?.category,
            .pleatedSkirt
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "miniskirt", confidence: 0.62)
            ])?.category,
            .miniSkirt
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "wide leg pants", confidence: 0.56)
            ])?.category,
            .bottom
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "wool coat", confidence: 0.58)
            ])?.category,
            .coat
        )
    }

    func testCategorySuggestionMapsCustomModelLabelsToWardrobeCategories() {
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "top", confidence: 0.89)
            ])?.category,
            .top
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "outerwear", confidence: 0.88)
            ])?.category,
            .outerwear
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "bottom", confidence: 0.87)
            ])?.category,
            .bottom
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "accessory", confidence: 0.86)
            ])?.category,
            .accessory
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "帽子", confidence: 0.85)
            ])?.category,
            .hat
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "pet clothing", confidence: 0.85)
            ])?.category,
            .pet
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "tote bag", confidence: 0.82)
            ])?.category,
            .toteBag
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "sunglasses", confidence: 0.81)
            ])?.category,
            .eyewear
        )
    }

    func testCategorySuggestionPrefersSpecificLabelOverGenericClothing() throws {
        let suggestion = try XCTUnwrap(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "clothing", confidence: 0.92),
                .init(identifier: "leather backpack", confidence: 0.48)
            ])
        )

        XCTAssertEqual(suggestion.category, .backpack)
        XCTAssertEqual(suggestion.matchedLabel, "leather backpack")
    }

    func testCategorySuggestionDoesNotTreatJkUniformTopAsAccessory() throws {
        let suggestion = try XCTUnwrap(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "bow tie", confidence: 0.86),
                .init(identifier: "sailor uniform shirt", confidence: 0.58)
            ])
        )

        XCTAssertEqual(suggestion.category, .top)
    }

    func testCategorySuggestionMapsOnePieceAndUniformLabels() {
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "jumpsuit", confidence: 0.72)
            ])?.category,
            .jumpsuit
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "sailor collar blouse", confidence: 0.61),
                .init(identifier: "necklace", confidence: 0.44)
            ])?.category,
            .top
        )
    }

    func testStrongNameHintsCanRepairObviousSlotMismatches() {
        XCTAssertEqual(WardrobeCategory.strongNameHint(for: "裤子 2"), .bottom)
        XCTAssertTrue(WardrobeCategory.shouldApplyStrongNameHint(.bottom, over: WardrobeCategory.shoes.rawValue))

        XCTAssertEqual(WardrobeCategory.strongNameHint(for: "连衣裙 白色"), .dress)
        XCTAssertTrue(WardrobeCategory.shouldApplyStrongNameHint(.dress, over: WardrobeCategory.top.rawValue))

        XCTAssertEqual(WardrobeCategory.strongNameHint(for: "jk 上衣"), .top)
        XCTAssertTrue(WardrobeCategory.shouldApplyStrongNameHint(.top, over: WardrobeCategory.accessory.rawValue))

        XCTAssertEqual(WardrobeCategory.strongNameHint(for: "白色运动鞋"), .sneakers)
        XCTAssertTrue(WardrobeCategory.shouldApplyStrongNameHint(.sneakers, over: WardrobeCategory.bottom.rawValue))
    }

    func testCategorySuggestionReturnsNilForUnrelatedLabels() {
        let suggestion = ClothingImageAnalyzer.categorySuggestion(from: [
            .init(identifier: "coffee cup", confidence: 0.91),
            .init(identifier: "table lamp", confidence: 0.62)
        ])

        XCTAssertNil(suggestion)
    }

    #if canImport(UIKit)
    @MainActor
    func testDominantColorIgnoresWhiteBackground() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
            UIColor(red: 0.08, green: 0.20, blue: 0.52, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 82, y: 70, width: 156, height: 180))
        }
        let data = try XCTUnwrap(image.pngData())
        let suggestion = try XCTUnwrap(ClothingImageAnalyzer.suggestDominantColor(from: data))

        XCTAssertEqual(suggestion.colorName, "海军蓝")
        XCTAssertGreaterThan(suggestion.confidence, 0.35)
    }

    @MainActor
    func testVisualSilhouetteCanSuggestDress() throws {
        let data = try XCTUnwrap(silhouetteImageData { context in
            UIColor.black.setFill()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 140, y: 66))
            path.addLine(to: CGPoint(x: 180, y: 66))
            path.addLine(to: CGPoint(x: 235, y: 252))
            path.addLine(to: CGPoint(x: 84, y: 252))
            path.close()
            path.fill()
        })

        let suggestion = try XCTUnwrap(ClothingImageAnalyzer.suggestCategory(from: data))
        XCTAssertEqual(suggestion.category, .dress)
    }

    @MainActor
    func testVisualSilhouetteCanSuggestBottom() throws {
        let data = try XCTUnwrap(silhouetteImageData { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 112, y: 54, width: 38, height: 226))
            context.cgContext.fill(CGRect(x: 170, y: 54, width: 38, height: 226))
            context.cgContext.fill(CGRect(x: 112, y: 54, width: 96, height: 42))
        })

        let suggestion = try XCTUnwrap(ClothingImageAnalyzer.suggestCategory(from: data))
        XCTAssertEqual(suggestion.category, .bottom)
    }

    @MainActor
    func testVisualSilhouetteCanSuggestShoes() throws {
        let data = try XCTUnwrap(silhouetteImageData { context in
            UIColor.black.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 34, y: 122, width: 118, height: 48))
            context.cgContext.fillEllipse(in: CGRect(x: 168, y: 122, width: 118, height: 48))
        })

        let suggestion = try XCTUnwrap(ClothingImageAnalyzer.suggestCategory(from: data))
        XCTAssertEqual(suggestion.category, .shoes)
    }

    private func silhouetteImageData(draw: (UIGraphicsImageRendererContext) -> Void) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
            draw(context)
        }
        return image.pngData()
    }
    #endif
}
