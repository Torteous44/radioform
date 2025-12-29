import SwiftUI

struct EQVisualization: View {
    let preset: EQPreset?

    var body: some View {
        Canvas { context, size in
            // Draw background
            context.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                with: .color(.black.opacity(0.05))
            )

            guard let preset = preset, !preset.bands.isEmpty else {
                // Draw flat line when no preset
                drawFlatLine(context: context, size: size)
                return
            }

            // Draw EQ curve
            drawEQCurve(context: context, size: size, preset: preset)
        }
        .frame(height: 80)
        .padding(.horizontal, 12)
    }

    private func drawFlatLine(context: GraphicsContext, size: CGSize) {
        let centerY = size.height / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: centerY))
        path.addLine(to: CGPoint(x: size.width, y: centerY))

        context.stroke(
            path,
            with: .color(.gray.opacity(0.3)),
            lineWidth: 2
        )
    }

    private func drawEQCurve(context: GraphicsContext, size: CGSize, preset: EQPreset) {
        let enabledBands = preset.bands.filter { $0.enabled }
        guard !enabledBands.isEmpty else {
            drawFlatLine(context: context, size: size)
            return
        }

        // Create smooth curve through band points
        var path = Path()
        let padding: CGFloat = 20
        let drawableWidth = size.width - (padding * 2)
        let drawableHeight = size.height - 20
        let centerY = size.height / 2

        // Draw center line (0 dB)
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: padding, y: centerY))
        centerLine.addLine(to: CGPoint(x: size.width - padding, y: centerY))
        context.stroke(centerLine, with: .color(.gray.opacity(0.2)), lineWidth: 1)

        // Draw +12dB and -12dB reference lines
        let maxGainY = centerY - (drawableHeight / 2)
        let minGainY = centerY + (drawableHeight / 2)

        var topLine = Path()
        topLine.move(to: CGPoint(x: padding, y: maxGainY))
        topLine.addLine(to: CGPoint(x: size.width - padding, y: maxGainY))
        context.stroke(topLine, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)

        var bottomLine = Path()
        bottomLine.move(to: CGPoint(x: padding, y: minGainY))
        bottomLine.addLine(to: CGPoint(x: size.width - padding, y: minGainY))
        context.stroke(bottomLine, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)

        // Sort bands by frequency
        let sortedBands = enabledBands.sorted { $0.frequencyHz < $1.frequencyHz }

        // Convert frequency to x position (logarithmic scale)
        func freqToX(_ freq: Float) -> CGFloat {
            let minFreq: Float = 20
            let maxFreq: Float = 20000
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)
            let logFreq = log10(freq)
            let normalized = (logFreq - logMin) / (logMax - logMin)
            return padding + (CGFloat(normalized) * drawableWidth)
        }

        // Convert gain to y position
        func gainToY(_ gain: Float) -> CGFloat {
            let normalized = CGFloat(gain / 12.0) // -12 to +12 dB range
            return centerY - (normalized * (drawableHeight / 2))
        }

        // Build smooth curve through points
        if !sortedBands.isEmpty {
            let firstBand = sortedBands[0]
            let startX = freqToX(firstBand.frequencyHz)
            let startY = gainToY(firstBand.gainDb)

            path.move(to: CGPoint(x: padding, y: centerY))
            path.addLine(to: CGPoint(x: startX, y: startY))

            for i in 0..<sortedBands.count {
                let band = sortedBands[i]
                let x = freqToX(band.frequencyHz)
                let y = gainToY(band.gainDb)

                if i > 0 {
                    let prevBand = sortedBands[i - 1]
                    let prevX = freqToX(prevBand.frequencyHz)
                    let prevY = gainToY(prevBand.gainDb)

                    // Smooth curve between points
                    let controlX1 = prevX + (x - prevX) * 0.5
                    let controlX2 = prevX + (x - prevX) * 0.5

                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: controlX1, y: prevY),
                        control2: CGPoint(x: controlX2, y: y)
                    )
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let lastBand = sortedBands[sortedBands.count - 1]
            let endX = freqToX(lastBand.frequencyHz)
            let endY = gainToY(lastBand.gainDb)
            path.addLine(to: CGPoint(x: size.width - padding, y: centerY))

            // Fill under curve
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width - padding, y: centerY))
            fillPath.addLine(to: CGPoint(x: padding, y: centerY))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .color(.blue.opacity(0.1))
            )

            // Stroke curve
            context.stroke(
                path,
                with: .color(.blue),
                lineWidth: 2.5
            )

            // Draw points
            for band in sortedBands {
                let x = freqToX(band.frequencyHz)
                let y = gainToY(band.gainDb)

                let circle = Path(ellipseIn: CGRect(
                    x: x - 3,
                    y: y - 3,
                    width: 6,
                    height: 6
                ))

                context.fill(circle, with: .color(.blue))
                context.stroke(circle, with: .color(.white), lineWidth: 1.5)
            }
        }
    }
}
