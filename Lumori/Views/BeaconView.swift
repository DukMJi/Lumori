import SwiftUI

// MARK: - Beacon View

/// Displays Lumori's animated paper-cut lighthouse scene.
///
/// The imported artwork supplies the lighthouse, moon, clouds,
/// rocks, and layered ocean. SwiftUI adds the current emotion
/// color to the lantern and water.
///
/// Tapping remains the responsibility of the parent view.
struct BeaconView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - Properties

    /// Color associated with the active beacon.
    let color: Color
    
    /// Controls whether the emotion glow and reflection are visible.
    var isActive = true

    /// When true, the scene fills its available parent.
    var fillsAvailableSpace = false
    
    /// Darkens the environment while keeping the emotion lighting visible.
    var isEnvironmentDimmed = false
    
    // MARK: - Scene Alignment

    /// Shared horizontal centerline for all emotion lighting.
    ///
    /// The lighthouse in PaperLighthouseBase sits slightly right of the
    /// mathematical center of the canvas, so all dynamic light effects
    /// should use the same corrected center.
    private let beaconCenterX: CGFloat = 0.610

    // MARK: - Animation State

    @State private var isRevealed = false
    @State private var isBreathing = false

    // MARK: - Body

    var body: some View {
        Group {
            if fillsAvailableSpace {
                animatedScene
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            } else {
                animatedScene
                    .aspectRatio(
                        9.0 / 16.0,
                        contentMode: .fit
                    )
            }
        }
        .background(Color.black)
        .opacity(isRevealed ? 1 : 0)
        .scaleEffect(isRevealed ? 1 : 0.985)
        .onAppear {
            beginAnimations()
        }
        .accessibilityHidden(true)
    }

    // MARK: - Animated Scene

    @ViewBuilder
    private var animatedScene: some View {
        if reduceMotion {
            scene(time: 0)
        } else {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0
                )
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
                Color.black

                shiftedArtwork(in: size)

                // MARK: Environment Dimming

                Color.black
                    .opacity(
                        isEnvironmentDimmed
                            ? 0.44
                            : 0
                    )
                    .animation(
                        .easeInOut(duration: 0.35),
                        value: isEnvironmentDimmed
                    )
                    .allowsHitTesting(false)

                // These stay ABOVE the darkening layer so the beacon
                // remains visually alive while the environment recedes.
                if isActive {
                    shiftedLanternLighting(
                        in: size
                    )

                    waterReflection(
                        in: size,
                        time: time
                    )
                }

                sceneVignette
            }
            
            .frame(
                width: size.width,
                height: size.height
            )
            .clipped()
        }
    }

    // MARK: - Artwork

    private func shiftedArtwork(
        in size: CGSize
    ) -> some View {
        Image(
            isActive
                ? "PaperLighthouseBase"
                : "PaperLighthouseBaseDark"
        )
        .resizable()
        .scaledToFill()
        .scaleEffect(1.055)
        .offset(y: size.height * 0.038)
        .allowsHitTesting(false)
    }

    // MARK: - Lighting Group

    private func shiftedLanternLighting(
        in size: CGSize
    ) -> some View {
        ZStack {
            lanternAtmosphere(in: size)

            downwardLightWash(in: size)

            lanternGlow(in: size)
        }
        .offset(y: size.height * 0.038)
        .allowsHitTesting(false)
    }

    // MARK: - Lantern Atmosphere

    /// Creates a wider, flatter halo around the lantern.
    ///
    /// The light spreads horizontally rather than appearing
    /// as a large circular orb.
    private func lanternAtmosphere(
        in size: CGSize
    ) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(
                                isBreathing ? 0.60 : 0.44
                            ),
                            color.opacity(0.32),
                            color.opacity(0.13),
                            color.opacity(0.040),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: size.width * 0.39
                    )
                )
                .frame(
                    width: size.width * 0.82,
                    height: size.width * 0.36
                )
                .scaleEffect(
                    x: isBreathing ? 1.035 : 0.98,
                    y: isBreathing ? 1.015 : 0.99
                )
                .blur(radius: size.width * 0.040)

            Ellipse()
                .fill(
                    color.opacity(
                        isBreathing ? 0.24 : 0.15
                    )
                )
                .frame(
                    width: size.width * 0.52,
                    height: size.width * 0.19
                )
                .blur(radius: size.width * 0.050)
        }
        .blendMode(.screen)
        .position(
            x: size.width * beaconCenterX,
            y: size.height * 0.304
        )
    }

    // MARK: - Downward Light Wash

    /// Adds only a faint amount of emotion color to the tower.
    private func downwardLightWash(
        in size: CGSize
    ) -> some View {
        LinearGradient(
            colors: [
                color.opacity(
                    isBreathing ? 0.080 : 0.045
                ),
                color.opacity(0.025),
                color.opacity(0.008),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(
            width: size.width * 0.23,
            height: size.height * 0.17
        )
        .mask {
            DownwardLightShape()
                .fill(Color.white)
        }
        .blur(radius: size.width * 0.020)
        .blendMode(.screen)
        .position(
            x: size.width * beaconCenterX,
            y: size.height * 0.392
        )
    }

    // MARK: - Lantern Glow

    /// Keeps only a small pale center while allowing the
    /// emotion color to dominate the lantern glass.
    private func lanternGlow(
        in size: CGSize
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            color.opacity(1.0),
                            color.opacity(1.0),
                            color.opacity(0.90),
                            color.opacity(0.54),
                            color.opacity(0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size.width * 0.083
                    )
                )
                .frame(
                    width: size.width * 0.17,
                    height: size.width * 0.17
                )
                .scaleEffect(
                    isBreathing ? 1.085 : 0.96
                )

            Ellipse()
                .fill(
                    color.opacity(
                        isBreathing ? 0.50 : 0.34
                    )
                )
                .frame(
                    width: size.width * 0.27,
                    height: size.width * 0.20
                )
                .blur(radius: size.width * 0.052)
        }
        .blendMode(.screen)
        .position(
            x: size.width * beaconCenterX,
            y: size.height * 0.304
        )
    }

    // MARK: - Water Reflection

    /// Creates a broad reflection near the waterline that fades
    /// before reaching too far into the foreground.
    private func waterReflection(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        let reflectionTop = size.height * 0.790
        let reflectionHeight = size.height * 0.125

        return ZStack(alignment: .top) {
            illuminatedWaterHaze(
                in: size,
                time: time
            )
            .offset(y: size.height * 0.002)

            VStack(
                spacing: size.height * 0.0046
            ) {
                reflectionRow(
                    size: size,
                    time: time,
                    index: 0,
                    pieces: [
                        ReflectionPiece(
                            width: 0.150,
                            height: 0.0046,
                            opacity: 1.00,
                            offset: -3
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 1,
                    pieces: [
                        ReflectionPiece(
                            width: 0.100,
                            height: 0.0040,
                            opacity: 0.97,
                            offset: -22
                        ),
                        ReflectionPiece(
                            width: 0.075,
                            height: 0.0037,
                            opacity: 0.80,
                            offset: 28
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 2,
                    pieces: [
                        ReflectionPiece(
                            width: 0.205,
                            height: 0.0052,
                            opacity: 0.94,
                            offset: 7
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 3,
                    pieces: [
                        ReflectionPiece(
                            width: 0.130,
                            height: 0.0045,
                            opacity: 0.88,
                            offset: 21
                        ),
                        ReflectionPiece(
                            width: 0.075,
                            height: 0.0037,
                            opacity: 0.69,
                            offset: -32
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 4,
                    pieces: [
                        ReflectionPiece(
                            width: 0.265,
                            height: 0.0057,
                            opacity: 0.84,
                            offset: -7
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 5,
                    pieces: [
                        ReflectionPiece(
                            width: 0.160,
                            height: 0.0047,
                            opacity: 0.77,
                            offset: -29
                        ),
                        ReflectionPiece(
                            width: 0.105,
                            height: 0.0040,
                            opacity: 0.62,
                            offset: 36
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 6,
                    pieces: [
                        ReflectionPiece(
                            width: 0.320,
                            height: 0.0061,
                            opacity: 0.72,
                            offset: 5
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 7,
                    pieces: [
                        ReflectionPiece(
                            width: 0.185,
                            height: 0.0049,
                            opacity: 0.63,
                            offset: 30
                        ),
                        ReflectionPiece(
                            width: 0.095,
                            height: 0.0038,
                            opacity: 0.48,
                            offset: -41
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 8,
                    pieces: [
                        ReflectionPiece(
                            width: 0.350,
                            height: 0.0062,
                            opacity: 0.56,
                            offset: -9
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 9,
                    pieces: [
                        ReflectionPiece(
                            width: 0.195,
                            height: 0.0048,
                            opacity: 0.46,
                            offset: -33
                        ),
                        ReflectionPiece(
                            width: 0.120,
                            height: 0.0040,
                            opacity: 0.36,
                            offset: 40
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 10,
                    pieces: [
                        ReflectionPiece(
                            width: 0.310,
                            height: 0.0058,
                            opacity: 0.39,
                            offset: 7
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 11,
                    pieces: [
                        ReflectionPiece(
                            width: 0.165,
                            height: 0.0044,
                            opacity: 0.29,
                            offset: 30
                        ),
                        ReflectionPiece(
                            width: 0.085,
                            height: 0.0035,
                            opacity: 0.21,
                            offset: -40
                        )
                    ]
                )

                reflectionRow(
                    size: size,
                    time: time,
                    index: 12,
                    pieces: [
                        ReflectionPiece(
                            width: 0.230,
                            height: 0.0050,
                            opacity: 0.20,
                            offset: -8
                        )
                    ]
                )
            }
        }
        .frame(
            width: size.width,
            height: reflectionHeight,
            alignment: .top
        )
        .position(
            x: size.width * beaconCenterX,
            y: reflectionTop + reflectionHeight / 2
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - Illuminated Water Haze

    /// Adds a faint area of emotion color to the surrounding water.
    ///
    /// This helps the reflection feel like emitted light rather than
    /// isolated bright fragments.
    private func illuminatedWaterHaze(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        let pulse =
            reduceMotion
                ? 0
                : sin(time * 0.50)

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(
                                0.35 + pulse * 0.025
                            ),
                            color.opacity(0.17),
                            color.opacity(0.055),
                            color.opacity(0.012),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 1,
                        endRadius: size.height * 0.14
                    )
                )
                .frame(
                    width: size.width * 0.62,
                    height: size.height * 0.145
                )
                .blur(radius: size.width * 0.026)

            Ellipse()
                .fill(
                    color.opacity(
                        0.045 + pulse * 0.006
                    )
                )
                .frame(
                    width: size.width * 0.78,
                    height: size.height * 0.11
                )
                .blur(radius: size.width * 0.042)
                .offset(y: size.height * 0.020)
        }
    }

    // MARK: - Reflection Row

    private func reflectionRow(
        size: CGSize,
        time: TimeInterval,
        index: Int,
        pieces: [ReflectionPiece]
    ) -> some View {
        ZStack {
            ForEach(
                Array(pieces.enumerated()),
                id: \.offset
            ) { pieceIndex, piece in
                reflectionPiece(
                    size: size,
                    time: time,
                    rowIndex: index,
                    pieceIndex: pieceIndex,
                    piece: piece
                )
            }
        }
        .frame(
            width: size.width,
            height: size.height * 0.0068
        )
    }

    // MARK: - Reflection Piece

    private func reflectionPiece(
        size: CGSize,
        time: TimeInterval,
        rowIndex: Int,
        pieceIndex: Int,
        piece: ReflectionPiece
    ) -> some View {
        let mainPhase =
            time * 0.46 +
            Double(rowIndex) * 0.73 +
            Double(pieceIndex) * 1.17

        let secondaryPhase =
            time * 0.25 +
            Double(rowIndex) * 1.09 +
            Double(pieceIndex) * 0.61

        let shimmer =
            reduceMotion
                ? 0
                : sin(mainPhase)

        let secondaryShimmer =
            reduceMotion
                ? 0
                : sin(secondaryPhase)

        let animatedOpacity =
            piece.opacity *
            (0.95 + shimmer * 0.038)

        let horizontalScale =
            1.0 +
            CGFloat(shimmer) * 0.032 +
            CGFloat(secondaryShimmer) * 0.014

        return PaperReflectionShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        color.opacity(animatedOpacity * 0.68),
                        color.opacity(animatedOpacity * 0.96),
                        color.opacity(animatedOpacity),
                        Color.white.opacity(animatedOpacity * 0.025),
                        color.opacity(animatedOpacity),
                        color.opacity(animatedOpacity * 0.80),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: size.width * piece.width,
                height: size.height * piece.height
            )
            .scaleEffect(
                x: horizontalScale,
                y: 1,
                anchor: .center
            )
            .offset(x: piece.offset)
            .shadow(
                color: color.opacity(
                    animatedOpacity * 0.55
                ),
                radius: 2.4
            )
    }

    // MARK: - Vignette

    private var sceneVignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.018),
                Color.black.opacity(0.14)
            ],
            center: .center,
            startRadius: 165,
            endRadius: 610
        )
        .allowsHitTesting(false)
    }

    // MARK: - Animation

    private func beginAnimations() {
        withAnimation(
            .easeOut(
                duration: reduceMotion ? 0.15 : 1.0
            )
        ) {
            isRevealed = true
        }

        guard !reduceMotion else {
            isBreathing = true
            return
        }

        withAnimation(
            .easeInOut(duration: 4.2)
                .repeatForever(autoreverses: true)
                .delay(0.3)
        ) {
            isBreathing = true
        }
    }
}

// MARK: - Reflection Piece Model

private struct ReflectionPiece {

    let width: CGFloat
    let height: CGFloat
    let opacity: Double
    let offset: CGFloat
}

// MARK: - Downward Light Shape

private struct DownwardLightShape: Shape {

    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.width * 0.43,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.57,
                y: rect.minY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.88,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: rect.width * 0.63,
                y: rect.height * 0.35
            ),
            control2: CGPoint(
                x: rect.width * 0.78,
                y: rect.height * 0.76
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.width * 0.12,
                y: rect.maxY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.43,
                y: rect.minY
            ),
            control1: CGPoint(
                x: rect.width * 0.22,
                y: rect.height * 0.76
            ),
            control2: CGPoint(
                x: rect.width * 0.37,
                y: rect.height * 0.35
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Paper Reflection Shape

private struct PaperReflectionShape: Shape {

    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.midY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.30,
                y: rect.minY
            ),
            control1: CGPoint(
                x: rect.width * 0.08,
                y: rect.height * 0.72
            ),
            control2: CGPoint(
                x: rect.width * 0.18,
                y: rect.minY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.68,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: rect.width * 0.43,
                y: rect.height * 0.04
            ),
            control2: CGPoint(
                x: rect.width * 0.56,
                y: rect.maxY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.midY
            ),
            control1: CGPoint(
                x: rect.width * 0.81,
                y: rect.height * 0.90
            ),
            control2: CGPoint(
                x: rect.width * 0.93,
                y: rect.height * 0.30
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.63,
                y: rect.height * 0.34
            ),
            control1: CGPoint(
                x: rect.width * 0.90,
                y: rect.height * 0.66
            ),
            control2: CGPoint(
                x: rect.width * 0.76,
                y: rect.height * 0.28
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.width * 0.29,
                y: rect.height * 0.67
            ),
            control1: CGPoint(
                x: rect.width * 0.52,
                y: rect.height * 0.35
            ),
            control2: CGPoint(
                x: rect.width * 0.40,
                y: rect.height * 0.73
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.minX,
                y: rect.midY
            ),
            control1: CGPoint(
                x: rect.width * 0.18,
                y: rect.height * 0.65
            ),
            control2: CGPoint(
                x: rect.width * 0.06,
                y: rect.height * 0.38
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        BeaconView(
            color: Color(
                red: 0.96,
                green: 0.38,
                blue: 0.52
            ),
            fillsAvailableSpace: true
        )
    }
    .preferredColorScheme(.dark)
}
