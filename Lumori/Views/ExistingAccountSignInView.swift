import SwiftUI

// MARK: - Existing Account Sign In

/// Allows a returning Lumori user to recover an account that was previously
/// secured with email and password.
struct ExistingAccountSignInView: View {

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject
    private var firebaseAuthService: FirebaseAuthService

    @EnvironmentObject
    private var userService: UserService

    @EnvironmentObject
    private var connectionStore: ConnectionStore

    @EnvironmentObject
    private var partnerBeaconStore: PartnerBeaconStore

    // MARK: - State

    @State
    private var email = ""

    @State
    private var password = ""

    @FocusState
    private var focusedField: Field?

    // MARK: - Field

    private enum Field {
        case email
        case password
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header

                        credentials

                        signInButton

                        if let errorMessage =
                            firebaseAuthService.errorMessage {

                            errorText(errorMessage)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Cancel") {
                        firebaseAuthService.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            firebaseAuthService.errorMessage = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.9))

            Text("Welcome back")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(
                "Sign in to restore your Lumori account and connection."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Credentials

    private var credentials: some View {
        VStack(spacing: 14) {
            TextField(
                "Email",
                text: $email
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textContentType(.username)
            .focused(
                $focusedField,
                equals: .email
            )
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }
            .padding(14)
            .background(fieldBackground)

            SecureField(
                "Password",
                text: $password
            )
            .textContentType(.password)
            .focused(
                $focusedField,
                equals: .password
            )
            .submitLabel(.go)
            .onSubmit {
                Task {
                    await signIn()
                }
            }
            .padding(14)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.07))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            }
    }

    // MARK: - Sign In

    private var signInButton: some View {
        Button {
            Task {
                await signIn()
            }
        } label: {
            Group {
                if firebaseAuthService.isSigningIn {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "#6874D8"))
        .disabled(
            firebaseAuthService.isSigningIn ||
            email.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty ||
            password.isEmpty
        )
    }

    // MARK: - Error

    private func errorText(
        _ message: String
    ) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red.opacity(0.9))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Authentication

    private func signIn() async {
        focusedField = nil

        let success =
            await firebaseAuthService
                .signInExistingAccount(
                    email: email,
                    password: password
                )

        guard success else {
            return
        }

        /*
         The authenticated Firebase UID has now changed from the temporary
         anonymous identity to the returning user's original UID.

         Reload their Lumori profile and restore the connection associated
         with that UID.
         */

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

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ExistingAccountSignInView()
        .environmentObject(
            FirebaseAuthService()
        )
        .environmentObject(
            UserService()
        )
        .environmentObject(
            ConnectionStore()
        )
        .environmentObject(
            PartnerBeaconStore()
        )
}
