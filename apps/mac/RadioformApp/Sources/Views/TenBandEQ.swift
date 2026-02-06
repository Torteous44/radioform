import SwiftUI
import AppKit

struct TenBandEQ: View {
    @ObservedObject private var presetManager = PresetManager.shared

    let bandFrequencies = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    let displayOrder = [10, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

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
                        let dbValue = 12 - (Float(index) * 3)
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
                HStack(spacing: 0) {
                    ForEach(displayOrder, id: \.self) { index in
                        VStack(spacing: 4) {
                            VerticalSlider(
                                value: index < 10
                                    ? Binding(
                                        get: { presetManager.currentBands[index] },
                                        set: { newValue in
                                            presetManager.updateBand(index: index, gainDb: newValue)
                                        }
                                    )
                                    : Binding(
                                        get: { presetManager.currentPreampDb },
                                        set: { newValue in
                                            presetManager.updatePreamp(gainDb: newValue)
                                        }
                                    ),
                                range: -12...12,
                                isFocused: presetManager.focusedBandIndex == index,
                                onDoubleTap: {
                                    presetManager.toggleFocusedBand(index)
                                }
                            )
                            .frame(width: 20, height: 100)

                            // Frequency label
                            Text(index == 10 ? "Pre" : bandFrequencies[index])
                                .font(.system(size: 9))
                                .foregroundColor(index == 10 ? .accentColor.opacity(0.7) : .secondary)
                                .frame(minWidth: 22)
                        }
                        .padding(.horizontal, 3)

                        if index == 10 {
                            // Subtle separator after preamp knob
                            Rectangle()
                                .fill(Color(NSColor.separatorColor).opacity(0.3))
                                .frame(width: 1, height: 80)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .background(
                // Scroll wheel receiver for Q factor — active when a band (0-9) is focused
                Group {
                    if let focusedIndex = presetManager.focusedBandIndex, focusedIndex < 10 {
                        ScrollWheelReceiver { delta in
                            let currentQ = presetManager.currentQFactors[focusedIndex]
                            let newQ = currentQ + Float(delta) * 0.1
                            presetManager.updateBandQ(index: focusedIndex, qFactor: newQ)
                        }
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                presetManager.setFocusedBand(nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let isFocused: Bool
    let onDoubleTap: () -> Void

    private let normalKnobSize: CGFloat = 16
    private let focusedKnobSize: CGFloat = 22

    private var knobSize: CGFloat {
        isFocused ? focusedKnobSize : normalKnobSize
    }

    private var knobDisplayText: String {
        if value >= 0 {
            return String(format: "+%.1f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 4)

                // Center line (0 dB)
                let centerY = geometry.size.height / 2
                Rectangle()
                    .fill(Color(NSColor.tertiaryLabelColor))
                    .frame(width: 20, height: 1)
                    .position(x: geometry.size.width / 2, y: centerY)

                // Filled portion (from center to knob)
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let knobY = geometry.size.height * (1 - CGFloat(normalizedValue))

                if value != 0 {
                    let fillHeight = abs(knobY - centerY)
                    let fillY = min(knobY, centerY)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 4, height: fillHeight)
                        .position(x: geometry.size.width / 2, y: fillY + fillHeight / 2)
                }

                // Knob
                ZStack {
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
                                .stroke(
                                    isFocused ? Color.accentColor.opacity(0.6) : Color(NSColor.separatorColor).opacity(0.8),
                                    lineWidth: isFocused ? 1.0 : 0.5
                                )
                        )

                    // dB text inside focused knob
                    if isFocused {
                        Text(knobDisplayText)
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 0.5)
                .position(
                    x: geometry.size.width / 2,
                    y: knobY
                )
                .onTapGesture(count: 2) {
                    onDoubleTap()
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
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

// MARK: - Scroll Wheel Receiver (macOS)

struct ScrollWheelReceiver: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        ScrollWheelNSView(onScroll: onScroll)
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollWheelNSView: NSView {
        var onScroll: (CGFloat) -> Void

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func scrollWheel(with event: NSEvent) {
            onScroll(event.deltaY)
        }
    }
}
