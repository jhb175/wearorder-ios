import SwiftUI

/// Side-by-side comparison wrapper. Reuses the existing
/// `WeatherAnimationView` engine and overlays the three biggest gaps
/// identified in the review: snow particles, drifting mist, and
/// volumetric light. This is **preview-only** — production still
/// renders the original `WeatherAnimationView` until we decide to
/// land any of these changes.
struct WeatherAnimationViewEnhanced: View {
    let kind: HomeDashboardViewModel.WeatherKind
    var isActive: Bool = true

    var body: some View {
        ZStack {
            WeatherAnimationView(kind: kind, isActive: isActive)

            switch kind {
            case .snow:
                WeatherSnowLayer(isActive: isActive)
            case .overcast:
                WeatherMistLayer(intensity: .dense, isActive: isActive)
            case .drizzle:
                WeatherMistLayer(intensity: .soft, isActive: isActive)
            case .sunny:
                WeatherVolumetricLightLayer(warmth: 1.0, isActive: isActive)
            case .partlyCloudy:
                WeatherVolumetricLightLayer(warmth: 0.55, isActive: isActive)
            case .windy, .heavyRain, .thunderstorm:
                EmptyView()
            }
        }
    }
}

// MARK: - Side-by-side preview gallery

private struct ComparisonRow: View {
    let title: String
    let kind: HomeDashboardViewModel.WeatherKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    WeatherAnimationView(kind: kind, isActive: true)
                        .frame(width: 178, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                        )
                    Text("现有")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(spacing: 6) {
                    WeatherAnimationViewEnhanced(kind: kind, isActive: true)
                        .frame(width: 178, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.30), lineWidth: 0.8)
                        )
                    Text("增强")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}

#Preview("现有 vs 增强 - 全部天气") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("天气动画对比")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("左：当前生产代码 · 右：增强版（雪粒子 / 雾漂移 / 体积光）")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            ComparisonRow(title: "晴 sunny — 体积光 + 尘埃", kind: .sunny)
            ComparisonRow(title: "多云 partlyCloudy — 暖度更低的体积光", kind: .partlyCloudy)
            ComparisonRow(title: "阴 overcast — 雾层漂移", kind: .overcast)
            ComparisonRow(title: "小雨 drizzle — 轻雾层", kind: .drizzle)
            ComparisonRow(title: "雪 snow — 28 颗多深度雪花（致命缺口）", kind: .snow)
            ComparisonRow(title: "大雨 heavyRain — 无变化（已经够好）", kind: .heavyRain)
            ComparisonRow(title: "雷暴 thunderstorm — 无变化（已经够好）", kind: .thunderstorm)
            ComparisonRow(title: "大风 windy — 无变化（已经够好）", kind: .windy)
        }
        .padding(20)
    }
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.13, blue: 0.20),
                Color(red: 0.18, green: 0.22, blue: 0.32)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    )
}

#Preview("雪 snow — 全宽") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                WeatherAnimationView(kind: .snow, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("现有 .snow（无任何雪粒子）").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            VStack(spacing: 8) {
                WeatherAnimationViewEnhanced(kind: .snow, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("增强 .snow（28 颗雪花 + 多深度模糊）").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
    }
}

#Preview("晴 sunny — 全宽") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                WeatherAnimationView(kind: .sunny, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("现有 .sunny（仅静态 7 道光线）").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            VStack(spacing: 8) {
                WeatherAnimationViewEnhanced(kind: .sunny, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("增强 .sunny（5 道脉动锥形体积光 + 飞尘）").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
    }
}

#Preview("阴 overcast — 全宽") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                WeatherAnimationView(kind: .overcast, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("现有 .overcast（仅静态径向光晕）").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            VStack(spacing: 8) {
                WeatherAnimationViewEnhanced(kind: .overcast, isActive: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("增强 .overcast（5 层雾漂移）").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
    }
}
