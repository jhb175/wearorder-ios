import SwiftUI

struct WeatherAnimationView: View {
    let kind: HomeDashboardViewModel.WeatherKind
    var isActive: Bool = true

    var body: some View {
        Group {
            if isActive {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    weatherCanvas(time: timeline.date.timeIntervalSinceReferenceDate, animated: true)
                }
            } else {
                weatherCanvas(time: 0, animated: false)
            }
        }
        .compositingGroup()
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func weatherCanvas(time: TimeInterval, animated: Bool) -> some View {
        Canvas { context, size in
            drawBaseAtmosphere(in: context, size: size, time: time)
            drawCloudLayer(in: context, size: size, time: time, layer: .far)
            drawSunGlowIfNeeded(in: context, size: size, time: time, animated: animated)
            drawHeroCloudCompositionIfNeeded(in: context, size: size, time: time, animated: animated)
            drawCloudLayer(in: context, size: size, time: time, layer: .mid)
            drawCloudLayer(in: context, size: size, time: time, layer: .near)
            drawMistIfNeeded(in: context, size: size, time: time)
            drawRainIfNeeded(in: context, size: size, time: time, animated: animated)
            drawWindIfNeeded(in: context, size: size, time: time, animated: animated)
            drawFloatingParticlesIfNeeded(in: context, size: size, time: time, animated: animated)
            drawLightningIfNeeded(in: context, size: size, time: time, animated: animated)
        }
    }

    private func drawBaseAtmosphere(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let rect = CGRect(origin: .zero, size: size)

        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: backgroundColors),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )

        let glowCenter = CGPoint(
            x: size.width * (kind == .sunny || kind == .partlyCloudy ? 0.74 : 0.70) + CGFloat(sin(time * 0.08) * 8),
            y: size.height * 0.24 + CGFloat(cos(time * 0.11) * 6)
        )
        let glowRect = CGRect(x: glowCenter.x - 92, y: glowCenter.y - 92, width: 184, height: 184)

        let primaryGlowOpacity: Double
        let secondaryGlowOpacity: Double

        switch kind {
        case .sunny:
            primaryGlowOpacity = 0.34
            secondaryGlowOpacity = 0.14
        case .partlyCloudy:
            primaryGlowOpacity = 0.22
            secondaryGlowOpacity = 0.08
        case .windy:
            primaryGlowOpacity = 0.12
            secondaryGlowOpacity = 0.04
        case .overcast, .drizzle, .snow:
            primaryGlowOpacity = 0.07
            secondaryGlowOpacity = 0.02
        case .heavyRain:
            primaryGlowOpacity = 0.04
            secondaryGlowOpacity = 0.01
        case .thunderstorm:
            primaryGlowOpacity = 0.03
            secondaryGlowOpacity = 0.0
        }

        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    glowColor.opacity(primaryGlowOpacity),
                    glowColor.opacity(secondaryGlowOpacity),
                    .clear
                ]),
                center: glowCenter,
                startRadius: 8,
                endRadius: 112
            )
        )
    }

    private func drawSunGlowIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        guard kind == .sunny || kind == .partlyCloudy else { return }

        let center = CGPoint(
            x: size.width * 0.76 + (animated ? CGFloat(sin(time * 0.10) * 8) : 0),
            y: size.height * 0.23 + (animated ? CGFloat(cos(time * 0.12) * 6) : 0)
        )
        let skyWashRect = CGRect(x: size.width * 0.34, y: -size.height * 0.04, width: size.width * 0.78, height: size.height * 0.82)
        let outerRect = CGRect(x: center.x - 156, y: center.y - 156, width: 312, height: 312)
        let midRect = CGRect(x: center.x - 104, y: center.y - 104, width: 208, height: 208)
        let innerRect = CGRect(x: center.x - 62, y: center.y - 62, width: 124, height: 124)
        let coreRect = CGRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84)
        let coreHaloRect = CGRect(x: center.x - 52, y: center.y - 52, width: 104, height: 104)
        let contrastRect = CGRect(x: center.x - 84, y: center.y - 84, width: 168, height: 168)
        let innerOpacity = kind == .sunny ? 0.54 : 0.26

        context.fill(
            Path(ellipseIn: skyWashRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.93, blue: 0.72).opacity(kind == .sunny ? 0.40 : 0.20),
                    Color(red: 1.0, green: 0.95, blue: 0.80).opacity(kind == .sunny ? 0.22 : 0.12),
                    .clear
                ]),
                center: CGPoint(x: skyWashRect.midX, y: skyWashRect.minY + skyWashRect.height * 0.34),
                startRadius: 12,
                endRadius: skyWashRect.width * 0.56
            )
        )

        drawSunStreaks(in: context, center: center, time: time, animated: animated)

        context.fill(
            Path(ellipseIn: outerRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.91, blue: 0.63).opacity(innerOpacity),
                    Color(red: 1.0, green: 0.95, blue: 0.78).opacity(kind == .sunny ? 0.28 : 0.14),
                    .clear
                ]),
                center: center,
                startRadius: 2,
                endRadius: 134
            )
        )

        context.fill(
            Path(ellipseIn: midRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.98, blue: 0.86).opacity(kind == .sunny ? 0.42 : 0.22),
                    Color.white.opacity(kind == .sunny ? 0.14 : 0.10),
                    .clear
                ]),
                center: center,
                startRadius: 4,
                endRadius: 88
            )
        )

        context.fill(
            Path(ellipseIn: innerRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(kind == .sunny ? 0.74 : 0.42),
                    Color.white.opacity(kind == .sunny ? 0.22 : 0.18),
                    .clear
                ]),
                center: center,
                startRadius: 2,
                endRadius: 52
            )
        )

        context.fill(
            Path(ellipseIn: contrastRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.95, green: 0.77, blue: 0.30).opacity(kind == .sunny ? 0.24 : 0.12),
                    Color(red: 0.98, green: 0.90, blue: 0.56).opacity(kind == .sunny ? 0.10 : 0.08),
                    .clear
                ]),
                center: center,
                startRadius: 18,
                endRadius: 70
            )
        )

        context.stroke(
            Path(ellipseIn: coreHaloRect),
            with: .color(Color.white.opacity(kind == .sunny ? 0.34 : 0.18)),
            lineWidth: kind == .sunny ? 2.8 : 1.8
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(kind == .sunny ? 0.96 : 0.72),
                    Color(red: 1.0, green: 0.95, blue: 0.72).opacity(kind == .sunny ? 0.92 : 0.58),
                    Color(red: 0.98, green: 0.79, blue: 0.34).opacity(kind == .sunny ? 0.82 : 0.40)
                ]),
                center: center,
                startRadius: 2,
                endRadius: 34
            )
        )

        let occluderCenter = CGPoint(
            x: center.x - size.width * 0.08 + (animated ? CGFloat(sin(time * 0.14 + 0.8) * 6) : 0),
            y: center.y + size.height * 0.07 + (animated ? CGFloat(cos(time * 0.10 + 0.4) * 4) : 0)
        )

        drawCloud(
            in: context,
            center: occluderCenter,
            scale: kind == .sunny ? 1.12 : 0.98,
            opacity: kind == .sunny ? 0.52 : 0.38,
            blur: kind == .sunny ? 4 : 6,
            stretch: 1.08,
            variant: .sunCumulus
        )

        drawCloud(
            in: context,
            center: CGPoint(x: occluderCenter.x + size.width * 0.09, y: occluderCenter.y - size.height * 0.02),
            scale: kind == .sunny ? 0.78 : 0.68,
            opacity: kind == .sunny ? 0.30 : 0.24,
            blur: 9,
            stretch: 1.18,
            variant: .veil
        )
    }

    private func drawSunStreaks(in context: GraphicsContext, center: CGPoint, time: TimeInterval, animated: Bool) {
        for index in 0..<7 {
            let length: CGFloat = index % 2 == 0 ? 150 : 118
            let width: CGFloat = index % 2 == 0 ? 24 : 16
            let angle = -36.0 + Double(index) * 13.0 + (animated ? sin(time * 0.05 + Double(index)) * 1.8 : 0)
            let alpha = index % 2 == 0 ? 0.11 : 0.07

            var rayContext = context
            rayContext.translateBy(x: center.x, y: center.y)
            rayContext.rotate(by: .degrees(angle))

            let rayRect = CGRect(x: 10, y: -width * 0.5, width: length, height: width)
            rayContext.fill(
                Path(roundedRect: rayRect, cornerRadius: width * 0.5),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(alpha),
                        Color(red: 1.0, green: 0.92, blue: 0.66).opacity(alpha * 0.72),
                        .clear
                    ]),
                    startPoint: CGPoint(x: rayRect.minX, y: rayRect.midY),
                    endPoint: CGPoint(x: rayRect.maxX, y: rayRect.midY)
                )
            )
        }
    }

    private func drawHeroCloudCompositionIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        switch kind {
        case .partlyCloudy:
            let lightRect = CGRect(
                x: size.width * 0.46,
                y: size.height * 0.02,
                width: size.width * 0.48,
                height: size.height * 0.58
            )

            context.fill(
                Path(ellipseIn: lightRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.24),
                        Color(red: 0.96, green: 0.97, blue: 1.0).opacity(0.16),
                        .clear
                    ]),
                    center: CGPoint(x: lightRect.midX, y: lightRect.minY + lightRect.height * 0.34),
                    startRadius: 12,
                    endRadius: lightRect.width * 0.44
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.73 + (animated ? CGFloat(sin(time * 0.12 + 0.6) * 7) : 0),
                y: size.height * 0.34 + (animated ? CGFloat(cos(time * 0.10 + 0.4) * 5) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.32,
                opacity: 0.60,
                blur: 4.5,
                stretch: 1.04,
                variant: .tower
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x + size.width * 0.14, y: heroCenter.y + size.height * 0.11),
                scale: 1.02,
                opacity: 0.32,
                blur: 7,
                stretch: 1.12,
                variant: .puff
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.13, y: heroCenter.y + size.height * 0.13),
                scale: 0.96,
                opacity: 0.24,
                blur: 9,
                stretch: 1.18,
                variant: .veil
            )

        case .drizzle:
            let washRect = CGRect(
                x: size.width * 0.40,
                y: size.height * 0.10,
                width: size.width * 0.58,
                height: size.height * 0.64
            )

            context.fill(
                Path(ellipseIn: washRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.12),
                        Color(red: 0.84, green: 0.90, blue: 0.97).opacity(0.10),
                        .clear
                    ]),
                    center: CGPoint(x: washRect.midX, y: washRect.midY * 0.92),
                    startRadius: 14,
                    endRadius: washRect.width * 0.42
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.70 + (animated ? CGFloat(sin(time * 0.10 + 0.5) * 7) : 0),
                y: size.height * 0.30 + (animated ? CGFloat(cos(time * 0.08 + 0.7) * 4) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.30,
                opacity: 0.56,
                blur: 5,
                stretch: 1.08,
                variant: .rainBand
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.13, y: heroCenter.y + size.height * 0.12),
                scale: 1.02,
                opacity: 0.32,
                blur: 8,
                stretch: 1.04,
                variant: .puff
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x + size.width * 0.13, y: heroCenter.y + size.height * 0.11),
                scale: 0.94,
                opacity: 0.22,
                blur: 10,
                stretch: 1.16,
                variant: .veil
            )

        case .overcast, .snow:
            let washRect = CGRect(
                x: size.width * 0.38,
                y: size.height * 0.02,
                width: size.width * 0.60,
                height: size.height * 0.70
            )

            context.fill(
                Path(ellipseIn: washRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.14),
                        Color(red: 0.78, green: 0.84, blue: 0.91).opacity(0.14),
                        .clear
                    ]),
                    center: CGPoint(x: washRect.midX, y: washRect.minY + washRect.height * 0.34),
                    startRadius: 12,
                    endRadius: washRect.width * 0.46
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.69 + (animated ? CGFloat(sin(time * 0.08 + 0.5) * 6) : 0),
                y: size.height * 0.31 + (animated ? CGFloat(cos(time * 0.07 + 0.8) * 4) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.40,
                opacity: 0.64,
                blur: 4.5,
                stretch: 1.14,
                variant: .shelf
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.15, y: heroCenter.y + size.height * 0.12),
                scale: 1.12,
                opacity: 0.34,
                blur: 7.5,
                stretch: 1.16,
                variant: .veil
            )

        case .heavyRain:
            let washRect = CGRect(
                x: size.width * 0.36,
                y: size.height * 0.06,
                width: size.width * 0.62,
                height: size.height * 0.72
            )

            context.fill(
                Path(ellipseIn: washRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.10),
                        Color(red: 0.68, green: 0.76, blue: 0.86).opacity(0.10),
                        .clear
                    ]),
                    center: CGPoint(x: washRect.midX, y: washRect.minY + washRect.height * 0.30),
                    startRadius: 12,
                    endRadius: washRect.width * 0.44
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.68 + (animated ? CGFloat(sin(time * 0.11 + 0.6) * 6) : 0),
                y: size.height * 0.30 + (animated ? CGFloat(cos(time * 0.09 + 0.3) * 4) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.36,
                opacity: 0.60,
                blur: 5,
                stretch: 1.08,
                variant: .stormBand
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.14, y: heroCenter.y + size.height * 0.14),
                scale: 1.02,
                opacity: 0.32,
                blur: 9,
                stretch: 1.10,
                variant: .rainBand
            )

        case .thunderstorm:
            let washRect = CGRect(
                x: size.width * 0.34,
                y: size.height * 0.02,
                width: size.width * 0.64,
                height: size.height * 0.74
            )

            context.fill(
                Path(ellipseIn: washRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.10),
                        Color(red: 0.66, green: 0.74, blue: 0.86).opacity(0.08),
                        .clear
                    ]),
                    center: CGPoint(x: washRect.midX, y: washRect.minY + washRect.height * 0.28),
                    startRadius: 12,
                    endRadius: washRect.width * 0.42
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.70 + (animated ? CGFloat(sin(time * 0.10 + 0.4) * 5) : 0),
                y: size.height * 0.26 + (animated ? CGFloat(cos(time * 0.08 + 0.9) * 4) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.46,
                opacity: 0.66,
                blur: 4.5,
                stretch: 1.12,
                variant: .stormBand
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x + size.width * 0.10, y: heroCenter.y + size.height * 0.12),
                scale: 1.10,
                opacity: 0.34,
                blur: 7.5,
                stretch: 1.10,
                variant: .shelf
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.09, y: heroCenter.y + size.height * 0.16),
                scale: 0.94,
                opacity: 0.24,
                blur: 8.0,
                stretch: 1.06,
                variant: .rainBand
            )

        case .windy:
            let washRect = CGRect(
                x: size.width * 0.42,
                y: size.height * 0.00,
                width: size.width * 0.58,
                height: size.height * 0.70
            )

            context.fill(
                Path(ellipseIn: washRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.16),
                        Color(red: 0.90, green: 0.95, blue: 0.99).opacity(0.10),
                        .clear
                    ]),
                    center: CGPoint(x: washRect.midX, y: washRect.minY + washRect.height * 0.30),
                    startRadius: 12,
                    endRadius: washRect.width * 0.46
                )
            )

            let heroCenter = CGPoint(
                x: size.width * 0.68 + (animated ? CGFloat(sin(time * 0.18 + 0.7) * 10) : 0),
                y: size.height * 0.30 + (animated ? CGFloat(cos(time * 0.10 + 0.5) * 4) : 0)
            )

            drawCloud(
                in: context,
                center: heroCenter,
                scale: 1.16,
                opacity: 0.44,
                blur: 6,
                stretch: 1.18,
                variant: .rainBand
            )

            drawCloud(
                in: context,
                center: CGPoint(x: heroCenter.x - size.width * 0.18, y: heroCenter.y + size.height * 0.10),
                scale: 0.94,
                opacity: 0.22,
                blur: 9,
                stretch: 1.28,
                variant: .veil
            )

        default:
            break
        }
    }

    private func drawCloudLayer(in context: GraphicsContext, size: CGSize, time: TimeInterval, layer: CloudLayer) {
        let specs = cloudSpecs(for: layer)
        let amplitudeX = size.width * layer.xAmplitude
        let amplitudeY = size.height * layer.yAmplitude

        for (index, spec) in specs.enumerated() {
            let phase = Double(index) * 0.9 + layer.phaseOffset
            let x = size.width * spec.x + CGFloat(sin(time * layer.speed + phase) * amplitudeX)
            let y = size.height * spec.y + CGFloat(cos(time * (layer.speed * 0.72) + phase) * amplitudeY)
            let scale = spec.scale * layer.scaleMultiplier
            let alphaBoost: Double
            let blurScale: CGFloat

            if kind == .sunny || kind == .partlyCloudy {
                if layer == .far {
                    alphaBoost = 1.20
                    blurScale = 0.58
                } else if layer == .mid {
                    alphaBoost = 1.46
                    blurScale = 0.46
                } else {
                    alphaBoost = 1.58
                    blurScale = 0.34
                }
            } else {
                if layer == .far {
                    alphaBoost = 1.10
                    blurScale = 0.76
                } else if layer == .mid {
                    alphaBoost = 1.18
                    blurScale = 0.66
                } else {
                    alphaBoost = 1.24
                    blurScale = 0.56
                }
            }

            let alpha = min(layer.opacity * spec.opacityMultiplier * alphaBoost, 0.82)
            let blur = max(layer.blur * blurScale, 2.8)

            drawCloud(
                in: context,
                center: CGPoint(x: x, y: y),
                scale: scale,
                opacity: alpha,
                blur: blur,
                stretch: layer.stretch,
                variant: spec.variant
            )
        }
    }

    private func drawMistIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let mistOpacity: Double

        switch kind {
        case .overcast, .snow:
            mistOpacity = 0.16
        case .drizzle:
            mistOpacity = 0.18
        case .heavyRain, .thunderstorm:
            mistOpacity = 0.14
        default:
            mistOpacity = 0.08
        }

        let rect = CGRect(
            x: size.width * 0.18 + CGFloat(sin(time * 0.06) * 10),
            y: size.height * 0.46 + CGFloat(cos(time * 0.05) * 6),
            width: size.width * 0.78,
            height: size.height * 0.34
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(mistOpacity),
                    Color.white.opacity(mistOpacity * 0.35),
                    .clear
                ]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 12,
                endRadius: rect.width * 0.52
            )
        )
    }

    private func drawRainIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        let intensity: Int
        let opacity: Double
        let lineWidth: CGFloat
        let speed: Double
        let length: CGFloat
        let slope: CGFloat
        let sway: CGFloat

        switch kind {
        case .drizzle:
            intensity = 12
            opacity = 0.34
            lineWidth = 1.05
            speed = 92
            length = 20
            slope = 8
            sway = 1.8
        case .heavyRain:
            intensity = 18
            opacity = 0.40
            lineWidth = 1.2
            speed = 132
            length = 30
            slope = 11
            sway = 2.4
        case .thunderstorm:
            intensity = 18
            opacity = 0.36
            lineWidth = 1.15
            speed = 142
            length = 30
            slope = 11
            sway = 2.6
        default:
            return
        }

        let backLayerCount = max(intensity / 2, 6)
        let frontLayerCount = intensity

        drawRainLayer(
            in: context,
            size: size,
            time: time,
            animated: animated,
            count: backLayerCount,
            xStart: 0.46,
            xSpan: 0.42,
            opacity: opacity * 0.34,
            lineWidth: max(lineWidth - 0.35, 0.7),
            baseSpeed: speed * 0.82,
            baseLength: length + 10,
            baseSlope: slope + 2,
            sway: sway * 0.7,
            secondaryStaticTrail: false,
            clustered: kind != .drizzle,
            bandCenters: kind == .drizzle ? [] : [0.60, 0.76]
        )

        drawRainLayer(
            in: context,
            size: size,
            time: time,
            animated: animated,
            count: frontLayerCount,
            xStart: 0.50,
            xSpan: 0.38,
            opacity: opacity,
            lineWidth: lineWidth,
            baseSpeed: speed,
            baseLength: length,
            baseSlope: slope,
            sway: sway,
            secondaryStaticTrail: !animated && kind != .drizzle,
            clustered: kind != .drizzle,
            bandCenters: kind == .thunderstorm ? [0.58, 0.72, 0.84] : (kind == .heavyRain ? [0.60, 0.78] : [])
        )
    }

    private func drawRainLayer(
        in context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        animated: Bool,
        count: Int,
        xStart: CGFloat,
        xSpan: CGFloat,
        opacity: Double,
        lineWidth: CGFloat,
        baseSpeed: Double,
        baseLength: CGFloat,
        baseSlope: CGFloat,
        sway: CGFloat,
        secondaryStaticTrail: Bool,
        clustered: Bool,
        bandCenters: [CGFloat]
    ) {
        for index in 0..<count {
            let normalized = CGFloat(index) / CGFloat(max(count - 1, 1))
            let xNormalized = xStart + normalized * xSpan
            let bandWeight: CGFloat
            if clustered, let nearestCenter = bandCenters.min(by: { abs($0 - xNormalized) < abs($1 - xNormalized) }) {
                let distance = abs(nearestCenter - xNormalized)
                let falloff = max(0, 1 - distance / 0.14)
                bandWeight = 0.72 + falloff * 0.52
            } else if clustered {
                let bandPhase = normalized * .pi * 1.2
                bandWeight = 0.72 + abs(sin(bandPhase)) * 0.30
            } else {
                bandWeight = 1.0
            }

            let xSeed = size.width * xNormalized
            let laneOffset = CGFloat(index % 3) * 4 - 4
            let phase = Double(index) * 0.37
            let x = xSeed + laneOffset + (animated ? CGFloat(sin(time * 0.24 + phase) * sway) : 0)
            let travel: CGFloat
            let dropLength: CGFloat
            let dropOpacity: Double
            let localSlope: CGFloat

            if animated {
                let speedVariance = 0.88 + Double(index % 5) * 0.06
                let stagger = Double(index * 23)
                let range = Double(size.height + 120)
                travel = CGFloat((time * baseSpeed * speedVariance + stagger).truncatingRemainder(dividingBy: range)) - 60
                dropLength = baseLength + CGFloat(index % 3) * 4 + (clustered ? CGFloat(abs(sin(Double(index) * 0.5)) * 5) : 0)
                dropOpacity = opacity * (0.78 + Double(index % 4) * 0.06) * Double(clustered ? bandWeight : 1.0)
                localSlope = baseSlope + CGFloat(sin(time * 0.30 + phase) * 1.4)
            } else {
                travel = size.height * (0.14 + normalized * 0.68)
                dropLength = baseLength + CGFloat((index % 2) * 4) + (clustered ? CGFloat(abs(sin(Double(index) * 0.4)) * 4) : 0)
                dropOpacity = opacity * (0.72 + Double(index % 4) * 0.08) * Double(clustered ? bandWeight : 1.0)
                localSlope = baseSlope
            }

            let start = CGPoint(x: x, y: travel)
            let mid = CGPoint(x: x - localSlope * 0.52, y: travel + dropLength * 0.54)
            let end = CGPoint(x: x - localSlope, y: travel + dropLength)

            var path = Path()
            path.move(to: start)
            path.addQuadCurve(
                to: end,
                control: CGPoint(x: mid.x, y: mid.y - dropLength * 0.08)
            )

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(0.02), location: 0.0),
                        .init(color: Color.white.opacity(dropOpacity * 0.42), location: 0.28),
                        .init(color: Color.white.opacity(dropOpacity), location: 1.0)
                    ]),
                    startPoint: start,
                    endPoint: end
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            if secondaryStaticTrail {
                var secondaryPath = Path()
                secondaryPath.move(to: CGPoint(x: start.x + 6, y: start.y - 10))
                secondaryPath.addLine(to: CGPoint(x: end.x + 4, y: end.y - 8))
                context.stroke(
                    secondaryPath,
                    with: .color(Color.white.opacity(dropOpacity * 0.34)),
                    style: StrokeStyle(lineWidth: max(lineWidth - 0.2, 0.8), lineCap: .round)
                )
            }
        }
    }

    private func drawWindIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        guard kind == .windy else { return }

        for index in 0..<9 {
            let phase = Double(index) * 0.9
            let y = size.height * (0.16 + CGFloat(index) * 0.075)
            let x = size.width * 0.34 + CGFloat(sin((animated ? time * 0.52 : 0) + phase) * 16)
            let length = size.width * (0.10 + CGFloat(index % 3) * 0.04)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x + length, y: y + 2),
                control: CGPoint(x: x + length * 0.52, y: y - 8)
            )

            context.stroke(
                path,
                with: .color(Color.white.opacity(0.26)),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
        }

        for index in 0..<4 {
            let phase = Double(index) * 0.7
            let center = CGPoint(
                x: size.width * (0.66 + CGFloat(index) * 0.08) + CGFloat(sin((animated ? time * 0.44 : 0) + phase) * 8),
                y: size.height * (0.22 + CGFloat(index % 3) * 0.22)
            )
            drawLeafHint(
                in: context,
                center: center,
                scale: index % 2 == 0 ? 1.0 : 0.84,
                rotation: .degrees(-24 + Double(index) * 12)
            )
        }
    }

    private func drawFloatingParticlesIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        guard kind == .sunny || kind == .windy || kind == .partlyCloudy else { return }

        for index in 0..<10 {
            let phase = Double(index) * 0.7
            let x = size.width * (0.56 + CGFloat(index) * 0.06) + CGFloat(sin((animated ? time * 0.36 : 0) + phase) * 10)
            let y = size.height * (0.48 + CGFloat(index % 4) * 0.10) + CGFloat(cos((animated ? time * 0.42 : 0) + phase) * 7)
            let rect = CGRect(x: x, y: y, width: 4.4, height: 4.4)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(kind == .sunny ? 0.24 : 0.14)))
        }
    }

    private func drawLightningIfNeeded(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        guard kind == .thunderstorm else { return }

        let flash: Double

        if animated {
            let phase = time.truncatingRemainder(dividingBy: 7.4)
            if phase < 0.10 {
                flash = (0.10 - phase) / 0.10 * 0.18
            } else if phase > 0.34 && phase < 0.40 {
                flash = (0.40 - phase) / 0.06 * 0.10
            } else {
                flash = 0
            }
        } else {
            flash = 0.12
        }

        guard flash > 0 else { return }

        let center = CGPoint(x: size.width * 0.72, y: size.height * 0.23)
        let flashRect = CGRect(x: center.x - 120, y: center.y - 90, width: 240, height: 180)

        context.fill(
            Path(ellipseIn: flashRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(flash),
                    Color.white.opacity(flash * 0.28),
                    .clear
                ]),
                center: center,
                startRadius: 4,
                endRadius: 110
            )
        )

        let boltOpacity = animated ? flash * 4.8 : 0.92
        if boltOpacity > 0.02 {
            drawLightningBolt(in: context, size: size, opacity: min(boltOpacity, 0.96))
        }
    }

    private func drawLightningBolt(in context: GraphicsContext, size: CGSize, opacity: Double) {
        let start = CGPoint(x: size.width * 0.72, y: size.height * 0.17)
        let endPoint = CGPoint(x: size.width * 0.68, y: size.height * 0.58)

        var bolt = Path()
        bolt.move(to: start)
        bolt.addLine(to: CGPoint(x: size.width * 0.69, y: size.height * 0.31))
        bolt.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.31))
        bolt.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.58))
        bolt.addLine(to: CGPoint(x: size.width * 0.71, y: size.height * 0.44))
        bolt.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.44))

        var glowContext = context
        glowContext.addFilter(.blur(radius: 8))
        glowContext.stroke(
            bolt,
            with: .color(Color.white.opacity(opacity * 0.28)),
            style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round)
        )

        context.stroke(
            bolt,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(opacity),
                    Color(red: 0.86, green: 0.88, blue: 1.0).opacity(opacity * 0.92),
                    Color(red: 0.70, green: 0.75, blue: 0.98).opacity(opacity * 0.84)
                ]),
                startPoint: start,
                endPoint: endPoint
            ),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawLeafHint(in context: GraphicsContext, center: CGPoint, scale: CGFloat, rotation: Angle) {
        var leafContext = context
        leafContext.translateBy(x: center.x, y: center.y)
        leafContext.rotate(by: rotation)

        let rect = CGRect(x: -7 * scale, y: -4 * scale, width: 14 * scale, height: 8 * scale)
        let leaf = Path(ellipseIn: rect)
        leafContext.fill(leaf, with: .color(Color(red: 0.63, green: 0.74, blue: 0.32).opacity(0.72)))

        var vein = Path()
        vein.move(to: CGPoint(x: -5 * scale, y: 0))
        vein.addQuadCurve(to: CGPoint(x: 5 * scale, y: 0), control: CGPoint(x: 0, y: -1.5 * scale))
        leafContext.stroke(vein, with: .color(Color.white.opacity(0.28)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    }

    private func drawCloud(
        in context: GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        opacity: Double,
        blur: CGFloat,
        stretch: CGFloat,
        variant: CloudVariant
    ) {
        let rect = CGRect(
            x: center.x - variant.baseWidth * scale * stretch * 0.5,
            y: center.y - variant.baseHeight * scale * 0.5,
            width: variant.baseWidth * scale * stretch,
            height: variant.baseHeight * scale
        )
        let mainPath = cloudPath(in: rect, variant: variant)
        let highlightPath = cloudHighlightPath(in: rect, variant: variant)
        let shadowPath = cloudShadowPath(in: rect, variant: variant)

        let bodyGradient: Gradient
        let coreGradient: Gradient
        let highlightColor: Color
        let shadowColor: Color
        let strokeColor: Color
        let crispStrokeColor: Color
        let strokeWidth: CGFloat
        let effectiveBlur: CGFloat
        let coreInset: CGFloat

        switch kind {
        case .sunny:
            bodyGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 1.24, 0.97)),
                Color(red: 0.96, green: 0.98, blue: 1.0).opacity(min(opacity * 1.06, 0.92)),
                Color(red: 0.84, green: 0.90, blue: 0.97).opacity(opacity * 0.54)
            ])
            coreGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 1.10, 0.95)),
                Color(red: 0.93, green: 0.97, blue: 1.0).opacity(opacity * 0.70)
            ])
            highlightColor = Color.white.opacity(opacity * 0.40)
            shadowColor = Color(red: 0.72, green: 0.79, blue: 0.88).opacity(opacity * 0.22)
            strokeColor = Color.white.opacity(opacity * 0.24)
            crispStrokeColor = Color.white.opacity(opacity * 0.18)
            strokeWidth = max(scale * 0.95, 1.0)
            effectiveBlur = blur * 0.72
            coreInset = rect.height * 0.028
        case .partlyCloudy, .windy:
            bodyGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 1.10, 0.88)),
                Color(red: 0.88, green: 0.92, blue: 0.97).opacity(opacity * 0.82),
                Color(red: 0.72, green: 0.80, blue: 0.90).opacity(opacity * 0.50)
            ])
            coreGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 0.98, 0.82)),
                Color(red: 0.84, green: 0.90, blue: 0.97).opacity(opacity * 0.64)
            ])
            highlightColor = Color.white.opacity(opacity * 0.24)
            shadowColor = Color(red: 0.60, green: 0.69, blue: 0.80).opacity(opacity * 0.22)
            strokeColor = Color.white.opacity(opacity * 0.18)
            crispStrokeColor = Color.white.opacity(opacity * 0.14)
            strokeWidth = max(scale * 0.92, 1.0)
            effectiveBlur = blur * 0.82
            coreInset = rect.height * 0.032
        case .overcast, .drizzle, .snow:
            bodyGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 0.96, 0.76)),
                Color(red: 0.80, green: 0.85, blue: 0.91).opacity(opacity * 0.76),
                Color(red: 0.58, green: 0.65, blue: 0.75).opacity(opacity * 0.46)
            ])
            coreGradient = Gradient(colors: [
                Color(red: 0.90, green: 0.94, blue: 0.98).opacity(opacity * 0.48),
                Color(red: 0.68, green: 0.75, blue: 0.84).opacity(opacity * 0.56)
            ])
            highlightColor = Color.white.opacity(opacity * 0.10)
            shadowColor = Color(red: 0.45, green: 0.53, blue: 0.64).opacity(opacity * 0.34)
            strokeColor = Color(red: 0.82, green: 0.88, blue: 0.95).opacity(opacity * 0.16)
            crispStrokeColor = Color(red: 0.82, green: 0.88, blue: 0.95).opacity(opacity * 0.24)
            strokeWidth = max(scale * 0.88, 1.0)
            effectiveBlur = max(blur * 0.54, 1.4)
            coreInset = rect.height * 0.022
        case .heavyRain, .thunderstorm:
            bodyGradient = Gradient(colors: [
                Color.white.opacity(min(opacity * 0.82, 0.62)),
                Color(red: 0.68, green: 0.75, blue: 0.84).opacity(opacity * 0.70),
                Color(red: 0.44, green: 0.50, blue: 0.60).opacity(opacity * 0.52)
            ])
            coreGradient = Gradient(colors: [
                Color(red: 0.78, green: 0.84, blue: 0.92).opacity(opacity * 0.40),
                Color(red: 0.52, green: 0.59, blue: 0.70).opacity(opacity * 0.58)
            ])
            highlightColor = Color.white.opacity(opacity * 0.06)
            shadowColor = Color(red: 0.28, green: 0.34, blue: 0.44).opacity(opacity * 0.40)
            strokeColor = Color(red: 0.72, green: 0.80, blue: 0.90).opacity(opacity * 0.14)
            crispStrokeColor = Color(red: 0.76, green: 0.84, blue: 0.93).opacity(opacity * 0.26)
            strokeWidth = max(scale * 0.86, 1.0)
            effectiveBlur = max(blur * 0.42, 1.0)
            coreInset = rect.height * 0.018
        }

        var layerContext = context
        layerContext.addFilter(.blur(radius: effectiveBlur))

        layerContext.fill(
            mainPath,
            with: .linearGradient(
                bodyGradient,
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )

        layerContext.fill(shadowPath, with: .color(shadowColor))
        layerContext.fill(highlightPath, with: .color(highlightColor))

        layerContext.stroke(
            mainPath,
            with: .color(strokeColor),
            lineWidth: strokeWidth
        )

        if kind == .overcast || kind == .drizzle || kind == .heavyRain || kind == .thunderstorm {
            let coreRect = rect.insetBy(dx: rect.width * 0.018, dy: coreInset)
            let corePath = cloudPath(in: coreRect, variant: variant)
            let coreHighlight = cloudHighlightPath(in: coreRect, variant: variant)

            context.fill(
                corePath,
                with: .linearGradient(
                    coreGradient,
                    startPoint: CGPoint(x: coreRect.midX, y: coreRect.minY),
                    endPoint: CGPoint(x: coreRect.midX, y: coreRect.maxY)
                )
            )

            context.fill(coreHighlight, with: .color(highlightColor.opacity(0.72)))
            context.stroke(
                corePath,
                with: .color(crispStrokeColor),
                lineWidth: max(strokeWidth * 0.92, 1.0)
            )
        }
    }

    private func cloudPath(in rect: CGRect, variant: CloudVariant) -> Path {
        Path { path in
            let minX = rect.minX
            let maxX = rect.maxX
            let minY = rect.minY
            let maxY = rect.maxY
            let width = rect.width
            let height = rect.height

            switch variant {
            case .hero:
                path.move(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.34),
                              control1: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.14),
                              control2: CGPoint(x: minX + width * 0.02, y: maxY - height * 0.20))
                path.addCurve(to: CGPoint(x: minX + width * 0.22, y: minY + height * 0.28),
                              control1: CGPoint(x: minX + width * 0.08, y: minY + height * 0.16),
                              control2: CGPoint(x: minX + width * 0.14, y: minY + height * 0.08))
                path.addCurve(to: CGPoint(x: minX + width * 0.44, y: minY + height * 0.08),
                              control1: CGPoint(x: minX + width * 0.28, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.36, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.68, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.54, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.60, y: minY + height * 0.08))
                path.addCurve(to: CGPoint(x: minX + width * 0.86, y: minY + height * 0.26),
                              control1: CGPoint(x: minX + width * 0.76, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.82, y: minY + height * 0.14))
                path.addCurve(to: CGPoint(x: maxX - width * 0.06, y: maxY - height * 0.18),
                              control1: CGPoint(x: maxX - width * 0.04, y: minY + height * 0.14),
                              control2: CGPoint(x: maxX - width * 0.00, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.10),
                              control1: CGPoint(x: maxX - width * 0.16, y: maxY + height * 0.04),
                              control2: CGPoint(x: minX + width * 0.28, y: maxY + height * 0.04))
            case .sunCumulus:
                path.move(to: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.34),
                              control1: CGPoint(x: minX + width * 0.04, y: maxY - height * 0.20),
                              control2: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.30))
                path.addCurve(to: CGPoint(x: minX + width * 0.26, y: minY + height * 0.26),
                              control1: CGPoint(x: minX + width * 0.12, y: minY + height * 0.18),
                              control2: CGPoint(x: minX + width * 0.18, y: minY + height * 0.06))
                path.addCurve(to: CGPoint(x: minX + width * 0.44, y: minY + height * 0.10),
                              control1: CGPoint(x: minX + width * 0.30, y: minY + height * 0.10),
                              control2: CGPoint(x: minX + width * 0.36, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.58, y: minY + height * 0.20),
                              control1: CGPoint(x: minX + width * 0.50, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.54, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.76, y: minY + height * 0.14),
                              control1: CGPoint(x: minX + width * 0.62, y: minY + height * 0.06),
                              control2: CGPoint(x: minX + width * 0.70, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: maxX - width * 0.08, y: maxY - height * 0.18),
                              control1: CGPoint(x: maxX - width * 0.10, y: minY + height * 0.18),
                              control2: CGPoint(x: maxX - width * 0.04, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.10),
                              control1: CGPoint(x: maxX - width * 0.20, y: maxY + height * 0.06),
                              control2: CGPoint(x: minX + width * 0.22, y: maxY + height * 0.05))
            case .puff:
                path.move(to: CGPoint(x: minX + width * 0.16, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.28),
                              control1: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.14),
                              control2: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.20))
                path.addCurve(to: CGPoint(x: minX + width * 0.30, y: minY + height * 0.24),
                              control1: CGPoint(x: minX + width * 0.14, y: minY + height * 0.14),
                              control2: CGPoint(x: minX + width * 0.20, y: minY + height * 0.06))
                path.addCurve(to: CGPoint(x: minX + width * 0.52, y: minY + height * 0.10),
                              control1: CGPoint(x: minX + width * 0.36, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.44, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: minX + width * 0.74, y: minY + height * 0.22),
                              control1: CGPoint(x: minX + width * 0.60, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.66, y: minY + height * 0.08))
                path.addCurve(to: CGPoint(x: maxX - width * 0.08, y: maxY - height * 0.22),
                              control1: CGPoint(x: maxX - width * 0.06, y: minY + height * 0.10),
                              control2: CGPoint(x: maxX - width * 0.02, y: maxY - height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.16, y: maxY - height * 0.10),
                              control1: CGPoint(x: maxX - width * 0.18, y: maxY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.30, y: maxY + height * 0.04))
            case .tower:
                path.move(to: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.14, y: maxY - height * 0.36),
                              control1: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.22),
                              control2: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.30))
                path.addCurve(to: CGPoint(x: minX + width * 0.28, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.16, y: minY + height * 0.18),
                              control2: CGPoint(x: minX + width * 0.22, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: minX + width * 0.42, y: minY + height * 0.08),
                              control1: CGPoint(x: minX + width * 0.32, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.36, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.58, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.48, y: minY + height * 0.04),
                              control2: CGPoint(x: minX + width * 0.54, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.72, y: minY + height * 0.10),
                              control1: CGPoint(x: minX + width * 0.62, y: minY + height * 0.04),
                              control2: CGPoint(x: minX + width * 0.68, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: maxX - width * 0.10, y: maxY - height * 0.20),
                              control1: CGPoint(x: maxX - width * 0.10, y: minY + height * 0.18),
                              control2: CGPoint(x: maxX - width * 0.04, y: maxY - height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.10),
                              control1: CGPoint(x: maxX - width * 0.24, y: maxY + height * 0.04),
                              control2: CGPoint(x: minX + width * 0.28, y: maxY + height * 0.04))
            case .shelf:
                path.move(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.06))
                path.addCurve(to: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.26),
                              control1: CGPoint(x: minX + width * 0.04, y: maxY - height * 0.14),
                              control2: CGPoint(x: minX + width * 0.04, y: maxY - height * 0.22))
                path.addCurve(to: CGPoint(x: minX + width * 0.20, y: minY + height * 0.24),
                              control1: CGPoint(x: minX + width * 0.10, y: minY + height * 0.20),
                              control2: CGPoint(x: minX + width * 0.14, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.38, y: minY + height * 0.12),
                              control1: CGPoint(x: minX + width * 0.24, y: minY + height * 0.10),
                              control2: CGPoint(x: minX + width * 0.30, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: minX + width * 0.56, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.44, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.50, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.74, y: minY + height * 0.14),
                              control1: CGPoint(x: minX + width * 0.62, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.68, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: minX + width * 0.88, y: minY + height * 0.24),
                              control1: CGPoint(x: minX + width * 0.80, y: minY + height * 0.06),
                              control2: CGPoint(x: minX + width * 0.86, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: maxX - width * 0.06, y: maxY - height * 0.16),
                              control1: CGPoint(x: maxX - width * 0.04, y: minY + height * 0.22),
                              control2: CGPoint(x: maxX - width * 0.00, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.06),
                              control1: CGPoint(x: maxX - width * 0.18, y: maxY + height * 0.06),
                              control2: CGPoint(x: minX + width * 0.26, y: maxY + height * 0.02))
            case .rainBand:
                path.move(to: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.05))
                path.addCurve(to: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.24),
                              control1: CGPoint(x: minX + width * 0.04, y: maxY - height * 0.12),
                              control2: CGPoint(x: minX + width * 0.02, y: maxY - height * 0.18))
                path.addCurve(to: CGPoint(x: minX + width * 0.18, y: minY + height * 0.24),
                              control1: CGPoint(x: minX + width * 0.08, y: minY + height * 0.20),
                              control2: CGPoint(x: minX + width * 0.12, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.34, y: minY + height * 0.10),
                              control1: CGPoint(x: minX + width * 0.22, y: minY + height * 0.12),
                              control2: CGPoint(x: minX + width * 0.28, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.52, y: minY + height * 0.16),
                              control1: CGPoint(x: minX + width * 0.40, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.46, y: minY + height * 0.08))
                path.addCurve(to: CGPoint(x: minX + width * 0.70, y: minY + height * 0.12),
                              control1: CGPoint(x: minX + width * 0.58, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.64, y: minY + height * 0.02))
                path.addCurve(to: CGPoint(x: minX + width * 0.88, y: minY + height * 0.22),
                              control1: CGPoint(x: minX + width * 0.76, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.84, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: maxX - width * 0.06, y: maxY - height * 0.16),
                              control1: CGPoint(x: maxX - width * 0.04, y: minY + height * 0.20),
                              control2: CGPoint(x: maxX - width * 0.02, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.08, y: maxY - height * 0.05),
                              control1: CGPoint(x: maxX - width * 0.20, y: maxY + height * 0.06),
                              control2: CGPoint(x: minX + width * 0.24, y: maxY + height * 0.02))
            case .stormBand:
                path.move(to: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.05))
                path.addCurve(to: CGPoint(x: minX + width * 0.04, y: maxY - height * 0.28),
                              control1: CGPoint(x: minX + width * 0.02, y: maxY - height * 0.14),
                              control2: CGPoint(x: minX + width * 0.00, y: maxY - height * 0.20))
                path.addCurve(to: CGPoint(x: minX + width * 0.14, y: minY + height * 0.26),
                              control1: CGPoint(x: minX + width * 0.06, y: minY + height * 0.24),
                              control2: CGPoint(x: minX + width * 0.10, y: minY + height * 0.14))
                path.addCurve(to: CGPoint(x: minX + width * 0.28, y: minY + height * 0.12),
                              control1: CGPoint(x: minX + width * 0.18, y: minY + height * 0.12),
                              control2: CGPoint(x: minX + width * 0.22, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.46, y: minY + height * 0.16),
                              control1: CGPoint(x: minX + width * 0.34, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.40, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.64, y: minY + height * 0.10),
                              control1: CGPoint(x: minX + width * 0.52, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.58, y: minY + height * 0.00))
                path.addCurve(to: CGPoint(x: minX + width * 0.82, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.70, y: minY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.78, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: maxX - width * 0.03, y: minY + height * 0.30),
                              control1: CGPoint(x: maxX - width * 0.10, y: minY + height * 0.06),
                              control2: CGPoint(x: maxX - width * 0.04, y: minY + height * 0.18))
                path.addCurve(to: CGPoint(x: maxX - width * 0.05, y: maxY - height * 0.20),
                              control1: CGPoint(x: maxX - width * 0.01, y: minY + height * 0.40),
                              control2: CGPoint(x: maxX - width * 0.00, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.05),
                              control1: CGPoint(x: maxX - width * 0.20, y: maxY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.20, y: maxY + height * 0.04))
            case .veil:
                path.move(to: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.06))
                path.addCurve(to: CGPoint(x: minX + width * 0.10, y: maxY - height * 0.20),
                              control1: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.12),
                              control2: CGPoint(x: minX + width * 0.06, y: maxY - height * 0.18))
                path.addCurve(to: CGPoint(x: minX + width * 0.24, y: minY + height * 0.24),
                              control1: CGPoint(x: minX + width * 0.12, y: minY + height * 0.22),
                              control2: CGPoint(x: minX + width * 0.18, y: minY + height * 0.14))
                path.addCurve(to: CGPoint(x: minX + width * 0.42, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.30, y: minY + height * 0.14),
                              control2: CGPoint(x: minX + width * 0.36, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.62, y: minY + height * 0.16),
                              control1: CGPoint(x: minX + width * 0.50, y: minY + height * 0.12),
                              control2: CGPoint(x: minX + width * 0.56, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.82, y: minY + height * 0.22),
                              control1: CGPoint(x: minX + width * 0.68, y: minY + height * 0.12),
                              control2: CGPoint(x: minX + width * 0.76, y: minY + height * 0.14))
                path.addCurve(to: CGPoint(x: maxX - width * 0.10, y: maxY - height * 0.14),
                              control1: CGPoint(x: maxX - width * 0.06, y: minY + height * 0.20),
                              control2: CGPoint(x: maxX - width * 0.04, y: maxY - height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.12, y: maxY - height * 0.06),
                              control1: CGPoint(x: maxX - width * 0.22, y: maxY + height * 0.02),
                              control2: CGPoint(x: minX + width * 0.24, y: maxY + height * 0.01))
            }
            path.closeSubpath()
        }
    }

    private func cloudHighlightPath(in rect: CGRect, variant: CloudVariant) -> Path {
        Path { path in
            let minX = rect.minX
            let minY = rect.minY
            let width = rect.width
            let height = rect.height

            switch variant {
            case .hero, .puff, .sunCumulus, .tower:
                path.move(to: CGPoint(x: minX + width * 0.20, y: minY + height * 0.30))
                path.addCurve(to: CGPoint(x: minX + width * 0.48, y: minY + height * 0.12),
                              control1: CGPoint(x: minX + width * 0.28, y: minY + height * 0.16),
                              control2: CGPoint(x: minX + width * 0.38, y: minY + height * 0.06))
                path.addCurve(to: CGPoint(x: minX + width * 0.72, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.56, y: minY + height * 0.08),
                              control2: CGPoint(x: minX + width * 0.64, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.80, y: minY + height * 0.28),
                              control1: CGPoint(x: minX + width * 0.76, y: minY + height * 0.20),
                              control2: CGPoint(x: minX + width * 0.80, y: minY + height * 0.22))
                path.addLine(to: CGPoint(x: minX + width * 0.78, y: minY + height * 0.38))
                path.addCurve(to: CGPoint(x: minX + width * 0.22, y: minY + height * 0.38),
                              control1: CGPoint(x: minX + width * 0.60, y: minY + height * 0.28),
                              control2: CGPoint(x: minX + width * 0.38, y: minY + height * 0.30))
            case .shelf, .veil, .rainBand, .stormBand:
                path.move(to: CGPoint(x: minX + width * 0.16, y: minY + height * 0.28))
                path.addCurve(to: CGPoint(x: minX + width * 0.38, y: minY + height * 0.18),
                              control1: CGPoint(x: minX + width * 0.22, y: minY + height * 0.18),
                              control2: CGPoint(x: minX + width * 0.30, y: minY + height * 0.12))
                path.addCurve(to: CGPoint(x: minX + width * 0.62, y: minY + height * 0.16),
                              control1: CGPoint(x: minX + width * 0.46, y: minY + height * 0.10),
                              control2: CGPoint(x: minX + width * 0.54, y: minY + height * 0.10))
                path.addCurve(to: CGPoint(x: minX + width * 0.80, y: minY + height * 0.22),
                              control1: CGPoint(x: minX + width * 0.70, y: minY + height * 0.12),
                              control2: CGPoint(x: minX + width * 0.76, y: minY + height * 0.14))
                path.addLine(to: CGPoint(x: minX + width * 0.78, y: minY + height * 0.32))
                path.addCurve(to: CGPoint(x: minX + width * 0.18, y: minY + height * 0.34),
                              control1: CGPoint(x: minX + width * 0.60, y: minY + height * 0.24),
                              control2: CGPoint(x: minX + width * 0.36, y: minY + height * 0.26))
            }
            path.closeSubpath()
        }
    }

    private func cloudShadowPath(in rect: CGRect, variant: CloudVariant) -> Path {
        let insetX: CGFloat
        let widthFactor: CGFloat
        let heightFactor: CGFloat

        switch variant {
        case .hero:
            insetX = 0.14
            widthFactor = 0.74
            heightFactor = 0.18
        case .sunCumulus:
            insetX = 0.14
            widthFactor = 0.72
            heightFactor = 0.16
        case .puff:
            insetX = 0.16
            widthFactor = 0.70
            heightFactor = 0.16
        case .tower:
            insetX = 0.18
            widthFactor = 0.66
            heightFactor = 0.16
        case .shelf:
            insetX = 0.10
            widthFactor = 0.80
            heightFactor = 0.14
        case .rainBand:
            insetX = 0.10
            widthFactor = 0.82
            heightFactor = 0.14
        case .stormBand:
            insetX = 0.08
            widthFactor = 0.84
            heightFactor = 0.16
        case .veil:
            insetX = 0.12
            widthFactor = 0.76
            heightFactor = 0.12
        }

        return Path(
            roundedRect: CGRect(
                x: rect.minX + rect.width * insetX,
                y: rect.maxY - rect.height * 0.26,
                width: rect.width * widthFactor,
                height: rect.height * heightFactor
            ),
            cornerRadius: rect.height * 0.08
        )
    }

    private func cloudSpecs(for layer: CloudLayer) -> [CloudSpec] {
        switch kind {
        case .sunny:
            if layer == .far {
                return [
                    CloudSpec(x: 0.64, y: 0.18, scale: 0.84, opacityMultiplier: 0.38, variant: .veil),
                    CloudSpec(x: 0.86, y: 0.22, scale: 0.90, opacityMultiplier: 0.34, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.74, y: 0.38, scale: 1.22, opacityMultiplier: 0.94, variant: .sunCumulus),
                    CloudSpec(x: 0.57, y: 0.52, scale: 0.92, opacityMultiplier: 0.64, variant: .puff)
                ]
            }
            return [
                CloudSpec(x: 0.68, y: 0.30, scale: 1.28, opacityMultiplier: 0.48, variant: .sunCumulus),
                CloudSpec(x: 0.52, y: 0.40, scale: 1.00, opacityMultiplier: 0.24, variant: .veil)
            ]
        case .partlyCloudy:
            if layer == .far {
                return [
                    CloudSpec(x: 0.60, y: 0.18, scale: 0.82, opacityMultiplier: 0.34, variant: .veil),
                    CloudSpec(x: 0.86, y: 0.20, scale: 0.90, opacityMultiplier: 0.36, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.74, y: 0.34, scale: 1.26, opacityMultiplier: 0.90, variant: .tower),
                    CloudSpec(x: 0.58, y: 0.48, scale: 1.00, opacityMultiplier: 0.60, variant: .puff),
                    CloudSpec(x: 0.92, y: 0.40, scale: 0.92, opacityMultiplier: 0.44, variant: .tower)
                ]
            }
            return [CloudSpec(x: 0.46, y: 0.58, scale: 1.00, opacityMultiplier: 0.22, variant: .veil)]
        case .overcast, .snow:
            if layer == .far {
                return [
                    CloudSpec(x: 0.48, y: 0.20, scale: 0.92, opacityMultiplier: 0.36, variant: .veil),
                    CloudSpec(x: 0.80, y: 0.22, scale: 0.96, opacityMultiplier: 0.34, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.68, y: 0.36, scale: 1.20, opacityMultiplier: 0.90, variant: .shelf),
                    CloudSpec(x: 0.88, y: 0.42, scale: 1.00, opacityMultiplier: 0.62, variant: .shelf),
                    CloudSpec(x: 0.50, y: 0.50, scale: 0.96, opacityMultiplier: 0.42, variant: .puff)
                ]
            }
            return [CloudSpec(x: 0.46, y: 0.58, scale: 1.04, opacityMultiplier: 0.20, variant: .veil)]
        case .drizzle:
            if layer == .far {
                return [
                    CloudSpec(x: 0.58, y: 0.18, scale: 0.90, opacityMultiplier: 0.34, variant: .veil),
                    CloudSpec(x: 0.84, y: 0.22, scale: 0.96, opacityMultiplier: 0.32, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.70, y: 0.34, scale: 1.14, opacityMultiplier: 0.92, variant: .rainBand),
                    CloudSpec(x: 0.54, y: 0.46, scale: 0.94, opacityMultiplier: 0.56, variant: .puff),
                    CloudSpec(x: 0.92, y: 0.40, scale: 0.94, opacityMultiplier: 0.46, variant: .rainBand)
                ]
            }
            return [CloudSpec(x: 0.46, y: 0.56, scale: 1.00, opacityMultiplier: 0.18, variant: .veil)]
        case .heavyRain, .thunderstorm:
            if layer == .far {
                return [
                    CloudSpec(x: 0.56, y: 0.16, scale: 1.04, opacityMultiplier: 0.42, variant: .veil),
                    CloudSpec(x: 0.82, y: 0.20, scale: 1.06, opacityMultiplier: 0.40, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.70, y: 0.30, scale: 1.24, opacityMultiplier: 0.92, variant: .stormBand),
                    CloudSpec(x: 0.54, y: 0.42, scale: 1.04, opacityMultiplier: 0.62, variant: .stormBand),
                    CloudSpec(x: 0.94, y: 0.36, scale: 0.98, opacityMultiplier: 0.52, variant: .puff)
                ]
            }
            return [CloudSpec(x: 0.48, y: 0.56, scale: 1.10, opacityMultiplier: 0.20, variant: .stormBand)]
        case .windy:
            if layer == .far {
                return [
                    CloudSpec(x: 0.50, y: 0.18, scale: 0.90, opacityMultiplier: 0.38, variant: .veil),
                    CloudSpec(x: 0.80, y: 0.24, scale: 0.96, opacityMultiplier: 0.36, variant: .veil)
                ]
            } else if layer == .mid {
                return [
                    CloudSpec(x: 0.64, y: 0.34, scale: 1.10, opacityMultiplier: 0.74, variant: .rainBand),
                    CloudSpec(x: 0.90, y: 0.40, scale: 0.98, opacityMultiplier: 0.50, variant: .puff)
                ]
            }
            return [CloudSpec(x: 0.46, y: 0.50, scale: 1.02, opacityMultiplier: 0.18, variant: .veil)]
        }
    }

    private var backgroundColors: [Color] {
        switch kind {
        case .sunny:
            return [
                Color(red: 0.48, green: 0.72, blue: 0.94).opacity(0.92),
                Color(red: 0.76, green: 0.89, blue: 0.99).opacity(0.70),
                Color(red: 0.98, green: 0.92, blue: 0.72).opacity(0.28)
            ]
        case .partlyCloudy:
            return [
                Color(red: 0.47, green: 0.70, blue: 0.90).opacity(0.82),
                Color(red: 0.70, green: 0.84, blue: 0.96).opacity(0.66),
                Color(red: 0.92, green: 0.95, blue: 0.99).opacity(0.24)
            ]
        case .overcast:
            return [
                Color(red: 0.42, green: 0.50, blue: 0.60).opacity(0.80),
                Color(red: 0.60, green: 0.68, blue: 0.78).opacity(0.58),
                Color(red: 0.86, green: 0.90, blue: 0.95).opacity(0.16)
            ]
        case .drizzle:
            return [
                Color(red: 0.46, green: 0.59, blue: 0.72).opacity(0.78),
                Color(red: 0.64, green: 0.76, blue: 0.88).opacity(0.56),
                Color(red: 0.88, green: 0.92, blue: 0.97).opacity(0.16)
            ]
        case .heavyRain:
            return [
                Color(red: 0.22, green: 0.30, blue: 0.40).opacity(0.86),
                Color(red: 0.38, green: 0.50, blue: 0.62).opacity(0.62),
                Color(red: 0.72, green: 0.82, blue: 0.92).opacity(0.12)
            ]
        case .thunderstorm:
            return [
                Color(red: 0.16, green: 0.20, blue: 0.30).opacity(0.90),
                Color(red: 0.26, green: 0.34, blue: 0.46).opacity(0.66),
                Color(red: 0.62, green: 0.72, blue: 0.88).opacity(0.12)
            ]
        case .windy:
            return [
                Color(red: 0.56, green: 0.74, blue: 0.90).opacity(0.78),
                Color(red: 0.76, green: 0.88, blue: 0.97).opacity(0.60),
                Color(red: 0.94, green: 0.97, blue: 1.0).opacity(0.18)
            ]
        case .snow:
            return [
                Color(red: 0.52, green: 0.63, blue: 0.74).opacity(0.78),
                Color(red: 0.72, green: 0.82, blue: 0.92).opacity(0.58),
                Color.white.opacity(0.24)
            ]
        }
    }

    private var glowColor: Color {
        switch kind {
        case .sunny, .partlyCloudy:
            return Color(red: 1.0, green: 0.93, blue: 0.76)
        case .overcast, .drizzle, .windy, .snow:
            return Color.white
        case .heavyRain, .thunderstorm:
            return Color(red: 0.88, green: 0.92, blue: 0.98)
        }
    }
}

private struct CloudSpec {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let opacityMultiplier: Double
    let variant: CloudVariant
}

private enum CloudVariant {
    case hero
    case puff
    case shelf
    case veil
    case sunCumulus
    case tower
    case rainBand
    case stormBand

    var baseWidth: CGFloat {
        switch self {
        case .hero:
            196
        case .puff:
            164
        case .shelf:
            212
        case .veil:
            188
        case .sunCumulus:
            208
        case .tower:
            176
        case .rainBand:
            224
        case .stormBand:
            236
        }
    }

    var baseHeight: CGFloat {
        switch self {
        case .hero:
            92
        case .puff:
            80
        case .shelf:
            72
        case .veil:
            68
        case .sunCumulus:
            98
        case .tower:
            108
        case .rainBand:
            78
        case .stormBand:
            92
        }
    }
}

private struct CloudLayer: Equatable {
    let speed: Double
    let opacity: Double
    let blur: CGFloat
    let xAmplitude: CGFloat
    let yAmplitude: CGFloat
    let scaleMultiplier: CGFloat
    let stretch: CGFloat
    let phaseOffset: Double

    static let far = CloudLayer(
        speed: 0.07,
        opacity: 0.18,
        blur: 18,
        xAmplitude: 0.020,
        yAmplitude: 0.012,
        scaleMultiplier: 0.92,
        stretch: 1.20,
        phaseOffset: 0.1
    )
    static let mid = CloudLayer(
        speed: 0.11,
        opacity: 0.30,
        blur: 10,
        xAmplitude: 0.030,
        yAmplitude: 0.018,
        scaleMultiplier: 1.0,
        stretch: 1.12,
        phaseOffset: 1.1
    )
    static let near = CloudLayer(
        speed: 0.15,
        opacity: 0.16,
        blur: 20,
        xAmplitude: 0.024,
        yAmplitude: 0.012,
        scaleMultiplier: 1.06,
        stretch: 1.26,
        phaseOffset: 2.2
    )
}
