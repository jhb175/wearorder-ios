import SwiftUI

/// Volumetric god-rays for `.sunny` and `.partlyCloudy`. The current
/// animation has 7 static rays radiating from the sun core; real
/// premium weather visuals add wide soft cones of light that fan
/// down through the canvas, with subtle pulsing. This layer adds that.
struct WeatherVolumetricLightLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let warmth: Double
    var isActive: Bool = true

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(time: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func canvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            let sunCenter = CGPoint(
                x: size.width * 0.76,
                y: size.height * 0.22
            )

            for index in 0..<5 {
                let baseAngle = -42.0 + Double(index) * 21.0
                let pulse = 0.78 + sin(time * 0.6 + Double(index)) * 0.22
                let coneLength: CGFloat = size.height * 0.92
                let coneSpread: CGFloat = 38 + CGFloat(index) * 6

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
                            .init(color: Color(red: 1.0, green: 0.95, blue: 0.78).opacity(0.18 * warmth * pulse), location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.96, blue: 0.84).opacity(0.06 * warmth * pulse), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: coneLength)
                    )
                )
            }

            let dustCount = 16
            for index in 0..<dustCount {
                let phase = Double(index) * 0.6
                let yNorm = (Double(index) / Double(dustCount - 1))
                let x = sunCenter.x + CGFloat(sin(time * 0.32 + phase)) * 38
                    - CGFloat(yNorm) * size.width * 0.18
                let y = sunCenter.y + CGFloat(yNorm) * size.height * 0.72
                    + CGFloat(cos(time * 0.28 + phase) * 6)
                let radius: CGFloat = 1.2 + CGFloat(index % 3) * 0.6
                let alpha = (0.18 - yNorm * 0.10) * warmth

                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 1.0, green: 0.96, blue: 0.84).opacity(alpha))
                )
            }
        }
    }
}
