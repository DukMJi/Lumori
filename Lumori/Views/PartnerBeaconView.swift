import SwiftUI

// MARK: - Partner Beacon View

/// Displays the paired partner's newest beacon.
///
/// When no beacon exists, Lumori shows the dark, inactive lighthouse.
/// When a beacon is active, the lighthouse illuminates with the
/// partner's emotion color.
struct PartnerBeaconView: View {

    // MARK: - Properties

    let partnerBeacon: BeaconEntry?

    /// Controls whether Lumori shows its built-in message when
    /// no partner beacon exists for today.
    var showsEmptyStateMessage: Bool = true

    // MARK: - State

    @State private var isShowingDetails = false
    @State private var isShowingSettings = false
    @StateObject private var beaconSeenService = BeaconSeenService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                beaconScene

                if isShowingDetails,
                   let partnerBeacon {

                    detailsOverlay(
                        for: partnerBeacon
                    )
                    .transition(.opacity)
                }

                if partnerBeacon == nil,
                   showsEmptyStateMessage {

                    emptyStateMessage
                }
            }
            .animation(
                .easeInOut(duration: 0.35),
                value: isShowingDetails
            )
            .animation(
                .easeInOut(duration: 0.65),
                value: partnerBeacon?.id
            )
            .onChange(of: partnerBeacon?.id) {
                isShowingDetails = false
            }
            .toolbar {
                settingsToolbarItem
            }
            .sheet(
                isPresented: $isShowingSettings
            ) {
                SettingsView()
            }
        }
    }

    // MARK: - Beacon Scene

    private var beaconScene: some View {
        Group {
            if let partnerBeacon {
                Button {
                    toggleDetails()
                } label: {
                    BeaconView(
                        color: Color(
                            hex: partnerBeacon.colorHex
                        ),
                        isActive: true,
                        fillsAvailableSpace: true,
                        isEnvironmentDimmed:
                            isShowingDetails
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isShowingDetails
                        ? "Hide partner beacon information"
                        : "Reveal partner beacon information"
                )

            } else {
                BeaconView(
                    color: .clear,
                    isActive: false,
                    fillsAvailableSpace: true,
                    isEnvironmentDimmed: false
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Details Overlay

    private func detailsOverlay(
        for entry: BeaconEntry
    ) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.48),
                        Color.black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 330)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                Spacer()

                BeaconDetailsView(
                    entry: entry
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 112)
                .transition(
                    .opacity.combined(
                        with: .move(edge: .bottom)
                    )
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleDetails()
        }
    }

    // MARK: - Empty State

    private var emptyStateMessage: some View {
        VStack {
            Spacer()

            VStack(spacing: 7) {
                Text(
                    "No beacon shared today"
                )
                .font(.headline)
                .foregroundStyle(
                    .white.opacity(0.74)
                )

                Text(
                    "Their previous beacon is still available in Sea."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.46)
                )
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 110)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Interaction

    private func toggleDetails() {

        let isOpeningDetails =
            !isShowingDetails

        withAnimation(
            .easeInOut(duration: 0.35)
        ) {
            isShowingDetails.toggle()
        }

        /*
         Only an intentional reveal counts as seeing the beacon.
         Closing the details does nothing.
         */
        if isOpeningDetails,
           let partnerBeacon {

            Task {
                await beaconSeenService
                    .markPartnerBeaconSeen(
                        entry:
                            partnerBeacon
                    )
            }
        }
    }

    // MARK: - Toolbar

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(
            placement: .topBarTrailing
        ) {
            Button {
                isShowingSettings = true
            } label: {
                Image(
                    systemName: "gearshape"
                )
                .foregroundStyle(
                    .white.opacity(0.84)
                )
            }
            .accessibilityLabel(
                "Settings"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    PartnerBeaconView(
        partnerBeacon:
            PartnerBeaconStore
                .sampleEntries
                .first
    )
    .environmentObject(
        BeaconStore()
    )
    .environmentObject(
        PartnerBeaconStore()
    )
    .environmentObject(
        ConnectionStore()
    )
}
