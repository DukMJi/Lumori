import Foundation

// MARK: - Partner Connection

/// Represents the user's connection to their partner.
///
/// Only one partner can exist at a time.
/// Future backend identifiers can replace the temporary values
/// without changing the surrounding interface.
struct PartnerConnection: Codable, Equatable {

    // MARK: - Properties

    /// Display name shown throughout the app.
    var partnerName: String

    /// Temporary identifier
    /// This will eventually become the backend user identifier.
    var partnerID: String

    /// Date the connection was established.
    var connectedDate: Date

    // MARK: - Initialization

    init(
        partnerName: String,
        partnerID: String,
        connectedDate: Date = Date()
    ) {
        self.partnerName = partnerName
        self.partnerID = partnerID
        self.connectedDate = connectedDate
    }
}
