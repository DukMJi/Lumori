import SwiftUI

// MARK: - App Navigation

/// Provides Lumori's three primary destinations.
///
/// Beacon shows the partner's current emotional update.
/// Sea contains previous partner beacons.
/// Share lets the current user create or update today's beacon.
struct ConnectedContentView: View {

    // MARK: - Environment

    @EnvironmentObject
    private var partnerBeaconStore: PartnerBeaconStore

    // MARK: - Body

    var body: some View {
        TabView {

            // MARK: Beacon

            PartnerBeaconView(
                partnerBeacon:
                    partnerBeaconStore.currentBeacon
            )
            .tabItem {
                Label(
                    "Beacon",
                    systemImage: "light.beacon.max"
                )
            }

            // MARK: Sea

            LanternHistoryView(
                entries:
                    partnerBeaconStore.historicalEntries
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
    }
}

// MARK: - Preview

#Preview {
    ConnectedContentView()
        .environmentObject(
            BeaconStore()
        )
        .environmentObject(
            PartnerBeaconStore()
        )
}
