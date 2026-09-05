import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Beacon Seen Service

/// Records and observes whether today's beacon has been intentionally opened
/// by the user's connected partner.
///
/// Lumori treats a beacon as viewed only when the partner explicitly reveals
/// its details. Merely receiving or loading a beacon does not create a receipt.
@MainActor
final class BeaconSeenService: ObservableObject {

    // MARK: - Published Properties

    /// True when the connected partner has opened the current user's beacon.
    @Published private(set)
    var hasPartnerSeenCurrentBeacon = false

    // MARK: - Firebase

    private let db =
        Firestore.firestore()

    private var seenListener:
        ListenerRegistration?

    // MARK: - Cleanup

    deinit {
        seenListener?
            .remove()
    }

    // MARK: - Mark Seen

    /// Records that the signed-in user intentionally opened the partner's
    /// current beacon.
    func markPartnerBeaconSeen(
        entry: BeaconEntry
    ) async {

        guard let currentUser =
                Auth.auth().currentUser
        else {
            return
        }

        do {

            let context =
                try await connectionContext(
                    currentUID:
                        currentUser.uid
                )

            let dateKey =
                makeDateKey(
                    for: entry.date
                )

            let beaconDocumentID =
                "\(dateKey)_\(context.partnerUID)"

            let viewReference =
                db
                    .collection(
                        "connections"
                    )
                    .document(
                        context.connectionID
                    )
                    .collection(
                        "beacons"
                    )
                    .document(
                        beaconDocumentID
                    )
                    .collection(
                        "views"
                    )
                    .document(
                        currentUser.uid
                    )

            try await viewReference
                .setData(
                    [
                        "viewerID":
                            currentUser.uid,

                        "viewedAt":
                            FieldValue
                                .serverTimestamp()
                    ],
                    merge: true
                )

            print(
                "👁️ Partner beacon viewed:"
            )

            print(
                beaconDocumentID
            )

        } catch {

            print(
                "🔥 Unable to record beacon view:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Observe Current Beacon

    /// Watches the current user's active beacon for a receipt from the
    /// connected partner.
    func startListening(
        to entry: BeaconEntry?
    ) async {

        stopListening()

        hasPartnerSeenCurrentBeacon =
            false

        guard let entry,
              let currentUser =
                Auth.auth().currentUser
        else {
            return
        }

        do {

            let context =
                try await connectionContext(
                    currentUID:
                        currentUser.uid
                )

            let dateKey =
                makeDateKey(
                    for: entry.date
                )

            let beaconDocumentID =
                "\(dateKey)_\(currentUser.uid)"

            let viewReference =
                db
                    .collection(
                        "connections"
                    )
                    .document(
                        context.connectionID
                    )
                    .collection(
                        "beacons"
                    )
                    .document(
                        beaconDocumentID
                    )
                    .collection(
                        "views"
                    )
                    .document(
                        context.partnerUID
                    )

            seenListener =
                viewReference
                    .addSnapshotListener {
                        [weak self]
                        snapshot,
                        error in

                        guard let self
                        else {
                            return
                        }

                        if let error {

                            print(
                                "🔥 Beacon seen listener error:",
                                error.localizedDescription
                            )

                            return
                        }

                        let hasBeenSeen =
                            snapshot?.exists
                            ?? false

                        Task {
                            @MainActor in

                            self
                                .hasPartnerSeenCurrentBeacon =
                                hasBeenSeen
                        }
                    }

        } catch {

            print(
                "🔥 Unable to start beacon seen listener:",
                error.localizedDescription
            )
        }
    }

    /// Removes the active Firestore listener.
    func stopListening() {

        seenListener?
            .remove()

        seenListener =
            nil

        hasPartnerSeenCurrentBeacon =
            false
    }

    // MARK: - Connection Context

    /// Resolves the current connection and connected partner UID.
    private func connectionContext(
        currentUID: String
    ) async throws
        -> BeaconConnectionContext {

        // MARK: Read User

        let userSnapshot =
            try await db
                .collection(
                    "users"
                )
                .document(
                    currentUID
                )
                .getDocument()

        guard let userData =
                userSnapshot.data()
        else {

            throw BeaconSeenError
                .userProfileMissing
        }

        guard let connectionID =
                userData[
                    "connectionID"
                ] as? String,
              !connectionID.isEmpty
        else {

            throw BeaconSeenError
                .notConnected
        }

        // MARK: Read Connection

        let connectionSnapshot =
            try await db
                .collection(
                    "connections"
                )
                .document(
                    connectionID
                )
                .getDocument()

        guard let connectionData =
                connectionSnapshot.data()
        else {

            throw BeaconSeenError
                .connectionMissing
        }

        let userA =
            connectionData[
                "userA"
            ] as? String

        let userB =
            connectionData[
                "userB"
            ] as? String

        let partnerUID: String?

        if userA == currentUID {

            partnerUID = userB

        } else if userB == currentUID {

            partnerUID = userA

        } else {

            partnerUID = nil
        }

        guard let partnerUID,
              !partnerUID.isEmpty
        else {

            throw BeaconSeenError
                .partnerMissing
        }

        return BeaconConnectionContext(
            connectionID:
                connectionID,
            partnerUID:
                partnerUID
        )
    }

    // MARK: - Date Key

    private func makeDateKey(
        for date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.calendar =
            Calendar.autoupdatingCurrent

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            .autoupdatingCurrent

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter.string(
            from: date
        )
    }
}

// MARK: - Connection Context

private struct BeaconConnectionContext {

    let connectionID: String
    let partnerUID: String
}

// MARK: - Errors

private enum BeaconSeenError:
    LocalizedError {

    case userProfileMissing
    case notConnected
    case connectionMissing
    case partnerMissing

    var errorDescription: String? {

        switch self {

        case .userProfileMissing:

            return
                "Lumori couldn't find the current user profile."

        case .notConnected:

            return
                "Lumori isn't currently connected to a partner."

        case .connectionMissing:

            return
                "Lumori couldn't find the active connection."

        case .partnerMissing:

            return
                "Lumori couldn't identify the connected partner."
        }
    }
}
