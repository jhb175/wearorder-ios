import CoreLocation
import Foundation
import OSLog
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
        case cityLookupUnavailable(String)
        case weatherKitAccessDenied
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
            case .cityLookupUnavailable(let cityName):
                "暂时无法解析“\(cityName)”的位置，请稍后重试或换一个更明确的城市名称。"
            case .weatherKitAccessDenied:
                "Apple Weather 暂时拒绝了天气请求。请确认已安装最新 TestFlight 构建；如果刚开启 WeatherKit，请重新 Archive 上传后再安装。"
            case .weatherKitUnavailable:
                "Apple Weather 暂时不可用，请稍后重试。"
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
        locationContinuation?.resume(throwing: WeatherForecastErrorClassifier.locationError(from: error))
        locationContinuation = nil
    }
}

enum WeatherForecastErrorClassifier {
    static func weatherKitError(from error: Error) -> WeatherForecastService.ForecastError {
        WeatherForecastDiagnostics.logWeatherKitError(error, context: "forecast")

        if let weatherError = error as? WeatherError {
            switch weatherError {
            case .permissionDenied:
                return .weatherKitAccessDenied
            default:
                break
            }
        }

        if let urlError = error as? URLError,
           networkURLErrorCodes.contains(urlError.code) {
            return .networkUnavailable
        }

        let nsError = error as NSError
        if isWeatherKitAccessDenied(nsError) {
            return .weatherKitAccessDenied
        }

        if isNetworkLikeError(nsError) {
            return .networkUnavailable
        }

        return .forecastUnavailable
    }

    static func cityLookupError(from error: Error, cityName: String) -> WeatherForecastService.ForecastError {
        if let forecastError = error as? WeatherForecastService.ForecastError {
            return forecastError
        }

        switch coreLocationCode(from: error) {
        case .some(.geocodeFoundNoResult), .some(.geocodeFoundPartialResult):
            return .cityNotFound(cityName)
        case .some(.network):
            return .networkUnavailable
        case .some(.geocodeCanceled), .some:
            return .cityLookupUnavailable(cityName)
        case .none:
            return .cityLookupUnavailable(cityName)
        }
    }

    static func locationError(from error: Error) -> WeatherForecastService.ForecastError {
        switch coreLocationCode(from: error) {
        case .some(.denied):
            return .permissionDenied
        default:
            return .locationUnavailable
        }
    }

    private static let networkURLErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .timedOut
    ]

    private static func isNetworkLikeError(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        return networkURLErrorCodes.contains(URLError.Code(rawValue: error.code))
    }

    private static func isWeatherKitAccessDenied(_ error: NSError) -> Bool {
        let diagnosticText = [
            error.domain,
            error.localizedDescription,
            String(describing: error.userInfo)
        ]
            .joined(separator: " ")
            .lowercased()

        let isWeatherRelated = diagnosticText.contains("weatherkit")
            || diagnosticText.contains("weatherdaemon")
            || diagnosticText.contains("com.apple.weather")
            || diagnosticText.contains("com.apple.developer.weatherkit")
            || error.domain.lowercased().contains("weather")

        let hasCredentialSignal = diagnosticText.contains("entitlement")
            || diagnosticText.contains("com.apple.developer.weatherkit")
            || diagnosticText.contains("jwt")
            || diagnosticText.contains("authenticator")

        let hasAccessDeniedSignal = diagnosticText.contains("permissiondenied")
            || diagnosticText.contains("permission denied")
            || diagnosticText.contains("unauthorized")
            || diagnosticText.contains("not authorized")
            || diagnosticText.contains("forbidden")

        return hasCredentialSignal || (isWeatherRelated && hasAccessDeniedSignal)
    }

    private static func coreLocationCode(from error: Error) -> CLError.Code? {
        if let coreLocationError = error as? CLError {
            return coreLocationError.code
        }

        let nsError = error as NSError
        guard nsError.domain == kCLErrorDomain else { return nil }
        return CLError.Code(rawValue: nsError.code)
    }
}

private enum WeatherForecastDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ramsey.wearorder",
        category: "WeatherForecast"
    )

    static func logWeatherKitError(_ error: Error, context: String) {
        let nsError = error as NSError
        logger.error(
            "WeatherKit request failed context=\(context, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .public)"
        )
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
            WeatherForecastDiagnostics.logWeatherKitError(WeatherError.permissionDenied, context: "permissionDenied")
            throw WeatherForecastService.ForecastError.weatherKitAccessDenied
        } catch {
            throw WeatherForecastErrorClassifier.weatherKitError(from: error)
        }
    }
}

private enum WeatherCityResolver {
    static func resolveCity(named cityName: String) async throws -> ResolvedWeatherCity {
        if let knownCity = WeatherCityFallbackDirectory.city(matching: cityName) {
            return ResolvedWeatherCity(
                location: CLLocation(latitude: knownCity.latitude, longitude: knownCity.longitude),
                sourceTitle: knownCity.displayName
            )
        }

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
        } catch {
            throw WeatherForecastErrorClassifier.cityLookupError(from: error, cityName: cityName)
        }
    }
}

enum WeatherCityFallbackDirectory {
    struct City: Equatable {
        let displayName: String
        let aliases: [String]
        let latitude: Double
        let longitude: Double
    }

    nonisolated static func city(matching input: String) -> City? {
        let normalizedInput = normalized(input)
        guard !normalizedInput.isEmpty else { return nil }

        return cities.first { city in
            let normalizedAliases = city.aliases.map(normalized)
            if normalizedAliases.contains(normalizedInput) {
                return true
            }

            return normalizedAliases.contains { alias in
                containsCJKCharacters(alias) && normalizedInput.hasPrefix(alias)
            }
        }
    }

    private nonisolated static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "特别行政区", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .lowercased()
    }

    private nonisolated static func containsCJKCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private nonisolated static let cities: [City] = [
        City(displayName: "上海", aliases: ["上海", "上海市", "Shanghai"], latitude: 31.2304, longitude: 121.4737),
        City(displayName: "北京", aliases: ["北京", "北京市", "Beijing", "Peking"], latitude: 39.9042, longitude: 116.4074),
        City(displayName: "广州", aliases: ["广州", "广州市", "Guangzhou", "Canton"], latitude: 23.1291, longitude: 113.2644),
        City(displayName: "深圳", aliases: ["深圳", "深圳市", "Shenzhen"], latitude: 22.5431, longitude: 114.0579),
        City(displayName: "杭州", aliases: ["杭州", "杭州市", "Hangzhou"], latitude: 30.2741, longitude: 120.1551),
        City(displayName: "南京", aliases: ["南京", "南京市", "Nanjing"], latitude: 32.0603, longitude: 118.7969),
        City(displayName: "苏州", aliases: ["苏州", "苏州市", "Suzhou"], latitude: 31.2989, longitude: 120.5853),
        City(displayName: "成都", aliases: ["成都", "成都市", "Chengdu"], latitude: 30.5728, longitude: 104.0668),
        City(displayName: "重庆", aliases: ["重庆", "重庆市", "Chongqing"], latitude: 29.5630, longitude: 106.5516),
        City(displayName: "武汉", aliases: ["武汉", "武汉市", "Wuhan"], latitude: 30.5928, longitude: 114.3055),
        City(displayName: "西安", aliases: ["西安", "西安市", "Xi'an", "Xian"], latitude: 34.3416, longitude: 108.9398),
        City(displayName: "天津", aliases: ["天津", "天津市", "Tianjin"], latitude: 39.3434, longitude: 117.3616),
        City(displayName: "青岛", aliases: ["青岛", "青岛市", "Qingdao"], latitude: 36.0671, longitude: 120.3826),
        City(displayName: "厦门", aliases: ["厦门", "厦门市", "Xiamen"], latitude: 24.4798, longitude: 118.0894),
        City(displayName: "福州", aliases: ["福州", "福州市", "Fuzhou"], latitude: 26.0745, longitude: 119.2965),
        City(displayName: "长沙", aliases: ["长沙", "长沙市", "Changsha"], latitude: 28.2282, longitude: 112.9388),
        City(displayName: "郑州", aliases: ["郑州", "郑州市", "Zhengzhou"], latitude: 34.7466, longitude: 113.6254),
        City(displayName: "合肥", aliases: ["合肥", "合肥市", "Hefei"], latitude: 31.8206, longitude: 117.2272),
        City(displayName: "宁波", aliases: ["宁波", "宁波市", "Ningbo"], latitude: 29.8683, longitude: 121.5440),
        City(displayName: "佛山", aliases: ["佛山", "佛山市", "Foshan"], latitude: 23.0215, longitude: 113.1214),
        City(displayName: "东莞", aliases: ["东莞", "东莞市", "Dongguan"], latitude: 23.0207, longitude: 113.7518),
        City(displayName: "无锡", aliases: ["无锡", "无锡市", "Wuxi"], latitude: 31.4912, longitude: 120.3119),
        City(displayName: "济南", aliases: ["济南", "济南市", "Jinan"], latitude: 36.6512, longitude: 117.1201),
        City(displayName: "大连", aliases: ["大连", "大连市", "Dalian"], latitude: 38.9140, longitude: 121.6147),
        City(displayName: "沈阳", aliases: ["沈阳", "沈阳市", "Shenyang"], latitude: 41.8057, longitude: 123.4315),
        City(displayName: "哈尔滨", aliases: ["哈尔滨", "哈尔滨市", "Harbin"], latitude: 45.8038, longitude: 126.5349),
        City(displayName: "长春", aliases: ["长春", "长春市", "Changchun"], latitude: 43.8171, longitude: 125.3235),
        City(displayName: "昆明", aliases: ["昆明", "昆明市", "Kunming"], latitude: 25.0389, longitude: 102.7183),
        City(displayName: "贵阳", aliases: ["贵阳", "贵阳市", "Guiyang"], latitude: 26.6477, longitude: 106.6302),
        City(displayName: "南宁", aliases: ["南宁", "南宁市", "Nanning"], latitude: 22.8170, longitude: 108.3669),
        City(displayName: "南昌", aliases: ["南昌", "南昌市", "Nanchang"], latitude: 28.6820, longitude: 115.8579),
        City(displayName: "太原", aliases: ["太原", "太原市", "Taiyuan"], latitude: 37.8706, longitude: 112.5489),
        City(displayName: "石家庄", aliases: ["石家庄", "石家庄市", "Shijiazhuang"], latitude: 38.0428, longitude: 114.5149),
        City(displayName: "乌鲁木齐", aliases: ["乌鲁木齐", "乌鲁木齐市", "Urumqi"], latitude: 43.8256, longitude: 87.6168),
        City(displayName: "拉萨", aliases: ["拉萨", "拉萨市", "Lhasa"], latitude: 29.6520, longitude: 91.1721),
        City(displayName: "兰州", aliases: ["兰州", "兰州市", "Lanzhou"], latitude: 36.0611, longitude: 103.8343),
        City(displayName: "海口", aliases: ["海口", "海口市", "Haikou"], latitude: 20.0440, longitude: 110.1999),
        City(displayName: "三亚", aliases: ["三亚", "三亚市", "Sanya"], latitude: 18.2528, longitude: 109.5119),
        City(displayName: "香港", aliases: ["香港", "Hong Kong", "HK"], latitude: 22.3193, longitude: 114.1694),
        City(displayName: "澳门", aliases: ["澳门", "Macau", "Macao"], latitude: 22.1987, longitude: 113.5439),
        City(displayName: "台北", aliases: ["台北", "台北市", "Taipei"], latitude: 25.0330, longitude: 121.5654),
        City(displayName: "东京", aliases: ["东京", "Tokyo"], latitude: 35.6762, longitude: 139.6503),
        City(displayName: "首尔", aliases: ["首尔", "Seoul"], latitude: 37.5665, longitude: 126.9780),
        City(displayName: "新加坡", aliases: ["新加坡", "Singapore"], latitude: 1.3521, longitude: 103.8198),
        City(displayName: "纽约", aliases: ["纽约", "New York", "NYC"], latitude: 40.7128, longitude: -74.0060),
        City(displayName: "洛杉矶", aliases: ["洛杉矶", "Los Angeles", "LA"], latitude: 34.0522, longitude: -118.2437),
        City(displayName: "旧金山", aliases: ["旧金山", "San Francisco", "SF"], latitude: 37.7749, longitude: -122.4194),
        City(displayName: "多伦多", aliases: ["多伦多", "Toronto"], latitude: 43.6532, longitude: -79.3832),
        City(displayName: "温哥华", aliases: ["温哥华", "Vancouver"], latitude: 49.2827, longitude: -123.1207),
        City(displayName: "伦敦", aliases: ["伦敦", "London"], latitude: 51.5072, longitude: -0.1276),
        City(displayName: "巴黎", aliases: ["巴黎", "Paris"], latitude: 48.8566, longitude: 2.3522),
        City(displayName: "柏林", aliases: ["柏林", "Berlin"], latitude: 52.5200, longitude: 13.4050),
        City(displayName: "罗马", aliases: ["罗马", "Rome"], latitude: 41.9028, longitude: 12.4964),
        City(displayName: "马德里", aliases: ["马德里", "Madrid"], latitude: 40.4168, longitude: -3.7038),
        City(displayName: "阿姆斯特丹", aliases: ["阿姆斯特丹", "Amsterdam"], latitude: 52.3676, longitude: 4.9041),
        City(displayName: "迪拜", aliases: ["迪拜", "Dubai"], latitude: 25.2048, longitude: 55.2708),
        City(displayName: "曼谷", aliases: ["曼谷", "Bangkok"], latitude: 13.7563, longitude: 100.5018),
        City(displayName: "吉隆坡", aliases: ["吉隆坡", "Kuala Lumpur"], latitude: 3.1390, longitude: 101.6869),
        City(displayName: "雅加达", aliases: ["雅加达", "Jakarta"], latitude: -6.2088, longitude: 106.8456),
        City(displayName: "马尼拉", aliases: ["马尼拉", "Manila"], latitude: 14.5995, longitude: 120.9842),
        City(displayName: "悉尼", aliases: ["悉尼", "Sydney"], latitude: -33.8688, longitude: 151.2093),
        City(displayName: "墨尔本", aliases: ["墨尔本", "Melbourne"], latitude: -37.8136, longitude: 144.9631),
        City(displayName: "德里", aliases: ["德里", "Delhi", "New Delhi"], latitude: 28.6139, longitude: 77.2090),
        City(displayName: "孟买", aliases: ["孟买", "Mumbai"], latitude: 19.0760, longitude: 72.8777),
        City(displayName: "伊斯坦布尔", aliases: ["伊斯坦布尔", "Istanbul"], latitude: 41.0082, longitude: 28.9784),
        City(displayName: "圣保罗", aliases: ["圣保罗", "Sao Paulo", "São Paulo"], latitude: -23.5558, longitude: -46.6396),
        City(displayName: "墨西哥城", aliases: ["墨西哥城", "Mexico City"], latitude: 19.4326, longitude: -99.1332),
        City(displayName: "开罗", aliases: ["开罗", "Cairo"], latitude: 30.0444, longitude: 31.2357)
    ]
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
