import SwiftUI

/// Mist / fog drift, volumetric god-rays, floating dust motes, and
/// wind streaks. These are the "atmosphere" effects that sit between
/// the cloud layers and the precipitation layer.
struct WeatherAtmosphericEffects: View {
    let palette: WeatherScenePalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            if palette.hasMist {
                drawMist(in: context, size: size)
            }
            if palette.hasVolumetricLight {
                drawVolumetricLight(in: context, size: size)
            }
            if palette.hasFloatingDust {
                drawFloatingDust(in: context, size: size)
            }
            if palette.windStreaks {
                drawWindStreaks(in: context, size: size)
            }
        }
    }

    // MARK: - Mist

    private func drawMist(in context: GraphicsContext, size: CGSize) {
        let bandCount = 5
        for index in 0..<bandCount {
            let phase = Double(index) * 1.4
            let speed = 0.05 + Double(index) * 0.012
            let driftX = CGFloat(sin(time * speed + phase)) * 38
            let driftY = CGFloat(cos(time * speed * 0.7 + phase)) * 12

            let bandY = size.height * (0.18 + CGFloat(index) * 0.14)
            let bandHeight = size.height * (0.18 + CGFloat(index) * 0.04)
            let centerX = size.width * 0.62 + driftX
            let centerY = bandY + driftY

            let rect = CGRect(
                x: centerX - size.width * 0.46,
                y: centerY - bandHeight * 0.5,
                width: size.width * 0.92,
                height: bandHeight
            )

            let baseAlpha = palette.mistIntensity * (1.0 - Double(index) * 0.10)

            var blurContext = context
            blurContext.addFilter(.blur(radius: 16))
            blurContext.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(baseAlpha),
                        Color(red: 0.86, green: 0.90, blue: 0.94).opacity(baseAlpha * 0.6),
                        .clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 18,
                    endRadius: rect.width * 0.42
                )
            )
        }
    }

    // MARK: - Volumetric light cones

    private func drawVolumetricLight(in context: GraphicsContext, size: CGSize) {
        let sunCenter = CGPoint(
            x: size.width * 0.78,
            y: size.height * 0.22
        )
        let warmth = palette.sunWarmth

        for index in 0..<5 {
            let baseAngle = -42.0 + Double(index) * 21.0
            let pulse = 0.78 + sin(time * 0.6 + Double(index) * 0.7) * 0.22
            let coneLength: CGFloat = size.height * 0.96
            let coneSpread: CGFloat = 36 + CGFloat(index) * 6

            var rayContext = context
            rayContext.translateBy(x: sunCenter.x, y: sunCenter.y)
            rayContext.rotate(by: .degrees(baseAngle))

            let conePath = Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: -coneSpread * 0.5, y: coneLength))
                path.addLine(to: CGPoint(x: coneSpread * 0.5, y: coneLength))
                path.closeSubpath()
            }

            rayContext.fill(
                conePath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.95, blue: 0.78).opacity(0.16 * warmth * pulse), location: 0.0),
                        .init(color: Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.06 * warmth * pulse), location: 0.55),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: coneLength)
                )
            )
        }
    }

    // MARK: - Floating dust

    private func drawFloatingDust(in context: GraphicsContext, size: CGSize) {
        let count = 14
        let warmth = palette.sunWarmth

        for index in 0..<count {
            let phase = Double(index) * 0.6
            let yNorm = Double(index) / Double(count - 1)
            let x = size.width * (0.46 + CGFloat(index) * 0.04)
                + CGFloat(sin(time * 0.32 + phase)) * 22
            let y = size.height * (0.22 + CGFloat(yNorm) * 0.62)
                + CGFloat(cos(time * 0.28 + phase)) * 8
            let radius: CGFloat = 1.0 + CGFloat(index % 3) * 0.6

            let alpha: Double
            if warmth > 0 {
                alpha = (0.18 - yNorm * 0.10) * warmth
            } else {
                alpha = 0.12 - yNorm * 0.06
            }

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let dustColor = warmth > 0
                ? Color(red: 1.0, green: 0.96, blue: 0.84)
                : Color.white
            context.fill(
                Path(ellipseIn: rect),
                with: .color(dustColor.opacity(alpha))
            )
        }
    }

    // MARK: - Wind streaks

    private func drawWindStreaks(in context: GraphicsContext, size: CGSize) {
        for index in 0..<10 {
            let yNorm = 0.18 + CGFloat(index) * 0.072
            let phase = Double(index) * 0.85
            let driftX = CGFloat(sin(time * 0.48 + phase)) * 18
            let baseY = size.height * yNorm
            let length = size.width * (0.16 + CGFloat(index % 3) * 0.06)

            let xStart = size.width * 0.32 + driftX

            var path = Path()
            path.move(to: CGPoint(x: xStart, y: baseY))
            path.addQuadCurve(
                to: CGPoint(x: xStart + length, y: baseY + 4),
                control: CGPoint(x: xStart + length * 0.5, y: baseY - 10)
            )

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: CGPoint(x: xStart, y: baseY),
                    endPoint: CGPoint(x: xStart + length, y: baseY)
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }
}
