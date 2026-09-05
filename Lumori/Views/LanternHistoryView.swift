import SwiftUI

// MARK: - Lantern History View

/// Displays both users' previous beacons as a continuously moving sea of lights.
///
/// A limited number of lights are visible at once. They slowly drift downward
/// from the horizon, move subtly side-to-side, and recycle back to the top.
///
/// Newer entries appear larger and brighter.
/// Older entries gradually become smaller and dimmer.
///
/// The full history remains available over time even though only a limited
/// number of lights are visible simultaneously.
struct LanternHistoryView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - Properties

    let myEntries: [BeaconEntry]
    let partnerEntries: [BeaconEntry]

    // MARK: - State

    @State
    private var selectedLight: HistoricalLight?

    // MARK: - Configuration

    /// Maximum number of historical lights visible simultaneously.
    private let maximumVisibleLights = 16

    // MARK: - Body

    var body: some View {
        ZStack {
            animatedScene
                .ignoresSafeArea()

            if historicalLights.isEmpty {
                emptyState
            }

            if let selectedLight {
                selectedDetails(
                    for: selectedLight
                )
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .animation(
            .easeInOut(duration: 0.35),
            value: selectedLight?.id
        )
    }

    // MARK: - Combined History

    private var historicalLights: [HistoricalLight] {
        let mine =
            myEntries.map {
                HistoricalLight(
                    entry: $0,
                    owner: .me
                )
            }

        let partner =
            partnerEntries.map {
                HistoricalLight(
                    entry: $0,
                    owner: .partner
                )
            }

        return (mine + partner)
            .sorted {
                $0.entry.date >
                $1.entry.date
            }
    }

    // MARK: - Animated Scene

    @ViewBuilder
    private var animatedScene: some View {
        if reduceMotion {

            scene(time: 0)

        } else {

            TimelineView(
                .animation(
                    minimumInterval:
                        1.0 / 30.0
                )
            ) { timeline in

                scene(
                    time:
                        timeline.date
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

                stars(
                    in: size,
                    time: time
                )
                
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
        }
        .ignoresSafeArea()
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

    /// Draws Lumori's night sky.
    ///
    /// Most stars remain nearly still while a handful change brightness
    /// very gradually. Each star uses a different phase and speed so the
    /// sky never appears to pulse in unison.
    private func stars(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        ZStack {

            star(
                x: 0.08,
                y: 0.08,
                scale: 0.65,
                phase: 0.2,
                speed: 0.23,
                twinkleAmount: 0.27,
                size: size,
                time: time
            )

            star(
                x: 0.20,
                y: 0.14,
                scale: 0.45,
                phase: 1.7,
                speed: 0.17,
                twinkleAmount: 0.05,
                size: size,
                time: time
            )

            star(
                x: 0.32,
                y: 0.07,
                scale: 0.70,
                phase: 3.1,
                speed: 0.28,
                twinkleAmount: 0.34,
                size: size,
                time: time
            )

            star(
                x: 0.44,
                y: 0.18,
                scale: 0.40,
                phase: 4.8,
                speed: 0.14,
                twinkleAmount: 0.04,
                size: size,
                time: time
            )

            star(
                x: 0.58,
                y: 0.10,
                scale: 0.72,
                phase: 2.4,
                speed: 0.21,
                twinkleAmount: 0.12,
                size: size,
                time: time
            )

            star(
                x: 0.70,
                y: 0.16,
                scale: 0.50,
                phase: 5.9,
                speed: 0.18,
                twinkleAmount: 0.05,
                size: size,
                time: time
            )

            star(
                x: 0.83,
                y: 0.09,
                scale: 0.60,
                phase: 0.9,
                speed: 0.31,
                twinkleAmount: 0.30,
                size: size,
                time: time
            )

            star(
                x: 0.91,
                y: 0.21,
                scale: 0.78,
                phase: 6.7,
                speed: 0.19,
                twinkleAmount: 0.09,
                size: size,
                time: time
            )

            star(
                x: 0.13,
                y: 0.27,
                scale: 0.48,
                phase: 2.9,
                speed: 0.15,
                twinkleAmount: 0.04,
                size: size,
                time: time
            )

            star(
                x: 0.73,
                y: 0.27,
                scale: 0.52,
                phase: 4.1,
                speed: 0.26,
                twinkleAmount: 0.19,
                size: size,
                time: time
            )
        }
    }

    private func star(
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        phase: Double,
        speed: Double,
        twinkleAmount: Double,
        size: CGSize,
        time: TimeInterval
    ) -> some View {

        let baseOpacity = 0.75

        let twinkle: Double = {
            guard !reduceMotion else {
                return baseOpacity
            }

            return baseOpacity +
                sin(
                    time * speed +
                    phase
                ) *
                twinkleAmount
        }()

        return Circle()
            .fill(
                Color(
                    red: 1.0,
                    green: 0.92,
                    blue: 0.79
                )
                .opacity(
                    max(
                        0.32,
                        min(
                            twinkle,
                            1.0
                        )
                    )
                )
            )
            .frame(
                width:
                    size.width *
                    0.007 *
                    scale,
                height:
                    size.width *
                    0.007 *
                    scale
            )
            .shadow(
                color:
                    Color.white.opacity(
                        max(
                            0,
                            twinkle - 0.58
                        )
                    ),
                radius: 2
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
                    x:
                        size.width *
                        0.023,
                    y:
                        -size.width *
                        0.010
                )
        }
        .frame(
            width:
                size.width * 0.082,
            height:
                size.width * 0.082
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
                    width:
                        size.width * 0.37,
                    height:
                        size.height * 0.085
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
                    width:
                        size.width * 0.33,
                    height:
                        size.height * 0.075
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
                    width:
                        size.width * 1.20,
                    height:
                        size.height * 0.15
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
                    width:
                        size.width * 1.20,
                    height:
                        size.height * 0.11
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
                amplitude:
                    size.height *
                    0.008
            )
            .fill(
                Color(
                    red: 0.055,
                    green: 0.105,
                    blue: 0.210
                )
            )
            .frame(
                width:
                    size.width * 1.22,
                height:
                    size.height * 0.50
            )
            .position(
                x: size.width * 0.50,
                y: size.height * 0.76
            )

            HistoryOceanShape(
                phase: 1.4,
                amplitude:
                    size.height *
                    0.010
            )
            .fill(
                Color(
                    red: 0.036,
                    green: 0.078,
                    blue: 0.170
                )
            )
            .frame(
                width:
                    size.width * 1.22,
                height:
                    size.height * 0.42
            )
            .position(
                x: size.width * 0.50,
                y: size.height * 0.82
            )

            HistoryOceanShape(
                phase: 2.7,
                amplitude:
                    size.height *
                    0.012
            )
            .fill(
                Color(
                    red: 0.020,
                    green: 0.055,
                    blue: 0.135
                )
            )
            .frame(
                width:
                    size.width * 1.22,
                height:
                    size.height * 0.34
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

        let visibleCount =
            min(
                maximumVisibleLights,
                historicalLights.count
            )

        return ZStack {
            ForEach(
                0..<visibleCount,
                id: \.self
            ) { slot in

                driftingLight(
                    slot: slot,
                    size: size,
                    time: time
                )
            }
        }
    }

    // MARK: - Drifting Light

    @ViewBuilder
    private func driftingLight(
        slot: Int,
        size: CGSize,
        time: TimeInterval
    ) -> some View {

        if !historicalLights.isEmpty {

            let motion =
                motionProfile(
                    for: slot
                )

            let cycle =
                reduceMotion
                    ? 0
                    : Int(
                        floor(
                            time /
                            motion.duration
                        )
                    )

            let entryIndex =
                (
                    slot +
                    cycle *
                    maximumVisibleLights
                )
                %
                historicalLights.count

            let light =
                historicalLights[
                    entryIndex
                ]

            historicalLight(
                light: light,
                slot: slot,
                size: size,
                time: time,
                motion: motion
            )
        }
    }

    private func historicalLight(
        light: HistoricalLight,
        slot: Int,
        size: CGSize,
        time: TimeInterval,
        motion: LightMotionProfile
    ) -> some View {

        let emotionColor =
            Color(
                hex:
                    light.entry.colorHex
            )

        let age =
            ageStyle(
                for:
                    light.entry
            )

        let progress: Double = {
            guard !reduceMotion else {
                return motion.initialProgress
            }

            let raw =
                (
                    time /
                    motion.duration
                ) +
                motion.initialProgress

            return raw -
                floor(raw)
        }()

        /*
         Lights enter near the horizon and slowly travel toward
         the bottom foreground.
         */
        let startY: CGFloat = 0.56
        let endY: CGFloat = 1.02

        let baseY =
            startY +
            (
                endY - startY
            ) *
            CGFloat(progress)

        let horizontalWander =
            reduceMotion
                ? 0
                : sin(
                    time *
                    motion.wanderSpeed +
                    motion.phase
                ) *
                motion.wanderAmount

        let bob =
            reduceMotion
                ? 0
                : sin(
                    time *
                    motion.bobSpeed +
                    motion.phase
                ) *
                motion.bobAmount

        let pulse =
            reduceMotion
                ? 1
                : 0.94 +
                    sin(
                        time * 0.62 +
                        motion.phase
                    ) *
                    0.06

        /*
         Fade gently at the beginning and end of each travel cycle
         so recycling never looks like a hard teleport.
         */
        let edgeOpacity =
            cycleOpacity(
                progress
            )

        let ownerScale =
            light.owner == .me
                ? 0.96
                : 1.0

        let finalScale =
            motion.scale *
            age.scale *
            ownerScale

        return Button {
            withAnimation(
                .easeInOut(
                    duration: 0.35
                )
            ) {
                selectedLight =
                    light
            }
        } label: {

            ZStack {

                lightGlow(
                    color: emotionColor,
                    intensity:
                        pulse *
                        age.brightness
                )
                .frame(
                    width:
                        size.width *
                        finalScale *
                        1.65,
                    height:
                        size.width *
                        finalScale *
                        1.20
                )

                lightCore(
                    color: emotionColor,
                    intensity:
                        pulse *
                        age.brightness,
                    owner: light.owner
                )
                .frame(
                    width:
                        size.width *
                        finalScale *
                        0.22,
                    height:
                        size.width *
                        finalScale *
                        0.22
                )
            }
            .opacity(
                edgeOpacity *
                age.opacity
            )
        }
        .buttonStyle(.plain)
        .position(
            x:
                size.width *
                (
                    motion.baseX +
                    horizontalWander
                ),
            y:
                size.height *
                baseY +
                bob
        )
        .zIndex(
            Double(
                100 -
                slot
            )
        )
        .accessibilityLabel(
            accessibilityLabel(
                for: light
            )
        )
    }

    // MARK: - Age Styling

    private func ageStyle(
        for entry: BeaconEntry
    ) -> AgeStyle {

        let calendar =
            Calendar.current

        let days =
            max(
                0,
                calendar.dateComponents(
                    [.day],
                    from:
                        calendar.startOfDay(
                            for: entry.date
                        ),
                    to:
                        calendar.startOfDay(
                            for: Date()
                        )
                ).day ?? 0
            )

        /*
         Age affects the light gradually rather than through
         obvious discrete categories.
         */

        let normalizedAge =
            min(
                Double(days) / 90.0,
                1.0
            )

        let scale =
            1.0 -
            normalizedAge * 0.32

        let brightness =
            1.0 -
            normalizedAge * 0.28

        let opacity =
            1.0 -
            normalizedAge * 0.22

        return AgeStyle(
            scale: scale,
            brightness: brightness,
            opacity: opacity
        )
    }

    // MARK: - Cycle Fade

    private func cycleOpacity(
        _ progress: Double
    ) -> Double {

        let fadeRange = 0.08

        if progress < fadeRange {
            return progress /
                fadeRange
        }

        if progress >
            1.0 - fadeRange {

            return
                (
                    1.0 -
                    progress
                )
                /
                fadeRange
        }

        return 1.0
    }

    // MARK: - Motion Profiles

    private func motionProfile(
        for slot: Int
    ) -> LightMotionProfile {

        let xPositions: [CGFloat] = [
            0.12,
            0.31,
            0.50,
            0.72,
            0.88,
            0.22,
            0.62,
            0.40,
            0.80,
            0.16,
            0.56,
            0.92,
            0.35,
            0.68,
            0.08,
            0.47
        ]

        let initialProgresses: [Double] = [
            0.04,
            0.36,
            0.67,
            0.19,
            0.82,
            0.52,
            0.11,
            0.74,
            0.29,
            0.92,
            0.45,
            0.61,
            0.15,
            0.79,
            0.56,
            0.33
        ]

        let index =
            slot %
            xPositions.count

        return LightMotionProfile(
            baseX:
                xPositions[index],
            initialProgress:
                initialProgresses[index],
            duration:
                64.0 +
                Double(
                    index % 5
                ) *
                5.5,
            phase:
                Double(index) *
                0.83,
            wanderSpeed:
                0.075 +
                Double(
                    index % 4
                ) *
                0.012,
            wanderAmount:
                0.012 +
                CGFloat(
                    index % 3
                ) *
                0.006,
            bobSpeed:
                0.36 +
                Double(
                    index % 4
                ) *
                0.035,
            bobAmount:
                1.4 +
                CGFloat(
                    index % 3
                ) *
                0.55,
            scale:
                0.085 +
                CGFloat(
                    index % 5
                ) *
                0.008
        )
    }

    // MARK: - Light Core

    private func lightCore(
        color: Color,
        intensity: Double,
        owner: HistoricalOwner
    ) -> some View {

        ZStack {

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(
                                0.70
                            ),
                            color.opacity(
                                1.0 *
                                intensity
                            ),
                            color.opacity(
                                0.65 *
                                intensity
                            ),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 18
                    )
                )
                .shadow(
                    color:
                        color.opacity(
                            0.80 *
                            intensity
                        ),
                    radius: 6
                )
                .blendMode(.screen)

            /*
             Your own historical lights receive a very subtle
             inner ring. Partner lights remain solid.

             This distinguishes ownership without introducing
             labels all over the Sea.
             */
            if owner == .me {
                Circle()
                    .stroke(
                        Color.white.opacity(
                            0.34
                        ),
                        lineWidth: 0.8
                    )
                    .padding(1.5)
            }
        }
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
                        color.opacity(
                            0.40 *
                            intensity
                        ),
                        color.opacity(
                            0.18 *
                            intensity
                        ),
                        color.opacity(
                            0.055 *
                            intensity
                        ),
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

    // MARK: - Foreground Water

    private func foregroundWater(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {

        let phase =
            reduceMotion
                ? 0
                : CGFloat(
                    time * 0.13
                )

        return HistoryOceanShape(
            phase: phase,
            amplitude:
                size.height *
                0.014
        )
        .fill(
            Color(
                red: 0.012,
                green: 0.036,
                blue: 0.095
            )
        )
        .frame(
            width:
                size.width * 1.22,
            height:
                size.height * 0.18
        )
        .position(
            x: size.width * 0.50,
            y: size.height * 0.97
        )
        .shadow(
            color: .black.opacity(
                0.44
            ),
            radius: 3,
            x: 0,
            y: -3
        )
        .allowsHitTesting(false)
    }

    // MARK: - Selected Details

    private func selectedDetails(
        for light: HistoricalLight
    ) -> some View {

        let entry =
            light.entry

        return ZStack {

            Color.black
                .opacity(0.50)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(
                        hex:
                            entry.colorHex
                    )
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
                        Color.black.opacity(
                            0.20
                        ),
                        Color.black.opacity(
                            0.60
                        ),
                        Color.black.opacity(
                            0.84
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 390)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {

                Spacer()

                Text(
                    light.owner ==
                        .me
                        ? "Your beacon"
                        : "Partner beacon"
                )
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(
                    .white.opacity(
                        0.52
                    )
                )
                .padding(
                    .bottom,
                    10
                )

                BeaconDetailsView(
                    entry: entry
                )
                .padding(
                    .horizontal,
                    28
                )
                .padding(
                    .bottom,
                    108
                )
            }
        }
        .contentShape(
            Rectangle()
        )
        .onTapGesture {
            withAnimation(
                .easeInOut(
                    duration: 0.35
                )
            ) {
                selectedLight = nil
            }
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(
        for light: HistoricalLight
    ) -> String {

        let owner =
            light.owner == .me
                ? "Your"
                : "Partner"

        let date =
            light.entry.date.formatted(
                date: .abbreviated,
                time: .omitted
            )

        return
            "\(owner) beacon from \(date)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {

            Spacer()

            Image(
                systemName:
                    "water.waves"
            )
            .font(
                .system(size: 28)
            )
            .foregroundStyle(
                .white.opacity(
                    0.40
                )
            )

            Text("No lights yet")
                .font(.headline)
                .foregroundStyle(
                    .white.opacity(
                        0.75
                    )
                )

            Text(
                "Your shared history will quietly gather here over time."
            )
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(
                    0.45
                )
            )
            .multilineTextAlignment(
                .center
            )
            .padding(
                .horizontal,
                48
            )

            Spacer()
                .frame(
                    height: 130
                )
        }
    }

    // MARK: - Vignette

    private var vignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.black.opacity(
                    0.04
                ),
                Color.black.opacity(
                    0.27
                )
            ],
            center: .center,
            startRadius: 160,
            endRadius: 620
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Historical Light

private struct HistoricalLight:
    Identifiable {

    let entry: BeaconEntry
    let owner: HistoricalOwner

    var id: String {
        "\(owner.rawValue)-\(entry.id.uuidString)"
    }
}

// MARK: - Historical Owner

private enum HistoricalOwner:
    String {

    case me
    case partner
}

// MARK: - Age Style

private struct AgeStyle {

    let scale: Double
    let brightness: Double
    let opacity: Double
}

// MARK: - Motion Profile

private struct LightMotionProfile {

    let baseX: CGFloat
    let initialProgress: Double

    let duration: Double

    let phase: Double

    let wanderSpeed: Double
    let wanderAmount: CGFloat

    let bobSpeed: Double
    let bobAmount: CGFloat

    let scale: CGFloat
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
                x:
                    rect.width *
                    0.28,
                y:
                    rect.height *
                    0.46
            ),
            control1: CGPoint(
                x:
                    rect.width *
                    0.06,
                y:
                    rect.height *
                    0.78
            ),
            control2: CGPoint(
                x:
                    rect.width *
                    0.12,
                y:
                    rect.height *
                    0.44
            )
        )

        path.addCurve(
            to: CGPoint(
                x:
                    rect.width *
                    0.54,
                y:
                    rect.height *
                    0.25
            ),
            control1: CGPoint(
                x:
                    rect.width *
                    0.34,
                y:
                    rect.height *
                    0.14
            ),
            control2: CGPoint(
                x:
                    rect.width *
                    0.46,
                y:
                    rect.height *
                    0.15
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.maxY
            ),
            control1: CGPoint(
                x:
                    rect.width *
                    0.71,
                y:
                    rect.height *
                    0.08
            ),
            control2: CGPoint(
                x:
                    rect.width *
                    0.89,
                y:
                    rect.height *
                    0.47
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
                x:
                    rect.width *
                    0.16,
                y:
                    rect.height *
                    0.58
            )
        )

        path.addLine(
            to: CGPoint(
                x:
                    rect.width *
                    0.32,
                y:
                    rect.height *
                    0.33
            )
        )

        path.addLine(
            to: CGPoint(
                x:
                    rect.width *
                    0.49,
                y:
                    rect.height *
                    0.54
            )
        )

        path.addLine(
            to: CGPoint(
                x:
                    rect.width *
                    0.67,
                y:
                    rect.height *
                    0.25
            )
        )

        path.addLine(
            to: CGPoint(
                x:
                    rect.width *
                    0.83,
                y:
                    rect.height *
                    0.47
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y:
                    rect.height *
                    0.30
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
                y:
                    rect.minY +
                    amplitude
            )
        )

        let step: CGFloat = 4

        for x in stride(
            from: rect.minX,
            through: rect.maxX,
            by: step
        ) {

            let progress =
                (
                    x -
                    rect.minX
                )
                /
                rect.width

            let y =
                rect.minY +
                amplitude +
                sin(
                    progress *
                    .pi *
                    2.2 +
                    phase
                )
                *
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
        myEntries:
            Array(
                PartnerBeaconStore
                    .sampleEntries
                    .prefix(4)
            ),
        partnerEntries:
            Array(
                PartnerBeaconStore
                    .sampleEntries
                    .dropFirst(4)
                    .prefix(4)
            )
    )
}
