import SwiftUI

struct TenBandEQ: View {
    @ObservedObject private var presetManager = PresetManager.shared

    let frequencies = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    var body: some View {
        VStack(spacing: 8) {
            // Grid of vertical sliders with background grid lines
            ZStack {
                // Horizontal grid lines
                GeometryReader { geometry in
                    let sliderHeight: CGFloat = 100
                    let topPadding: CGFloat = 0

                    // Draw grid lines every 3 dB (-12 to +12 = 9 lines)
                    ForEach(0..<9, id: \.self) { index in
                        let dbValue = 12 - (Float(index) * 3) // +12, +9, +6, +3, 0, -3, -6, -9, -12
                        let yPosition = topPadding + (sliderHeight * CGFloat(index) / 8.0)
                        let isCenterLine = (dbValue == 0)

                        Rectangle()
                            .fill(Color(NSColor.separatorColor).opacity(isCenterLine ? 0.3 : 0.15))
                            .frame(height: 1)
                            .offset(y: yPosition)
                    }
                }
                .frame(height: 100)

                // Sliders on top of grid
                HStack(spacing: 6) {
                    ForEach(0..<10, id: \.self) { index in
                        VStack(spacing: 4) {
                            // Vertical slider
                            VerticalSlider(
                                value: Binding(
                                    get: { presetManager.currentBands[index] },
                                    set: { newValue in
                                        presetManager.updateBand(index: index, gainDb: newValue)
                                    }
                                ),
                                range: -12...12
                            )
                            .frame(width: 20, height: 100)

                            // Frequency label
                            Text(frequencies[index])
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 22)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track background - static, no animation
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 4)

                // Center line (0 dB) - static
                let centerY = geometry.size.height / 2
                Rectangle()
                    .fill(Color(NSColor.tertiaryLabelColor))
                    .frame(width: 20, height: 1)
                    .position(x: geometry.size.width / 2, y: centerY)

                // Filled portion (from center to knob)
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let knobY = geometry.size.height * (1 - CGFloat(normalizedValue))

                // Fill from center line to knob position
                if value != 0 {
                    let fillHeight = abs(knobY - centerY)
                    let fillY = min(knobY, centerY)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 4, height: fillHeight)
                        .position(x: geometry.size.width / 2, y: fillY + fillHeight / 2)
                }

                // Knob
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(NSColor.controlBackgroundColor),
                                Color(NSColor.controlBackgroundColor).opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.separatorColor).opacity(0.8), lineWidth: 0.5)
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 0.5)
                    .position(
                        x: geometry.size.width / 2,
                        y: knobY
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let newValue = 1 - (gesture.location.y / geometry.size.height)
                                let clampedValue = max(0, min(1, newValue))
                                value = range.lowerBound + Float(clampedValue) * (range.upperBound - range.lowerBound)
                            }
                    )
            }
        }
    }
}
