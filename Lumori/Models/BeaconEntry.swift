import Foundation

// MARK: - Beacon Entry

/// Represents one emotional beacon stored locally by Lumori.
///
/// The local model remains independent from Firebase so the app can
/// continue functioning even when network synchronization is unavailable.
struct BeaconEntry: Identifiable, Codable, Equatable {

    // MARK: - Properties

    let id: UUID

    /// The user's description of how they feel.
    let feeling: String

    /// Optional context explaining the feeling in more detail.
    let reason: String?

    /// Up to three short contributing words.
    let contributions: [String]

    /// Stored as hexadecimal text so the color can be persisted.
    let colorHex: String

    /// The most recent time this day's beacon was shared or updated.
    let date: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        feeling: String,
        reason: String? = nil,
        contributions: [String],
        colorHex: String,
        date: Date = Date()
    ) {
        self.id = id
        self.feeling = feeling
        self.reason = reason
        self.contributions = contributions
        self.colorHex = colorHex
        self.date = date
    }
}

// MARK: - Firestore Beacon Entry

/// Firebase representation of a Lumori beacon.
///
/// Firestore stores one document per user per calendar day.
/// `ownerID` identifies which member of the connection created it,
/// while `dateKey` provides a stable calendar-day identifier.
struct FirestoreBeaconEntry: Codable, Equatable {

    let id: String
    let ownerID: String

    let feeling: String
    let reason: String?
    let contributions: [String]

    let colorHex: String

    let date: Date
    let dateKey: String

    let updatedAt: Date

    // MARK: - Local Conversion

    func asBeaconEntry() -> BeaconEntry {

        let beaconID =
            UUID(uuidString: id) ?? UUID()

        return BeaconEntry(
            id: beaconID,
            feeling: feeling,
            reason: reason,
            contributions: contributions,
            colorHex: colorHex,
            date: date
        )
    }
}
