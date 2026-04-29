import SwiftUI

struct WeatherDetailView: View {
    let weather: HomeDashboardViewModel.WeatherSnapshot?
    let headline: String
    let reminder: String
    let secondaryNote: String
    let sourceLabel: String

    private var displayWeather: HomeDashboardViewModel.WeatherSnapshot {
        weather ?? HomeDashboardViewModel.placeholderWeather
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                if weather != nil {
                    hourlyForecastSection
                    dailyForecastSection
                    weatherDetailsGrid
                    WeatherAttributionBlock(weather: displayWeather)
                } else {
                    emptyForecastState
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .background(weatherDetailBackground)
        .navigationTitle("天气穿搭")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weatherDetailBackground: some View {
        AppAdaptiveBackground()
    }

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            WeatherAnimationView(kind: displayWeather.kind, isActive: weather != nil)
                .opacity(0.96)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.10),
                    Color.white.opacity(0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 18) {
                Label(sourceLabel, systemImage: displayWeather.symbolName ?? displayWeather.kind.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(weather.map { "\($0.temperature)°" } ?? "--°")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(.white)

                    Text("体感 \(weather?.apparentTemperature ?? displayWeather.apparentTemperature)° · 最高 \(displayWeather.high)° / 最低 \(displayWeather.low)°")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("今日穿搭判断")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(reminder)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(secondaryNote)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }

    private var hourlyForecastSection: some View {
        WeatherGlassSection(title: "小时预报", subtitle: "温度、降水和风速") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(displayWeather.hourlyForecast) { hour in
                        VStack(spacing: 9) {
                            Text(hour.date.formatted(.dateTime.hour()))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: hour.symbolName)
                                .font(.title3.weight(.semibold))
                                .symbolRenderingMode(.multicolor)
                                .frame(height: 24)
                            Text("\(hour.temperature)°")
                                .font(.headline.weight(.bold))
                            Label("\(hour.precipitationChance)%", systemImage: "drop.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(hour.windSpeed)km/h")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 72)
                        .padding(.vertical, 12)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 24)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var dailyForecastSection: some View {
        WeatherGlassSection(title: "10 日趋势", subtitle: "提前安排 OOTD 和计划") {
            VStack(spacing: 10) {
                ForEach(displayWeather.dailyForecast) { day in
                    HStack(spacing: 12) {
                        Text(dayLabel(for: day.date))
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 54, alignment: .leading)

                        Image(systemName: day.symbolName)
                            .font(.title3)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 28)

                        Label("\(day.precipitationChance)%", systemImage: "drop.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .leading)

                        Spacer()

                        Text("\(day.low)°")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.28), .orange.opacity(0.48)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: 78, height: 6)
                        Text("\(day.high)°")
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .homeCardSurface(weight: .tertiary, cornerRadius: 18)
                }
            }
        }
    }

    private var weatherDetailsGrid: some View {
        WeatherGlassSection(title: "穿搭指标", subtitle: "只保留和出门决策有关的信息") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WeatherDetailMetricCard(title: "体感", value: "\(displayWeather.apparentTemperature)°", symbol: "thermometer.medium")
                WeatherDetailMetricCard(title: "湿度", value: "\(displayWeather.humidity)%", symbol: "humidity.fill")
                WeatherDetailMetricCard(title: "风速", value: "\(displayWeather.windSpeed)km/h", symbol: "wind")
                WeatherDetailMetricCard(title: "降水", value: displayWeather.precipitationChance.map { "\($0)%" } ?? "--", symbol: "umbrella.percent")
                WeatherDetailMetricCard(title: "紫外线", value: displayWeather.uvIndex.map { "\($0)" } ?? "--", symbol: "sun.max.fill")
                WeatherDetailMetricCard(title: "温差", value: "\(displayWeather.high - displayWeather.low)°", symbol: "arrow.up.and.down")
            }
        }
    }

    private var emptyForecastState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有真实天气")
                .font(.headline)
            Text("回到首页授权定位或选择城市后，这里会展示 Apple Weather 的小时预报、10 日趋势和穿搭指标。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "明天"
        }

        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct WeatherGlassSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            content
        }
        .padding(16)
        .glassCard(cornerRadius: 28, tint: Color.white.opacity(0.15))
    }
}

private struct WeatherDetailMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.86))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .tracking(0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: 22)
    }
}

private struct WeatherAttributionBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let weather: HomeDashboardViewModel.WeatherSnapshot

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: markURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Text(weather.providerName)
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: 148, maxHeight: 20, alignment: .leading)

            Spacer(minLength: 8)

            if let legalURL = weather.providerLegalURL {
                Link("数据来源", destination: legalURL)
                    .font(.caption.weight(.semibold))
            } else {
                Text("天气数据")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .foregroundStyle(.secondary)
    }

    private var markURL: URL? {
        colorScheme == .dark ? weather.providerMarkLightURL : weather.providerMarkDarkURL
    }
}

#Preview("Weather Detail") {
    NavigationStack {
        WeatherDetailView(
            weather: HomeDashboardViewModel.mockWeather(for: .partlyCloudy),
            headline: "多云",
            reminder: "早晚温差大，记得加件外套",
            secondaryNote: "体感 23°",
            sourceLabel: "Apple Weather"
        )
    }
}
