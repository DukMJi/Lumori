import Foundation

struct LumoriConnection: Codable, Identifiable {

    var id: String

    var userA: String
    var userB: String?

    var createdAt: Date
    var connectedAt: Date?

    var status: String
}
