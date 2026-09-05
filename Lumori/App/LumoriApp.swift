import SwiftUI
import FirebaseCore

// Reduce the effort required to emotionally understand
// someone you care about.

@main
struct LumoriApp: App {

    // MARK: - App Delegate

    @UIApplicationDelegateAdaptor(
        AppDelegate.self
    )
    private var appDelegate

    // MARK: - Initialization

    init() {
        FirebaseApp.configure()
    }

    // MARK: - App State

    @StateObject
    private var beaconStore =
        BeaconStore()

    @StateObject
    private var partnerBeaconStore =
        PartnerBeaconStore()

    @StateObject
    private var connectionStore =
        ConnectionStore()

    @StateObject
    private var firebaseAuthService =
        FirebaseAuthService()

    @StateObject
    private var userService =
        UserService()

    @StateObject
    private var pairingService =
        PairingService()

    @StateObject
    private var audioManager =
        AudioManager()

    @StateObject
    private var notificationManager =
        NotificationManager.shared

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(
                    beaconStore
                )
                .environmentObject(
                    partnerBeaconStore
                )
                .environmentObject(
                    connectionStore
                )
                .environmentObject(
                    firebaseAuthService
                )
                .environmentObject(
                    userService
                )
                .environmentObject(
                    pairingService
                )
                .environmentObject(
                    audioManager
                )
                .environmentObject(
                    notificationManager
                )
        }
    }
}
