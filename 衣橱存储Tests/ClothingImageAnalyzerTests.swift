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
            .shoes
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
            .bottom
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "cotton shirt", confidence: 0.62)
            ])?.category,
            .top
        )
        XCTAssertEqual(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "wool coat", confidence: 0.58)
            ])?.category,
            .outerwear
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
    }

    func testCategorySuggestionPrefersSpecificLabelOverGenericClothing() throws {
        let suggestion = try XCTUnwrap(
            ClothingImageAnalyzer.categorySuggestion(from: [
                .init(identifier: "clothing", confidence: 0.92),
                .init(identifier: "leather backpack", confidence: 0.48)
            ])
        )

        XCTAssertEqual(suggestion.category, .bag)
        XCTAssertEqual(suggestion.matchedLabel, "leather backpack")
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
    #endif
}
