import SwiftUI

// MARK: - Lantern History View

/// Displays previous partner beacons as a quiet sea of lights.
///
/// Each historical beacon becomes a small emotion-colored light
/// floating above the water with a subtle reflection below it.
/// Newer entries appear larger and closer; older entries recede.
struct LanternHistoryView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - Properties

    let entries: [BeaconEntry]

    // MARK: - State

    @State private var selectedEntry: BeaconEntry?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            animatedScene

            if entries.isEmpty {
                emptyState
            }

            if let selectedEntry {
                selectedDetails(for: selectedEntry)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(
            .easeInOut(duration: 0.35),
            value: selectedEntry?.id
        )
    }

    // MARK: - Animated Scene

    @ViewBuilder
    private var animatedScene: some View {
        if reduceMotion {
            scene(time: 0)
        } else {
            TimelineView(
                .animation(minimumInterval: 1.0 / 30.0)
            ) { timeline in
                scene(
                    time: timeline.date
                        .timeIntervalSinceReferenceDate
                )
            }
        }
    }

    // MARK: - Scene

    private func scene(
        time: TimeInterval
    ) -> some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                paperSky(in: size)

                stars(in: size)

                moon(in: size)

                clouds(in: size)

                distantHills(in: size)

                ocean(in: size)

                lightField(
                    in: size,
                    time: time
                )

                foregroundWater(
                    in: size,
                    time: time
                )

                vignette
            }
            .frame(
                width: size.width,
                height: size.height
            )
            .clipped()
        }
    }

    // MARK: - Sky

    private func paperSky(
        in size: CGSize
    ) -> some View {
        LinearGradient(
            colors: [
                Color(
                    red: 0.012,
                    green: 0.045,
                    blue: 0.105
                ),
                Color(
                    red: 0.025,
                    green: 0.070,
                    blue: 0.155
                ),
                Color(
                    red: 0.055,
                    green: 0.100,
                    blue: 0.195
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Stars

    private func stars(
        in size: CGSize
    ) -> some View {
        ZStack {
            star(x: 0.08, y: 0.08, scale: 0.65, size: size)
            star(x: 0.20, y: 0.14, scale: 0.45, size: size)
            star(x: 0.32, y: 0.07, scale: 0.70, size: size)
            star(x: 0.44, y: 0.18, scale: 0.40, size: size)
            star(x: 0.58, y: 0.10, scale: 0.72, size: size)
            star(x: 0.70, y: 0.16, scale: 0.50, size: size)
            star(x: 0.83, y: 0.09, scale: 0.60, size: size)
            star(x: 0.91, y: 0.21, scale: 0.78, size: size)
            star(x: 0.13, y: 0.27, scale: 0.48, size: size)
            star(x: 0.73, y: 0.27, scale: 0.52, size: size)
        }
    }

    private func star(
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        size: CGSize
    ) -> some View {
        Circle()
            .fill(
                Color(
                    red: 1.0,
                    green: 0.92,
                    blue: 0.79
                )
                .opacity(0.72)
            )
            .frame(
                width: size.width * 0.007 * scale,
                height: size.width * 0.007 * scale
            )
            .position(
                x: size.width * x,
                y: size.height * y
            )
    }

    // MARK: - Moon

    private func moon(
        in size: CGSize
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    Color(
                        red: 0.96,
                        green: 0.89,
                        blue: 0.76
                    )
                )

            Circle()
                .fill(
                    Color(
                        red: 0.016,
                        green: 0.050,
                        blue: 0.115
                    )
                )
                .offset(
                    x: size.width * 0.023,
                    y: -size.width * 0.010
                )
        }
        .frame(
            width: size.width * 0.082,
            height: size.width * 0.082
        )
        .shadow(
            color: .black.opacity(0.30),
            radius: 3,
            x: 1,
            y: 3
        )
        .position(
            x: size.width * 0.20,
            y: size.height * 0.145
        )
    }

    // MARK: - Clouds

    private func clouds(
        in size: CGSize
    ) -> some View {
        ZStack {
            HistoryCloudShape()
                .fill(
                    Color(
                        red: 0.13,
                        green: 0.21,
                        blue: 0.33
                    )
                )
                .frame(
                    width: size.width * 0.37,
                    height: size.height * 0.085
                )
                .position(
                    x: size.width * 0.08,
                    y: size.height * 0.34
                )

            HistoryCloudShape()
                .fill(
                    Color(
                        red: 0.16,
                        green: 0.25,
                        blue: 0.38
                    )
                )
                .frame(
                    width: size.width * 0.33,
                    height: size.height * 0.075
                )
                .position(
                    x: size.width * 0.92,
                    y: size.height * 0.30
                )
        }
        .shadow(
            color: .black.opacity(0.34),
            radius: 2,
            x: 0,
            y: 4
        )
    }

    // MARK: - Hills

    private func distantHills(
        in size: CGSize
    ) -> some View {
        ZStack {
            HistoryHillShape()
                .fill(
                    Color(
                        red: 0.065,
                        green: 0.105,
                        blue: 0.205
                    )
                )
                .frame(
                    width: size.width * 1.20,
                    height: size.height * 0.15
                )
                .position(
                    x: size.width * 0.48,
                    y: size.height * 0.53
                )

            HistoryHillShape()
                .fill(
                    Color(
                        red: 0.095,
                        green: 0.145,
                        blue: 0.260
                    )
                )
                .frame(
                    width: size.width * 1.20,
                    height: size.height * 0.11
                )
                .position(
                    x: size.width * 0.60,
                    y: size.height * 0.56
                )
        }
    }

    // MARK: - Ocean

    private func ocean(
        in size: CGSize
    ) -> some View {
        ZStack {
            HistoryOceanShape(
                phase: 0,
                amplitude: size.height * 0.008
            )
            .fill(
                Color(
                    red: 0.055,
                    green: 0.105,
                    blue: 0.210
                )
            )
            .frame(
                width: size.width * 1.22,
                height: size.height * 0.50
            )
            .position(
                x: size.width * 0.50,
                y: size.height * 0.76
            )

            HistoryOceanShape(
                phase: 1.4,
                amplitude: size.height * 0.010
            )
            .fill(
                Color(
                    red: 0.036,
                    green: 0.078,
                    blue: 0.170
                )
            )
            .frame(
                width: size.width * 1.22,
                height: size.height * 0.42
            )
            .position(
                x: size.width * 0.50,
                y: size.height * 0.82
            )

            HistoryOceanShape(
                phase: 2.7,
                amplitude: size.height * 0.012
            )
            .fill(
                Color(
                    red: 0.020,
                    green: 0.055,
                    blue: 0.135
                )
            )
            .frame(
                width: size.width * 1.22,
                height: size.height * 0.34
            )
            .position(
                x: size.width * 0.50,
                y: size.height * 0.88
            )
        }
    }

    // MARK: - Sea of Lights

    private func lightField(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        ZStack {
            ForEach(
                Array(displayEntries.enumerated()),
                id: \.element.id
            ) { index, entry in
                historicalLight(
                    entry: entry,
                    index: index,
                    size: size,
                    time: time
                )
            }
        }
    }

    private var displayEntries: [BeaconEntry] {
        Array(
            entries
                .sorted { $0.date > $1.date }
                .prefix(18)
        )
    }

    private func historicalLight(
        entry: BeaconEntry,
        index: Int,
        size: CGSize,
        time: TimeInterval
    ) -> some View {
        let placement =
            lightPlacement(for: index)

        let emotionColor =
            Color(hex: entry.colorHex)

        let bob =
            reduceMotion
                ? 0
                : sin(
                    time * placement.speed +
                    placement.phase
                ) * placement.bobAmount

        let pulse =
            reduceMotion
                ? 1
                : 0.93 +
                    sin(
                        time * 0.70 +
                        placement.phase
                    ) * 0.07

        return Button {
            withAnimation(
                .easeInOut(duration: 0.35)
            ) {
                selectedEntry = entry
            }
        } label: {
            ZStack {
                lightReflection(
                    color: emotionColor,
                    intensity: pulse
                )
                .frame(
                    width:
                        size.width *
                        placement.scale *
                        1.35,
                    height:
                        size.width *
                        placement.scale *
                        1.05
                )
                .offset(
                    y:
                        size.width *
                        placement.scale *
                        0.62
                )

                lightGlow(
                    color: emotionColor,
                    intensity: pulse
                )
                .frame(
                    width:
                        size.width *
                        placement.scale *
                        1.65,
                    height:
                        size.width *
                        placement.scale *
                        1.20
                )

                lightCore(
                    color: emotionColor,
                    intensity: pulse
                )
                .frame(
                    width:
                        size.width *
                        placement.scale *
                        0.22,
                    height:
                        size.width *
                        placement.scale *
                        0.22
                )
            }
            .offset(y: bob)
        }
        .buttonStyle(.plain)
        .position(
            x: size.width * placement.x,
            y: size.height * placement.y
        )
        .zIndex(placement.zIndex)
        .accessibilityLabel(
            "Beacon from \(entry.date.formatted(date: .abbreviated, time: .omitted))"
        )
    }

    // MARK: - Light Core

    private func lightCore(
        color: Color,
        intensity: Double
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.70),
                        color.opacity(1.0 * intensity),
                        color.opacity(0.65 * intensity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 18
                )
            )
            .shadow(
                color: color.opacity(0.80 * intensity),
                radius: 6
            )
            .blendMode(.screen)
    }

    // MARK: - Light Glow

    private func lightGlow(
        color: Color,
        intensity: Double
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.40 * intensity),
                        color.opacity(0.18 * intensity),
                        color.opacity(0.055 * intensity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 78
                )
            )
            .scaleEffect(
                x: 1.35,
                y: 0.82
            )
            .blur(radius: 12)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    // MARK: - Reflection

    private func lightReflection(
        color: Color,
        intensity: Double
    ) -> some View {
        VStack(spacing: 2) {
            reflectionStrip(
                color: color,
                width: 0.28,
                opacity: 0.54 * intensity
            )

            reflectionStrip(
                color: color,
                width: 0.52,
                opacity: 0.42 * intensity
            )

            reflectionStrip(
                color: color,
                width: 0.38,
                opacity: 0.31 * intensity
            )

            reflectionStrip(
                color: color,
                width: 0.66,
                opacity: 0.22 * intensity
            )

            reflectionStrip(
                color: color,
                width: 0.46,
                opacity: 0.14 * intensity
            )
        }
        .blendMode(.screen)
    }

    private func reflectionStrip(
        color: Color,
        width: CGFloat,
        opacity: Double
    ) -> some View {
        GeometryReader { geometry in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            color.opacity(opacity),
                            color.opacity(opacity * 0.72),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width:
                        geometry.size.width *
                        width,
                    height: 1.4
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
        }
        .frame(height: 3)
    }

    // MARK: - Light Placement

    private func lightPlacement(
        for index: Int
    ) -> LightPlacement {
        let placements: [LightPlacement] = [
            .init(x: 0.52, y: 0.69, scale: 0.18, phase: 0.0, speed: 0.55, bobAmount: 2.8, zIndex: 18),
            .init(x: 0.28, y: 0.73, scale: 0.14, phase: 0.8, speed: 0.48, bobAmount: 2.4, zIndex: 17),
            .init(x: 0.76, y: 0.74, scale: 0.13, phase: 1.6, speed: 0.52, bobAmount: 2.3, zIndex: 16),
            .init(x: 0.15, y: 0.78, scale: 0.10, phase: 2.3, speed: 0.45, bobAmount: 2.0, zIndex: 15),
            .init(x: 0.88, y: 0.79, scale: 0.095, phase: 2.9, speed: 0.50, bobAmount: 1.9, zIndex: 14),
            .init(x: 0.42, y: 0.80, scale: 0.094, phase: 3.5, speed: 0.43, bobAmount: 1.9, zIndex: 13),
            .init(x: 0.65, y: 0.82, scale: 0.085, phase: 4.0, speed: 0.49, bobAmount: 1.7, zIndex: 12),
            .init(x: 0.24, y: 0.85, scale: 0.072, phase: 4.6, speed: 0.42, bobAmount: 1.5, zIndex: 11),
            .init(x: 0.82, y: 0.86, scale: 0.068, phase: 5.1, speed: 0.46, bobAmount: 1.4, zIndex: 10),
            .init(x: 0.50, y: 0.87, scale: 0.067, phase: 5.7, speed: 0.41, bobAmount: 1.4, zIndex: 9),
            .init(x: 0.10, y: 0.89, scale: 0.055, phase: 6.2, speed: 0.44, bobAmount: 1.2, zIndex: 8),
            .init(x: 0.91, y: 0.90, scale: 0.053, phase: 6.8, speed: 0.40, bobAmount: 1.1, zIndex: 7),
            .init(x: 0.36, y: 0.91, scale: 0.052, phase: 7.2, speed: 0.38, bobAmount: 1.0, zIndex: 6),
            .init(x: 0.69, y: 0.92, scale: 0.049, phase: 7.8, speed: 0.43, bobAmount: 1.0, zIndex: 5),
            .init(x: 0.20, y: 0.94, scale: 0.042, phase: 8.3, speed: 0.37, bobAmount: 0.8, zIndex: 4),
            .init(x: 0.79, y: 0.945, scale: 0.040, phase: 8.8, speed: 0.39, bobAmount: 0.8, zIndex: 3),
            .init(x: 0.46, y: 0.955, scale: 0.037, phase: 9.3, speed: 0.36, bobAmount: 0.7, zIndex: 2),
            .init(x: 0.61, y: 0.96, scale: 0.035, phase: 9.9, speed: 0.35, bobAmount: 0.7, zIndex: 1)
        ]

        return placements[
            min(
                index,
                placements.count - 1
            )
        ]
    }

    // MARK: - Foreground Water

    private func foregroundWater(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        let phase =
            reduceMotion
                ? 0
                : CGFloat(time * 0.13)

        return HistoryOceanShape(
            phase: phase,
            amplitude: size.height * 0.014
        )
        .fill(
            Color(
                red: 0.012,
                green: 0.036,
                blue: 0.095
            )
        )
        .frame(
            width: size.width * 1.22,
            height: size.height * 0.18
        )
        .position(
            x: size.width * 0.50,
            y: size.height * 0.97
        )
        .shadow(
            color: .black.opacity(0.44),
            radius: 3,
            x: 0,
            y: -3
        )
        .allowsHitTesting(false)
    }

    // MARK: - Selected Details

    private func selectedDetails(
        for entry: BeaconEntry
    ) -> some View {
        ZStack {
            Color.black
                .opacity(0.50)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: entry.colorHex)
                        .opacity(0.16),
                    Color.clear
                ],
                center: .center,
                startRadius: 1,
                endRadius: 260
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .blendMode(.screen)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.20),
                        Color.black.opacity(0.60),
                        Color.black.opacity(0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 360)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                Spacer()

                BeaconDetailsView(
                    entry: entry
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 108)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(
                .easeInOut(duration: 0.35)
            ) {
                selectedEntry = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "water.waves")
                .font(.system(size: 28))
                .foregroundStyle(
                    .white.opacity(0.40)
                )

            Text("No lights yet")
                .font(.headline)
                .foregroundStyle(
                    .white.opacity(0.75)
                )

            Text(
                "Previous beacons will quietly gather here over time."
            )
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(0.45)
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 48)

            Spacer()
                .frame(height: 130)
        }
    }

    // MARK: - Vignette

    private var vignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.04),
                Color.black.opacity(0.27)
            ],
            center: .center,
            startRadius: 160,
            endRadius: 620
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Light Placement

private struct LightPlacement {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let phase: Double
    let speed: Double
    let bobAmount: CGFloat
    let zIndex: Double
}

// MARK: - Cloud Shape

private struct HistoryCloudShape: Shape {

    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.maxY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.28,
                y: rect.height * 0.46
            ),
            control1: CGPoint(
                x: rect.width * 0.06,
                y: rect.height * 0.78
            ),
            control2: CGPoint(
                x: rect.width * 0.12,
                y: rect.height * 0.44
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.54,
                y: rect.height * 0.25
            ),
            control1: CGPoint(
                x: rect.width * 0.34,
                y: rect.height * 0.14
            ),
            control2: CGPoint(
                x: rect.width * 0.46,
                y: rect.height * 0.15
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: rect.width * 0.71,
                y: rect.height * 0.08
            ),
            control2: CGPoint(
                x: rect.width * 0.89,
                y: rect.height * 0.47
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Hill Shape

private struct HistoryHillShape: Shape {

    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.16,
                y: rect.height * 0.58
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.32,
                y: rect.height * 0.33
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.49,
                y: rect.height * 0.54
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.67,
                y: rect.height * 0.25
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.83,
                y: rect.height * 0.47
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: rect.height * 0.30
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: rect.maxY
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Ocean Shape

private struct HistoryOceanShape: Shape {

    let phase: CGFloat
    let amplitude: CGFloat

    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY + amplitude
            )
        )

        let step: CGFloat = 4

        for x in stride(
            from: rect.minX,
            through: rect.maxX,
            by: step
        ) {
            let progress =
                (x - rect.minX) / rect.width

            let y =
                rect.minY +
                amplitude +
                sin(
                    progress * .pi * 2.2 +
                    phase
                ) *
                amplitude

            path.addLine(
                to: CGPoint(
                    x: x,
                    y: y
                )
            )
        }

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.maxY
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    LanternHistoryView(
        entries:
            Array(
                PartnerBeaconStore
                    .sampleEntries
                    .prefix(8)
            )
    )
}
