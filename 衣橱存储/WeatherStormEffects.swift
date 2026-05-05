import SwiftUI

/// Lightning system: each strike has a unique branched bolt path
/// generated from a noise function on time, plus a multi-stage
/// flash-strike-afterglow cycle. The legacy engine reused the same
/// fixed zigzag for every flash.
struct WeatherStormEffects: View {
    let palette: WeatherScenePalette
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            guard palette.hasLightning else { return }

            let cycle = strikeCycle(time: time)
            guard cycle.flashIntensity > 0 else { return }

            drawAmbientFlash(in: context, size: size, intensity: cycle.flashIntensity)
            if cycle.boltOpacity > 0.05 {
                drawBolt(
                    in: context,
                    size: size,
                    seed: cycle.strikeSeed,
                    opacity: cycle.boltOpacity
                )
            }
        }
    }

    // MARK: - Cycle

    private struct StrikeCycle {
        let flashIntensity: Double
        let boltOpacity: Double
        let strikeSeed: Int
    }

    private func strikeCycle(time: TimeInterval) -> StrikeCycle {
        let stormPeriod: Double = 6.4
        let phase = time.truncatingRemainder(dividingBy: stormPeriod)
        let strikeSeed = Int(time / stormPeriod)

        // Three-stage strike: pre-flash → main → afterglow.
        let preFlashWindow = 0.10
        let mainWindow = 0.18
        let afterWindow = 0.46

        if phase < preFlashWindow {
            let progress = phase / preFlashWindow
            return StrikeCycle(
                flashIntensity: progress * 0.16,
                boltOpacity: 0,
                strikeSeed: strikeSeed
            )
        }

        if phase < mainWindow {
            let progress = (phase - preFlashWindow) / (mainWindow - preFlashWindow)
            let envelope = sin(progress * .pi)
            return StrikeCycle(
                flashIntensity: envelope * 0.42,
                boltOpacity: envelope,
                strikeSeed: strikeSeed
            )
        }

        if phase < afterWindow {
            let progress = (phase - mainWindow) / (afterWindow - mainWindow)
            return StrikeCycle(
                flashIntensity: (1.0 - progress) * 0.10,
                boltOpacity: max(0, (1.0 - progress) * 0.34),
                strikeSeed: strikeSeed
            )
        }

        // Random secondary flicker mid-cycle
        let secondary = phase.truncatingRemainder(dividingBy: 1.6)
        if secondary < 0.05 {
            let progress = secondary / 0.05
            let envelope = sin(progress * .pi) * 0.18
            return StrikeCycle(
                flashIntensity: envelope * 0.5,
                boltOpacity: envelope * 0.6,
                strikeSeed: strikeSeed + 13
            )
        }

        return StrikeCycle(flashIntensity: 0, boltOpacity: 0, strikeSeed: strikeSeed)
    }

    // MARK: - Drawing

    private func drawAmbientFlash(in context: GraphicsContext, size: CGSize, intensity: Double) {
        let center = CGPoint(x: size.width * 0.72, y: size.height * 0.22)
        let rect = CGRect(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(intensity),
                    Color(red: 0.86, green: 0.90, blue: 1.0).opacity(intensity * 0.46),
                    .clear
                ]),
                center: center,
                startRadius: 8,
                endRadius: max(size.width, size.height) * 0.6
            )
        )
    }

    private func drawBolt(in context: GraphicsContext, size: CGSize, seed: Int, opacity: Double) {
        let path = boltPath(in: size, seed: seed)

        // Glow underlayer.
        var glowContext = context
        glowContext.addFilter(.blur(radius: 8))
        glowContext.stroke(
            path,
            with: .color(Color(red: 0.86, green: 0.90, blue: 1.0).opacity(opacity * 0.46)),
            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        )

        // Crisp main bolt.
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(opacity),
                    Color(red: 0.84, green: 0.92, blue: 1.0).opacity(opacity * 0.92),
                    Color(red: 0.62, green: 0.74, blue: 0.96).opacity(opacity * 0.78)
                ]),
                startPoint: CGPoint(x: size.width * 0.72, y: 0),
                endPoint: CGPoint(x: size.width * 0.62, y: size.height)
            ),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
        )
    }

    private func boltPath(in size: CGSize, seed: Int) -> Path {
        let topX = size.width * (0.66 + 0.10 * CGFloat(noise(seed: seed, component: 0)))
        let segments = 6 + (seed % 3)

        var path = Path()
        var current = CGPoint(x: topX, y: 0)
        path.move(to: current)

        let endY = size.height * (0.74 + 0.12 * CGFloat(noise(seed: seed, component: 99)))

        for index in 0..<segments {
            let progress = CGFloat(index + 1) / CGFloat(segments)
            let segmentSeed = seed * 31 + index
            let xOffset = CGFloat(noise(seed: segmentSeed, component: 1) - 0.5) * size.width * 0.16
            let nextX = topX + xOffset + (progress - 0.5) * size.width * 0.06
            let nextY = progress * endY
            let next = CGPoint(x: nextX, y: nextY)
            path.addLine(to: next)
            current = next

            // Branch occasionally
            if index > 1 && noise(seed: segmentSeed, component: 2) > 0.62 {
                let branchLength = CGFloat(noise(seed: segmentSeed, component: 3)) * size.height * 0.10
                let branchX = current.x + (noise(seed: segmentSeed, component: 4) - 0.5) * 22
                path.move(to: current)
                path.addLine(to: CGPoint(x: branchX, y: current.y + branchLength))
                path.move(to: current)
            }
        }

        return path
    }

    /// Cheap deterministic noise in [0, 1].
    private func noise(seed: Int, component: Int) -> Double {
        let v = sin(Double(seed) * 12.9898 + Double(component) * 78.233) * 43758.5453
        return v - floor(v)
    }
}
