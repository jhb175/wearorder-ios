import SwiftUI

struct WeatherCardView: View {
    let weather: HomeDashboardViewModel.WeatherSnapshot?
    let headline: String
    let reminder: String
    let secondaryNote: String
    var sourceLabel = "天气预报"
    let isAnimationActive: Bool

    var body: some View {
        ZStack {
            glassBaseLayer
            WeatherAtmosphereLayer(weather: displayWeather, isAnimationActive: isAnimationActive)
            leftSafetyVeil
            bottomFogLayer
            glassHighlightLayer

            GeometryReader { proxy in
                HStack {
                    WeatherInfoPanel(
                        weather: weather,
                        headline: headline,
                        reminder: reminder,
                        secondaryNote: secondaryNote,
                        sourceLabel: sourceLabel,
                        primaryText: primaryText,
                        secondaryText: secondaryText
                    )
                    .frame(width: max(min(proxy.size.width * 0.42, 246), 188), alignment: .leading)
                    .padding(.leading, 26)
                    .padding(.top, 24)
                    .padding(.bottom, 22)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 318)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(cardBorderGradient, lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
    }

    private var glassBaseLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(baseGlassTopOpacity),
                            Color.white.opacity(baseGlassBottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(baseOverlayTopOpacity),
                                    Color.white.opacity(baseOverlayMidOpacity),
                                    Color.white.opacity(baseOverlayBottomOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

            HStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(edgeGlowOpacity),
                        Color.white.opacity(edgeGlowOpacity * 0.33),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(trailingGlowOpacity)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private var leftSafetyVeil: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(safetyVeilLeadingOpacity),
                    Color.black.opacity(safetyVeilMiddleOpacity),
                    Color.black.opacity(safetyVeilTrailingOpacity),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 196)

            Spacer(minLength: 0)
        }
        .blur(radius: 12)
    }

    private var bottomFogLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(bottomFogMidOpacity),
                    Color.white.opacity(bottomFogBottomOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 88)
        }
        .allowsHitTesting(false)
    }

    private var glassHighlightLayer: some View {
        ZStack {
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(topHighlightLeadingOpacity),
                        Color.white.opacity(topHighlightTrailingOpacity),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 92)

                Spacer()
            }

            HStack {
                Capsule()
                    .fill(Color.white.opacity(leftRefractionOpacity))
                    .frame(width: 78, height: 220)
                    .rotationEffect(.degrees(-14))
                    .blur(radius: 16)
                    .offset(x: -12, y: 8)

                Spacer()

                Capsule()
                    .fill(Color.white.opacity(rightRefractionOpacity))
                    .frame(width: 88, height: 250)
                    .rotationEffect(.degrees(10))
                    .blur(radius: 20)
                    .offset(x: 12)
            }
        }
        .allowsHitTesting(false)
    }

    private var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(borderTopOpacity),
                Color.white.opacity(0.10),
                Color.white.opacity(borderBottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryText: Color {
        Color.white.opacity(0.97)
    }

    private var secondaryText: Color {
        Color.white.opacity(0.78)
    }

    private var displayWeather: HomeDashboardViewModel.WeatherSnapshot {
        weather ?? HomeDashboardViewModel.placeholderWeather
    }

    private var baseGlassTopOpacity: Double {
        switch displayWeather.kind {
        case .sunny, .partlyCloudy:
            0.18
        case .windy:
            0.17
        case .overcast, .drizzle, .snow:
            0.15
        case .heavyRain, .thunderstorm:
            0.13
        }
    }

    private var baseGlassBottomOpacity: Double {
        switch displayWeather.kind {
        case .sunny, .partlyCloudy:
            0.07
        case .windy:
            0.065
        case .overcast, .drizzle, .snow:
            0.055
        case .heavyRain, .thunderstorm:
            0.05
        }
    }

    private var baseOverlayTopOpacity: Double { displayWeather.kind == .sunny ? 0.13 : 0.11 }
    private var baseOverlayMidOpacity: Double { displayWeather.kind == .thunderstorm ? 0.04 : 0.05 }
    private var baseOverlayBottomOpacity: Double { displayWeather.kind == .heavyRain || displayWeather.kind == .thunderstorm ? 0.015 : 0.02 }
    private var edgeGlowOpacity: Double { displayWeather.kind == .sunny ? 0.20 : 0.17 }
    private var trailingGlowOpacity: Double { displayWeather.kind == .thunderstorm ? 0.08 : 0.10 }

    private var safetyVeilLeadingOpacity: Double {
        switch displayWeather.kind {
        case .sunny, .partlyCloudy:
            0.22
        case .windy:
            0.24
        case .overcast, .drizzle, .snow:
            0.28
        case .heavyRain, .thunderstorm:
            0.32
        }
    }

    private var safetyVeilMiddleOpacity: Double {
        switch displayWeather.kind {
        case .sunny, .partlyCloudy:
            0.11
        case .windy:
            0.12
        case .overcast, .drizzle, .snow:
            0.15
        case .heavyRain, .thunderstorm:
            0.18
        }
    }

    private var safetyVeilTrailingOpacity: Double {
        switch displayWeather.kind {
        case .sunny, .partlyCloudy:
            0.04
        case .windy:
            0.05
        case .overcast, .drizzle, .snow:
            0.06
        case .heavyRain, .thunderstorm:
            0.07
        }
    }

    private var bottomFogMidOpacity: Double {
        switch displayWeather.kind {
        case .sunny:
            0.05
        case .partlyCloudy, .windy:
            0.06
        case .overcast, .drizzle, .snow:
            0.07
        case .heavyRain, .thunderstorm:
            0.08
        }
    }

    private var bottomFogBottomOpacity: Double {
        switch displayWeather.kind {
        case .sunny:
            0.11
        case .partlyCloudy, .windy:
            0.12
        case .overcast, .drizzle, .snow:
            0.13
        case .heavyRain, .thunderstorm:
            0.14
        }
    }

    private var topHighlightLeadingOpacity: Double { displayWeather.kind == .sunny ? 0.30 : 0.26 }
    private var topHighlightTrailingOpacity: Double { displayWeather.kind == .thunderstorm ? 0.08 : 0.10 }
    private var leftRefractionOpacity: Double { displayWeather.kind == .sunny ? 0.08 : 0.07 }
    private var rightRefractionOpacity: Double { displayWeather.kind == .heavyRain || displayWeather.kind == .thunderstorm ? 0.12 : 0.14 }
    private var borderTopOpacity: Double { displayWeather.kind == .thunderstorm ? 0.46 : 0.54 }
    private var borderBottomOpacity: Double { displayWeather.kind == .heavyRain || displayWeather.kind == .thunderstorm ? 0.20 : 0.24 }
}

private struct WeatherAtmosphereLayer: View {
    let weather: HomeDashboardViewModel.WeatherSnapshot
    let isAnimationActive: Bool

    var body: some View {
        ZStack {
            WeatherAnimationView(kind: weather.kind, isActive: isAnimationActive)
                .opacity(1.0)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    .clear,
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.04),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 136)

                Spacer()
            }
        }
    }
}

private struct WeatherInfoPanel: View {
    let weather: HomeDashboardViewModel.WeatherSnapshot?
    let headline: String
    let reminder: String
    let secondaryNote: String
    let sourceLabel: String
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Label(sourceLabel, systemImage: weather == nil ? "location" : "cloud.sun")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)

                Text(headline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primaryText.opacity(0.88))

                Text(temperatureText)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .tracking(0)
                    .foregroundStyle(primaryText)

                Text(apparentTemperatureText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(secondaryText)
            }

            HStack(spacing: 10) {
                WeatherMetricChip(title: "最高", value: weather.map { "\($0.high)°" } ?? "--")
                WeatherMetricChip(title: "最低", value: weather.map { "\($0.low)°" } ?? "--")
            }
            .frame(maxWidth: 172)

            VStack(alignment: .leading, spacing: 9) {
                Text("天气搭配提醒")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .textCase(.uppercase)

                Text(reminder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText.opacity(0.94))
                    .lineLimit(3)

                Text(secondaryNote)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(secondaryText.opacity(0.92))
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var temperatureText: String {
        weather.map { "\($0.temperature)°" } ?? "--°"
    }

    private var apparentTemperatureText: String {
        weather.map { "体感 \($0.apparentTemperature)°" } ?? "等待定位"
    }
}

private struct WeatherMetricChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.9)
        }
    }

    private var primaryText: Color {
        Color.white.opacity(0.94)
    }

    private var secondaryText: Color {
        Color.white.opacity(0.72)
    }
}

#Preview("Sunny Static") {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.95, blue: 0.92),
                Color(red: 0.93, green: 0.94, blue: 0.98),
                Color(red: 0.98, green: 0.94, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .sunny),
            headline: HomeDashboardViewModel.WeatherKind.sunny.rawValue,
            reminder: "紫外线较强，注意防晒",
            secondaryNote: "早晚温差大",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Cloudy Static") {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.96, blue: 0.98),
                Color(red: 0.90, green: 0.93, blue: 0.97),
                Color(red: 0.96, green: 0.94, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .partlyCloudy),
            headline: HomeDashboardViewModel.WeatherKind.partlyCloudy.rawValue,
            reminder: "早晚温差大，记得加件外套",
            secondaryNote: "体感 23°",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Light Rain Static") {
    ZStack {
        Color(red: 0.92, green: 0.94, blue: 0.97).ignoresSafeArea()
        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .drizzle),
            headline: HomeDashboardViewModel.WeatherKind.drizzle.rawValue,
            reminder: "记得带伞，鞋子尽量选择防滑款",
            secondaryNote: "体感 20°",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Overcast Static") {
    ZStack {
        Color(red: 0.90, green: 0.92, blue: 0.95).ignoresSafeArea()
        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .overcast),
            headline: HomeDashboardViewModel.WeatherKind.overcast.rawValue,
            reminder: "天色偏阴，建议用亮一点的单品提气色",
            secondaryNote: "空气湿度较高",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Heavy Rain Static") {
    ZStack {
        Color(red: 0.85, green: 0.88, blue: 0.92).ignoresSafeArea()
        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .heavyRain),
            headline: HomeDashboardViewModel.WeatherKind.heavyRain.rawValue,
            reminder: "雨天路滑，优先防水外套和防滑鞋",
            secondaryNote: "出门记得带伞",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Windy Static") {
    ZStack {
        Color(red: 0.92, green: 0.95, blue: 0.98).ignoresSafeArea()
        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .windy),
            headline: HomeDashboardViewModel.WeatherKind.windy.rawValue,
            reminder: "风力较大，注意防风保暖",
            secondaryNote: "高空坠物，注意安全",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Thunderstorm Static") {
    ZStack {
        Color(red: 0.86, green: 0.89, blue: 0.93).ignoresSafeArea()
        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .thunderstorm),
            headline: HomeDashboardViewModel.WeatherKind.thunderstorm.rawValue,
            reminder: "注意雷雨天气，尽量减少久留室外",
            secondaryNote: "体感 17°",
            isAnimationActive: false
        )
        .padding(20)
    }
}

#Preview("Sunny Animated") {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.95, blue: 0.92),
                Color(red: 0.93, green: 0.94, blue: 0.98),
                Color(red: 0.98, green: 0.94, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WeatherCardView(
            weather: HomeDashboardViewModel.mockWeather(for: .sunny),
            headline: HomeDashboardViewModel.WeatherKind.sunny.rawValue,
            reminder: "紫外线较强，注意防晒",
            secondaryNote: "第二阶段再继续加强动画层",
            isAnimationActive: true
        )
        .padding(20)
    }
}
