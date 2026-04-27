import CoreLocation
import Foundation

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
        guard CLLocationManager.locationServicesEnabled() else {
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
        return try await OpenMeteoForecastClient.fetchTodayForecast(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func fetchTodayForecast(cityName: String) async throws -> HomeDashboardViewModel.WeatherSnapshot {
        let trimmedCityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCityName.isEmpty else {
            throw ForecastError.invalidCityName
        }

        let city = try await OpenMeteoGeocodingClient.resolveCity(named: trimmedCityName)
        return try await OpenMeteoForecastClient.fetchTodayForecast(
            latitude: city.latitude,
            longitude: city.longitude,
            sourceTitle: city.weatherSourceTitle
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

private enum OpenMeteoForecastClient {
    static func fetchTodayForecast(
        latitude: Double,
        longitude: Double,
        sourceTitle: String? = nil
    ) async throws -> HomeDashboardViewModel.WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherForecastService.ForecastError.forecastUnavailable
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else {
                throw WeatherForecastService.ForecastError.forecastUnavailable
            }

            let forecast = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
            return forecast.snapshot(sourceTitle: sourceTitle)
        } catch let error as WeatherForecastService.ForecastError {
            throw error
        } catch {
            throw WeatherForecastService.ForecastError.networkUnavailable
        }
    }
}

private enum OpenMeteoGeocodingClient {
    static func resolveCity(named cityName: String) async throws -> OpenMeteoCity {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: cityName),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            throw WeatherForecastService.ForecastError.forecastUnavailable
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else {
                throw WeatherForecastService.ForecastError.forecastUnavailable
            }

            let geocoding = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
            guard let city = geocoding.results?.first else {
                throw WeatherForecastService.ForecastError.cityNotFound(cityName)
            }
            return city
        } catch let error as WeatherForecastService.ForecastError {
            throw error
        } catch {
            throw WeatherForecastService.ForecastError.networkUnavailable
        }
    }
}

private struct OpenMeteoGeocodingResponse: Decodable {
    let results: [OpenMeteoCity]?
}

private struct OpenMeteoCity: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let admin1: String?
    let country: String?

    var weatherSourceTitle: String {
        let locationParts = [name, admin1, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = Array(locationParts.prefix(2)).joined(separator: " · ")
        return displayName.isEmpty ? "城市天气" : "\(displayName)天气"
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let current: CurrentWeather
    let daily: DailyWeather

    func snapshot(sourceTitle: String?) -> HomeDashboardViewModel.WeatherSnapshot {
        let weatherCode = daily.weatherCode.first ?? current.weatherCode
        let condition = OpenMeteoConditionMapper.condition(for: weatherCode)
        let currentTemperature = Int(current.temperature.rounded())
        let apparentTemperature = Int(current.apparentTemperature.rounded())
        let high = Int((daily.high.first ?? current.temperature).rounded())
        let low = Int((daily.low.first ?? current.temperature).rounded())
        let humidity = Int(current.humidity.rounded())
        let windSpeed = Int(current.windSpeed.rounded())

        return HomeDashboardViewModel.WeatherSnapshot(
            kind: condition.kind,
            conditionTitle: condition.title,
            temperature: currentTemperature,
            apparentTemperature: apparentTemperature,
            high: high,
            low: low,
            humidity: humidity,
            windSpeed: windSpeed,
            sourceTitle: sourceTitle
        )
    }

    struct CurrentWeather: Decodable {
        let temperature: Double
        let apparentTemperature: Double
        let humidity: Double
        let windSpeed: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }

    struct DailyWeather: Decodable {
        let weatherCode: [Int]
        let high: [Double]
        let low: [Double]

        enum CodingKeys: String, CodingKey {
            case weatherCode = "weather_code"
            case high = "temperature_2m_max"
            case low = "temperature_2m_min"
        }
    }
}

private enum OpenMeteoConditionMapper {
    static func condition(for code: Int) -> (kind: HomeDashboardViewModel.WeatherKind, title: String) {
        switch code {
        case 0:
            (.sunny, "晴天")
        case 1, 2:
            (.partlyCloudy, "多云")
        case 3, 45, 48:
            (.overcast, "阴天")
        case 51, 53, 55, 56, 57:
            (.drizzle, "小雨")
        case 61, 63, 80, 81:
            (.drizzle, "阵雨")
        case 65, 66, 67, 82:
            (.heavyRain, "大雨")
        case 71, 73, 75, 77, 85, 86:
            (.snow, "降雪")
        case 95, 96, 99:
            (.thunderstorm, "雷雨")
        default:
            (.partlyCloudy, "天气预报")
        }
    }
}
