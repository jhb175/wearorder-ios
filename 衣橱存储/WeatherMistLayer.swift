import SwiftUI

/// Soft drifting mist bands for `.overcast` and `.drizzle`. The current
/// animation only paints a static radial wash for those kinds; this
/// layer adds slow horizontal drift that reads like real fog.
struct WeatherMistLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let intensity: Intensity
    var isActive: Bool = true

    enum Intensity {
        case soft
        case dense

        var bandCount: Int {
            switch self {
            case .soft: 3
            case .dense: 5
            }
        }

        var alpha: Double {
            switch self {
            case .soft: 0.16
            case .dense: 0.24
            }
        }
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
            for band in 0..<intensity.bandCount {
                let phase = Double(band) * 1.4
                let speed = 0.04 + Double(band) * 0.012
                let driftX = sin(time * speed + phase) * 36
                let driftY = cos(time * speed * 0.7 + phase) * 12

                let bandY = size.height * (0.18 + CGFloat(band) * 0.16)
                let bandHeight = size.height * (0.18 + CGFloat(band) * 0.04)
                let centerX = size.width * 0.66 + CGFloat(driftX)
                let centerY = bandY + CGFloat(driftY)

                let rect = CGRect(
                    x: centerX - size.width * 0.42,
                    y: centerY - bandHeight * 0.5,
                    width: size.width * 0.84,
                    height: bandHeight
                )

                let alpha = intensity.alpha * (1.0 - Double(band) * 0.12)

                var blurContext = context
                blurContext.addFilter(.blur(radius: 14))
                blurContext.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(alpha),
                            Color(red: 0.86, green: 0.90, blue: 0.94).opacity(alpha * 0.6),
                            .clear
                        ]),
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        startRadius: 18,
                        endRadius: rect.width * 0.42
                    )
                )
            }
        }
    }
}
