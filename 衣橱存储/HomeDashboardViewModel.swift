import Foundation
import Observation

@Observable
final class HomeDashboardViewModel {
    struct TodayOOTDSnapshot {
        let outfit: OOTDOutfit
        let relationMessage: String?
        let piecePreviewNames: [String]
        let subtitle: String
    }

    struct UpcomingPlanSummary: Identifiable {
        let id: UUID
        let plan: OutfitPlan
        let relationMessage: String?
        let reminderText: String?

        var dateText: String {
            plan.date.formatted(.dateTime.month().day().weekday(.abbreviated))
        }

        var outfitTitle: String {
            plan.linkedOutfit?.title ?? plan.outfitSummary
        }
    }

    enum WeatherKind: String, CaseIterable, Identifiable {
        case sunny = "晴天"
        case partlyCloudy = "多云"
        case overcast = "阴天"
        case drizzle = "小雨"
        case heavyRain = "大雨"
        case thunderstorm = "雷雨"
        case windy = "大风"
        case snow = "下雪"

        var id: String { rawValue }

        var symbolName: String {
            switch self {
            case .sunny:
                "sun.max.fill"
            case .partlyCloudy:
                "cloud.sun.fill"
            case .overcast:
                "smoke.fill"
            case .drizzle:
                "cloud.drizzle.fill"
            case .heavyRain:
                "cloud.rain.fill"
            case .thunderstorm:
                "cloud.bolt.rain.fill"
            case .windy:
                "wind"
            case .snow:
                "cloud.snow.fill"
            }
        }

        var conditionTitle: String {
            rawValue
        }
    }

    struct WeatherSnapshot {
        let kind: WeatherKind
        let conditionTitle: String?
        let temperature: Int
        let apparentTemperature: Int
        let high: Int
        let low: Int
        let humidity: Int
        let windSpeed: Int
        let sourceTitle: String?

        init(
            kind: WeatherKind,
            conditionTitle: String? = nil,
            temperature: Int,
            apparentTemperature: Int,
            high: Int,
            low: Int,
            humidity: Int,
            windSpeed: Int,
            sourceTitle: String? = nil
        ) {
            self.kind = kind
            self.conditionTitle = conditionTitle
            self.temperature = temperature
            self.apparentTemperature = apparentTemperature
            self.high = high
            self.low = low
            self.humidity = humidity
            self.windSpeed = windSpeed
            self.sourceTitle = sourceTitle
        }

        func overridingTemperature(_ temperature: Int) -> WeatherSnapshot {
            let apparentDelta = apparentTemperature - self.temperature
            let spread = max(4, high - low)
            let lowerOffset = spread / 2
            let upperOffset = spread - lowerOffset
            return WeatherSnapshot(
                kind: kind,
                conditionTitle: conditionTitle,
                temperature: temperature,
                apparentTemperature: temperature + apparentDelta,
                high: temperature + upperOffset,
                low: temperature - lowerOffset,
                humidity: humidity,
                windSpeed: windSpeed,
                sourceTitle: sourceTitle
            )
        }
    }

    enum WeatherSourceState: Equatable {
        case preview
        case needsLocationPermission
        case locating
        case loadingForecast
        case live(updatedAt: Date)
        case permissionDenied
        case unavailable(String)
        case loadingCityForecast(String)

        var sourceLabel: String {
            switch self {
            case .preview:
                "预览天气"
            case .needsLocationPermission:
                "本地天气"
            case .locating:
                "正在定位"
            case .loadingForecast:
                "天气预报"
            case .live:
                "天气预报"
            case .permissionDenied, .unavailable:
                "天气不可用"
            case .loadingCityForecast(let cityName):
                "\(cityName)天气"
            }
        }
    }

    struct WeatherCallout {
        let title: String
        let message: String
        let actionTitle: String
        let symbolName: String
    }

    struct QuickAction: Identifiable {
        enum Kind: Hashable {
            case addClothing
            case recommendOutfit
            case createOOTD
            case createPlan
        }

        let id: Kind
        let title: String
        let subtitle: String
        let symbolName: String
    }

    enum Mood: String, CaseIterable, Identifiable {
        case calm = "松弛"
        case sharp = "利落"
        case playful = "轻甜"

        var id: String { rawValue }
    }

    enum Occasion: String, CaseIterable, Identifiable {
        case commute = "通勤"
        case cafe = "咖啡"
        case weekend = "周末"

        var id: String { rawValue }
    }

    var items: [WardrobeItem] = []
    var plans: [OutfitPlan] = []
    var outfits: [OOTDOutfit] = []
    var selectedMood: Mood = .sharp
    var selectedOccasion: Occasion = .commute
    var weather: WeatherSnapshot?
    var weatherSourceState: WeatherSourceState

    let quickActions: [QuickAction] = [
        QuickAction(id: .addClothing, title: "添加衣物", subtitle: "录入单品", symbolName: "plus.viewfinder"),
        QuickAction(id: .recommendOutfit, title: "智能推荐", subtitle: "按天气搭配", symbolName: "sparkles"),
        QuickAction(id: .createOOTD, title: "开始搭配", subtitle: "组合 OOTD", symbolName: "square.grid.2x2"),
        QuickAction(id: .createPlan, title: "新建计划", subtitle: "安排未来几天", symbolName: "calendar.badge.plus")
    ]

    init(previewWeather: WeatherKind? = nil) {
        if let previewWeather {
            weather = Self.mockWeather(for: previewWeather)
            weatherSourceState = .preview
        } else {
            weather = nil
            weatherSourceState = .needsLocationPermission
        }
    }

    func update(items: [WardrobeItem], plans: [OutfitPlan], outfits: [OOTDOutfit]) {
        self.items = items.sorted { $0.name < $1.name }
        self.plans = plans.sorted { $0.date < $1.date }
        self.outfits = outfits.sorted { $0.createdAt > $1.createdAt }
    }

    func setWeather(_ kind: WeatherKind, temperatureOverride: Int? = nil) {
        let snapshot = Self.mockWeather(for: kind)
        weather = temperatureOverride.map { snapshot.overridingTemperature($0) } ?? snapshot
        weatherSourceState = .preview
    }

    func markForecastRequestStarted(requestPermissionIfNeeded: Bool) {
        weatherSourceState = requestPermissionIfNeeded ? .locating : .loadingForecast
    }

    func markCityForecastRequestStarted(cityName: String) {
        weatherSourceState = .loadingCityForecast(cityName)
    }

    func applyForecast(_ snapshot: WeatherSnapshot, updatedAt: Date = .now) {
        weather = snapshot
        weatherSourceState = .live(updatedAt: updatedAt)
    }

    func requireLocationPermission() {
        weatherSourceState = .needsLocationPermission
    }

    func markLocationPermissionDenied() {
        weatherSourceState = .permissionDenied
    }

    func markForecastUnavailable(_ message: String) {
        weatherSourceState = .unavailable(message)
    }

    var totalItemsText: String {
        "\(items.count)"
    }

    var recentItems: [WardrobeItem] {
        Array(items.prefix(5))
    }

    var nextPlans: [OutfitPlan] {
        Array(plans.prefix(4))
    }

    var savedOutfitsCountText: String {
        "\(outfits.count)"
    }

    var todayOutfit: OOTDOutfit? {
        outfits.first(where: \.isToday)
    }

    var todayOOTDSnapshot: TodayOOTDSnapshot? {
        guard let todayOutfit else { return nil }

        let linkedPlan = upcomingPlans.first { $0.linkedOutfit?.id == todayOutfit.id }
        let relationMessage = linkedPlan.map { "已加入\($0.date.formatted(.dateTime.month().day()))计划" }
        let subtitle = todayOutfit.notes.isEmpty ? todayOutfit.summaryText : todayOutfit.notes

        return TodayOOTDSnapshot(
            outfit: todayOutfit,
            relationMessage: relationMessage,
            piecePreviewNames: todayOutfit.orderedItems.prefix(3).map(\.name),
            subtitle: subtitle
        )
    }

    var upcomingPlans: [OutfitPlan] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return plans
            .filter { $0.date >= startOfToday }
            .sorted { $0.date < $1.date }
    }

    var upcomingPlanSummaries: [UpcomingPlanSummary] {
        Array(upcomingPlans.prefix(3)).map { plan in
            let relationMessage: String?
            if let linkedOutfit = plan.linkedOutfit, linkedOutfit.isToday {
                relationMessage = "关联今日搭配"
            } else {
                relationMessage = nil
            }

            let reminderText = plan.reminderEnabled
            ? plan.reminderDate?.formatted(.dateTime.hour().minute())
            : nil

            return UpcomingPlanSummary(
                id: plan.id,
                plan: plan,
                relationMessage: relationMessage,
                reminderText: reminderText
            )
        }
    }

    var todaySummary: String {
        if items.isEmpty {
            return "先录入几件常穿单品，首页就会开始串联搭配和计划。"
        }

        if todayOOTDSnapshot == nil, upcomingPlanSummaries.isEmpty {
            return "\(items.count) 件单品已准备，接下来可以保存今日搭配或新建计划。"
        }

        return "\(items.count) 件单品 · \(upcomingPlanSummaries.count) 条近期计划 · \(plans.filter { $0.reminderEnabled }.count) 个提醒已准备"
    }

    var welcomeTitle: String {
        "早安，今天也穿得很漂亮"
    }

    var weatherHeadline: String {
        weather?.conditionTitle ?? weather?.kind.conditionTitle ?? "等待天气预报"
    }

    var weatherReminder: String {
        guard let weather else {
            return "开启本地天气后，首页会按真实预报生成搭配建议"
        }

        switch weather.kind {
        case .sunny:
            if weather.high >= 30 {
                return "紫外线较强，注意防晒"
            }
            return "天气明朗，适合轻盈透气穿搭"
        case .partlyCloudy:
            if weather.high - weather.low >= 8 {
                return "早晚温差大，记得加件外套"
            }
            return "云量适中，适合叠穿和轻层次"
        case .overcast:
            return "天色偏阴，建议用亮一点的单品提气色"
        case .drizzle:
            return "记得带伞，鞋子尽量选择防滑款"
        case .heavyRain:
            return "雨势较大，出门优先防水外套和包袋"
        case .thunderstorm:
            return "注意雷雨天气，尽量减少久留室外"
        case .windy:
            return "注意大风，出门看好随身物品"
        case .snow:
            return "注意防滑和保暖，优先外套与防水鞋履"
        }
    }

    var secondaryWeatherNote: String {
        guard let weather else {
            return "用于今日穿搭推荐"
        }

        if weather.high - weather.low >= 8 {
            return "早晚温差大"
        }

        if weather.windSpeed >= 8 {
            return "注意大风"
        }

        return "体感 \(weather.apparentTemperature)°"
    }

    var weatherCallout: WeatherCallout? {
        switch weatherSourceState {
        case .preview, .live:
            nil
        case .needsLocationPermission:
            WeatherCallout(
                title: "开启本地天气",
                message: "授权定位后，首页会自动读取今天的天气预报和温度。",
                actionTitle: "获取天气",
                symbolName: "location.fill"
            )
        case .locating:
            WeatherCallout(
                title: "正在定位",
                message: "正在获取当前位置，用于查询今天的天气预报。",
                actionTitle: "请稍候",
                symbolName: "location"
            )
        case .loadingForecast:
            WeatherCallout(
                title: "正在更新天气",
                message: "正在读取今天的预报数据。",
                actionTitle: "请稍候",
                symbolName: "cloud.sun"
            )
        case .permissionDenied:
            WeatherCallout(
                title: "定位权限未开启",
                message: "可以选择常用城市获取真实天气预报，也可以到系统设置里重新开启定位。",
                actionTitle: "选择城市",
                symbolName: "location.slash"
            )
        case .loadingCityForecast(let cityName):
            WeatherCallout(
                title: "正在读取\(cityName)天气",
                message: "正在按你选择的城市查询今天的预报。",
                actionTitle: "请稍候",
                symbolName: "mappin.and.ellipse"
            )
        case .unavailable(let message):
            WeatherCallout(
                title: "天气暂时不可用",
                message: message,
                actionTitle: "重试",
                symbolName: "arrow.clockwise"
            )
        }
    }

    var canUseForecastForRecommendation: Bool {
        weather != nil
    }

    var recommendation: OutfitRecommendation {
        if let todayOutfit {
            return OutfitRecommendation(outfit: todayOutfit)
        }

        let top = item(namedCategory: "上装") ?? item(namedCategory: "裙装")
        let bottom = selectedOccasion == .cafe ? item(namedCategory: "裙装") : item(namedCategory: "下装")
        let hasLargeTemperatureSwing = weather.map { $0.high - $0.low >= 8 } ?? false
        let layer = selectedMood == .calm || hasLargeTemperatureSwing ? item(namedCategory: "外套") : nil
        let shoes = item(namedCategory: "鞋履")
        let bag = item(namedCategory: "包袋")

        let pieces = [top, bottom, layer, shoes, bag].compactMap { $0 }
        let subtitle: String
        let reason: String
        let styleTags: [String]

        switch (selectedMood, selectedOccasion) {
        case (.sharp, .commute):
            subtitle = "低饱和、线条干净，适合需要效率感的工作日。"
            reason = "优先组合中性色和轻结构单品，保持专业但不生硬。"
            styleTags = ["通勤", "极简", "轻结构"]
        case (.calm, _):
            subtitle = "加入柔和针织层次，让整体更轻松有呼吸感。"
            reason = "温和色彩和外搭会让穿着状态更松弛，也更适合早晚温差。"
            styleTags = ["松弛", "层次", "低饱和"]
        case (.playful, .weekend):
            subtitle = "用裙装和配饰做重点，保留轻盈和一点趣味。"
            reason = "周末场景容错更高，适合把视觉重点放在轮廓和小配件。"
            styleTags = ["周末", "轻甜", "有亮点"]
        default:
            subtitle = "在已有衣橱里做低成本切换，今天就能直接穿。"
            reason = "规则引擎当前仅按场景和心情做本地匹配，结果稳定且可解释。"
            styleTags = ["日常", "易复用", "本地推荐"]
        }

        return OutfitRecommendation(
            title: "\(selectedOccasion.rawValue)推荐",
            subtitle: subtitle,
            reason: reason,
            pieces: pieces,
            styleTags: styleTags
        )
    }

    private func item(namedCategory category: String) -> WardrobeItem? {
        items.first { $0.category == category }
    }

    var todayOOTDEmptyMessage: String {
        if items.isEmpty {
            return "先去衣橱录入单品，之后就可以保存第一套今日搭配。"
        }

        return "还没有设置今日搭配。去 OOTD 页面保存一套，并勾选“设为今日搭配”。"
    }

    var upcomingPlansEmptyMessage: String {
        if outfits.isEmpty {
            return "还没有计划。先保存一套 OOTD，再把它绑定到某一天。"
        }

        return "最近没有 upcoming 计划。去计划页安排未来几天的穿搭。"
    }

    static func mockWeather(for kind: WeatherKind) -> WeatherSnapshot {
        switch kind {
        case .sunny:
            WeatherSnapshot(kind: .sunny, temperature: 27, apparentTemperature: 29, high: 31, low: 22, humidity: 44, windSpeed: 3)
        case .partlyCloudy:
            WeatherSnapshot(kind: .partlyCloudy, temperature: 24, apparentTemperature: 23, high: 28, low: 19, humidity: 50, windSpeed: 4)
        case .overcast:
            WeatherSnapshot(kind: .overcast, temperature: 20, apparentTemperature: 19, high: 22, low: 16, humidity: 68, windSpeed: 3)
        case .drizzle:
            WeatherSnapshot(kind: .drizzle, temperature: 22, apparentTemperature: 20, high: 26, low: 18, humidity: 77, windSpeed: 4)
        case .heavyRain:
            WeatherSnapshot(kind: .heavyRain, temperature: 19, apparentTemperature: 18, high: 21, low: 17, humidity: 90, windSpeed: 6)
        case .thunderstorm:
            WeatherSnapshot(kind: .thunderstorm, temperature: 18, apparentTemperature: 17, high: 20, low: 16, humidity: 93, windSpeed: 7)
        case .windy:
            WeatherSnapshot(kind: .windy, temperature: 21, apparentTemperature: 19, high: 24, low: 15, humidity: 46, windSpeed: 11)
        case .snow:
            WeatherSnapshot(kind: .snow, temperature: -2, apparentTemperature: -5, high: 1, low: -6, humidity: 82, windSpeed: 4)
        }
    }

    static var placeholderWeather: WeatherSnapshot {
        mockWeather(for: .partlyCloudy)
    }
}

struct OutfitRecommendation {
    let title: String
    let subtitle: String
    let reason: String
    let pieces: [WardrobeItem]
    let styleTags: [String]
}

extension OutfitRecommendation {
    init(outfit: OOTDOutfit) {
        self.init(
            title: outfit.isToday ? "今日已保存搭配" : outfit.title,
            subtitle: outfit.notes.isEmpty ? "已从衣橱中手动组合完成。" : outfit.notes,
            reason: outfit.summaryText,
            pieces: outfit.orderedItems,
            styleTags: [
                outfit.isToday ? "今日搭配" : "已保存",
                "手动搭配",
                "\(outfit.orderedItems.count) 件单品"
            ]
        )
    }
}
