import SwiftUI

// MARK: - My Beacon View

/// Allows the current user to create or update today's beacon.
///
/// The screen intentionally remains quiet and lightweight:
/// the emotion itself is the primary action, while context and
/// contributing factors stay secondary and optional.
struct MyBeaconView: View {

    // MARK: - Environment

    @EnvironmentObject
    private var beaconStore: BeaconStore

    // MARK: - Services

    private let colorService = BeaconColorService()

    // MARK: - Input State

    @State private var feeling = ""
    @State private var reason = ""

    @State private var contributionOne = ""
    @State private var contributionTwo = ""
    @State private var contributionThree = ""

    @State private var isShowingConfirmation = false

    // MARK: - Computed Properties

    private var cleanedFeeling: String {
        feeling.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var cleanedReason: String? {
        let cleaned =
            reason.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleaned.isEmpty
            ? nil
            : cleaned
    }

    private var cleanedContributions: [String] {
        [
            contributionOne,
            contributionTwo,
            contributionThree
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter {
            !$0.isEmpty
        }
    }

    private var isEditingBeacon: Bool {
        !cleanedFeeling.isEmpty
    }

    private var previewColorHex: String {
        if isEditingBeacon {
            return colorService.colorHex(
                for: cleanedFeeling
            )
        }

        return beaconStore
            .currentMyBeacon?
            .colorHex
            ?? "#A7B1C2"
    }

    private var previewColor: Color {
        Color(hex: previewColorHex)
    }

    private var previewFeeling: String? {
        if isEditingBeacon {
            return cleanedFeeling
        }

        return beaconStore
            .currentMyBeacon?
            .feeling
    }

    private var canSave: Bool {
        !cleanedFeeling.isEmpty
    }

    private var hasCurrentBeacon: Bool {
        beaconStore.currentMyBeacon != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ShareBackground()

                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 30
                    ) {
                        previewSection

                        feelingSection

                        if !beaconStore
                            .previousFeelings
                            .isEmpty {

                            previousFeelingsSection
                        }

                        reasonSection

                        contributionsSection

                        saveButton

                        Spacer()
                            .frame(height: 18)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                if isShowingConfirmation {
                    confirmationOverlay
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.96)
                            )
                        )
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 16) {
            Text(
                hasCurrentBeacon && !isEditingBeacon
                    ? "Your beacon today"
                    : "Your light"
            )
            .font(.caption)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(
                .white.opacity(0.45)
            )

            ShareBeaconPreview(
                color: previewColor,
                isActive:
                    previewFeeling != nil
            )

            if let previewFeeling {
                Text(previewFeeling)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else {
                Text("Your beacon is quiet")
                    .font(.subheadline)
                    .foregroundStyle(
                        .white.opacity(0.48)
                    )
            }

            if hasCurrentBeacon &&
                !isEditingBeacon {

                Text(
                    "Sharing again today will update your current beacon."
                )
                .font(.caption)
                .foregroundStyle(
                    .white.opacity(0.36)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.035)
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.055),
                lineWidth: 1
            )
        }
        .animation(
            .easeInOut(duration: 0.35),
            value: previewColorHex
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: previewFeeling
        )
    }

    // MARK: - Feeling

    private var feelingSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title:
                    hasCurrentBeacon
                    ? "How do you feel now?"
                    : "How are you feeling?",
                subtitle:
                    hasCurrentBeacon
                    ? "Update today's beacon whenever it changes."
                    : "A few words are enough."
            )

            TextField(
                "Peaceful, overwhelmed, excited…",
                text: $feeling,
                axis: .vertical
            )
            .font(.body)
            .textInputAutocapitalization(
                .sentences
            )
            .lineLimit(1...3)
            .padding(.horizontal, 17)
            .padding(.vertical, 16)
            .background(inputBackground)
        }
    }

    // MARK: - Previous Feelings

    private var previousFeelingsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Recently used")
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(
                    .white.opacity(0.42)
                )

            FlowLayout(spacing: 9) {
                ForEach(
                    beaconStore.previousFeelings,
                    id: \.self
                ) { previousFeeling in
                    Button(previousFeeling) {
                        withAnimation(
                            .easeInOut(
                                duration: 0.22
                            )
                        ) {
                            feeling =
                                previousFeeling
                        }
                    }
                    .buttonStyle(
                        ShareSuggestionButtonStyle(
                            accentColor:
                                previewColor
                        )
                    )
                }
            }
        }
    }

    // MARK: - Reason

    private var reasonSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title: "Want to say more?",
                subtitle:
                    "Optional — give them a little context."
            )

            TextField(
                "What's behind the feeling?",
                text: $reason,
                axis: .vertical
            )
            .textInputAutocapitalization(
                .sentences
            )
            .lineLimit(3...6)
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .background(inputBackground)
        }
    }

    // MARK: - Contributions

    private var contributionsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title: "What's contributing?",
                subtitle:
                    "Up to three optional words."
            )

            HStack(spacing: 9) {
                contributionField(
                    placeholder: "work",
                    text: $contributionOne
                )

                contributionField(
                    placeholder: "sleep",
                    text: $contributionTwo
                )

                contributionField(
                    placeholder: "us",
                    text: $contributionThree
                )
            }
        }
    }

    private func contributionField(
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        TextField(
            placeholder,
            text: text
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(
                .white.opacity(0.055)
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.055),
                lineWidth: 1
            )
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            saveBeacon()
        } label: {
            HStack(spacing: 8) {
                Image(
                    systemName:
                        hasCurrentBeacon
                        ? "arrow.triangle.2.circlepath"
                        : "light.beacon.max.fill"
                )

                Text(
                    hasCurrentBeacon
                    ? "Update Today"
                    : "Share Beacon"
                )
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                canSave
                ? previewColor.opacity(0.72)
                : Color.white.opacity(0.07)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                canSave
                ? previewColor.opacity(0.70)
                : Color.white.opacity(0.05),
                lineWidth: 1
            )
        }
        .shadow(
            color:
                canSave
                ? previewColor.opacity(0.22)
                : .clear,
            radius: 18
        )
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.58)
        .animation(
            .easeInOut(duration: 0.25),
            value: canSave
        )
        .animation(
            .easeInOut(duration: 0.30),
            value: previewColorHex
        )
    }

    // MARK: - Confirmation

    private var confirmationOverlay: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        previewColor.opacity(0.20)
                    )
                    .frame(
                        width: 54,
                        height: 54
                    )

                Image(systemName: "checkmark")
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )
            }

            Text(
                hasCurrentBeacon
                ? "Beacon updated"
                : "Beacon shared"
            )
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                Color(
                    red: 0.035,
                    green: 0.055,
                    blue: 0.095
                )
                .opacity(0.96)
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.08),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.38),
            radius: 24
        )
    }

    // MARK: - Shared Styling

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.46)
                )
        }
    }

    private var inputBackground: some View {
        RoundedRectangle(
            cornerRadius: 17,
            style: .continuous
        )
        .fill(
            .white.opacity(0.055)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.055),
                lineWidth: 1
            )
        }
    }

    // MARK: - Actions

    private func saveBeacon() {
        let savedColorHex =
            colorService.colorHex(
                for: cleanedFeeling
            )

        let wasUpdating =
            beaconStore.currentMyBeacon != nil

        beaconStore.saveBeacon(
            feeling: feeling,
            reason: reason,
            contributions: [
                contributionOne,
                contributionTwo,
                contributionThree
            ],
            colorHex: savedColorHex
        )

        feeling = ""
        reason = ""
        contributionOne = ""
        contributionTwo = ""
        contributionThree = ""

        withAnimation(
            .easeInOut(duration: 0.28)
        ) {
            isShowingConfirmation = true
        }

        Task {
            try? await Task.sleep(
                for: .seconds(1.35)
            )

            await MainActor.run {
                withAnimation(
                    .easeInOut(duration: 0.28)
                ) {
                    isShowingConfirmation =
                        false
                }
            }
        }

        _ = wasUpdating
    }
}

// MARK: - Share Beacon Preview

private struct ShareBeaconPreview: View {

    let color: Color
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    color.opacity(
                        isActive
                        ? (isBreathing
                           ? 0.24
                           : 0.14)
                        : 0.04
                    )
                )
                .frame(
                    width: 230,
                    height: 120
                )
                .blur(radius: 26)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(
                                isActive
                                ? 0.55
                                : 0.10
                            ),
                            color.opacity(
                                isActive
                                ? 0.98
                                : 0.10
                            ),
                            color.opacity(
                                isActive
                                ? 0.32
                                : 0.04
                            ),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 64
                    )
                )
                .frame(
                    width: 130,
                    height: 130
                )
                .scaleEffect(
                    isBreathing
                    ? 1.055
                    : 0.97
                )

            Circle()
                .fill(
                    .white.opacity(
                        isActive
                        ? 0.72
                        : 0.08
                    )
                )
                .frame(
                    width: 11,
                    height: 11
                )
                .shadow(
                    color:
                        isActive
                        ? color.opacity(0.90)
                        : .clear,
                    radius: 10
                )
        }
        .frame(height: 130)
        .onAppear {
            guard !reduceMotion else {
                isBreathing = true
                return
            }

            withAnimation(
                .easeInOut(duration: 3.8)
                    .repeatForever(
                        autoreverses: true
                    )
            ) {
                isBreathing = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Background

private struct ShareBackground: View {

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.010,
                        green: 0.030,
                        blue: 0.070
                    ),
                    Color(
                        red: 0.020,
                        green: 0.055,
                        blue: 0.120
                    ),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.025),
                    Color.clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Suggestion Button Style

private struct ShareSuggestionButtonStyle:
    ButtonStyle {

    let accentColor: Color

    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(0.88)
            )
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(
                        accentColor.opacity(
                            configuration.isPressed
                            ? 0.22
                            : 0.09
                        )
                    )
            }
            .overlay {
                Capsule()
                    .stroke(
                        accentColor.opacity(0.14),
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {

    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maximumWidth =
            proposal.width ?? 0

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX + size.width >
                maximumWidth &&
                currentX > 0 {

                currentX = 0
                currentY +=
                    rowHeight + spacing
                rowHeight = 0
            }

            currentX +=
                size.width + spacing

            rowHeight =
                max(
                    rowHeight,
                    size.height
                )
        }

        return CGSize(
            width: maximumWidth,
            height:
                currentY + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX =
            bounds.minX

        var currentY =
            bounds.minY

        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX + size.width >
                bounds.maxX &&
                currentX > bounds.minX {

                currentX =
                    bounds.minX

                currentY +=
                    rowHeight + spacing

                rowHeight = 0
            }

            subview.place(
                at: CGPoint(
                    x: currentX,
                    y: currentY
                ),
                proposal:
                    ProposedViewSize(size)
            )

            currentX +=
                size.width + spacing

            rowHeight =
                max(
                    rowHeight,
                    size.height
                )
        }
    }
}

// MARK: - Preview

#Preview {
    MyBeaconView()
        .environmentObject(
            BeaconStore()
        )
}
