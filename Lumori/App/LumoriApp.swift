import SwiftUI
import FirebaseCore

// Reduce the effort required to emotionally understand
// someone you care about.

@main
struct LumoriApp: App {
    
    init() {
        FirebaseApp.configure()
    }

    // MARK: - App State

    // Stores beacons created by the current user.
    @StateObject private var beaconStore = BeaconStore()

    // Stores beacons received from the paired partner.
    @StateObject private var partnerBeaconStore =
        PartnerBeaconStore()
    
    @StateObject private var connectionStore = ConnectionStore()
    
    @StateObject
    private var firebaseAuthService = FirebaseAuthService()
    
    @StateObject private var userService = UserService()
    
    @StateObject private var pairingService = PairingService()
    
    @StateObject private var audioManager = AudioManager()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(beaconStore)
                .environmentObject(partnerBeaconStore)
                .environmentObject(connectionStore)
                .environmentObject(firebaseAuthService)
                .environmentObject(userService)
                .environmentObject(pairingService)
                .environmentObject(audioManager)
        }
    }
}
