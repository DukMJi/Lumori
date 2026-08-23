import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Service

/// Creates, loads, repairs, and updates the authenticated user's Lumori profile.
///
/// Firebase Authentication owns the user's identity.
/// Firestore stores Lumori-specific profile information such as:
///
/// - createdAt
/// - connectionID
/// - displayName
@MainActor
final class UserService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var userProfile: LumoriUser?

    @Published private(set) var errorMessage: String?

    @Published private(set) var isUpdatingDisplayName = false

    // MARK: - Firebase

    private let db = Firestore.firestore()

    // MARK: - Create Or Load User

    func createOrLoadUser() async {

        guard let firebaseUser =
                Auth.auth().currentUser
        else {

            errorMessage =
                "No Firebase user found."

            return
        }

        let uid =
            firebaseUser.uid

        let reference =
            db
                .collection("users")
                .document(uid)

        do {

            let snapshot =
                try await reference
                    .getDocument()

            // MARK: Existing User

            if snapshot.exists {

                let data =
                    snapshot.data() ?? [:]

                let existingConnectionID =
                    data["connectionID"]
                        as? String

                let existingDisplayName =
                    data["displayName"]
                        as? String

                let createdAt =
                    (data["createdAt"]
                        as? Timestamp)?
                        .dateValue()
                    ?? Date()

                let repairedUser =
                    LumoriUser(
                        id: uid,
                        createdAt: createdAt,
                        connectionID:
                            existingConnectionID,
                        displayName:
                            existingDisplayName
                    )

                // Repair missing required fields without
                // deleting existing Firebase profile data.
                try reference
                    .setData(
                        from: repairedUser,
                        merge: true
                    )

                userProfile =
                    repairedUser

                errorMessage =
                    nil

                print(
                    "🌙 Loaded Lumori user:"
                )

                print(uid)

                return
            }

            // MARK: New User

            let newUser =
                LumoriUser(
                    id: uid,
                    createdAt: Date(),
                    connectionID: nil,
                    displayName: nil
                )

            try reference
                .setData(
                    from: newUser
                )

            userProfile =
                newUser

            errorMessage =
                nil

            print(
                "🌙 Created Lumori user:"
            )

            print(uid)

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                "🔥 Firestore Error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Display Name

    /// Saves or updates the current user's Lumori display name.
    ///
    /// This only updates the displayName field and preserves all other
    /// profile data such as the active connectionID.
    @discardableResult
    func updateDisplayName(
        _ name: String
    ) async -> Bool {

        let cleanedName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanedName.isEmpty
        else {

            errorMessage =
                "Enter a name first."

            return false
        }

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            errorMessage =
                "No Firebase user found."

            return false
        }

        isUpdatingDisplayName =
            true

        errorMessage =
            nil

        defer {
            isUpdatingDisplayName =
                false
        }

        do {

            let reference =
                db
                    .collection("users")
                    .document(uid)

            try await reference
                .setData(
                    [
                        "displayName":
                            cleanedName
                    ],
                    merge: true
                )

            // Keep the local profile synchronized immediately.
            if let existingProfile =
                userProfile {

                userProfile =
                    LumoriUser(
                        id:
                            existingProfile.id,
                        createdAt:
                            existingProfile.createdAt,
                        connectionID:
                            existingProfile.connectionID,
                        displayName:
                            cleanedName
                    )

            } else {

                // If the profile has not been loaded yet,
                // reload it now.
                await createOrLoadUser()
            }

            print(
                "👤 Lumori display name updated:"
            )

            print(
                cleanedName
            )

            return true

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                "🔥 Display name update error:",
                error.localizedDescription
            )

            return false
        }
    }
}
