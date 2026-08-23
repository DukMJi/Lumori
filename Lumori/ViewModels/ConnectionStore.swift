import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Connection Store

/// Manages the current Lumori partner connection.
///
/// Firebase is the source of truth for the relationship.
/// A small local cache is retained for fast startup.
@MainActor
final class ConnectionStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var connection: PartnerConnection?

    @Published private(set) var isRestoringConnection = false

    @Published private(set) var isDisconnecting = false

    @Published private(set) var restoreErrorMessage: String?

    @Published private(set) var disconnectErrorMessage: String?

    // MARK: - Local Storage

    private let storageKey =
        "lumori.partnerConnection"

    // MARK: - Firebase

    private let db =
        Firestore.firestore()

    // MARK: - Realtime Listener

    private var userConnectionListener:
        ListenerRegistration?

    private var listeningUserID:
        String?

    // MARK: - Initialization

    init() {
        loadConnection()
    }

    deinit {
        userConnectionListener?
            .remove()
    }

    // MARK: - Computed Properties

    var isConnected: Bool {
        connection != nil
    }

    // MARK: - Restore From Firebase

    /// Restores the authenticated user's real Lumori connection.
    ///
    /// This also loads the connected partner's profile so Lumori
    /// can display their real display name.
    func restoreConnectionFromFirebase() async {

        guard !isRestoringConnection else {
            return
        }

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            restoreErrorMessage =
                "No authenticated Firebase user was found."

            return
        }

        isRestoringConnection =
            true

        restoreErrorMessage =
            nil

        defer {
            isRestoringConnection =
                false
        }

        do {

            // MARK: Current User Profile

            let userReference =
                db
                    .collection("users")
                    .document(uid)

            let userSnapshot =
                try await userReference
                    .getDocument()

            guard let userData =
                    userSnapshot.data()
            else {

                throw ConnectionRestoreError
                    .userProfileMissing
            }

            guard let connectionID =
                    userData[
                        "connectionID"
                    ] as? String,
                  !connectionID.isEmpty
            else {

                clearLocalConnection()

                startUserConnectionListener(
                    for: uid
                )

                print(
                    "🔗 No Firebase connection found."
                )

                return
            }

            // MARK: Shared Connection

            let connectionReference =
                db
                    .collection("connections")
                    .document(connectionID)

            let firebaseConnection =
                try await connectionReference
                    .getDocument(
                        as:
                            LumoriConnection.self
                    )

            guard firebaseConnection.status ==
                    "connected"
            else {

                clearLocalConnection()

                startUserConnectionListener(
                    for: uid
                )

                return
            }

            // MARK: Determine Partner UID

            let partnerUID: String

            if firebaseConnection.userA ==
                uid {

                guard let userB =
                        firebaseConnection.userB,
                      !userB.isEmpty
                else {

                    throw ConnectionRestoreError
                        .partnerMissing
                }

                partnerUID =
                    userB

            } else if firebaseConnection.userB ==
                        uid {

                partnerUID =
                    firebaseConnection.userA

            } else {

                throw ConnectionRestoreError
                    .userNotMember
            }

            // MARK: Load Partner Profile

            let partnerName =
                try await loadPartnerDisplayName(
                    partnerUID:
                        partnerUID
                )

            // MARK: Build Local Connection

            connection =
                PartnerConnection(
                    partnerName:
                        partnerName,
                    partnerID:
                        partnerUID,
                    connectedDate:
                        firebaseConnection.connectedAt
                        ?? firebaseConnection.createdAt
                )

            saveConnection()

            startUserConnectionListener(
                for: uid
            )

            print(
                "🔗 Restored Firebase connection:"
            )

            print(
                connectionID
            )

            print(
                "👤 Partner:"
            )

            print(
                partnerName
            )

        } catch {

            restoreErrorMessage =
                error.localizedDescription

            print(
                "🔥 Connection restore error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Partner Profile

    /// Loads the connected partner's display name.
    ///
    /// "Partner" is used as a graceful fallback until that user
    /// has chosen a Lumori display name.
    private func loadPartnerDisplayName(
        partnerUID: String
    ) async throws -> String {

        let partnerReference =
            db
                .collection("users")
                .document(partnerUID)

        let partnerSnapshot =
            try await partnerReference
                .getDocument()

        guard partnerSnapshot.exists
        else {
            return "Partner"
        }

        let partnerData =
            partnerSnapshot.data() ?? [:]

        guard let displayName =
                partnerData[
                    "displayName"
                ] as? String
        else {
            return "Partner"
        }

        let cleanedName =
            displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return cleanedName.isEmpty
            ? "Partner"
            : cleanedName
    }

    // MARK: - Realtime Connection State

    private func startUserConnectionListener(
        for uid: String
    ) {

        if listeningUserID == uid,
           userConnectionListener != nil {

            return
        }

        stopUserConnectionListener()

        listeningUserID =
            uid

        let reference =
            db
                .collection("users")
                .document(uid)

        userConnectionListener =
            reference.addSnapshotListener {
                [weak self]
                snapshot,
                error in

                guard let self
                else {
                    return
                }

                if let error {

                    print(
                        "🔥 Connection listener error:",
                        error.localizedDescription
                    )

                    return
                }

                guard let snapshot,
                      snapshot.exists
                else {
                    return
                }

                let data =
                    snapshot.data() ?? [:]

                let firebaseConnectionID =
                    data[
                        "connectionID"
                    ] as? String

                Task { @MainActor in

                    guard let firebaseConnectionID,
                          !firebaseConnectionID.isEmpty
                    else {

                        if self.connection != nil {

                            print(
                                "🔗 Firebase connection removed."
                            )

                            self.clearLocalConnection()
                        }

                        return
                    }

                    if self.connection == nil {

                        await self
                            .restoreConnectionFromFirebase()
                    }
                }
            }
    }

    private func stopUserConnectionListener() {

        userConnectionListener?
            .remove()

        userConnectionListener =
            nil

        listeningUserID =
            nil
    }

    // MARK: - Firebase Disconnect

    @discardableResult
    func disconnectFromFirebase() async -> Bool {

        guard !isDisconnecting else {
            return false
        }

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            disconnectErrorMessage =
                "No authenticated Firebase user was found."

            return false
        }

        isDisconnecting =
            true

        disconnectErrorMessage =
            nil

        defer {
            isDisconnecting =
                false
        }

        do {

            let currentUserReference =
                db
                    .collection("users")
                    .document(uid)

            let currentUserSnapshot =
                try await currentUserReference
                    .getDocument()

            guard let currentUserData =
                    currentUserSnapshot.data()
            else {

                throw ConnectionDisconnectError
                    .userProfileMissing
            }

            guard let connectionID =
                    currentUserData[
                        "connectionID"
                    ] as? String,
                  !connectionID.isEmpty
            else {

                clearLocalConnection()

                return true
            }

            let connectionReference =
                db
                    .collection("connections")
                    .document(connectionID)

            try await db.runTransaction {
                transaction,
                errorPointer in

                do {

                    let connectionSnapshot =
                        try transaction.getDocument(
                            connectionReference
                        )

                    guard connectionSnapshot.exists
                    else {

                        throw ConnectionDisconnectError
                            .connectionMissing
                    }

                    let firebaseConnection =
                        try connectionSnapshot.data(
                            as:
                                LumoriConnection.self
                        )

                    guard firebaseConnection.userA == uid ||
                            firebaseConnection.userB == uid
                    else {

                        throw ConnectionDisconnectError
                            .userNotMember
                    }

                    transaction.updateData(
                        [
                            "status":
                                "disconnected",
                            "disconnectedAt":
                                FieldValue
                                    .serverTimestamp()
                        ],
                        forDocument:
                            connectionReference
                    )

                    let userAReference =
                        self.db
                            .collection("users")
                            .document(
                                firebaseConnection.userA
                            )

                    transaction.updateData(
                        [
                            "connectionID":
                                FieldValue.delete()
                        ],
                        forDocument:
                            userAReference
                    )

                    if let userB =
                            firebaseConnection.userB,
                       !userB.isEmpty {

                        let userBReference =
                            self.db
                                .collection("users")
                                .document(userB)

                        transaction.updateData(
                            [
                                "connectionID":
                                    FieldValue.delete()
                            ],
                            forDocument:
                                userBReference
                        )
                    }

                    return nil

                } catch {

                    errorPointer?
                        .pointee =
                            error as NSError

                    return nil
                }
            }

            clearLocalConnection()

            print(
                "💔 Lumori connection disconnected:"
            )

            print(
                connectionID
            )

            return true

        } catch {

            disconnectErrorMessage =
                error.localizedDescription

            print(
                "🔥 Disconnect error:",
                error.localizedDescription
            )

            return false
        }
    }

    // MARK: - Local Connect

    func connect(
        partnerName: String,
        pairingCode: String
    ) {

        let cleanedPartnerName =
            partnerName.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let cleanedPairingCode =
            pairingCode.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanedPartnerName.isEmpty
        else {
            return
        }

        guard !cleanedPairingCode.isEmpty
        else {
            return
        }

        connection =
            PartnerConnection(
                partnerName:
                    cleanedPartnerName,
                partnerID:
                    cleanedPairingCode
            )

        saveConnection()

        Task {
            await restoreConnectionFromFirebase()
        }
    }

    // MARK: - Local Disconnect

    func disconnect() {
        clearLocalConnection()
    }

    // MARK: - Persistence

    private func saveConnection() {

        guard let connection
        else {
            return
        }

        do {

            let data =
                try JSONEncoder()
                    .encode(
                        connection
                    )

            UserDefaults.standard
                .set(
                    data,
                    forKey:
                        storageKey
                )

        } catch {

            print(
                "Unable to save partner connection:",
                error
            )
        }
    }

    private func loadConnection() {

        guard let data =
                UserDefaults.standard
                    .data(
                        forKey:
                            storageKey
                    )
        else {
            return
        }

        do {

            connection =
                try JSONDecoder()
                    .decode(
                        PartnerConnection.self,
                        from: data
                    )

        } catch {

            print(
                "Unable to load partner connection:",
                error
            )

            UserDefaults.standard
                .removeObject(
                    forKey:
                        storageKey
                )
        }
    }

    // MARK: - Local Cleanup

    private func clearLocalConnection() {

        connection =
            nil

        UserDefaults.standard
            .removeObject(
                forKey:
                    storageKey
            )
    }
}

// MARK: - Restore Errors

private enum ConnectionRestoreError:
    LocalizedError {

    case userProfileMissing
    case partnerMissing
    case userNotMember

    var errorDescription: String? {

        switch self {

        case .userProfileMissing:

            return "Lumori couldn't find your Firebase profile."

        case .partnerMissing:

            return "Lumori couldn't find the second person in this connection."

        case .userNotMember:

            return "This Firebase user does not belong to the saved Lumori connection."
        }
    }
}

// MARK: - Disconnect Errors

private enum ConnectionDisconnectError:
    LocalizedError {

    case userProfileMissing
    case connectionMissing
    case userNotMember

    var errorDescription: String? {

        switch self {

        case .userProfileMissing:

            return "Lumori couldn't find your Firebase profile."

        case .connectionMissing:

            return "Lumori couldn't find the shared connection."

        case .userNotMember:

            return "This account does not belong to the saved Lumori connection."
        }
    }
}
