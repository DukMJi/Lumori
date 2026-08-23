import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Pairing Service

@MainActor
final class PairingService: ObservableObject {

    // MARK: - Published State

    @Published var pairingCode: String?
    @Published var isCreatingCode = false
    @Published var isJoiningCode = false
    @Published var isConnected = false
    @Published var errorMessage: String?

    // MARK: - Firebase

    private let db = Firestore.firestore()

    // MARK: - Listener

    private var connectionListener:
        ListenerRegistration?

    // MARK: - Cleanup

    deinit {
        connectionListener?.remove()
    }

    // MARK: - Create Pairing Code

    func createPairingCode() async {

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            errorMessage =
                "No authenticated Lumori user was found."

            return
        }

        isCreatingCode = true
        errorMessage = nil

        defer {
            isCreatingCode = false
        }

        do {

            let code =
                try await generateUniqueCode()

            let connection =
                LumoriConnection(
                    id: code,
                    userA: uid,
                    userB: nil,
                    createdAt: Date(),
                    connectedAt: nil,
                    status: "waiting"
                )

            try db
                .collection("connections")
                .document(code)
                .setData(from: connection)

            pairingCode = code

            print(
                "🔗 Pairing code created:"
            )

            print(code)

            listenForConnection(
                code: code
            )

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                "🔥 Pairing creation error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Join Pairing Code

    func joinPairingCode(
        _ rawCode: String
    ) async {

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            errorMessage =
                "No authenticated Lumori user was found."

            return
        }

        let code =
            normalizedCode(
                rawCode
            )

        guard code.count == 6
        else {

            errorMessage =
                "Enter the 6-digit pairing code."

            return
        }

        isJoiningCode = true
        errorMessage = nil

        defer {
            isJoiningCode = false
        }

        let connectionReference =
            db
                .collection("connections")
                .document(code)

        let joiningUserReference =
            db
                .collection("users")
                .document(uid)

        do {

            try await db.runTransaction {
                transaction,
                errorPointer in

                do {

                    // MARK: Connection

                    let connectionSnapshot =
                        try transaction
                            .getDocument(
                                connectionReference
                            )

                    guard connectionSnapshot.exists
                    else {

                        throw PairingError
                            .invalidCode
                    }

                    let connection =
                        try connectionSnapshot
                            .data(
                                as:
                                    LumoriConnection.self
                            )

                    guard connection.userA != uid
                    else {

                        throw PairingError
                            .cannotJoinOwnCode
                    }

                    guard connection.userB == nil,
                          connection.status ==
                            "waiting"
                    else {

                        throw PairingError
                            .codeAlreadyUsed
                    }

                    // MARK: Joining User

                    // We may read our own profile, but we deliberately
                    // do not read the creator's user document.
                    //
                    // Firestore Security Rules validate both users'
                    // final connectionID values atomically.
                    let joiningUserSnapshot =
                        try transaction
                            .getDocument(
                                joiningUserReference
                            )

                    if let joiningData =
                            joiningUserSnapshot.data(),
                       joiningData[
                            "connectionID"
                       ] != nil {

                        throw PairingError
                            .userAlreadyConnected
                    }

                    let creatorUserReference =
                        self.db
                            .collection("users")
                            .document(
                                connection.userA
                            )

                    // MARK: Complete Connection

                    transaction.updateData(
                        [
                            "userB":
                                uid,
                            "connectedAt":
                                Date(),
                            "status":
                                "connected"
                        ],
                        forDocument:
                            connectionReference
                    )

                    // MARK: Creator Profile

                    transaction.setData(
                        [
                            "connectionID":
                                code
                        ],
                        forDocument:
                            creatorUserReference,
                        merge: true
                    )

                    // MARK: Joining Profile

                    transaction.setData(
                        [
                            "connectionID":
                                code
                        ],
                        forDocument:
                            joiningUserReference,
                        merge: true
                    )

                    return nil

                } catch {

                    errorPointer?
                        .pointee =
                            error as NSError

                    return nil
                }
            }

            pairingCode = code
            isConnected = true

            print(
                "❤️ Lumori connection completed:"
            )

            print(code)

        } catch {

            let message =
                pairingMessage(
                    for: error
                )

            errorMessage =
                message

            print(
                "🔥 Pairing join error:",
                message
            )
        }
    }

    // MARK: - Connection Listener

    func listenForConnection(
        code: String
    ) {

        connectionListener?
            .remove()

        let reference =
            db
                .collection("connections")
                .document(code)

        connectionListener =
            reference
                .addSnapshotListener {
                    [weak self]
                    snapshot,
                    error in

                    guard let self
                    else {
                        return
                    }

                    if let error {

                        Task { @MainActor in

                            self.errorMessage =
                                error.localizedDescription
                        }

                        return
                    }

                    guard let snapshot,
                          snapshot.exists
                    else {
                        return
                    }

                    do {

                        let connection =
                            try snapshot.data(
                                as:
                                    LumoriConnection.self
                            )

                        if connection.status ==
                            "connected",
                           connection.userB != nil {

                            Task { @MainActor in

                                self.isConnected =
                                    true

                                print(
                                    "❤️ Partner joined connection:"
                                )

                                print(code)

                                self.connectionListener?
                                    .remove()

                                self.connectionListener =
                                    nil
                            }
                        }

                    } catch {

                        Task { @MainActor in

                            self.errorMessage =
                                error.localizedDescription
                        }
                    }
                }
    }

    // MARK: - Stop Listening

    func stopListening() {

        connectionListener?
            .remove()

        connectionListener =
            nil
    }

    // MARK: - Unique Code

    private func generateUniqueCode()
        async throws -> String {

        for _ in 0..<10 {

            let candidate =
                String(
                    Int.random(
                        in:
                            100000...999999
                    )
                )

            let snapshot =
                try await db
                    .collection(
                        "connections"
                    )
                    .document(
                        candidate
                    )
                    .getDocument()

            if !snapshot.exists {
                return candidate
            }
        }

        throw PairingError
            .couldNotGenerateCode
    }

    // MARK: - Normalization

    private func normalizedCode(
        _ code: String
    ) -> String {

        String(
            code
                .filter(\.isNumber)
                .prefix(6)
        )
    }

    // MARK: - Error Message

    private func pairingMessage(
        for error: Error
    ) -> String {

        guard let pairingError =
                error as? PairingError
        else {

            return error
                .localizedDescription
        }

        switch pairingError {

        case .invalidCode:

            return "That pairing code doesn't exist."

        case .cannotJoinOwnCode:

            return "You can't join your own pairing code."

        case .codeAlreadyUsed:

            return "That pairing code has already been used."

        case .userAlreadyConnected:

            return "This Lumori account is already connected."

        case .couldNotGenerateCode:

            return "Lumori couldn't create a pairing code. Please try again."
        }
    }
}

// MARK: - Pairing Error

private enum PairingError:
    LocalizedError {

    case invalidCode
    case cannotJoinOwnCode
    case codeAlreadyUsed
    case userAlreadyConnected
    case couldNotGenerateCode

    var errorDescription: String? {

        switch self {

        case .invalidCode:

            return "Invalid pairing code."

        case .cannotJoinOwnCode:

            return "Cannot join your own code."

        case .codeAlreadyUsed:

            return "Pairing code already used."

        case .userAlreadyConnected:

            return "User already connected."

        case .couldNotGenerateCode:

            return "Could not generate pairing code."
        }
    }
}
