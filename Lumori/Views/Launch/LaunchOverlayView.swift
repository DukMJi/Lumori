import SwiftUI

// MARK: - Launch Overlay View

/// Presents Lumori's intentionally brief opening transition.
///
/// Lumori appears immediately on black, then the entire overlay
/// quietly dissolves to reveal the already-loaded application.
struct LaunchOverlayView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - State

    @State private var overlayOpacity = 1.0
    @State private var logoScale = 0.985
    @State private var hasStartedAnimation = false

    // MARK: - Completion

    private let onAnimationCompleted: () -> Void

    // MARK: - Initialization

    init(
        onAnimationCompleted: @escaping () -> Void
    ) {
        self.onAnimationCompleted = onAnimationCompleted
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Lumori")
                    .font(
                        .system(
                            size: 38,
                            weight: .light,
                            design: .serif
                        )
                    )
                    .tracking(5)
                    .foregroundStyle(
                        .white.opacity(0.92)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.46),
                                Color(
                                    red: 0.50,
                                    green: 0.54,
                                    blue: 0.88
                                )
                                .opacity(0.24),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 18
                        )
                    )
                    .frame(
                        width: 28,
                        height: 28
                    )
                    .blur(radius: 1.5)
            }
            .scaleEffect(logoScale)
            .accessibilityElement(
                children: .combine
            )
            .accessibilityLabel("Lumori")
            .accessibilityAddTraits(.isHeader)
        }
        .opacity(overlayOpacity)
        .allowsHitTesting(true)
        .task {
            await beginLaunchAnimation()
        }
    }

    // MARK: - Animation

    @MainActor
    private func beginLaunchAnimation() async {
        guard !hasStartedAnimation else {
            return
        }

        hasStartedAnimation = true

        if reduceMotion {
            await performReducedMotionTransition()
        } else {
            await performStandardTransition()
        }

        guard !Task.isCancelled else {
            return
        }

        onAnimationCompleted()
    }

    /// Standard sequence:
    ///
    /// 1. Lumori is visible immediately.
    /// 2. Hold very briefly.
    /// 3. Slightly settle the logo.
    /// 4. Fade the entire black overlay away.
    @MainActor
    private func performStandardTransition() async {
        // Tiny amount of movement so the logo does not feel static.
        withAnimation(
            .easeOut(duration: 0.35)
        ) {
            logoScale = 1.0
        }

        try? await Task.sleep(
            for: .milliseconds(300)
        )

        guard !Task.isCancelled else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.65)
        ) {
            overlayOpacity = 0.0
        }

        try? await Task.sleep(
            for: .milliseconds(670)
        )
    }

    // MARK: - Reduced Motion

    @MainActor
    private func performReducedMotionTransition() async {
        logoScale = 1.0

        try? await Task.sleep(
            for: .milliseconds(250)
        )

        overlayOpacity = 0.0

        try? await Task.sleep(
            for: .milliseconds(50)
        )
    }
}

// MARK: - Preview

#Preview {
    LaunchOverlayView {
        // No action required in preview.
    }
}
