import XCTest
@testable import 衣橱存储

final class WeatherForecastServiceTests: XCTestCase {
    func testKnownChineseCityResolvesFromFallbackDirectory() {
        let city = WeatherCityFallbackDirectory.city(matching: "上海")

        XCTAssertEqual(city?.displayName, "上海")
        XCTAssertEqual(city?.latitude ?? 0, 31.2304, accuracy: 0.0001)
        XCTAssertEqual(city?.longitude ?? 0, 121.4737, accuracy: 0.0001)
    }

    func testKnownCityHandlesSuffixAndEnglishAlias() {
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "上海市")?.displayName, "上海")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "Shanghai")?.displayName, "上海")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "深圳 南山区")?.displayName, "深圳")
    }

    func testUnknownCityFallsThroughToSystemGeocoder() {
        XCTAssertNil(WeatherCityFallbackDirectory.city(matching: "一个不存在的城市名称"))
    }
}
