import SwiftUI

// MARK: - Pairing View

/// Handles Lumori's account security and partner pairing flow.
///
/// Anonymous users first secure their Lumori account with email/password.
/// Returning users can instead sign in to an existing Lumori account.
///
/// Once the account is secured, the user can either:
/// - create a pairing code, or
/// - join an existing pairing code.
struct PairingView: View {

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var connectionStore: ConnectionStore

    @EnvironmentObject
    private var pairingService: PairingService

    @EnvironmentObject
    private var userService: UserService

    @EnvironmentObject
    private var firebaseAuthService: FirebaseAuthService

    // MARK: - Pairing Mode

    private enum PairingMode: String, CaseIterable, Identifiable {
        case invite = "Invite"
        case join = "Join"

        var id: String {
            rawValue
        }
    }

    // MARK: - State

    @State
    private var selectedMode: PairingMode = .invite

    @State
    private var enteredCode = ""

    @State
    private var displayName = ""

    @State
    private var email = ""

    @State
    private var password = ""

    @State
    private var confirmPassword = ""

    @State
    private var didCopyCode = false

    @State
    private var hasCompletedLocalConnection = false

    @State
    private var isPreparingPairing = false

    @State
    private var isShowingExistingAccountSignIn = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header

                        nameSection

                        if firebaseAuthService.isAnonymous {
                            accountSecuritySection
                        } else {
                            securedAccountSection
                            pairingSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)

        .sheet(
            isPresented: $isShowingExistingAccountSignIn
        ) {
            ExistingAccountSignInView()
        }

        .task {
            loadExistingName()
        }

        .onChange(
            of: pairingService.isConnected
        ) { _, isConnected in
            guard isConnected else {
                return
            }

            Task {
                await finishConnectionIfNeeded()
            }
        }

        .onChange(
            of: firebaseAuthService.isAnonymous
        ) { _, isAnonymous in
            guard !isAnonymous else {
                return
            }

            Task {
                await refreshAfterAuthentication()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.9))

            Text("Connect with someone")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(
                "Lumori is a private space shared between two people."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - Name

    private var nameSection: some View {
        sectionCard {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                sectionTitle("Your name")

                Text(
                    "This is the name your partner will see."
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))

                TextField(
                    "Name",
                    text: $displayName
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(14)
                .background(fieldBackground)
            }
        }
    }

    // MARK: - Account Security

    private var accountSecuritySection: some View {
        sectionCard {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                sectionTitle(
                    "Secure your Lumori account"
                )

                Text(
                    "You'll need an account before connecting so your Lumori data can be restored later."
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))

                TextField(
                    "Email",
                    text: $email
                )
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .padding(14)
                .background(fieldBackground)

                SecureField(
                    "Password",
                    text: $password
                )
                .textContentType(.newPassword)
                .padding(14)
                .background(fieldBackground)

                SecureField(
                    "Confirm password",
                    text: $confirmPassword
                )
                .textContentType(.newPassword)
                .padding(14)
                .background(fieldBackground)

                secureAccountButton

                Button {
                    firebaseAuthService.errorMessage = nil
                    isShowingExistingAccountSignIn = true
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            "Already have an account?"
                        )
                        .foregroundStyle(.white.opacity(0.5))

                        Text("Sign in")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if let errorMessage =
                    firebaseAuthService.errorMessage {

                    errorText(
                        errorMessage
                    )
                }
            }
        }
    }

    // MARK: - Secure Account Button

    private var secureAccountButton: some View {
        Button {
            Task {
                await secureAccount()
            }
        } label: {
            Group {
                if firebaseAuthService.isLinkingEmail {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Secure Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .buttonStyle(.borderedProminent)
        .tint(
            Color(
                hex: "#6874D8"
            )
        )
        .disabled(
            firebaseAuthService.isLinkingEmail ||
            isPreparingPairing
        )
    }

    // MARK: - Secured Account

    private var securedAccountSection: some View {
        sectionCard {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                HStack(spacing: 10) {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    Text("Account secured")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                if let emailAddress =
                    firebaseAuthService.emailAddress {

                    Text(emailAddress)
                        .font(.subheadline)
                        .foregroundStyle(
                            .white.opacity(0.55)
                        )
                }
            }
        }
    }

    // MARK: - Pairing

    private var pairingSection: some View {
        sectionCard {
            VStack(spacing: 18) {
                Picker(
                    "Pairing mode",
                    selection: $selectedMode
                ) {
                    ForEach(
                        PairingMode.allCases
                    ) { mode in
                        Text(mode.rawValue)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedMode {

                case .invite:
                    inviteSection

                case .join:
                    joinSection
                }
            }
        }
    }

    // MARK: - Invite

    private var inviteSection: some View {
        VStack(spacing: 16) {

            if let code =
                pairingService.pairingCode {

                Text(
                    "Share this code with your partner."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.55)
                )
                .multilineTextAlignment(.center)

                Text(code)
                    .font(
                        .system(
                            size: 36,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .tracking(5)
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)

                Button {
                    UIPasteboard.general.string =
                        code

                    didCopyCode = true

                    DispatchQueue.main
                        .asyncAfter(
                            deadline:
                                .now() + 1.5
                        ) {
                            didCopyCode = false
                        }

                } label: {
                    Label(
                        didCopyCode
                            ? "Copied"
                            : "Copy Code",
                        systemImage:
                            didCopyCode
                                ? "checkmark"
                                : "doc.on.doc"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)

                if pairingService.isConnected {
                    ProgressView(
                        "Finishing connection…"
                    )
                    .tint(.white)
                    .foregroundStyle(
                        .white.opacity(0.7)
                    )
                } else {
                    Text(
                        "Waiting for your partner…"
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                }

            } else {

                Text(
                    "Create a private code for your partner to enter on their device."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.55)
                )
                .multilineTextAlignment(.center)

                Button {
                    Task {
                        await createPairingCode()
                    }
                } label: {
                    Group {
                        if pairingService
                            .isCreatingCode {

                            ProgressView()
                                .tint(.white)

                        } else {

                            Label(
                                "Create Pairing Code",
                                systemImage: "link"
                            )
                            .fontWeight(
                                .semibold
                            )
                        }
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                    .frame(height: 46)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(
                    Color(
                        hex: "#6874D8"
                    )
                )
                .disabled(
                    pairingService
                        .isCreatingCode ||
                    isPreparingPairing
                )
            }

            pairingError
        }
    }

    // MARK: - Join

    private var joinSection: some View {
        VStack(spacing: 16) {

            Text(
                "Enter the six-digit code from your partner."
            )
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(0.55)
            )
            .multilineTextAlignment(.center)

            TextField(
                "000000",
                text: $enteredCode
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(
                .system(
                    size: 28,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .tracking(4)
            .padding(14)
            .background(fieldBackground)
            .onChange(of: enteredCode) {
                let digits =
                    enteredCode.filter {
                        $0.isNumber
                    }

                enteredCode =
                    String(
                        digits.prefix(6)
                    )
            }

            Button {
                Task {
                    await joinPairingCode()
                }
            } label: {
                Group {
                    if pairingService
                        .isJoiningCode {

                        ProgressView()
                            .tint(.white)

                    } else {

                        Text("Join Connection")
                            .fontWeight(
                                .semibold
                            )
                    }
                }
                .frame(
                    maxWidth: .infinity
                )
                .frame(height: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(
                Color(
                    hex: "#6874D8"
                )
            )
            .disabled(
                enteredCode.count != 6 ||
                pairingService
                    .isJoiningCode ||
                isPreparingPairing
            )

            pairingError
        }
    }

    // MARK: - Pairing Error

    @ViewBuilder
    private var pairingError: some View {
        if let errorMessage =
            pairingService.errorMessage {

            errorText(
                errorMessage
            )
        }
    }

    // MARK: - Card

    private func sectionCard<
        Content: View
    >(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(18)
            .background {
                RoundedRectangle(
                    cornerRadius: 20
                )
                .fill(
                    Color.white.opacity(
                        0.055
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 20
                    )
                    .stroke(
                        Color.white.opacity(
                            0.07
                        ),
                        lineWidth: 1
                    )
                }
            }
    }

    // MARK: - Field Background

    private var fieldBackground: some View {
        RoundedRectangle(
            cornerRadius: 14
        )
        .fill(
            Color.white.opacity(0.07)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 14
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    // MARK: - Text Helpers

    private func sectionTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func errorText(
        _ message: String
    ) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(
                .red.opacity(0.9)
            )
            .multilineTextAlignment(
                .center
            )
            .frame(
                maxWidth: .infinity
            )
    }

    // MARK: - Initial State

    private func loadExistingName() {
        if let existingName =
            userService.userProfile?
                .displayName,
           !existingName.isEmpty {

            displayName = existingName
        }
    }

    // MARK: - Secure Account

    private func secureAccount() async {
        let cleanName =
            displayName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanName.isEmpty else {
            firebaseAuthService.errorMessage =
                "Enter your name first."
            return
        }

        guard password ==
                confirmPassword else {

            firebaseAuthService.errorMessage =
                "Passwords do not match."
            return
        }

        isPreparingPairing = true

        defer {
            isPreparingPairing = false
        }

        firebaseAuthService.errorMessage =
            nil

        await userService
            .updateDisplayName(
                cleanName
            )

        guard
            userService.errorMessage == nil
        else {
            return
        }

        let success =
            await firebaseAuthService
                .linkEmailAccount(
                    email: email,
                    password: password
                )

        guard success else {
            return
        }

        firebaseAuthService
            .refreshCurrentUser()

        await userService
            .createOrLoadUser()
    }

    // MARK: - Create Pairing Code

    private func createPairingCode() async {
        guard
            await prepareNameForPairing()
        else {
            return
        }

        await pairingService
            .createPairingCode()
    }

    // MARK: - Join Pairing Code

    private func joinPairingCode() async {
        guard
            await prepareNameForPairing()
        else {
            return
        }

        await pairingService
            .joinPairingCode(
                enteredCode
            )

        if pairingService.isConnected {
            await finishConnectionIfNeeded()
        }
    }

    // MARK: - Name Preparation

    private func prepareNameForPairing()
        async -> Bool {

        let cleanName =
            displayName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanName.isEmpty else {
            pairingService.errorMessage =
                "Enter your name first."
            return false
        }

        isPreparingPairing = true

        defer {
            isPreparingPairing = false
        }

        await userService
            .updateDisplayName(
                cleanName
            )

        return
            userService.errorMessage == nil
    }

    // MARK: - Complete Connection

    private func finishConnectionIfNeeded()
        async {

        guard
            !hasCompletedLocalConnection
        else {
            return
        }

        guard let code =
            pairingService.pairingCode
                ?? normalizedEnteredCode
        else {
            return
        }

        hasCompletedLocalConnection =
            true

        connectionStore.connect(
            partnerName: "Partner",
            pairingCode: code
        )

        await connectionStore
            .restoreConnectionFromFirebase()

        if connectionStore.isConnected {
            dismiss()
        } else {
            hasCompletedLocalConnection =
                false
        }
    }

    // MARK: - Existing Account Refresh

    private func refreshAfterAuthentication()
        async {

        await userService
            .createOrLoadUser()

        loadExistingName()

        await connectionStore
            .restoreConnectionFromFirebase()

        if connectionStore.isConnected {
            dismiss()
        }
    }

    // MARK: - Code Normalization

    private var normalizedEnteredCode:
        String? {

        let code =
            enteredCode.filter {
                $0.isNumber
            }

        guard code.count == 6 else {
            return nil
        }

        return code
    }
}

// MARK: - Preview

#Preview {
    PairingView()
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
