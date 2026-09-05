import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Beacon Store

/// Manages the current user's beacon entries.
///
/// Lumori keeps one user beacon per calendar day. Saving again on the
/// same day updates that day's entry instead of creating a duplicate.
///
/// Entries are stored locally first and synchronized to Firebase.
///
/// When the user is connected, BeaconStore also listens to the current
/// user's own Firebase beacon history so the archive can be restored
/// after signing in on another device or reinstalling Lumori.
@MainActor
final class BeaconStore: ObservableObject {

    // MARK: - Published Properties

    /// User beacon entries ordered from newest to oldest.
    @Published private(set)
    var entries: [BeaconEntry]

    /// Causes date-dependent state to refresh when the day changes.
    @Published private(set)
    var dayReference = Date()

    /// The most recent Firebase synchronization error, if one occurred.
    @Published private(set)
    var syncErrorMessage: String?

    // MARK: - Local Storage

    private let storageKey =
        "lumori.myBeaconEntries"

    // MARK: - Firebase

    private let db =
        Firestore.firestore()

    private var beaconListener:
        ListenerRegistration?

    // MARK: - Private Properties

    private var midnightRefreshTask:
        Task<Void, Never>?

    // MARK: - Initialization

    init() {

        entries = []

        loadEntries()

        scheduleMidnightRefresh()
    }

    deinit {

        midnightRefreshTask?
            .cancel()

        beaconListener?
            .remove()
    }

    // MARK: - Computed Properties

    /// Returns the current user's beacon when it was shared today.
    var currentMyBeacon: BeaconEntry? {

        entries.first { entry in

            Calendar
                .autoupdatingCurrent
                .isDate(
                    entry.date,
                    inSameDayAs:
                        effectiveDayReference
                )
        }
    }

    /// Returns all feelings previously entered by the user.
    ///
    /// Duplicate feelings are removed without changing their
    /// newest-to-oldest order.
    var previousFeelings: [String] {

        var seenFeelings =
            Set<String>()

        return entries.compactMap { entry in

            let normalizedFeeling =
                entry.feeling
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .lowercased()

            guard
                !normalizedFeeling.isEmpty
            else {
                return nil
            }

            guard
                seenFeelings
                    .insert(
                        normalizedFeeling
                    )
                    .inserted
            else {
                return nil
            }

            return entry.feeling
        }
    }

    /// Returns every entry that is not today's active beacon.
    var historicalEntries: [BeaconEntry] {

        entries.filter { entry in

            !Calendar
                .autoupdatingCurrent
                .isDate(
                    entry.date,
                    inSameDayAs:
                        effectiveDayReference
                )
        }
    }

    // MARK: - Date Reference

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

    // MARK: - Saving

    /// Saves or updates the current user's beacon for today.
    ///
    /// The beacon is written locally immediately. Lumori then
    /// synchronizes the same entry to Firestore in the background.
    ///
    /// When today's beacon already exists, its UUID is preserved so
    /// the update represents the same daily beacon.
    func saveBeacon(
        feeling: String,
        reason: String?,
        contributions: [String],
        colorHex: String
    ) {

        let cleanedFeeling =
            feeling.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanedFeeling.isEmpty
        else {
            return
        }

        let cleanedReason =
            cleanedOptionalText(
                reason
            )

        let cleanedContributions =
            contributions
                .map {
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
                .prefix(3)

        let now = Date()

        let entryToSave:
            BeaconEntry

        // MARK: Update Existing Day

        if let todayIndex =
            entries.firstIndex(
                where: {

                    Calendar
                        .autoupdatingCurrent
                        .isDate(
                            $0.date,
                            inSameDayAs:
                                now
                        )
                }
            ) {

            let existingEntry =
                entries[
                    todayIndex
                ]

            let updatedEntry =
                BeaconEntry(
                    id:
                        existingEntry.id,
                    feeling:
                        cleanedFeeling,
                    reason:
                        cleanedReason,
                    contributions:
                        Array(
                            cleanedContributions
                        ),
                    colorHex:
                        colorHex,
                    date:
                        now
                )

            entries[
                todayIndex
            ] =
                updatedEntry

            entryToSave =
                updatedEntry

        } else {

            // MARK: Create New Day

            let newEntry =
                BeaconEntry(
                    feeling:
                        cleanedFeeling,
                    reason:
                        cleanedReason,
                    contributions:
                        Array(
                            cleanedContributions
                        ),
                    colorHex:
                        colorHex,
                    date:
                        now
                )

            entries.append(
                newEntry
            )

            entryToSave =
                newEntry
        }

        // MARK: Local Persistence

        sortEntries()

        saveEntries()

        refreshDailyState()

        // MARK: Firebase Synchronization

        Task {

            await syncBeaconToFirestore(
                entryToSave
            )
        }
    }

    // MARK: - Firebase History Listener

    /// Begins listening to the signed-in user's own beacon documents
    /// inside the active Lumori connection.
    ///
    /// This restores historical beacons from Firebase and keeps the
    /// local archive synchronized across installations and devices.
    func startListening() async {

        stopListening()

        syncErrorMessage = nil

        guard let firebaseUser =
                Auth.auth().currentUser
        else {
            return
        }

        let uid =
            firebaseUser.uid

        do {

            // MARK: Find Current Connection

            let userSnapshot =
                try await db
                    .collection(
                        "users"
                    )
                    .document(
                        uid
                    )
                    .getDocument()

            guard let userData =
                    userSnapshot.data()
            else {
                return
            }

            guard let connectionID =
                    userData[
                        "connectionID"
                    ] as? String,
                  !connectionID.isEmpty
            else {

                return
            }

            let query =
                db
                    .collection(
                        "connections"
                    )
                    .document(
                        connectionID
                    )
                    .collection(
                        "beacons"
                    )
                    .whereField(
                        "ownerID",
                        isEqualTo:
                            uid
                    )

            beaconListener =
                query
                    .addSnapshotListener {
                        [weak self]
                        snapshot,
                        error in

                        guard let self
                        else {
                            return
                        }

                        if let error {

                            Task {
                                @MainActor in

                                self.syncErrorMessage =
                                    error.localizedDescription

                                print(
                                    "🔥 Own beacon listener error:",
                                    error.localizedDescription
                                )
                            }

                            return
                        }

                        guard let snapshot
                        else {
                            return
                        }

                        let firebaseEntries =
                            snapshot
                                .documents
                                .compactMap {
                                    document
                                    -> BeaconEntry? in

                                    do {

                                        let firebaseEntry =
                                            try document
                                                .data(
                                                    as:
                                                        FirestoreBeaconEntry.self
                                                )

                                        return firebaseEntry
                                            .asBeaconEntry()

                                    } catch {

                                        print(
                                            "🔥 Unable to decode own Firebase beacon:",
                                            error.localizedDescription
                                        )

                                        return nil
                                    }
                                }

                        Task {
                            @MainActor in

                            self
                                .mergeFirebaseEntries(
                                    firebaseEntries
                                )
                        }
                    }

            print(
                "🌊 Listening for own beacons:"
            )

            print(uid)

        } catch {

            syncErrorMessage =
                error.localizedDescription

            print(
                "🔥 Unable to start own beacon listener:",
                error.localizedDescription
            )
        }
    }

    /// Stops listening to the current user's Firebase beacon history.
    func stopListening() {

        beaconListener?
            .remove()

        beaconListener =
            nil
    }

    // MARK: - Merge Firebase History

    /// Merges Firebase history into locally stored history.
    ///
    /// Matching calendar days are replaced by the Firebase version.
    /// This prevents duplicate daily beacons when restoring from another
    /// device while preserving local-only entries that may have existed
    /// before the user connected.
    private func mergeFirebaseEntries(
        _ firebaseEntries: [BeaconEntry]
    ) {

        var mergedEntries =
            entries

        let calendar =
            Calendar.autoupdatingCurrent

        for firebaseEntry
            in firebaseEntries {

            if let existingIndex =
                mergedEntries
                    .firstIndex(
                        where: {

                            calendar
                                .isDate(
                                    $0.date,
                                    inSameDayAs:
                                        firebaseEntry.date
                                )
                        }
                    ) {

                mergedEntries[
                    existingIndex
                ] =
                    firebaseEntry

            } else {

                mergedEntries.append(
                    firebaseEntry
                )
            }
        }

        entries =
            mergedEntries

        sortEntries()

        saveEntries()

        refreshDailyState()

        print(
            "🌊 Own beacons updated:"
        )

        print(
            firebaseEntries.count
        )
    }

    // MARK: - Firebase Synchronization

    /// Synchronizes one local beacon to the currently paired
    /// Lumori connection.
    private func syncBeaconToFirestore(
        _ entry: BeaconEntry
    ) async {

        syncErrorMessage = nil

        guard let firebaseUser =
                Auth.auth().currentUser
        else {

            let message =
                "No Firebase user is available."

            syncErrorMessage =
                message

            print(
                "🔥 Beacon sync error:",
                message
            )

            return
        }

        let uid =
            firebaseUser.uid

        do {

            // MARK: Find User Connection

            let userReference =
                db
                    .collection(
                        "users"
                    )
                    .document(
                        uid
                    )

            let userSnapshot =
                try await userReference
                    .getDocument()

            guard let userData =
                    userSnapshot.data()
            else {

                throw BeaconSyncError
                    .userProfileMissing
            }

            guard let connectionID =
                    userData[
                        "connectionID"
                    ] as? String,
                  !connectionID.isEmpty
            else {

                throw BeaconSyncError
                    .notConnected
            }

            // MARK: Create Daily Identifier

            let dateKey =
                makeDateKey(
                    for: entry.date
                )

            let documentID =
                "\(dateKey)_\(uid)"

            // MARK: Build Firebase Beacon

            let firebaseBeacon =
                FirestoreBeaconEntry(
                    id:
                        entry.id.uuidString,
                    ownerID:
                        uid,
                    feeling:
                        entry.feeling,
                    reason:
                        entry.reason,
                    contributions:
                        entry.contributions,
                    colorHex:
                        entry.colorHex,
                    date:
                        entry.date,
                    dateKey:
                        dateKey,
                    updatedAt:
                        Date()
                )

            // MARK: Write Beacon

            let beaconReference =
                db
                    .collection(
                        "connections"
                    )
                    .document(
                        connectionID
                    )
                    .collection(
                        "beacons"
                    )
                    .document(
                        documentID
                    )

            try beaconReference
                .setData(
                    from:
                        firebaseBeacon
                )

            print(
                "💡 Beacon synced to Firebase:"
            )

            print(
                documentID
            )

        } catch {

            syncErrorMessage =
                error.localizedDescription

            print(
                "🔥 Beacon sync error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Daily Reset

    /// Refreshes date-dependent user beacon state.
    ///
    /// This should be called whenever Lumori returns to the foreground.
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
            Task {
                [weak self] in

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

                guard
                    !Task.isCancelled
                else {
                    return
                }

                self?
                    .refreshDailyState()
            }
    }

    // MARK: - Date Key

    /// Creates the calendar-day identifier used by Firestore.
    ///
    /// Example:
    ///
    /// `2026-08-15`
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

    // MARK: - Debug State

    #if DEBUG

    private var debugDayOffset = 0

    #endif

    // MARK: - Debug Tools

    #if DEBUG

    /// Removes all locally saved beacons created by the current user.
    ///
    /// This currently clears local data only.
    func clearAllEntries() {

        debugDayOffset = 0

        entries = []

        UserDefaults.standard
            .removeObject(
                forKey:
                    storageKey
            )

        refreshDailyState()
    }

    /// Advances the effective date by one day for development testing.
    func simulateNewDay() {

        debugDayOffset += 1

        objectWillChange
            .send()
    }

    /// Restores daily behavior to the real current date.
    func restoreCurrentDay() {

        debugDayOffset = 0

        refreshDailyState()
    }

    #endif

    // MARK: - Local Persistence

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
                "Unable to save user beacon entries:",
                error
            )
        }
    }

    private func loadEntries() {

        guard let data =
                UserDefaults
                    .standard
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
                "Unable to load user beacon entries:",
                error
            )
        }
    }

    // MARK: - Helpers

    private func sortEntries() {

        entries.sort {
            $0.date > $1.date
        }
    }

    private func cleanedOptionalText(
        _ text: String?
    ) -> String? {

        guard let text
        else {
            return nil
        }

        let cleanedText =
            text.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return cleanedText.isEmpty
            ? nil
            : cleanedText
    }
}

// MARK: - Beacon Sync Error

private enum BeaconSyncError:
    LocalizedError {

    case userProfileMissing
    case notConnected

    var errorDescription: String? {

        switch self {

        case .userProfileMissing:

            return
                "Lumori couldn't find your Firebase profile."

        case .notConnected:

            return
                "This Lumori account is not connected to a partner."
        }
    }
}
