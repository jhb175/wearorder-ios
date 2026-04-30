import Foundation

struct PlanWeatherSummary: Equatable {
    let date: Date
    let sourceTitle: String
    let conditionTitle: String
    let symbolName: String
    let high: Int
    let low: Int
    let precipitationChance: Int
    let uvIndex: Int
    let windSpeed: Int

    var temperatureRangeText: String {
        "\(high)° / \(low)°"
    }

    var compactText: String {
        "\(conditionTitle) \(temperatureRangeText)"
    }

    var detailText: String {
        "降水 \(precipitationChance)% · UV \(uvIndex) · 风 \(windSpeed)km/h"
    }

    var outfitHint: String {
        var hints: [String] = []

        if precipitationChance >= 45 || conditionTitle.contains("雨") {
            hints.append("建议带伞，鞋履优先选择耐脏或防滑款。")
        }

        if conditionTitle.contains("雪") {
            hints.append("建议增加保暖外套和防滑鞋。")
        }

        if low <= 12 || high - low >= 9 {
            hints.append("早晚温差明显，外套或叠穿会更稳妥。")
        }

        if high >= 28 {
            hints.append("天气偏热，优先选择轻薄透气单品。")
        }

        if windSpeed >= 22 {
            hints.append("风力偏大，外套和发型配饰要考虑稳定性。")
        }

        if uvIndex >= 6 {
            hints.append("紫外线偏强，可以加入帽子、墨镜或防晒外搭。")
        }

        return hints.first ?? "天气适合按当天场景搭配，注意鞋履和外套的舒适度。"
    }
}

enum PlanWeatherLoadState: Equatable {
    case idle
    case missingCity
    case loading
    case loaded(PlanWeatherSummary)
    case unavailable(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    static func message(from error: Error) -> String {
        if let forecastError = error as? WeatherForecastService.ForecastError {
            return forecastError.userMessage
        }
        return error.localizedDescription
    }
}
