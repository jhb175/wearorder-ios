import CoreLocation
import Foundation
import WeatherKit

final class WeatherForecastService: NSObject, CLLocationManagerDelegate {
    enum ForecastError: Error, Equatable {
        case locationServicesDisabled
        case permissionNeeded
        case permissionDenied
        case locationUnavailable
        case forecastUnavailable
        case networkUnavailable
        case invalidCityName
        case cityNotFound(String)
        case weatherKitUnavailable

        var userMessage: String {
            switch self {
            case .locationServicesDisabled:
                "系统定位服务未开启，无法读取本地天气。"
            case .permissionNeeded:
                "需要先授权定位，才能获取今天的本地天气。"
            case .permissionDenied:
                "定位权限未开启，无法获取本地天气。"
            case .locationUnavailable:
                "暂时无法获取当前位置，请稍后重试。"
            case .forecastUnavailable:
                "天气服务暂时没有返回可用预报，请稍后重试。"
            case .networkUnavailable:
                "网络不可用，无法更新天气预报。"
            case .invalidCityName:
                "请输入城市名称，用于查询天气预报。"
            case .cityNotFound(let cityName):
                "没有找到“\(cityName)”的天气预报，请检查城市名称后重试。"
            case .weatherKitUnavailable:
                "WeatherKit 尚未配置完成，请在 Apple Developer 后台和 Xcode Capability 中启用 WeatherKit。"
            }
        }
    }

    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func fetchTodayForecast(requestPermissionIfNeeded: Bool) async throws -> HomeDashboardViewModel.WeatherSnapshot {
        guard await locationServicesEnabled() else {
            throw ForecastError.locationServicesDisabled
        }

        let status = await resolvedAuthorizationStatus(requestPermissionIfNeeded: requestPermissionIfNeeded)
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            if status == .notDetermined {
                throw ForecastError.permissionNeeded
            }
            throw ForecastError.permissionDenied
        }

        let location = try await requestCurrentLocation()
        return try await WeatherKitForecastClient.fetchTodayForecast(at: location, sourceTitle: nil)
    }

    private func locationServicesEnabled() async -> Bool {
        await Task.detached(priority: .utility) {
            CLLocationManager.locationServicesEnabled()
        }.value
    }

    func fetchTodayForecast(cityName: String) async throws -> HomeDashboardViewModel.WeatherSnapshot {
        let trimmedCityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCityName.isEmpty else {
            throw ForecastError.invalidCityName
        }

        let city = try await WeatherCityResolver.resolveCity(named: trimmedCityName)
        return try await WeatherKitForecastClient.fetchTodayForecast(
            at: city.location,
            sourceTitle: city.sourceTitle
        )
    }

    private func resolvedAuthorizationStatus(requestPermissionIfNeeded: Bool) async -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        guard status == .notDetermined, requestPermissionIfNeeded else {
            return status
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        guard locationContinuation == nil else {
            throw ForecastError.locationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }

        authorizationContinuation?.resume(returning: status)
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            locationContinuation?.resume(throwing: ForecastError.locationUnavailable)
            locationContinuation = nil
            return
        }

        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: ForecastError.locationUnavailable)
        locationContinuation = nil
    }
}

private enum WeatherKitForecastClient {
    static func fetchTodayForecast(
        at location: CLLocation,
        sourceTitle: String?
    ) async throws -> HomeDashboardViewModel.WeatherSnapshot {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let attribution = try? await WeatherService.shared.attribution
            return weather.snapshot(sourceTitle: sourceTitle, attribution: attribution)
        } catch let error as WeatherForecastService.ForecastError {
            throw error
        } catch WeatherError.permissionDenied {
            throw WeatherForecastService.ForecastError.weatherKitUnavailable
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw WeatherForecastService.ForecastError.networkUnavailable
        } catch {
            throw WeatherForecastService.ForecastError.networkUnavailable
        }
    }
}

private enum WeatherCityResolver {
    static func resolveCity(named cityName: String) async throws -> ResolvedWeatherCity {
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(cityName)
            guard let placemark = placemarks.first,
                  let location = placemark.location
            else {
                throw WeatherForecastService.ForecastError.cityNotFound(cityName)
            }

            return ResolvedWeatherCity(location: location, sourceTitle: placemark.weatherSourceTitle(fallback: cityName))
        } catch let error as WeatherForecastService.ForecastError {
            throw error
        } catch let error as CLError {
            if error.code == .geocodeFoundNoResult || error.code == .geocodeFoundPartialResult {
                throw WeatherForecastService.ForecastError.cityNotFound(cityName)
            }
            throw WeatherForecastService.ForecastError.networkUnavailable
        } catch {
            throw WeatherForecastService.ForecastError.cityNotFound(cityName)
        }
    }
}

private struct ResolvedWeatherCity {
    let location: CLLocation
    let sourceTitle: String
}

private extension CLPlacemark {
    func weatherSourceTitle(fallback: String) -> String {
        let locationParts = [locality, subAdministrativeArea, administrativeArea, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = uniquePrefix(locationParts, maxCount: 2).joined(separator: " · ")
        return displayName.isEmpty ? fallback : displayName
    }
}

private extension Weather {
    func snapshot(sourceTitle: String?, attribution: WeatherAttribution?) -> HomeDashboardViewModel.WeatherSnapshot {
        let current = currentWeather
        let today = dailyForecast.forecast.first { Calendar.current.isDate($0.date, inSameDayAs: current.date) }
            ?? dailyForecast.forecast.first
        let windSpeed = roundedKPH(current.wind.speed)
        let condition = WeatherKitConditionMapper.condition(for: current.condition, windSpeed: windSpeed)
        let dayHigh = today.map { roundedCelsius($0.highTemperature) } ?? roundedCelsius(current.temperature)
        let dayLow = today.map { roundedCelsius($0.lowTemperature) } ?? roundedCelsius(current.temperature)
        let precipitationChance = today
            .map { percent($0.precipitationChance) }
            ?? hourlyForecast.forecast.first.map { percent($0.precipitationChance) }

        return HomeDashboardViewModel.WeatherSnapshot(
            kind: condition.kind,
            conditionTitle: condition.title,
            temperature: roundedCelsius(current.temperature),
            apparentTemperature: roundedCelsius(current.apparentTemperature),
            high: dayHigh,
            low: dayLow,
            humidity: percent(current.humidity),
            windSpeed: windSpeed,
            sourceTitle: sourceTitle,
            providerName: normalizedProviderName(from: attribution),
            providerLegalURL: attribution?.legalPageURL,
            providerMarkLightURL: attribution?.combinedMarkLightURL,
            providerMarkDarkURL: attribution?.combinedMarkDarkURL,
            symbolName: current.symbolName,
            uvIndex: current.uvIndex.value,
            precipitationChance: precipitationChance,
            hourlyForecast: hourlyForecast.forecast
                .filter { $0.date >= current.date.addingTimeInterval(-60 * 30) }
                .prefix(12)
                .map(HomeDashboardViewModel.WeatherHourSnapshot.init),
            dailyForecast: dailyForecast.forecast
                .prefix(10)
                .map(HomeDashboardViewModel.WeatherDaySnapshot.init)
        )
    }

    private func normalizedProviderName(from attribution: WeatherAttribution?) -> String {
        let providerName = attribution?.serviceName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return providerName.isEmpty ? "Apple Weather" : providerName
    }
}

extension HomeDashboardViewModel.WeatherHourSnapshot {
    nonisolated init(_ hour: HourWeather) {
        let condition = WeatherKitConditionMapper.condition(
            for: hour.condition,
            windSpeed: roundedKPH(hour.wind.speed)
        )
        self.init(
            date: hour.date,
            kind: condition.kind,
            symbolName: hour.symbolName,
            temperature: roundedCelsius(hour.temperature),
            precipitationChance: percent(hour.precipitationChance),
            windSpeed: roundedKPH(hour.wind.speed)
        )
    }
}

extension HomeDashboardViewModel.WeatherDaySnapshot {
    nonisolated init(_ day: DayWeather) {
        let condition = WeatherKitConditionMapper.condition(
            for: day.condition,
            windSpeed: roundedKPH(day.wind.speed)
        )
        self.init(
            date: day.date,
            kind: condition.kind,
            symbolName: day.symbolName,
            high: roundedCelsius(day.highTemperature),
            low: roundedCelsius(day.lowTemperature),
            precipitationChance: percent(day.precipitationChance),
            uvIndex: day.uvIndex.value,
            windSpeed: roundedKPH(day.wind.speed)
        )
    }
}

private enum WeatherKitConditionMapper {
    nonisolated static func condition(
        for condition: WeatherCondition,
        windSpeed: Int
    ) -> (kind: HomeDashboardViewModel.WeatherKind, title: String) {
        switch condition {
        case .clear, .mostlyClear, .hot:
            windSpeed >= 10 ? (.windy, "大风") : (.sunny, "晴天")
        case .partlyCloudy, .sunFlurries, .sunShowers:
            windSpeed >= 10 ? (.windy, "大风") : (.partlyCloudy, "多云")
        case .cloudy, .mostlyCloudy, .foggy, .haze, .smoky, .blowingDust:
            (.overcast, "阴天")
        case .drizzle, .freezingDrizzle:
            (.drizzle, "小雨")
        case .rain:
            (.drizzle, "阵雨")
        case .heavyRain, .freezingRain, .hail:
            (.heavyRain, "大雨")
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms, .hurricane, .tropicalStorm:
            (.thunderstorm, "雷雨")
        case .flurries, .snow, .heavySnow, .blizzard, .blowingSnow, .sleet, .wintryMix, .frigid:
            (.snow, "降雪")
        case .breezy, .windy:
            (.windy, "大风")
        default:
            (.partlyCloudy, "天气预报")
        }
    }
}

private nonisolated func roundedCelsius(_ measurement: Measurement<UnitTemperature>) -> Int {
    Int(measurement.converted(to: .celsius).value.rounded())
}

private nonisolated func roundedKPH(_ measurement: Measurement<UnitSpeed>) -> Int {
    Int(measurement.converted(to: .kilometersPerHour).value.rounded())
}

private nonisolated func percent(_ value: Double) -> Int {
    Int((value * 100).rounded())
}

private nonisolated func uniquePrefix(_ values: [String], maxCount: Int) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []
    for value in values where !seen.contains(value) {
        seen.insert(value)
        result.append(value)
        if result.count == maxCount { break }
    }
    return result
}
