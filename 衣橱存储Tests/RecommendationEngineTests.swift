import XCTest
@testable import 衣橱存储

@MainActor
final class RecommendationEngineTests: XCTestCase {
    func testSnowForecastMapsToSnowRecommendationWeather() {
        XCTAssertEqual(HomeDashboardViewModel.WeatherKind.snow.recommendationWeather, .snow)
    }

    func testRainyHotWeatherDoesNotFilterSpringSummerItems() {
        let top = makeItem(
            id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            name: "薄荷绿短袖",
            category: "上装",
            colorName: "薄荷绿",
            season: "春夏"
        )
        let bottom = makeItem(
            id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            name: "浅蓝半裙",
            category: "下装",
            colorName: "浅蓝",
            season: "春夏"
        )
        let shoes = makeItem(
            id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
            name: "白色运动鞋",
            category: "鞋履",
            colorName: "暖白",
            season: "四季"
        )

        let response = RecommendationEngine.generateRecommendations(
            from: [top, bottom, shoes],
            input: RecommendationInput(
                weather: .drizzle,
                temperatureCelsius: 30,
                occasion: .casual,
                style: .comfortable
            )
        )

        XCTAssertNil(response.emptyStateMessage)
        XCTAssertFalse(response.results.isEmpty)
        XCTAssertEqual(response.results.first?.topItem.id, top.id)
        XCTAssertEqual(response.results.first?.bottomItem.id, bottom.id)
        XCTAssertTrue(response.results.first?.scoreHighlights.contains("适合偏热天气") == true)
    }

    func testMissingBottomReturnsUsefulEmptyState() {
        let top = makeItem(
            id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
            name: "白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季"
        )

        let response = RecommendationEngine.generateRecommendations(
            from: [top],
            input: RecommendationInput(
                weather: .sunny,
                temperatureCelsius: 24,
                occasion: .commute,
                style: .minimal
            )
        )

        XCTAssertTrue(response.results.isEmpty)
        XCTAssertEqual(response.emptyStateMessage, "当前衣橱缺少可用下装，先补录一些下装或裙装后再试。")
    }

    func testRecommendationIncludesExplanationsAndWardrobeGaps() {
        let top = makeItem(
            id: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
            name: "白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季"
        )
        let bottom = makeItem(
            id: "ffffffff-ffff-ffff-ffff-ffffffffffff",
            name: "西装裤",
            category: "下装",
            colorName: "炭灰",
            season: "四季"
        )
        let shoes = makeItem(
            id: "99999999-9999-9999-9999-999999999999",
            name: "乐福鞋",
            category: "鞋履",
            colorName: "曜石黑",
            season: "四季"
        )

        let response = RecommendationEngine.generateRecommendations(
            from: [top, bottom, shoes],
            input: RecommendationInput(
                weather: .drizzle,
                temperatureCelsius: 16,
                occasion: .commute,
                style: .minimal
            )
        )

        XCTAssertNil(response.emptyStateMessage)
        let result = try! XCTUnwrap(response.results.first)
        let insightIDs = Set(result.insights.map(\.id))
        XCTAssertTrue(insightIDs.contains("weather"))
        XCTAssertTrue(insightIDs.contains("temperature"))
        XCTAssertTrue(insightIDs.contains("occasion"))
        XCTAssertTrue(response.wardrobeGaps.map(\.id).contains("missing-bag"))
        XCTAssertTrue(response.wardrobeGaps.map(\.id).contains("missing-outerwear"))
    }

    func testRecommendationSuggestsReplacementItems() {
        let top = makeItem(
            id: "12121212-1212-1212-1212-121212121212",
            name: "奶油白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季"
        )
        let alternateTop = makeItem(
            id: "23232323-2323-2323-2323-232323232323",
            name: "浅蓝针织衫",
            category: "上装",
            colorName: "浅蓝",
            season: "春秋"
        )
        let bottom = makeItem(
            id: "34343434-3434-3434-3434-343434343434",
            name: "炭灰西装裤",
            category: "下装",
            colorName: "炭灰",
            season: "四季"
        )
        let alternateBottom = makeItem(
            id: "45454545-4545-4545-4545-454545454545",
            name: "深蓝牛仔裤",
            category: "下装",
            colorName: "海军蓝",
            season: "四季"
        )
        let shoes = makeItem(
            id: "56565656-5656-5656-5656-565656565656",
            name: "黑色乐福鞋",
            category: "鞋履",
            colorName: "曜石黑",
            season: "四季"
        )

        let response = RecommendationEngine.generateRecommendations(
            from: [top, alternateTop, bottom, alternateBottom, shoes],
            input: RecommendationInput(
                weather: .partlyCloudy,
                temperatureCelsius: 22,
                occasion: .commute,
                style: .minimal
            )
        )

        let result = try! XCTUnwrap(response.results.first)
        let selectedIDs = Set(result.orderedItems.map(\.id))
        XCTAssertFalse(result.replacements.isEmpty)
        XCTAssertFalse(result.replacements.contains { selectedIDs.contains($0.replacementItem.id) })
        XCTAssertTrue(result.replacements.contains { $0.slotTitle.contains("替换") })
    }

    func testRecommendationAddsUpgradeTipsForMissingOptionalItems() {
        let top = makeItem(
            id: "67676767-6767-6767-6767-676767676767",
            name: "白衬衫",
            category: "上装",
            colorName: "奶油白",
            season: "四季"
        )
        let bottom = makeItem(
            id: "78787878-7878-7878-7878-787878787878",
            name: "西装裤",
            category: "下装",
            colorName: "炭灰",
            season: "四季"
        )

        let response = RecommendationEngine.generateRecommendations(
            from: [top, bottom],
            input: RecommendationInput(
                weather: .sunny,
                temperatureCelsius: 24,
                occasion: .commute,
                style: .minimal
            )
        )

        let result = try! XCTUnwrap(response.results.first)
        let tipIDs = Set(result.upgradeTips.map(\.id))
        XCTAssertTrue(tipIDs.contains("add-shoes"))
        XCTAssertTrue(tipIDs.contains("add-bag"))
    }

    private func makeItem(
        id: String,
        name: String,
        category: String,
        colorName: String,
        season: String
    ) -> WardrobeItem {
        WardrobeItem(
            id: UUID(uuidString: id)!,
            name: name,
            category: category,
            colorName: colorName,
            season: season,
            imageSymbol: "tshirt.fill",
            styleTagsText: "休闲, 舒适, 通勤, 简洁",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
