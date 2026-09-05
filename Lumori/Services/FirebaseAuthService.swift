import Foundation
import Combine
import FirebaseAuth

// MARK: - Firebase Auth Service

/// Owns Lumori's Firebase authentication state.
///
/// Lumori begins with an anonymous Firebase identity so a user can enter the
/// app without creating an account.
///
/// When the user decides to connect with someone, they can:
/// - secure the anonymous account with email/password, preserving its UID
/// - sign into an existing secured Lumori account
///
/// Signing out does not disconnect the user's Lumori relationship.
/// It only removes that account from the current device and creates a new
/// anonymous session.
@MainActor
final class FirebaseAuthService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentUserID: String?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAnonymous = true
    @Published private(set) var emailAddress: String?

    @Published private(set) var isLinkingEmail = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var isSigningOut = false

    @Published var errorMessage: String?

    // MARK: - Initialization

    init() {
        if let currentUser = Auth.auth().currentUser {
            updateState(from: currentUser)
        } else {
            Task {
                await signInAnonymously()
            }
        }
    }

    // MARK: - Anonymous Authentication

    /// Creates Lumori's temporary anonymous identity.
    func signInAnonymously() async {
        guard Auth.auth().currentUser == nil else {
            refreshCurrentUser()
            return
        }

        errorMessage = nil

        do {
            let result = try await Auth.auth().signInAnonymously()

            updateState(from: result.user)

            print("🔥 Lumori anonymous authentication ready:")
            print(result.user.uid)

            NotificationCenter.default.post(
                name: .firebaseUserReady,
                object: nil
            )

        } catch {
            errorMessage = authMessage(for: error)

            print("❌ Anonymous authentication failed:")
            print(error.localizedDescription)
        }
    }

    // MARK: - Secure Anonymous Account

    /// Links email/password credentials to the current anonymous account.
    ///
    /// Firebase preserves the existing UID.
    func linkEmailAccount(
        email: String,
        password: String
    ) async -> Bool {

        let cleanedEmail = normalizeEmail(email)

        errorMessage = nil

        guard isValidEmail(cleanedEmail) else {
            errorMessage = "Enter a valid email address."
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Lumori could not find your current account."
            return false
        }

        guard user.isAnonymous else {
            errorMessage = "This Lumori account is already secured."
            return false
        }

        isLinkingEmail = true

        defer {
            isLinkingEmail = false
        }

        let originalUID = user.uid

        do {
            let credential = EmailAuthProvider.credential(
                withEmail: cleanedEmail,
                password: password
            )

            let result = try await user.link(
                with: credential
            )

            updateState(from: result.user)

            print("🔐 Lumori account secured")
            print("🆔 UID preserved:")
            print(originalUID)

            NotificationCenter.default.post(
                name: .firebaseUserReady,
                object: nil
            )

            return true

        } catch {
            errorMessage = authMessage(for: error)

            print("❌ Lumori account security failed:")
            print(error.localizedDescription)

            return false
        }
    }

    // MARK: - Existing Account Sign In

    /// Signs into an existing secured Lumori account.
    ///
    /// This replaces the fresh anonymous Firebase session with the returning
    /// user's original Firebase identity.
    func signInExistingAccount(
        email: String,
        password: String
    ) async -> Bool {

        let cleanedEmail = normalizeEmail(email)

        errorMessage = nil

        guard isValidEmail(cleanedEmail) else {
            errorMessage = "Enter a valid email address."
            return false
        }

        guard !password.isEmpty else {
            errorMessage = "Enter your password."
            return false
        }

        isSigningIn = true

        defer {
            isSigningIn = false
        }

        do {
            let result = try await Auth.auth().signIn(
                withEmail: cleanedEmail,
                password: password
            )

            updateState(from: result.user)

            print("🔓 Existing Lumori account signed in")
            print("🆔 Restored UID:")
            print(result.user.uid)

            NotificationCenter.default.post(
                name: .firebaseUserReady,
                object: nil
            )

            return true

        } catch {
            errorMessage = authMessage(for: error)

            print("❌ Existing Lumori account sign-in failed:")
            print(error.localizedDescription)

            return false
        }
    }
    
    // MARK: - Password Reset

    /// Sends Firebase's password-reset email for an existing Lumori account.
    func sendPasswordReset(
        email: String
    ) async -> Bool {

        let cleanedEmail = normalizeEmail(email)

        errorMessage = nil

        guard isValidEmail(cleanedEmail) else {
            errorMessage = "Enter a valid email address."
            return false
        }

        do {
            try await Auth.auth().sendPasswordReset(
                withEmail: cleanedEmail
            )

            print("📩 Lumori password reset email sent")
            print(cleanedEmail)

            return true

        } catch {
            errorMessage = authMessage(for: error)

            print("❌ Password reset failed:")
            print(error.localizedDescription)

            return false
        }
    }

    // MARK: - Sign Out

    /// Signs the secured account out of this device and immediately creates a
    /// new anonymous Lumori session.
    ///
    /// This does NOT modify the user's Firestore connection and therefore does
    /// not disconnect their partner.
    func signOutToAnonymous() async -> Bool {

        guard !isSigningOut else {
            return false
        }

        errorMessage = nil
        isSigningOut = true

        defer {
            isSigningOut = false
        }

        do {
            let previousUID = Auth.auth().currentUser?.uid

            try Auth.auth().signOut()

            // Clear the published state immediately so views do not continue
            // treating the previous secured account as active.
            currentUserID = nil
            isAuthenticated = false
            isAnonymous = true
            emailAddress = nil

            print("🚪 Lumori account signed out")

            if let previousUID {
                print("🆔 Signed-out UID:")
                print(previousUID)
            }

            // Lumori always operates with a Firebase identity, so immediately
            // establish a new anonymous account for this installation.
            let result = try await Auth.auth().signInAnonymously()

            updateState(from: result.user)

            print("🔥 New anonymous Lumori session:")
            print(result.user.uid)

            NotificationCenter.default.post(
                name: .firebaseUserReady,
                object: nil
            )

            return true

        } catch {
            refreshCurrentUser()

            errorMessage = authMessage(for: error)

            print("❌ Lumori sign out failed:")
            print(error.localizedDescription)

            return false
        }
    }

    // MARK: - Refresh

    func refreshCurrentUser() {
        guard let user = Auth.auth().currentUser else {
            currentUserID = nil
            isAuthenticated = false
            isAnonymous = true
            emailAddress = nil
            return
        }

        updateState(from: user)
    }

    // MARK: - State

    private func updateState(from user: User) {
        currentUserID = user.uid
        isAuthenticated = true
        isAnonymous = user.isAnonymous
        emailAddress = user.email
    }

    // MARK: - Validation

    private func normalizeEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")

        guard parts.count == 2 else {
            return false
        }

        return parts[1].contains(".")
    }

    // MARK: - Firebase Errors

    private func authMessage(for error: Error) -> String {
        let nsError = error as NSError

        guard let code = AuthErrorCode(
            rawValue: nsError.code
        ) else {
            return "Something went wrong. Please try again."
        }

        switch code {

        case .emailAlreadyInUse,
             .credentialAlreadyInUse:
            return "That email is already connected to another Lumori account."

        case .invalidEmail:
            return "Enter a valid email address."

        case .weakPassword:
            return "Choose a stronger password."

        case .wrongPassword,
             .invalidCredential:
            return "The email or password is incorrect."

        case .userNotFound:
            return "No Lumori account was found with that email."

        case .userDisabled:
            return "This Lumori account is currently unavailable."

        case .tooManyRequests:
            return "Too many attempts were made. Please wait a little while and try again."

        case .networkError:
            return "Lumori couldn't reach the network. Check your connection and try again."

        default:
            return nsError.localizedDescription
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let firebaseUserReady = Notification.Name(
        "firebaseUserReady"
    )
}
