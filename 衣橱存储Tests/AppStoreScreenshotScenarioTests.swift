import XCTest
@testable import 衣橱存储

final class AppStoreScreenshotScenarioTests: XCTestCase {
    func testScenarioSetCoversCommercialScreenshots() {
        XCTAssertEqual(AppStoreScreenshotScenario.allCases.count, 5)
        XCTAssertEqual(AppStoreScreenshotScenario.recommendedDevice, "6.9-inch iPhone")

        let previewNames = Set(AppStoreScreenshotScenario.allCases.map(\.previewName))
        XCTAssertEqual(previewNames.count, AppStoreScreenshotScenario.allCases.count)

        let captions = AppStoreScreenshotScenario.allCases.map(\.storeCaption)
        XCTAssertTrue(captions.allSatisfy { !$0.isEmpty })
    }

    func testScenarioSurfacesCoverCoreProductAreas() {
        var hasHome = false
        var hasWardrobe = false
        var hasRecommendation = false
        var hasPlans = false
        var hasSettings = false

        for scenario in AppStoreScreenshotScenario.allCases {
            switch scenario.surface {
            case .mainTab(.home):
                hasHome = true
            case .mainTab(.wardrobe):
                hasWardrobe = true
            case .mainTab(.settings):
                hasSettings = true
            case .mainTab(.ootd):
                break
            case .ootdSection(.plans):
                hasPlans = true
            case .ootdSection(.today), .ootdSection(.library):
                break
            case .recommendationResult:
                hasRecommendation = true
            }
        }

        XCTAssertTrue(hasHome)
        XCTAssertTrue(hasWardrobe)
        XCTAssertTrue(hasRecommendation)
        XCTAssertTrue(hasPlans)
        XCTAssertTrue(hasSettings)
    }

    func testScenarioPreviewNamesAreOrderedForXcodePicker() {
        XCTAssertEqual(
            AppStoreScreenshotScenario.allCases.map(\.previewName),
            [
                "App Store 1 · 首页总览",
                "App Store 2 · 数字衣橱",
                "App Store 3 · 智能推荐",
                "App Store 4 · 计划提醒",
                "App Store 5 · 隐私支持"
            ]
        )
    }
}
