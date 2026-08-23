import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Partner Beacon Store

/// Manages beacon entries received from the connected partner.
///
/// Firebase is the source of truth for partner beacons. Lumori listens
/// to the partner's beacon documents in real time and mirrors those
/// entries locally for fast loading and offline presentation.
///
/// Lumori keeps one partner beacon per calendar day.
@MainActor
final class PartnerBeaconStore: ObservableObject {

    // MARK: - Published Properties

    /// Partner entries ordered from newest to oldest.
    @Published private(set) var entries: [BeaconEntry]

    /// Causes date-dependent views to refresh when the day changes.
    @Published private(set) var dayReference = Date()

    /// Indicates whether Lumori is currently establishing the
    /// partner beacon listener.
    @Published private(set) var isStartingListener = false

    /// Most recent partner synchronization error.
    @Published private(set) var syncErrorMessage: String?

    // MARK: - Local Storage

    private let storageKey =
        "lumori.partnerBeaconEntries"

    // MARK: - Firebase

    private let db =
        Firestore.firestore()

    private var beaconListener:
        ListenerRegistration?

    private var listeningConnectionID:
        String?

    private var listeningPartnerUID:
        String?

    // MARK: - Private Properties

    private var midnightRefreshTask:
        Task<Void, Never>?

    #if DEBUG

    private var sampleUpdateIndex = 0
    private var debugDayOffset = 0

    #endif

    // MARK: - Initialization

    init(
        entries: [BeaconEntry]? = nil
    ) {

        if let entries {

            self.entries =
                entries.sorted {
                    $0.date > $1.date
                }

        } else {

            self.entries = []

            loadEntries()
        }

        scheduleMidnightRefresh()
    }

    deinit {

        midnightRefreshTask?
            .cancel()

        beaconListener?
            .remove()
    }

    // MARK: - Computed Properties

    /// Returns the partner's newest beacon only when it was shared today.
    var currentBeacon: BeaconEntry? {

        guard let newestEntry =
                entries.first
        else {
            return nil
        }

        guard Calendar
            .autoupdatingCurrent
            .isDate(
                newestEntry.date,
                inSameDayAs:
                    effectiveDayReference
            )
        else {
            return nil
        }

        return newestEntry
    }

    /// Returns every entry that is not currently displayed as today's beacon.
    var historicalEntries: [BeaconEntry] {

        guard currentBeacon != nil
        else {
            return entries
        }

        return Array(
            entries.dropFirst()
        )
    }

    // MARK: - Date Reference

    /// Returns the date Lumori currently treats as today.
    private var effectiveDayReference: Date {

        #if DEBUG

        return Calendar
            .autoupdatingCurrent
            .date(
                byAdding: .day,
                value: debugDayOffset,
                to: dayReference
            ) ?? dayReference

        #else

        return dayReference

        #endif
    }

    // MARK: - Firebase Listener

    /// Finds the authenticated user's connection and begins listening
    /// to the other member's beacon documents.
    func startListening() async {

        guard !isStartingListener
        else {
            return
        }

        guard let uid =
                Auth.auth().currentUser?.uid
        else {

            syncErrorMessage =
                "No authenticated Firebase user was found."

            return
        }

        isStartingListener = true
        syncErrorMessage = nil

        defer {
            isStartingListener = false
        }

        do {

            // MARK: Load Current User

            let userSnapshot =
                try await db
                    .collection("users")
                    .document(uid)
                    .getDocument()

            guard let userData =
                    userSnapshot.data()
            else {

                throw PartnerSyncError
                    .userProfileMissing
            }

            guard let connectionID =
                    userData[
                        "connectionID"
                    ] as? String,
                  !connectionID.isEmpty
            else {

                throw PartnerSyncError
                    .notConnected
            }

            // MARK: Load Connection

            let connection =
                try await db
                    .collection("connections")
                    .document(connectionID)
                    .getDocument(
                        as:
                            LumoriConnection.self
                    )

            guard connection.status ==
                    "connected"
            else {

                throw PartnerSyncError
                    .connectionNotCompleted
            }

            // MARK: Determine Partner

            let partnerUID: String

            if connection.userA == uid {

                guard let userB =
                        connection.userB,
                      !userB.isEmpty
                else {

                    throw PartnerSyncError
                        .partnerMissing
                }

                partnerUID = userB

            } else if connection.userB == uid {

                partnerUID =
                    connection.userA

            } else {

                throw PartnerSyncError
                    .userNotMember
            }

            // Avoid attaching duplicate listeners.
            if listeningConnectionID ==
                    connectionID,
               listeningPartnerUID ==
                    partnerUID,
               beaconListener != nil {

                return
            }

            attachBeaconListener(
                connectionID:
                    connectionID,
                partnerUID:
                    partnerUID
            )

        } catch {

            syncErrorMessage =
                error.localizedDescription

            print(
                "🔥 Partner beacon listener error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Attach Listener

    private func attachBeaconListener(
        connectionID: String,
        partnerUID: String
    ) {

        stopListening()

        listeningConnectionID =
            connectionID

        listeningPartnerUID =
            partnerUID

        let query =
            db
                .collection("connections")
                .document(connectionID)
                .collection("beacons")
                .whereField(
                    "ownerID",
                    isEqualTo:
                        partnerUID
                )

        beaconListener =
            query.addSnapshotListener {
                [weak self]
                snapshot,
                error in

                guard let self
                else {
                    return
                }

                if let error {

                    Task { @MainActor in

                        self.syncErrorMessage =
                            error.localizedDescription

                        print(
                            "🔥 Partner beacon sync error:",
                            error.localizedDescription
                        )
                    }

                    return
                }

                guard let snapshot
                else {
                    return
                }

                var firebaseEntries:
                    [FirestoreBeaconEntry] = []

                for document in
                    snapshot.documents {

                    do {

                        let beacon =
                            try document.data(
                                as:
                                    FirestoreBeaconEntry.self
                            )

                        firebaseEntries.append(
                            beacon
                        )

                    } catch {

                        print(
                            "🔥 Unable to decode partner beacon:",
                            error.localizedDescription
                        )
                    }
                }

                let convertedEntries =
                    firebaseEntries
                        .map {
                            $0.asBeaconEntry()
                        }
                        .sorted {
                            $0.date > $1.date
                        }

                Task { @MainActor in

                    self.entries =
                        convertedEntries

                    self.saveEntries()

                    self.refreshDailyState()

                    self.syncErrorMessage =
                        nil

                    print(
                        "🌊 Partner beacons updated:"
                    )

                    print(
                        convertedEntries.count
                    )
                }
            }

        print(
            "🌊 Listening for partner beacons:"
        )

        print(
            partnerUID
        )
    }

    // MARK: - Stop Listening

    func stopListening() {

        beaconListener?
            .remove()

        beaconListener = nil

        listeningConnectionID =
            nil

        listeningPartnerUID =
            nil
    }

    // MARK: - Synchronization

    /// Replaces all locally held partner entries.
    ///
    /// Primarily retained for development and preview support.
    func replaceEntries(
        with newEntries:
            [BeaconEntry]
    ) {

        entries =
            newEntries.sorted {
                $0.date > $1.date
            }

        saveEntries()

        refreshDailyState()
    }

    /// Adds a received partner beacon or updates an existing entry.
    ///
    /// Retained for Lumori's DEBUG simulation tools.
    func receive(
        _ entry: BeaconEntry
    ) {

        if let existingIDIndex =
            entries.firstIndex(
                where: {
                    $0.id == entry.id
                }
            ) {

            entries[
                existingIDIndex
            ] = entry

        } else if let sameDayIndex =
            entries.firstIndex(
                where: {

                    Calendar
                        .autoupdatingCurrent
                        .isDate(
                            $0.date,
                            inSameDayAs:
                                entry.date
                        )
                }
            ) {

            let existingEntry =
                entries[
                    sameDayIndex
                ]

            entries[
                sameDayIndex
            ] =
                BeaconEntry(
                    id:
                        existingEntry.id,
                    feeling:
                        entry.feeling,
                    reason:
                        entry.reason,
                    contributions:
                        entry.contributions,
                    colorHex:
                        entry.colorHex,
                    date:
                        entry.date
                )

        } else {

            entries.append(
                entry
            )
        }

        sortEntries()

        saveEntries()

        refreshDailyState()
    }

    // MARK: - Daily Reset

    /// Refreshes date-dependent partner beacon state.
    func refreshDailyState() {

        dayReference =
            Date()

        scheduleMidnightRefresh()
    }

    private func scheduleMidnightRefresh() {

        midnightRefreshTask?
            .cancel()

        let calendar =
            Calendar.autoupdatingCurrent

        let todayStart =
            calendar.startOfDay(
                for: Date()
            )

        guard let nextMidnight =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: todayStart
                )
        else {
            return
        }

        let secondsUntilMidnight =
            max(
                nextMidnight
                    .timeIntervalSinceNow,
                1
            )

        midnightRefreshTask =
            Task { [weak self] in

                do {

                    try await Task.sleep(
                        for:
                            .seconds(
                                secondsUntilMidnight
                            )
                    )

                } catch {

                    return
                }

                guard !Task.isCancelled
                else {
                    return
                }

                self?
                    .refreshDailyState()
            }
    }

    // MARK: - Persistence

    private func saveEntries() {

        do {

            let data =
                try JSONEncoder()
                    .encode(
                        entries
                    )

            UserDefaults.standard
                .set(
                    data,
                    forKey:
                        storageKey
                )

        } catch {

            print(
                "Unable to save partner beacon entries:",
                error
            )
        }
    }

    private func loadEntries() {

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

            entries =
                try JSONDecoder()
                    .decode(
                        [BeaconEntry].self,
                        from: data
                    )

            sortEntries()

        } catch {

            print(
                "Unable to load partner beacon entries:",
                error
            )

            UserDefaults.standard
                .removeObject(
                    forKey:
                        storageKey
                )
        }
    }

    // MARK: - Helpers

    private func sortEntries() {

        entries.sort {
            $0.date > $1.date
        }
    }

    // MARK: - Debug Tools

    #if DEBUG

    /// Simulates the connected partner sharing or updating today's beacon.
    func simulateNextUpdate() {

        let sample =
            Self.simulatedUpdates[
                sampleUpdateIndex %
                Self.simulatedUpdates.count
            ]

        sampleUpdateIndex += 1

        let simulatedEntry =
            BeaconEntry(
                feeling:
                    sample.feeling,
                reason:
                    sample.reason,
                contributions:
                    sample.contributions,
                colorHex:
                    sample.colorHex,
                date:
                    Date()
            )

        receive(
            simulatedEntry
        )
    }

    /// Advances Lumori's effective date by one day.
    func simulateNewDay() {

        debugDayOffset += 1

        objectWillChange.send()
    }

    /// Returns Lumori to the real current calendar day.
    func restoreCurrentDay() {

        debugDayOffset = 0

        refreshDailyState()
    }

    /// Restores the original prototype partner entries.
    func resetToSampleEntries() {

        sampleUpdateIndex = 0
        debugDayOffset = 0

        entries =
            Self.sampleEntries.sorted {
                $0.date > $1.date
            }

        saveEntries()

        refreshDailyState()
    }

    /// Removes every locally stored partner beacon.
    func clearEntries() {

        sampleUpdateIndex = 0
        debugDayOffset = 0

        entries = []

        UserDefaults.standard
            .removeObject(
                forKey:
                    storageKey
            )

        refreshDailyState()
    }

    #endif
}

// MARK: - Partner Sync Error

private enum PartnerSyncError:
    LocalizedError {

    case userProfileMissing
    case notConnected
    case connectionNotCompleted
    case partnerMissing
    case userNotMember

    var errorDescription:
        String? {

        switch self {

        case .userProfileMissing:

            return "Lumori couldn't find your Firebase profile."

        case .notConnected:

            return "This Lumori account is not connected."

        case .connectionNotCompleted:

            return "Your Lumori connection is not complete yet."

        case .partnerMissing:

            return "Lumori couldn't find your partner in this connection."

        case .userNotMember:

            return "This Firebase user does not belong to the saved Lumori connection."
        }
    }
}

// MARK: - Prototype Data

extension PartnerBeaconStore {

    static let sampleEntries:
        [BeaconEntry] = [

        BeaconEntry(
            feeling:
                "Overwhelmed",
            reason:
                "I have a lot to finish before the end of the week.",
            contributions: [
                "school",
                "work"
            ],
            colorHex:
                "#6874D8",
            date:
                Date()
        ),

        BeaconEntry(
            feeling:
                "Hopeful",
            reason:
                "Things are finally starting to move in the right direction.",
            contributions: [
                "future",
                "progress"
            ],
            colorHex:
                "#D6A85F",
            date:
                Calendar
                    .autoupdatingCurrent
                    .date(
                        byAdding: .day,
                        value: -1,
                        to: Date()
                    ) ?? Date()
        ),

        BeaconEntry(
            feeling:
                "Peaceful",
            reason:
                "I had time to slow down and be alone today.",
            contributions: [
                "rest",
                "music"
            ],
            colorHex:
                "#5D9C91",
            date:
                Calendar
                    .autoupdatingCurrent
                    .date(
                        byAdding: .day,
                        value: -3,
                        to: Date()
                    ) ?? Date()
        )
    ]

    #if DEBUG

    private struct SimulatedBeacon {

        let feeling: String
        let reason: String
        let contributions:
            [String]
        let colorHex: String
    }

    private static let simulatedUpdates:
        [SimulatedBeacon] = [

        SimulatedBeacon(
            feeling:
                "Content",
            reason:
                "Today felt quiet in a good way.",
            contributions: [
                "rest",
                "home"
            ],
            colorHex:
                "#6EAA8C"
        ),

        SimulatedBeacon(
            feeling:
                "Anxious",
            reason:
                "There are a few things on my mind that I haven't sorted out yet.",
            contributions: [
                "school",
                "uncertainty"
            ],
            colorHex:
                "#A66FAF"
        ),

        SimulatedBeacon(
            feeling:
                "Excited",
            reason:
                "I finally have something good to look forward to.",
            contributions: [
                "plans",
                "future"
            ],
            colorHex:
                "#D19A61"
        ),

        SimulatedBeacon(
            feeling:
                "Drained",
            reason:
                "I don't think I have much energy left today.",
            contributions: [
                "work",
                "sleep"
            ],
            colorHex:
                "#5B8FB9"
        )
    ]

    #endif
}
