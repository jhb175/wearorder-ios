import SwiftData
import SwiftUI

private struct AppStoreScreenshotPreview: View {
    let scenario: AppStoreScreenshotScenario
    private let previewContainer = WardrobePreviewContainer.make()

    var body: some View {
        switch scenario.surface {
        case .mainTab(let tab):
            ContentView(previewWeather: scenario.previewWeather, previewTab: tab)
                .preferredColorScheme(scenario.preferredColorScheme)
                .modelContainer(previewContainer)
        case .recommendationResult:
            NavigationStack {
                RecommendationResultView(response: recommendationResponse)
            }
            .preferredColorScheme(scenario.preferredColorScheme)
            .modelContainer(previewContainer)
        }
    }

    private var recommendationResponse: RecommendationResponse {
        RecommendationEngine.generateRecommendations(
            from: WardrobeMockData.items,
            input: RecommendationInput(
                weather: .drizzle,
                temperatureCelsius: 24,
                occasion: .commute,
                style: .minimal
            )
        )
    }
}

#Preview("App Store 1 · 首页总览") {
    AppStoreScreenshotPreview(scenario: .homeDashboard)
}

#Preview("App Store 2 · 数字衣橱") {
    AppStoreScreenshotPreview(scenario: .wardrobeLibrary)
}

#Preview("App Store 3 · 智能推荐") {
    AppStoreScreenshotPreview(scenario: .recommendationResult)
}

#Preview("App Store 4 · 计划提醒") {
    AppStoreScreenshotPreview(scenario: .plannerTimeline)
}

#Preview("App Store 5 · 隐私支持") {
    AppStoreScreenshotPreview(scenario: .privacySupport)
}
