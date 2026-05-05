import SwiftUI

/// Falling snow particles for the `.snow` weather kind. The current
/// `WeatherAnimationView` has no snow particles at all — `.snow` only
/// differs from `.overcast` by background color, which is the single
/// biggest gap in the existing animation. This layer fills it.
struct WeatherSnowLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isActive: Bool = true

    private static let flakes: [Flake] = (0..<28).map { index in
        // Deterministic-ish hash-spread coordinates; we want stable layout
        // across launches without paying for an RNG seed every time.
        let hash = { (s: Int) -> Double in
            let v = sin(Double(s) * 12.9898 + Double(index) * 78.233) * 43758.5453
            return v - floor(v)
        }
        return Flake(
            x: 0.42 + 0.56 * CGFloat(hash(1)),
            speed: 0.18 + 0.16 * CGFloat(hash(2)),
            radius: 1.4 + 2.2 * CGFloat(hash(3)),
            sway: 6 + 16 * CGFloat(hash(4)),
            phase: 2 * .pi * hash(5),
            depth: 0.34 + 0.66 * CGFloat(hash(6))
        )
    }

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
            for flake in Self.flakes {
                let cycle = size.height + 60
                let yRaw = CGFloat(time) * 60 * flake.speed * flake.depth
                let y = (yRaw.truncatingRemainder(dividingBy: cycle)) - 30
                let xSway = CGFloat(sin(time * 0.42 * Double(flake.depth) + flake.phase)) * flake.sway
                let x = size.width * flake.x + xSway

                let radius = flake.radius * flake.depth
                let opacity = 0.32 + 0.5 * Double(flake.depth)
                let rect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                var blurContext = context
                blurContext.addFilter(.blur(radius: max(2.6 - radius, 0.6)))
                blurContext.fill(
                    Path(ellipseIn: rect.insetBy(dx: -1.2, dy: -1.2)),
                    with: .color(Color.white.opacity(opacity * 0.42))
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(opacity),
                            Color.white.opacity(opacity * 0.4),
                            .clear
                        ]),
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        startRadius: 0.6,
                        endRadius: radius * 1.8
                    )
                )
            }
        }
    }

    private struct Flake {
        let x: CGFloat
        let speed: CGFloat
        let radius: CGFloat
        let sway: CGFloat
        let phase: Double
        let depth: CGFloat
    }
}
