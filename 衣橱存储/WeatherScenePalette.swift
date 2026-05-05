import SwiftUI

/// Per-kind palette + intensity knobs for the weather scene.
///
/// All colors and counts live here so individual layers stay
/// stylistically coherent — change a single value and every layer that
/// reads it reacts together.
struct WeatherScenePalette {
    let kind: HomeDashboardViewModel.WeatherKind

    // MARK: - Sky

    var skyGradient: [Color] {
        switch kind {
        case .sunny:
            return [
                Color(red: 0.36, green: 0.66, blue: 0.95),
                Color(red: 0.62, green: 0.84, blue: 0.99),
                Color(red: 0.98, green: 0.91, blue: 0.74)
            ]
        case .partlyCloudy:
            return [
                Color(red: 0.40, green: 0.66, blue: 0.92),
                Color(red: 0.68, green: 0.82, blue: 0.96),
                Color(red: 0.93, green: 0.95, blue: 0.99)
            ]
        case .overcast:
            return [
                Color(red: 0.40, green: 0.49, blue: 0.60),
                Color(red: 0.60, green: 0.68, blue: 0.78),
                Color(red: 0.85, green: 0.89, blue: 0.94)
            ]
        case .drizzle:
            return [
                Color(red: 0.42, green: 0.55, blue: 0.70),
                Color(red: 0.62, green: 0.75, blue: 0.86),
                Color(red: 0.88, green: 0.92, blue: 0.97)
            ]
        case .heavyRain:
            return [
                Color(red: 0.18, green: 0.26, blue: 0.36),
                Color(red: 0.36, green: 0.46, blue: 0.58),
                Color(red: 0.66, green: 0.76, blue: 0.86)
            ]
        case .thunderstorm:
            return [
                Color(red: 0.10, green: 0.13, blue: 0.22),
                Color(red: 0.24, green: 0.30, blue: 0.42),
                Color(red: 0.50, green: 0.58, blue: 0.74)
            ]
        case .windy:
            return [
                Color(red: 0.46, green: 0.66, blue: 0.86),
                Color(red: 0.74, green: 0.86, blue: 0.96),
                Color(red: 0.94, green: 0.97, blue: 1.00)
            ]
        case .snow:
            return [
                Color(red: 0.46, green: 0.58, blue: 0.72),
                Color(red: 0.72, green: 0.82, blue: 0.92),
                Color(red: 0.94, green: 0.96, blue: 0.99)
            ]
        }
    }

    // MARK: - Sun visibility

    /// 0…1 — how visible the sun is. Drives disc opacity, glow, lens flare.
    var sunVisibility: Double {
        switch kind {
        case .sunny: 1.0
        case .partlyCloudy: 0.42
        case .windy: 0.16
        case .overcast, .drizzle, .snow: 0.0
        case .heavyRain, .thunderstorm: 0.0
        }
    }

    var sunWarmth: Double { kind == .sunny ? 1.0 : (kind == .partlyCloudy ? 0.66 : 0.0) }

    // MARK: - Cloud configuration

    var cloudOpacity: Double {
        switch kind {
        case .sunny: 0.48
        case .partlyCloudy: 0.78
        case .overcast: 0.92
        case .drizzle: 0.86
        case .heavyRain: 0.96
        case .thunderstorm: 1.0
        case .windy: 0.62
        case .snow: 0.84
        }
    }

    var cloudTint: Color {
        switch kind {
        case .sunny, .partlyCloudy, .windy, .snow:
            Color.white
        case .overcast, .drizzle:
            Color(red: 0.92, green: 0.94, blue: 0.97)
        case .heavyRain:
            Color(red: 0.78, green: 0.82, blue: 0.88)
        case .thunderstorm:
            Color(red: 0.62, green: 0.66, blue: 0.78)
        }
    }

    /// Whether the partlyCloudy hero cloud should occlude the sun.
    var cloudOccludesSun: Bool { kind == .partlyCloudy }

    // MARK: - Precipitation

    enum Precipitation {
        case none
        case rain(intensity: Double)
        case snow(intensity: Double)
    }

    var precipitation: Precipitation {
        switch kind {
        case .drizzle: .rain(intensity: 0.4)
        case .heavyRain: .rain(intensity: 0.85)
        case .thunderstorm: .rain(intensity: 1.0)
        case .snow: .snow(intensity: 1.0)
        default: .none
        }
    }

    // MARK: - Atmospheric effects

    var hasMist: Bool {
        switch kind {
        case .overcast, .drizzle, .snow: true
        default: false
        }
    }

    var mistIntensity: Double {
        switch kind {
        case .overcast: 0.32
        case .drizzle: 0.20
        case .snow: 0.18
        default: 0.0
        }
    }

    var hasVolumetricLight: Bool {
        kind == .sunny || kind == .partlyCloudy
    }

    var hasFloatingDust: Bool {
        kind == .sunny || kind == .windy || kind == .partlyCloudy
    }

    // MARK: - Wind

    var windStreaks: Bool { kind == .windy }

    /// Global "wind drift" multiplier. Used by clouds to drift faster
    /// in windy conditions and slower in calm.
    var windSpeed: Double {
        switch kind {
        case .sunny, .partlyCloudy: 1.0
        case .overcast, .drizzle: 0.84
        case .heavyRain: 1.6
        case .thunderstorm: 1.8
        case .windy: 2.6
        case .snow: 0.66
        }
    }

    // MARK: - Storm

    var hasLightning: Bool { kind == .thunderstorm }

    // MARK: - Density caps (for performance gating)

    var rainParticleCount: Int {
        switch kind {
        case .drizzle: 14
        case .heavyRain: 26
        case .thunderstorm: 30
        default: 0
        }
    }

    var snowParticleCount: Int {
        kind == .snow ? 36 : 0
    }
}
