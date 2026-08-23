import SwiftUI

// MARK: - Unpaired Content View

/// Lumori's normal experience before the user connects with a partner.
///
/// Anonymous users can explore Lumori and create their own beacon
/// without first creating an account. Account security and pairing
/// are only requested when the user chooses to connect with someone.
struct UnpairedContentView: View {

    // MARK: - State

    @State
    private var isShowingPairing = false

    // MARK: - Body

    var body: some View {
        TabView {

            // MARK: Beacon

            unpairedBeacon
                .tabItem {
                    Label(
                        "Beacon",
                        systemImage: "light.beacon.max"
                    )
                }

            // MARK: Sea

            LanternHistoryView(
                entries: []
            )
            .tabItem {
                Label(
                    "Sea",
                    systemImage: "water.waves"
                )
            }

            // MARK: Share

            MyBeaconView()
                .tabItem {
                    Label(
                        "Share",
                        systemImage: "square.and.pencil"
                    )
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .sheet(
            isPresented: $isShowingPairing
        ) {
            PairingView()
        }
    }

    // MARK: - Unpaired Beacon

    private var unpairedBeacon: some View {
        ZStack {
            PartnerBeaconView(
                partnerBeacon: nil,
                showsEmptyStateMessage: false
            )

            VStack {
                Spacer()

                connectCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 42)
            }
        }
    }

    // MARK: - Connect Card

    private var connectCard: some View {
        VStack(spacing: 10) {

            Text(
                "Your lighthouse is quiet"
            )
            .font(.headline)
            .foregroundStyle(.white)

            Text(
                "Connect when you're ready to share your beacons."
            )
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(0.55)
            )
            .multilineTextAlignment(.center)

            Button {
                isShowingPairing = true
            } label: {
                Label(
                    "Connect with someone",
                    systemImage: "link"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(
                .borderedProminent
            )
            .tint(
                Color(hex: "#6874D8")
            )
            .padding(.top, 2)
        }
        .padding(16)
        .background {
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                Color.black.opacity(0.52)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18
                )
                .stroke(
                    Color.white.opacity(0.07),
                    lineWidth: 1
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UnpairedContentView()
        .environmentObject(
            BeaconStore()
        )
        .environmentObject(
            PartnerBeaconStore()
        )
        .environmentObject(
            ConnectionStore()
        )
        .environmentObject(
            PairingService()
        )
        .environmentObject(
            UserService()
        )
        .environmentObject(
            FirebaseAuthService()
        )
}
