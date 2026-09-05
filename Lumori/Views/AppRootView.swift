import SwiftUI

// MARK: - App Root View

/// Chooses between Lumori's onboarding, unpaired, and connected experiences.
///
/// Every user begins with an anonymous Firebase identity.
/// Account creation is only required when the user chooses to connect.
///
/// AppRootView also coordinates:
/// - one-time onboarding
/// - Firebase profile restoration
/// - partner connection restoration
/// - live partner beacon synchronization
/// - daily state refresh
/// - Lumori's ambient soundtrack
struct AppRootView: View {

    // MARK: - Environment

    @Environment(\.scenePhase)
    private var scenePhase

    @EnvironmentObject
    private var beaconStore: BeaconStore

    @EnvironmentObject
    private var connectionStore: ConnectionStore

    @EnvironmentObject
    private var partnerBeaconStore: PartnerBeaconStore

    @EnvironmentObject
    private var firebaseAuthService: FirebaseAuthService

    @EnvironmentObject
    private var userService: UserService

    @EnvironmentObject
    private var audioManager: AudioManager

    // MARK: - Onboarding

    /// Stored locally on the device.
    ///
    /// Once the user reaches the final onboarding page and taps
    /// "Enter Lumori", the introduction will no longer appear automatically.
    @AppStorage("lumori.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    // MARK: - State

    @State
    private var hasAttemptedConnectionRestore = false

    // MARK: - Body

    var body: some View {
        LaunchContainerView {
            rootContent
        }

        // MARK: Soundtrack Startup

        .task {
            audioManager.resumeIfNeeded()
        }

        // MARK: Firebase Startup

        .task(
            id: firebaseAuthService.currentUserID
        ) {
            await restoreApplicationState()
        }

        // MARK: Connection Changes

        .onChange(
            of: connectionStore.isConnected
        ) {
            Task {
                await handleConnectionChange()
            }
        }

        // MARK: Scene Changes

        .onChange(of: scenePhase) {
            switch scenePhase {

            case .active:
                audioManager.resumeIfNeeded()

                beaconStore
                    .refreshDailyState()

                partnerBeaconStore
                    .refreshDailyState()

                Task {
                    await refreshFirebaseState()
                }

            case .inactive,
                 .background:
                audioManager.stop()

            @unknown default:
                break
            }
        }
    }

    // MARK: - Root Content

    @ViewBuilder
    private var rootContent: some View {

        if !hasCompletedOnboarding {

            OnboardingView()

        } else if shouldShowLoadingState {

            loadingView

        } else if connectionStore.isConnected {

            ConnectedContentView()

        } else {

            UnpairedContentView()
        }
    }

    // MARK: - Loading

    private var shouldShowLoadingState: Bool {
        firebaseAuthService.currentUserID == nil ||
        connectionStore.isRestoringConnection ||
        !hasAttemptedConnectionRestore
    }

    private var loadingView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
                .scaleEffect(0.9)
        }
    }

    // MARK: - Startup

    private func restoreApplicationState() async {
        guard firebaseAuthService.currentUserID != nil else {
            return
        }

        await userService
            .createOrLoadUser()

        await connectionStore
            .restoreConnectionFromFirebase()

        if connectionStore.isConnected {

            await beaconStore
                .startListening()

            await partnerBeaconStore
                .startListening()

        } else {

            beaconStore
                .stopListening()

            partnerBeaconStore
                .stopListening()
        }

        hasAttemptedConnectionRestore = true
    }

    // MARK: - Connection Change

    private func handleConnectionChange() async {
        if connectionStore.isConnected {

            await partnerBeaconStore
                .startListening()

        } else {

            partnerBeaconStore
                .stopListening()
        }
    }

    // MARK: - Foreground Refresh

    private func refreshFirebaseState() async {
        guard firebaseAuthService.currentUserID != nil else {
            return
        }

        await userService
            .createOrLoadUser()

        await connectionStore
            .restoreConnectionFromFirebase()

        if connectionStore.isConnected {

            await partnerBeaconStore
                .startListening()

        } else {

            partnerBeaconStore
                .stopListening()
        }
    }
}

// MARK: - Preview

#Preview {
    AppRootView()
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
            FirebaseAuthService()
        )
        .environmentObject(
            UserService()
        )
        .environmentObject(
            PairingService()
        )
        .environmentObject(
            AudioManager()
        )
}
