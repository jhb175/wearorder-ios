import SwiftUI

/// Compose-style layered renderer: each layer is its own Canvas, fed
/// the same `WeatherScenePalette`. The palette decides what the layer
/// draws (or suppresses entirely), so swapping a kind cleanly
/// reconfigures every layer in unison.
///
/// Frame rate is 30fps (1.0/30.0), up from the legacy 12fps. SwiftUI
/// pauses TimelineView when the host is offscreen, and the home tab
/// uses `deferredTab` so this view isn't even instantiated when the
/// user is on another tab.
struct WeatherScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: HomeDashboardViewModel.WeatherKind
    var windSpeedKPH: Int? = nil
    var isActive: Bool = true

    var body: some View {
        if shouldAnimate {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                composedScene(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            composedScene(time: 0)
        }
    }

    private var shouldAnimate: Bool {
        isActive && !reduceMotion
    }

    private func composedScene(time: TimeInterval) -> some View {
        let palette = WeatherScenePalette(kind: kind, windSpeedKPH: windSpeedKPH)
        return ZStack {
            WeatherSkyLayer(palette: palette, time: time)
            WeatherCloudSystem(palette: palette, time: time)
            WeatherAtmosphericEffects(palette: palette, time: time)
            WeatherPrecipitationSystem(palette: palette, time: time)
            WeatherStormEffects(palette: palette, time: time)
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Sunny") {
    WeatherScene(kind: .sunny)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("PartlyCloudy") {
    WeatherScene(kind: .partlyCloudy)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Overcast") {
    WeatherScene(kind: .overcast)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Drizzle") {
    WeatherScene(kind: .drizzle)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Heavy Rain") {
    WeatherScene(kind: .heavyRain)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Thunderstorm") {
    WeatherScene(kind: .thunderstorm)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Windy") {
    WeatherScene(kind: .windy)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("Snow") {
    WeatherScene(kind: .snow)
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.black)
}

#Preview("All weather grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(HomeDashboardViewModel.WeatherKind.allCases) { kind in
                VStack(spacing: 6) {
                    WeatherScene(kind: kind)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(kind.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .background(Color.black.ignoresSafeArea())
}
