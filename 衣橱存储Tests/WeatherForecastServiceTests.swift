import CoreLocation
import WeatherKit
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

    func testWeatherKitPermissionDeniedDoesNotShowGenericSetupFailure() {
        XCTAssertEqual(
            WeatherForecastErrorClassifier.weatherKitError(from: WeatherError.permissionDenied),
            .weatherKitAccessDenied
        )
    }

    func testWeatherKitClassifierDoesNotTreatUnrelatedJWTErrorsAsAccessDenied() {
        let error = NSError(
            domain: "WearOrderTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "jwt token refresh failed"]
        )

        XCTAssertEqual(
            WeatherForecastErrorClassifier.weatherKitError(from: error),
            .forecastUnavailable
        )
    }

    func testWeatherKitClassifierDetectsWeatherDaemonAuthenticatorFailure() {
        let error = NSError(
            domain: "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "JWT authenticator rejected request"]
        )

        XCTAssertEqual(
            WeatherForecastErrorClassifier.weatherKitError(from: error),
            .weatherKitAccessDenied
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

    func testPlanWeatherSummarySuggestsOuterwearForTemperatureSwing() {
        let summary = PlanWeatherSummary(
            date: .now,
            sourceTitle: "东京",
            conditionTitle: "晴天",
            symbolName: "sun.max",
            high: 20,
            low: 9,
            precipitationChance: 5,
            uvIndex: 3,
            windSpeed: 8
        )

        XCTAssertEqual(summary.compactText, "晴天 20° / 9°")
        XCTAssertEqual(summary.outfitHint, "早晚温差明显，外套或叠穿会更稳妥。")
    }

    func testPlanWeatherSummaryPrioritizesRainHint() {
        let summary = PlanWeatherSummary(
            date: .now,
            sourceTitle: "伦敦",
            conditionTitle: "小雨",
            symbolName: "cloud.rain",
            high: 18,
            low: 11,
            precipitationChance: 70,
            uvIndex: 1,
            windSpeed: 12
        )

        XCTAssertEqual(summary.detailText, "降水 70% · UV 1 · 风 12km/h")
        XCTAssertEqual(summary.outfitHint, "建议带伞，鞋履优先选择耐脏或防滑款。")
    }

    func testForecastDateUnavailableMessageIsUserReadable() {
        XCTAssertEqual(
            WeatherForecastService.ForecastError.forecastDateUnavailable.userMessage,
            "该日期暂时超出可预报范围，请选择更近的日期或稍后再试。"
        )
    }
}
