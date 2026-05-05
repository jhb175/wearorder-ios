import SwiftUI

/// Base sky gradient + sun disc + lens flare ghosts. The disc is a
/// real luminous body — radial gradient core, outer haze, NOT an SF
/// Symbol like the legacy fallback.
struct WeatherSkyLayer: View {
    let palette: WeatherScenePalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            drawSky(in: context, size: size)
            drawSunDiscIfVisible(in: context, size: size)
            drawLensFlareIfVisible(in: context, size: size)
        }
    }

    private func drawSky(in context: GraphicsContext, size: CGSize) {
        // Gentle drift of the gradient origin so the sky never feels static
        let drift = CGFloat(sin(time * 0.20)) * 18
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: palette.skyGradient),
                startPoint: CGPoint(x: drift, y: 0),
                endPoint: CGPoint(x: size.width + drift, y: size.height)
            )
        )
    }

    private func drawSunDiscIfVisible(in context: GraphicsContext, size: CGSize) {
        guard palette.sunVisibility > 0 else { return }

        let center = sunCenter(in: size)
        let visibility = palette.sunVisibility
        let warmth = palette.sunWarmth

        // Outer warm haze — bigger than the disc, very soft.
        let hazeRect = CGRect(
            x: center.x - 168, y: center.y - 168,
            width: 336, height: 336
        )
        context.fill(
            Path(ellipseIn: hazeRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.74).opacity(0.32 * visibility),
                    Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.14 * visibility),
                    .clear
                ]),
                center: center,
                startRadius: 8,
                endRadius: 168
            )
        )

        // Core disc — bright, with subtle warm-cool gradient.
        let discRadius: CGFloat = 36
        let discRect = CGRect(
            x: center.x - discRadius, y: center.y - discRadius,
            width: discRadius * 2, height: discRadius * 2
        )
        context.fill(
            Path(ellipseIn: discRect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.96 * visibility), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.92 * visibility), location: 0.55),
                    .init(color: Color(red: 0.99, green: 0.84, blue: 0.42).opacity(0.74 * visibility * warmth), location: 1.0)
                ]),
                center: center,
                startRadius: 1,
                endRadius: discRadius
            )
        )

        // Crisp halo ring for definition.
        let haloRect = discRect.insetBy(dx: -8, dy: -8)
        context.stroke(
            Path(ellipseIn: haloRect),
            with: .color(Color.white.opacity(0.30 * visibility)),
            lineWidth: 1.2
        )

        // Soft pulsing rays — animated subtly via time.
        drawSunRays(in: context, center: center, visibility: visibility)
    }

    private func drawSunRays(in context: GraphicsContext, center: CGPoint, visibility: Double) {
        let rayCount = 9
        let rotation = time * 0.04 // very slow whole-disc rotation for life
        for index in 0..<rayCount {
            let baseAngle = -90.0 + Double(index) * (360.0 / Double(rayCount)) + rotation * (180 / .pi)
            let pulse = 0.78 + sin(time * 1.4 + Double(index) * 0.6) * 0.22
            let length: CGFloat = 86 + CGFloat(index % 3) * 18
            let width: CGFloat = 10 + CGFloat(index % 2) * 6

            var ray = context
            ray.translateBy(x: center.x, y: center.y)
            ray.rotate(by: .degrees(baseAngle))

            let rect = CGRect(x: 42, y: -width * 0.5, width: length, height: width)
            ray.fill(
                Path(roundedRect: rect, cornerRadius: width * 0.5),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.18 * visibility * pulse),
                        Color(red: 1.0, green: 0.92, blue: 0.66).opacity(0.10 * visibility * pulse),
                        .clear
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                )
            )
        }
    }

    private func drawLensFlareIfVisible(in context: GraphicsContext, size: CGSize) {
        guard palette.sunVisibility > 0.5 else { return }

        let sun = sunCenter(in: size)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let direction = CGPoint(x: center.x - sun.x, y: center.y - sun.y)

        let ghosts: [(distance: CGFloat, radius: CGFloat, alpha: Double, hue: Color)] = [
            (0.55, 22, 0.16, Color(red: 1.0, green: 0.94, blue: 0.78)),
            (0.85, 14, 0.12, Color(red: 0.96, green: 0.88, blue: 1.0)),
            (1.18, 30, 0.10, Color(red: 1.0, green: 0.82, blue: 0.62)),
            (1.55, 10, 0.08, Color.white)
        ]

        for ghost in ghosts {
            let pos = CGPoint(
                x: sun.x + direction.x * ghost.distance,
                y: sun.y + direction.y * ghost.distance
            )
            let rect = CGRect(
                x: pos.x - ghost.radius,
                y: pos.y - ghost.radius,
                width: ghost.radius * 2,
                height: ghost.radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [ghost.hue.opacity(ghost.alpha), .clear]),
                    center: pos,
                    startRadius: 0,
                    endRadius: ghost.radius
                )
            )
        }
    }

    /// Sun position is upper-right of card, with very subtle drift.
    func sunCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * 0.78 + CGFloat(sin(time * 0.24)) * 9,
            y: size.height * 0.22 + CGFloat(cos(time * 0.32)) * 6
        )
    }
}
