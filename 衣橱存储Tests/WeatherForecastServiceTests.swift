import CoreLocation
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

    func testGlobalCityFallbackDirectoryCoversMajorMarkets() {
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "New York")?.displayName, "纽约")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "Los Angeles")?.displayName, "洛杉矶")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "London")?.displayName, "伦敦")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "Paris")?.displayName, "巴黎")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "Tokyo")?.displayName, "东京")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "Seoul")?.displayName, "首尔")
        XCTAssertEqual(WeatherCityFallbackDirectory.city(matching: "São Paulo")?.displayName, "圣保罗")
    }

    func testLatinFallbackCitiesDoNotStealAmbiguousRegionalQueries() {
        XCTAssertNil(WeatherCityFallbackDirectory.city(matching: "Paris Texas"))
        XCTAssertNil(WeatherCityFallbackDirectory.city(matching: "London Ontario"))
        XCTAssertNil(WeatherCityFallbackDirectory.city(matching: "San Francisco District"))
    }

    func testUnknownCityFallsThroughToSystemGeocoder() {
        XCTAssertNil(WeatherCityFallbackDirectory.city(matching: "一个不存在的城市名称"))
    }

    func testWeatherKitClassifierKeepsNonConnectivityURLErrorsGeneric() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.weatherKitError(from: error),
            .forecastUnavailable
        )
    }

    func testWeatherKitClassifierMapsOfflineToNetworkUnavailable() {
        let error = URLError(.notConnectedToInternet)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.weatherKitError(from: error),
            .networkUnavailable
        )
    }

    func testCityLookupClassifierOnlyUsesCityNotFoundForNoResults() {
        let error = NSError(domain: kCLErrorDomain, code: CLError.Code.geocodeFoundNoResult.rawValue)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.cityLookupError(from: error, cityName: "测试城市"),
            .cityNotFound("测试城市")
        )
    }

    func testCityLookupClassifierMapsNetworkFailureToNetworkUnavailable() {
        let error = NSError(domain: kCLErrorDomain, code: CLError.Code.network.rawValue)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.cityLookupError(from: error, cityName: "测试城市"),
            .networkUnavailable
        )
    }

    func testCityLookupClassifierDoesNotTreatUnknownFailuresAsCityNotFound() {
        let error = NSError(domain: "WeatherCityResolverTests", code: 1)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.cityLookupError(from: error, cityName: "测试城市"),
            .cityLookupUnavailable("测试城市")
        )
    }

    func testLocationClassifierMapsDeniedToPermissionDenied() {
        let error = NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue)

        XCTAssertEqual(
            WeatherForecastErrorClassifier.locationError(from: error),
            .permissionDenied
        )
    }
}
