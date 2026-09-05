import SwiftUI

// MARK: - Existing Account Sign In

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

    @State
    private var isSendingPasswordReset = false

    @State
    private var passwordResetMessage: String?

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

                        forgotPasswordButton

                        signInButton

                        if let resetMessage =
                            passwordResetMessage {

                            Text(resetMessage)
                                .font(.footnote)
                                .foregroundStyle(
                                    .green.opacity(0.9)
                                )
                                .multilineTextAlignment(
                                    .center
                                )
                                .frame(
                                    maxWidth: .infinity
                                )
                        }

                        if let errorMessage =
                            firebaseAuthService.errorMessage {

                            errorText(
                                errorMessage
                            )
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

            Image(
                systemName:
                    "person.crop.circle"
            )
            .font(
                .system(size: 40)
            )
            .foregroundStyle(
                .white.opacity(0.9)
            )

            Text("Welcome back")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(
                "Sign in to restore your Lumori account and connection."
            )
            .font(.subheadline)
            .foregroundStyle(
                .white.opacity(0.55)
            )
            .multilineTextAlignment(
                .center
            )
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
            .textInputAutocapitalization(
                .never
            )
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

    // MARK: - Forgot Password

    private var forgotPasswordButton: some View {
        HStack {
            Spacer()

            Button {
                Task {
                    await sendPasswordReset()
                }
            } label: {
                if isSendingPasswordReset {

                    ProgressView()
                        .tint(.white)

                } else {

                    Text("Forgot password?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                Color(
                    hex: "#8993EB"
                )
            )
            .disabled(
                isSendingPasswordReset
            )
        }
        .padding(.top, -8)
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
        .tint(
            Color(
                hex: "#6874D8"
            )
        )
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

    // MARK: - Sign In Action

    private func signIn() async {
        focusedField = nil

        passwordResetMessage = nil

        let success =
            await firebaseAuthService
                .signInExistingAccount(
                    email: email,
                    password: password
                )

        guard success else {
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

        dismiss()
    }

    // MARK: - Password Reset Action

    private func sendPasswordReset() async {

        focusedField = nil

        passwordResetMessage = nil

        firebaseAuthService.errorMessage = nil

        let cleanedEmail =
            email.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedEmail.isEmpty else {

            firebaseAuthService.errorMessage =
                "Enter your email address first."

            return
        }

        isSendingPasswordReset = true

        let success =
            await firebaseAuthService
                .sendPasswordReset(
                    email: cleanedEmail
                )

        isSendingPasswordReset = false

        guard success else {
            return
        }

        passwordResetMessage =
            "Password reset email sent. Check your inbox."
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
