import SwiftUI

// MARK: - Settings View

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

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
    
    @EnvironmentObject
    private var notificationManager: NotificationManager

    // MARK: - State

    @State
    private var isShowingDisconnectConfirmation = false

    @State
    private var isShowingSignOutConfirmation = false

    @State
    private var isShowingIntroduction = false

    @State
    private var isSigningOut = false

    @State
    private var signOutErrorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                connectionSection

                accountSection

                soundSection
                
                notificationSection

                appearanceSection

                helpSection

                aboutSection

                #if DEBUG
                debugSection
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            
            .task {
                await notificationManager
                    .refreshAuthorizationStatus()
            }

            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }

            // MARK: Introduction

            .fullScreenCover(
                isPresented: $isShowingIntroduction
            ) {
                OnboardingView(
                    isReplay: true
                )
            }

            // MARK: Disconnect Confirmation

            .confirmationDialog(
                "Disconnect from your partner?",
                isPresented:
                    $isShowingDisconnectConfirmation,
                titleVisibility: .visible
            ) {

                Button(
                    "Disconnect Partner",
                    role: .destructive
                ) {
                    Task {
                        await disconnectPartner()
                    }
                }

                Button(
                    "Cancel",
                    role: .cancel
                ) {}

            } message: {
                Text(
                    "This ends the shared Lumori connection for both people. Your existing account is not deleted."
                )
            }

            // MARK: Sign Out Confirmation

            .confirmationDialog(
                "Sign out of Lumori?",
                isPresented:
                    $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {

                Button(
                    "Sign Out",
                    role: .destructive
                ) {
                    Task {
                        await signOut()
                    }
                }

                Button(
                    "Cancel",
                    role: .cancel
                ) {}

            } message: {
                Text(
                    "Signing out only removes this account from this device. It will not disconnect your partner or delete your Lumori account."
                )
            }

            // MARK: Sign Out Error

            .alert(
                "Unable to Sign Out",
                isPresented: Binding(
                    get: {
                        signOutErrorMessage != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            signOutErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    signOutErrorMessage = nil
                }
            } message: {
                Text(
                    signOutErrorMessage
                        ?? "Something went wrong."
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connection

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            if let connection =
                connectionStore.connection {

                LabeledContent(
                    "Partner",
                    value: connection.partnerName
                )

                LabeledContent(
                    "Status",
                    value: "Connected"
                )

                LabeledContent(
                    "Connected",
                    value:
                        connection.connectedDate
                            .formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                )

                Button(
                    role: .destructive
                ) {
                    isShowingDisconnectConfirmation =
                        true
                } label: {
                    Label(
                        "Disconnect Partner",
                        systemImage:
                            "person.crop.circle.badge.minus"
                    )
                }
                .disabled(
                    connectionStore.isDisconnecting
                )

                if connectionStore.isDisconnecting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)

                        Text(
                            "Disconnecting…"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                if let errorMessage =
                    connectionStore
                        .disconnectErrorMessage {

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

            } else {

                LabeledContent(
                    "Status",
                    value: "Not connected"
                )
            }

        } header: {
            Text("Connection")
        } footer: {
            if connectionStore.isConnected {
                Text(
                    "Disconnect Partner ends the shared Lumori connection for both people."
                )
            }
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        if !firebaseAuthService.isAnonymous {

            Section {

                if let email =
                    firebaseAuthService.emailAddress {

                    LabeledContent(
                        "Email",
                        value: email
                    )
                }

                Button(
                    role: .destructive
                ) {
                    isShowingSignOutConfirmation =
                        true
                } label: {
                    if isSigningOut {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)

                            Text(
                                "Signing Out…"
                            )
                        }
                    } else {
                        Label(
                            "Sign Out",
                            systemImage:
                                "rectangle.portrait.and.arrow.right"
                        )
                    }
                }
                .disabled(
                    isSigningOut ||
                    firebaseAuthService.isSigningOut
                )

            } header: {
                Text("Account")
            } footer: {
                Text(
                    "Signing out affects only this device. It does not disconnect your partner or delete your account."
                )
            }
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section {

            Toggle(
                "Ambient Music",
                isOn: Binding(
                    get: {
                        audioManager.isMusicEnabled
                    },
                    set: { newValue in
                        audioManager.setMusicEnabled(
                            newValue
                        )
                    }
                )
            )

        } header: {
            Text("Sound")
        } footer: {
            Text(
                "Play Lumori's ambient soundtrack while the app is open."
            )
        }
    }
    
    // MARK: - Notifications

    private var notificationSection: some View {
        Section {

            Toggle(
                "Beacon Notifications",
                isOn: Binding(
                    get: {
                        notificationManager
                            .isEnabled
                    },
                    set: { newValue in

                        Task {
                            await notificationManager
                                .setEnabled(
                                    newValue
                                )
                        }
                    }
                )
            )

            if notificationManager
                .authorizationStatus == .denied {

                Button {
                    notificationManager
                        .openSystemSettings()
                } label: {
                    Label(
                        "Open iPhone Settings",
                        systemImage:
                            "gear"
                    )
                }
            }

        } header: {
            Text("Notifications")
        } footer: {

            if notificationManager
                .authorizationStatus == .denied {

                Text(
                    "Notifications are disabled in iPhone Settings."
                )

            } else {

                Text(
                    "Get notified when your partner shares a beacon. Notifications are off by default."
                )
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {

            LabeledContent(
                "Theme",
                value: "Dark"
            )
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        Section("Help") {

            Button {
                isShowingIntroduction = true
            } label: {
                Label(
                    "View Introduction",
                    systemImage: "book.closed"
                )
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {

            LabeledContent(
                "App",
                value: "Lumori"
            )

            LabeledContent(
                "Version",
                value: appVersion
            )
        }
    }

    // MARK: - Debug

    #if DEBUG

    private var debugSection: some View {
        Section("Debug") {

            if let uid =
                firebaseAuthService.currentUserID {

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Firebase UID")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                    Text(uid)
                        .font(
                            .system(
                                .caption,
                                design: .monospaced
                            )
                        )
                        .textSelection(
                            .enabled
                        )
                }
                .padding(
                    .vertical,
                    4
                )
            }
        }
    }

    #endif

    // MARK: - Disconnect

    private func disconnectPartner() async {

        await connectionStore
            .disconnectFromFirebase()

        guard
            connectionStore
                .disconnectErrorMessage == nil
        else {
            return
        }

        partnerBeaconStore
            .stopListening()

        dismiss()
    }

    // MARK: - Sign Out

    private func signOut() async {

        guard !isSigningOut else {
            return
        }

        isSigningOut = true
        signOutErrorMessage = nil

        partnerBeaconStore
            .stopListening()

        let success =
            await firebaseAuthService
                .signOutToAnonymous()

        guard success else {

            signOutErrorMessage =
                firebaseAuthService.errorMessage
                ?? "Lumori could not sign out."

            isSigningOut = false

            if connectionStore.isConnected {
                await partnerBeaconStore
                    .startListening()
            }

            return
        }

        await userService
            .createOrLoadUser()

        await connectionStore
            .restoreConnectionFromFirebase()

        partnerBeaconStore
            .stopListening()

        isSigningOut = false

        dismiss()
    }

    // MARK: - Version

    private var appVersion: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String

        return version ?? "1.0"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(
            ConnectionStore()
        )
        .environmentObject(
            PartnerBeaconStore()
        )
        .environmentObject(
            FirebaseAuthService()
        )
        .environmentObject(
            UserService()
        )
        .environmentObject(
            AudioManager()
        )
        .environmentObject(
            NotificationManager()
        )
}
