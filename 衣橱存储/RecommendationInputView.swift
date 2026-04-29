import SwiftData
import SwiftUI

struct RecommendationInputView: View {
    @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]
    @State private var input = RecommendationInput()
    private let weatherSource: WeatherPrefillSource

    init(
        defaultWeather: RecommendationWeather? = nil,
        defaultTemperature: Int? = nil,
        weatherSource: WeatherPrefillSource = .ootdTab
    ) {
        _input = State(initialValue: RecommendationInput(weather: defaultWeather, temperatureCelsius: defaultTemperature))
        self.weatherSource = weatherSource
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    readinessSection
                    occasionSection
                    styleSection

                NavigationLink {
                    RecommendationResultView(
                        response: RecommendationEngine.generateRecommendations(
                            from: items,
                            input: input
                        )
                    )
                } label: {
                    Label("生成 1~3 套推荐", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))
                .disabled(!recommendationReadiness.canGenerateRecommendation)
                .opacity(recommendationReadiness.canGenerateRecommendation ? 1 : 0.58)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(background)
        .navigationTitle("轻量推荐")
        .homeInlineNavigationTitle()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("条件推荐")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("输入简单条件，用本地规则从现有衣橱生成可执行的穿搭建议。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(weatherSource.headline(for: input.weather, temperature: input.temperatureCelsius), systemImage: weatherSource.systemImage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    private var readinessSection: some View {
        let isReady = recommendationReadiness.canGenerateRecommendation

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 5) {
                Text(isReady ? "推荐已准备好" : recommendationReadiness.recommendationBlockedTitle)
                    .font(.subheadline.weight(.semibold))
                Text(isReady ? recommendationReadiness.recommendationReadyMessage : recommendationReadiness.recommendationBlockedMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .homeCardSurface(weight: isReady ? .tertiary : .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var occasionSection: some View {
        optionSection(
            title: "场景",
            subtitle: "今天主要去哪里",
            options: RecommendationOccasion.allCases,
            selected: $input.occasion
        )
    }

    private var styleSection: some View {
        optionSection(
            title: "风格 / 心情",
            subtitle: "偏轻松还是更利落",
            options: RecommendationStyle.allCases,
            selected: $input.style
        )
    }

    private var recommendationReadiness: WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness.make(items: items, outfits: [])
    }

    private func optionSection<Option: Identifiable & RawRepresentable>(
        title: String,
        subtitle: String,
        options: [Option],
        selected: Binding<Option>
    ) -> some View where Option.RawValue == String {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options) { option in
                    let isSelected = selected.wrappedValue.id == option.id

                    Button {
                        selected.wrappedValue = option
                    } label: {
                        Text(option.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(
                        cornerRadius: HomeMetrics.secondaryRadius,
                        tint: isSelected ? Color.white.opacity(0.26) : Color.white.opacity(0.12)
                    )
                }
            }
        }
    }

    private var background: some View {
        AppAdaptiveBackground()
    }
}

extension RecommendationInputView {
    enum WeatherPrefillSource: Equatable {
        case homeWeatherCard
        case ootdTab

        var systemImage: String {
            switch self {
            case .homeWeatherCard:
                "cloud.sun"
            case .ootdTab:
                "sparkles"
            }
        }

        func headline(for weather: RecommendationWeather?, temperature: Int?) -> String {
            guard let weather else {
                return "尚未获取天气预报，将先按场景和风格生成"
            }

            let temperatureText = temperature.map { " · \($0)°" } ?? ""
            switch self {
            case .homeWeatherCard:
                return "已按首页天气预报预填：\(weather.rawValue)\(temperatureText)"
            case .ootdTab:
                return "已按首页天气预报预填：\(weather.rawValue)\(temperatureText)"
            }
        }
    }
}

#Preview("Recommendation Input") {
    NavigationStack {
        RecommendationInputView(defaultWeather: .drizzle, weatherSource: .homeWeatherCard)
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
