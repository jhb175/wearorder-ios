import SwiftUI

/// Three-layer parallax cloud renderer. Each cloud is built from
/// 3-5 overlapping soft circles to give a billowing cumulus shape
/// instead of the geometric "shelf" / "puff" SVG-style outlines that
/// the legacy engine used.
struct WeatherCloudSystem: View {
    let palette: WeatherScenePalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            for layer in CloudLayer.allCases {
                drawLayer(layer, in: context, size: size)
            }

            // PartlyCloudy hero cloud occludes the sun — this is the layer
            // that makes partlyCloudy actually distinct from sunny.
            if palette.cloudOccludesSun {
                drawHeroOccluder(in: context, size: size)
            }
        }
    }

    private func drawLayer(_ layer: CloudLayer, in context: GraphicsContext, size: CGSize) {
        let specs = clouds(for: layer)
        for spec in specs {
            let center = cloudCenter(for: spec, layer: layer, size: size)

            drawCumulus(
                in: context,
                center: center,
                width: size.width * spec.width,
                height: size.height * spec.height,
                opacity: spec.opacity * palette.cloudOpacity * layer.opacityMultiplier,
                blur: layer.blur,
                tint: palette.cloudTint
            )
        }
    }

    private func cloudCenter(for spec: CloudSpec, layer: CloudLayer, size: CGSize) -> CGPoint {
        // All weather kinds stream clouds left-to-right and wrap. Speed
        // is `linearDriftSpeed * palette.cloudDriftMultiplier` so calm
        // weather (sunny) drifts gently and windy/storms blow harder.
        // spec.x is ignored — clouds enter from the left edge and exit
        // past the right; spec.phase distributes them along the cycle.
        let cycleWidth = size.width * 1.7
        let pxPerSec = layer.linearDriftSpeed * CGFloat(palette.cloudDriftMultiplier)
        let phaseOffset = (spec.phase / (.pi * 2)) * cycleWidth
        let raw = time * Double(pxPerSec) + phaseOffset
        let traveled = raw.truncatingRemainder(dividingBy: Double(cycleWidth))
        let x = -size.width * 0.35 + CGFloat(traveled)
        let yBob = CGFloat(cos(time * 0.5 + spec.phase)) * size.height * 0.012
        return CGPoint(x: x, y: size.height * spec.y + yBob)
    }

    private func drawHeroOccluder(in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(
            x: size.width * 0.74 + CGFloat(sin(time * 0.22)) * 18,
            y: size.height * 0.26 + CGFloat(cos(time * 0.28)) * 9
        )

        // Slightly warm underbelly: sun behind the cloud catches the
        // bottom edge.
        drawCumulus(
            in: context,
            center: CGPoint(x: center.x, y: center.y + 6),
            width: size.width * 0.72,
            height: size.height * 0.40,
            opacity: 0.42,
            blur: 8,
            tint: Color(red: 1.0, green: 0.92, blue: 0.78)
        )

        drawCumulus(
            in: context,
            center: center,
            width: size.width * 0.66,
            height: size.height * 0.36,
            opacity: 0.96,
            blur: 4,
            tint: palette.cloudTint
        )
    }

    private func drawCumulus(
        in context: GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        opacity: Double,
        blur: CGFloat,
        tint: Color
    ) {
        // Three overlapping soft circles arranged horizontally — this is
        // the cheapest shape that reads as "fluffy cloud" without
        // looking like a stretched ellipse.
        let circles: [(CGPoint, CGFloat)] = [
            (CGPoint(x: center.x - width * 0.32, y: center.y + height * 0.10), height * 0.62),
            (CGPoint(x: center.x - width * 0.10, y: center.y - height * 0.16), height * 0.78),
            (CGPoint(x: center.x + width * 0.14, y: center.y - height * 0.08), height * 0.72),
            (CGPoint(x: center.x + width * 0.32, y: center.y + height * 0.12), height * 0.58)
        ]

        var blurredContext = context
        if blur > 0 {
            blurredContext.addFilter(.blur(radius: blur))
        }

        // Underbelly shadow for depth.
        let shadowTint = Color(red: 0.50, green: 0.58, blue: 0.70)
        for (point, radius) in circles {
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius * 0.78,
                width: radius * 2,
                height: radius * 1.56
            )
            blurredContext.fill(
                Path(ellipseIn: rect.offsetBy(dx: 0, dy: radius * 0.34)),
                with: .color(shadowTint.opacity(opacity * 0.18))
            )
        }

        // Main body.
        for (point, radius) in circles {
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius * 0.78,
                width: radius * 2,
                height: radius * 1.56
            )
            blurredContext.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        tint.opacity(opacity),
                        tint.opacity(opacity * 0.74),
                        tint.opacity(opacity * 0.42)
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.16),
                    startRadius: 2,
                    endRadius: radius * 1.2
                )
            )
        }

        // Top highlight sliver.
        if !shouldSuppressHighlight {
            for (point, radius) in circles {
                let rect = CGRect(
                    x: point.x - radius * 0.9,
                    y: point.y - radius * 0.78,
                    width: radius * 1.8,
                    height: radius * 0.62
                )
                blurredContext.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(opacity * 0.20))
                )
            }
        }
    }

    private var shouldSuppressHighlight: Bool {
        switch palette.kind {
        case .heavyRain, .thunderstorm: true
        default: false
        }
    }

    // MARK: - Cloud specs per kind

    private struct CloudSpec {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let opacity: Double
        let phase: Double
    }

    private func clouds(for layer: CloudLayer) -> [CloudSpec] {
        // Phases are evenly distributed in [0, 2π] per layer so that
        // clouds appear as a continuous stream rather than clumping
        // when the linear-drift system wraps the cycle.
        switch palette.kind {
        case .sunny:
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.18, width: 0.34, height: 0.18, opacity: 0.32, phase: 0),
                    CloudSpec(x: 0, y: 0.26, width: 0.30, height: 0.16, opacity: 0.28, phase: .pi)
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.46, width: 0.34, height: 0.16, opacity: 0.40, phase: .pi * 0.5),
                    CloudSpec(x: 0, y: 0.58, width: 0.32, height: 0.14, opacity: 0.32, phase: .pi * 1.5)
                ]
            case .near:
                return []
            }
        case .partlyCloudy:
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.18, width: 0.34, height: 0.18, opacity: 0.42, phase: 0)
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.42, width: 0.38, height: 0.22, opacity: 0.62, phase: 0),
                    CloudSpec(x: 0, y: 0.50, width: 0.36, height: 0.20, opacity: 0.50, phase: .pi)
                ]
            case .near:
                return [
                    CloudSpec(x: 0, y: 0.72, width: 0.42, height: 0.20, opacity: 0.42, phase: .pi * 0.5)
                ]
            }
        case .overcast, .drizzle:
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.16, width: 0.42, height: 0.20, opacity: 0.64, phase: 0),
                    CloudSpec(x: 0, y: 0.20, width: 0.40, height: 0.20, opacity: 0.62, phase: .pi * (2.0 / 3.0)),
                    CloudSpec(x: 0, y: 0.18, width: 0.44, height: 0.20, opacity: 0.66, phase: .pi * (4.0 / 3.0))
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.38, width: 0.48, height: 0.24, opacity: 0.86, phase: .pi * (1.0 / 3.0)),
                    CloudSpec(x: 0, y: 0.46, width: 0.46, height: 0.22, opacity: 0.84, phase: .pi),
                    CloudSpec(x: 0, y: 0.42, width: 0.50, height: 0.24, opacity: 0.82, phase: .pi * (5.0 / 3.0))
                ]
            case .near:
                return [
                    CloudSpec(x: 0, y: 0.66, width: 0.52, height: 0.22, opacity: 0.60, phase: 0),
                    CloudSpec(x: 0, y: 0.72, width: 0.50, height: 0.20, opacity: 0.58, phase: .pi)
                ]
            }
        case .heavyRain, .thunderstorm:
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.12, width: 0.46, height: 0.20, opacity: 0.76, phase: 0),
                    CloudSpec(x: 0, y: 0.16, width: 0.44, height: 0.22, opacity: 0.78, phase: .pi * (2.0 / 3.0)),
                    CloudSpec(x: 0, y: 0.14, width: 0.48, height: 0.20, opacity: 0.74, phase: .pi * (4.0 / 3.0))
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.34, width: 0.54, height: 0.28, opacity: 0.92, phase: .pi * (1.0 / 3.0)),
                    CloudSpec(x: 0, y: 0.40, width: 0.50, height: 0.26, opacity: 0.94, phase: .pi),
                    CloudSpec(x: 0, y: 0.36, width: 0.56, height: 0.28, opacity: 0.90, phase: .pi * (5.0 / 3.0))
                ]
            case .near:
                return [
                    CloudSpec(x: 0, y: 0.62, width: 0.58, height: 0.26, opacity: 0.68, phase: 0),
                    CloudSpec(x: 0, y: 0.68, width: 0.54, height: 0.24, opacity: 0.70, phase: .pi)
                ]
            }
        case .windy:
            // In windy mode spec.x is ignored (clouds stream linearly), but
            // y, size, opacity and phase still matter. Phase is evenly
            // spaced so the stream is continuous instead of clumping.
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.16, width: 0.36, height: 0.16, opacity: 0.40, phase: 0.0),
                    CloudSpec(x: 0, y: 0.22, width: 0.40, height: 0.14, opacity: 0.36, phase: .pi * 0.5),
                    CloudSpec(x: 0, y: 0.18, width: 0.34, height: 0.16, opacity: 0.32, phase: .pi),
                    CloudSpec(x: 0, y: 0.26, width: 0.38, height: 0.14, opacity: 0.34, phase: .pi * 1.5)
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.42, width: 0.42, height: 0.18, opacity: 0.58, phase: 0.0),
                    CloudSpec(x: 0, y: 0.48, width: 0.46, height: 0.20, opacity: 0.62, phase: .pi * 0.66),
                    CloudSpec(x: 0, y: 0.46, width: 0.40, height: 0.18, opacity: 0.50, phase: .pi * 1.32)
                ]
            case .near:
                return [
                    CloudSpec(x: 0, y: 0.68, width: 0.50, height: 0.22, opacity: 0.40, phase: 0.0),
                    CloudSpec(x: 0, y: 0.72, width: 0.46, height: 0.20, opacity: 0.36, phase: .pi)
                ]
            }
        case .snow:
            switch layer {
            case .far:
                return [
                    CloudSpec(x: 0, y: 0.16, width: 0.44, height: 0.18, opacity: 0.66, phase: 0),
                    CloudSpec(x: 0, y: 0.20, width: 0.40, height: 0.18, opacity: 0.62, phase: .pi * (2.0 / 3.0)),
                    CloudSpec(x: 0, y: 0.18, width: 0.42, height: 0.18, opacity: 0.64, phase: .pi * (4.0 / 3.0))
                ]
            case .mid:
                return [
                    CloudSpec(x: 0, y: 0.40, width: 0.50, height: 0.24, opacity: 0.78, phase: .pi * 0.5),
                    CloudSpec(x: 0, y: 0.46, width: 0.46, height: 0.22, opacity: 0.74, phase: .pi * 1.5)
                ]
            case .near:
                return [
                    CloudSpec(x: 0, y: 0.68, width: 0.54, height: 0.22, opacity: 0.54, phase: 0),
                    CloudSpec(x: 0, y: 0.72, width: 0.50, height: 0.20, opacity: 0.50, phase: .pi)
                ]
            }
        }
    }

    enum CloudLayer: CaseIterable {
        case far
        case mid
        case near

        /// Pixels per second of left-to-right drift, scaled by
        /// `palette.cloudDriftMultiplier`. Far/mid/near give parallax.
        var linearDriftSpeed: CGFloat {
            switch self {
            case .far: 22
            case .mid: 38
            case .near: 56
            }
        }

        var blur: CGFloat {
            switch self {
            case .far: 8
            case .mid: 4
            case .near: 2
            }
        }

        var opacityMultiplier: Double {
            switch self {
            case .far: 0.74
            case .mid: 1.0
            case .near: 0.82
            }
        }
    }
}
