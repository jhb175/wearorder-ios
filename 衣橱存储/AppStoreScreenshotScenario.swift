import SwiftUI

enum AppStoreScreenshotScenario: String, CaseIterable, Identifiable {
    enum Surface {
        case mainTab(ContentView.HomeTab)
        case recommendationResult
    }

    case homeDashboard
    case wardrobeLibrary
    case recommendationResult
    case plannerTimeline
    case privacySupport

    static let recommendedDevice = "6.9-inch iPhone"

    var id: String { rawValue }

    var previewName: String {
        switch self {
        case .homeDashboard:
            "App Store 1 · 首页总览"
        case .wardrobeLibrary:
            "App Store 2 · 数字衣橱"
        case .recommendationResult:
            "App Store 3 · 智能推荐"
        case .plannerTimeline:
            "App Store 4 · 计划提醒"
        case .privacySupport:
            "App Store 5 · 隐私支持"
        }
    }

    var surface: Surface {
        switch self {
        case .homeDashboard:
            .mainTab(.home)
        case .wardrobeLibrary:
            .mainTab(.wardrobe)
        case .recommendationResult:
            .recommendationResult
        case .plannerTimeline:
            .mainTab(.plans)
        case .privacySupport:
            .mainTab(.settings)
        }
    }

    var previewWeather: HomeDashboardViewModel.WeatherKind {
        switch self {
        case .homeDashboard:
            .sunny
        case .wardrobeLibrary:
            .partlyCloudy
        case .recommendationResult:
            .drizzle
        case .plannerTimeline:
            .partlyCloudy
        case .privacySupport:
            .sunny
        }
    }

    var preferredColorScheme: ColorScheme? {
        nil
    }

    var storeCaption: String {
        switch self {
        case .homeDashboard:
            "首页串联今日天气、OOTD 和近期计划。"
        case .wardrobeLibrary:
            "集中管理衣物照片、分类和购买信息。"
        case .recommendationResult:
            "基于天气、温度和场景生成本地搭配。"
        case .plannerTimeline:
            "把 OOTD 安排到日期，并用本地提醒跟进。"
        case .privacySupport:
            "本地优先，不追踪，不上传衣橱数据。"
        }
    }
}
