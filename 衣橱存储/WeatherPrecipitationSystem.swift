import SwiftUI

/// Rain + snow precipitation. Both kinds use deterministic-ish hashed
/// particle layouts so visual density is stable across launches but
/// not visibly repeating.
struct WeatherPrecipitationSystem: View {
    let palette: WeatherScenePalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            switch palette.precipitation {
            case .none:
                break
            case .rain(let intensity):
                drawRain(in: context, size: size, intensity: intensity)
            case .snow(let intensity):
                drawSnow(in: context, size: size, intensity: intensity)
            }
        }
    }

    // MARK: - Rain

    private func drawRain(in context: GraphicsContext, size: CGSize, intensity: Double) {
        let count = palette.rainParticleCount
        guard count > 0 else { return }

        // Slope grows with intensity: drizzle barely angled, thunderstorm
        // markedly slanted (driven by storm wind).
        let backSlope: CGFloat = 6 + 18 * CGFloat(intensity)
        let frontSlope: CGFloat = 8 + 22 * CGFloat(intensity)

        // Two passes: back layer (slower, blurred), front layer (sharper).
        drawRainPass(
            in: context, size: size,
            count: max(count / 2, 6),
            xStart: 0.36, xSpan: 0.56,
            speed: 220, length: 28,
            slope: backSlope, sway: 3.2,
            lineWidth: 0.9,
            alpha: 0.18 * intensity,
            blur: 1.4
        )
        drawRainPass(
            in: context, size: size,
            count: count,
            xStart: 0.36, xSpan: 0.56,
            speed: 280, length: 36,
            slope: frontSlope, sway: 2.4,
            lineWidth: 1.2,
            alpha: 0.42 * intensity,
            blur: 0
        )

        drawRainSplash(in: context, size: size, intensity: intensity)
    }

    private func drawRainPass(
        in context: GraphicsContext,
        size: CGSize,
        count: Int,
        xStart: CGFloat,
        xSpan: CGFloat,
        speed: Double,
        length: CGFloat,
        slope: CGFloat,
        sway: CGFloat,
        lineWidth: CGFloat,
        alpha: Double,
        blur: CGFloat
    ) {
        var passContext = context
        if blur > 0 {
            passContext.addFilter(.blur(radius: blur))
        }

        for index in 0..<count {
            let normalized = CGFloat(index) / CGFloat(max(count - 1, 1))
            let xBase = xStart + normalized * xSpan
            let x = size.width * xBase + CGFloat(sin(time * 0.6 + Double(index) * 0.4)) * sway

            let cycle = size.height + 80
            let stagger = Double(index) * 23.7
            let speedVariance = 0.86 + Double(index % 5) * 0.06
            let yRaw = (time * speed * speedVariance + stagger).truncatingRemainder(dividingBy: cycle)
            let yStart = CGFloat(yRaw) - 40
            let yEnd = yStart + length + CGFloat(index % 3) * 4

            var path = Path()
            path.move(to: CGPoint(x: x, y: yStart))
            path.addQuadCurve(
                to: CGPoint(x: x - slope, y: yEnd),
                control: CGPoint(x: x - slope * 0.5, y: yStart + length * 0.45)
            )

            passContext.stroke(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(0), location: 0.0),
                        .init(color: Color.white.opacity(alpha * 0.46), location: 0.36),
                        .init(color: Color.white.opacity(alpha), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: x, y: yStart),
                    endPoint: CGPoint(x: x - slope, y: yEnd)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    private func drawRainSplash(in context: GraphicsContext, size: CGSize, intensity: Double) {
        // Splash dots near the bottom edge — small bright impacts that
        // appear at a few hashed x positions, opacity-modulated by a
        // fast sin so they "pop" sequentially.
        let splashRowY = size.height * 0.92
        for index in 0..<8 {
            let xNorm = 0.40 + CGFloat(index) * 0.07
            let x = size.width * xNorm
            let phase = Double(index) * 0.7
            let pop = max(0, sin(time * 4.0 + phase))
            let alpha = 0.36 * intensity * pop
            guard alpha > 0.04 else { continue }

            let radius: CGFloat = 1.6 + CGFloat(pop) * 1.6
            let rect = CGRect(
                x: x - radius,
                y: splashRowY - radius * 0.4,
                width: radius * 2,
                height: radius * 0.8
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(alpha))
            )
        }
    }

    // MARK: - Snow

    private func drawSnow(in context: GraphicsContext, size: CGSize, intensity: Double) {
        let count = palette.snowParticleCount
        guard count > 0 else { return }

        for index in 0..<count {
            let hash = Self.hash(seed: index)

            let xNorm = 0.30 + 0.68 * hash(0)
            let speed = 0.16 + 0.30 * hash(1)
            let radius: CGFloat = 1.2 + 2.6 * CGFloat(hash(2))
            let sway: CGFloat = 6 + 18 * CGFloat(hash(3))
            let phase = 2 * .pi * hash(4)
            let depth: CGFloat = 0.34 + 0.66 * CGFloat(hash(5))

            let cycle = Double(size.height) + 80
            // Bumped fall speed: was 60*speed*depth (~10-28 px/s).
            // Now 90*speed (constant base) + per-flake depth boost so closer
            // flakes also fall faster, reading as real depth.
            let fallSpeed = 90.0 * Double(speed) + 60.0 * Double(depth)
            let yRaw = time * fallSpeed
            let y = CGFloat(yRaw.truncatingRemainder(dividingBy: cycle)) - 40
            let xSway = CGFloat(sin(time * 0.85 * Double(depth) + phase)) * sway
            let x = size.width * xNorm + xSway

            let effectiveRadius = radius * depth
            let alpha = (0.32 + 0.5 * Double(depth)) * intensity

            // Soft halo for the closer flakes.
            if depth > 0.6 {
                let haloRect = CGRect(
                    x: x - effectiveRadius * 1.8,
                    y: y - effectiveRadius * 1.8,
                    width: effectiveRadius * 3.6,
                    height: effectiveRadius * 3.6
                )
                var blurContext = context
                blurContext.addFilter(.blur(radius: 2.4))
                blurContext.fill(
                    Path(ellipseIn: haloRect),
                    with: .color(Color.white.opacity(alpha * 0.22))
                )
            }

            let rect = CGRect(
                x: x - effectiveRadius,
                y: y - effectiveRadius,
                width: effectiveRadius * 2,
                height: effectiveRadius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(alpha),
                        Color.white.opacity(alpha * 0.42),
                        .clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0.4,
                    endRadius: effectiveRadius * 1.8
                )
            )
        }
    }

    /// Cheap hash that's stable per seed but spreads values across [0, 1].
    private static func hash(seed: Int) -> (Int) -> Double {
        return { component in
            let v = sin(Double(seed) * 12.9898 + Double(component) * 78.233 + 15.731) * 43758.5453
            return v - floor(v)
        }
    }
}
